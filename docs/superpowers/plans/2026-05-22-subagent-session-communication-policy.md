## 1) Root-cause analysis

- **Resume routing was underspecified in practice.** AGENTS.md defines `$ses_<id> <reply>`, but the session id was **not consistently surfaced** at subagent start, pause, or completion, so users often lacked the exact token needed to resume the intended subagent.
- **Direct-to-subagent expectations were unmet.** Users reasonably expected `$ses_<id>` to route directly to the waiting subagent and bypass Maestro, but actual behavior sometimes restarted a fresh planner/subagent session instead of reattaching.
- **Handoff metadata was incomplete.** Existing required handoff text names the subagent, but does **not require** `session-id`, ownership, resume syntax, or pause/resume instructions in every handoff.
- **Authority boundaries were blurry.** In this workflow, Maestro or senior-implementer sometimes performed work assigned to planner, which made it unclear whether the planner session should be resumed or considered superseded.
- **Commit authority was ambiguous.** Repo docs assign planning and committing plan documents to planner, but session interruptions plus takeover behavior made ownership of the next action unclear.
- **Runtime aborts amplified policy gaps.** The prior incident summary shows worker shutdowns and `Aborted process` errors; once a live worker died, policy/operator guidance was not strong enough to guarantee that the next user reply reattached to the original session.

---

## 2) Concrete policy changes

### A. AGENTS.md unified-diff hunk

```diff
--- a/.config/opencode/AGENTS.md
+++ b/.config/opencode/AGENTS.md
@@
 ## Subagent delegation (short)
 
 - Policy (short): If a responsibility or skill in repo docs is assigned to a named subagent, the parent agent MUST spawn that subagent to perform the work. 
 - Routing question: before spawning, the Maestro MAY ask exactly one routing-only clarifying question (hard limit: 1 question, max 18 words) to choose the correct subagent or scope. This single question must not perform or begin the delegated work (no discovery beyond routing). After the Maestro spawns a subagent, that subagent follows its own interaction rules — e.g. an iterative, one‑question‑per‑message dialog — to refine scope and design.
 - Handoff wording (required): when spawning a named subagent the Maestro SHOULD use exactly:
 
   "Switching you to the <subagent> subagent now — please interact directly with it; I will remain available for orchestration."
+- Mandatory handoff metadata (required in EVERY subagent handoff, pause, and completion message):
+  - `Session: ses_<session-id>`
+  - `Resume: $ses_<session-id> <your reply>`
+  - `Owner: <subagent>`
+  - `Authority: only the owning subagent may perform <subagent> responsibilities unless a human-approved Maestro override is active`
+- Maestro handoff checklist (required before sending any subagent handoff):
+  1. Name the target subagent explicitly.
+  2. Include the exact session id in `ses_<id>` form.
+  3. Include the exact resume command in `$ses_<id> <reply>` form.
+  4. State that replies with `$ses_<id>` route to the owning subagent, not Maestro triage.
+  5. State that only the owning subagent may perform its named responsibilities unless the human activates the two-step Maestro override.
 - Per-subagent override: a subagent file may define a more specific first-message/handoff wording; that override applies only to that subagent and must be explicit in the subagent file.
@@
 # Subagent interaction rules:
@@
 Interaction rules (minimal):
 - Ask one clarifying question per message (repeat as needed — there is no single-question-per-session cap).
 - Perform only responsibilities listed in the subagent file.
+- The owning subagent MUST surface its session id on start, on any pause/wait-for-user message, and on completion/handoff back.
+- The owning subagent MUST include the exact resume syntax on every pause/wait-for-user message:
+
+  `To resume this session after a restart, reply in chat using: $ses_<session-id> <your reply here>`
+
+- No takeover rule: no other agent may perform the owning subagent's named responsibilities, commit on its behalf, or declare its scoped work complete unless the human has activated the two-step Maestro override for that exact scope.
 - When done, return control to the <parent agent> with the exact final handoff:
 
   "The <subagent> subagent has completed the scoped work. Returning control to the <parent agent>  for orchestration and next-step delegation."
@@
 ## Subagent resume token policy
@@
 - User-facing resume syntax: A user may resume a waiting subagent by sending a single-line message that begins with:
 
   $ses_<session-id> <their reply>
@@
 - Authorization: Only allow resume actions when the requester is authenticated as the session owner or has explicit permission to reply to that session. Reject anonymous or unauthorized resume attempts.
+- Routing guarantee: when a valid `$ses_<session-id>` token is present and authorization succeeds, the reply MUST be routed directly to that session's owning subagent rather than being re-triaged as a fresh Maestro task.
 - Privacy/safety: Perform authorization checks before token lookup or resume processing. For unauthorized requests, do not disclose session content and do not confirm whether a session exists unless policy explicitly allows it.
@@
 - Operator actions (no-code):
-  - Add the one-line resume hint to exported transcripts and to subagent prompts where sessions may be left waiting.
+  - Add the one-line resume hint plus `Session: ses_<id>` to exported transcripts and to subagent prompts where sessions may be left waiting.
   - When manually rehydrating a session, use the session-id directly (case-insensitive lookup), enforce authorization checks before applying the reply, and preserve the token verbatim.
   - Treat resume requests as audit events: record who requested/when/session-id/result and retain logs per your retention policy. Do not log full reply/session content by default.
   - If token is expired, require transcript-based/manual rehydration instead of direct resume.
```

