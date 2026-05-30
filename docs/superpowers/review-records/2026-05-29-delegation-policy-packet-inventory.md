# Delegation Policy Packet Inventory

Date: 2026-05-30
Branch: `delegation-policy-consolidation`
Related plan: `docs/superpowers/plans/2026-05-29-delegation-policy-consolidation.md`

## Purpose

Record the user-approved decisions for delegation-packet-related policy surfaces before implementation begins.

## Inventory and decisions

| ID | Location | What it is | Current state | Conflict type | User decision | Action taken |
|---:|---|---|---|---|---|---|
| 1 | `.config/opencode/AGENTS.md` | Live policy; Delegation Packet section (closed schema) | Clean closed-schema packet, but delegation flow is scattered across 5+ subsections | Structural duplication / scattered flow | **keep + consolidate** | Pending implementation: consolidate into one canonical sequential chapter/checklist in AGENTS.md |
| 2 | `.config/opencode/agents/maestro.md` | Maestro agent prompt; own `# Delegation Packet` section | Mirrors AGENTS.md closed schema | DRY violation / duplication | **migrate** | Pending implementation: reduce to pointer + Maestro-only operational rules |
| 3 | `.config/opencode/agents/planner.md` | Planner agent prompt | One-line reference to Delegation Packet definition | None | **keep** | No change planned unless needed for pointer consistency |
| 4 | Other agent specs (`brainstormer.md`, `code-reviewer.md`, `docs-reviewer.md`, `junior-implementer.md`, `senior-implementer.md`, `general.md`, `policy-implementer.md`) | Agent prompts | No packet-related content found in inventory search; only skill references | None | **keep** | No packet-related edits planned |
| 5 | `docs/superpowers/templates/subagent-handoff-templates.md` | Handoff template | Clean closed-schema template; includes `Artifact path`, `Verbatim user request`, `Warnings`, `Preview:` | Missing Annex example for approved spec | **migrate** | Pending implementation: add Annex section + spec addendum adjustments |
| 6 | `docs/superpowers/plans/2026-05-22-maestro-intent-preservation-policy.md` | Old plan document (not live policy) | Contains legacy intent-preserving packet fields (`Active slice`, `Deliverables`, `Non-deliverables`, `Provenance`, `Verbatim user context`) and legacy tests | Historical schema conflict only | **historical** | Pending implementation: mark as superseded/historical, do not treat as live policy |
| 7 | `docs/superpowers/specs/2026-05-24-delegation-packet-pragmatic-tdd-policy-design.md` | Older spec (historic) | Earlier Delegation Packet concept; closed-schema compatible | Overlap with newer binding spec | **historical** | Pending implementation: retain as historical/context, add superseded pointer if needed |
| 8 | `docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md` | Binding approved spec | Closed-schema + Annex target design | None | **keep canonical** | Pending implementation: apply approved addendum nits and use as binding source |
| 9 | Upstream skill `subagent-driven-development/implementer-prompt.md` (adopted by reference) | Skill template referenced via `subagent-driven-development` in agent prompts | Rich-context expectations (`Task Description`, `Context`, `Your Job`, etc.) | Policy risk: conflicts with “instructions live in artifact” | **policy-override** | Pending implementation: local policy states artifact is authoritative; packet/Annex must not carry instructions |

## Notes

- This record captures user approval of inventory decisions before implementation.
- “Pending implementation” means the approved plan still needs to be executed; this review record does not itself change policy.
- Runtime routing behavior is out of scope for this inventory; this covers documentation/prompt/template policy surfaces only.
