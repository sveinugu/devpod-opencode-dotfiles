#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_retire_worktree: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
retire_script="$repo_root/bin/retire-worktree"
new_worktree_script="$repo_root/bin/new-worktree"
clone_repo_script="$repo_root/bin/clone-repo"

[ -f "$new_worktree_script" ] || fail 'bin/new-worktree not found'
[ -f "$clone_repo_script" ] || fail 'bin/clone-repo not found'
[ -f "$retire_script" ] || fail 'bin/retire-worktree not found'

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_root="$tmpdir/workspace"
home_dir="$tmpdir/home"
mkdir -p "$workspace_root/repos" "$workspace_root/state/repos" "$workspace_root/tmp/repos" "$home_dir"

top_source="$tmpdir/top-source"
git init "$top_source" >/dev/null 2>&1
(
  cd "$top_source"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M main
  printf 'top\n' > README.md
  printf '#!/usr/bin/env bash\nset -euo pipefail\n' > install.sh
  chmod +x install.sh
  mkdir -p .config/opencode
  printf '{}\n' > .config/opencode/opencode.json
  git add README.md install.sh .config/opencode/opencode.json
  git commit -m 'top fixture' >/dev/null 2>&1
)

git clone --bare "$top_source" "$workspace_root/.bare" >/dev/null 2>&1
git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/main" main >/dev/null 2>&1

mkdir -p "$workspace_root/state/hub/etc"
printf 'export HUB_INSTALL_BRANCH=main\n' > "$workspace_root/state/hub/etc/install.env"
printf 'export HUB_INSTALL_BRANCH_DIR=%s\n' "$workspace_root/main" >> "$workspace_root/state/hub/etc/install.env"

child_source="$tmpdir/child-source"
git init "$child_source" >/dev/null 2>&1
(
  cd "$child_source"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M trunk
  printf 'child\n' > README.md
  git add README.md
  git commit -m 'child fixture' >/dev/null 2>&1
)

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$clone_repo_script" "$child_source" >/dev/null

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='lane-hub-loss' bash "$new_worktree_script" --repo hub feature/hub-loss >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='lane-hub-clean' bash "$new_worktree_script" --repo hub feature/hub-clean >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='lane-child-retire' bash "$new_worktree_script" --repo child-source feature/child-retire >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='shared-lane' bash "$new_worktree_script" --repo hub feature/shared-a >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='shared-lane' bash "$new_worktree_script" --repo hub feature/shared-b >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='lane-hub-mismatch' bash "$new_worktree_script" --repo hub feature/hub-mismatch >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='lane-hub-mismatch-other' bash "$new_worktree_script" --repo hub feature/hub-mismatch-other >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='lane-hub-stale' bash "$new_worktree_script" --repo hub feature/hub-stale >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='lane-hub-staged' bash "$new_worktree_script" --repo hub feature/hub-staged >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='lane-hub-untracked-stale' bash "$new_worktree_script" --repo hub feature/hub-untracked-stale >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='lane-hub-canonical-guard' bash "$new_worktree_script" --repo hub feature/hub-canonical-guard >/dev/null

hub_registry="$workspace_root/state/hub/lanes/registry.tsv"

hub_loss_worktree="$workspace_root/work/feature/hub-loss"
printf 'tracked change\n' >> "$hub_loss_worktree/README.md"
printf 'untracked text body\n' > "$hub_loss_worktree/UNTRACKED.txt"
printf '\x00\x01\x02\x03' > "$hub_loss_worktree/BINARY.bin"
(
  cd "$hub_loss_worktree"
  git add README.md
  git commit -m 'local only commit for cleanup evidence' >/dev/null 2>&1
)
printf 'tracked dirty after commit\n' >> "$hub_loss_worktree/README.md"

hub_staged_worktree="$workspace_root/work/feature/hub-staged"
printf 'staged-only tracked change\n' >> "$hub_staged_worktree/README.md"
(
  cd "$hub_staged_worktree"
  git add README.md
)

