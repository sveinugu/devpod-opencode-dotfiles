# Persistence and security design for bare-hub manager

Date: 2026-05-21
Scope: `/workspaces` persistence in DevPod on k3d, install-source behavior for dotfiles, and bare-hub manager guardrails.

> **Superseded in part:** The durable-state and backup model in this document has been superseded by `docs/superpowers/plans/2026-05-21-bare-hub-manager.md`, which is now the canonical combined spec + implementation plan for the bare-hub manager workflow. While this document remains in the repo, read all persistence and backup guidance through that newer document.

## Executive summary

`/workspaces` is durable only when DevPod mounts durable Kubernetes storage; `hostPath` and PVC-backed volumes can persist, while `emptyDir` cannot. For a bare-hub/worktree layout, installing from a mounted repo checkout is safer than copying from local disk because copied worktrees often keep broken `.git` indirection. The biggest risks are path/symlink attacks into `$HOME`, host-credential exposure through bind mounts, and over-broad persistent state. Recommended default: PVC-backed `/workspaces`, non-root installer, explicit absolute source/worktree paths, and per-workspace state with `0700` permissions.

## `/workspaces` persistence models in DevPod on k3d

| Model | Typical k3d shape | Pod recreate | Node restart | Node delete/recreate | Notes |
|---|---|---|---|---|---|
| `hostPath` | Pod mounts a path from the k3d node | Persists | Persists if the node keeps the same backing path | Often lost unless the same host bind path is reattached | Simple, single-node coupling |
| PVC / `StorageClass` | Pod mounts a PVC; in k3d this is usually local-path storage | Persists | Usually persists | Persists only if the PV maps to a stable host path or durable Docker volume | Best default if backing path is explicit |
| `emptyDir` | Pod-local scratch storage | Lost | Lost | Lost | Never use for `/workspaces` if state matters |

In single-node k3d, persistence usually means either PVC/local-path or direct `hostPath`. If `/workspaces` survives `kubectl delete pod` but not cluster rebuilds, it is likely node-local rather than host-persistent.

## Install source behavior and side-effects

| Install source | Path resolution | Symlinks and permissions | Git/worktree side-effects | Risk summary |
|---|---|---|---|---|
| Repo checkout inside DevPod (`/workspaces/dotfiles/main/install.sh`) | Source-relative paths resolve inside the checkout | Symlinks target container-visible paths; ownership usually matches pod UID/GID | `.git` points to a gitdir inside the mounted tree, so worktrees stay valid | Preferred |
| Host repo bind-mounted into DevPod | Same if the same host path is mounted into the container | Root-owned host files can trigger write failures or `safe.directory` warnings | Worktrees work only if checkout and gitdir are mounted with identical paths | Acceptable |
| Local disk copied into container | Installer resolves against the copied path | `cp -a` may preserve symlinks; ownership/perms may change | Copied worktrees often break because `.git` still references the original gitdir path | Not recommended |

Side-effects: copied worktrees may keep `.git` as `gitdir: /Users/...` or another host-only path; repo-based installs keep links live to the checkout while copy-based installs drift; running as `root` can leave `$HOME` files root-owned.

## Security risks

| Action | Attack scenario | Likelihood | Impact |
|---|---|---:|---:|
| Install from repo | Malicious repo symlink points outside source tree; installer links `/etc/passwd` or host secret into `$HOME` | Medium | High |
| Install from repo | TOCTOU race swaps a validated symlink target after check but before `ln -s` | Low | High |
| Install from copied local disk | Copied `.git` points to host path or another repo, causing edits against the wrong gitdir | Medium | Medium |
| Writing into `$HOME` | Installer overwrites `~/.ssh/config`, `~/.config/opencode`, or shell rc files without explicit consent | Medium | High |
| Persistent `/workspaces` | Transcripts, auth files, or repo-local secrets remain readable by other workspaces or future sessions | Medium | High |
| Host bind mounts | Mounted Docker socket, SSH agent, kubeconfig, or auth files give agents host-level control or a container-escape path | Medium | High |
| Bare-hub manager use | Agent runs with CWD at hub root and mutates administrative files instead of a checkout | Medium | Medium |
| Agent privileges | Over-broad `opencode` permissions allow arbitrary `git add`, shell access, or secret exfiltration | Medium | High |
| Shared workspace state | Per-workspace state directories expose previous transcripts, plans, or secrets to unrelated repos | Medium | Medium |

