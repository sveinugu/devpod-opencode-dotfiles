#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
artifact="$repo_root/docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md"
fail=0

check_fixed() {
    local file="$1" pattern="$2" label="$3"
    if rg -qF -- "$pattern" "$file" 2>/dev/null; then
        printf '  PASS  %s\n' "$label"
    else
        printf '  FAIL  %s — missing in %s\n' "$label" "$file" >&2
        fail=1
    fi
}

check_surface_label() {
    local file="$1" surface="$2" label="$3"
    local pattern

    pattern="$(python - "$surface" "$label" <<'PY'
import re
import sys

surface = re.escape(sys.argv[1])
label = re.escape(sys.argv[2])
print(rf'(?ms)^###\s+{surface}\s*$\n(?:(?!^###\s|^##\s).)*{label}')
PY
)"

    if rg -qUP -- "$pattern" "$file" 2>/dev/null; then
        printf '  PASS  %s contains "%s"\n' "$surface" "$label"
    else
        printf '  FAIL  %s missing "%s" in %s\n' "$surface" "$label" "$file" >&2
        fail=1
    fi
}

echo "=== Repo Documentation + Refactor Audit Contract Test ==="

check_fixed "$artifact" '## Surface inventory' 'Top-level section: Surface inventory'
check_fixed "$artifact" '## Documentation gap inventory' 'Top-level section: Documentation gap inventory'
check_fixed "$artifact" '## Clean-code hotspot inventory' 'Top-level section: Clean-code hotspot inventory'
check_fixed "$artifact" '## Prioritized follow-on slices' 'Top-level section: Prioritized follow-on slices'
check_fixed "$artifact" '## Sequencing rationale' 'Top-level section: Sequencing rationale'

check_fixed "$artifact" '### Entry and orientation surfaces' 'Surface subsection: Entry and orientation surfaces'
check_fixed "$artifact" '### Operational and runbook surfaces' 'Surface subsection: Operational and runbook surfaces'
check_fixed "$artifact" '### Developer command and workflow surfaces' 'Surface subsection: Developer command and workflow surfaces'
check_fixed "$artifact" '### Agent-facing guidance and orientation surfaces' 'Surface subsection: Agent-facing guidance and orientation surfaces'

for surface in \
    'Entry and orientation surfaces' \
    'Operational and runbook surfaces' \
    'Developer command and workflow surfaces' \
    'Agent-facing guidance and orientation surfaces'
do
    check_surface_label "$artifact" "$surface" 'Current role'
    check_surface_label "$artifact" "$surface" 'Primary audiences'
    check_surface_label "$artifact" "$surface" 'Current assets'
    check_surface_label "$artifact" "$surface" 'Documentation gaps'
    check_surface_label "$artifact" "$surface" 'Readability/refactor hotspots'
    check_surface_label "$artifact" "$surface" 'Risk of change'
    check_surface_label "$artifact" "$surface" 'Recommended slice type'
done

check_fixed "$artifact" 'P1 — foundation blockers' 'Priority model label: P1 foundation blockers'
check_fixed "$artifact" 'P2 — important structural improvements' 'Priority model label: P2 important structural improvements'
check_fixed "$artifact" 'P3 — opportunistic cleanups' 'Priority model label: P3 opportunistic cleanups'
check_fixed "$artifact" 'Supporting policy nudge' 'Priority model label: Supporting policy nudge'

if [ "$fail" -eq 0 ]; then
    printf 'PASS test_repo_documentation_refactor_audit\n'
else
    printf 'FAIL test_repo_documentation_refactor_audit\n' >&2
    exit 1
fi