hub_untracked_stale_worktree="$workspace_root/work/feature/hub-untracked-stale"
printf 'untracked stale v1\n' > "$hub_untracked_stale_worktree/UNTRACKED-STABLE.txt"

child_retire_worktree="$workspace_root/repos/child-source/work/feature/child-retire"
(
  cd "$child_retire_worktree"
  printf 'child local only commit\n' >> README.md
  git add README.md
  git commit -m 'child local only commit for cleanup evidence' >/dev/null 2>&1
)

hub_canonical_guard_worktree="$workspace_root/work/feature/hub-canonical-guard"
hub_external_dir="$tmpdir/external-layout/hub-canonical-guard"
git --git-dir="$workspace_root/.bare" worktree remove --force "$hub_canonical_guard_worktree" >/dev/null
mkdir -p "$(dirname "$hub_external_dir")"
git --git-dir="$workspace_root/.bare" worktree add "$hub_external_dir" feature/hub-canonical-guard >/dev/null

python3 - "$hub_registry" "$hub_external_dir" <<'PY'
from pathlib import Path
import sys

registry = Path(sys.argv[1])
external_path = sys.argv[2]
lines = registry.read_text().splitlines()
out = []
for idx, line in enumerate(lines):
    if idx == 0:
        out.append(line)
        continue
    cols = line.split('\t')
    if cols[0] == 'lane-hub-canonical-guard':
        cols[3] = external_path
    out.append('\t'.join(cols))
registry.write_text('\n'.join(out) + '\n')
PY

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub main >"$tmpdir/default-refusal.out" 2>&1
default_refusal_rc="$?"
set -e
[ "$default_refusal_rc" = '1' ] || fail 'retire-worktree should refuse default checkout target'
grep -F 'refused: target resolves to default checkout and cannot be retired' "$tmpdir/default-refusal.out" >/dev/null || fail 'retire-worktree should explain default checkout refusal'

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub feature/does-not-exist >"$tmpdir/unmanaged-refusal.out" 2>&1
unmanaged_refusal_rc="$?"
set -e
[ "$unmanaged_refusal_rc" = '1' ] || fail 'retire-worktree should refuse unmanaged target'
grep -F 'refused: target does not resolve to a managed active lane binding' "$tmpdir/unmanaged-refusal.out" >/dev/null || fail 'retire-worktree should explain unmanaged target refusal'

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub shared-lane >"$tmpdir/ambiguous-refusal.out" 2>&1
ambiguous_refusal_rc="$?"
set -e
[ "$ambiguous_refusal_rc" = '1' ] || fail 'retire-worktree should refuse ambiguous target'
grep -F 'refused: target is ambiguous across multiple active lane bindings' "$tmpdir/ambiguous-refusal.out" >/dev/null || fail 'retire-worktree should explain ambiguous target refusal'

python3 - "$hub_registry" <<'PY'
from pathlib import Path
import sys

registry = Path(sys.argv[1])
lines = registry.read_text().splitlines()
out = []
for idx, line in enumerate(lines):
    if idx == 0:
        out.append(line)
        continue
    cols = line.split('\t')
    if cols[0] == 'lane-hub-mismatch':
        cols[2] = 'feature/hub-mismatch-other'
    out.append('\t'.join(cols))
