#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_dockerfile_opencode_helper_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"

dockerfile="$repo_root/Dockerfile"
helper_script="$repo_root/scripts/lib/run-with-sudo-nono.sh"

[ -f "$dockerfile" ] || fail 'Dockerfile not found'
[ -f "$helper_script" ] || fail 'scripts/lib/run-with-sudo-nono.sh not found'

grep -F 'COPY scripts/lib/run-with-sudo-nono.sh /usr/local/libexec/dotfiles-run-helper' "$dockerfile" >/dev/null || fail 'Dockerfile must stage run-with-sudo-nono helper to /usr/local/libexec/dotfiles-run-helper'
grep -F 'chmod 0755 /usr/local/libexec/dotfiles-run-helper' "$dockerfile" >/dev/null || fail 'Dockerfile must mark helper executable'
grep -F 'exec sudo -n -u "$run_as_user" "$@"' "$helper_script" >/dev/null || fail 'run-with-sudo-nono helper must preserve explicit user-bound execution contract'

if grep -F '/usr/local/libexec/dotfiles-run-helper' "$repo_root/scripts/lib/install/materialize.sh" >/dev/null; then
  fail 'helper must remain preparatory and not become primary install materialization path'
fi

printf 'PASS test_dockerfile_opencode_helper_contract\n'
