#!/usr/bin/env bash
set -euo pipefail

_nwf_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$_nwf_dir/require-non-empty.sh"
unset _nwf_dir

new_worktree_usage() {
  printf 'usage: new-worktree [--repo <hub|repo-name>] <branch>\n' >&2
}

new_worktree_parse_cli() {
  if [ "$#" -lt 1 ]; then
    new_worktree_usage
    exit 2
  fi

  new_worktree_repo_name=''
  new_worktree_branch=''
  new_worktree_branch_set=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --repo)
        shift
        if [ "$#" -eq 0 ]; then
          new_worktree_usage
          exit 2
        fi
        new_worktree_repo_name="${1:-}"
        ;;
      --help|-h)
        new_worktree_usage
        exit 0
        ;;
      *)
        if [ "$new_worktree_branch_set" = true ]; then
          new_worktree_usage
          exit 2
        fi
        new_worktree_branch="$1"
        new_worktree_branch_set=true
        ;;
    esac
    shift
  done

  if [ -z "$new_worktree_branch" ]; then
    new_worktree_usage
    exit 2
  fi
}

new_worktree_infer_repo_name_from_pwd() {
  local workspace_root="$1"
  local script_dir="$2"

  require_non_empty 'new_worktree_infer_repo_name_from_pwd' 'workspace_root' "$workspace_root"
  require_non_empty 'new_worktree_infer_repo_name_from_pwd' 'script_dir' "$script_dir"

  if [ -n "$new_worktree_repo_name" ]; then
    return 0
  fi

  local resolver="${WORKSPACE_NAV_REPO_ROOT_RESOLVER:-$script_dir/../scripts/lib/resolve-managed-repo-root.sh}"
  local inferred_repo_root=''
  if ! inferred_repo_root="$(HUB_WORKSPACE_ROOT="$workspace_root" bash "$resolver" "${PWD:-$(pwd -P)}" 2>/dev/null)"; then
    printf 'refused: unable to infer managed repo context; use --repo <hub|repo-name>\n' >&2
    exit 1
  fi

  if [ "$inferred_repo_root" = "$workspace_root" ]; then
    new_worktree_repo_name='hub'
  elif [[ "$inferred_repo_root" == "$workspace_root/repos/"* ]]; then
    new_worktree_repo_name="${inferred_repo_root#"$workspace_root/repos/"}"
  else
    printf 'refused: unable to infer managed repo context; use --repo <hub|repo-name>\n' >&2
    exit 1
  fi
}

new_worktree_resolve_repo_context() {
  local workspace_root="$1"
  local script_dir="$2"
  local repo_env=''

  require_non_empty 'new_worktree_resolve_repo_context' 'workspace_root' "$workspace_root"
  require_non_empty 'new_worktree_resolve_repo_context' 'script_dir' "$script_dir"

  new_worktree_infer_repo_name_from_pwd "$workspace_root" "$script_dir"

  if [ "$new_worktree_repo_name" = 'hub' ]; then
    new_worktree_repo_root="$workspace_root"
    "$script_dir/../scripts/lib/validate_hub_repo_root.sh" "$workspace_root/main" >/dev/null
    new_worktree_bare_dir="$workspace_root/.bare"
    new_worktree_repo_default_branch='main'
    new_worktree_repo_default_dir="$workspace_root/main"
    new_worktree_target="$workspace_root/work/$new_worktree_branch"
    new_worktree_state_dir="$workspace_root/state/hub/work/$new_worktree_branch"
    new_worktree_tmp_dir="$workspace_root/tmp/hub/work/$new_worktree_branch"
    new_worktree_hub_kind='hub'
    new_worktree_repo_for_env='hub'
    new_worktree_lane_repo_identity='hub'
  else
    new_worktree_repo_root="$workspace_root/repos/$new_worktree_repo_name"
    repo_env="$workspace_root/state/repos/$new_worktree_repo_name/etc/repo.env"
    if [ ! -f "$repo_env" ]; then
      printf 'refused: managed child default branch metadata is missing or invalid\n' >&2
      exit 1
    fi
    # shellcheck disable=SC1090
    . "$repo_env"
    new_worktree_repo_default_branch="${DYN_REPO_DEFAULT_BRANCH:-}"
    new_worktree_repo_default_dir="${DYN_REPO_DEFAULT_DIR:-}"
    if [ -z "$new_worktree_repo_default_branch" ] || [ -z "$new_worktree_repo_default_dir" ] || [ ! -d "$new_worktree_repo_default_dir" ]; then
      printf 'refused: managed child default branch metadata is missing or invalid\n' >&2
      exit 1
    fi
    "$script_dir/../scripts/lib/validate_hub_repo_root.sh" "$new_worktree_repo_default_dir" >/dev/null
    new_worktree_bare_dir="$new_worktree_repo_root/.bare"
    new_worktree_target="$new_worktree_repo_root/work/$new_worktree_branch"
    new_worktree_state_dir="$workspace_root/state/repos/$new_worktree_repo_name/work/$new_worktree_branch"
    new_worktree_tmp_dir="$workspace_root/tmp/repos/$new_worktree_repo_name/work/$new_worktree_branch"
    new_worktree_hub_kind='child'
    new_worktree_repo_for_env="$new_worktree_repo_name"
    new_worktree_lane_repo_identity="$new_worktree_repo_name"
  fi
}

