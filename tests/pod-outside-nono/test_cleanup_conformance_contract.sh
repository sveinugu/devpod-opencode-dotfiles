#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_cleanup_conformance_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_outside_nono_test 'test_cleanup_conformance_contract'

legacy_agents_dir="$repo_root/.config/opencode/.agents"
harness_skills_dir="$repo_root/.config/opencode/skills"
legacy_claude_skills_dir="$repo_root/.config/opencode/.claude/skills"
legacy_skills_lock="$repo_root/.config/opencode/skills-lock.json"
runtime_plugin="$repo_root/.config/opencode/plugins/nono-sandbox.ts"
runtime_skills_dir="$repo_root/.config/opencode/skills"
runtime_skill="$runtime_skills_dir/nono-sandbox"
runtime_marker="$repo_root/.config/opencode/.nono-opencode-v1-pack-marker"

[ ! -e "$legacy_agents_dir" ] || fail 'deprecated .config/opencode/.agents surface should not exist'
for external_skill in clean-code pragmatic-programmer; do
  [ ! -e "$harness_skills_dir/$external_skill" ] || fail "external skill belongs under .agents/skills: $external_skill"
done
[ ! -e "$legacy_claude_skills_dir" ] || fail 'deprecated .config/opencode/.claude/skills surface should not exist'
[ ! -e "$legacy_skills_lock" ] || fail 'deprecated .config/opencode/skills-lock.json should not exist'

python3 - "$runtime_plugin" "$runtime_skills_dir" "$runtime_skill" "$runtime_marker" <<'PY'
import pathlib
import sys

plugin_path, skills_dir, skill_path, marker_path = map(pathlib.Path, sys.argv[1:])
pack_plugin_suffix = pathlib.Path("packages/nolabs-ai/opencode-v1/plugin/nono-sandbox.ts")
pack_skill_suffix = pathlib.Path("packages/nolabs-ai/opencode-v1/skills/nono-sandbox")

def require_pack_link(link, target_suffix, label):
    if not link.exists() and not link.is_symlink():
        return
    if not link.is_symlink():
        raise SystemExit(f"{label} must remain a symlink into the installed Nono pack")
    try:
        target = link.resolve(strict=True)
    except FileNotFoundError:
        raise SystemExit(f"{label} points to a missing Nono pack target")
    if not target.as_posix().endswith(target_suffix.as_posix()):
        raise SystemExit(f"{label} points outside the installed Nono OpenCode v1 pack: {target}")

require_pack_link(plugin_path, pack_plugin_suffix, "Nono plugin")
require_pack_link(skill_path, pack_skill_suffix, "Nono skill")

if skills_dir.exists() and not skills_dir.is_symlink():
    entries = sorted(path.name for path in skills_dir.iterdir())
    if entries != ["nono-sandbox"]:
        raise SystemExit(f"unexpected config-local generated skills: {entries!r}")

if marker_path.exists() and (marker_path.is_symlink() or marker_path.stat().st_size != 0):
    raise SystemExit("Nono pack marker must be an empty generated file")
PY

for generated_output in \
  .config/opencode/plugins/opencode-loop.js \
  .config/opencode/commands/loop-help.md \
  .config/opencode/commands/loop.md; do
  if git -C "$repo_root" ls-files --error-unmatch -- "$generated_output" >/dev/null 2>&1; then
    fail "installer-generated output must not be tracked: $generated_output"
  fi
done

[ -d "$repo_root/.agents/skills" ] || fail 'canonical top-level .agents/skills surface missing'
[ -f "$repo_root/skills-lock.json" ] || fail 'canonical top-level skills-lock.json missing'
[ -f "$repo_root/harness-installs.jsonc" ] || fail 'canonical top-level harness-installs.jsonc missing'

python3 - "$repo_root/harness-installs.jsonc" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
outputs = set()
for entry in manifest.get('installs', []):
    for output in entry.get('outputs', []):
        outputs.add(output)

declared_outputs = {
    '.config/opencode/plugins/opencode-loop.js',
    '.config/opencode/commands/loop.md',
    '.config/opencode/commands/loop-help.md',
    '.config/opencode/commands/loop-goal.md',
}

if outputs != declared_outputs:
    raise SystemExit(f'manifest output set mismatch: {outputs!r}')
PY

printf 'PASS test_cleanup_conformance_contract\n'
