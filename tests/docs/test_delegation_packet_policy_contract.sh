#!/usr/bin/env bash
# Doc-contract test: delegation packet policy drift guardrails
#
# Fails if:
#  - Canonical chapter is missing required anchor phrases
#  - Forbidden legacy packet fields appear in canonical surfaces
#  - Verbatim quoting contract anchors are absent

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"
maestro="$repo_root/.config/opencode/agents/maestro.md"
templates="$repo_root/docs/superpowers/templates/subagent-handoff-templates.md"
spec="$repo_root/docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md"

fail=0

check_anchor() {
    local file="$1" pattern="$2" label="$3"
    if rg -qF "$pattern" "$file"; then
        printf '  PASS  %s\n' "$label"
    else
        printf '  FAIL  %s — missing anchor in %s\n' "$label" "$file" >&2
        fail=1
    fi
}

check_anchor_regex() {
    local file="$1" pattern="$2" label="$3"
    if rg -q "$pattern" "$file"; then
        printf '  PASS  %s\n' "$label"
    else
        printf '  FAIL  %s — missing anchor in %s\n' "$label" "$file" >&2
        fail=1
    fi
}

forbidden_in() {
    local file="$1" pattern="$2" label="$3"
    if rg -q "$pattern" "$file"; then
        printf '  FAIL  %s — forbidden field found in %s\n' "$label" "$file" >&2
        rg -n "$pattern" "$file" >&2
        fail=1
    else
        printf '  PASS  %s\n' "$label"
    fi
}

echo "=== Delegation Packet Policy Contract Test ==="
echo ""

# --- Required anchors in canonical chapter ---
echo "--- Required anchors in AGENTS.md canonical chapter ---"
check_anchor "$agents" "# Delegation & Sessions (canonical)" "Canonical chapter heading"
check_anchor "$agents" "Delegation Packet (closed schema; Maestro" "Delegation Packet section"
check_anchor "$agents" "Annex (non-authoritative; not part of Delegation Packet)" "Annex section"
check_anchor "$agents" "Verbatim quoting contract" "Verbatim quoting section"
check_anchor "$agents" "Artifact semantics + handshake" "Artifact semantics section"
check_anchor "$agents" "Required handoff wording" "Handoff wording section"
check_anchor "$agents" "Session metadata visibility timing" "Session metadata visibility"
check_anchor "$agents" "Anti-scatter checklist" "Anti-scatter checklist"

# --- Required anchors in spec ---
echo ""
echo "--- Required anchors in spec ---"
check_anchor "$spec" "Delegation Packet" "Spec: packet schema"
check_anchor "$spec" "Annex (non-authoritative; not part of Delegation Packet)" "Spec: annex header"
check_anchor "$spec" "Highlight (derived from verbatim" "Spec: highlight rules"
check_anchor "$spec" "Subagent stop-rule" "Spec: stop rule"

# --- Forbidden legacy fields in canonical surfaces ---
echo ""
echo "--- Forbidden legacy fields in canonical surfaces ---"
forbidden_in "$agents" "^\\s*Active slice:" "Active slice: in AGENTS.md"
forbidden_in "$agents" "^\\s*Deliverables:" "Deliverables: in AGENTS.md"
forbidden_in "$agents" "^\\s*Non-deliverables:" "Non-deliverables: in AGENTS.md"
forbidden_in "$agents" "^\\s*Provenance:" "Provenance: in AGENTS.md"
forbidden_in "$templates" "^\\s*Active slice:" "Active slice: in templates"
forbidden_in "$templates" "^\\s*Deliverables:" "Deliverables: in templates"
forbidden_in "$templates" "^\\s*Non-deliverables:" "Non-deliverables: in templates"
forbidden_in "$templates" "^\\s*Provenance:" "Provenance: in templates"
forbidden_in "$maestro" "^\\s*Active slice:" "Active slice: in maestro.md"
forbidden_in "$maestro" "^\\s*Deliverables:" "Deliverables: in maestro.md"
forbidden_in "$maestro" "^\\s*Non-deliverables:" "Non-deliverables: in maestro.md"
forbidden_in "$maestro" "^\\s*Provenance:" "Provenance: in maestro.md"

# --- Maestro pointer verification ---
echo ""
echo "--- Maestro pointer verification ---"
check_anchor "$maestro" "Delegation Packet" "Maestro points to AGENTS.md canonical"
check_anchor "$maestro" "are defined in" "Maestro pointer has reference path"

echo ""
if [ "$fail" -eq 0 ]; then
    printf 'PASS test_delegation_packet_policy_contract\n'
else
    printf 'FAIL test_delegation_packet_policy_contract\n' >&2
    exit 1
fi