new_worktree_create_or_attach_branch_worktree() {
  local base_branch=''

  require_non_empty 'new_worktree_create_or_attach_branch_worktree' 'new_worktree_branch' "${new_worktree_branch:-}"
  require_non_empty 'new_worktree_create_or_attach_branch_worktree' 'new_worktree_repo_default_branch' "${new_worktree_repo_default_branch:-}"
  require_non_empty 'new_worktree_create_or_attach_branch_worktree' 'new_worktree_bare_dir' "${new_worktree_bare_dir:-}"
  require_non_empty 'new_worktree_create_or_attach_branch_worktree' 'new_worktree_target' "${new_worktree_target:-}"

  if [ "$new_worktree_branch" = "$new_worktree_repo_default_branch" ]; then
    printf 'refused: requested worktree name matches reserved default branch name "%s"\n' "$new_worktree_repo_default_branch" >&2
    exit 1
  fi

  if [ ! -d "$new_worktree_bare_dir" ]; then
    printf 'refused: managed bare repository is missing\n' >&2
    exit 1
  fi

  if ! git --git-dir="$new_worktree_bare_dir" show-ref --verify --quiet "refs/heads/$new_worktree_branch"; then
    if git --git-dir="$new_worktree_bare_dir" show-ref --verify --quiet "refs/remotes/origin/$new_worktree_branch"; then
      git --git-dir="$new_worktree_bare_dir" branch "$new_worktree_branch" "origin/$new_worktree_branch" >/dev/null
    else
      if [ "$new_worktree_repo_name" = 'hub' ]; then
        base_branch='main'
      else
        base_branch="$new_worktree_repo_default_branch"
      fi
      git --git-dir="$new_worktree_bare_dir" branch "$new_worktree_branch" "$base_branch" >/dev/null
    fi
  fi

  git --git-dir="$new_worktree_bare_dir" config "branch.$new_worktree_branch.remote" 'origin'
  git --git-dir="$new_worktree_bare_dir" config "branch.$new_worktree_branch.merge" "refs/heads/$new_worktree_branch"

  if git --git-dir="$new_worktree_bare_dir" worktree list --porcelain | grep -F "worktree $new_worktree_target" >/dev/null 2>&1; then
    :
  else
    mkdir -p "$(dirname "$new_worktree_target")"
    git --git-dir="$new_worktree_bare_dir" worktree add "$new_worktree_target" "$new_worktree_branch" >/dev/null
  fi
}

