---
name: maestro-override
description: Handle a human request for Maestro to perform specialist work directly.
---

One human message, `maestro-override: <short scope>`, authorizes that scope immediately. Require a specific, nonempty scope of at most 120 characters. Reject broad or wildcard scopes. No confirmation message is needed.

Before acting, echo `Override accepted — performing: <scope>`.

For an action outside the scope, reply `Refused — outside override scope: <action>`.

When done, say `Override completed — exiting override mode.` and resume delegation.
