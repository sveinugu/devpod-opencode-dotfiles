#!/usr/bin/env bash
#
# Contract test: openai-compatible-fix plugin layout and policy.
#
# Verifies that the plugin file exists in the expected location, is written in
# TypeScript (matching the existing opencode-loop.ts convention), exports the
# required symbol, and that the plugin is discoverable by OpenCode's local
# plugin loader.
#

set -euo pipefail

fail() {
  printf 'FAIL test_openai_compatible_fix_plugin_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_openai_compatible_fix_plugin_contract'

plugins_dir="$repo_root/.config/opencode/plugins"
plugin_file="$plugins_dir/openai-compatible-fix.ts"
opencode_cfg="$repo_root/.config/opencode/opencode.jsonc"

# --- File existence ----------------------------------------------------------
[ -f "$plugin_file" ] || fail "plugin file not found at $plugin_file"

# --- Format: TypeScript (.ts), not .js, matching existing convention ----------
# This repo's local plugins use .ts (opencode-loop.ts).
[[ "$plugin_file" == *.ts ]] || fail "plugin must be .ts, not .js (matches opencode-loop.ts convention)"

# --- Export symbol ------------------------------------------------------------
grep -q '^export const OpenAICompatibleFix' "$plugin_file" || fail "plugin must export OpenAICompatibleFix as named const"

# --- Default export (required by OpenCode plugin loader) ----------------------
grep -q '^export default OpenAICompatibleFix' "$plugin_file" || fail "plugin must have default export of OpenAICompatibleFix"

# --- chat.params hook is registered ------------------------------------------
grep -q '"chat.params"' "$plugin_file" || fail "plugin must register chat.params hook"

# --- Patches max_completion_tokens -------------------------------------------
grep -q 'max_completion_tokens' "$plugin_file" || fail "plugin must set max_completion_tokens in output.options"

# --- Removes max_tokens ------------------------------------------------------
grep -q 'delete .*max_tokens' "$plugin_file" || fail "plugin must delete max_tokens from output/options"

# --- Removes reasoningSummary ------------------------------------------------
grep -q 'delete .*reasoningSummary' "$plugin_file" || fail "plugin must delete reasoningSummary from output/options"

# --- Covers known reasoning model prefixes -----------------------------------
for prefix in "gpt-5" "o1" "o3" "o4"; do
  grep -F "$prefix" "$plugin_file" >/dev/null || fail "plugin must cover reasoning model prefix '$prefix'"
done

# --- Plugin must not be in opencode.jsonc's "plugin" array --------------------
# Local .ts plugins in plugins/ are auto-discovered; they do not belong in the
# npm/git-based plugin registry array.
if grep -q 'openai-compatible-fix' "$opencode_cfg"; then
  fail "local plugin must not appear in opencode.jsonc 'plugin' array (auto-discovered from plugins/)"
fi

printf 'PASS test_openai_compatible_fix_plugin_contract\n'
