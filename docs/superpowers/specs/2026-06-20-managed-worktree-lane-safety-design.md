# Managed Worktree Lane Safety Design

Date: 2026-06-20  
Status: Proposed (direction approved by user; written spec pending review)

## Problem

Current worktree policy and agent-facing guidance are too weak for real multi-lane work.

Observed failures include:

- Maestro often does not create a dedicated worktree before dispatching scoped authoring work.
- Several scoped sessions can share one worktree, which mixes unrelated changes and risks wrong-task commits.
- Commits can land in the wrong worktree or wrong branch because lane identity is not enforced strongly enough.
- Agents and docs express worktree usage mostly as preference rather than refusal-backed policy.
- There is no managed cleanup command for retiring a local worktree and its local branch after proving what would or would not be lost.

These failures already appear not only across unrelated features, but also inside one parent change stream when testing produces multiple follow-up bug lanes that may need to proceed in parallel.

## Scope

This design defines one coherent policy/tooling direction for managed worktree safety across both the top-level hub and managed child repos.

It covers:

- work-item and lane identity for scoped work
- Maestro/agent dispatch rules for creating, reusing, and splitting managed worktrees
- explicit pushback behavior for wrong-worktree situations
- agent-facing policy/docs surfaces that must be updated
- a managed local cleanup tool for retiring worktrees and local branches safely

It does **not** include remote branch deletion in v1.

## Goals

- Prevent wrong-task commits from shared or mismatched worktrees.
- Make dedicated managed worktrees mandatory for scoped authoring lanes.
- Support multiple parallel follow-up lanes under one parent spec/plan/feature without mixing commits.
- Make Maestro responsible for resolving or creating the correct managed worktree before dispatch.
- Turn worktree mistakes into explicit refusals or lane-selection prompts rather than soft preferences.
- Provide a safe local cleanup path for both hub and child repos.
- Keep the design compatible with one Maestro tracking multiple active lanes at once.

## Non-goals

- No remote branch deletion in v1.
- No arbitrary-path cleanup or generic Git force-delete wrapper.
- No requirement that one Maestro session may track only one active lane.
- No attempt in this slice to redesign all session routing semantics beyond what is necessary for worktree/lane safety.
- No runtime/plugin enforcement requirement in this slice; policy, prompts, scripts, and tests are the intended first implementation surfaces.

## Chosen Design

### 0) V1 compatibility constraints

Three compatibility constraints are part of this design, not follow-up questions:

- The canonical Delegation Packet schema remains unchanged in v1.
- Session resume identity must treat the lane as part of the effective work-item identity.
- The existing branch-keyed `state/` / `tmp/` filesystem layout remains in place in v1.

If later implementation discussion pushes against the third point, the expected default is to push back and keep the branch-keyed layout unless the user explicitly chooses a different direction.

### 1) Lane-based identity model

The unit of exclusive managed worktree ownership is an **active lane**, not merely a file path and not merely a parent feature.

- A **parent change stream** may be anchored by one or more existing artifacts such as a spec, plan, approved implementation branch, or related bugfix context.
- An **active lane** is the concrete line of authoring work currently producing commits.
- A lane may be a direct continuation of an existing approved change stream, or a child follow-up lane under that parent.

Important consequence:

- A parent feature/spec/plan may have multiple child bugfix or follow-up lanes.
- Each active child lane must have its **own** dedicated branch/worktree pair.
- A worktree may be reused on resume only when the resumed work is the **same lane**.

This keeps natural continuation cheap while preventing commit mixing once parallel work begins.

### 2) Reuse and split rules

Reuse an existing managed worktree only when the new request is a true continuation of the same lane.

Treat it as the same lane when all remain true:

- it is a direct continuation or correction of the same approved change stream
- it stays on the same intended branch/change lane
- it does not introduce a separately reviewable feature/fix lane
- reusing the existing worktree would not mix commits that should be reviewed separately

Create a new sibling lane and a new managed worktree when any of these become true:

- the work expands beyond the current lane's approved continuation
- a second follow-up fix must proceed in parallel with the first
- the work is independently reviewable or should produce a separately understandable commit series
- reusing the current worktree would blur ownership of commits or approval history

Example:

- Feature lane exists.
- Bug A is found during testing and may begin as continuation there.
- Bug B is later discovered and should be worked on in parallel.
- Bug B must be split into a sibling lane with its own branch/worktree.

### 3) Lane identity separate from branch/worktree names

Each lane must have a stable **lane ID** separate from branch and worktree path.

- Lane IDs should be human-readable rather than opaque.
- Maestro should generate a visible/editable default lane ID rather than relying directly on branch naming.
- Branch names and worktree paths remain operational details recorded in binding metadata.

This allows a lane to stay conceptually stable even when several anchors exist around it, including parent artifacts, resumed sessions, and sibling follow-up lanes.

### 4) Binding record under canonical state

Each active lane must have one authoritative local binding record under the canonical `state/` tree.

V1 keeps the existing branch-keyed filesystem layout used by current managed worktrees.

- Existing paths such as `state/hub/main`, `state/hub/work/<branch>`, `state/repos/<repo>/<default-branch>`, and `state/repos/<repo>/work/<branch>` remain authoritative for per-worktree state roots.
- Lane IDs do **not** replace those filesystem keys in v1.
- Instead, v1 adds lane-binding registry metadata alongside the existing layout.

Recommended structure:

- one central lane registry per managed repo context
- plus per-worktree pointers or equivalent reverse lookup metadata

Each lane binding should capture at least:

- lane ID
- repo identity (`hub` or child repo name)
- branch name
- worktree path
- parent artifact anchor(s) when applicable
- current status (`active`, `retired`, or equivalent)
- enough session/routing linkage to let Maestro resume the correct lane safely

The authoritative binding must live in local managed state, not in tracked repo files.

In v1, lane ID is therefore a registry-level identity layered on top of the already-existing branch/worktree-keyed directory structure.

### 5) Lane-scoped by default

For scoped work, actions are **lane-scoped by default**.

Treat an action as lane-scoped whenever it relates meaningfully to a specific scoped work item, lane, branch, worktree, artifact anchor, or bug/follow-up stream.

This includes:

- building or previewing a Delegation Packet for scoped work
- resolving or creating a worktree for a lane
- reading session metadata in order to route or resume a specific lane
- git status/diff/log/commit actions for a lane
- review routing tied to a specific lane
- cleanup or retirement of a lane

Truly lane-neutral actions are rare and mostly limited to:

- receiving a new message before the target lane is known
- listing active lanes
- detecting ambiguity
- asking the user which lane to resume or continue
- routing an explicit `$<task_id>` token to its known owner session

When in doubt, Maestro must require lane selection first.

Because the Delegation Packet schema is closed, lane identity is **not** sent as a new packet field in v1.

Instead, the receiving subagent derives the effective lane identity locally from:

- the delegated `Worktree path:`
- the managed lane registry/binding metadata
- the delegated artifact anchor(s), when present
- local repo state and branch/worktree evidence

If this local derivation does not yield one coherent lane, the subagent must stop and push back rather than infer or silently repair the lane identity.

### 6) Maestro multi-lane rules

Maestro may coordinate multiple active lanes at once, but must maintain strict lane identity.

Rules:

- Any lane-scoped action must target one explicit lane.
- Maestro must not carry over lane/worktree context implicitly from the last action.
- If the user's request, resume token, worktree path, branch, or artifact anchor identifies a lane unambiguously, Maestro may switch internally without extra confirmation.
- If more than one active lane is plausible, Maestro must ask the user which lane to use.
- If continuing work would split one parent change stream into multiple concurrent follow-up lanes, Maestro must surface that a new sibling lane/worktree is being created.

This is a hybrid model:

- strict internal lane binding always
- user-visible lane switching when ambiguity exists or when parallel lane-splitting is introduced

For session routing, the lane becomes part of effective work-item identity.

Concretely, where current policy says one session per `(subagent type, work item)`, v1 should interpret scoped multi-lane work as one session per `(subagent type, lane-qualified work item)`.

Implications:

- two sibling lanes under the same parent artifact are different resume targets
- a resumed session must match both the subagent type and the intended lane-qualified work item
- when only the parent artifact matches but multiple active lanes exist beneath it, Maestro must ask rather than guessing
- the lane-qualified identity may be represented operationally through artifact anchor(s) plus the bound worktree/registry mapping; it does not require a new Delegation Packet field in v1

