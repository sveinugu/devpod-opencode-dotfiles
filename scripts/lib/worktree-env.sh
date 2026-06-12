#!/usr/bin/env bash
set -euo pipefail

checkout_dir="${1:?usage: worktree-env.sh CHECKOUT_DIR HUB_KIND [REPO_NAME]}"
hub_kind="${2:?usage: worktree-env.sh CHECKOUT_DIR HUB_KIND [REPO_NAME]}"
repo_name="${3:-hub}"

workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
checkout_dir="$(readlink -f "$checkout_dir")"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exclude_helper="$script_dir/ensure-bare-excludes.sh"

refuse() {
  printf '%s\n' "$1" >&2
  exit 1
}

case "$hub_kind" in
  hub|child) ;;
  *)
    refuse 'usage: worktree-env.sh CHECKOUT_DIR HUB_KIND [REPO_NAME]'
    ;;
esac

if [ "$hub_kind" = "hub" ]; then
  hub_dir="$workspace_root"
  hub_main_dir="$workspace_root/main"
  hub_state_dir="$workspace_root/state/hub"
  hub_tmp_dir="$workspace_root/tmp/hub"
  dyn_repo_dir="$workspace_root"
  dyn_repo_main_dir="$workspace_root/main"
  dyn_repo_state_dir="$workspace_root/state/hub"
  dyn_repo_tmp_dir="$workspace_root/tmp/hub"
  case "$checkout_dir" in
    "$workspace_root/main")
      dyn_worktree_state_dir="$workspace_root/state/hub/main"
      dyn_worktree_tmp_dir="$workspace_root/tmp/hub/main"
      ;;
    "$workspace_root/work"/*)
      work_rel="${checkout_dir#"$workspace_root/work/"}"
      dyn_worktree_state_dir="$workspace_root/state/hub/work/$work_rel"
      dyn_worktree_tmp_dir="$workspace_root/tmp/hub/work/$work_rel"
      ;;
    *)
      refuse 'refused: checkout is not a managed top-level worktree'
      ;;
  esac
  bare_dir="$workspace_root/.bare"
elif [ "$hub_kind" = "child" ]; then
  child_root="$workspace_root/repos/$repo_name"
  child_env="$workspace_root/state/repos/$repo_name/etc/repo.env"
  dyn_repo_default_branch=''
  dyn_repo_default_dir=''
  hub_dir="$workspace_root"
  hub_main_dir="$workspace_root/main"
  hub_state_dir="$workspace_root/state/hub"
  hub_tmp_dir="$workspace_root/tmp/hub"
  dyn_repo_dir="$child_root"
  dyn_repo_state_dir="$workspace_root/state/repos/$repo_name"
  dyn_repo_tmp_dir="$workspace_root/tmp/repos/$repo_name"
  if [ -f "$child_env" ]; then
    # shellcheck disable=SC1090
    . "$child_env"
    dyn_repo_default_branch="${DYN_REPO_DEFAULT_BRANCH:-}"
    dyn_repo_default_dir="${DYN_REPO_DEFAULT_DIR:-}"
  fi
  if [ -z "$dyn_repo_default_branch" ] || [ -z "$dyn_repo_default_dir" ]; then
    refuse 'refused: managed child default branch metadata is missing or invalid'
  fi
  case "$checkout_dir" in
    "$dyn_repo_default_dir")
      dyn_worktree_state_dir="$workspace_root/state/repos/$repo_name/$dyn_repo_default_branch"
      dyn_worktree_tmp_dir="$workspace_root/tmp/repos/$repo_name/$dyn_repo_default_branch"
      ;;
    "$child_root/work"/*)
      work_rel="${checkout_dir#"$child_root/work/"}"
      dyn_worktree_state_dir="$workspace_root/state/repos/$repo_name/work/$work_rel"
      dyn_worktree_tmp_dir="$workspace_root/tmp/repos/$repo_name/work/$work_rel"
      ;;
    *)
      refuse 'refused: checkout is not a managed child worktree'
      ;;
  esac
  bare_dir="$child_root/.bare"
fi

if [ ! -f "$exclude_helper" ]; then
  refuse 'refused: missing bare exclude helper'
fi

if [ ! -d "$bare_dir" ]; then
  refuse 'refused: managed bare repository is missing'
fi

bash "$exclude_helper" "$bare_dir"

mkdir -p "$dyn_worktree_state_dir" "$dyn_worktree_tmp_dir"
generated_envrc="$checkout_dir/.envrc.generated.$$"

cat > "$generated_envrc" <<EOF
export HUB_DIR="$hub_dir"
export HUB_MAIN_DIR="$hub_main_dir"
export HUB_STATE_DIR="$hub_state_dir"
export HUB_TMP_DIR="$hub_tmp_dir"
export DYN_REPO_DIR="$dyn_repo_dir"
export DYN_REPO_DEFAULT_BRANCH="${dyn_repo_default_branch:-}"
export DYN_REPO_DEFAULT_DIR="${dyn_repo_default_dir:-$dyn_repo_dir}"
export DYN_REPO_STATE_DIR="$dyn_repo_state_dir"
export DYN_REPO_TMP_DIR="$dyn_repo_tmp_dir"
export DYN_WORKTREE_DIR="$checkout_dir"
export DYN_WORKTREE_STATE_DIR="$dyn_worktree_state_dir"
export DYN_WORKTREE_TMP_DIR="$dyn_worktree_tmp_dir"
if [ -f /workspaces/dotfiles/state/hub/etc/install.env ]; then
  source /workspaces/dotfiles/state/hub/etc/install.env
fi
source ./.envrc.local
EOF

write_new_envrc=false
if [ ! -e "$checkout_dir/.envrc" ]; then
  write_new_envrc=true
else
  if cmp -s "$checkout_dir/.envrc" "$generated_envrc"; then
    if [ ! -e "$checkout_dir/.envrc.local" ]; then
      : > "$checkout_dir/.envrc.local"
    fi
    rm -f "$generated_envrc"
    exit 0
  fi

  timestamp="$(date +%Y%m%d%H%M%S)"
  backup_name=".envrc.bak.$timestamp"
  cp "$checkout_dir/.envrc" "$checkout_dir/$backup_name"
  printf 'warning: backed up existing .envrc to %s\n' "$backup_name" >&2
  write_new_envrc=true
fi

if [ "$write_new_envrc" = true ]; then
  mv "$generated_envrc" "$checkout_dir/.envrc"
  if command -v direnv >/dev/null 2>&1; then
    direnv allow "$checkout_dir"
  fi
fi

if [ ! -e "$checkout_dir/.envrc.local" ]; then
  : > "$checkout_dir/.envrc.local"
fi

printf 'ok: generated managed envrc at %s/.envrc\n' "$checkout_dir"
