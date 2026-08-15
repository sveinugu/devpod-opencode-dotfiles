# Test execution contexts

These bash contract tests do **not** all run in the same environment.
Use the context runner instead of ad-hoc “run everything” invocations.

## Contexts

- `host` — run on host shell, outside workspace sandboxing and outside nono.
- `pod-outside-nono` — run inside workspace/pod shell, but outside nono sandbox.
- `pod-inside-nono` — run from sandboxed agent session (inside nono).

## Run commands

```bash
bash tests/context/run.sh host
bash tests/context/run.sh pod-outside-nono
bash tests/context/run.sh pod-inside-nono
```

## Notes

- Host-only bootstrap tests fail fast with a clear message if run inside nono.
- `tests/context/pod-outside-nono/test_nono_blocking_matrix_contract.sh` fails fast when run inside nono by design.
- Wrapper-specific behavior remains covered in dedicated wrapper tests (`test_opencode_secure_wrapper_contract.sh`, `test_nono_identity_integration_contract.sh`).

- `tests/devspace/test_resolve_git_identity.sh` remains host-context because it validates interactive global git identity prompts using pseudo-TTY flows and isolated HOME state.

## Moved tests in phase-2 context split

- `pod-inside-nono`
  - `tests/context/pod-inside-nono/test_new_worktree.sh`
  - `tests/context/pod-inside-nono/test_retire_worktree.sh`
  - `tests/context/pod-inside-nono/test_managed_lane_registry.sh`
  - `tests/context/pod-inside-nono/test_public_repo_clone_behavior_core.sh`
  - `tests/context/pod-inside-nono/test_devspace_enablement_manifest_contract.sh`
  - `tests/context/pod-inside-nono/test_maestro_intent_preservation_policy.sh`
  - `tests/context/pod-inside-nono/test_p1_docs_orientation.sh`
  - `tests/context/pod-inside-nono/test_clean_code_policy_contract.sh`
  - `tests/context/pod-inside-nono/test_multi_question_interaction_policy.sh`
  - `tests/context/pod-inside-nono/test_devspace_credential_phasing_security_contract.sh`
  - `tests/context/pod-inside-nono/test_devspace_full_plan_consistency.sh`
  - `tests/context/pod-inside-nono/test_delegation_packet_policy_contract.sh`
  - `tests/context/pod-inside-nono/test_repo_documentation_refactor_audit.sh`
  - `tests/context/pod-inside-nono/test_p2_runbook_consolidation.sh`
  - `tests/context/pod-inside-nono/test_nono_policy_runbook_contract.sh`
  - `tests/context/pod-inside-nono/test_managed_worktree_lane_safety_policy.sh`
  - `tests/context/pod-inside-nono/test_devspace_credential_phasing_identity_separation_contract.sh`
  - `tests/context/pod-inside-nono/test_workspace_manifest_contract.sh`
  - `tests/context/pod-inside-nono/test_workspace_preinstalled_tools_contract.sh`
  - `tests/context/pod-inside-nono/test_devspace_command_surface.sh`
  - `tests/context/pod-inside-nono/test_opencode_provider_policy_contract.sh`
  - `tests/context/pod-inside-nono/test_workspace_navigation_helper_layout.sh`
  - `tests/context/pod-inside-nono/test_managed_lane_registry_contracts.sh`
  - `tests/context/pod-inside-nono/test_managed_lane_registry_layout.sh`
  - `tests/context/pod-inside-nono/test_opencode_runtime_contract_alignment.sh`
  - `tests/context/pod-inside-nono/test_opencode_path_resolution_contract.sh`
  - `tests/context/pod-inside-nono/test_openai_compatible_fix_plugin_contract.sh`
  - `tests/context/pod-inside-nono/test_openai_compatible_fix_plugin_runtime_guard.sh`
  - `tests/context/pod-inside-nono/test_nono_profile_layout.sh`
  - `tests/context/pod-inside-nono/test_nono_identity_integration_contract.sh`
  - `tests/context/pod-inside-nono/test_nono_secret_boundary_contract.sh`
  - `tests/context/pod-inside-nono/test_opencode_secure_wrapper_contract.sh`
  - `tests/context/pod-inside-nono/test_provider_enablement_sync_contract.sh`
- `pod-outside-nono`
  - `tests/context/pod-outside-nono/test_nono_blocking_matrix_contract.sh`
  - `tests/context/pod-outside-nono/test_nono_proxy_toy_contract.sh`
  - `tests/context/pod-outside-nono/test_nono_secret_helper_contract.sh`
  - `tests/context/pod-outside-nono/test_workspace_navigation_shell.sh`
  - `tests/context/pod-outside-nono/test_create_hub_repo.sh`
  - `tests/context/pod-outside-nono/test_public_repo_clone_behavior_ux.sh`
- `host`
  - `tests/context/host/test_setup_host_bare_hub.sh`
  - `tests/context/host/test_verify_host_bare_hub.sh`

Current canonical paths are the context files above; callers should invoke those paths (or `tests/context/run.sh`) directly.
