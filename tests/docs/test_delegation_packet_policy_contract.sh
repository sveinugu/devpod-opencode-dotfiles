#!/usr/bin/env bash
# Doc-contract test: delegation packet policy drift guardrails
#
# Fails if:
#  - Canonical chapter is missing required prevention-policy anchors
#  - Forbidden legacy packet fields appear in canonical surfaces
#  - Verbatim quoting / preview-gate anchors are absent

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"
maestro="$repo_root/.config/opencode/agents/maestro.md"
templates="$repo_root/docs/superpowers/templates/subagent-handoff-templates.md"
spec="$repo_root/docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md"
tmpdir="$(mktemp -d)"

cleanup() {
    rm -rf "$tmpdir"
}

trap cleanup EXIT

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

extract_pre_canonical_agents() {
    local destination="$1"
    local canonical_start

    canonical_start="$(rg -n "^# Delegation & Sessions \(canonical\)$" "$agents" | cut -d: -f1)"
    if [ -z "$canonical_start" ]; then
        printf '  FAIL  Cannot extract pre-canonical AGENTS.md region — canonical chapter heading missing\n' >&2
        fail=1
        : > "$destination"
        return
    fi

    python - "$agents" "$canonical_start" "$destination" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
canonical_start = int(sys.argv[2])
destination = Path(sys.argv[3])

lines = source.read_text().splitlines()
destination.write_text("\n".join(lines[: canonical_start - 1]) + "\n")
PY
}

echo "=== Delegation Packet Policy Contract Test ==="
echo ""

pre_canonical_agents="$tmpdir/agents-pre-canonical.md"
extract_pre_canonical_agents "$pre_canonical_agents"

# --- Required anchors in canonical chapter ---
echo "--- Required anchors in AGENTS.md canonical chapter ---"
check_anchor "$agents" "# Delegation & Sessions (canonical)" "Canonical chapter heading"
check_anchor "$agents" "Delegation Packet (closed schema; Maestro" "Delegation Packet section"
check_anchor "$agents" '`Worktree path:` (explicit absolute path to editable checkout)' "Worktree path allowed field"
check_anchor "$agents" "Maestro-side prevention for new scoped delegation" "Maestro prevention subsection"
check_anchor "$agents" 'Maestro MUST NOT call Task / launch a subagent for new scoped delegation until the `Delegation Packet` has passed the Maestro pre-dispatch checks defined below' "Pre-dispatch prohibition"
check_anchor "$agents" 'If the packet fails any pre-dispatch check, Maestro MUST refuse dispatch, MUST NOT emit the required handoff wording, MUST NOT fabricate session metadata, and MUST instead surface the failure and seek correction.' "Refusal-before-launch rule"
check_anchor "$agents" 'Delegation Packet refused — <brief reason>. Dispatch stopped before launch.' "Refusal wording anchor"
check_anchor "$agents" 'If Maestro had to choose, compress, or explain, preview is mandatory.' "Preview umbrella rule"
check_anchor "$agents" 'Router-owned metadata (`Session:`, `Resume:`, `Owner:`, `Authority:`) is exempt from the preview requirement because those fields are launch-generated and populated only after Task returns.' "Router metadata preview exemption"
check_anchor "$agents" 'If a single full user message is sufficient, Maestro should quote that whole message.' "Full-message quoting default"
check_anchor "$agents" 'Partial-message quoting automatically makes the packet non-trivial and therefore preview-gated.' "Partial-message preview gate"
check_anchor "$agents" 'This policy should be written so a later runtime validator can implement it directly, but no runtime/plugin work is part of this slice.' "Runtime/plugin deferral"
check_anchor "$agents" "Annex (non-authoritative; not part of Delegation Packet)" "Annex section"
check_anchor "$agents" "Verbatim quoting contract" "Verbatim quoting section"
check_anchor "$agents" "Artifact semantics + handshake" "Artifact semantics section"
check_anchor "$agents" 'When `Artifact paths:` is present, all listed paths are binding requirements sources, and the handshake applies across the full listed set rather than only the first path.' "Artifact paths plural semantics"
check_anchor "$agents" "Required handoff wording" "Handoff wording section"
check_anchor "$agents" "Session metadata visibility timing" "Session metadata visibility"
check_anchor "$agents" "Resume token routing semantics" "Resume token routing section"
check_anchor "$agents" "Recovery alignment" "Recovery alignment section"
check_anchor "$agents" "Anti-scatter checklist" "Anti-scatter checklist"
check_anchor "$agents" "If Highlight is present but does not match verbatim lines after stripping markup" "Highlight mismatch stop-rule"
check_anchor "$agents" "ONLY permitted text in the dispatch message is the required handoff wording line" "Outer-boundary handoff-only rule"
check_anchor "$agents" 'Open questions:` entries must be questions' "Open questions must be questions"
check_anchor "$agents" 'Hypotheses:` bullet MUST include the literal phrase `confirm before relying`' "Hypotheses confirm-before-relying rule"
check_anchor "$agents" 'Evidence blocks MUST contain raw output only inside a fenced block and MUST include a `source:` label' "Evidence raw-output source-label rule"

