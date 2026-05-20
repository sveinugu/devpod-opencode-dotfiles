# GitHub App Integration M2 Durable Dedupe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace M1 process-local idempotency with a Redis-backed durable dedupe layer that retains replay records for at least 24 hours and works across executor replicas without changing Request Contract v1.

**Architecture:** Keep the external FastAPI contract unchanged and move only the internal idempotency state from in-memory process state to a Redis-backed store behind a small store interface. Use canonicalized scope digests for Redis keys, one short-lived tokenized claim key to prevent concurrent cross-replica double-execution, and one 24-hour result key written atomically with TTL via Lua so replays stay deterministic across replicas and restarts.

**Tech Stack:** Python, FastAPI, pytest, redis-py, Redis

---

## 1) Summary

M2 should use Redis, not Postgres, because the hard requirement is durable 24-hour replay retention with cross-replica dedupe, and Redis gives native TTL, low-latency atomic claim operations, and simpler operations for ephemeral replay state. The implementation should be a small internal store swap: keep Request Contract v1 unchanged, add a Redis-backed idempotency adapter plus migration flags, use Lua for atomic finalize/release paths, and verify behavior first with failing pytest integration tests that prove restart survival, deterministic first-writer races, and replay across two app replicas.

## 2) Decision: Redis vs Postgres

**Recommendation: Redis**

**Why Redis wins here**

- TTL is a first-class requirement; Redis expiration is native and deterministic, while Postgres would need `expires_at` plus a cleanup job.
- Cross-replica dedupe needs an atomic first-writer claim; Redis `SET ... NX EX` is simpler than SQL row-lock choreography for this narrow case.
- The replay payload is small, short-lived, and key-addressed; this is cache-like state, not relational business data.
- The codebase is currently a thin FastAPI tracer-bullet; Redis adds less implementation and operational surface than adding durable SQL schema management just for 24-hour replay state.

**Why not Postgres first**

- More moving parts for retention semantics: table, indexes, cleanup worker, vacuum considerations, lock strategy.
- Higher chance of over-design for a state model that is read/write by exact key and naturally expires.

**Short fallback plan if Redis cannot be approved**

Use Postgres with table `idempotency_records`, composite unique key `(workload_identity, repo, action, idempotency_key)`, columns `payload_hash`, `canonical_result_json`, `first_request_id`, `created_at`, `expires_at`, and a cleanup job every 15 minutes deleting expired rows. Keep the same store interface so the application code change is limited to swapping the adapter.

## 3) Data model / schema / key formats

### Canonicalization rules

- Build dedupe scope from a canonical JSON object with fixed field names and sort order:

  ```python
  {
      "action": validated_action_slug,
      "idempotency_key": request.idempotency_key,
      "repo": f"{owner}/{name}".lower(),
      "workload_identity": authenticated_subject,
  }
  ```

- `repo` must be normalized to lowercase `owner/name` after request validation so `Octo-OrG/Demo-Repo` and `octo-org/demo-repo` map to one dedupe scope.
- `action` must come from the server-side validated action enum/slug, not raw client spelling.
- `workload_identity` stays case-sensitive and exact; do not lowercase or trim authenticated principal strings.
- `idempotency_key` is treated as an opaque caller token; reject leading/trailing whitespace during validation instead of trimming silently.
- Compute `scope_digest = sha256(canonical_scope_json).hexdigest()` and use that digest in Redis key names to avoid delimiter ambiguity, excessive key length, and inconsistent percent-encoding.
- Compute `payload_hash` from canonical JSON bytes for the request payload (`sort_keys=True`, compact separators) so field ordering does not change mismatch behavior.

### Internal keying rules

- **Authoritative dedupe scope:** `(workload_identity, repo, action, idempotency_key)`
- **Stored correlation fields:** `scope_digest`, `first_request_id`, `last_request_id`, `payload_hash`, `canonical_result_json`, `created_at`, `expires_at`, `schema_version`

### TTL invariants

