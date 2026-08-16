#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  printf 'usage: run-with-sudo-nono.sh <run-as-user> <command> [args...]\n' >&2
  exit 2
fi

run_as_user="$1"
shift

if ! command -v sudo >/dev/null 2>&1; then
  printf 'refused: sudo is required for run-with-sudo-nono helper\n' >&2
  exit 1
fi

exec sudo -n -u "$run_as_user" "$@"
