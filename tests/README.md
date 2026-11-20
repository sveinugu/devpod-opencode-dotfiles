# Test execution contexts

Each test has a required execution context. Use the context runner instead of ad-hoc “run everything” invocations.

## Contexts

- `static` — read-only repository metadata and configuration checks; runnable on host or pod without runtime setup.

- `host` — run on host shell, outside workspace sandboxing and outside nono.
- `pod-outside-nono` — run inside workspace/pod shell, but outside nono sandbox.
- `pod-inside-nono` — run from sandboxed agent session (inside nono).

## Run commands

```bash
bash tests/run.sh static
bash tests/run.sh host
bash tests/run.sh pod-outside-nono
bash tests/run.sh pod-inside-nono
```

## Notes

- Host-only bootstrap tests fail fast with a clear message if run inside nono.
- `pod-outside-nono/test_nono_blocking_matrix_contract.sh` fails fast when run inside nono by design.
- Harness agents must not execute `pod-outside-nono` tests or commands as `vscode`. Ask the human to run them in their own outside-nono shell and return the output. Changing HOME/XDG, bypassing guards or running underlying commands directly does not authorize that execution context. See the canonical policy in `.config/opencode/AGENTS.md`.
- The Nono blocking matrix requires an installed, verified `nolabs-ai/opencode-v1` pack in the human's runtime. Pack installation and any needed ownership repairs are operator prerequisites. Tests do not perform these repairs.
- Wrapper-specific behavior remains covered in dedicated wrapper tests (`test_opencode_secure_wrapper_contract.sh`, `test_nono_identity_integration_contract.sh`).

- `host/test_resolve_git_identity.sh` remains host-context because it validates interactive global git identity prompts using pseudo-TTY flows and isolated HOME state.
- Host context falls back to `/tmp` when `TEMP`, `TMP`, and `TMPDIR` are all unset.

## What belongs in the suite

The testing policy is defined in [delivery-workflow](../.config/opencode/skills/delivery-workflow/SKILL.md#testing-scope).

Keep tests for meaningful executable behavior, runtime configuration and permissions. Preserve structural checks for machine-consumed metadata and required files. Pure repository checks belong in `static`. Tests that need a runtime retain their context guards. Use parsers for structured configuration where practical.

Policy and documentation prose normally need semantic review and relevant structural validation. Do not assert exact policy sentences, headings, Markdown rows or snapshots of prose. Do not keep recurring acceptance tests for historical plans, review records or completed documentation migrations. Validate links and executable examples when relevant. A wording match does not establish that an example works or an agent follows a rule.

For mixed tests, retain the behavioral/configuration checks and remove prose assertions. Historical plans and review records may name retired tests. Consult the current runner for executable commands. Do not rewrite historical evidence.

`tests/run.sh` is the authoritative suite list. The additional scripts in `tests/devspace/` are not included automatically. Runtime suites remain separate from `static`. Run each relevant suite explicitly.
