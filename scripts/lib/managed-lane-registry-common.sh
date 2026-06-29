#!/usr/bin/env bash

managed_lane_registry_require_non_empty() {
  local value="${1:-}"
  local field_name="${2:-value}"
  if [ -z "$value" ]; then
    printf 'refused: managed lane registry missing required %s\n' "$field_name" >&2
    return 1
  fi
}

managed_lane_registry_escape_tsv() {
  local value="${1-}"
  value="${value//\\/\\\\}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}