new_worktree_prepare_checkout_sidecars() {
  local workspace_root="$1"
  local script_dir="$2"

  require_non_empty 'new_worktree_prepare_checkout_sidecars' 'workspace_root' "$workspace_root"
  require_non_empty 'new_worktree_prepare_checkout_sidecars' 'script_dir' "$script_dir"
  require_non_empty 'new_worktree_prepare_checkout_sidecars' 'new_worktree_state_dir' "${new_worktree_state_dir:-}"
  require_non_empty 'new_worktree_prepare_checkout_sidecars' 'new_worktree_tmp_dir' "${new_worktree_tmp_dir:-}"
  require_non_empty 'new_worktree_prepare_checkout_sidecars' 'new_worktree_target' "${new_worktree_target:-}"

  mkdir -p "$new_worktree_state_dir" "$new_worktree_tmp_dir"

  new_worktree_lane_id="${MANAGED_LANE_ID:-$new_worktree_branch}"
  new_worktree_parent_artifact_anchors="${MANAGED_LANE_PARENT_ARTIFACTS:-}"
  new_worktree_session_task_id="${MANAGED_LANE_SESSION_TASK_ID:-}"
  new_worktree_session_owner="${MANAGED_LANE_SESSION_OWNER:-}"
  new_worktree_routing_state="${MANAGED_LANE_ROUTING_STATE:-unbound}"
  new_worktree_lane_status='active'

  if [ "$new_worktree_repo_name" = 'hub' ]; then
    if [ ! -e "$workspace_root/main/.envrc" ]; then
      "$script_dir/../scripts/lib/worktree-env.sh" "$workspace_root/main" "$new_worktree_hub_kind" "$new_worktree_repo_for_env" >/dev/null
    fi
  fi
  if [ ! -e "$new_worktree_target/.envrc" ]; then
    "$script_dir/../scripts/lib/worktree-env.sh" "$new_worktree_target" "$new_worktree_hub_kind" "$new_worktree_repo_for_env" >/dev/null
  fi

  if [ "$new_worktree_repo_name" != 'hub' ]; then
    if [ ! -e "$new_worktree_repo_default_dir/.envrc" ]; then
      "$script_dir/../scripts/lib/worktree-env.sh" "$new_worktree_repo_default_dir" "$new_worktree_hub_kind" "$new_worktree_repo_for_env" >/dev/null
    fi
  fi
}

new_worktree_record_lane_binding() {
  local workspace_root="$1"

  require_non_empty 'new_worktree_record_lane_binding' 'workspace_root' "$workspace_root"
  require_non_empty 'new_worktree_record_lane_binding' 'new_worktree_lane_repo_identity' "${new_worktree_lane_repo_identity:-}"
  require_non_empty 'new_worktree_record_lane_binding' 'new_worktree_branch' "${new_worktree_branch:-}"
  require_non_empty 'new_worktree_record_lane_binding' 'new_worktree_target' "${new_worktree_target:-}"
  require_non_empty 'new_worktree_record_lane_binding' 'new_worktree_state_dir' "${new_worktree_state_dir:-}"
  require_non_empty 'new_worktree_record_lane_binding' 'new_worktree_lane_id' "${new_worktree_lane_id:-}"
  require_non_empty 'new_worktree_record_lane_binding' 'new_worktree_routing_state' "${new_worktree_routing_state:-}"
  require_non_empty 'new_worktree_record_lane_binding' 'new_worktree_lane_status' "${new_worktree_lane_status:-}"

  managed_lane_registry_record_binding \
    "$workspace_root" \
    "$new_worktree_lane_repo_identity" \
    "$new_worktree_lane_id" \
    "$new_worktree_branch" \
    "$new_worktree_target" \
    "$new_worktree_state_dir" \
    "$new_worktree_parent_artifact_anchors" \
    "$new_worktree_session_task_id" \
    "$new_worktree_session_owner" \
    "$new_worktree_routing_state" \
    "$new_worktree_lane_status"
}

new_worktree_report_success() {
  printf 'ok: created worktree at %s\n' "$new_worktree_target"
}
