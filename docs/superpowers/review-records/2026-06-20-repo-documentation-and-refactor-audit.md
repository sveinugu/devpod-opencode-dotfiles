# 2026-06-20 Repo Documentation + Refactor Audit

## Surface inventory

### Entry and orientation surfaces
- Current role: First-contact orientation for the repo and workspace install flow is split across `README.md` (what this repo is), `devspace.yaml` (how operators actually provision/repair/destroy), and `install.sh` (the real execution path users run in the workspace).
- Primary audiences:
  - New workspace users trying to get to a working shell quickly.
  - Maintainers/operators running `devspace` lifecycle pipelines.
  - Implementers/agents who must respect bare-hub + worktree semantics before making changes.
- Current assets:
  - `README.md` = 2 lines. Evidence supports hypothesis (1): onboarding is too thin to route users to the right first command.
  - `devspace.yaml` = 95 lines with operational pipeline definitions (`provision`, `doctor`, `repair`, `destroy`, `verify-ssh`) but no clear top-level entry funnel from `README.md`.
  - `install.sh` = 199 lines and currently carries most practical context: argument parsing, install source detection, validation/safety checks, state writes, shell helper setup, zsh plugin/bootstrap install, symlink orchestration, and opencode bootstrap.
- Documentation gaps:
  - No explicit “start here” path that tells a first-time user whether to run `devspace run-pipeline provision`, `bash install.sh`, or a runbook command.
  - No top-level cross-linking from `README.md` to runbooks where the actual operational guidance exists.
  - Core behavioral assumptions (hub root vs checkout path, install branch persistence, navigation helpers) are discoverable only after reading deeper docs/scripts.
- Readability/refactor hotspots:
  - `install.sh` is a readability hotspot validated by evidence (hypothesis 3). It interleaves setup policy, environment/materialization logic, and user-facing messaging in one orchestration-heavy script.
  - Abstraction levels are mixed (high-level flow + low-level install mechanics together), making change review expensive and raising accidental regression risk.
- Risk of change:
  - `README.md`: low runtime risk, medium coordination risk if wording diverges from canonical runbooks.
  - `devspace.yaml`: medium-high operational risk; command semantics are user-visible and pipeline-sensitive.
  - `install.sh`: medium-high risk due to broad side effects and integration with install-env persistence + shell bootstrapping.
- Recommended slice type:
  - Slice A (docs-first tracer): add entry routing and explicit first-command guidance.
  - Slice B (behavior-preserving refactor): extract focused helpers from `install.sh` while holding existing install/devspace tests as characterization guards.

### Operational and runbook surfaces
- Current role: These runbooks are the practical operational source of truth once users get past entry points. They describe lifecycle actions, navigation conventions, and host/pod responsibilities.
- Primary audiences:
  - Host-side operators responsible for provisioning and mounting the workspace.
  - Pod-side users performing daily worktree/repo operations.
  - Contributors/agents needing policy-conformant operational context.
- Current assets:
  - `docs/superpowers/runbooks/devspace-bare-hub-usage.md` = 152 lines with detailed operational behavior and hub usage constraints.
  - `docs/superpowers/runbooks/devspace-workspace-lifecycle.md` = 115 lines covering lifecycle pipelines and workspace command patterns.
  - `docs/superpowers/runbooks/host-bare-hub-bootstrap.md` = 133 lines describing host-vs-pod setup and bootstrap flow.
  - Evidence validates hypothesis (2): runbook content is strong but buried behind weak entry routing.
- Documentation gaps:
  - Cross-linking is sparse: no reliable “if you are on host, go here / if in pod, go here” route from top-level docs.
  - Content overlap between the two DevSpace runbooks around lifecycle semantics, navigation helpers, and install-branch behavior increases drift risk.
  - Host bootstrap includes manual flows that can become outdated relative to managed wrappers (`bin/clone-repo`, `bin/new-worktree`).