## Mitigations and guardrails

- Require explicit absolute source and target arguments, for example: `./install.sh --source-root /workspaces/dotfiles/main --target-home "$HOME"`. Refuse relative paths and source roots whose `git rev-parse --show-toplevel` does not equal the supplied path.
- Refuse hub-root execution: if `pwd -P` is `/workspaces/dotfiles` or another bare-hub root, exit with `Refused — hub-root CWD detected. Provide explicit worktree path.`
- Add `scripts/install-validate-source.sh` that resolves every candidate source with `readlink -f`, rejects any path escaping the source root, and rejects a `.git` file whose `gitdir:` target is missing or outside `/workspaces/dotfiles`.
- Run installers as the workspace user only: `test "$(id -u)" -ne 0 || { echo 'Refused — do not run as root'; exit 1; }`. Set `umask 077` before writing state.
- Use atomic writes: create temp links/files in `$(mktemp -d)` and promote with `mv -Tf`.
- Minimal prompt: before replacing an existing non-symlink in `$HOME`, show `Replace $HOME/.zshrc with link to /workspaces/dotfiles/main/.zshrc? [y/N]`.
- Keep host mounts minimal and read-only where possible; do not mount `/var/run/docker.sock`, kubeconfig, or host credential stores unless required.
- Tighten `.config/opencode/opencode.jsonc` so dangerous shell patterns remain `ask`/`deny`, and store runtime state only under `/workspaces/dotfiles/state/opencode` with `0700` permissions.
- Store transcripts per workspace under `/workspaces/dotfiles/state/opencode/<workspace-id>`.
- If bootstrap/install source comes from a remote repo, pin a reviewed commit and verify `git verify-commit`, signed tags, or an installer checksum before first install.

## Recommended k3d/DevPod default

Preferred default: mount `/workspaces` from a PVC backed by the local-path provisioner, but ensure that provisioner writes to an explicit host-backed path or stable Docker volume on the k3d server node. Run the workspace container as UID/GID `1000:1000` with `fsGroup: 1000`, keep `/workspaces/dotfiles/state` owned by that user, and back up the underlying host path daily with `restic` or `rsync --archive --delete`.

## Admin tests and verification

Identify the volume type:

```bash
kubectl get pod <workspace-pod> -o jsonpath='{range .spec.volumes[*]}{.name}{"\t"}{.persistentVolumeClaim.claimName}{"\t"}{.hostPath.path}{"\n"}{end}'
kubectl describe pvc <pvc-name>
```

Expected: either a PVC name for the `/workspaces` volume or a concrete `hostPath`; empty output for both suggests ephemeral storage.

Persistence check:

```bash
kubectl exec <workspace-pod> -- sh -lc 'echo persist-1 > /workspaces/.persist-check && sync && ls -l /workspaces/.persist-check'
kubectl delete pod <workspace-pod>
kubectl exec <new-workspace-pod> -- cat /workspaces/.persist-check
docker restart k3d-<cluster>-server-0
kubectl exec <workspace-pod> -- cat /workspaces/.persist-check
```

Expected: file survives pod recreation and node restart. In a disposable environment, recreate the k3d node/cluster with the same host backing path; if the file disappears, storage was node-local.

Symlink-race simulation:

```bash
mkdir -p /tmp/race/src /tmp/race/home
printf ok > /tmp/race/src/good
ln -snf /tmp/race/src/good /tmp/race/src/current
(while true; do ln -snf /etc/passwd /tmp/race/src/current; ln -snf /tmp/race/src/good /tmp/race/src/current; done) &
./scripts/install-validate-source.sh /tmp/race/src /tmp/race/src/current
```

