# Test execution contexts

These bash contract tests do **not** all run in the same environment.
Use the context runner instead of ad-hoc “run everything” invocations.

## Contexts

- `host` — run on host shell, outside workspace sandboxing and outside nono.
- `pod-outside-nono` — run inside workspace/pod shell, but outside nono sandbox.
- `pod-inside-nono` — run from sandboxed agent session (inside nono).

## Run commands

```bash
bash tests/run.sh host
bash tests/run.sh pod-outside-nono
bash tests/run.sh pod-inside-nono
```

## Notes

- Host-only bootstrap tests fail fast with a clear message if run inside nono.
- `pod-outside-nono/test_nono_blocking_matrix_contract.sh` fails fast when run inside nono by design.
- Wrapper-specific behavior remains covered in dedicated wrapper tests (`test_opencode_secure_wrapper_contract.sh`, `test_nono_identity_integration_contract.sh`).

- `host/test_resolve_git_identity.sh` remains host-context because it validates interactive global git identity prompts using pseudo-TTY flows and isolated HOME state.
- Host context falls back to `/tmp` when `TEMP`, `TMP`, and `TMPDIR` are all unset.

## Moved tests in phase-2 context split

- `pod-inside-nono`
  - `pod-inside-nono/test_new_worktree.sh`
  - `pod-inside-nono/test_retire_worktree.sh`
  - `pod-inside-nono/test_managed_lane_registry.sh`
  - `pod-inside-nono/test_public_repo_clone_behavior_core.sh`
  - `pod-inside-nono/test_devspace_enablement_manifest_contract.sh`
  - `pod-inside-nono/test_maestro_intent_preservation_policy.sh`
  - `pod-inside-nono/test_p1_docs_orientation.sh`
  - `pod-inside-nono/test_clean_code_policy_contract.sh`
  - `pod-inside-nono/test_multi_question_interaction_policy.sh`
  - `pod-inside-nono/test_devspace_credential_phasing_security_contract.sh`
  - `pod-inside-nono/test_devspace_full_plan_consistency.sh`
  - `pod-inside-nono/test_delegation_packet_policy_contract.sh`
  - `pod-inside-nono/test_repo_documentation_refactor_audit.sh`
  - `pod-inside-nono/test_p2_runbook_consolidation.sh`
  - `pod-inside-nono/test_nono_policy_runbook_contract.sh`
  - `pod-inside-nono/test_managed_worktree_lane_safety_policy.sh`
  - `pod-inside-nono/test_devspace_credential_phasing_identity_separation_contract.sh`
  - `pod-inside-nono/test_workspace_manifest_contract.sh`
  - `pod-inside-nono/test_workspace_preinstalled_tools_contract.sh`
  - `pod-inside-nono/test_devspace_command_surface.sh`
  - `pod-inside-nono/test_opencode_provider_policy_contract.sh`
  - `pod-inside-nono/test_workspace_navigation_helper_layout.sh`
  - `pod-inside-nono/test_managed_lane_registry_contracts.sh`
  - `pod-inside-nono/test_managed_lane_registry_layout.sh`
  - `pod-inside-nono/test_opencode_runtime_contract_alignment.sh`
  - `pod-inside-nono/test_opencode_path_resolution_contract.sh`
  - `pod-inside-nono/test_openai_compatible_fix_plugin_contract.sh`
  - `pod-inside-nono/test_openai_compatible_fix_plugin_runtime_guard.sh`
  - `pod-inside-nono/test_nono_profile_layout.sh`
  - `pod-inside-nono/test_nono_identity_integration_contract.sh`
  - `pod-inside-nono/test_nono_secret_boundary_contract.sh`
  - `pod-inside-nono/test_opencode_secure_wrapper_contract.sh`
  - `pod-inside-nono/test_provider_enablement_sync_contract.sh`
  - `pod-inside-nono/test_bare_hub_guardrails.sh`
  - `pod-inside-nono/test_cleanup_round_contracts.sh`
  - `pod-inside-nono/test_provision_hub_repo_core_tar_contract.sh`
  - `pod-inside-nono/test_resolve_install_target.sh`
  - `pod-inside-nono/test_worktree_refactor_layout.sh`
  - `pod-inside-nono/test_install_helper_layout.sh`
  - `pod-inside-nono/test_read_install_env.sh`
- `pod-outside-nono`
  - `pod-outside-nono/test_nono_blocking_matrix_contract.sh`
  - `pod-outside-nono/test_nono_proxy_toy_contract.sh`
  - `pod-outside-nono/test_nono_secret_helper_contract.sh`
  - `pod-outside-nono/test_workspace_navigation_shell.sh`
  - `pod-outside-nono/test_create_hub_repo.sh`
  - `pod-outside-nono/test_public_repo_clone_behavior_ux.sh`
  - `pod-outside-nono/test_workspace_navigation_commands.sh`
  - `pod-outside-nono/test_workspace_navigation_helper_contracts.sh`
  - `pod-outside-nono/test_workspace_navigation_path_contract.sh`
  - `pod-outside-nono/test_install_local_source_contract.sh`
  - `pod-outside-nono/test_install_oh_my_zsh_failure_surface.sh`
  - `pod-outside-nono/test_install_validate_source.sh`
  - `pod-outside-nono/test_workspace_navigation_install_env_refresh.sh`
- `host`
  - `host/test_setup_host_bare_hub.sh`
  - `host/test_verify_host_bare_hub.sh`
  - `host/test_workspace_provision.sh`
  - `host/test_workspace_repair.sh`
  - `host/test_devspace_provision_branch_default.sh`
  - `host/test_devspace_destroy.sh`
  - `host/test_devspace_dev_preflight.sh`
  - `host/test_devspace_doctor.sh`
  - `host/test_resolve_git_identity.sh`
  - `host/test_ssh_contract.sh`

Current canonical paths are the context files above; callers should invoke those paths (or `run.sh`) directly.
