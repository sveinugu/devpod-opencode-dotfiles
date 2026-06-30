#!/usr/bin/env bash

require_non_empty() {
  local function_name="$1"
  local arg_name="$2"
  local arg_value="$3"

  if [ -n "$arg_value" ]; then
    return 0
  fi

  printf 'refused: %s requires non-empty %s\n' "$function_name" "$arg_name" >&2
  exit 1
}
