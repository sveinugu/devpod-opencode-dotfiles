# Orchestration Agent Bootstrap and Harness Install Design

Date: 2026-08-16  
Status: Draft for user approval

Related:
- `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`
- `.config/opencode/AGENTS.md`
- `scripts/lib/install/materialize.sh`
- `scripts/lib/launch-opencode-nono.sh`
- `scripts/provision-workspace.sh`

## Problem

The current install flow mixes three different concerns:

1. branch-aware workspace/home symlink materialization,
2. skill installation,
3. plugin installation.

Current state snapshot:

```text
install.sh
├── branch-aware home/worktree materialization
├── local skill installation via repo-backed OpenCode config paths
└── installer-style plugin regeneration into repo-backed OpenCode config paths
```

That mix currently creates two concrete problems:

- local skill installs from `.config/opencode` can materialize stale content under repo-backed `.config/opencode/.agents/...`, which is the wrong discovery surface for the intended workflow,
- plugin installation uses two different mechanisms: ordinary OpenCode npm plugin activation through `opencode.jsonc`, and installer-driven plugins such as `@bybrawe/opencode-loop` that materialize extra files into the OpenCode config tree.

The design must support the intended operator workflow:

- **Dev:** run `install.sh` in-pod against the active hub branch/worktree,
- **Test:** provision against a hub branch/worktree,
- **Prod:** rebase `main` and provision.

The agent runtime remains primary. `install.sh` must therefore continue to support both in-pod runs and provision-driven runs, while reducing privileged operations to the narrowest set still required.

## Goals

### Primary goals

- Keep `install.sh` as a first-class branch-apply workflow for both in-pod and provision-driven runs.
- Move skills to a harness-invariant project-local surface.
- Keep ordinary OpenCode npm plugin selection authoritative in `opencode.jsonc`.
- Add an explicit contract for installer-style harness/plugin installs that materialize extra files.
- Avoid per-user sudo-based skill/plugin installation.
- Keep only the minimum privileged operations required for cross-user home wiring.

### Supporting and future-facing goals

- Preserve room for future harnesses beyond OpenCode without reopening the whole layout.
- Retain a reusable general sudo+nono helper in scope as preparatory infrastructure, even if the chosen install model no longer depends on it for skill/plugin materialization.

## Non-goals

- Do not implement runtime/plugin enforcement in this slice.
- Do not redesign OpenCode's native plugin cache behavior.
- Do not require committed generated installer-plugin outputs.
- Do not require a dedicated per-user agent skill-install helper in the chosen approach.

## Chosen approach

Use a split model with one project-local harness surface and two OpenCode-specific install modes:

1. **Project-local skills** live at top-level `.agents/skills/` and are tracked by top-level `skills-lock.json`.
2. **Ordinary npm OpenCode plugins** remain declared in `.config/opencode/opencode.jsonc` and are resolved by OpenCode into user cache directories.
3. **Installer-managed harness installs** are declared in top-level `harness-installs.jsonc`; `install.sh` refreshes them by running each entry's `uninstall` command and then `install` command, verifying the declared outputs afterward.

Under this approach, project-local skill installation and installer-plugin regeneration run as the normal workspace user inside the repo/worktree. Sudo remains limited to branch-sensitive cross-user home wiring, plus separately useful reusable infrastructure.

## Design details

### 1. Harness-invariant local surface

Use a top-level harness-neutral surface for local agent assets:

- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.agents/skills/`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/skills-lock.json`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/harness-installs.jsonc`

Rationale:

- `.agents/skills` is branch-aware and works naturally with the user's `install.sh` workflow.
- `skills-lock.json` already matches the shape that `skills add` generates and should therefore remain alongside the harness-local skill tree rather than inside `.config/opencode`.
- `harness-installs.jsonc` belongs beside `skills-lock.json`, not under `.config/opencode`, because the intent is broader than OpenCode-only future use.

### 2. Project-local skills

Skill installation changes from repo-backed `.config/opencode/.agents/...` to top-level `.agents/skills/...`.

Required behavior:

- run `skills add` from the repo/worktree root, not from `.config/opencode`,
- use local/project install semantics so the materialized skill tree lands in top-level `.agents/skills/`,
- keep top-level `skills-lock.json` as the committed lock/provenance artifact,
- have `install.sh` include the matching lock-driven install/refresh path via `npx -y skills experimentall_install` so project-local skills can be reconstructed from the committed top-level lock artifact,
- allow `.agents/skills` to be partly committed where the repo intentionally owns local/project skills, while still allowing generated skill installs under that tree.

The design does **not** require `~/.agents` to be the primary discovery path.

### 3. New subagent skill-path orientation

If this slice introduces any new subagent prompt files (for example under `.config/opencode/agents/`), each new subagent must include explicit path pointers to the relevant skill roots so the bootstrap/install model remains discoverable during direct subagent interaction.

Required prompt-path pointers:

- canonical project-local skill root: `/workspaces/dotfiles/work/devspace-model-credential-phasing/.agents/skills/`
- repo-backed OpenCode-config view for `agent`: `/home/agent/.config/opencode/.agents/skills/`
- repo-backed OpenCode-config view for `vscode`: `/home/vscode/.config/opencode/.agents/skills/`

Clarification:

- these prompt pointers are orientation aids for humans/agents and review, not a claim that repo-backed `.config/opencode/.agents/...` remains the canonical install target,
- the canonical install target in this design remains top-level `.agents/skills/`,
- the home-scoped `.config/opencode/.agents/skills/` paths remain relevant as runtime-visible views during bootstrap, install verification, and migration cleanup.

### 4. Ordinary npm OpenCode plugins

For ordinary npm OpenCode plugins, `.config/opencode/opencode.jsonc` remains the authoritative runtime plugin manifest.

Examples in current scope:

- `oc-plugin-karpathy-guidelines@latest`
- `superpowers@git+https://github.com/obra/superpowers.git`

Expected behavior:

- OpenCode reads the plugin array from `opencode.jsonc`.
- OpenCode installs/caches those packages under the runtime user's cache tree (for example `~/.cache/opencode/node_modules`).
- The design must treat that cache location as runtime state, not as a committed repo surface.

Important constraint:

- `.config/opencode/package.json` and `.config/opencode/package-lock.json` are **not** the authoritative runtime plugin manifest for ordinary OpenCode npm plugins.
- They may remain committed when needed for repo-local OpenCode plugin dependencies, local plugin authoring dependencies, or other repo-local config-dir JavaScript dependencies, but they must not become a second manually maintained source of truth for which ordinary runtime plugins are enabled.
- The implementation should make that secondary role explicit so future maintainers understand why `.config/opencode/package.json` exists even when `opencode.jsonc` remains the runtime authority.

### 5. Installer-managed harness installs

Some packages require more than ordinary OpenCode plugin declaration. `@bybrawe/opencode-loop` is the motivating example.

Observed installer behavior for `npx -y @bybrawe/opencode-loop`:

- copies a plugin file to `~/.config/opencode/plugins/opencode-loop.js`,
- copies command markdown files to `~/.config/opencode/commands/loop*.md`.

Because `~/.config/opencode` is symlinked to the repo-backed `.config/opencode`, those outputs materialize inside the active branch/worktree and must be treated as generated install outputs.

Create a top-level manifest at:

- `/workspaces/dotfiles/work/devspace-model-credential-phasing/harness-installs.jsonc`

Manifest contract:

- one entry per installer-managed package/install surface,
- each entry declares:
  - `name`
  - `workingDirectory`
  - `install`
  - `uninstall`
  - `outputs`

Illustrative shape:

```jsonc
{
  "installs": [
    {
      "name": "opencode-loop",
      "workingDirectory": ".config/opencode",
      "install": ["npx", "-y", "@bybrawe/opencode-loop"],
      "uninstall": ["npx", "-y", "@bybrawe/opencode-loop", "--uninstall"],
      "outputs": [
        ".config/opencode/plugins/opencode-loop.js",
        ".config/opencode/commands/loop-help.md",
        ".config/opencode/commands/loop.md"
      ]
    }
  ]
}
```