- Result TTL is `86400` seconds, set exactly once on the first successful durable result write.
- Replay reads, mismatch reads, and status lookups must never call `EXPIRE`, `PEXPIRE`, or `PERSIST` on result keys.
- Result field write and result TTL assignment must happen in the same Lua script invocation; `HSET` followed by a separate `EXPIRE` command is not acceptable.
- Claim TTL is short-lived (`60` seconds) and always less than the upstream request timeout so orphaned claims self-clear.
- `created_at` and `expires_at` are derived from the same winner-side clock sample used to set the result TTL; tests should allow at most 1 second skew between stored timestamps and observed Redis TTL.

### Redis keys

1. **Result key** — durable replay record, TTL 86400 seconds

   ```text
   gha:idem:v2:result:7c52a4cc9f4a0b93e3f3d0e5d2d8fef3ebc9d5b1a4f70b498ce9c6e321cb7d44
   ```

   **Redis hash fields**

   - `schema_version` = `2`
   - `scope_digest` = `7c52a4cc9f4a0b93e3f3d0e5d2d8fef3ebc9d5b1a4f70b498ce9c6e321cb7d44`
   - `first_request_id` = `req_ab12cd34`
   - `last_request_id` = `req_ab12cd34`
   - `workload_identity` = `system:serviceaccount:devpod-workspaces:opencode-agent`
   - `repo` = `octo-org/demo-repo`
   - `action` = `comment-pr`
   - `idempotency_key` = `idem_ab12cd34`
   - `payload_hash` = `<sha256>`
   - `canonical_result_json` = `{"comment_id":9001,"url":"https://github.com/octo-org/demo-repo/pull/42#issuecomment-9001"}`
   - `created_at` = `2026-05-20T14:03:11Z`
   - `expires_at` = `2026-05-21T14:03:11Z`

2. **Claim key** — short-lived in-flight winner lock, TTL 60 seconds

   ```text
   gha:idem:v2:claim:7c52a4cc9f4a0b93e3f3d0e5d2d8fef3ebc9d5b1a4f70b498ce9c6e321cb7d44
   ```

    **Value**

    - random lock token tied to the winning request, for example `req_ab12cd34:3d2b6c4f8f9e4c0ea7ab1c5d9f0e1234`

### Required indexes

- Redis primary access is by exact key; no secondary index is required for serving.
- Optional operational scan prefix only: `gha:idem:v2:result:*` for metrics/runbook inspection.
- If the Postgres fallback is used, create:
  - `UNIQUE INDEX uq_idem_scope ON idempotency_records(workload_identity, repo, action, idempotency_key)`
  - `INDEX idx_idem_expires_at ON idempotency_records(expires_at)`

### Internal flow contract

1. Canonicalize scope and payload, then compute `scope_digest` and `payload_hash` before touching Redis.
2. Read result key.
3. If found and payload hash matches, return cached canonical result without changing the TTL.
4. If found and payload hash differs, return `409 DUPLICATE_PAYLOAD_MISMATCH` without changing the TTL.
5. If missing, acquire claim key with `SET claim_key lock_token NX EX 60`.
6. Winner executes GitHub mutation, then runs `finalize_result.lua` to atomically verify lock ownership, write the result hash, assign the 24-hour TTL, and delete the claim key.
7. If the winner fails before result finalization, it may only release the claim via `release_claim.lua` compare-and-delete using the same `lock_token`; plain `DEL claim_key` is forbidden.
8. If `finalize_result.lua` returns `LOCK_MISMATCH`, treat the request as having lost claim ownership and fall back to replay polling / retryable timeout behavior rather than deleting the current claim.
9. Loser polls result key briefly; if result appears, return replay response; if not, return existing retryable timeout behavior without changing the external envelope shape.

### Required Lua scripts

`finalize_result.lua`

