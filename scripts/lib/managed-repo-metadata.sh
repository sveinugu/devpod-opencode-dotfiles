_mrm_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$_mrm_dir/require-non-empty.sh"
unset _mrm_dir

metadata_refusal() {
  local repo_name="$1"
  printf 'refused: managed child default branch metadata is missing or invalid for "%s"\n' "$repo_name" >&2
}

metadata_repair_hint() {
  local repo_name="$1"
  local repo_root="$2"
  local workspace_root="$3"
  local helper_script_base_dir="$4"

  require_non_empty 'metadata_repair_hint' 'repo_name' "$repo_name"
  require_non_empty 'metadata_repair_hint' 'repo_root' "$repo_root"
  require_non_empty 'metadata_repair_hint' 'workspace_root' "$workspace_root"
  require_non_empty 'metadata_repair_hint' 'script_dir' "$helper_script_base_dir"

  local helper_path="$(cd "$helper_script_base_dir/../scripts/lib" && pwd -P)/write-managed-repo-env.sh"
  local suggested_branch=''
  local suggested_dir=''

  if [ -d "$repo_root/main" ]; then
    suggested_branch='main'
  elif [ -d "$repo_root/master" ]; then
    suggested_branch='master'
  fi

  if [ -z "$suggested_branch" ]; then
    suggested_branch='main'
  fi

  suggested_dir="$repo_root/$suggested_branch"

  printf 'to repair, run:\n' >&2
  printf '  HUB_WORKSPACE_ROOT="%s" bash %s "%s" "%s" "%s"\n' "$workspace_root" "$helper_path" "$repo_name" "$suggested_branch" "$suggested_dir" >&2
}

fail_metadata() {
  local repo_name="$1"
  local repo_root="$2"
  local workspace_root="$3"
  local helper_script_base_dir="$4"

  require_non_empty 'fail_metadata' 'repo_name' "$repo_name"
  require_non_empty 'fail_metadata' 'repo_root' "$repo_root"
  require_non_empty 'fail_metadata' 'workspace_root' "$workspace_root"
  require_non_empty 'fail_metadata' 'script_dir' "$helper_script_base_dir"

  metadata_refusal "$repo_name"
  metadata_repair_hint "$repo_name" "$repo_root" "$workspace_root" "$helper_script_base_dir"
  exit 1
}
