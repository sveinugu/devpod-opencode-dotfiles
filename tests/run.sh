#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash tests/run.sh <host|pod-outside-nono|pod-inside-nono>

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
      tests/host/test_setup_host_bare_hub.sh
      tests/host/test_verify_host_bare_hub.sh
      tests/host/test_workspace_provision.sh
      tests/host/test_workspace_repair.sh
      tests/host/test_devspace_provision_branch_default.sh
      tests/host/test_devspace_destroy.sh
      tests/host/test_devspace_dev_preflight.sh
      tests/host/test_devspace_doctor.sh
      tests/host/test_resolve_git_identity.sh
      tests/host/test_ssh_contract.sh
      tests/host/test_dockerfile_opencode_helper_contract.sh
    )
    run_test_list "${tests[@]}"
    ;;
  pod-outside-nono)
    tests=(
      tests/pod-outside-nono/test_nono_blocking_matrix_contract.sh
      tests/pod-outside-nono/test_nono_proxy_toy_contract.sh
      tests/pod-outside-nono/test_nono_secret_helper_contract.sh
      tests/pod-outside-nono/test_workspace_navigation_shell.sh
      tests/pod-outside-nono/test_create_hub_repo.sh
      tests/pod-outside-nono/test_public_repo_clone_behavior_ux.sh
      tests/pod-outside-nono/test_workspace_navigation_commands.sh
      tests/pod-outside-nono/test_workspace_navigation_helper_contracts.sh
      tests/pod-outside-nono/test_workspace_navigation_path_contract.sh
      tests/pod-outside-nono/test_install_local_source_contract.sh
      tests/pod-outside-nono/test_project_local_skills_contract.sh
      tests/pod-outside-nono/test_harness_installs_contract.sh
      tests/pod-outside-nono/test_generated_output_ignore_contract.sh
      tests/pod-outside-nono/test_cleanup_conformance_contract.sh
      tests/pod-outside-nono/test_install_oh_my_zsh_failure_surface.sh
      tests/pod-outside-nono/test_install_validate_source.sh
      tests/pod-outside-nono/test_workspace_navigation_install_env_refresh.sh
    )
    run_test_list "${tests[@]}"
    ;;
  pod-inside-nono)
    tests=(
      tests/pod-inside-nono/test_devspace_enablement_manifest_contract.sh
      tests/pod-inside-nono/test_maestro_intent_preservation_policy.sh
      tests/pod-inside-nono/test_p1_docs_orientation.sh
      tests/pod-inside-nono/test_clean_code_policy_contract.sh
      tests/pod-inside-nono/test_multi_question_interaction_policy.sh
      tests/pod-inside-nono/test_devspace_credential_phasing_security_contract.sh
      tests/pod-inside-nono/test_devspace_full_plan_consistency.sh
      tests/pod-inside-nono/test_delegation_packet_policy_contract.sh
      tests/pod-inside-nono/test_repo_documentation_refactor_audit.sh
      tests/pod-inside-nono/test_p2_runbook_consolidation.sh
      tests/pod-inside-nono/test_nono_policy_runbook_contract.sh
      tests/pod-inside-nono/test_managed_worktree_lane_safety_policy.sh
      tests/pod-inside-nono/test_devspace_credential_phasing_identity_separation_contract.sh
      tests/pod-inside-nono/test_workspace_manifest_contract.sh
      tests/pod-inside-nono/test_workspace_preinstalled_tools_contract.sh
      tests/pod-inside-nono/test_devspace_command_surface.sh
      tests/pod-inside-nono/test_opencode_provider_policy_contract.sh
      tests/pod-inside-nono/test_workspace_navigation_helper_layout.sh
      tests/pod-inside-nono/test_managed_lane_registry_contracts.sh
      tests/pod-inside-nono/test_managed_lane_registry_layout.sh
      tests/pod-inside-nono/test_opencode_runtime_contract_alignment.sh
      tests/pod-inside-nono/test_opencode_path_resolution_contract.sh
      tests/pod-inside-nono/test_openai_compatible_fix_plugin_contract.sh
      tests/pod-inside-nono/test_openai_compatible_fix_plugin_runtime_guard.sh
      tests/pod-inside-nono/test_nono_profile_layout.sh
      tests/pod-inside-nono/test_nono_identity_integration_contract.sh
      tests/pod-inside-nono/test_nono_secret_boundary_contract.sh
      tests/pod-inside-nono/test_opencode_secure_wrapper_contract.sh
      tests/pod-inside-nono/test_provider_enablement_sync_contract.sh
      tests/pod-inside-nono/test_new_worktree.sh
      tests/pod-inside-nono/test_retire_worktree.sh
      tests/pod-inside-nono/test_managed_lane_registry.sh
      tests/pod-inside-nono/test_public_repo_clone_behavior_core.sh
      tests/pod-inside-nono/test_bare_hub_guardrails.sh
      tests/pod-inside-nono/test_cleanup_round_contracts.sh
      tests/pod-inside-nono/test_provision_hub_repo_core_tar_contract.sh
      tests/pod-inside-nono/test_resolve_install_target.sh
      tests/pod-inside-nono/test_worktree_refactor_layout.sh
      tests/pod-inside-nono/test_install_helper_layout.sh
      tests/pod-inside-nono/test_read_install_env.sh
    )
    run_test_list "${tests[@]}"
    ;;
  *)
    printf 'Unknown context: %s\n' "$context" >&2
    usage
    exit 2
    ;;
esac