- Readability/refactor hotspots:
  - Duplication pressure between runbooks causes maintenance overhead and contradictory wording risk.
  - Mixed “concept explanation” and “step-by-step procedure” sections reduce scanability for urgent operations.
  - Context switching between HOST and POD instructions is cognitively heavy where boundaries are not explicit.
- Risk of change:
  - Runtime risk low (docs-only), but coordination risk medium-high because these runbooks currently carry guidance missing from `README.md`.
  - Incorrect consolidation could remove safety caveats; edits need explicit host/pod boundary preservation.
- Recommended slice type:
  - Documentation consolidation with an index-first structure and explicit audience routing.
  - De-duplicate shared semantics; keep one canonical definition per concept and cross-link from other runbooks.

### Developer command and workflow surfaces
- Current role: Command entry points in `bin/*` plus shared helpers in `scripts/lib/*` implement managed worktree/lane lifecycle semantics and enforce refusal-style safety guarantees.
- Primary audiences:
  - Developers/operators invoking `bin/new-worktree`, `bin/retire-worktree`, `bin/dre`, `bin/dwt`.
  - Agents/scripts that require deterministic lane/worktree metadata and install-branch coherence.
- Current assets:
  - Command surfaces: `bin/new-worktree` (177), `bin/retire-worktree` (232), `bin/dre` (139), `bin/dwt` (151), plus `bin/clone-repo` (87).
  - Core helpers: `scripts/lib/managed-worktree-cleanup.sh` (269), `scripts/lib/hub-repo-core.sh` (250), `scripts/lib/managed-lane-registry.sh` (178), `scripts/lib/worktree-env.sh` (138).
  - Small focused exemplars (hypothesis 5 partially validated): `resolve-install-target.sh` (20), `resolve-managed-repo-root.sh` (22), `read-install-env.sh` (24), `validate_hub_repo_root.sh` (24), `validate_install_source_tree.sh` (39).
  - Test contracts exist for several paths, but not all operational expectations are discoverable from docs.
- Documentation gaps:
  - Workflow intent is distributed across command scripts, helper libraries, and test assertions rather than a concise operator-facing workflow map.
  - It is hard to infer “which command should I run in which context” without reading code and tests.
  - Known baseline failures are not surfaced as documented caveats in the audit-ready workflow context.
- Readability/refactor hotspots:
  - `bin/new-worktree` validated as next hotspot (hypothesis 4): CLI parsing + repo inference + branch/worktree/env/lane updates in one command.
  - `bin/retire-worktree` and `managed-worktree-cleanup.sh` have high orchestration density around destructive flows.
  - `hub-repo-core.sh` and `managed-lane-registry.sh` show mixed abstraction levels and naming pressure from carrying multiple responsibilities.
  - `bin/dre` and `bin/dwt` are moderate-size navigation wrappers with potential duplication pressure in argument/context handling.
- Risk of change:
  - Medium-high due to lane/worktree safety constraints and destructive cleanup operations.
  - Elevated regression probability if refactors are not driven by characterization tests.
- Recommended slice type:
  - Slice A: workflow documentation map (commands → helpers → governing tests).
  - Slice B: targeted behavior-preserving readability refactors on top hotspots, one file family at a time, gated by existing and expanded characterization tests.

### Agent-facing guidance and orientation surfaces
- Current role: Canonical agent governance and operational contract definition for delegation, routing, lane safety, and ownership boundaries.
- Primary audiences:
  - Maestro (router/delegator responsibilities).
  - Senior/junior implementers and reviewers (execution + verification responsibilities).
  - Any subagent consuming packet schema, session metadata, and policy anchors.
- Current assets:
  - `.config/opencode/AGENTS.md` = 604 lines and 59 heading anchors (comprehensive policy body).
  - `docs/superpowers/templates/subagent-handoff-templates.md` supports packet construction in practice.
  - `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md` preserves prior governance review context.
  - Doc-contract tests enforce required policy anchors and reduce accidental drift.
- Documentation gaps:
  - No concise “agent start here” route for first-time readers before entering dense policy sections.
  - Supporting templates/review records assume pre-existing packet vocabulary and can be hard to use cold.
  - Safety-critical concepts are present but not layered by reader maturity (newcomer vs experienced contributor).
