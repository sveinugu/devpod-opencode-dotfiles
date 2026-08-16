# allow-direnv-managed-worktrees Design

Date: 2026-08-16
Status: Draft

Related:
- `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- `docs/superpowers/runbooks/nono-policy.md`
- `docs/superpowers/specs/2026-06-20-managed-worktree-lane-safety-design.md`
- `scripts/lib/worktree-env.sh`
- `bin/new-worktree`
- `bin/clone-repo`
- `bin/repair-workspace`

## Short summary

`bin/allow-direnv-managed-worktrees` is a one-off operator helper for refreshing managed checkout direnv trust across the bare-hub workspace. It defaults to dry-run discovery and reporting, and with an explicit execution flag it repairs missing managed env files when needed and then runs `direnv allow` for the selected managed checkouts.

## Motivation and rationale

Managed checkouts already receive generated `.envrc` and `.envrc.local` files during provision, child onboarding, and managed worktree creation. In practice, operators still need a simple follow-up command when direnv trust state is lost, when a workspace is recreated, or when some managed checkouts are missing their env sidecars.

The goal here is a small operator-facing tool, not a general workspace repair framework:

- scan the whole managed workspace from any managed checkout;
- refuse hub-root execution;
- show a clear dry-run report by default;
- on request, repair missing managed env files using the existing managed envrc implementation;
- then run `direnv allow` serially.

This keeps the everyday workflow small:

```bash
bin/allow-direnv-managed-worktrees
bin/allow-direnv-managed-worktrees --allow
```

## Non-goals and constraints

### Non-goals

This helper intentionally does not:

- create or remove worktrees;
- onboard child repos;
- change branch or lane bindings;
- modify nono profiles, DevSpace manifests, or XDG defaults;
- act on arbitrary directories outside the canonical managed checkout layout;
- replace full workspace repair responsibilities already owned by `bin/repair-workspace`.

### Constraints

- the top-level default checkout is `main` only;
- child repos use their exact managed default-branch checkout from local metadata;
- hub root (`/workspaces/dotfiles`) remains an administrative path and must be refused;
- the tool should remain simple and operator-readable: human output plus a plain summary line, no JSON output in v1;
- execution is serial only.

## Chosen scope

This design intentionally keeps one combined operator flow:

1. default dry-run scans the whole managed workspace and reports status;
2. `--allow` executes on targets that need direnv attention;
3. missing managed env files are repaired first through the existing managed envrc helper;
4. divergent/manual `.envrc` files are only rewritten when `--force` is also supplied.

This combines direnv trust refresh and minimal managed env-file repair in one command so the operator does not need to scope and learn a second helper.

## Behavioral specification

### CLI synopsis

```bash
bin/allow-direnv-managed-worktrees [--allow] [--force]
```

### Flags

| Flag | Meaning |
| --- | --- |
| _none_ | Dry-run. Discover canonical managed checkouts across the workspace and print status only. |
| `--allow` | Execute repair/allow actions for checkouts that need attention. |
| `--force` | Valid only together with `--allow`. Re-run `direnv allow` for all managed checkouts with `.envrc`, and permit rewrite of divergent/manual `.envrc` files through the managed envrc helper. |
| `--help` | Print usage and exit `0`. |

### Invalid usage

- `--force` without `--allow` is a usage error;
- unexpected positional arguments are a usage error;
- running from hub root is a safety refusal, not a usage error.

### Default behavior

With no flags, the helper:

1. verifies that the current directory is a managed checkout and not hub root;
2. discovers all canonical managed checkouts in the workspace;
3. classifies each one;
4. prints a human-readable report and a plain summary line;
5. performs no mutations.

### Execution behavior

#### `--allow`

Without `--force`, execution acts on:

- `not allowed`
- `unknown`
- `missing .envrc (repair+allow pending)`
- `missing .envrc.local (repair+allow pending)`

It does **not** rewrite a present-but-divergent `.envrc` in this mode.

#### `--allow --force`

With `--force`, execution acts on all canonical managed checkouts that are eligible for managed env behavior, including:

- all checkouts with an existing `.envrc`, even if already allowed;
- checkouts missing `.envrc` or `.envrc.local`;
- checkouts whose `.envrc` exists but differs from the generated managed content.

In the divergent case, the existing `.envrc` is backed up to `.envrc.bak.*` and replaced with the managed content through the existing helper behavior.

## Managed checkout discovery

The helper scans the whole managed workspace, but it may only be launched from a managed checkout.

### Allowed launch locations

The current working directory must resolve inside one of these managed checkout classes:

- top-level `main`
- top-level `work/*`
- child repo default checkout at `repos/<repo>/<default-branch>`
- child repo worktree at `repos/<repo>/work/*`

### Hub-root refusal

If the current working directory resolves to the workspace root itself, the helper must refuse with the repo-standard exact message:

```text
Refused — hub-root CWD detected. Provide explicit worktree path.
```

### Canonical managed checkout set

The helper considers only these checkout classes as eligible targets:

- `/workspaces/dotfiles/main`
- `/workspaces/dotfiles/work/*`
- `/workspaces/dotfiles/repos/<repo>/<default-branch>`
- `/workspaces/dotfiles/repos/<repo>/work/*`

It must not act on:

- hub root itself;
- bare repo paths;
- arbitrary directories under `repos/`, `state/`, or `tmp/`;
- nested subdirectories beneath a managed checkout path.

### Child repo default-branch resolution

For child repos, default checkout resolution must use managed local metadata rather than remote/network inference:

- read `state/repos/<repo>/etc/repo.env`;
- require `DYN_REPO_DEFAULT_BRANCH` and `DYN_REPO_DEFAULT_DIR`;
- validate that the default dir resolves under `repos/<repo>/`.

If that metadata is missing or invalid, the repo is reported as a discovery error and omitted from action.

## Status classification

Each discovered managed checkout should be reported in one of these states:

- `allowed`
- `not allowed`
- `unknown`
- `missing .envrc (repair+allow pending)`
- `missing .envrc.local (repair+allow pending)`
- `divergent .envrc (force required)`

Notes:

- `.envrc.local` absence is repairable without `--force`;
- `.envrc` divergence means the file exists but does not match the generated managed content for that checkout;
- divergence must be visible in dry-run so the operator knows `--allow` alone will not rewrite it.

### Detection rules

- Missing `.envrc` and missing `.envrc.local` are determined directly from file presence.
- Divergent `.envrc` is determined by comparing the current file to the generated managed content using the same logic already used by `scripts/lib/worktree-env.sh`.
- `allowed` / `not allowed` detection should be attempted when possible.
- If direnv trust state cannot be classified safely and portably for a path, report `unknown` rather than guessing.

The helper should prefer honest reporting over brittle parsing of direnv internals.

## Repair behavior

### Existing implementation to reuse

Managed env-file repair already exists in `scripts/lib/worktree-env.sh` and should be reused rather than reimplemented.

That helper already supports:

- generating missing `.envrc`;
- recreating missing `.envrc.local`;
- backing up and rewriting a divergent `.envrc`;
- no-op success when `.envrc` already matches;
- `direnv allow` after writing the managed `.envrc`.

### Required repair rules in this helper

#### Missing `.envrc`

When a managed checkout lacks `.envrc` and execution is requested:

1. invoke the managed envrc helper for that checkout;
2. create or repair managed env files;
3. immediately run `direnv allow` as part of that flow;
4. report the action clearly.

#### Missing `.envrc.local`

When `.envrc` exists but `.envrc.local` is missing and execution is requested:

1. invoke the managed envrc helper for that checkout;
2. recreate `.envrc.local`;
3. immediately run `direnv allow` if the helper rewrites `.envrc`; otherwise allow-refresh behavior remains part of the outer helper execution for that checkout;
4. report the action clearly.

#### Divergent/manual `.envrc`

When `.envrc` exists but differs from the managed generated content:

- dry-run reports `divergent .envrc (force required)`;
- `--allow` alone does not rewrite it;
- `--allow --force` invokes the managed envrc helper, which must back up the old file and replace it with the generated managed content.

### Safety note on divergence

Rewriting a hand-edited `.envrc` is intentionally treated as a stronger operation than filling in missing managed sidecars. The operator must opt into that rewrite with `--force`.

## Direnv interaction

### Presence of direnv

- Real execution requires `direnv` in `PATH`.
- If `direnv` is missing, execution fails with a clear error.
- Dry-run discovery may still proceed without `direnv`, but trust-state reporting may degrade to `unknown` where needed.

### Execution model

- serial only;
- no `--jobs` support;
- no background work.

### Failure handling

- if a single `direnv allow` call fails, print the error and continue to the next target;
- the final exit code is non-zero if any execution step failed;
- missing env files are not treated as fatal when repair succeeds.

## Output and exit codes

### Human-readable output

The helper should emit stable human-readable lines such as:

- `plan:` for dry-run target reporting
- `ok:` for completed repair/allow actions
- `skip:` for no-op or intentionally deferred cases
- `warning:` for divergence and other non-fatal operator attention
- `error:` for allow/repair failures
- `refused:` for scope/safety refusals

### Summary line

The helper must print one plain summary line suitable for quick operator review, for example:

```text
summary: discovered=7 allowed=2 not_allowed=1 unknown=1 missing_envrc=1 missing_envrc_local=1 divergent=1 attempted=4 failed=1
```

Exact field names may vary, but the summary must cover discovery counts, actionable states, attempts, and failures.

### Exit codes

| Exit code | Meaning |
| --- | --- |
| `0` | Dry-run succeeded, or execution completed with no failures. |
| `1` | One or more repair/allow actions failed after argument parsing succeeded. |
| `2` | Usage error, such as `--force` without `--allow`. |
| `3` | Safety refusal, such as hub-root execution or launch from outside a managed checkout. |

## Interaction with existing user-facing commands

This helper should not require operators to misuse other commands as envrc repair tools.

### `bin/clone-repo`

Not a repair command. It refuses rerun when the child repo path already exists and therefore must not be the recommended way to repair missing `.envrc`.

### `bin/new-worktree`

Can incidentally regenerate missing `.envrc` for an existing managed non-default worktree because it reuses the existing sidecar-preparation flow. However, it also carries branch/worktree creation and lane-binding side effects, so it should not be the primary repair instruction.

### `bin/repair-workspace`

Repairs workspace structure and install-wiring, but it is broader than needed and does not clearly own `.envrc` sidecar regeneration for every existing managed checkout. This helper should provide the dedicated operator path for managed env trust and sidecar repair.

## Acceptance tests (TDD)

Implementers should create integration/contract tests before coding, preferably under `tests/devspace/` or the current execution-context layout used by the repo.

### 1. Dry-run classification across workspace

- **Suggested name:** `tests/devspace/test_allow_direnv_managed_worktrees.sh`
- **Invocation:** `bash tests/devspace/test_allow_direnv_managed_worktrees.sh`
- **Covers:** discovery of all canonical managed checkout classes and reporting of `allowed`, `not allowed`, `unknown`, `missing .envrc`, `missing .envrc.local`, and `divergent .envrc`.

### 2. Hub-root refusal

- **Suggested name:** `tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh`
- **Invocation:** `bash tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh`
- **Covers:** exact hub-root refusal string and refusal when launched outside managed checkout context.

### 3. Missing `.envrc` repair + allow

- **Suggested name:** `tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh`
- **Invocation:** `bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh`
- **Covers:** `--allow` repairs missing `.envrc`, recreates managed content, and runs `direnv allow` in one command.

### 4. Missing `.envrc.local` repair + allow

- **Suggested name:** `tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh`
- **Invocation:** `bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh`
- **Covers:** `--allow` recreates `.envrc.local` when missing and continues normal allow processing.

### 5. Divergent `.envrc` requires force

- **Suggested name:** `tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh`
- **Invocation:** `bash tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh`
- **Covers:** dry-run reports divergence, `--allow` alone leaves it untouched, and `--allow --force` backs up and rewrites the file.

### 6. Continue after allow failure

- **Suggested name:** `tests/devspace/test_allow_direnv_managed_worktrees_failures.sh`
- **Invocation:** `bash tests/devspace/test_allow_direnv_managed_worktrees_failures.sh`
- **Covers:** failed `direnv allow` prints the error, later targets still run, and final exit is `1`.

## Implementation notes

- keep the implementation shell-based and consistent with existing repo command style;
- prefer reusing existing metadata and helper logic over inventing new state files;
- centralize discovery of canonical managed checkout paths;
- centralize status classification so dry-run and execution use the same target model;
- reuse `scripts/lib/worktree-env.sh` for env-file repair rather than duplicating its generation rules;
- preserve existing managed-worktree safety expectations by refusing hub root and unmanaged paths.

## Suggested docs/runbook updates

After implementation, update `docs/superpowers/runbooks/devspace-bare-hub-usage.md` to add:

- the new helper command;
- the dry-run-first operator flow;
- a note that the helper can repair missing managed env files and then run `direnv allow`;
- a note that divergent/manual `.envrc` requires `--allow --force`.

## Security and policy checklist

- honor the existing managed-worktree safety model and exact hub-root refusal wording;
- do not expand the tool into arbitrary-path mutation;
- do not modify nono profiles, deployment manifests, or XDG agreements in this slice;
- rely on the existing nono allowance for the direnv allow-list directory under `$XDG_DATA_HOME/direnv`;
- keep behavior idempotent for already-correct managed checkouts;
- preserve backup-on-rewrite behavior for divergent `.envrc`.
