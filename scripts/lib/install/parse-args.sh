#!/usr/bin/env bash
set -euo pipefail

install_usage() {
  printf 'usage: install.sh [--dry-run]\n' >&2
  exit 1
}

install_parse_args() {
  dry_run=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        dry_run=true
        ;;
      *)
        install_usage
        ;;
    esac
    shift
  done
}
