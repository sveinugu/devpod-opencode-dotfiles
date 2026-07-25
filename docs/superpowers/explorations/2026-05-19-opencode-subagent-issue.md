# Summary: Subagent abort/resume issue (2026-05-19)

Background
----------
On 2026-05-19 we observed repeated failures when spawning and resuming subagents (brainstormer/general). Subagent runs would start, ask a single clarifying question, and then the runtime would abort processing and the subagent would not receive user replies. The problem appeared while using OpenCode locally with the OpenCode Companion and when running inside a k3d/kubernetes environment.

Symptoms
--------
- Subagents are created and sessions are recorded in the DB, but the live in-memory worker handling the LLM call shuts down and the session processing aborts.
- Logs show repeated "ERROR ... Aborted process" messages and worker shutdown events ("service=default worker shutting down", "disposing all instances").
- After a restart of the OpenCode process the DB still contains transcripts, but UI replies to rehydrated subagents do not reliably resume the original sessions.

Evidence & key log excerpts
---------------------------
Relevant log slices and timestamps were saved in the runtime logs. Representative excerpts:

From /home/vscode/.local/share/opencode/log/2026-05-19T160916.log:

```
24382: INFO  2026-05-19T16:58:41 +1610ms service=default worker shutting down
24383: INFO  2026-05-19T16:58:41 +1ms service=default disposing all instances
24403: ERROR 2026-05-19T16:58:41 +2ms service=session.processor session.id=ses_1bed8aaecffeK8xJIEqUFS0Aq8 messageID=msg_e412cdd01001S9Ssc8O96vxUZv error=Aborted process
```

From /home/vscode/.local/share/opencode/log/2026-05-19T183203.log:

```
1106: INFO  2026-05-19T18:39:26 +6012ms service=session.prompt session.id=ses_1beff32adffex42WsKM8Hks5PF cancel
1107: ERROR 2026-05-19T18:39:26 +2ms service=session.processor session.id=ses_1beff32adffex42WsKM8Hks5PF messageID=msg_e41890904001gUueBGzJSZBK5E error=Aborted process
5945: INFO  2026-05-19T18:56:26 +8721ms service=default worker shutting down
5956: ERROR 2026-05-19T18:56:26 +2ms service=session.processor session.id=ses_1beff32adffex42WsKM8Hks5PF messageID=msg_e41988df5001ANkOGIahYr2WJM error=Aborted process
```

Sessions & transcripts
----------------------
Transcripts for aborted sessions were exported to /tmp/opencode/transcripts/. Affected session IDs include (non-exhaustive):

- ses_1beff32adffex42WsKM8Hks5PF (maestro)
- ses_1bed8aaecffeK8xJIEqUFS0Aq8 (brainstormer)
- ses_1bed0eb17ffeyoIQ5W5J1SfODL (brainstormer)
- ses_1beb188c8ffew4cIPI1b4qOU0g (brainstormer)

Files saved:
- /tmp/opencode/transcripts/ses_1beff32adffex42WsKM8Hks5PF.txt
- /tmp/opencode/transcripts/ses_1bed8aaecffeK8xJIEqUFS0Aq8.txt
- /tmp/opencode/transcripts/ses_1bed0eb17ffeyoIQ5W5J1SfODL.txt
- /tmp/opencode/transcripts/ses_1beb188c8ffew4cIPI1b4qOU0g.txt

Root-cause analysis (preliminary)
---------------------------------
- The immediate cause of the observed "Aborted process" errors is an internal worker shutdown: logs show the runtime intentionally or forcibly shutting down the default worker and disposing instances. When that happens in-flight LLM calls are aborted and session processors emit errors.
- Side effects: session records and transcripts remain in the DB, but the live LLM stream is lost and the runtime does not transparently reconnect the user to the waiting subagent.
- Secondary factors observed: snapshot/git warnings (e.g., "fatal: pathspec '.config/opencode/AGENTS.md' did not match any files") and some plugin/npm install errors in background logs. Those appear noisy but not the primary shutdown trigger.

Immediate mitigations (short-term)
---------------------------------
1. When rehydrating a session, use an explicit resume token that routes the reply to the correct session (reduce UI routing ambiguity). Example: require the user to send a two-line reply beginning with "resume-session: <session-id>" then the single answer line.
2. Increase session/LLM timeouts and add retries around session.processor/LLM calls to reduce aborts from transient failures.
3. Keep exported transcripts (already in /tmp/opencode/transcripts/) to allow manual rehydration and forensic analysis.

Recommended config edits (surgical)
-----------------------------------
- Make subagents addressable directly from the UI to avoid Maestro-only handoffs. Minimal frontmatter change for critical agents (example in ~/.config/opencode/agents/brainstormer.md):

```
mode: all
permission:
  edit: deny
  bash: ask
```

Apply similar conservative permission sets to @general and other subagents you want to converse with directly.

Long-term fixes (medium-term)
-----------------------------
1. UI plugin: implement a small opencode plugin that surfaces session/task IDs and provides a "Reply to subagent" button that attaches replies to the correct session id (best UX and robust against process restarts).
2. Resume-by-task_id: persist resume links in the UI so users can reattach to sessions after restarts instead of relying on Maestro routing.
3. Improve worker lifecycle telemetry: emit diagnostic records at shutdown (PID, exit code, memory usage) to determine whether OOM or supervisor restarts are the cause.

Next steps
----------
1. If you want, restart the OpenCode process and rehydrate a single session manually using the transcript file; I can assist by producing the exact resume token and a priming prompt to paste.
2. Apply the minimal agent frontmatter changes (mode: all + locked permissions) and restart OpenCode to allow direct replies.
3. If you prefer, I can scaffold the small UI plugin and provide exact file paths and a minimal hooks implementation to add a "Reply to subagent" button.

Contact & evidence locations
---------------------------
- Runtime logs: /home/vscode/.local/share/opencode/log/
- Transcripts: /tmp/opencode/transcripts/
- AGENTS.md and related config: /home/vscode/dotfiles/.config/opencode/AGENTS.md

Please review this summary. If it looks good I will commit it to branch work/opencode-subagent-issue.