registry.write_text('\n'.join(out) + '\n')
PY

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub lane-hub-mismatch >"$tmpdir/mismatch-refusal.out" 2>&1
mismatch_refusal_rc="$?"
set -e
[ "$mismatch_refusal_rc" = '1' ] || fail 'retire-worktree should refuse still-attached branch/worktree mismatch'
grep -F 'refused: branch/worktree attachment mismatch for managed target' "$tmpdir/mismatch-refusal.out" >/dev/null || fail 'retire-worktree should explain branch/worktree mismatch refusal'

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub lane-hub-canonical-guard >"$tmpdir/canonical-layout-refusal.out" 2>&1
canonical_layout_refusal_rc="$?"
set -e
[ "$canonical_layout_refusal_rc" = '1' ] || fail 'retire-worktree should refuse non-canonical managed worktree paths'
grep -F 'refused: target worktree path is outside managed canonical layout' "$tmpdir/canonical-layout-refusal.out" >/dev/null || fail 'retire-worktree should explain canonical layout refusal'

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub --dry-run lane-hub-staged >"$tmpdir/staged-refusal.out" 2>&1
staged_refusal_rc="$?"
set -e
[ "$staged_refusal_rc" = '1' ] || fail 'retire-worktree should refuse staged tracked changes during dry-run'
grep -F 'loss check: tracked modifications would be lost' "$tmpdir/staged-refusal.out" >/dev/null || fail 'retire-worktree should report staged tracked-change loss risk'
grep -F 'staged-only tracked change' "$tmpdir/staged-refusal.out" >/dev/null || fail 'retire-worktree should include staged patch evidence'

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub --dry-run lane-hub-loss >"$tmpdir/loss-refusal.out" 2>&1
loss_refusal_rc="$?"
set -e
[ "$loss_refusal_rc" = '1' ] || fail 'retire-worktree should refuse loss-risk target during dry-run'
grep -F 'loss check: tracked modifications would be lost' "$tmpdir/loss-refusal.out" >/dev/null || fail 'retire-worktree should report tracked-change loss risk'
grep -F 'loss evidence (tracked patch):' "$tmpdir/loss-refusal.out" >/dev/null || fail 'retire-worktree should include tracked patch evidence'
grep -F 'loss check: untracked files would be lost' "$tmpdir/loss-refusal.out" >/dev/null || fail 'retire-worktree should report untracked-file loss risk'
grep -F 'loss evidence (untracked text): UNTRACKED.txt' "$tmpdir/loss-refusal.out" >/dev/null || fail 'retire-worktree should include untracked text evidence'
grep -F 'loss evidence (binary): BINARY.bin' "$tmpdir/loss-refusal.out" >/dev/null || fail 'retire-worktree should include binary-file evidence'
grep -F 'loss check: local-only commits would become unreachable' "$tmpdir/loss-refusal.out" >/dev/null || fail 'retire-worktree should report local-only commit loss risk'
grep -F 'loss evidence (local-only commits):' "$tmpdir/loss-refusal.out" >/dev/null || fail 'retire-worktree should include local-only commit list and patch evidence'
grep -F 'loss check: unable to prove upstream safety' "$tmpdir/loss-refusal.out" >/dev/null || fail 'retire-worktree should report missing upstream proof loss risk'
grep -F 'retry with: ' "$tmpdir/loss-refusal.out" >/dev/null || fail 'retire-worktree should print exact retry command with force token'

loss_token="$(sed -n 's/^force-token: //p' "$tmpdir/loss-refusal.out" | head -n1)"
[ -n "$loss_token" ] || fail 'retire-worktree refusal should print force token'

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub --force lane-hub-loss >"$tmpdir/force-without-token.out" 2>&1
force_without_token_rc="$?"
set -e
[ "$force_without_token_rc" = '1' ] || fail 'retire-worktree should reject --force without --force-token'
grep -F 'refused: --force requires --force-token' "$tmpdir/force-without-token.out" >/dev/null || fail 'retire-worktree should explain missing force-token refusal'

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub --force --force-token "$loss_token" lane-hub-loss >"$tmpdir/force-success.out" 2>&1 || fail 'retire-worktree force run should succeed with matching token'
grep -F 'ok: retired managed lane lane-hub-loss' "$tmpdir/force-success.out" >/dev/null || fail 'retire-worktree success should report retired lane id'
[ ! -d "$workspace_root/work/feature/hub-loss" ] || fail 'retire-worktree should remove hub worktree on successful cleanup'
if git --git-dir="$workspace_root/.bare" show-ref --verify --quiet refs/heads/feature/hub-loss; then
  fail 'retire-worktree should delete local branch on successful cleanup'
