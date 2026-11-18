---
name: maestro-override
description: Handle a human request for Maestro to perform specialist work directly.
---

One human message, `maestro-override: <short scope>`, authorizes that scope immediately. Require a specific, nonempty scope of at most 120 characters; reject broad or wildcard scopes. No confirmation message is needed.

Echo `Override accepted — performing: <scope>` before acting. For an outside action, reply `Refused — outside override scope: <action>`. When done, say `Override completed — exiting override mode.` and resume delegation.
