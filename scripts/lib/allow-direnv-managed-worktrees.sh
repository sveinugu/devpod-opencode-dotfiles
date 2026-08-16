#!/usr/bin/env bash
set -euo pipefail

ALLOW_DIRENV_STATUS_ALLOWED='allowed'
ALLOW_DIRENV_STATUS_NOT_ALLOWED='not allowed'
ALLOW_DIRENV_STATUS_UNKNOWN='unknown'
ALLOW_DIRENV_STATUS_MISSING_ENVRC='missing .envrc (repair+allow pending)'
ALLOW_DIRENV_STATUS_MISSING_ENVRC_LOCAL='missing .envrc.local (repair+allow pending)'
ALLOW_DIRENV_STATUS_DIVERGENT='divergent .envrc (force required)'

allow_direnv_target_checkouts=()
allow_direnv_target_kinds=()
allow_direnv_target_repos=()

allow_direnv_usage() {
  printf 'usage: allow-direnv-managed-worktrees [--allow] [--force]\n' >&2
}

allow_direnv_refuse_hub_root() {
  printf 'Refused — hub-root CWD detected. Provide explicit worktree path.\n' >&2
  exit 3
}

allow_direnv_refuse_unmanaged_launch() {
  printf 'refused: launch path is outside managed checkout context\n' >&2
  exit 3
}

allow_direnv_parse_cli() {
  allow_direnv_flag_allow='0'
  allow_direnv_flag_force='0'

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help|-h)
        allow_direnv_usage
        exit 0
        ;;
      --allow)
        allow_direnv_flag_allow='1'
        ;;
      --force)
        allow_direnv_flag_force='1'
        ;;
      *)
        allow_direnv_usage
        exit 2
        ;;
    esac
    shift
  done

  if [ "$allow_direnv_flag_force" = '1' ] && [ "$allow_direnv_flag_allow" != '1' ]; then
    allow_direnv_usage
    exit 2
  fi
}

allow_direnv_resolve_paths() {
  allow_direnv_workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
  allow_direnv_workspace_root="$(cd "$allow_direnv_workspace_root" && pwd -P)"
  allow_direnv_cwd="$(pwd -P)"
  allow_direnv_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

  if [ "$allow_direnv_cwd" = "$allow_direnv_workspace_root" ]; then
    allow_direnv_refuse_hub_root
  fi
}

