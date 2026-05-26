#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_resolve_git_identity: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
script_path="$repo_root/scripts/resolve-git-identity.sh"

[ -f "$script_path" ] || fail "scripts/resolve-git-identity.sh not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

run_interactive() {
  local input="$1"
  local output_path="$2"
  local command="$3"
  printf '%b' "$input" | script -q -e -c "$command" /dev/null >"$output_path"
}

extract_identity_assignments() {
  local output_path="$1"
  sed -n 's/.*\(HUB_GITHUB_USER_NAME=.*\)/\1/p' "$output_path"
  sed -n 's/.*\(HUB_GITHUB_USER_EMAIL=.*\)/\1/p' "$output_path"
}

home_env="$tmpdir/home-env"
mkdir -p "$home_env"

identity_env_output="$(
  HUB_GITHUB_USER_NAME='Env User' \
  HUB_GITHUB_USER_EMAIL='env@example.com' \
  HOME="$home_env" \
  bash "$script_path" --no-prompts
)"
eval "$identity_env_output"
[ "${HUB_GITHUB_USER_NAME:-}" = 'Env User' ] || fail "script should preserve HUB_GITHUB_USER_NAME override"
[ "${HUB_GITHUB_USER_EMAIL:-}" = 'env@example.com' ] || fail "script should preserve HUB_GITHUB_USER_EMAIL override"

home_global_complete="$tmpdir/home-global-complete"
mkdir -p "$home_global_complete"
HOME="$home_global_complete" git config --global user.name 'Global User'
HOME="$home_global_complete" git config --global user.email 'global@example.com'

run_interactive 'y\n' "$tmpdir/global-complete.out" \
  "env HOME=\"$home_global_complete\" bash \"$script_path\""
grep -F 'Using global git identity: Global User <global@example.com>' "$tmpdir/global-complete.out" >/dev/null || fail "accepting global config should print resolved global identity"
eval "$(extract_identity_assignments "$tmpdir/global-complete.out")"
HUB_GITHUB_USER_NAME="$(printf '%s' "${HUB_GITHUB_USER_NAME:-}" | tr -d '\r')"
HUB_GITHUB_USER_EMAIL="$(printf '%s' "${HUB_GITHUB_USER_EMAIL:-}" | tr -d '\r')"
[ "${HUB_GITHUB_USER_NAME:-}" = 'Global User' ] || fail "accepting global config should emit global user.name"
[ "${HUB_GITHUB_USER_EMAIL:-}" = 'global@example.com' ] || fail "accepting global config should emit global user.email"

home_global_missing="$tmpdir/home-global-missing"
mkdir -p "$home_global_missing"
HOME="$home_global_missing" git config --global user.name 'Global Name Only'

run_interactive 'y\nmissing@example.com\n' "$tmpdir/global-missing.out" \
  "env HOME=\"$home_global_missing\" bash \"$script_path\""
grep -F 'Using global git identity: Global Name Only <missing@example.com>' "$tmpdir/global-missing.out" >/dev/null || fail "global flow should print resolved identity after collecting missing fields"
eval "$(extract_identity_assignments "$tmpdir/global-missing.out")"
HUB_GITHUB_USER_NAME="$(printf '%s' "${HUB_GITHUB_USER_NAME:-}" | tr -d '\r')"
HUB_GITHUB_USER_EMAIL="$(printf '%s' "${HUB_GITHUB_USER_EMAIL:-}" | tr -d '\r')"
[ "${HUB_GITHUB_USER_NAME:-}" = 'Global Name Only' ] || fail "script should keep global user.name when prompting for missing email"
[ "${HUB_GITHUB_USER_EMAIL:-}" = 'missing@example.com' ] || fail "script should prompt for missing global email"

home_manual="$tmpdir/home-manual"
mkdir -p "$home_manual"

run_interactive 'n\ny\nManual User\nmanual@example.com\n' "$tmpdir/manual.out" \
  "env HOME=\"$home_manual\" bash \"$script_path\""
eval "$(extract_identity_assignments "$tmpdir/manual.out")"
HUB_GITHUB_USER_NAME="$(printf '%s' "${HUB_GITHUB_USER_NAME:-}" | tr -d '\r')"
HUB_GITHUB_USER_EMAIL="$(printf '%s' "${HUB_GITHUB_USER_EMAIL:-}" | tr -d '\r')"
[ "${HUB_GITHUB_USER_NAME:-}" = 'Manual User' ] || fail "manual fallback should emit entered user.name"
[ "${HUB_GITHUB_USER_EMAIL:-}" = 'manual@example.com' ] || fail "manual fallback should emit entered user.email"

run_interactive 'n\ny\nSubshell User\nsubshell@example.com\n' "$tmpdir/subshell.out" \
  "env HOME=\"$home_manual\" sh -lc \"identity_output=\\\$(bash '$script_path'); printf '%s\\n' \\\"\\\$identity_output\\\"\""
eval "$(extract_identity_assignments "$tmpdir/subshell.out")"
HUB_GITHUB_USER_NAME="$(printf '%s' "${HUB_GITHUB_USER_NAME:-}" | tr -d '\r')"
HUB_GITHUB_USER_EMAIL="$(printf '%s' "${HUB_GITHUB_USER_EMAIL:-}" | tr -d '\r')"
[ "${HUB_GITHUB_USER_NAME:-}" = 'Subshell User' ] || fail "interactive command substitution should still prompt for user.name"
[ "${HUB_GITHUB_USER_EMAIL:-}" = 'subshell@example.com' ] || fail "interactive command substitution should still prompt for user.email"

run_interactive 'n\ny\nTTY Prompt User\ntty-prompt@example.com\n' "$tmpdir/subshell-stderr.out" \
  "env HOME=\"$home_manual\" sh -lc \"identity_output=\\\$(bash '$script_path' 2>'$tmpdir/subshell.stderr'); printf '%s\\n' \\\"\\\$identity_output\\\"\""
eval "$(extract_identity_assignments "$tmpdir/subshell-stderr.out")"
HUB_GITHUB_USER_NAME="$(printf '%s' "${HUB_GITHUB_USER_NAME:-}" | tr -d '\r')"
HUB_GITHUB_USER_EMAIL="$(printf '%s' "${HUB_GITHUB_USER_EMAIL:-}" | tr -d '\r')"
[ "${HUB_GITHUB_USER_NAME:-}" = 'TTY Prompt User' ] || fail "interactive prompt via subshell should still collect user.name when stderr is redirected"
[ "${HUB_GITHUB_USER_EMAIL:-}" = 'tty-prompt@example.com' ] || fail "interactive prompt via subshell should still collect user.email when stderr is redirected"
[ ! -s "$tmpdir/subshell.stderr" ] || fail "interactive prompts should be written to tty instead of stderr"

run_interactive 'n\nn\n' "$tmpdir/skip.out" \
  "env HOME=\"$home_manual\" bash \"$script_path\""
if grep -Eq '^HUB_GITHUB_USER_(NAME|EMAIL)=' "$tmpdir/skip.out"; then
  fail "declining global and manual identity should emit no identity assignments"
fi

identity_no_prompts_output="$(HOME="$home_manual" bash "$script_path" --no-prompts)"
if [ -n "$identity_no_prompts_output" ]; then
  fail "--no-prompts without env overrides should emit no identity assignments"
fi

printf 'PASS test_resolve_git_identity\n'
