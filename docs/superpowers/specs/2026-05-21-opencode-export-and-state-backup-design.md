# OpenCode Export And State Backup Design

Date: 2026-05-21  
Status: Proposed  
Supersedes: The persistence portion of the bare-hub manager plan and the earlier `/workspaces` persistence design.

## Executive Summary

This design replaces the earlier idea of treating large parts of `/workspaces/dotfiles` as durable state. Instead, Git remains the durability layer for source code and committed documents, while local keep-worthy state is backed up explicitly. OpenCode session history is backed up by regularly exporting all sessions with `opencode export`, not by copying OpenCode's internal storage directly. Other keep-worthy local state is backed up from repo-relative `state/` directories, while all `tmp/` directories remain disposable and excluded. Backup is performed in two alternating half-hour phases: in-pod export and staging, then host-side pull and snapshot backup with `restic`.

## Goals

- Preserve readable and recoverable OpenCode session history.
- Preserve keep-worthy local flat-file state stored under `state/`.
- Exclude disposable runtime and debug material under `tmp/`.
- Keep the design simple, standard, and reversible.
- Avoid giving DevPod agents direct write access to the real backup destination.
- Prefer stale-but-internally-consistent files over fresher but possibly inconsistent files.

## Non-Goals

- Do not treat general `/workspaces` content as durable state.
- Do not back up Git-tracked source content as part of this mechanism.
- Do not back up `tmp/` directories.
- Do not attempt transactionally consistent snapshots across all state files.
- Do not depend on exact resumability of imported OpenCode sessions.
- Do not solve laptop-loss or cloud-backend backup policy here.

## Core Decisions

- Git is the durability layer for code, specs, plans, and other intentionally committed content.
- OpenCode durable backup source is `opencode export`, not OpenCode's internal storage layout.
- OpenCode exports use full `opencode export <session-id>`, not `--sanitize`.
- All OpenCode sessions are exported by default.
- Durable exports live at `/workspaces/dotfiles/state/opencode/exported_sessions/`.
- Other durable local state is backed up from:
  - `/workspaces/dotfiles/state/`
  - `/workspaces/dotfiles/repos/*/state/`
- All `tmp/` directories are excluded from backup.
- Backup staging is performed inside the pod under `/tmp/opencode-backup-staging/`.
- Host backup is a scheduled host-side pull via `kubectl exec ... tar ...`.
- Host-side snapshots are stored with `restic`.
- The host backs up the whole staged tree every run. No custom changed-since-last-run gate is used in phase 1.

## Storage Contract

### Durable State

The following locations are considered keep-worthy and included in backup:

- `/workspaces/dotfiles/state/`
- `/workspaces/dotfiles/state/opencode/exported_sessions/`
- `/workspaces/dotfiles/repos/*/state/`

### Disposable State

The following locations are considered disposable and excluded from backup:

- Any `tmp/` directory under the managed workspace tree
- Any OpenCode or debugging scratch material intentionally written under `tmp/`
- Backup staging under `/tmp/opencode-backup-staging/`

### State Semantics

Files in `state/` must be treated as independently restorable artifacts, not as a transactionally consistent set. A restored backup may contain individually consistent files from slightly different moments in time. This is acceptable for this design.

## OpenCode Export Contract

### Export Source

OpenCode session history is backed up by exporting sessions through the documented CLI:

- `opencode session list --format json`
- `opencode export <session-id>`

### Export Mode

The default export mode is full export:

- `opencode export <session-id>`

The sanitized export mode is not used for primary backups because it redacts message history and tool outputs too aggressively for the intended recovery use case.

### Export Directory

Exports are written to:

- `/workspaces/dotfiles/state/opencode/exported_sessions/`

### Export Filename Format

Each exported session JSON file uses this filename format:

- `<exported-at>-<session-id>-<title-slug>.json`

Example:

- `2026-05-21T21-14-32Z-ses_1b58f0a84ffeRLncNW1WghbuIu-git-worktree-with-devpods-on-mac.json`

### Export Filename Rules

- `<exported-at>` is a sortable UTC timestamp in filename-safe form.
- `<session-id>` is the authoritative stable identity.
- `<title-slug>` is for humans only.
- Title slug normalization is simple and built-in only:
  - lowercase
  - whitespace collapsed to `-`
  - strip or replace unsafe filename characters
  - crop to a reasonable maximum length
