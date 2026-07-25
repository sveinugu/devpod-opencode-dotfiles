# Manual Additions Log (Outside Full Spec/Plan Round)

Purpose: track operational/security changes implemented between full spec/plan cycles so runbooks and implementation remain auditable.

## 2026-07-25 — DevSpace model-credential hardening follow-ups

### 1) `/tmp` staging hardening for DevSpace pipelines

- scope: `devspace.yaml` provision/doctor/repair
- change:
  - stage helper scripts under dedicated paths (`/tmp/dotfiles-provision-staging`, `/tmp/dotfiles-doctor-staging`, `/tmp/dotfiles-repair-staging`)
  - remove staged artifacts after each pipeline via cleanup traps
- rationale: reduce linger time of executable staged scripts under shared `/tmp`

### 2) Persist full `/home/agent` and separate agent runtime state

- scope: `k8s/devspace-bare-hub/workspace-deployment.yaml`, wrapper defaults
- change:
  - mount PVC subPath `home-agent` at `/home/agent`
  - init-container bootstraps `/home/agent` ownership and runtime directories
  - wrapped OpenCode runtime defaults to `/home/agent` XDG paths
- rationale: avoid persistent agent runtime state in `/tmp` and keep runtime separated from `/home/vscode`

### 3) Root-owned pinned OpenCode raw binary

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

- scope: `bin/update-opencode-version`
- change:
  - support `--latest` and `--version <vX.Y.Z|X.Y.Z>`
  - update `Dockerfile` `OPENCODE_VERSION`, `OPENCODE_LINUX_X64_SHA256`, `OPENCODE_LINUX_ARM64_SHA256`
- rationale: keep pinned-image model while enabling simple controlled version bumps

## Operator reminder

After updates affecting `Dockerfile` or deployment manifests:

```bash
devspace build
devspace deploy
```