fi
grep -F $'lane-hub-loss\thub\tfeature/hub-loss\t' "$workspace_root/state/hub/lanes/registry.tsv" | grep -F $'\tretired' >/dev/null || fail 'retire-worktree should mark lane binding as retired in registry'

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo child-source lane-child-retire >"$tmpdir/child-refusal.out" 2>&1
child_refusal_rc="$?"
set -e
[ "$child_refusal_rc" = '1' ] || fail 'retire-worktree should refuse child target without force token when loss proof is missing'
grep -F 'repo: child-source' "$tmpdir/child-refusal.out" >/dev/null || fail 'retire-worktree output should include child repo identity'
grep -F 'loss check: local-only commits would become unreachable' "$tmpdir/child-refusal.out" >/dev/null || fail 'retire-worktree should detect child local-only commits using detected child default branch'

child_token="$(sed -n 's/^force-token: //p' "$tmpdir/child-refusal.out" | head -n1)"
[ -n "$child_token" ] || fail 'retire-worktree child refusal should print force token'

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo child-source --force --force-token "$child_token" lane-child-retire >"$tmpdir/child-force-success.out" 2>&1 || fail 'retire-worktree should support child lane cleanup'
[ ! -d "$workspace_root/repos/child-source/work/feature/child-retire" ] || fail 'retire-worktree should remove child worktree on successful cleanup'
if git --git-dir="$workspace_root/repos/child-source/.bare" show-ref --verify --quiet refs/heads/feature/child-retire; then
  fail 'retire-worktree should delete child local branch on successful cleanup'
fi
grep -F $'lane-child-retire\tchild-source\tfeature/child-retire\t' "$workspace_root/state/repos/child-source/lanes/registry.tsv" | grep -F $'\tretired' >/dev/null || fail 'retire-worktree should mark child lane binding as retired in registry'

hub_stale_worktree="$workspace_root/work/feature/hub-stale"
printf 'first change\n' >> "$hub_stale_worktree/README.md"
set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub --dry-run lane-hub-stale >"$tmpdir/stale-refusal-1.out" 2>&1
stale_refusal_1_rc="$?"
set -e
[ "$stale_refusal_1_rc" = '1' ] || fail 'retire-worktree should refuse stale lane dry-run before force'
stale_token_1="$(sed -n 's/^force-token: //p' "$tmpdir/stale-refusal-1.out" | head -n1)"
[ -n "$stale_token_1" ] || fail 'retire-worktree should print stale test force token'

printf 'second change\n' >> "$hub_stale_worktree/README.md"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub --force --force-token "$stale_token_1" lane-hub-stale >"$tmpdir/stale-token-refusal.out" 2>&1
stale_token_refusal_rc="$?"
set -e
[ "$stale_token_refusal_rc" = '1' ] || fail 'retire-worktree should reject stale force token after state change'
grep -F 'refused: stale force-token for current risk report' "$tmpdir/stale-token-refusal.out" >/dev/null || fail 'retire-worktree should explain stale force-token refusal'

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub --dry-run lane-hub-untracked-stale >"$tmpdir/untracked-stale-refusal-1.out" 2>&1
untracked_stale_refusal_1_rc="$?"
set -e
[ "$untracked_stale_refusal_1_rc" = '1' ] || fail 'retire-worktree should refuse untracked-stale lane dry-run before force'
untracked_stale_token_1="$(sed -n 's/^force-token: //p' "$tmpdir/untracked-stale-refusal-1.out" | head -n1)"
[ -n "$untracked_stale_token_1" ] || fail 'retire-worktree should print untracked stale test force token'

printf 'untracked stale v2\n' > "$hub_untracked_stale_worktree/UNTRACKED-STABLE.txt"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$retire_script" --repo hub --force --force-token "$untracked_stale_token_1" lane-hub-untracked-stale >"$tmpdir/untracked-stale-token-refusal.out" 2>&1
untracked_stale_token_refusal_rc="$?"
set -e
[ "$untracked_stale_token_refusal_rc" = '1' ] || fail 'retire-worktree should reject stale force token after untracked content changes'
grep -F 'refused: stale force-token for current risk report' "$tmpdir/untracked-stale-token-refusal.out" >/dev/null || fail 'retire-worktree should explain stale force-token refusal for untracked content changes'

printf 'PASS test_retire_worktree\n'