```lua
-- KEYS[1] = claim key
-- KEYS[2] = result key
-- ARGV[1] = expected lock token
-- ARGV[2] = result ttl seconds (86400)
-- ARGV[3] = schema_version
-- ARGV[4] = scope_digest
-- ARGV[5] = first_request_id
-- ARGV[6] = last_request_id
-- ARGV[7] = workload_identity
-- ARGV[8] = repo
-- ARGV[9] = action
-- ARGV[10] = idempotency_key
-- ARGV[11] = payload_hash
-- ARGV[12] = canonical_result_json
-- ARGV[13] = created_at
-- ARGV[14] = expires_at
local claim = redis.call("GET", KEYS[1])
if claim ~= ARGV[1] then
  return "LOCK_MISMATCH"
end
if redis.call("EXISTS", KEYS[2]) == 1 then
  redis.call("DEL", KEYS[1])
  return "RESULT_ALREADY_EXISTS"
end
redis.call("HSET", KEYS[2],
  "schema_version", ARGV[3],
  "scope_digest", ARGV[4],
  "first_request_id", ARGV[5],
  "last_request_id", ARGV[6],
  "workload_identity", ARGV[7],
  "repo", ARGV[8],
  "action", ARGV[9],
  "idempotency_key", ARGV[10],
  "payload_hash", ARGV[11],
  "canonical_result_json", ARGV[12],
  "created_at", ARGV[13],
  "expires_at", ARGV[14]
)
redis.call("EXPIRE", KEYS[2], tonumber(ARGV[2]))
redis.call("DEL", KEYS[1])
return "OK"
```

`release_claim.lua`

```lua
-- KEYS[1] = claim key
-- ARGV[1] = expected lock token
if redis.call("GET", KEYS[1]) == ARGV[1] then
  return redis.call("DEL", KEYS[1])
end
return 0
```

## 4) Migration strategy and runbook steps

**Important honesty note:** zero downtime is realistic; zero dedupe-gap is not. Existing M1 in-memory keys cannot be backfilled after restart, so the migration must minimize but cannot erase that pre-existing limitation.

### Rollout path

1. **Ship the abstraction first**
   - Add `IdempotencyStore` interface.
   - Keep `InMemoryIdempotencyStore` as the default.
   - Add `RedisIdempotencyStore` behind config.

2. **Provision Redis before cutover**
   - Enable TLS, AUTH/ACL, persistence (`appendonly yes` preferred), and encryption at rest via the managed service or encrypted volume.

3. **Dual-write warm-up (near-zero downtime)**
   - All replicas stay on the same migration mode.
   - Successful M1 writes also populate Redis result keys.
   - Recommended read behavior during warm-up is still memory-primary because Redis is not yet authoritative.
   - Keep this on for one full 24-hour window.

4. **Use one mixed-mode safety strategy, not ad hoc partial rollout**
   - **Recommended:** cluster-wide switch. Drain or pause traffic, then deploy all replicas with `IDEMPOTENCY_BACKEND=redis` in one rollout wave so no serving replica remains memory-only while another is Redis-only.
   - **Fallback if cluster-wide switch is impossible:** temporary `dual-read` mode on **all** replicas, reading Redis first and memory second while dual-write remains enabled. Remove memory reads after the final all-replica Redis cutover.
   - Replica startup should export/log its current idempotency migration mode so mixed fleets are visible immediately.
   - Keep optional memory fallback disabled after cutover to avoid split-brain replay decisions.

5. **Observe for 24 hours**
   - Watch replay-hit rate, payload mismatch rate, Redis latency, and claim contention.

6. **Remove dual-write mode**
   - Leave only Redis as the authoritative M2 backend.

### Runbook steps

1. Confirm Redis readiness and TLS connectivity.
2. Deploy code containing both stores but with memory still primary.
3. Enable dual-write on every replica.
4. Wait 24 hours.
5. Perform a cluster-wide switch to Redis primary, or enable temporary dual-read on every replica if a synchronized switch is impossible.
6. Verify no replica is advertising a stale migration mode before resuming normal traffic.
7. Run cross-replica replay verification commands from §6.
8. If rollback is needed, revert every replica together to memory-only knowing cross-replica replay guarantee is temporarily lost.

## 5) API / internal contract notes

### External contract (unchanged)