- Readability/refactor hotspots:
  - Primary hotspot is orientation density (information architecture), not algorithmic complexity.
  - Large policy file size makes operational lookups slower and increases wrong-section interpretation risk.
- Risk of change:
  - High: wording/anchor changes can break tests and cross-agent coordination guarantees.
  - Recommended edits should prefer additive navigation overlays over deep in-place policy rewrites.
- Recommended slice type:
  - Docs-only orientation/index overlay with explicit routes by role.
  - Keep policy edits narrow and evidence-backed; if needed, label as supporting policy nudge behind operational evidence.

## Documentation gap inventory

| Gap ID | Surface | Affected audiences | Current evidence | Likely fix type | Priority bucket |
| --- | --- | --- | --- | --- | --- |
| DG-1 | Entry and orientation | New users; first-time operators | `README.md` contains only 2 lines and does not route to install/lifecycle paths | Add top-level onboarding path with first-command sequence | P1 — foundation blocker |
| DG-2 | Entry and orientation | Operators; maintainers | `devspace.yaml` has 95 lines of actionable lifecycle pipelines but no obvious discoverability from README | Cross-link `README.md` to lifecycle commands/runbooks | P1 — foundation blocker |
| DG-3 | Entry and orientation | Implementers; agents | Critical install semantics mostly embedded in `install.sh` (199 lines) rather than front-door docs | Add entry-level concept map: hub root vs checkout vs worktree | P1 — foundation blocker |
| DG-4 | Operational and runbooks | Pod users; maintainers | Overlap across `devspace-bare-hub-usage.md` (152) and `devspace-workspace-lifecycle.md` (115) for lifecycle and navigation semantics | Consolidate duplicate sections; define canonical source + links | P2 — structural improvement |
| DG-5 | Operational and runbooks | Host operators | `host-bare-hub-bootstrap.md` includes manual flows that can drift from wrapper commands (`bin/clone-repo`, `bin/new-worktree`) | Align host runbook around wrapper-first flow, keep manual fallback explicit | P2 — structural improvement |
| DG-6 | Operational and runbooks | All audiences crossing host/pod boundary | Current docs do not consistently route readers by environment context | Add explicit HOST/POD decision points and reciprocal links | P2 — structural improvement |
| DG-7 | Developer command/workflow | Developers; maintainers | Workflow knowledge is spread across commands, helpers, and tests; no concise workflow map | Add command-to-helper-to-test map doc | P2 — structural improvement |
| DG-8 | Developer command/workflow | Contributors modifying scripts | High orchestration density in major scripts makes safe edit boundaries hard to discover quickly | Add hotspot index with likely refactor seam candidates | P2 — structural improvement |
| DG-9 | Developer command/workflow | CI/maintenance owners | Pre-existing failures noted (`test_workspace_repair.sh`, `test_workspace_navigation_commands.sh`) are not surfaced as baseline caveats in audit-oriented docs | Add known-baseline-failures note in audit/workflow docs | P2 — structural improvement |
| DG-10 | Agent-facing guidance | First-time agent contributors | `AGENTS.md` is comprehensive (604 lines, 59 anchors) but lacks an obvious short entry route | Add role-based “start here” orientation overlay | P2 — structural improvement |
| DG-11 | Agent-facing guidance | Agents using templates/review records | Templates assume packet/policy vocabulary familiarity without warm-up context | Add glossary or quick vocabulary bridge in orientation docs | P3 — opportunistic clarity |
| DG-12 | Cross-surface navigation | All audiences | Strong content exists but routing between entry docs, runbooks, workflows, and policy is fragmented | Add a single documentation index spanning entry/runbook/workflow/agent docs | P1 — foundation blocker |

## Clean-code hotspot inventory

