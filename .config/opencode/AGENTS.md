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