#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(git rev-parse --show-toplevel)}"
manifest_path="$repo_root/harness-installs.jsonc"

if [ ! -f "$manifest_path" ]; then
  printf 'refused: top-level harness-installs.jsonc is missing at %s\n' "$manifest_path" >&2
  exit 1
fi

run_install_command() {
  local name="$1"
  local phase="$2"
  local working_directory="$3"
  shift 3

  if [ "$#" -eq 0 ]; then
    printf 'refused: %s phase %s command is empty\n' "$name" "$phase" >&2
    exit 1
  fi

  if [ "${DRY_RUN:-false}" = 'true' ]; then
    printf 'DRY-RUN (%s/%s) (cd %s && %s)\n' "$name" "$phase" "$working_directory" "$*"
    return 0
  fi

  (
    cd "$working_directory"
    "$@"
  )
}

verify_declared_outputs() {
  local name="$1"
  shift

  if [ "$#" -eq 0 ]; then
    printf 'refused: %s outputs list is empty\n' "$name" >&2
    exit 1
  fi

  local output=''
  for output in "$@"; do
    if [ "${DRY_RUN:-false}" = 'true' ]; then
      printf 'DRY-RUN verify output: %s\n' "$output"
      continue
    fi

    if [ ! -e "$repo_root/$output" ]; then
      printf 'refused: declared output missing for %s: %s\n' "$name" "$output" >&2
      exit 1
    fi
  done
}

while IFS=$'\t' read -r name working_directory install_json uninstall_json outputs_json; do
  workdir_path="$repo_root/$working_directory"

  if [ ! -d "$workdir_path" ]; then
    printf 'refused: workingDirectory for %s does not exist: %s\n' "$name" "$workdir_path" >&2
    exit 1
  fi

  readarray -t install_cmd < <(python3 - <<'PY' "$install_json"
import json
import sys
for token in json.loads(sys.argv[1]):
    print(token)
PY
)

  readarray -t uninstall_cmd < <(python3 - <<'PY' "$uninstall_json"
import json
import sys
for token in json.loads(sys.argv[1]):
    print(token)
PY
)

  readarray -t declared_outputs < <(python3 - <<'PY' "$outputs_json"
import json
import sys
for token in json.loads(sys.argv[1]):
    print(token)
PY
)

  run_install_command "$name" "uninstall" "$workdir_path" "${uninstall_cmd[@]}"
  run_install_command "$name" "install" "$workdir_path" "${install_cmd[@]}"
  verify_declared_outputs "$name" "${declared_outputs[@]}"
done < <(python3 - <<'PY' "$manifest_path"
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
installs = manifest.get('installs')
if not isinstance(installs, list) or not installs:
    raise SystemExit('manifest installs must be a non-empty list')

required = ('name', 'workingDirectory', 'install', 'uninstall', 'outputs')
for entry in installs:
    missing = [field for field in required if field not in entry]
    if missing:
        raise SystemExit(f'manifest entry missing fields: {missing}')
    print(
        entry['name'],
        entry['workingDirectory'],
        json.dumps(entry['install']),
        json.dumps(entry['uninstall']),
        json.dumps(entry['outputs']),
        sep='\t',
    )
PY
)