- Keep Request Contract v1 request and response envelopes exactly as they are now.
- Keep current success behavior: first write returns `201`, replay returns `200`, mismatch returns `409 DUPLICATE_PAYLOAD_MISMATCH`.
- Do not add external fields for Redis metadata, TTL, lock ownership, or replica source.

### Internal-only layout

- Redis key names, canonicalization rules, lock semantics, `lock_token`, `expires_at`, and `schema_version` remain internal-only.
- `request_id` remains a correlation field, not the primary dedupe key.
- `status_by_request_id` may stay process-local for M2 unless a later slice requires durable status lookups; that is separate from durable dedupe.

## 6) Test specs and verification matrix

### Behavior-first pytest snippets

`tests/integration/test_m2_idempotency_retention.py`

```python
@pytest.mark.integration
def test_replay_hit_survives_executor_restart_within_24h(redis_backed_live_server, auth_headers):
    request = {
        "request_id": "req_m2_restart_a",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_m2_restart_a",
        "payload": {"pr_number": 42, "body": "retain me"},
    }

    first = redis_backed_live_server.post("/v1/action", headers=auth_headers, json=request)
    redis_backed_live_server.restart_replica("a")
    replay = redis_backed_live_server.post("/v1/action", headers=auth_headers, json=request)

    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.json() == first.json()
    assert redis_backed_live_server.github_comment_count(request["request_id"]) == 1


@pytest.mark.integration
def test_cross_replica_replay_returns_same_canonical_result(redis_two_replica_cluster, auth_headers):
    request = {
        "request_id": "req_m2_replica_a",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_m2_replica_a",
        "payload": {"pr_number": 42, "body": "same result across replicas"},
    }

    first = redis_two_replica_cluster.replica_a.post("/v1/action", headers=auth_headers, json=request)
    replay = redis_two_replica_cluster.replica_b.post("/v1/action", headers=auth_headers, json=request)

    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.json() == first.json()
    assert redis_two_replica_cluster.total_github_comment_count(request["request_id"]) == 1


@pytest.mark.integration
def test_same_key_different_payload_returns_duplicate_payload_mismatch_within_24h(redis_two_replica_cluster, auth_headers):
    first = {
        "request_id": "req_m2_payload_a",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_m2_payload_a",
        "payload": {"pr_number": 42, "body": "body a"},
    }
    second = {**first, "request_id": "req_m2_payload_b", "payload": {"pr_number": 42, "body": "body b"}}

    assert redis_two_replica_cluster.replica_a.post("/v1/action", headers=auth_headers, json=first).status_code == 201
    conflict = redis_two_replica_cluster.replica_b.post("/v1/action", headers=auth_headers, json=second)

    assert conflict.status_code == 409
    assert conflict.json()["error"]["code"] == "DUPLICATE_PAYLOAD_MISMATCH"


@pytest.mark.integration
def test_concurrent_cross_replica_race_is_deterministic(redis_two_replica_cluster, auth_headers, idem_race_barrier):
    request_a = {
        "request_id": "req_m2_race_a",
        "repo": "Octo-OrG/Demo-Repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_m2_race_a",
        "payload": {"pr_number": 42, "body": "race me"},
    }
    request_b = {**request_a, "request_id": "req_m2_race_b", "repo": "octo-org/demo-repo"}

    first, second = redis_two_replica_cluster.run_race(
        request_a=request_a,
        request_b=request_b,
        barrier=idem_race_barrier,
    )

    assert sorted([first.status_code, second.status_code]) == [200, 201]
    assert first.json() == second.json()
    assert redis_two_replica_cluster.total_github_comment_count("idem_m2_race_a") == 1


@pytest.mark.integration
def test_replay_does_not_extend_result_ttl(redis_backed_live_server, auth_headers):
    request = {
        "request_id": "req_m2_ttl_a",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_m2_ttl_a",
        "payload": {"pr_number": 42, "body": "ttl stays fixed"},
    }

    first = redis_backed_live_server.post("/v1/action", headers=auth_headers, json=request)
    ttl_after_first = redis_backed_live_server.result_ttl(request)
    replay = redis_backed_live_server.post("/v1/action", headers=auth_headers, json=request)
    ttl_after_replay = redis_backed_live_server.result_ttl(request)

    assert first.status_code == 201
    assert replay.status_code == 200
    assert 0 < ttl_after_replay <= ttl_after_first
    assert ttl_after_first - ttl_after_replay <= 1
```

