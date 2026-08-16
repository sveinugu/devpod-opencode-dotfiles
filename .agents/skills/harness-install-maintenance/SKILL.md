---
name: harness-install-maintenance
description: Use when maintaining repo-root local skill installation and harness-installs manifest refresh behavior.
---

# Harness Install Maintenance

This repository's bootstrap contract keeps install authority split across:

- top-level `.agents/skills/` and top-level `skills-lock.json` for project-local skills,
- `.config/opencode/opencode.jsonc` for ordinary runtime plugin authority,
- top-level `harness-installs.jsonc` for installer-managed regeneration outputs.

When changing install/bootstrap behavior:

1. Keep `.config/opencode/AGENTS.md` as canonical policy authority.
2. Preserve `install.sh` branch-aware behavior and hub-root refusal.
3. Re-run contract tests under `tests/pod-outside-nono/` and `tests/host/` that cover this split.
4. Keep privileged (`sudo`) behavior out of ordinary local skill/plugin regeneration paths.
