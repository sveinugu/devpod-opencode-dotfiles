# docs/superpowers authoring guide

Purpose: define what each `docs/superpowers/` subdirectory is for, so new artifacts land in the right place.

## Directory map

- `change-records/`
  - Change ledgers and historical additive records between full spec/plan cycles.
  - Example: manual additions logs, migration notes, change timelines.

- `explorations/`
  - Exploratory or investigative write-ups that are informative but not binding implementation authority.
  - Example: alternatives research, incident/issue explorations, problem analysis notes.

- `plans/`
  - Approved implementation plans (task breakdown, acceptance tests, sequencing).
  - Use when translating a spec/design into executable work.

- `review-records/`
  - Persisted review artifacts when a durable record is explicitly requested or required.
  - For PR-based work, GitHub review history is still the default review record.

- `runbooks/`
  - Operational how-to documentation (repeatable procedures and command flows).
  - Focus on action-oriented guidance for host/pod/operator workflows.

- `specs/`
  - Design/specification artifacts describing scope, architecture, constraints, and acceptance intent.
  - May be used as binding requirements sources when referenced in delegation packets.

- `templates/`
  - Reusable templates for handoffs, packets, and process documentation.

## Placement rules

- Put artifacts in the **smallest correct semantic home** (do not overload `runbooks/` with non-procedural records).
- If no existing subdirectory fits, add a new one only when it has a distinct, reusable purpose.
- Keep naming date-prefixed where history/auditability matters (`YYYY-MM-DD-...`).
