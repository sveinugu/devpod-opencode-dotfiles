#!/usr/bin/env bash

# Refresh direnv-managed variables for each non-interactive bash invocation.
# This keeps HUB_*/DYN_*/TMP* aligned with the current working directory.
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv export bash 2>/dev/null || true)"
fi
