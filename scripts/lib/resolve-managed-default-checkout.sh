resolve_managed_default_checkout_require_non_empty() {
  local function_name="$1"
  local arg_name="$2"
  local arg_value="$3"

  if [ -n "$arg_value" ]; then
    return 0
  fi

  printf 'refused: %s requires non-empty %s\n' "$function_name" "$arg_name" >&2
  exit 1
}

resolve_managed_default_checkout_require_helpers() {
  local helper_script_base_dir="$1"
  local metadata_helper_path=''

  resolve_managed_default_checkout_require_non_empty 'resolve_managed_default_checkout_require_helpers' 'helper_script_base_dir' "$helper_script_base_dir"

  if declare -F metadata_require_non_empty >/dev/null 2>&1 && declare -F fail_metadata >/dev/null 2>&1; then
    return 0
  fi

  metadata_helper_path="$helper_script_base_dir/../scripts/lib/managed-repo-metadata.sh"
  if [ -f "$metadata_helper_path" ]; then
    # shellcheck disable=SC1090
    . "$metadata_helper_path"
  fi

  if declare -F metadata_require_non_empty >/dev/null 2>&1 && declare -F fail_metadata >/dev/null 2>&1; then
    return 0
  fi

  printf 'refused: resolve_managed_default_checkout requires managed-repo-metadata helpers\n' >&2
  exit 1
}

resolve_managed_default_checkout() {
  local repo_name="$1"
  local repo_root="$2"
  local workspace_root="$3"
  local helper_script_base_dir="$4"

  resolve_managed_default_checkout_require_non_empty 'resolve_managed_default_checkout' 'repo_name' "$repo_name"
  resolve_managed_default_checkout_require_non_empty 'resolve_managed_default_checkout' 'repo_root' "$repo_root"
  resolve_managed_default_checkout_require_non_empty 'resolve_managed_default_checkout' 'workspace_root' "$workspace_root"
  resolve_managed_default_checkout_require_non_empty 'resolve_managed_default_checkout' 'helper_script_base_dir' "$helper_script_base_dir"
  resolve_managed_default_checkout_require_helpers "$helper_script_base_dir"

  metadata_require_non_empty 'resolve_managed_default_checkout' 'repo_name' "$repo_name"
  metadata_require_non_empty 'resolve_managed_default_checkout' 'repo_root' "$repo_root"
  metadata_require_non_empty 'resolve_managed_default_checkout' 'workspace_root' "$workspace_root"
  metadata_require_non_empty 'resolve_managed_default_checkout' 'helper_script_base_dir' "$helper_script_base_dir"

  local repo_env="$workspace_root/state/repos/$repo_name/etc/repo.env"
  local repo_root_canon=''
  local default_branch=''
  local default_dir=''
  local default_dir_canon=''

  if [ ! -f "$repo_env" ]; then
    fail_metadata "$repo_name" "$repo_root" "$workspace_root" "$helper_script_base_dir"
  fi

  if ! repo_root_canon="$(readlink -f "$repo_root" 2>/dev/null)"; then
    fail_metadata "$repo_name" "$repo_root" "$workspace_root" "$helper_script_base_dir"
  fi

  # shellcheck disable=SC1090
  if ! . "$repo_env" 2>/dev/null; then
    fail_metadata "$repo_name" "$repo_root" "$workspace_root" "$helper_script_base_dir"
  fi

  default_branch="${DYN_REPO_DEFAULT_BRANCH:-}"
  default_dir="${DYN_REPO_DEFAULT_DIR:-}"
  if [ -z "$default_branch" ] || [ -z "$default_dir" ] || [ ! -d "$default_dir" ]; then
    fail_metadata "$repo_name" "$repo_root" "$workspace_root" "$helper_script_base_dir"
  fi

  if ! default_dir_canon="$(readlink -f "$default_dir" 2>/dev/null)"; then
    fail_metadata "$repo_name" "$repo_root" "$workspace_root" "$helper_script_base_dir"
  fi

  case "$default_dir_canon" in
    "$repo_root_canon"|"$repo_root_canon"/*) ;;
    *)
      fail_metadata "$repo_name" "$repo_root" "$workspace_root" "$helper_script_base_dir"
      ;;
  esac

  MANAGED_REPO_DEFAULT_BRANCH="$default_branch"
  MANAGED_REPO_DEFAULT_DIR="$default_dir"
  MANAGED_REPO_DEFAULT_DIR_CANON="$default_dir_canon"
}
