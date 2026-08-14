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
- `tests/devspace/test_nono_blocking_matrix_contract.sh` fails fast when run inside nono by design.
- Wrapper-specific behavior remains covered in dedicated wrapper tests (`test_opencode_secure_wrapper_contract.sh`, `test_nono_identity_integration_contract.sh`).