allow_direnv_is_under() {
  local path="$1"
  local prefix="$2"

  case "$path" in
    "$prefix"|"$prefix"/*) return 0 ;;
  esac
  return 1
}

allow_direnv_child_default_dir() {
  local workspace_root="$1"
  local repo_name="$2"
  local repo_env="$workspace_root/state/repos/$repo_name/etc/repo.env"
  local default_dir=''

  if [ ! -f "$repo_env" ]; then
    return 1
  fi

  default_dir="$(
    set -euo pipefail
    # shellcheck disable=SC1090
    . "$repo_env"
    printf '%s\n' "${DYN_REPO_DEFAULT_DIR:-}"
  )"

  if [ -z "$default_dir" ] || [ ! -d "$default_dir" ]; then
    return 1
  fi

  printf '%s\n' "$default_dir"
}

allow_direnv_discover_targets() {
  local workspace_root="$1"
  local repo_root=''
  local repo_name=''
  local repo_default_dir=''
  local worktree_path=''
  local child_bare=''

  allow_direnv_target_checkouts=()
  allow_direnv_target_kinds=()
  allow_direnv_target_repos=()
  allow_direnv_target_count=0

  if [ -d "$workspace_root/main" ]; then
    allow_direnv_add_target "$workspace_root/main" 'hub' 'hub'
  fi

  if [ -d "$workspace_root/.bare" ]; then
    while IFS= read -r worktree_path; do
      [ -d "$worktree_path" ] || continue
      case "$worktree_path" in
        "$workspace_root/work"/*)
          allow_direnv_add_target "$worktree_path" 'hub' 'hub'
          ;;
      esac
    done < <(git --git-dir="$workspace_root/.bare" worktree list --porcelain | sed -n 's/^worktree //p' | sort)
  fi

  if [ -d "$workspace_root/repos" ]; then
    while IFS= read -r repo_root; do
      [ -d "$repo_root" ] || continue
      repo_name="$(basename "$repo_root")"

      if repo_default_dir="$(allow_direnv_child_default_dir "$workspace_root" "$repo_name")"; then
        allow_direnv_add_target "$repo_default_dir" 'child' "$repo_name"
      else
        printf 'warning: skipped child repo %s due to missing or invalid metadata\n' "$repo_name"
      fi

      child_bare="$repo_root/.bare"
      if [ -d "$child_bare" ]; then
        while IFS= read -r worktree_path; do
          [ -d "$worktree_path" ] || continue
          case "$worktree_path" in
            "$repo_root/work"/*)
              allow_direnv_add_target "$worktree_path" 'child' "$repo_name"
              ;;
          esac
        done < <(git --git-dir="$child_bare" worktree list --porcelain | sed -n 's/^worktree //p' | sort)
      fi
    done < <(find "$workspace_root/repos" -mindepth 1 -maxdepth 1 -type d | sort)
  fi
}

allow_direnv_add_target() {
  local checkout_dir="$1"
  local hub_kind="$2"
  local repo_name="$3"

  allow_direnv_target_checkouts+=("$checkout_dir")
  allow_direnv_target_kinds+=("$hub_kind")
  allow_direnv_target_repos+=("$repo_name")
  allow_direnv_target_count="${#allow_direnv_target_checkouts[@]}"
}

allow_direnv_validate_launch_path() {
  local idx=''
  local checkout_dir=''

  for idx in "${!allow_direnv_target_checkouts[@]}"; do
    checkout_dir="${allow_direnv_target_checkouts[$idx]}"
    if allow_direnv_is_under "$allow_direnv_cwd" "$checkout_dir"; then
      return 0
    fi
  done

  allow_direnv_refuse_unmanaged_launch
}

allow_direnv_direnv_status_text() {
  local checkout_dir="$1"
  local status_text=''

  if ! command -v direnv >/dev/null 2>&1; then
    printf '%s\n' "$ALLOW_DIRENV_STATUS_UNKNOWN"
    return
  fi

  # direnv status does not support a positional path argument.
  # Run status from the target checkout directory so detection matches real direnv behavior.
  if ! status_text="$(cd "$checkout_dir" && direnv status 2>/dev/null || true)"; then
    printf '%s\n' "$ALLOW_DIRENV_STATUS_UNKNOWN"
    return
  fi

  case "$status_text" in
    *'"allowed":1'*|*'Found RC allowed true'*)
      printf '%s\n' "$ALLOW_DIRENV_STATUS_ALLOWED"
      ;;
    *'"allowed":0'*|*'Found RC allowed false'*)
      printf '%s\n' "$ALLOW_DIRENV_STATUS_NOT_ALLOWED"
      ;;
    *)
      printf '%s\n' "$ALLOW_DIRENV_STATUS_UNKNOWN"
      ;;
  esac
}

allow_direnv_is_envrc_divergent() {
  local checkout_dir="$1"
  local hub_kind="$2"
  local repo_name="$3"
  local candidate_path=''

  candidate_path="$checkout_dir/.envrc.managed-candidate.$$"
  if ! WORKTREE_ENV_GENERATE_ONLY=1 WORKTREE_ENV_GENERATED_PATH="$candidate_path" HUB_WORKSPACE_ROOT="$allow_direnv_workspace_root" bash "$allow_direnv_lib_dir/worktree-env.sh" "$checkout_dir" "$hub_kind" "$repo_name" >/dev/null 2>&1; then
    rm -f "$candidate_path"
    return 1
  fi

  if cmp -s "$checkout_dir/.envrc" "$candidate_path"; then
    rm -f "$candidate_path"
    return 1
  fi

  rm -f "$candidate_path"
  return 0
}

allow_direnv_classify_target() {
  local checkout_dir="$1"
  local hub_kind="$2"
  local repo_name="$3"
  local trust_state=''

  if [ ! -e "$checkout_dir/.envrc" ]; then
    printf '%s\n' "$ALLOW_DIRENV_STATUS_MISSING_ENVRC"
    return
  fi

  if [ ! -e "$checkout_dir/.envrc.local" ]; then
    printf '%s\n' "$ALLOW_DIRENV_STATUS_MISSING_ENVRC_LOCAL"
    return
  fi

  if allow_direnv_is_envrc_divergent "$checkout_dir" "$hub_kind" "$repo_name"; then
    printf '%s\n' "$ALLOW_DIRENV_STATUS_DIVERGENT"
    return
  fi

  trust_state="$(allow_direnv_direnv_status_text "$checkout_dir")"
  printf '%s\n' "$trust_state"
}

allow_direnv_collect_counts() {
  allow_direnv_count_allowed=0
  allow_direnv_count_not_allowed=0
  allow_direnv_count_unknown=0
  allow_direnv_count_missing_envrc=0
  allow_direnv_count_missing_envrc_local=0
  allow_direnv_count_divergent=0
  allow_direnv_count_attempted=0
  allow_direnv_count_failed=0
}

allow_direnv_increment_status_count() {
  local status="$1"

  case "$status" in
    "$ALLOW_DIRENV_STATUS_ALLOWED")
      allow_direnv_count_allowed="$((allow_direnv_count_allowed + 1))"
      ;;
    "$ALLOW_DIRENV_STATUS_NOT_ALLOWED")
      allow_direnv_count_not_allowed="$((allow_direnv_count_not_allowed + 1))"
      ;;
    "$ALLOW_DIRENV_STATUS_UNKNOWN")
      allow_direnv_count_unknown="$((allow_direnv_count_unknown + 1))"
      ;;
    "$ALLOW_DIRENV_STATUS_MISSING_ENVRC")
      allow_direnv_count_missing_envrc="$((allow_direnv_count_missing_envrc + 1))"
      ;;
    "$ALLOW_DIRENV_STATUS_MISSING_ENVRC_LOCAL")
      allow_direnv_count_missing_envrc_local="$((allow_direnv_count_missing_envrc_local + 1))"
      ;;
    "$ALLOW_DIRENV_STATUS_DIVERGENT")
      allow_direnv_count_divergent="$((allow_direnv_count_divergent + 1))"
      ;;
  esac
}

allow_direnv_status_is_actionable() {
  local status="$1"
  local force_mode="$2"

  if [ "$force_mode" = '1' ]; then
    case "$status" in
      "$ALLOW_DIRENV_STATUS_ALLOWED"|"$ALLOW_DIRENV_STATUS_NOT_ALLOWED"|"$ALLOW_DIRENV_STATUS_UNKNOWN"|"$ALLOW_DIRENV_STATUS_MISSING_ENVRC"|"$ALLOW_DIRENV_STATUS_MISSING_ENVRC_LOCAL"|"$ALLOW_DIRENV_STATUS_DIVERGENT")
        return 0
        ;;
    esac
    return 1
  fi

  case "$status" in
    "$ALLOW_DIRENV_STATUS_NOT_ALLOWED"|"$ALLOW_DIRENV_STATUS_UNKNOWN"|"$ALLOW_DIRENV_STATUS_MISSING_ENVRC"|"$ALLOW_DIRENV_STATUS_MISSING_ENVRC_LOCAL")
      return 0
      ;;
  esac

  return 1
}

allow_direnv_needs_repair() {
  local status="$1"
  local force_mode="$2"

  case "$status" in
    "$ALLOW_DIRENV_STATUS_MISSING_ENVRC"|"$ALLOW_DIRENV_STATUS_MISSING_ENVRC_LOCAL")
      return 0
      ;;
    "$ALLOW_DIRENV_STATUS_DIVERGENT")
      if [ "$force_mode" = '1' ]; then
        return 0
      fi
      return 1
      ;;
  esac

  return 1
}

allow_direnv_repair_target() {
  local checkout_dir="$1"
  local hub_kind="$2"
  local repo_name="$3"

  if WORKTREE_ENV_SKIP_DIRENV_ALLOW=1 HUB_WORKSPACE_ROOT="$allow_direnv_workspace_root" bash "$allow_direnv_lib_dir/worktree-env.sh" "$checkout_dir" "$hub_kind" "$repo_name" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

allow_direnv_execute_allow() {
  local checkout_dir="$1"

  direnv allow "$checkout_dir" >/dev/null 2>&1
}

allow_direnv_execute_target() {
  local checkout_dir="$1"
  local hub_kind="$2"
  local repo_name="$3"
  local status="$4"
  local force_mode="$5"

  if ! allow_direnv_status_is_actionable "$status" "$force_mode"; then
    printf 'skip: %s [%s]\n' "$checkout_dir" "$status"
    return 0
  fi

  allow_direnv_count_attempted="$((allow_direnv_count_attempted + 1))"

  if allow_direnv_needs_repair "$status" "$force_mode"; then
    if ! allow_direnv_repair_target "$checkout_dir" "$hub_kind" "$repo_name"; then
      printf 'error: repair failed %s [%s]\n' "$checkout_dir" "$status"
      allow_direnv_count_failed="$((allow_direnv_count_failed + 1))"
      return 1
    fi
  fi

  if ! allow_direnv_execute_allow "$checkout_dir"; then
    printf 'error: allow failed %s [%s]\n' "$checkout_dir" "$status"
    allow_direnv_count_failed="$((allow_direnv_count_failed + 1))"
    return 1
  fi

  printf 'ok: allowed %s\n' "$checkout_dir"
  return 0
}

allow_direnv_summary_line() {
  printf 'summary: discovered=%s allowed=%s not_allowed=%s unknown=%s missing_envrc=%s missing_envrc_local=%s divergent=%s attempted=%s failed=%s\n' \
    "$allow_direnv_target_count" \
    "$allow_direnv_count_allowed" \
    "$allow_direnv_count_not_allowed" \
    "$allow_direnv_count_unknown" \
    "$allow_direnv_count_missing_envrc" \
    "$allow_direnv_count_missing_envrc_local" \
    "$allow_direnv_count_divergent" \
    "$allow_direnv_count_attempted" \
    "$allow_direnv_count_failed"
}

allow_direnv_managed_worktrees_main() {
  local idx=''
  local checkout_dir=''
  local hub_kind=''
  local repo_name=''
  local status=''
  local execution_had_failures=0

  if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    printf 'refused: bash 4 or newer is required\n' >&2
    exit 1
  fi

  allow_direnv_parse_cli "$@"
  allow_direnv_resolve_paths

  allow_direnv_discover_targets "$allow_direnv_workspace_root"
  allow_direnv_validate_launch_path
  allow_direnv_collect_counts

  if [ "$allow_direnv_flag_allow" = '1' ] && ! command -v direnv >/dev/null 2>&1; then
    printf 'error: direnv command is required for --allow execution\n' >&2
    exit 1
  fi

  for idx in "${!allow_direnv_target_checkouts[@]}"; do
    checkout_dir="${allow_direnv_target_checkouts[$idx]}"
    hub_kind="${allow_direnv_target_kinds[$idx]}"
    repo_name="${allow_direnv_target_repos[$idx]}"

    status="$(allow_direnv_classify_target "$checkout_dir" "$hub_kind" "$repo_name")"
    allow_direnv_increment_status_count "$status"

    if [ "$allow_direnv_flag_allow" = '1' ]; then
      if ! allow_direnv_execute_target "$checkout_dir" "$hub_kind" "$repo_name" "$status" "$allow_direnv_flag_force"; then
        execution_had_failures=1
      fi
    else
      printf 'plan: %s [%s]\n' "$checkout_dir" "$status"
    fi
  done

  allow_direnv_summary_line

  if [ "$execution_had_failures" = '1' ]; then
    exit 1
  fi

  exit 0
}
