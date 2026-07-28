#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'refused: %s\n' "$1" >&2
  exit 1
}

require_absolute_path() {
  local path_value="$1"
  case "$path_value" in
    /*) ;;
    *) fail "path must be absolute: $path_value" ;;
  esac
}

require_executable_path() {
  local path_value="$1"
  local label="$2"

  require_absolute_path "$path_value"
  [ -x "$path_value" ] || fail "$label not executable at $path_value"
}

require_basename() {
  local path_value="$1"
  local expected_name="$2"
  local label="$3"

  [ "$(basename "$path_value")" = "$expected_name" ] || fail "$label basename must be $expected_name"
}

setpriv_binary=''
nono_binary=''
profile_path=''
agent_uid=''
agent_gid=''
runtime_home=''
runtime_xdg_config_home=''
runtime_xdg_cache_home=''
runtime_xdg_data_home=''
runtime_xdg_state_home=''
opencode_xdg_state_home=''
runtime_path=''
opencode_config_content=''
raw_opencode_binary=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --setpriv-binary)
      setpriv_binary="$2"
      shift 2
      ;;
    --nono-binary)
      nono_binary="$2"
      shift 2
      ;;
    --profile)
      profile_path="$2"
      shift 2
      ;;
    --agent-uid)
      agent_uid="$2"
      shift 2
      ;;
    --agent-gid)
      agent_gid="$2"
      shift 2
      ;;
    --runtime-home)
      runtime_home="$2"
      shift 2
      ;;
    --runtime-xdg-config-home)
      runtime_xdg_config_home="$2"
      shift 2
      ;;
    --runtime-xdg-cache-home)
      runtime_xdg_cache_home="$2"
      shift 2
      ;;
    --runtime-xdg-data-home)
      runtime_xdg_data_home="$2"
      shift 2
      ;;
    --runtime-xdg-state-home)
      runtime_xdg_state_home="$2"
      shift 2
      ;;
    --opencode-xdg-state-home)
      opencode_xdg_state_home="$2"
      shift 2
      ;;
    --runtime-path)
      runtime_path="$2"
      shift 2
      ;;
    --opencode-config-content)
      opencode_config_content="$2"
      shift 2
      ;;
    --raw-opencode-binary)
      raw_opencode_binary="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      fail "unsupported launch option: $1"
      ;;
  esac
done

[ -n "$setpriv_binary" ] || fail 'missing --setpriv-binary'
[ -n "$nono_binary" ] || fail 'missing --nono-binary'
[ -n "$profile_path" ] || fail 'missing --profile'
[ -n "$agent_uid" ] || fail 'missing --agent-uid'
[ -n "$agent_gid" ] || fail 'missing --agent-gid'
[ -n "$runtime_home" ] || fail 'missing --runtime-home'
[ -n "$runtime_xdg_config_home" ] || fail 'missing --runtime-xdg-config-home'
[ -n "$runtime_xdg_cache_home" ] || fail 'missing --runtime-xdg-cache-home'
[ -n "$runtime_xdg_data_home" ] || fail 'missing --runtime-xdg-data-home'
[ -n "$runtime_xdg_state_home" ] || fail 'missing --runtime-xdg-state-home'
[ -n "$opencode_xdg_state_home" ] || fail 'missing --opencode-xdg-state-home'
[ -n "$runtime_path" ] || fail 'missing --runtime-path'
[ -n "$opencode_config_content" ] || fail 'missing --opencode-config-content'
[ -n "$raw_opencode_binary" ] || fail 'missing --raw-opencode-binary'

case "$agent_uid" in
  ''|*[!0-9]*) fail 'agent uid must be numeric' ;;
esac

case "$agent_gid" in
  ''|*[!0-9]*) fail 'agent gid must be numeric' ;;
esac

require_executable_path "$setpriv_binary" 'setpriv binary'
require_basename "$setpriv_binary" 'setpriv' 'setpriv binary'
require_executable_path "$nono_binary" 'nono binary'
require_basename "$nono_binary" 'nono' 'nono binary'
require_executable_path "$raw_opencode_binary" 'raw opencode binary'
require_basename "$raw_opencode_binary" 'opencode-raw' 'raw opencode binary'

require_absolute_path "$runtime_home"
require_absolute_path "$runtime_xdg_config_home"
require_absolute_path "$runtime_xdg_cache_home"
require_absolute_path "$runtime_xdg_data_home"
require_absolute_path "$runtime_xdg_state_home"
require_absolute_path "$opencode_xdg_state_home"
require_absolute_path "$profile_path"

[ -r "$profile_path" ] || fail "nono profile not readable at $profile_path"

exec /usr/bin/env HOME="$runtime_home" XDG_CONFIG_HOME="$runtime_xdg_config_home" XDG_CACHE_HOME="$runtime_xdg_cache_home" XDG_DATA_HOME="$runtime_xdg_data_home" XDG_STATE_HOME="$runtime_xdg_state_home" PATH="$runtime_path" LD_PRELOAD= LD_LIBRARY_PATH= PYTHONPATH= DYLD_INSERT_LIBRARIES= "$setpriv_binary" --reuid="$agent_uid" --regid="$agent_gid" --clear-groups --inh-caps=-all --ambient-caps=-all --bounding-set=-all --nnp "$nono_binary" run --profile "$profile_path" --allow-cwd --no-rollback-prompt --silent -- /usr/bin/env HOME="$runtime_home" XDG_CONFIG_HOME="$runtime_xdg_config_home" XDG_CACHE_HOME="$runtime_xdg_cache_home" XDG_DATA_HOME="$runtime_xdg_data_home" XDG_STATE_HOME="$opencode_xdg_state_home" OPENCODE_CONFIG_CONTENT="$opencode_config_content" "$raw_opencode_binary" "$@"