### Verification matrix

| Goal | File path | Command | Expected red result before implementation | Expected green result after implementation |
|---|---|---|---|---|
| M1 limitation remains documented | `tests/integration/test_m1_idempotency_process_lifetime.py` | `pytest tests/integration/test_m1_idempotency_process_lifetime.py::test_m1_restart_clears_in_memory_dedupe -v` | `PASSED` showing current restart-loss behavior | `PASSED` unchanged; proves migration did not rewrite M1 semantics retroactively |
| Restart-safe 24h replay | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_replay_hit_survives_executor_restart_within_24h -v` | `FAILED` because second request still returns `201` and GitHub mutation count is `2` | `PASSED`; second request returns `200` and mutation count stays `1` |
| Cross-replica dedupe | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_cross_replica_replay_returns_same_canonical_result -v` | `FAILED` because replica B does not see replica A state | `PASSED`; replay body matches exactly and total mutation count is `1` |
| Payload mismatch within window | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_same_key_different_payload_returns_duplicate_payload_mismatch_within_24h -v` | `FAILED` because second payload is accepted or wrong code is returned | `PASSED`; `409` with `DUPLICATE_PAYLOAD_MISMATCH` |
| Deterministic first-writer race | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_concurrent_cross_replica_race_is_deterministic -v` | `FAILED` because both requests can execute the GitHub mutation or response bodies diverge | `PASSED`; exactly one `201`, one `200`, identical bodies, one mutation |
| TTL invariant: replay never extends retention | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_replay_does_not_extend_result_ttl -v` | `FAILED` because replay refreshes the TTL or no TTL is present | `PASSED`; replay returns `200` and observed TTL only decreases |
| Lock release is token-safe | `tests/integration/test_m2_redis_scripts.py` | `pytest tests/integration/test_m2_redis_scripts.py::test_release_claim_does_not_delete_reacquired_lock -v` | `FAILED` because a stale owner can delete a newer claim | `PASSED`; compare-and-delete leaves the newer token intact |
| External contract unchanged | `tests/e2e/test_contract_envelope.py` | `pytest tests/e2e/test_contract_envelope.py -v` | Existing failures if envelope shape drifts | `PASSED` with Request Contract v1 unchanged |
| TTL visible at 24h floor | runbook / staging shell | `redis-cli --tls --user app --pass "$REDIS_PASSWORD" TTL "gha:idem:v2:result:7c52a4cc9f4a0b93e3f3d0e5d2d8fef3ebc9d5b1a4f70b498ce9c6e321cb7d44"` | `-2` or unexpected low TTL before feature | Integer between `86340` and `86400` immediately after first write |
| Mixed-mode safety enforced | runbook / staging shell | `kubectl logs deploy/github-app-executor | rg "idempotency_mode=(memory|dual-write|dual-read|redis)"` | Multiple concurrent modes appear during cutover | Exactly one mode appears across serving replicas for each rollout phase |

## 7) Operational checklist

### Scaling / HA

- Run Redis with one primary plus at least one replica; prefer a managed Redis with automatic failover.
- Keep the app stateless beyond Redis so executor replicas can scale horizontally.
- Set a client-side timeout budget and surface Redis errors as retryable upstream failures, not silent bypasses.

### Backup / restore

- Use AOF (`appendfsync everysec`) or managed equivalent.
- Treat restored dedupe state older than 24 hours as invalid; if snapshot age is unknown, clear `gha:idem:v2:*` during disaster recovery to avoid resurrecting stale replay decisions.

### Security

- Redis TLS in transit, ACL-authenticated clients, encryption at rest on disks or managed service volumes.
- Store Redis credentials in the existing secret-management path; rotate credentials without changing Request Contract v1.

### Rotation

- Support Redis password rotation with dual credentials or rolling restarts.
- Document Redis endpoint and credential rotation separately from GitHub App private-key rotation; they are operationally independent.

### Monitoring / alerting

- `github_app_idem_replay_hits_total`
- `github_app_idem_first_writes_total`
- `github_app_idem_payload_mismatch_total`
- `github_app_idem_claim_contention_total`
- `github_app_idem_store_errors_total`
- `github_app_idem_redis_roundtrip_seconds`
- `github_app_idem_result_ttl_seconds` (sampled)

**Alerts**

- Redis unavailable for 5 minutes
- Replay-hit rate drops to near-zero during known retry traffic
- Store error rate > 1% for 10 minutes
- Claim contention spike above normal baseline

## 8) Minimal implementation slices / tasks

### Slice 1 — Introduce store boundary and red tests

- **Owner:** Backend
- **Estimate:** 2 hours
- **Files:** `services/github_app_executor/app/main.py`, `services/github_app_executor/app/services.py` or new `services/github_app_executor/app/idempotency.py`, `tests/conftest.py`, `tests/integration/test_m2_idempotency_retention.py`
- **Acceptance criteria:** failing M2 tests exist first, including deterministic race and TTL invariants; app can be configured for memory or Redis without changing the external API; canonical scope/payload helpers are defined once and reused everywhere.

### Slice 2 — Implement Redis result store and claim lock

- **Owner:** Backend
- **Estimate:** 4 hours
- **Files:** `services/github_app_executor/app/idempotency.py`, `pyproject.toml`, `services/github_app_executor/app/main.py`
- **Acceptance criteria:** replay within 24 hours works after restart and across two replicas; payload mismatch returns `409 DUPLICATE_PAYLOAD_MISMATCH`; Lua finalize writes result+TTL atomically; claim release uses tokenized compare-and-delete instead of plain delete.

### Slice 3 — Migration flags, rollout docs, and staging verification

- **Owner:** Backend + Platform
- **Estimate:** 3 hours
- **Files:** `services/github_app_executor/README.md`, `docs/runbooks/github-app-executor.md`, deploy manifests/config files for Redis settings
- **Acceptance criteria:** documented dual-write rollout, cluster-wide switch or temporary dual-read safety rules, rollback steps, and exact staging verification commands from this plan.

### Slice 4 — Metrics, alerts, and operational hardening

- **Owner:** Platform / SRE
- **Estimate:** 2 hours
- **Files:** metrics module, dashboards/alerts, runbook docs
- **Acceptance criteria:** metrics emitted, alerts defined, and Redis HA/backup/restore guidance committed.

**Total estimate:** 11 hours

## 9) M2 acceptance criteria

- Redis is the selected durable dedupe backend for M2, with the Postgres path documented only as fallback.
- Request Contract v1 request and response envelopes remain externally unchanged.
- Dedupe scope remains `(workload_identity, repo, action, idempotency_key)`.
- Replay records survive executor restart and are reusable from a different executor replica for at least 24 hours.
- Same-scope, different-payload replays return `409 DUPLICATE_PAYLOAD_MISMATCH` within the 24-hour retention window.
- Redis TTL is set from first successful write and is not extended by replay hits.
- Result write + TTL assignment is atomic, and claim release is token-safe against stale-owner deletes.
- Redis keys are built from canonicalized scope digests so equivalent repo/action inputs map to one dedupe record.
- Migration supports near-zero downtime via abstraction-first rollout plus dual-write warm-up before a cluster-wide Redis switch or all-replica temporary dual-read window.
- Runbooks, metrics, and alerts are committed alongside the backend change.

## 10) Remaining open questions

1. If the same dedupe scope and payload arrives with a **different** `request_id`, should M2 replay the prior result or reject it as a caller bug?
2. What is the acceptable loser-wait budget for claim contention: short poll and return cached result, or wait up to the full upstream timeout?
3. Is a managed Redis with TLS, ACLs, and encrypted persistence already available in the target cluster, or must it be introduced in the same delivery window?
4. Should durable `/v1/status/{request_id}` be in scope for M2, or is process-local status acceptable while only dedupe becomes durable?