echo ""
echo "--- Required pre-dispatch checks in AGENTS.md ---"
check_anchor "$agents" "Allowed fields only" "Allowed-fields-only check"
check_anchor "$agents" "Verbatim quoting contract satisfied" "Verbatim quoting check"
check_anchor "$agents" "Warnings discipline" "Warnings discipline check"
check_anchor "$agents" "Artifact-path discipline" "Artifact-path discipline check"
check_anchor "$agents" "Packet/Annex boundary discipline" "Packet/Annex boundary check"
check_anchor "$agents" 'For non-trivial packets, Maestro must show the exact outgoing packet content that exists before launch and require explicit user approval before dispatch.' "Non-trivial exact-packet preview rule"
check_anchor "$agents" 'This preview excludes router-owned metadata (`Session:`, `Resume:`, `Owner:`, `Authority:`) because those fields do not exist until after launch.' "Preview excludes launch-generated metadata"

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
forbidden_in "$templates" "or N/A" "N/A placeholder text in templates"
forbidden_in "$maestro" "^\\s*Active slice:" "Active slice: in maestro.md"
forbidden_in "$maestro" "^\\s*Deliverables:" "Deliverables: in maestro.md"
forbidden_in "$maestro" "^\\s*Non-deliverables:" "Non-deliverables: in maestro.md"
forbidden_in "$maestro" "^\\s*Provenance:" "Provenance: in maestro.md"

# --- No duplicate packet schema before canonical chapter ---
echo ""
echo "--- No duplicate packet schema before canonical chapter ---"
forbidden_in "$pre_canonical_agents" "Allowed packet fields" "Pre-canonical AGENTS.md duplicates allowed packet fields"
forbidden_in "$pre_canonical_agents" "Forbidden packet content" "Pre-canonical AGENTS.md duplicates forbidden packet content"
forbidden_in "$pre_canonical_agents" "Example packet" "Pre-canonical AGENTS.md duplicates example packet"

# --- Maestro pointer verification ---
echo ""
echo "--- Maestro pointer verification ---"
check_anchor "$maestro" "Delegation Packet" "Maestro points to AGENTS.md canonical"
check_anchor "$maestro" "are defined in" "Maestro pointer has reference path"
check_anchor "$maestro" 'Preview any non-trivial packet before dispatch by showing the exact pre-launch packet content and obtaining explicit user approval.' "Maestro pre-launch preview wording"

# --- Template preview guidance verification ---
echo ""
echo "--- Template preview guidance verification ---"
check_anchor "$templates" 'Preview non-trivial packets before dispatch by showing the exact pre-launch packet content and obtaining explicit user approval.' "Template preview guidance matches canonical rule"

# --- Anti-scatter order verification ---
echo ""
echo "--- Anti-scatter order verification ---"
check_anchor_regex "$agents" '1\. \*\*Identify target subagent and confirm this is new scoped delegation\.' "Anti-scatter starts with target identification"
check_anchor_regex "$agents" '5\. \*\*Run Maestro pre-dispatch checks\.' "Anti-scatter validates before launch"
check_anchor_regex "$agents" '6\. \*\*If the packet is non-trivial, preview the exact pre-launch packet content and obtain explicit user approval\.' "Anti-scatter pre-launch preview wording"
check_anchor_regex "$agents" '7\. \*\*Only then call Task / launch the subagent\.' "Anti-scatter launch after validation"
check_anchor_regex "$agents" '8\. \*\*After successful launch, emit required handoff wording and validated session metadata\.' "Anti-scatter metadata after launch"

echo ""
if [ "$fail" -eq 0 ]; then
    printf 'PASS test_delegation_packet_policy_contract\n'
else
    printf 'FAIL test_delegation_packet_policy_contract\n' >&2
    exit 1
fi