Expected: validator refuses with `refused: symlink escapes source root` and no file in `/tmp/race/home` changes.

## Clarifying questions for the user

- Is your k3d cluster single-node, and do you know whether its local-path provisioner writes to a host bind mount or node-local container storage?
- Do you need `/workspaces` to survive full cluster rebuilds, or only pod restarts and node/container restarts?
- Will any DevPod workspace mount host credentials or sockets such as Docker, SSH agent, kubeconfig, or GPG?
- Do you want the installer to allow any overwrites in `$HOME` without a prompt, or should non-symlink replacements always ask?
- Are your dotfiles/bootstrap repos signed, or should the design assume unsigned commits and rely on pinned reviewed SHAs?

## Prioritized actionable TODOs

1. **Add source-root and hub-root validation**  
   Files: `install.sh`, `scripts/install-validate-source.sh`  
   Steps: (1) create validator script; (2) require `--source-root` and reject hub-root CWD; (3) run one pass and one refusal check.  
   Commit: `feat(install): refuse unsafe source roots and hub-root execution`

2. **Make home writes atomic and prompt on risky replacement**  
   Files: `install.sh`, optionally `scripts/link-dotfile.sh`  
   Steps: (1) add `mktemp` + `mv -Tf`; (2) prompt before replacing existing non-symlink files in `$HOME`; (3) verify ownership stays `1000:1000`.  
   Commit: `feat(install): harden dotfile linking and overwrite prompts`

3. **Harden persistent state isolation**  
   Files: `.config/opencode/opencode.jsonc`, `scripts/redirect-opencode-state.sh`  
   Steps: (1) enforce state under `/workspaces/dotfiles/state/opencode/<workspace-id>`; (2) set `umask 077` and `chmod 700`; (3) confirm transcripts are not written to `/tmp/opencode`.  
   Commit: `chore(security): isolate opencode workspace state`

4. **Pin durable `/workspaces` storage in k3d**  
   Files: create `.devpod/k8s/workspaces-pvc.yaml` or equivalent ops doc/manifests  
   Steps: (1) declare PVC/StorageClass usage; (2) document the host backing path; (3) verify sentinel survives pod recreation and node restart.  
   Commit: `ops(k3d): pin persistent storage for workspaces`

5. **Add an admin verification runbook**  
   Files: `docs/superpowers/runbooks/devpod-persistence-verification.md`  
   Steps: (1) capture `kubectl`/`docker` verification commands; (2) add a symlink-race test; (3) record expected outputs and failures.  
   Commit: `docs(runbook): add persistence and installer security checks`

## User-provided environment answers (2026-05-21)

1. Cluster: "Cluster is currently single-node, but I might want to add extra nodes (e.g. one for control, one per devpod). local-path provisioner => node-local persistent storage backed by a directory on the k3s node (/var/lib/rancher/k3s/storage/...)."

2. Persistence requirement: "Content of e.g. /workspaces/dotfiles/state and /workspaces/dotfiles/repos/omnipy/state somehow needs persistence, but could be git-based. The rest is already git-based persistence (if committed). Otherwise: survive pod/node restarts only (not full cluster rebuilds)."

3. Host mounts: "No"

4. Installer UX: "if run by devpods: no, If run manually: Possibly, if combined with --dry-run (showing all paths that will be changed) and -y options (yes to all prompts)."

5. Signing: "Not signed now, but can start signing if needed."

### Implications & recommended immediate actions (from planner)

- Add source-root validation plus explicit refusal of hub-root execution in `install.sh`.
- Isolate persistent OpenCode state per workspace under `/workspaces/dotfiles/state/opencode/<workspace-id>` with `0700` perms.
- Pin `/workspaces` to durable k3d storage and verify persistence across pod restarts; consider `Retain` policy and backups.
