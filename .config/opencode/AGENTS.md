# Overview

The current configuration allows subagent-driven-development according to the `obra/superpowers` plugin, with (currently) a less powerful `maestro` agent coordinating (mostly) more powerful subagents. This allows for making great use of model plans where the quota is the number of premium requests.

## How the agent should relate to the supported skills

The configuration imports the following skills, in prioritized order:
- wondelai/pragmatic-programmer
- oc-plugin-karpathy-guidelines
- obra/superpowers

Please report major disagreements between skills to the human partner (user)!

## On Test-driven development

Important: TDD tests are NOT unit tests! It is important that the tests are implemented at the level where they describe and provide specific behavior/functionality to the human partner.
Tests of particular software subcomponents should be prioritized only if they are generally useful or particularly important for the architecture.
If tests are implemented as unit tests at a too low level, then code refactor becomes more difficult and TDD breaks down (too much time refactoring tests vs coding new features).

Also, more than in obra/superpowers, the Pragmatic Programmer highlights the importance of tests as exploratory devices to pin down the interfaces, functionality, architecture and design of code before it is written, in discussions with the human partner. Interaction with the human partner around tests should be prioritized if new interfaces or architectures are considered, unless the human says otherwise.

## Subagent delegation (short)

- Policy (short): If a responsibility or skill in repo docs is assigned to a named subagent, the parent agent MUST spawn that subagent to perform the work. 
- Routing question: before spawning, the Maestro MAY ask exactly one routing-only clarifying question (hard limit: 1 question, max 18 words) to choose the correct subagent or scope. This single question must not perform or begin the delegated work (no discovery beyond routing). After the Maestro spawns a subagent, that subagent follows its own interaction rules — e.g. an iterative, one‑question‑per‑message dialog — to refine scope and design.
- Handoff wording (required): when spawning a named subagent the Maestro SHOULD use exactly:

  "Switching you to the <subagent> subagent now — please interact directly with it; I will remain available for orchestration."
- Per-subagent override: a subagent file may define a more specific first-message/handoff wording; that override applies only to that subagent and must be explicit in the subagent file.


# Subagent interaction rules:

First message (recommended, can be overridden in this file for this subagent):

  "I’m the <subagent> subagent. I’ll work with you directly; I will ask one question at a time and return control to the Maestro when the scoped work is complete."

Interaction rules (minimal):
- Ask one clarifying question per message (repeat as needed — there is no single-question-per-session cap).
- Perform only responsibilities listed in the subagent file.
- When done, return control to the <parent agent> with the exact final handoff:

  "The <subagent> subagent has completed the scoped work. Returning control to the <parent agent>  for orchestration and next-step delegation."