Required install contract:

- `install.sh` processes each manifest entry by running `uninstall`, then `install`,
- execution happens from the declared `workingDirectory`,
- output verification happens after install,
- no sudo is used for this regeneration path.

The manifest itself is committed repo state. The listed outputs are generated install state and must remain git-ignored rather than tracked.

Generated outputs for installer-managed installs are intentionally git-ignored and refreshed on each install run.

### 6. Privilege boundary

Chosen privilege model:

- **No sudo required for:**
  - project-local skill installation into `.agents/skills/`,
  - installer-managed output regeneration into repo-backed `.config/opencode/plugins/` and `.config/opencode/commands/`,
  - ordinary OpenCode npm plugin cache population.
- **Sudo remains required for:**
  - cross-user home symlink switching/wiring tied to the active hub branch/worktree,
  - existing root-owned secure launch infrastructure,
  - future reusable harness infrastructure where a root-owned helper is still the right boundary.

This inherits the broader two-user and constrained-helper security direction from `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`; this slice narrows that boundary so skill and installer-managed plugin materialization stay outside the privileged path.

The design keeps a reusable general sudo+nono helper in scope because it remains useful for future harness support even though the chosen skill/plugin materialization path no longer depends on it.

### 7. General reusable sudo+nono helper

Retain a generalized reusable helper in the design at:

- repo source: `/workspaces/dotfiles/work/devspace-model-credential-phasing/scripts/lib/run-with-sudo-nono.sh`
- installed helper: `/usr/local/libexec/dotfiles-run-helper`

Purpose in this slice:

- prepare a reusable, root-owned, validated helper surface for future harness/runtime work,
- keep Opencode-specific secure launch logic factored cleanly from future generic harness execution needs,
- refactor the existing OpenCode wrapper/launch path to use that general helper rather than keeping a permanently special-case wrapper path.

Required helper interface contract:

| Surface | Requirement |
| --- | --- |
| Inputs | The helper must accept a validated target program plus argument vector, and must not depend on hidden interactive shell state. |
| Working directory | The caller must be able to run the helper from a declared repo/worktree path so install steps remain branch-aware. |
| Environment | Any required environment inputs must be explicit and documented; ambient credential leakage is out of contract. |
| Exit behavior | Exit `0` means the delegated command completed successfully; non-zero means validation failure, launch failure, or delegated command failure. Child exit status should be preserved when practical. |
| Failure mode | Missing prerequisites must fail closed rather than silently skipping privilege or sandbox checks. |

This helper is preparatory infrastructure in the chosen approach, not the primary mechanism for project-local skill installation or installer-plugin regeneration.

### 8. Helper + local skill for future maintenance

The design should include both:

1. **Helper surface** to run the declared installer-managed refresh flow correctly from `harness-installs.jsonc`.
2. **Local project skill** to explain the install model for future humans/agents.

Intent:

- the helper prevents procedural mistakes,
- the skill preserves the reasoning and expected maintenance flow when details are forgotten later,
- the maintenance skill should point future readers back to `.config/opencode/AGENTS.md` for design-approval and contract-test expectations.

### 9. Cleanup and conformance task

The implementation plan must include a separate cleanup/conformance task after the new layout is introduced.

Required cleanup scope:

- remove or quarantine stale/non-conforming repo content produced by the old layout, including stale `.config/opencode/.agents/...`-style materialization and other now-wrong generated surfaces,
- account for currently uncommitted generated content that does not match the new contract,
- clean up `.gitignore` rules so committed vs generated surfaces are explicit,
- make the cleanup task verification-focused so it can prove the repo no longer depends on the deprecated skill/plugin materialization paths.

Definition of stale for this slice:

- any generated skill content under repo-backed `.config/opencode/.agents/`, `.config/opencode/skills/`, or `.config/opencode/skills-lock.json`,
- any generated plugin/command output under `.config/opencode/plugins/` or `.config/opencode/commands/` that is not declared by the current `harness-installs.jsonc` manifest outputs,
- any ignore rule that still treats the deprecated layout as canonical after the new top-level `.agents/skills` + `skills-lock.json` contract is introduced.

