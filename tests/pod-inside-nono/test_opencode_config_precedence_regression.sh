#!/usr/bin/env bash
set -euo pipefail

# Regression guard for the model overrides design: OPENCODE_CONFIG_CONTENT must
# win over markdown agent frontmatter, opencode.json agent entries and top-level
# defaults. Runs the real installed OpenCode binary against an isolated config
# directory (fixture agents only, --pure skips plugins). Rerun after every
# OpenCode upgrade.

fail() {
  printf 'FAIL test_opencode_config_precedence_regression: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_opencode_config_precedence_regression'

raw_opencode="${OPENCODE_RAW_BINARY:-/usr/local/bin/opencode-raw}"
[ -x "$raw_opencode" ] || fail "raw opencode binary not executable at $raw_opencode"

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_opencode_config_precedence_regression')"
tmp_root="$(context_make_test_tmpdir "$temp_root" 'test_opencode_config_precedence_regression')"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$tmp_root/config/opencode/agents" "$tmp_root/data" "$tmp_root/state" "$tmp_root/cache"
printf -- '---\ndescription: Fixture custom agent.\nmode: subagent\nmodel: gpt-uio-yellow/gpt-6.1-terra\n---\n\nFixture.\n' \
  >"$tmp_root/config/opencode/agents/fixture-agent.md"
cat >"$tmp_root/config/opencode/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "gpt-uio-yellow/Inferact/GLM-5.3-NVFP4",
  "small_model": "gpt-uio-yellow/google/gemma-4-31B-it",
  "agent": { "compaction": { "model": "gpt-uio-yellow/Inferact/GLM-5.3-NVFP4" } }
}
JSON

run_opencode() {
  (cd "$tmp_root" && XDG_CONFIG_HOME="$tmp_root/config" XDG_DATA_HOME="$tmp_root/data" \
    XDG_STATE_HOME="$tmp_root/state" XDG_CACHE_HOME="$tmp_root/cache" \
    timeout 120 "$raw_opencode" "$@" --pure)
}

agent_model() {
  python3 -c '
import json, sys
text = sys.stdin.read()
data = json.loads(text[text.index("{"):])
m = data["model"]
print(m["providerID"] + "/" + m["modelID"])
'
}

config_value() {
  python3 -c '
import json, sys
text = sys.stdin.read()
print(json.loads(text[text.index("{"):]).get(sys.argv[1]))
' "$1"
}

overrides='{"agent":{"fixture-agent":{"model":"github-copilot/claude-haiku-5.5"},"compaction":{"model":"github-copilot/claude-haiku-5.5"}},"model":"github-copilot/claude-sonnet-5.5","small_model":"github-copilot/gpt-6-luna"}'

[ "$(run_opencode debug agent fixture-agent | agent_model)" = "gpt-uio-yellow/gpt-6.1-terra" ] || fail "baseline: custom agent should use its frontmatter model"
[ "$(run_opencode debug agent compaction | agent_model)" = "gpt-uio-yellow/Inferact/GLM-5.3-NVFP4" ] || fail "baseline: built-in agent should use its opencode.json model"

[ "$(OPENCODE_CONFIG_CONTENT="$overrides" run_opencode debug agent fixture-agent | agent_model)" = "github-copilot/claude-haiku-5.5" ] || fail "OPENCODE_CONFIG_CONTENT must override markdown agent frontmatter"
[ "$(OPENCODE_CONFIG_CONTENT="$overrides" run_opencode debug agent compaction | agent_model)" = "github-copilot/claude-haiku-5.5" ] || fail "OPENCODE_CONFIG_CONTENT must override built-in agent model from opencode.json"
config_out="$(OPENCODE_CONFIG_CONTENT="$overrides" run_opencode debug config)"
[ "$(config_value model <<<"$config_out")" = "github-copilot/claude-sonnet-5.5" ] || fail "OPENCODE_CONFIG_CONTENT must override top-level model"
[ "$(config_value small_model <<<"$config_out")" = "github-copilot/gpt-6-luna" ] || fail "OPENCODE_CONFIG_CONTENT must override top-level small_model"

printf 'PASS test_opencode_config_precedence_regression\n'
