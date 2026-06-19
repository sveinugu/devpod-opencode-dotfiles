# DevSpace Bare-Hub Workspace Design

Date: 2026-05-23  
Status: Proposed  
Related: `docs/superpowers/explorations/2026-05-23-devpod-alternatives.md`, `docs/superpowers/plans/2026-05-21-bare-hub-manager.md`

## Executive Summary

This design defines a DevSpace-based replacement for the earlier DevPod-centered bare-hub-manager workflow. The top-level workspace remains a bare-hub manager rooted in the dotfiles/OpenCode-policy repository, but the workspace itself becomes cluster-native: a persistent Kubernetes workspace pod with one PVC, thin DevSpace orchestration, explicit provisioning, and host-pull backup/export.

The core direction is intentionally simple. DevSpace is used as the launcher, connector, and thin workflow wrapper. The real workspace behavior stays in ordinary repo-owned shell scripts. Provisioning is explicit, not hidden in normal startup. The top-level dotfiles repo remains the only authority for `/home/vscode` configuration through `install.sh`, while child repos under `repos/*` use the same bare-hub/worktree model without taking over home-directory authority.

The design covers the full intended workflow replacement, but it separates implementation scope into phases. Phase 1 focuses on the durable workspace, top-level hub bootstrap, thin DevSpace CLI surface, and public child-repo onboarding. Phase 2 adds the periodic backup staging and host-pull backup flow that were already explored conceptually.

## Goals

- Replace the DevPod workflow end-to-end with a DevSpace-based workspace flow.
- Preserve the bare-hub-manager model and explicit worktree-based editing rules.
- Keep the top-level dotfiles/OpenCode-policy repo as the workspace anchor and `/home/vscode` authority.
- Use cluster-native persistent storage instead of host-mounted source.
- Keep the user-facing system understandable: prebuilt image, shell scripts, and thin DevSpace wrappers.
- Support terminal-first use, with SSH/PyCharm as secondary access.
- Support child repo onboarding under `repos/*` using the same managed bare-hub conventions.
- Preserve a host-pull backup/export model that survives cluster loss better than PVC-only recovery.

## Non-Goals

- Do not introduce a full workspace platform beyond the needs of 1 fixed workspace in v1.
- Do not rely on DevSpace file sync or pod replacement as the core durability model.
- Do not implement broker/GitHub App integration in this spec.
- Do not require private-repo bootstrap in v1.
- Do not make child repos authorities for `/home/vscode` config.
- Do not require Helm packaging in v1.

## Supersedes Boundary

This design supersedes only the earlier assumptions that depended on host-mounted DevPod workspace deployment.

### Replaced assumptions

- host-first bootstrap of the editable workspace into a host directory mount
- host-mounted source as the workspace source of truth
- DevPod as the runtime and workspace launcher
- the assumption that `/workspaces/dotfiles` is populated from a host directory mount

### Retained assumptions

- the bare-hub/worktree editing model
- the top-level dotfiles repo as the workspace anchor
- `install.sh` local-source behavior
- the canonical `state/` / `tmp/` separation intent
- host-pull backup direction as the preferred durability boundary

Unless this document explicitly replaces a bare-hub-manager assumption, anything not directly tied to host-mounted DevPod workspace deployment remains in force.

## Chosen Architecture

### Authoritative repo model

One normal local checkout of the dotfiles repo is the authoritative launcher/template repo. It contains:

- `devspace.yaml`
- Kubernetes manifests
- thin DevSpace pipeline wrappers
- workspace lifecycle scripts
- `install.sh`
- OpenCode policies and user config

The in-cluster top-level workspace is created as a fresh bare clone of that same GitHub repo.

### Workspace shape

- Kubernetes workload: `Deployment`
- Storage: one PVC
- PVC usage: separate directories on the same PVC mounted to:
  - `/workspaces/dotfiles`
  - `/home/vscode`
- Mount model: both paths are PVC subpaths on the same volume, not nested mounts
- Default working directory: `/workspaces/dotfiles/main`
- Image model: prebuilt, pinned image using the current Dockerfile as the basis
- Manifest style: plain kubectl manifests in v1
- Workspace exposure: no standalone Service in v1
- Access model: terminal-first; DevSpace-managed SSH as secondary access

### DevSpace role

DevSpace is intentionally thin. Its responsibilities are:

- deploy or start the workspace Deployment/PVC/pod
- attach terminal access
- provide DevSpace-managed SSH
- expose a harmonized CLI surface through thin pipelines
- avoid owning the actual bare-hub logic

The bare-hub logic remains in repo-owned shell scripts.

## Workspace Lifecycle

### Command surface

The v1 DevSpace command surface is:

- `devspace dev`
- `devspace run-pipeline provision`
- `devspace run-pipeline doctor`
- `devspace run-pipeline repair`
- `devspace run-pipeline destroy`

`reset` and `backup` are intentionally not part of the v1 command surface.

### `devspace dev`

`devspace dev` is the thin DevSpace wrapper for interactive access. In v1 it may create or start the workspace Deployment, PVC, and pod when needed, but it must not hide provisioning. If the workspace content is unprovisioned, `devspace dev` must refuse normal interactive use and tell the user to run `devspace run-pipeline provision`.

This keeps the workflow helpful without reintroducing hidden auto-bootstrap behavior.

### `provision`

`provision` is explicit and runs inside the workspace pod. The DevSpace wrapper must first ensure the Deployment, PVC, and pod exist and are running, then execute the provisioning script in-pod.

Provisioning is responsible for turning an empty or partially degraded durable workspace into a usable bare-hub workspace.

In v1, the top-level provision source/ref contract is:

- the source repository is the top-level dotfiles GitHub repo
- the authoritative bootstrap ref is `origin/main`
- v1 provision must refuse if `origin/main` does not exist
- v1 provision must refuse if an existing top-level `main/` path is present in a broken or detached state
- the initial attached `main` worktree is created from `origin/main`
- later phases may make the bootstrap ref configurable, but v1 must not

### `doctor`

`doctor` is included in v1 because it adds significant operational clarity for relatively low complexity. It is a host-side, read-only command and is intended to answer whether the workspace exists, is reachable, and looks provisioned.

In v1, `doctor` is human-readable only.

V1 `doctor` uses one flat required checklist rather than separate required and advisory categories.

The minimum v1 `doctor` checklist is:

- the workspace Deployment exists
- the workspace PVC exists
- the workspace pod is reachable
- the top-level `.bare` exists and is a usable bare Git directory
- the top-level `main` worktree exists and is attached from that bare repo
- `work/`, `repos/`, `state/`, and `tmp/` exist
- canonical `state/` and `tmp/` hub paths exist for the top-level `main` worktree
- `/home/vscode` symlinks point into the top-level dotfiles worktree as expected

Exit-code semantics in v1:

- exit 0: all required checks pass
- exit 1: one or more required checks fail
- exit 2: invalid CLI usage

V1 does not define advisory-only checks.

### `repair`

`repair` is the primary v1 recovery command. It is explicitly non-destructive.

`repair` must not delete existing worktrees, tracked files, untracked files, or user-home content under `/home/vscode`. Its role is to make a best effort to restore the managed workspace structure around the existing PVC contents.

In v1, `repair` may:

- recreate missing managed directories such as `work/`, `repos/`, `state/`, and `tmp/`
- recreate canonical `state/` and `tmp/` subdirectories if missing
- reattach or recreate the top-level `main` worktree if the top-level bare repo is valid and `main` is missing
- rerun `main/install.sh` to relink `/home/vscode` back to the default top-level `main` worktree
- preserve a non-`main` symlink target in `/home/vscode` when it still points to an existing top-level worktree and the user has intentionally repointed home config there

In v1, `repair` must refuse rather than guess when core workspace identity is ambiguous or invalid, including cases such as:

- invalid or unreadable top-level `.bare`
- conflicting path types at managed locations
- missing top-level repo identity that prevents safe reattachment of `main`

`repair` preserves existing uncommitted changes, dirty worktrees, live session data, and other extant PVC contents on a best-effort basis by not deleting them. It does not guarantee that previously corrupted files become valid; it guarantees only that the command itself is non-destructive and focuses on structural recovery.

### `reset`

`reset` is not implemented in v1.

The name is reserved for a possible future destructive in-place rebuild command once later phases define explicit preservation boundaries and durable backup/export paths that make such a command operationally useful.

In v1:

- use `repair` for non-destructive recovery
- use `destroy`, then `provision`, for a guaranteed clean rebuild from scratch

### `destroy`

`destroy` deletes both the workspace Deployment/pod and the PVC. It is the true from-scratch reset path and is especially useful during setup iteration and bootstrap debugging.

