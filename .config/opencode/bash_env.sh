#!/usr/bin/env bash

# Refresh direnv-managed variables for each non-interactive bash invocation.
# This keeps HUB_*/DYN_*/TMP* aligned with the current working directory.
if [ "${__DOTFILES_BASH_ENV_DIRENV_RUNNING:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

if command -v direnv >/dev/null 2>&1; then
  __DOTFILES_BASH_ENV_DIRENV_RUNNING=1
  export __DOTFILES_BASH_ENV_DIRENV_RUNNING

  __dotfiles_saved_bash_env="${BASH_ENV-}"
  unset BASH_ENV

  eval "$(direnv export bash 2>/dev/null || true)"

  if [ -n "$__dotfiles_saved_bash_env" ]; then
    export BASH_ENV="$__dotfiles_saved_bash_env"
  else
    unset BASH_ENV
  fi

  unset __dotfiles_saved_bash_env
  unset __DOTFILES_BASH_ENV_DIRENV_RUNNING
fi