- No third-party slug library is required.

### Re-Export Rules

For each session returned by `opencode session list --format json`:

- If no export exists for the session id, export it.
- If the export filename is malformed, re-export it.
- If the session `updated` timestamp is newer than the export timestamp, re-export it.

### Export Replacement Rules

- Write each new export to a temporary file first.
- Validate that the temporary file is non-empty and valid JSON.
- Validate expected top-level structure such as `info.id` and `messages`.
- Replace the old export only after the new export passes validation.
- Keep only the newest export per session in the export directory.

## Backup Staging Contract

### Staging Root

Use:

- `/tmp/opencode-backup-staging/current/`
- `/tmp/opencode-backup-staging/next/`

### Staging Model

This design uses double-buffer staging.

- `current/` is the last known-good staged backup set.
- `next/` is prepared during the current staging run.
- Host backup reads only `current/`.
- `next/` is never read by the host backup job.

### Why Double Buffering

Double buffering ensures:

- the host never backs up an in-progress staging tree
- an interrupted staging run does not poison the backup source
- busy files can retain their last staged copy

### How `next/` Is Prepared

- Seed `next/` from `current/`.
- Refresh included source files into `next/`.
- Remove entries that no longer exist in the source, except where the source file is currently skipped due to being open for write.
- On successful completion, atomically replace `current/` with `next/`.

### Handling Files Open For Write

The backup-prep policy for source files is:

- if a file is open for write, wait briefly and retry once
- if the file is still open for write, skip refreshing that file
- keep the previous staged copy from `current/` in `next/`
- record the skipped file in the per-run report

This intentionally prefers stale-but-internally-consistent files over fresher but potentially inconsistent files.

### Consequences Of Busy-File Preservation

- The newest staged set may contain stale copies of files that were busy during staging.
- Those files remain present in the newest backup snapshot.
- Directory-level freshness may vary file-by-file.
- This is preferred over omitting busy files from the newest snapshot.

### Staging Inputs

Stage only:

- `/workspaces/dotfiles/state/`
- `/workspaces/dotfiles/repos/*/state/`

Do not stage:

- any `tmp/` directories

### Staging Reporting

Each staging run should record a per-file skipped list for files that remained open for write after the retry.

## Host Backup Contract

### Backup Direction

Backup is host-side pull only.

The pod must not be given writable access to the real backup destination.

### Host Access Method

The default access mechanism is:

- scheduled host-side pull via `kubectl exec ... tar ...` from the live DevPod pod

This is preferred over `kubectl cp` for automation because it is more explicit and easier to control for inclusion and exclusion.

### Backup Engine

Use `restic` on the Mac host.

Why:

- open source
- standard snapshot backup tool
- compression
- deduplication
- older snapshots survive later deletions in source data

### Backup Scope

The host backs up the entire staged `current/` tree every backup run.

No custom "only back up if changed" logic is used in phase 1. Efficiency comes from `restic` deduplication and compression, not from custom incremental decision logic.

## Schedule

The default schedule alternates every half hour while the laptop is on.

### Phase A: In-Pod Export And Staging

Recommended default slot:

- top of the hour, for example `:00`

Actions:

- export all OpenCode sessions as needed
- refresh `next/` from `current/`
- update staged copies of included `state/` files
- preserve prior staged copies for files still open for write
- swap `next/` into `current/` on success

### Phase B: Host Pull And Snapshot Backup

Recommended default slot:

- half past the hour, for example `:30`

Actions:

- pull staged `current/` from the live DevPod pod
- run `restic backup` against the pulled data

### Scheduling Assumption

This design assumes the staging phase completes well within thirty minutes under normal conditions.

## Recovery Contract

### Recovery Inputs

The recovery script accepts:

- one or more directories
- one or more explicit JSON file paths

If an input is a directory, the script scans it for `*.json`.

This keeps the interface Unix-friendly and allows manual filtering before invocation.

### Recovery Ordering

Recovery imports exports in reverse chronological order:

- newest export first

### Recovery Deduplication

Recovery deduplicates by `session-id`.

