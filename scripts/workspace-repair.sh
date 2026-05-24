#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
  printf 'usage: workspace-repair.sh\n' >&2
  exit 2
fi

workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
home_dir="${HUB_HOME_DIR:-/home/vscode}"
provision_branch="${HUB_PROVISION_BRANCH:-main}"

refuse() {
  printf '%s\n' "$1" >&2
  exit 1
}

run_step() {
  local step="$1"
  shift

  if ! "$@"; then
    printf 'error: workspace repair failed during %s\n' "$step" >&2
    exit 1
  fi
}

ensure_dir_path() {
  local path="$1"
  if [ -e "$path" ] && [ ! -d "$path" ]; then
    refuse 'refused: managed path conflicts by type'
  fi
  mkdir -p "$path"
}

if ! git --git-dir="$workspace_root/.bare" rev-parse --is-bare-repository >/dev/null 2>&1; then
  refuse 'refused: existing .bare path is invalid'
fi

run_step 'ensure managed directory work/' ensure_dir_path "$workspace_root/work"
run_step 'ensure managed directory repos/' ensure_dir_path "$workspace_root/repos"
run_step 'ensure managed directory state/' ensure_dir_path "$workspace_root/state"
run_step 'ensure managed directory tmp/' ensure_dir_path "$workspace_root/tmp"
run_step "ensure canonical state path state/hub/${provision_branch}" ensure_dir_path "$workspace_root/state/hub/$provision_branch"
run_step "ensure canonical tmp path tmp/hub/${provision_branch}" ensure_dir_path "$workspace_root/tmp/hub/$provision_branch"

if git --git-dir="$workspace_root/.bare" worktree list --porcelain | grep -F "worktree $workspace_root/main" >/dev/null 2>&1; then
  main_branch="$(git -C "$workspace_root/main" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ -n "$main_branch" ] && [ "$main_branch" != "$provision_branch" ]; then
    # Fetch latest branch content from origin before switching so the worktree gets current install.sh etc.
    if [ "$provision_branch" != "main" ]; then
      git --git-dir="$workspace_root/.bare" fetch origin "$provision_branch:$provision_branch" 2>/dev/null || \
        printf 'warning: could not fetch %s from origin, using cached content\n' "$provision_branch" >&2
    fi
    run_step "switch main worktree to branch $provision_branch" git -C "$workspace_root/main" checkout "$provision_branch"
    run_step "ensure canonical state path state/hub/${provision_branch}" ensure_dir_path "$workspace_root/state/hub/$provision_branch"
    run_step "ensure canonical tmp path tmp/hub/${provision_branch}" ensure_dir_path "$workspace_root/tmp/hub/$provision_branch"
  fi
else
  if [ -e "$workspace_root/main" ] && [ ! -d "$workspace_root/main" ]; then
    refuse 'refused: managed path conflicts by type'
  fi
  if [ -e "$workspace_root/main" ]; then
    refuse 'refused: workspace identity is ambiguous'
  fi
  if ! git --git-dir="$workspace_root/.bare" show-ref --verify --quiet "refs/heads/$provision_branch"; then
    refuse "refused: workspace identity is ambiguous; refs/heads/$provision_branch is missing (set HUB_PROVISION_BRANCH to the provisioned branch)"
  fi
  run_step 'reattach top-level main worktree' git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/main" "$provision_branch" >/dev/null
fi

preserve_non_main=false
for rel in .zshrc .zprofile .config/opencode; do
  path="$home_dir/$rel"
  if [ ! -L "$path" ]; then
    continue
  fi
  target="$(readlink "$path")"
  case "$target" in
    "$workspace_root/work"/*)
      target_parent="$(dirname "$target")"
      if [ -d "$target_parent" ]; then
        preserve_non_main=true
      fi
      ;;
  esac
done

if [ "$preserve_non_main" = false ]; then
  if [ ! -x "$workspace_root/main/install.sh" ]; then
    run_step 'chmod main/install.sh' chmod +x "$workspace_root/main/install.sh"
  fi
  run_step 'run main/install.sh' env HOME="$home_dir" "$workspace_root/main/install.sh"

  install_ok=true
  for rel in .zshrc .zprofile .config/opencode; do
    link_path="$home_dir/$rel"
    if [ -L "$link_path" ]; then
      target="$(readlink "$link_path")"
      if [ ! -e "$target" ]; then
        printf 'error: workspace repair failed during run main/install.sh (symlink target %s -> %s does not exist)\n' "$rel" "$target" >&2
        install_ok=false
      fi
    fi
  done

  if [ "$install_ok" = false ]; then
    exit 1
  fi
fi

printf 'ok: repaired workspace structure at %s\n' "$workspace_root"