| Hotspot ID | Surface/files | Observed symptoms | Supporting evidence (line counts, test output) | Likely refactor shape | Risk of change |
| --- | --- | --- | --- | --- | --- |
| HC-1 | `install.sh` | Mixed abstraction levels; one script performs install orchestration, policy checks, state writes, and user messaging | 199 lines; evidence validates install readability hotspot (hypothesis 3) | Extract cohesive helper functions/files by phase (parse/resolve/validate/materialize), preserve behavior contracts | Medium-high |
| HC-2 | `bin/new-worktree` | CLI parse + repo inference + branch/worktree creation + env/lane registry updates in one flow; naming pressure from broad scope | 177 lines; hypothesis 4 validated as next hotspot | Split into smaller flow stages with explicit phase naming; keep command UX stable | Medium-high |
| HC-3 | `bin/retire-worktree` + `scripts/lib/managed-worktree-cleanup.sh` | Destructive cleanup path has high orchestration density and mixed responsibility boundaries | `bin/retire-worktree` 232 lines + cleanup helper 269 lines | Separate decision/validation from execution/cleanup phases; tighten guard naming and intent-revealing function boundaries | High |
| HC-4 | `scripts/lib/hub-repo-core.sh` | Multiple core operations coupled into one large helper; mixed low/high-level concerns | 250 lines; central dependency for command surfaces | Partition by cohesive operation families and simplify call paths | Medium-high |
| HC-5 | `scripts/lib/managed-lane-registry.sh` | Registry read/write/update semantics packed together; difficult to reason about invariants quickly | 178 lines with lane-safety significance | Isolate registry mutation helpers and improve naming around lane invariants | Medium-high |
| HC-6 | `bin/dre` + `bin/dwt` | Moderate-size navigation commands with potential duplication pressure in context resolution and messaging patterns | `bin/dre` 139 lines; `bin/dwt` 151 lines | Identify shared navigation resolution seam and extract only if behavior parity can be proven | Medium |
| HC-7 | Workflow verification baseline | Characterization safety net is present but currently noisy due unrelated pre-existing failures, increasing refactor confidence cost | Pre-existing failures observed: `test_workspace_repair.sh` FAIL (repair should recreate non-main install worktree); `test_workspace_navigation_commands.sh` FAIL (dre should print exact runnable metadata repair command) | Record baseline failures explicitly and keep them out-of-scope for hotspot refactor slices unless separately approved | Medium (process risk) |

## Prioritized follow-on slices

Prioritization uses the approved four-factor model: audience impact, task-blocking severity, change leverage, and implementation safety.

| Slice | Audience impact | Task-blocking severity | Change leverage | Implementation safety | Priority |
| --- | --- | --- | --- | --- | --- |
| Docs foundation: top-level orientation | High (all 3 audiences) | High (onboarding + safe usage) | High (routes all downstream docs) | High (local/reversible docs edits) | P1 |
| Documentation consolidation: runbooks | High (all 3 audiences) | Medium-high (navigation friction) | High (reduces overlap/drift) | High (doc-only) | P2 |
| Refactor: install.sh structure | Medium-high (maintainers + operators) | Medium-high (maintenance + safe edits) | High (central install flow) | Medium (script refactor with tests) | P2 |
| Refactor: worktree/navigation path | Medium (maintainers + agents) | Medium (less entry-blocking) | Medium-high (shared command family) | Medium-low (destructive-flow sensitivity) | P3 |
| Docs navigation: agent orientation | Medium (agent-heavy audience) | Medium-low (less daily blocking) | Medium (lookup speed + reduced misread risk) | High (additive doc overlay) | P3 |
| Small guidance nudge for docs/readability expectations | Low-medium (indirect, contingent) | Low (non-blocking) | Medium (if ambiguity persists) | Medium (policy wording sensitivity) | Supporting policy nudge |

### P1 — foundation blockers

1) **Docs foundation: top-level orientation**
- Primary surfaces/files affected: `README.md`, `devspace.yaml`, `install.sh`, plus cross-links to `docs/superpowers/runbooks/devspace-workspace-lifecycle.md` and `docs/superpowers/runbooks/devspace-bare-hub-usage.md`.
- Slice type: `doc-only`.
- Why it belongs here: first-contact routing is currently the broadest blocker (`README.md` is too thin), and this slice improves onboarding and safe command selection for every audience before any deeper changes.
- Intentionally leaves for later: runbook de-duplication details and shell refactor work.