### 7) Mandatory worktree resolution before dispatch

For scoped authoring work, Maestro must resolve or create the dedicated managed worktree **before** dispatch.

Hard requirements:

- dispatch must carry the explicit worktree path for the target lane
- resuming a lane must prefer that lane's existing bound worktree
- a missing dedicated worktree is not a reason to proceed in `main`; it is a reason for Maestro to create/resolve the lane worktree first
- if the lane registry and delegated worktree path cannot be reconciled before dispatch, Maestro must stop rather than launching a packet with ambiguous lane identity

Hard-stop conditions:

- dispatching scoped authoring work from hub root
- dispatching scoped authoring work from `main` when that lane requires its dedicated worktree
- dispatching two unrelated active lanes into one worktree
- continuing a lane from a worktree bound to a different active lane
- attempting lane-sensitive repo operations without having resolved the target lane first

### 8) Pushback contract for docs and agents

Worktree safety must be expressed as refusal-backed policy, not merely as preference wording.

Agent/policy surfaces should explicitly communicate that wrong-worktree behavior is a refusal condition.

Subagents should not trust Maestro or user-provided lane/worktree information blindly.

Required direction:

- for lane-scoped work, the receiving subagent must independently verify that the delegated lane identity, worktree path, branch, and relevant artifact anchors are coherent with local repo state and policy
- this verification is performed by deriving lane identity locally from `Worktree path:` plus registry/repo evidence, not by expecting a new lane field in the Delegation Packet
- if Maestro-provided metadata, user instructions, and local repo/worktree evidence disagree materially, the subagent must stop and push back rather than silently choosing one
- if the delegated worktree is missing, bound to another active lane, or otherwise inconsistent with the delegated scope, the subagent must refuse substantive work and surface the mismatch
- subagents may trust routing metadata only after this local coherence check passes

The intended direction is:

- prefer managed commands such as `bin/new-worktree` for worktree creation
- require explicit worktree-path dispatch for lane-scoped work
- require pushback when the current checkout and target lane do not match
- preserve exact existing bare-hub refusal strings where already defined

### 9) Managed cleanup tool: v1 scope

Add one managed cleanup/retirement tool for both the top-level hub and managed child repos.

V1 scope:

- remove a managed non-default worktree
- remove the corresponding **local** branch
- retire or tombstone the lane binding record

V1 exclusions:

- no deletion of remote branches on `origin`
- no arbitrary-path deletion
- no deletion of default checkouts (`main` for hub, detected default branch for child repos)

Primary target model:

- target by lane ID or branch name resolved through binding metadata
- explicit worktree path may still be accepted as a lower-level explicit target form

### 10) Cleanup safety checks

The normal cleanup run must refuse unless all non-overridable structural checks pass and all loss checks are either clear or intentionally forced later.

Non-overridable structural checks:

- target resolves to a managed worktree in the canonical layout
- target is not the repo default checkout
- target branch/worktree identity is not ambiguous
- target branch is not still attached to another worktree / active checkout
- target matches the managed layout and binding contract

Loss checks that must be evaluated and reported:

- uncommitted tracked changes
- untracked files/directories that would be lost
- local-only commits that would become unreachable from the deleted local branch
- missing/unusable upstream state that prevents the tool from proving everything is already pushed

### 11) Cleanup output and evidence contract

The normal failing run is part of the safety protocol.

When cleanup refuses for loss-related reasons, it must print explicit evidence, not merely filenames.

Required evidence direction:

- modified tracked files: full patch/diff content
- untracked text files: full file content
- local-only commits: commit list plus patch content
- binary files: path, size, hash, and a clear statement that binary content would be lost

The refusal output must also print:

- which checks failed
- which losses are potential and why
- the exact force command format to retry, if the situation is force-overridable

### 12) `--dry-run`, `--force`, and stateless force token

The cleanup tool should support:

- `--dry-run` to inspect the decision without deletion
- `--force` for intentional destructive cleanup of loss-related failures
- a required `--force-token <token>` proving that the caller saw the current refusal report

`--force` must override only loss-related failures. It must **not** override structural safety invariants.

Recommended token model:

