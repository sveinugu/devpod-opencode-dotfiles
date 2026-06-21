did_you_mean() {
  local needle="$1"
  shift

  [ "$#" -gt 0 ] || return 0

  local suggestion
  suggestion="$(python3 - "$needle" "$@" <<'PY'
import difflib
import sys

needle = sys.argv[1]
candidates = sys.argv[2:]
matches = difflib.get_close_matches(needle, candidates, n=1, cutoff=0.5)
if matches:
    print(matches[0])
PY
)"

  if [ -n "$suggestion" ]; then
    printf 'did you mean: %s\n' "$suggestion" >&2
  fi
}
