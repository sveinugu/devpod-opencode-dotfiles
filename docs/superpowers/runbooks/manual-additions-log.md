# Manual Additions Log (Outside Full Spec/Plan Round)

Purpose: track operational/security changes implemented between full spec/plan cycles so runbooks and implementation remain auditable.

## 2026-07-25 — DevSpace model-credential hardening follow-ups

### 0) Secure wrapped OpenCode launch path (current steady-state)

- commits: `7e08f1a`, `e100607`, `6c5e530`, `89187b7`, `c695178`, `c518c18`, `4950070`, `e66bbd9`, `79f2ee2`, `fa8b0a8`
- scope: `Dockerfile`, `.config/opencode/bin/opencode`, `.config/nono/profiles/devspace-opencode-secure.jsonc`, helper scripts
- change:
  - `nono` is image-installed and root-owned (`/usr/local/bin/nono`), not provision-time user-installed
  - wrapped `opencode` launch uses constrained `sudo` + `setpriv` privilege drop to `agent` before `nono` execution
  - generated runtime nono profile is created by root-owned helper under `/etc/nono/profiles/runtime`
  - provider routes/credentials are filtered to runtime-enabled providers from generated runtime policy output
  - secure profile keeps required group contracts and explicit shell-config bypass entries for install flow compatibility
- rationale: stabilize secure-launch behavior under least-privilege and explicit runtime policy contracts

### 1) `/tmp` staging hardening for DevSpace pipelines

- commits: `a4f2cb1`

- scope: `devspace.yaml` provision/doctor/repair
- change:
  - stage helper scripts under dedicated paths (`/tmp/dotfiles-provision-staging`, `/tmp/dotfiles-doctor-staging`, `/tmp/dotfiles-repair-staging`)
  - remove staged artifacts after each pipeline via cleanup traps
- rationale: reduce linger time of executable staged scripts under shared `/tmp`

### 2) Persist full `/home/agent` and separate agent runtime state

- commits: `a4f2cb1`

- scope: `k8s/devspace-bare-hub/workspace-deployment.yaml`, wrapper defaults
- change:
  - mount PVC subPath `home-agent` at `/home/agent`
  - init-container bootstraps `/home/agent` ownership and runtime directories
  - wrapped OpenCode runtime defaults to `/home/agent` XDG paths
- rationale: avoid persistent agent runtime state in `/tmp` and keep runtime separated from `/home/vscode`

### 3) Root-owned pinned OpenCode raw binary

- commits: `41c4e38`

- scope: `Dockerfile`, wrapper defaults, nono profile, sudoers contract, shell PATH
- change:
  - install pinned OpenCode binary at image build under `/usr/local/libexec/opencode/<version>/opencode`
  - expose stable root-owned executable at `/usr/local/bin/opencode-raw`
  - remove user-side OpenCode install from `scripts/provision-workspace.sh`
  - wrapper default `OPENCODE_RAW_BINARY` now `/usr/local/bin/opencode-raw`
  - nono filesystem allowlist and sudoers runtime rule updated for `/usr/local/bin/opencode-raw`
  - shell path precedence remains wrapped launcher first (`$HOME/.config/opencode/bin`), then `/usr/local/bin`
- rationale: remove mixed ownership between runtime sandbox and user-home-installed executable; improve reproducibility and rollback/auditability

### 4) Simple pinned-version update helper

- commits: `41c4e38`

- scope: `bin/update-opencode-version`
- change:
  - support `--latest` and `--version <vX.Y.Z|X.Y.Z>`
  - update `Dockerfile` `OPENCODE_VERSION`, `OPENCODE_LINUX_X64_SHA256`, `OPENCODE_LINUX_ARM64_SHA256`
- rationale: keep pinned-image model while enabling simple controlled version bumps

### 5) Provider-enablement manifest-driven runtime generation

- commits: `49a16a9`, `f63e0f9`
- scope: provision workflow + runbooks
- change:
  - provisioning syncs runtime provider outputs from install-branch policy plus host-local enablement manifest
  - required provider credential secret bootstrap is documented and treated as a pre-deploy requirement
- rationale: keep provider behavior explicit, reproducible, and policy-driven across deploy/provision cycles

## Commit-range review notes

Review scope: commits from `97c721e3296d5a6d20fbce680f9eeafc6373de4c` to current `HEAD`.

- Included above: additions that change user/operator-visible behavior and remain valid at `HEAD`.
- Not included: implementation-only fixes/refactors that align existing approved behavior without introducing new functionality.
- Not included: reverted experiments (for example temporary root-run nono changes) that are not valid at `HEAD`.

## Operator reminder

After updates affecting `Dockerfile` or deployment manifests:

```bash
devspace build
devspace deploy
```
