# Phase 0 Tracer-Bullet POC: Workspace SA token → Broker → OPA → GitHub App action

This POC demonstrates the Phase 0 discovery flow from the spec (`docs/superpowers/specs/2026-05-20-github-app-integration-design.md`) with self-hosted/open-source components and **no dependency on github.com**.

The default execution path here is local simulation (all services run in-process), plus Kubernetes manifests for a cluster run.

## What this POC validates

1. Workspace pod style caller uses a projected ServiceAccount-like token (read from file).
2. Broker validates the workload token (TokenReview-like in demo, real TokenReview path in `broker_server.py`; optional JWKS-sim mode).
3. Broker calls OPA for allow/deny policy.
4. If allowed, broker mints a simulated GitHub App installation token and executes a GitHub comment action.
5. The GitHub API call is simulated by a local HTTP service (`github_sim_server.py`) and logs app identity/context.

## Directory layout

- `phase0_broker/demo_run.py` — self-contained runnable tracer bullet + local in-memory servers.
- `phase0_broker/broker_server.py` — standalone broker service for Kubernetes-style deployment.
- `phase0_broker/github_sim_server.py` — standalone local GitHub API simulator.
- `tests/test_broker_flow.py` — behavior tests (allow + deny).
- `k8s/phase0-poc.yaml` — namespace/service accounts/deployments/services/workspace pod/network policy.
- `k8s/rbac-tokenreview.yaml` — TokenReview RBAC for broker.
- `k8s/github-app-secret.example.yaml` — placeholder secret manifest.

## Local run (executed in this environment)

```bash
python3 -m unittest discover -s "poc/github-app-phase0/tests" -v
python3 "poc/github-app-phase0/run_demo.py"
python3 -c "from phase0_broker.demo_run import run_demo_once; import json; r=run_demo_once(persona='blocked-persona', token_path='/tmp/broker-token'); print(json.dumps(r['broker_response'], indent=2)); print('\n'.join(r['broker_logs'])); print('\n'.join(r['opa_logs'])); print('\n'.join(r['github_logs']) or 'NO_GITHUB_MUTATION_LOG')" \
  # run from poc/github-app-phase0
```

Expected:
- Test suite passes.
- Allow-path returns `status=ok` and simulated comment URL.
- Deny-path returns `POLICY_DENY` and no simulated GitHub mutation log.

## Kubernetes run (prepared artifacts)

> NOTE: these commands are prepared but not executed in this environment (no cluster access).

Set vars:

```bash
export NAMESPACE=github-app-poc
export WORKSPACE_SERVICEACCOUNT=workspace-agent
export BROKER_SERVICEACCOUNT=github-broker
export BROKER_IMAGE=python:3.12-slim
export OPA_IMAGE=openpolicyagent/opa:0.66.0
export GITHUB_APP_SECRET_NAME=github-app-key
```

Render and apply:

```bash
envsubst < poc/github-app-phase0/k8s/github-app-secret.example.yaml | kubectl apply -f -
envsubst < poc/github-app-phase0/k8s/phase0-poc.yaml | kubectl apply -f -
envsubst < poc/github-app-phase0/k8s/rbac-tokenreview.yaml | kubectl apply -f -
```

Copy code into broker/github-sim image (example approach):

1. Build a small image containing `phase0_broker/*`.
2. Push to an internal registry.
3. Set `BROKER_IMAGE` to that image before apply.

Trigger request from workspace pod:

```bash
kubectl -n "$NAMESPACE" exec workspace-agent -- python3 - <<'PY'
import json
from urllib import request

with open('/var/run/secrets/opencode/broker-token', 'r', encoding='utf-8') as fp:
    token = fp.read().strip()

payload = {
  'request_id': 'req-phase0-k8s-1',
  'repo': 'octo-org/demo-repo',
  'action': 'comment-pr',
  'persona': 'reviewer',
  'idempotency_key': 'idem-phase0-k8s-1',
  'payload': {'pr_number': 42, 'body': 'Kubernetes tracer bullet.'}
}

req = request.Request(
  'http://broker:8080/actions/comment-pr',
  data=json.dumps(payload).encode('utf-8'),
  headers={'Content-Type':'application/json','Authorization':f'Bearer {token}'},
  method='POST'
)
print(request.urlopen(req, timeout=10).read().decode('utf-8'))
PY
```

Collect evidence:

```bash
kubectl -n "$NAMESPACE" logs deploy/broker -c broker
kubectl -n "$NAMESPACE" logs deploy/broker -c opa
kubectl -n "$NAMESPACE" logs deploy/github-sim
```

NetworkPolicy verification (workspace direct egress deny intent):

```bash
kubectl -n "$NAMESPACE" exec workspace-agent -- sh -lc "wget -qO- --timeout=5 http://github-sim:8082/ || true"
# In strict CNI, direct non-allowed egress should fail except allowed broker/dns destinations.
```

## Notes on token validation modes in `broker_server.py`

- `TOKEN_VALIDATION_MODE=tokenreview` (preferred): broker calls Kubernetes TokenReview API.
- `TOKEN_VALIDATION_MODE=jwks-sim`: demo-only HS256 verification (placeholder for real JWKS validation path).

## Security constraints

- All components are open-source/self-hosted.
- No real GitHub calls are required.
- Broker is the sole holder of GitHub App key material in this model.
- Workspace receives structured result, not reusable GitHub installation token.