### P2 — important structural improvements

2) **Documentation consolidation: runbooks**
- Primary surfaces/files affected: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`, `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`, `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`.
- Slice type: `doc-only`.
- Why it belongs here: content quality is strong but discoverability and overlap issues create recurring friction; consolidating canonical sections gives broad leverage without code risk.
- Intentionally leaves for later: deeper content expansion and non-essential wording normalization.

3) **Refactor: install.sh structure**
- Primary surfaces/files affected: `install.sh`, `tests/install/*` (and any directly related characterization checks).
- Slice type: `refactor-only`.
- Why it belongs here: `install.sh` concentrates mixed responsibilities in one high-touch script; a behavior-preserving structural refactor reduces maintenance cost and future change risk with existing tests as safety rails.
- Intentionally leaves for later: command-family refactors (`new-worktree`/`retire-worktree`) and broad helper-library decomposition.

### P3 — opportunistic cleanups

4) **Refactor: worktree/navigation path**
- Primary surfaces/files affected: `bin/new-worktree`, `bin/retire-worktree`, `scripts/lib/managed-worktree-cleanup.sh`, `scripts/lib/hub-repo-core.sh`.
- Slice type: `refactor-only`.
- Why it belongs here: high-value cleanup for maintainability, but less blocking than entry docs and install-path clarity; sequencing later limits risk while earlier slices reduce operational confusion.
- Intentionally leaves for later: deeper helper decomposition (`managed-lane-registry.sh`, optional `dre`/`dwt` seam extraction).

5) **Docs navigation: agent orientation**
- Primary surfaces/files affected: `.config/opencode/AGENTS.md` (additive orientation overlay only), `docs/superpowers/templates/`, `docs/superpowers/review-records/` references.
- Slice type: `doc-only`.
- Why it belongs here: improves policy lookup and newcomer orientation for agent audiences, but is less task-blocking for day-to-day human onboarding than P1/P2 docs work.
- Intentionally leaves for later: substantive policy rewrites or anchor changes in canonical governance text.

### Supporting policy nudge (subordinate to doc/refactor evidence)

6) **Small guidance nudge for docs/readability expectations**
- Primary surfaces/files affected: narrowly scoped sections in `.config/opencode/AGENTS.md` and/or related agent guidance files.
- Slice type: `supporting policy nudge`.
- Why it belongs here: only justified if repeated ambiguity remains after P1-P3 doc/refactor slices; this is a reinforcement step, not a primary fix.
- Intentionally leaves for later: any broad policy restructuring, new enforcement machinery, or anchor-heavy rewrites.

## Sequencing rationale

1. **Entry-point/docs improvements first:** first-contact confusion is currently the widest blocker (`README.md` is minimal and does not route readers). Improving entry docs first reduces misuse risk before touching operational code.
2. **Runbook consolidation before code refactors:** runbooks already contain strong operational detail, but overlap and weak routing create discovery friction. Consolidating canonical guidance first lowers documentation drift while upcoming refactors happen.
3. **`install.sh` refactor before worktree command refactors:** `install.sh` is a concentrated 199-line hotspot with mixed responsibilities and high change frequency, so it yields more immediate maintenance leverage than distributed worktree hotspots.
4. **Agent orientation + policy nudges last:** orientation overlays and any policy nudge should follow docs/refactor stabilization so wording reflects settled structure; these are useful but less blocking for daily user/operator flow.

Pre-existing unrelated baseline failures observed during evidence collection (`test_workspace_repair.sh` and `test_workspace_navigation_commands.sh`) should remain tracked as separate remediation streams, not coupled to this follow-on sequencing unless explicitly approved.

**User Check-in 2:** choose which approved follow-on slice to plan/implement first (for example, Slice 1 P1 docs foundation, Slice 2 runbook consolidation, or Slice 3 `install.sh` refactor).
