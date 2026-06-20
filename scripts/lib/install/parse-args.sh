#!/usr/bin/env bash
set -euo pipefail

install_usage() {
  printf 'usage: install.sh [--dry-run] [-y|--yes]\n' >&2
  exit 1
}

install_parse_args() {
  dry_run=false
  assume_yes=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        dry_run=true
        ;;
      -y|--yes)
        assume_yes=true
        ;;
      *)
        install_usage
        ;;
    esac
    shift
  done
}
