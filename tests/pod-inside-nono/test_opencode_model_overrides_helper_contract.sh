#!/usr/bin/env bash
set -euo pipefail

# Contract for scripts/lib/opencode-config-content.py: builds the
# OPENCODE_CONFIG_CONTENT payload from the generated provider runtime plus the
# host-local model overrides file. Uses fixture files only; no OpenCode launch.

fail() {
  printf 'FAIL test_opencode_model_overrides_helper_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_opencode_model_overrides_helper_contract'

helper="$repo_root/scripts/lib/opencode-config-content.py"
[ -f "$helper" ] || fail "config content helper must exist at scripts/lib/opencode-config-content.py"

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_opencode_model_overrides_helper_contract')"
tmp_root="$(context_make_test_tmpdir "$temp_root" 'test_opencode_model_overrides_helper_contract')"
trap 'rm -rf "$tmp_root"' EXIT

runtime="$tmp_root/provider-runtime.json"
agents_dir="$tmp_root/agents"
mkdir -p "$agents_dir"
printf -- '---\nmodel: gpt-uio-yellow/gpt-6.1-terra\n---\n' >"$agents_dir/maestro.md"
printf -- '---\nmodel: github-copilot/claude-opus-5.5\n---\n' >"$agents_dir/planner.md"
mkdir -p "$agents_dir/phantom.md"

cat >"$runtime" <<'JSON'
{
  "enabled_providers": ["gpt-uio-yellow", "github-copilot"],
  "provider": {
    "gpt-uio-yellow": {
      "api": "openai",
      "models": {
        "Inferact/GLM-5.3-NVFP4": { "id": "Inferact/GLM-5.3-NVFP4", "name": "GLM 5.3" },
        "Qwen/Qwen3.8-27B-FP8": { "id": "Qwen/Qwen3.8-27B-FP8", "name": "Qwen 3.8" }
      }
    }
  }
}
JSON

run_helper() {
  local overrides="$1"
  python3 "$helper" --runtime "$runtime" --overrides "$overrides" --agents-dir "$agents_dir" --today 2026-11-19 \
    >"$tmp_root/out.json" 2>"$tmp_root/err.txt"
}

# Missing overrides file: provider block passes through unchanged.
run_helper "$tmp_root/does-not-exist.json" || fail "missing overrides file must not refuse launch"
python3 - "$runtime" "$tmp_root/out.json" <<'PY' || fail "missing overrides file must emit the provider block unchanged"
import json, sys
runtime = json.load(open(sys.argv[1]))
out = json.load(open(sys.argv[2]))
assert out == {'enabled_providers': runtime['enabled_providers'], 'provider': runtime['provider']}, out
PY
[ ! -s "$tmp_root/err.txt" ] || fail "missing overrides file must not print notices"

# Active overrides for a custom agent, a built-in agent and a default; one expired entry.
cat >"$tmp_root/valid.json" <<'JSON'
{
  "agents": {
    "maestro": { "model": "github-copilot/gpt-6.1-terra", "reason": "UiO terra\n  depleted", "until": "2026-12-01" },
    "compaction": { "model": "gpt-uio-yellow/Qwen/Qwen3.8-27B-FP8", "reason": "GLM depleted" },
    "planner": { "model": "github-copilot/gpt-6.2-sol", "reason": "old switch", "until": "2026-11-19" }
  },
  "defaults": {
    "small_model": { "model": "gpt-uio-yellow/Inferact/GLM-5.3-NVFP4", "reason": "Gemma depleted" }
  }
}
JSON
run_helper "$tmp_root/valid.json" || fail "valid overrides must not refuse launch: $(cat "$tmp_root/err.txt")"
python3 - "$runtime" "$tmp_root/out.json" <<'PY' || fail "active overrides must be merged and nothing else added"
import json, sys
runtime = json.load(open(sys.argv[1]))
out = json.load(open(sys.argv[2]))
assert set(out) == {'enabled_providers', 'provider', 'agent', 'small_model'}, set(out)
assert out['provider'] == runtime['provider']
assert out['agent'] == {
    'maestro': {'model': 'github-copilot/gpt-6.1-terra'},
    'compaction': {'model': 'gpt-uio-yellow/Qwen/Qwen3.8-27B-FP8'},
}, out['agent']
assert out['small_model'] == 'gpt-uio-yellow/Inferact/GLM-5.3-NVFP4'
PY
grep -F 'model override: maestro -> github-copilot/gpt-6.1-terra (UiO terra depleted; until 2026-12-01)' "$tmp_root/err.txt" >/dev/null || fail "active agent override must be announced on stderr"
grep -F 'model override: small_model -> gpt-uio-yellow/Inferact/GLM-5.3-NVFP4 (Gemma depleted)' "$tmp_root/err.txt" >/dev/null || fail "active default override must be announced on stderr"
grep -F 'warning: model override for planner expired on 2026-11-19; ignored' "$tmp_root/err.txt" >/dev/null || fail "expired override must be ignored with a warning"

# Each invalid file is refused with a message naming the problem.
expect_refusal() {
  local name="$1" json="$2" message="$3"
  printf '%s\n' "$json" >"$tmp_root/$name.json"
  if run_helper "$tmp_root/$name.json"; then
    fail "$name: invalid overrides must refuse launch"
  fi
  grep -F "refused: model overrides $tmp_root/$name.json: $message" "$tmp_root/err.txt" >/dev/null || fail "$name: expected refusal '$message', got: $(cat "$tmp_root/err.txt")"
}

expect_refusal invalid-json '{ not json' 'not valid JSON'
expect_refusal top-level-key '{ "agents": {}, "extra": {} }' 'unknown top-level key: extra'
expect_refusal agents-type '{ "agents": [] }' 'agents must be an object'
expect_refusal unknown-default '{ "defaults": { "large_model": { "model": "github-copilot/gpt-6.1-terra", "reason": "x" } } }' 'unknown default: large_model'
expect_refusal missing-reason '{ "agents": { "maestro": { "model": "github-copilot/gpt-6.1-terra" } } }' 'agents.maestro: missing reason'
expect_refusal unknown-entry-key '{ "agents": { "maestro": { "model": "github-copilot/gpt-6.1-terra", "reason": "x", "note": "y" } } }' 'agents.maestro: unknown key: note'
expect_refusal bad-until '{ "agents": { "maestro": { "model": "github-copilot/gpt-6.1-terra", "reason": "x", "until": "1 Dec" } } }' 'agents.maestro: until must be YYYY-MM-DD'

expect_refusal null-until '{ "agents": { "maestro": { "model": "github-copilot/gpt-6.1-terra", "reason": "x", "until": null } } }' 'agents.maestro: until must be YYYY-MM-DD'
expect_refusal blank-model-id '{ "agents": { "maestro": { "model": "github-copilot/ ", "reason": "x" } } }' 'agents.maestro: model must be a literal provider/model id'
expect_refusal placeholder-model '{ "agents": { "maestro": { "model": "github-copilot/{env:MODEL}", "reason": "x" } } }' 'agents.maestro: model must be a literal provider/model id'
expect_refusal trailing-newline-model '{ "agents": { "maestro": { "model": "github-copilot/gpt-6.1-terra\n", "reason": "x" } } }' 'agents.maestro: model must be a literal provider/model id'
expect_refusal duplicate-key '{ "agents": { "maestro": { "model": "openai/gpt-6.1-terra", "model": "github-copilot/gpt-6.1-terra", "reason": "x" } } }' 'duplicate key: model'

# The file is shared by all checkouts: a valid entry that this checkout cannot
# apply is skipped with a warning, and the other entries still apply.
expect_skip() {
  local name="$1" json="$2" message="$3"
  printf '%s\n' "$json" >"$tmp_root/$name.json"
  run_helper "$tmp_root/$name.json" || fail "$name: an entry this checkout cannot apply must not refuse launch: $(cat "$tmp_root/err.txt")"
  grep -F "warning: model override $message" "$tmp_root/err.txt" >/dev/null || fail "$name: expected warning '$message', got: $(cat "$tmp_root/err.txt")"
  python3 - "$tmp_root/out.json" <<'PY' || fail "$name: the skipped entry must not be applied and the valid one must"
import json, sys
out = json.load(open(sys.argv[1]))
assert out.get('agent') == {'planner': {'model': 'github-copilot/gpt-6.2-sol'}}, out.get('agent')
assert 'small_model' not in out, out
PY
}

valid_planner='"planner": { "model": "github-copilot/gpt-6.2-sol", "reason": "kept" }'
expect_skip unknown-agent "{ \"agents\": { \"maestr\": { \"model\": \"github-copilot/gpt-6.1-terra\", \"reason\": \"x\" }, $valid_planner } }" 'agents.maestr skipped on this checkout: unknown agent: maestr'
expect_skip directory-agent "{ \"agents\": { \"phantom\": { \"model\": \"github-copilot/gpt-6.1-terra\", \"reason\": \"x\" }, $valid_planner } }" 'agents.phantom skipped on this checkout: unknown agent: phantom'
expect_skip provider-disabled "{ \"agents\": { \"maestro\": { \"model\": \"openai/gpt-6.1-terra\", \"reason\": \"x\" }, $valid_planner } }" 'agents.maestro skipped on this checkout: provider not enabled: openai'
expect_skip model-unlisted "{ \"agents\": { \"maestro\": { \"model\": \"gpt-uio-yellow/gpt-6.1-terra\", \"reason\": \"x\" }, $valid_planner } }" 'agents.maestro skipped on this checkout: model not listed for gpt-uio-yellow: gpt-6.1-terra'
expect_skip default-unlisted "{ \"agents\": { $valid_planner }, \"defaults\": { \"small_model\": { \"model\": \"anthropic/claude\", \"reason\": \"x\" } } }" 'defaults.small_model skipped on this checkout: provider not enabled: anthropic'

printf 'PASS test_opencode_model_overrides_helper_contract\n'