- normal refusing run builds a canonical risk report from current state
- tool computes a token from that exact report and target identity
- refusal output prints the token and the exact retry command
- force run recomputes the current report and accepts only if the token still matches

This keeps force confirmation stateless and automatically invalidates stale approvals when state changes.

### 13) Lane retirement record

After successful cleanup, the lane record should not disappear without trace.

Recommended outcome:

- compact the active binding into a minimal retired/tombstone record rather than deleting all evidence outright

This preserves enough audit/history context to understand what lane previously occupied the branch/worktree without keeping active-lane metadata alive forever.

## Acceptance Criteria

1. Scoped authoring work cannot be dispatched into `main`, hub root, or an unrelated lane worktree when a dedicated lane worktree is required.
2. A resumed scoped session reuses its lane's bound worktree rather than silently switching to another checkout.
3. One parent feature/spec/plan may spawn multiple concurrent child lanes, each with its own branch/worktree binding.
4. Maestro can track multiple active lanes, but any ambiguous lane-sensitive action triggers lane-selection rather than implicit reuse.
5. Lane identity for delegated work is derived locally from delegated worktree path plus registry/repo evidence without changing the v1 Delegation Packet schema.
6. Session-resume identity treats sibling lanes under one parent artifact as different lane-qualified work items.
7. V1 keeps the current branch-keyed `state/` / `tmp/` filesystem layout and adds lane-binding registry metadata alongside it.
8. Agent-facing policy/docs express wrong-worktree situations as refusal-backed behavior rather than soft preference wording.
9. Receiving subagents independently verify lane/worktree/branch coherence instead of trusting Maestro or user routing data blindly.
10. Cleanup tooling works for both hub and managed child repos.
11. Normal cleanup refuses when content-loss risk exists and prints concrete evidence of that risk.
12. Structural safety failures remain non-overridable even in force mode.
13. `--force` is accepted only with a matching token derived from the current refusal report.
14. Remote branch deletion remains out of scope for v1.

## Testing Strategy

### Automated

- Add or extend doc-contract tests to pin the new refusal-backed lane/worktree policy in:
  - `.config/opencode/AGENTS.md`
  - `.config/opencode/agents/maestro.md`
  - `.config/opencode/agents/senior-implementer.md`
  - any other touched authoring-agent prompts
- Add script/integration tests for managed worktree resolution and cleanup behavior across both hub and child repos.
- Add tests that cover:
  - lane reuse on resume,
  - sibling lanes under one parent artifact producing distinct resume targets,
  - sibling lane creation for parallel follow-up work,
  - local lane derivation from delegated worktree path plus registry state without requiring packet-schema changes,
  - refusal on mismatched worktree/lane identity,
  - subagent refusal when delegated lane/worktree metadata conflicts with local state,
  - refusal evidence generation for tracked/untracked/binary/local-only-commit loss,
  - force-token acceptance and invalidation when state changes,
  - protection of default checkouts and non-managed targets.

### Manual verification

- Validate that real Maestro-guided follow-up bug work no longer reuses the wrong worktree by accident.
- Validate that ambiguous multi-lane situations produce a clear lane-selection prompt.
- Validate that cleanup refusal output is readable enough for an intentional abandonment decision.

User Check-in: review whether the lane-selection UX and refusal wording feel clear enough before implementation planning.

## Risks / Trade-offs

- Multi-lane identity is more complex than a simple branch-only rule, but it matches real follow-up bug workflows better.
- Full diff/content evidence can make cleanup refusal output large, especially for local-only commit patches.
- Lane metadata design must avoid becoming a second confusing authority beside Git itself.
- Overly aggressive ambiguity prompts could create friction if lane identification heuristics are weak.

## Implementation Surfaces

Expected first implementation surfaces include:

- `.config/opencode/AGENTS.md`
- `.config/opencode/agents/maestro.md`
- `.config/opencode/agents/senior-implementer.md`
- relevant runbooks describing managed worktree usage
- managed state metadata helpers/commands for lane binding
- one managed cleanup command for hub + child repos
- doc-contract and shell/integration tests

## Follow-up / Out of Scope

- Remote branch deletion, including any `origin` cleanup flow
- Richer UI/session visualization for many active lanes
- Any later runtime/plugin validator that mechanically enforces the policy inside OpenCode