- the first file seen for a session id wins
- older exports for the same session id are skipped

This matches newest-first ordering and ensures only the newest selected export per session is imported.

### Metadata Parsing During Recovery

Preferred source of metadata:

- filename metadata first

Fallback:

- if filename metadata is malformed, parse the JSON file to recover needed metadata such as session id

### Recovery Operation

Recovery uses:

- `opencode import <file>`

### Recovery Expectation

This design assumes imported sessions will at least be readable after recovery. Exact live-session resumability is not guaranteed and is out of scope for this design.

## Security Model

- The real backup destination is not mounted writable into DevPod.
- Agents and in-pod scripts only affect:
  - live workspace state
  - exported session JSONs
  - staging under `/tmp`
- The actual backup repository is written only by the host-side backup process.
- Malicious or buggy in-pod deletion can affect future source state, but older `restic` snapshots remain available.
- This design reduces the blast radius compared with a writable host-mounted backup target.

## Assumptions

- The environment is currently single-node k3d on Colima.
- Pod and local-path volume persistence across ordinary restarts is "good enough" operationally.
- Full-cluster rebuild durability is not required.
- Writers for repo-relative `state/` files are uncontrolled and may be arbitrary tools.
- Most uncontrolled writers use ordinary open-write-close flat-file behavior.
- Logs and churn-heavy output should live in `tmp/`, not `state/`.

## Guarantees

This design aims to provide these guarantees:

- OpenCode session history is backed up in a documented, tool-supported format.
- The newest backup never reads an in-progress staging tree.
- Busy files can remain stale, but the newest staged set still contains their last known-good staged copy.
- `tmp/` is excluded from durable backup.
- The latest backup snapshot is expected to contain individually consistent files, though not necessarily a transactionally consistent whole-state snapshot.
- Older backup snapshots remain available even after later deletions in source data.

## Explicit Non-Guarantees

This design does not guarantee:

- exact transaction-level consistency across all files in `state/`
- exact resumability of imported OpenCode sessions
- preservation of arbitrary OpenCode internal runtime state
- durability across laptop loss or cloud-backend failure
- perfect detection of all logically incomplete files from uncontrolled writers

## Failure Handling

### Export Failure

- Keep the previous export for that session.
- Report the failed session export.
- Continue with other sessions where appropriate.

### Busy Source File During Staging

- Retry once.
- If still open for write, keep the last staged copy.
- Report the file individually.

### Staging Failure Before Swap

- Leave `current/` untouched.
- Do not expose partial `next/` to host backup.

### Host Pull Or Backup Failure

- Fail that backup run clearly.
- Retry at the next scheduled backup window.
- Existing `restic` snapshots remain unaffected.

## Out Of Scope Future Improvements

These are intentionally not part of phase 1:

- helper pod backup access
- filesystem-level snapshots
- backup change detection before `restic`
- multi-node storage redesign
- direct backup of OpenCode internal databases
- richer import filtering or restore UIs
- cloud backup policy beyond using a host path that may itself be synced elsewhere

## Proposed Script Responsibilities

These names are illustrative and can be revised during implementation.

- `scripts/opencode-export-all-sessions.sh`
  - enumerate all sessions
  - export or re-export as needed
  - manage validated replacement of exported session JSON files

- `scripts/prepare-state-backup-set.sh`
  - seed `next/` from `current/`
  - stage durable `state/` content
  - retry once for busy files
  - preserve prior staged copies for still-busy files
  - emit per-file skipped report
  - atomically swap `next/` into `current/`

- `scripts/host-pull-and-restic-backup.sh`
  - pull staged `current/` from the live DevPod pod
  - run `restic backup` on the pulled tree

- `scripts/recover-opencode-sessions.sh`
  - accept directories and explicit JSON file paths
  - sort newest-first
  - dedupe by session id
  - fall back to JSON parsing when filename metadata is malformed
  - call `opencode import` on the selected files

## Final Design Position

The earlier persistence design was too broad. This design narrows persistence and backup to exactly the data that is both useful and realistically recoverable:

- exported OpenCode sessions
- repo-relative durable `state/`
- no `tmp/`
- no attempt to make all of `/workspaces` precious

This is the intended phase 1 design.
