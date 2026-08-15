#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash tests/context/run.sh <host|pod-outside-nono|pod-inside-nono>

Runs bash contract tests by execution context.
EOF
}

context="${1:-}"
if [ -z "$context" ]; then
  usage
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

run_test_list() {
  local tests=("$@")
  local total="${#tests[@]}"
  local passed=0
  local failed=0

  for t in "${tests[@]}"; do
    if bash "$t"; then
      printf 'PASS %s\n' "$t"
      passed=$((passed + 1))
    else
      printf 'FAIL %s\n' "$t" >&2
      failed=$((failed + 1))
    fi
  done

  printf 'Summary: total=%s passed=%s failed=%s\n' "$total" "$passed" "$failed"
  [ "$failed" -eq 0 ]
}

case "$context" in
  host)
    tests=(
      tests/bootstrap/test_setup_host_bare_hub.sh
      tests/bootstrap/test_verify_host_bare_hub.sh
      tests/devspace/test_workspace_provision.sh
      tests/devspace/test_workspace_repair.sh
      tests/devspace/test_devspace_provision_branch_default.sh
      tests/devspace/test_devspace_destroy.sh
      tests/devspace/test_devspace_dev_preflight.sh
      tests/devspace/test_devspace_doctor.sh
      tests/devspace/test_resolve_git_identity.sh
    )
    run_test_list "${tests[@]}"
    ;;
  pod-outside-nono)
    tests=(
      tests/devspace/test_nono_blocking_matrix_contract.sh
      tests/devspace/test_nono_proxy_toy_contract.sh
      tests/devspace/test_nono_secret_helper_contract.sh
      tests/install/test_workspace_navigation_shell.sh
      tests/context/pod-outside-nono/test_create_hub_repo.sh
      tests/context/pod-outside-nono/test_public_repo_clone_behavior_ux.sh
    )
    run_test_list "${tests[@]}"
    ;;
  pod-inside-nono)
    tests=(
      tests/devspace/test_nono_profile_layout.sh
      tests/devspace/test_nono_identity_integration_contract.sh
      tests/devspace/test_nono_secret_boundary_contract.sh
      tests/devspace/test_opencode_secure_wrapper_contract.sh
      tests/docs/test_nono_policy_runbook_contract.sh
      tests/devspace/test_workspace_manifest_contract.sh
      tests/devspace/test_workspace_preinstalled_tools_contract.sh
      tests/devspace/test_devspace_command_surface.sh
      tests/context/pod-inside-nono/test_new_worktree.sh
      tests/context/pod-inside-nono/test_retire_worktree.sh
      tests/context/pod-inside-nono/test_managed_lane_registry.sh
      tests/context/pod-inside-nono/test_public_repo_clone_behavior_core.sh
    )
    run_test_list "${tests[@]}"
    ;;
  *)
    printf 'Unknown context: %s\n' "$context" >&2
    usage
    exit 2
    ;;
esac
