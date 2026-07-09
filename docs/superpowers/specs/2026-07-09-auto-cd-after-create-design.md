# Auto-CD After `new-worktree` / `clone-repo` Creation (Design)

Date: 2026-07-09  
Status: Proposed (design approved by user; written spec pending implementation)

## Problem

`bin/new-worktree` and `bin/clone-repo` currently create the requested checkout and print a success message with the resulting path.

That is Unix-normal for scripts, but it leaves an interactive workflow gap: after creating a worktree or managed child repo, the user can forget to move into the new checkout before opening tools such as OpenCode.

The requested change is to make the interactive experience move the user into the newly created checkout automatically, while staying aligned with normal Unix boundaries.

## Scope

This design covers the interactive navigation experience for:

- `bin/new-worktree`
- `bin/clone-repo`
- `.config/shell/workspace-navigation.zsh`
- focused tests and documentation needed to protect the shell/script integration contract

This slice is design-only. It does not implement the behavior.

## Goals

- Make successful interactive `new-worktree` runs land the shell in the new worktree by default.
- Make successful interactive `clone-repo` runs land the shell in the created repo's default checkout by default.
- Keep the actual `cd` behavior in shell code rather than in child processes.
- Provide a single shared opt-out environment variable for both commands.
- Show the opt-out hint from shell code on every successful wrapper-driven run, regardless of whether auto-`cd` happened.
- Avoid brittle parsing of human-readable success output.

## Non-goals

- Do not make the scripts themselves change the parent shell directory.
- Do not add separate opt-out environment variables per command.
- Do not require CLI opt-out flags in v1.
- Do not change `dhub`, `dre`, `dwt`, or general startup auto-`cd` behavior.
- Do not recompute destination paths independently in shell code when the scripts already know the authoritative target.

## Design Constraints

- Raw script usage must remain valid for automation and non-interactive contexts.
- Existing human-readable success output may remain user-facing, but must not become the shell integration contract.
- The destination path should have one authoritative producer per command run.
- Shell wrapper behavior should degrade safely if shell-integration metadata is missing or invalid after an otherwise successful create operation.

## Chosen Direction

Use interactive shell wrappers for `new-worktree` and `clone-repo`, backed by a small machine-readable handoff from the scripts.

This keeps the Unix boundary clean:

- the scripts create and report
- the shell decides whether to `cd`

This matches the existing repository pattern where interactive navigation behavior already lives in `.config/shell/workspace-navigation.zsh`.

## Alternatives Considered

### 1. Parse existing success text in shell wrappers

Rejected. This is the smallest apparent change, but it couples shell behavior to human-facing message formatting and is therefore brittle.

### 2. Add interactive shell wrappers plus a machine-readable target-path handoff

Chosen. This keeps destination-path knowledge authoritative in the scripts while leaving all parent-shell behavior in shell code.

### 3. Recompute the destination entirely in shell code

Rejected. This duplicates path-resolution knowledge already owned by the scripts and increases drift risk for child repos and non-`main` defaults.

## User-Visible Behavior

### Successful interactive `new-worktree`

- The wrapper runs the underlying command.
- The wrapper prints the command's normal output.
- The wrapper prints a shell-owned hint about the shared opt-out environment variable.
- If opt-out is not enabled, the wrapper prints `cd -> <target>` and moves the current shell into the new worktree.
- If opt-out is enabled, the wrapper stays in the current directory and still prints the hint.

### Successful interactive `clone-repo`

- The wrapper runs the underlying command.
- The wrapper prints the command's normal output.
- The wrapper prints a shell-owned hint about the shared opt-out environment variable.
- If opt-out is not enabled, the wrapper prints `cd -> <target>` and moves the current shell into the managed repo's default checkout.
- If opt-out is enabled, the wrapper stays in the current directory and still prints the hint.

### Failure behavior

- If the underlying command fails, the wrapper preserves its output and exit status.
- No success hint is printed.
- No directory change occurs.

### Degraded shell-wrapper behavior

If the underlying command succeeds but the wrapper cannot obtain a usable target path from the handoff contract, the wrapper should:

- warn clearly
- stay in the current directory
- preserve the successful create operation rather than reclassifying it as a creation failure

This avoids falsely reporting the overall creation as failed after the repo/worktree already exists.

## Shell/Script Contract

### Shell wrappers

`.config/shell/workspace-navigation.zsh` should define interactive wrappers named `new-worktree` and `clone-repo`.

Each wrapper should:

1. create a temporary target file
2. invoke the real executable with the temp-file path passed in an environment variable
3. preserve stdout, stderr, and exit status from the underlying command
4. read and validate the target path on success
5. print the opt-out hint
6. either `cd` to the target or stay put, depending on the shared opt-out variable

The wrappers should use `command new-worktree` / `command clone-repo` so they reach the real executable rather than recursively calling themselves.

### Shared opt-out variable

Use one shared environment variable for both commands:

- `HUB_WORKSPACE_NAV_DISABLE_AUTO_CD=1`

The wrappers own this behavior. The scripts themselves should not change behavior based on this variable.

### Machine-readable handoff

The wrapper should pass a temp-file path through a shell-integration environment variable, for example:

- `HUB_WORKSPACE_NAV_TARGET_FILE`

On success, `bin/new-worktree` and `bin/clone-repo` should write the resolved absolute destination path to that file when the variable is present.

The wrapper should treat that file as the authoritative shell-integration handoff and should not parse human-readable success text.

## Script Responsibilities

`bin/new-worktree` and `bin/clone-repo` should continue to:

- perform creation/setup work
- keep their current human-readable success reporting

Additionally, when the target-file environment variable is present, each script should write its final absolute destination path to that file as a machine-readable success handoff for the interactive shell wrapper.

## Testing and Documentation Direction

Implementation should add focused coverage in two layers.

### Script-level coverage

- `new-worktree` writes the created worktree path to the target file when requested.
- `clone-repo` writes the created default-checkout path to the target file when requested.
- Existing success output remains intact.

### Shell-level coverage

- Wrapper auto-jumps on success when opt-out is unset.
- Wrapper does not jump when `HUB_WORKSPACE_NAV_DISABLE_AUTO_CD=1`.
- Wrapper prints the hint in both states.
- Wrapper warns and stays put when handoff data is missing or invalid after successful creation.
- Wrapper preserves underlying failure behavior.

Documentation should be updated only where needed to explain the interactive wrapper behavior and the shared opt-out variable.

## Risks and Mitigations

### Risk: recursive wrapper invocation

Mitigation: wrappers should use `command ...` to call the real executable.

### Risk: malformed or missing target-path handoff

Mitigation: validate that the handoff is non-empty and names an existing directory before attempting `cd`; otherwise warn and stay put.

### Risk: output regressions

Mitigation: preserve current human-readable success lines and add explicit tests for the new machine-readable handoff contract.

### Risk: hidden behavior in automation

Mitigation: keep all hinting and `cd` behavior in interactive shell wrappers only.

## Acceptance Checks

1. Running `new-worktree` from an interactive shell wrapper with opt-out unset creates the worktree, prints the normal output, prints the hint, and lands the shell in the new worktree.
2. Running `clone-repo` from an interactive shell wrapper with opt-out unset creates the managed child repo, prints the normal output, prints the hint, and lands the shell in the repo's default checkout.
3. Running either wrapper with `HUB_WORKSPACE_NAV_DISABLE_AUTO_CD=1` still succeeds, still prints the hint, and leaves the shell in the original directory.
4. Running the raw scripts without wrapper semantics remains valid and does not rely on parent-shell directory changes.
5. If the script succeeds but handoff metadata is missing or invalid, the wrapper warns and stays put without misreporting the already successful creation as failed.
6. If the underlying command fails, the wrapper does not print a success hint and does not change directories.

## Recommended Implementation Shape

The simplest implementation shape consistent with this design is:

- a small shared shell helper in `.config/shell/workspace-navigation.zsh`
- minimal script changes to emit an optional target-path handoff
- focused tests that protect both the shell behavior and the script contract

This keeps the change orthogonal, reversible, and tightly scoped.
