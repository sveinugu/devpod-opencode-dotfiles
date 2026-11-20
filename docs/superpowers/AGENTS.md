# docs/superpowers authoring guide

Use this guide to choose the right `docs/superpowers/` subdirectory for each artifact.

## Directory map

| Directory | Purpose |
| --- | --- |
| `change-records/` | Change ledgers and historical additive records between full spec/plan cycles. Examples include manual additions logs, migration notes and change timelines. |
| `explorations/` | Informative investigations, such as alternatives research, incident explorations and problem analysis. These do not provide binding implementation authority. |
| `plans/` | Approved implementation plans that translate specs/designs into executable work. They cover task breakdown, acceptance tests and sequencing. |
| `review-records/` | Persisted reviews when a durable record is explicitly requested or required. GitHub review history remains the default for PR-based work. |
| `runbooks/` | Operational how-to documentation with repeatable procedures and commands. Focus on actions for host, pod and operator workflows. |
| `specs/` | Designs and specifications that describe scope, architecture, constraints and acceptance intent. These may be binding requirements sources when referenced in delegation packets. |
| `templates/` | Reusable templates for handoffs, packets and process documentation. |

## Placement rules

- Put each artifact in the most specific directory that fits its purpose. Do not overload `runbooks/` with non-procedural records.
- If no existing subdirectory fits, add a new one only when it has a distinct, reusable purpose.
- Keep naming date-prefixed where history/auditability matters (`YYYY-MM-DD-...`).

## Manual additions maintenance

For this dotfiles repository, authors must log operational, security, harness/workflow or verification-strategy changes made outside a full spec/plan cycle. Update `change-records/manual-additions-log.md` after the implementation commit and before handoff.

Log only committed work with actual commit references. Never log uncommitted work or pending placeholders. Follow the log's organizing principles, including what to omit.

When a full spec/plan cycle changes an earlier logged addition, normally add only a pointer. Do not duplicate its design or acceptance criteria.

Review the entry for current behavior, chronological commit dates and traceable references. Do not add exact-wording tests for the log.