After `destroy`, the next `provision` behaves as a true first creation of the workspace. No preservation guarantees are made for workspace contents, `/home/vscode`, uncommitted work, live session data, or local state on the deleted PVC.

### `backup`

`backup` is not implemented in v1. It is deferred to phase 2.

## Bare-Hub Bootstrap Model

### Top-level repo bootstrap

The top-level dotfiles repo is the initial workspace anchor.

Provisioning uses:

- fresh GitHub clone during provision
- anonymous/public access in v1
- `git clone --bare` as the initial bootstrap shape
- `origin/main` as the only supported bootstrap ref in v1
- refusal if `origin/main` is absent

The provisioning script then:

1. creates or repairs the managed hub layout
2. writes the hub-root gitdir shim as needed
3. attaches `main`
4. creates `work/`, `repos/`, `state/`, and `tmp/`
5. runs `main/install.sh`

`main` is the required primary branch in v1.

### Why `git clone --bare`

This was chosen because it is the simplest first-create path, matches the existing bare-hub-manager direction, and is easy to explain. More explicit `init --bare` plus `fetch` logic is deferred unless later repair semantics require it.

### Hub semantics

The top-level hub root is administrative, not the normal editable entrypoint. Normal editing happens from:

- `/workspaces/dotfiles/main`
- `/workspaces/dotfiles/work/<branch-or-task>`

The same pattern applies recursively to child repos under `repos/*`.

### Canonical `state/` and `tmp/` mapping

The managed workspace uses one canonical durable root and one canonical disposable root:

- durable root: `/workspaces/dotfiles/state/`
- disposable root: `/workspaces/dotfiles/tmp/`

Each managed worktree maps to one canonical key beneath both roots.

Top-level examples:

- `/workspaces/dotfiles/state/hub/main/`
- `/workspaces/dotfiles/state/hub/work/<name>/`
- `/workspaces/dotfiles/tmp/hub/main/`
- `/workspaces/dotfiles/tmp/hub/work/<name>/`

Child repo examples:

- `/workspaces/dotfiles/state/repos/<repo>/<default-branch>/`
- `/workspaces/dotfiles/state/repos/<repo>/work/<name>/`
- `/workspaces/dotfiles/tmp/repos/<repo>/<default-branch>/`
- `/workspaces/dotfiles/tmp/repos/<repo>/work/<name>/`

The top-level workspace and all child repos must use this same mapping convention in v1.

### Shell navigation helper semantics

The shell-level navigation helpers are part of the managed workspace contract because they are the human-facing way to move between the default checkout and feature worktrees without guessing.

- `dhub` resolves the active installed top-level checkout from install state.
- `dre <repo>` resolves the managed child repo root under `repos/<repo>`.
- `dwt` works only from an existing managed repo context.

`dwt` has one explicit shortcut behavior in addition to named worktree resolution:

- `dwt` with no argument resolves the current repo's default checkout.
- `dwt <default-branch-name>` resolves that same current repo default checkout.
- `dwt <other-name>` resolves `work/<other-name>` inside the current managed repo context.

This shortcut is repo-specific. For the top-level hub, the reserved alias is `main`. For child repos, the reserved alias is the exact detected remote default branch name, such as `master`.

To keep that behavior unambiguous, the actual default branch name for a managed repo is reserved and must not be used as a feature worktree name. `new-worktree` must refuse creation of a worktree whose requested name matches that repo's default branch name.

### Managed bare-repo excludes for generated artifacts

Generated local artifacts such as `.envrc`, `.envrc.local`, `.envrc.bak.*`, and `.opencode/` should not rely on tracked repo `.gitignore` files in this model. They are local runtime artifacts, and the ignore mechanism in v1 is each bare repo's local exclude file at `<bare>/info/exclude`.

The default pattern set is maintained in tracked `scripts/lib/bare-excludes.list`, one pattern per line. Contributors update that file to change the managed default exclude policy.

`scripts/lib/ensure-bare-excludes.sh` reads that list and overwrites the target exclude file rather than appending to it. This gives explicit management paths deterministic reset semantics.

The application policy is intentionally role-based:

- the top-level `.bare` is managed infrastructure, so bootstrap/provision management paths may reapply the managed exclude set there;
- child repo bare directories are seeded with the managed exclude set at creation time, but later local edits to child `info/exclude` files are preserved.

Routine runtime commands such as worktree environment generation and new-worktree creation must not silently self-heal or rewrite exclude files. Drift for the top-level `.bare/info/exclude` should remain visible through verification, but mismatch is warning-only rather than a hard failure.