### B. Add this explicit ownership/commit rule snippet

```markdown
## Named-responsibility ownership

- If repo docs assign a responsibility to a named subagent, that subagent is the sole owner of that responsibility for the active scope.
- Other agents, including Maestro and senior-implementer, MUST NOT perform that responsibility, commit artifacts owned by that responsibility, or answer in a way that implies takeover.
- Exception: the human may activate the existing two-step Maestro override for an exact short scope. Without that override, takeover is forbidden.
- If takeover would otherwise occur, the acting agent must refuse with:
  `Refused — owned by <subagent>; resume or re-dispatch that subagent, or use Maestro override.`
```

### C. Agent handoff template inserts

```markdown
Session: ses_<session-id>
Resume: $ses_<session-id> <your reply>
Owner: <subagent>
Authority: only the owning subagent may perform <subagent> responsibilities unless a human-approved Maestro override is active
```

---

## 3) Operational enforcement mechanisms

1. **Pre-spawn Maestro checklist**
   - **Where:** Maestro prompt / AGENTS.md
   - **Rule:** Maestro must not send a subagent handoff unless the handoff contains subagent name, `Session:`, `Resume:`, `Owner:`, `Authority:`.
   - **Verification:** manual prompt test with checklist; expected handoff contains all 5 fields.

2. **Resume-routing audit log**
   - **Where:** operator procedure / runtime audit logging
   - **Rule:** every `$ses_<id>` attempt logs requester, timestamp, session id, auth result, routed owner, outcome.
   - **Verification command/test:** send a valid and invalid `$ses_...` resume; confirm two audit entries exist.

3. **CI warning/enforcement scan for transcript/prompt docs**
   - **Where:** CI config
   - **Rule:** scan changed agent prompts / AGENTS.md for required strings: `Session: ses_`, `Resume: $ses_`, `Owner:`, `Authority:`.
   - **Verification command:**  
     `rg -n 'Session: ses_|Resume: \$ses_|Owner: |Authority:' .config/opencode ~/.config/opencode`
   - Start as warning, later fail CI.

4. **Commit-gating rule for planner-owned artifacts**
   - **Where:** agent prompt + review checklist
   - **Rule:** if a plan/spec/review-record commit exists, reviewer checks that the owning subagent authored/performed the action or a Maestro override is recorded.
   - **Verification:** PR checklist item: “Planner-owned artifact committed by planner or explicit override present.”

5. **Transcript export requirement**
   - **Where:** transcript export template / README/operator docs
   - **Rule:** exported transcripts must include a resumable footer with exact session id and command.
   - **Verification:** inspect exported transcript footer for `Session:` and `To resume...`.

---

## 4) Short migration plan

1. **Announce + doc update**
   - Publish the AGENTS.md policy update and updated handoff templates.
   - Tell operators/users that `$ses_<id>` is now the canonical direct-resume path.

2. **7-day warning mode**
   - Enable CI/prompt checks in warning mode only.
   - Track missing `Session:` / `Resume:` fields and takeover incidents.

3. **Enforcement**
   - Fail checks when handoff metadata is missing.
   - Require session-id presence for all subagent start/pause/completion messages.

---

## 5) Example updated handoff templates

### Start
```text
Switching you to the planner subagent now — please interact directly with it; I will remain available for orchestration.
Session: ses_1b0f1c87affesM8rI5JULY23Ic
Resume: $ses_1b0f1c87affesM8rI5JULY23Ic <your reply>
Owner: planner
Authority: only the owning subagent may perform planner responsibilities unless a human-approved Maestro override is active
```

### Pause / waiting for user
```text
I’m the planner subagent. I’m waiting for your reply before continuing.
Session: ses_1b0f1c87affesM8rI5JULY23Ic
Resume: $ses_1b0f1c87affesM8rI5JULY23Ic <your reply>
Owner: planner
Authority: only the owning subagent may perform planner responsibilities unless a human-approved Maestro override is active
To resume this session after a restart, reply in chat using: $ses_1b0f1c87affesM8rI5JULY23Ic <your reply here>
```

### Completion
```text
The planner subagent has completed the scoped work. Returning control to the Maestro for orchestration and next-step delegation.
Session: ses_1b0f1c87affesM8rI5JULY23Ic
Owner: planner
Authority: planner responsibilities remain planner-owned unless a human-approved Maestro override is activated for a new scope
```

### Recommended resume message pattern
```text
$ses_1b0f1c87affesM8rI5JULY23Ic Here is my answer
```

Planner session id: `ses_1b0f1c87affesM8rI5JULY23Ic`