This cleanup task is separate from the core install-flow refactor so the resulting diff and verification story remain easier to review.

## Target artifacts

### New or moved repo artifacts

- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.agents/skills/`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/skills-lock.json`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/harness-installs.jsonc`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.agents/skills/harness-install-maintenance/SKILL.md`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/scripts/lib/install/install-project-skills.sh`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/scripts/lib/install/run-harness-installs.sh`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/scripts/lib/run-with-sudo-nono.sh`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/scripts/lib/opencode-wrapper.sh`

### Existing repo artifacts to update

- `/workspaces/dotfiles/work/devspace-model-credential-phasing/install.sh`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/scripts/lib/install/materialize.sh`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/scripts/lib/launch-opencode-nono.sh`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/scripts/provision-workspace.sh`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.config/opencode/opencode.jsonc`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.config/opencode/agents/*.md` for any new subagent introduced by this slice, so each new subagent includes the required skill-path pointers
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.config/opencode/package.json`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.config/opencode/package-lock.json`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.config/opencode/.gitignore`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.gitignore`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/Dockerfile`

### Runtime / installed-path targets

- `/usr/local/libexec/dotfiles-run-helper`
- `/home/agent/.config/opencode`
- `/home/vscode/.config/opencode`
- `/home/agent/.cache/opencode/node_modules`
- `/home/vscode/.cache/opencode/node_modules`

### Installer-generated, git-ignored output surfaces

- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.config/opencode/plugins/`
- `/workspaces/dotfiles/work/devspace-model-credential-phasing/.config/opencode/commands/`

## Verification strategy

| Command | Expected pass criteria | Validates |
| --- | --- | --- |
| `bash tests/pod-outside-nono/test_install_local_source_contract.sh` | exits `0`; proves `install.sh` sources local skills from repo root/worktree context rather than repo-backed `.config/opencode/.agents/...` | branch-aware install source selection |
| `bash tests/pod-outside-nono/test_project_local_skills_contract.sh` | exits `0`; proves skills materialize into top-level `.agents/skills/` and top-level `skills-lock.json` is the lock/reconstruction authority | project-local skill contract |
| `bash tests/pod-outside-nono/test_harness_installs_contract.sh` | exits `0`; proves each manifest entry runs uninstall+install from its declared `workingDirectory` and verifies declared outputs | installer-managed manifest contract |
| `bash tests/pod-outside-nono/test_generated_output_ignore_contract.sh` | exits `0`; proves installer-managed outputs are treated as generated and ignored rather than required committed files | generated-output ignore contract |
| `bash tests/pod-outside-nono/test_cleanup_conformance_contract.sh` | exits `0`; proves stale legacy materialization paths are no longer canonical and `.gitignore` matches the new split | cleanup and conformance contract |
| `bash tests/host/test_dockerfile_opencode_helper_contract.sh` | exits `0`; proves Dockerfile stages `/usr/local/libexec/dotfiles-run-helper` and the helper remains distinct from ordinary skill/plugin materialization | generic helper contract |

Verification expectations:

1. `install.sh` run from a worktree/root branch context installs skills from repo root into top-level `.agents/skills`, not from `.config/opencode` into stale `.config/opencode/.agents/...`.
2. Top-level `skills-lock.json` is the generated/maintained lock artifact for local skill installation, and `install.sh` includes the lock-driven `npx -y skills experimentall_install` reconstruction path.
3. Ordinary npm plugins remain declared in `.config/opencode/opencode.jsonc`; implementation does not repurpose `.config/opencode/package.json` as the authoritative runtime plugin manifest for those entries.
4. `.config/opencode/package.json` is documented and verified only as a repo-local dependency surface for local plugin/config-dir JavaScript dependencies.
5. `harness-installs.jsonc` drives uninstall+install refresh for installer-managed packages from the declared `workingDirectory`.
6. Installer-managed outputs appear in `.config/opencode/plugins/` and `.config/opencode/commands/` after refresh and are git-ignored.
7. Privileged operations remain limited to cross-user branch/home wiring plus reusable secure-launch infrastructure, not skill/plugin regeneration.
8. Dockerfile installs the reusable generic helper at `/usr/local/libexec/dotfiles-run-helper`, and the OpenCode wrapper/launch path is refactored to use it.
9. A distinct cleanup/conformance task removes stale generated content and aligns `.gitignore` with the new contract.
10. If the slice introduces new subagent prompt files, each new subagent includes explicit pointers to `/workspaces/dotfiles/work/devspace-model-credential-phasing/.agents/skills/`, `/home/agent/.config/opencode/.agents/skills/`, and `/home/vscode/.config/opencode/.agents/skills/`.

## Acceptance tests

| Acceptance test | Goal / artifact coverage |
| --- | --- |
| **Project-local skills contract** (`tests/pod-outside-nono/test_project_local_skills_contract.sh`) | validates top-level `.agents/skills` and top-level `skills-lock.json` as the canonical local skill surfaces |
| **Harness install manifest contract** (`tests/pod-outside-nono/test_harness_installs_contract.sh`) | validates `harness-installs.jsonc`, declared `workingDirectory`, uninstall+install refresh, and output verification |
| **Generated-output ignore contract** (`tests/pod-outside-nono/test_generated_output_ignore_contract.sh`) | validates `.gitignore` treatment for `.config/opencode/plugins/` and `.config/opencode/commands/` generated outputs |
| **Cleanup/conformance contract** (`tests/pod-outside-nono/test_cleanup_conformance_contract.sh`) | validates removal/quarantine of deprecated `.config/opencode/.agents/...`-style materialization and stale generated surfaces |
| **Dockerfile helper contract** (`tests/host/test_dockerfile_opencode_helper_contract.sh`) | validates `/usr/local/libexec/dotfiles-run-helper` as reusable helper infrastructure distinct from ordinary skill/plugin materialization |

## Risks and follow-up concerns

| Risk | Mitigation / follow-up |
| --- | --- |
| **OpenCode npm cache runtime path**: because ordinary npm plugins remain authoritative in `opencode.jsonc`, implementation may need a nono/runtime policy update for `~/.cache/opencode/node_modules` access. | Re-check the runtime profile against the security constraints in `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md` and add or reject cache-path allowances explicitly. |
| **Generated installer outputs may accumulate stale files without explicit cleanup.** | Keep both `uninstall` and `install` in the manifest contract and require the cleanup/conformance contract test to fail if undeclared outputs remain. |
| **Authority confusion around `.config/opencode/package.json`.** | Document it as a secondary repo-local dependency surface only, and keep contract tests focused on `opencode.jsonc` as the runtime plugin authority. |
| **Repo hygiene drift**: stale generated content and legacy `.gitignore` rules can make the new layout look more complex than it is if the cleanup/conformance task is skipped. | Treat cleanup/conformance as a separate required task with dedicated verification before the slice is considered done. |
| **Future harness expansion**: the top-level `harness-installs.jsonc` and `.agents` layout intentionally reserve space for future Claude or other harness-specific install entries. | Keep the manifest format and helper contract harness-neutral; require any future harness entry to add its own contract test rather than relying on convention alone. |

## User Check-in

**User Check-in:** confirm the following package/install authority split before plan and implementation:

- top-level `.agents/skills` + top-level `skills-lock.json` for project-local skills,
- `.config/opencode/opencode.jsonc` for ordinary npm OpenCode plugins,
- top-level `harness-installs.jsonc` for installer-managed packages refreshed on each install,
- installer-managed outputs git-ignored and regenerated without sudo,
- generic sudo+nono helper retained as reusable future-facing infrastructure,
- and any new subagent introduced in this slice explicitly points to `/workspaces/dotfiles/work/devspace-model-credential-phasing/.agents/skills/`, `/home/agent/.config/opencode/.agents/skills/`, and `/home/vscode/.config/opencode/.agents/skills/`.