## `/home/vscode` and Install Model

### Authority boundary

Only the top-level dotfiles repo may drive `/home/vscode` configuration. Child repos under `repos/*` are managed workspaces only.

### Install model

`install.sh` remains symlink-first.

- Running it from `main` points `/home/vscode` config at `main`
- Running it from a feature worktree repoints the same symlinks to that worktree

This preserves the existing “live config from the active worktree” behavior and supports policy/config branch work in the top-level dotfiles hub.

### Persistence and lifecycle semantics

`/home/vscode` and `/workspaces/dotfiles` share one durable lifecycle. In practice, v1 uses one PVC, but the important user-facing behavior is:

- normal stop/start keeps both
- `repair` keeps both in place and attempts non-destructive structural recovery
- `destroy` deletes both by deleting the PVC

This intentionally makes non-pushed home-directory changes disposable when a workspace is truly destroyed.

## Child Repo Onboarding

### v1 scope

Child repo onboarding is included in v1, but kept narrow:

- implemented as an in-pod script path
- public repos only in v1
- private repo onboarding deferred until the GitHub App proxy/broker exists

### Behavior

The onboarding script creates a child bare hub under `repos/<name>` and applies the same managed layout conventions used by the top-level workspace:

- `repos/<name>/.bare`
- `repos/<name>/<default-branch>`
- `repos/<name>/work/`
- matching `state/` and `tmp/` paths under the canonical shared tree

In v1, child repo onboarding is an in-pod script or thin pipeline invocation, not an external host-side mutation path.

In v1, child onboarding uses a repo-derived default name for `repos/<name>`. If that derived path already exists, `add-repo` must refuse rather than rename automatically. A user-supplied `--name` override is deferred to later phases and is not part of v1.

In v1, child onboarding must detect the child repo's exact remote default branch name and materialize that checkout without renaming it to `main`. If the remote default branch cannot be determined or attached, onboarding must refuse rather than guess. Later phases may broaden source-ref configuration, but v1 must preserve the detected default branch name exactly.

The top-level dotfiles repo remains the only `/home/vscode` authority even after child repos are added.

## Backup and Export Architecture

### Position in the roadmap

Backup/export is part of the full design, but it is intentionally phase 2 after the initial workspace flow works.

### Chosen primary path

Primary backup/export remains:

- in-pod staging
- host-side pull
- host-side `restic`

This remains the primary durability path because it better addresses cluster-loss concerns than PVC-only recovery.

### Timing and responsibility split

- phase-2 in-pod staging CronJob schedule is fixed by the authoritative plan at minute 0 of every hour (`0 * * * *`)
- phase-2 host-side backup schedule is fixed by the authoritative plan at minute 30 of every hour (`30 * * * *`)
- phase-2 user-facing commands are expected to include `devspace run-pipeline staging` and `devspace run-pipeline backup`
- primary phase-2 `backup` command = host-side pull + `restic`
- manual staging-only trigger required for debugging/verification in phase 2
- stale staging should produce a warning rather than a hard failure by default
- repeated stale staging warnings remain warnings rather than escalating to hard failure by default
- the host-side staging/pull destination should be operator-configurable

### Periodic staging trigger

Phase 2 should use a Kubernetes CronJob for periodic staging.

Why:

- cleaner separation from the interactive workspace process
- easier operational reasoning than embedding cron/timers inside the workspace container
- better fit for a later background backup phase

### Debuggability requirements

The periodic staging system must be debuggable by design:

- CronJob and manual one-shot staging use the same staging script
- staging writes human-readable logs
- staging records persistent status under the workspace `state/` tree
- failures are visible in both Kubernetes job logs and workspace state
- staging failures do not break normal workspace use
- host backup can report whether staged data is fresh or stale, and stale staging should warn by default

### Separate OpenCode deliverables

Phase 2 should treat OpenCode session export and OpenCode session recovery as separate deliverables, not merely incidental side effects of the general backup flow.

#### OpenCode session export deliverable

The system must produce a distinct OpenCode session export artifact under the durable workspace state tree.

Minimum phase-2 contract:

- exported OpenCode session artifacts are written under a documented path such as `state/opencode/exported_sessions/`
- export is independently runnable from the rest of the backup flow
- export success/failure is visible separately from host-side pull + `restic`
- exported session artifacts are intended to be readable and recoverable as files, not only as part of opaque snapshots

#### OpenCode session recovery deliverable

The system must provide a distinct recovery path for previously exported OpenCode session artifacts.

Minimum phase-2 contract:

- exported session artifacts can be pulled back from backup storage and restored into the documented durable export location
- recovery of exported session files is a separate deliverable from full workspace rebuild
- the acceptance target is recovery of exported session artifacts as readable files and a documented recovery workflow
- exact resumability as live OpenCode sessions is not required unless a later phase defines and verifies that behavior explicitly

### Fallback path 1: PVC snapshot/clone

PVC snapshot/clone is retained as a later optional fast-recovery enhancement.

Pros:

- fast local recovery
- good for corruption or accidental damage

Cons:

- weaker protection against total cluster/storage loss
- storage-stack dependent
- not portable enough to be the primary durability path

### Fallback path 2: object-store export

Object-store export is retained as a later unattended/off-cluster extension.

Pros:

- stronger off-cluster durability
- useful for headless or always-on backup scenarios

Cons:

- more infrastructure and secret management
- unnecessary for the first full replacement

## Security and Isolation Considerations

- Workspace source of truth lives inside the cluster on a PVC, not on host-mounted source.
- DevSpace is not used as the core persistence mechanism; Kubernetes owns the durable workspace object.
- v1 uses DevSpace-managed SSH only, not an always-on SSH service inside the workspace container.
- The workspace has no standalone Service in v1.
- Backup remains host-pull oriented rather than giving the workspace direct write access to the backup destination.
- A future broker, when implemented, should be a separate Deployment/service and should not share the workspace PVC.

## Alternatives Considered

### In-pod auto-bootstrap on first start

Rejected as the primary model. Although it could work, it makes provisioning feel hidden inside normal startup and is harder to reason about when startup fails. Explicit provision was chosen because it is easier to understand, debug, and maintain.

### DevSpace pod replacement + `persistPaths` as the main workspace mechanism

Rejected as the core model. It is more magical and makes durability and cleanup semantics harder to reason about. An explicit Kubernetes Deployment/PVC gives a clearer security and lifecycle story.

### StatefulSet for the workspace

Deferred. For one fixed workspace in v1, `Deployment` + PVC is simpler and sufficient. StatefulSet can be revisited if multiple named workspace instances or stronger stable-identity requirements appear later.

### Image-seeded template snapshot

Rejected as the primary bootstrap source. The image remains important as the baseline runtime/tooling layer, but the dotfiles repo is the authoritative template source. Fresh GitHub clone at provision time keeps that source of truth clearer.

### Copy-first home install

Rejected. Symlink-first better matches the existing dotfiles workflow and preserves the live, branch-selectable configuration behavior.

## Deferred Items

- broker implementation and broker manifests
- private repo bootstrap/auth
- multiple named workspace instances
- `reset` as a destructive in-place rebuild command
- always-on SSH service in the workspace
- Helm packaging
- StatefulSet migration
- PVC snapshot as primary backup path
- object-store export as primary backup path

## Open Questions For Planning

The following remain intentionally open for the planning stage:

1. Exact manifest decomposition and file layout
2. Exact single-PVC mount/subPath implementation
3. Exact `doctor` checks and failure boundaries
4. Exact `repair` refusal boundaries and recovery limits
5. Exact `add-repo` CLI shape beyond repo-derived naming and collision refusal
6. Exact provision idempotency/refusal boundaries for partial states
7. Exact host-side backup staging configuration interface and warning/failure semantics

## Phase Structure

### Phase 1

- DevSpace-based workspace Deployment/PVC
- explicit provision flow
- top-level dotfiles bare-hub bootstrap
- symlink-first `/home/vscode` model
- `doctor`, `repair`, `destroy`
- public child-repo onboarding

### Phase 2

- periodic in-pod staging
- Kubernetes CronJob for staging
- manual one-shot staging trigger
- `staging` and `backup` command surface
- host-side pull + `restic`
- OpenCode session export as a separate deliverable
- OpenCode session recovery as a separate deliverable

## Pragmatic Assessment

Current design score: **8.5/10**

Remaining work to reach 10/10 is mostly about tightening operational contracts rather than changing architecture:

1. Make repair/provision refusal boundaries explicit in the plan
2. Make `doctor` checks and host-side invocation contract explicit in the plan
3. Make host backup warning/failure semantics explicit in the plan
