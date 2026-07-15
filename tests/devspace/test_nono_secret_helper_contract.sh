#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_secret_helper_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
helper="$repo_root/scripts/lib/nono-secret-env.sh"

[ -f "$helper" ] || fail "nono secret helper not found"

tmp_root="$(mktemp -d "$repo_root/.tmp-nono-secret-helper-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

secret_dir="$tmp_root/secrets"
mkdir -p "$secret_dir"

cat >"$secret_dir/openai_api_key" <<'EOF'
openai-real
EOF
cat >"$secret_dir/anthropic_api_key" <<'EOF'
anthropic-real
EOF
cat >"$secret_dir/github_token" <<'EOF'
github-real
EOF
cat >"$secret_dir/gpt_uio_yellow_api_key" <<'EOF'
yellow-real
EOF
cat >"$secret_dir/gpt_uio_red_api_key" <<'EOF'
red-real
EOF

out_exports="$tmp_root/exports.out"
bash -c "source '$helper'; nono_secret_env_emit_exports '$secret_dir'" >"$out_exports" 2>&1 || fail "helper should emit exports when all secret files are present"

for expected in \
  'export OPENAI_API_KEY=' \
  'export ANTHROPIC_API_KEY=' \
  'export GITHUB_TOKEN=' \
  'export GPT_UIO_YELLOW_API_KEY=' \
  'export GPT_UIO_RED_API_KEY='; do
  grep -F "$expected" "$out_exports" >/dev/null || fail "helper missing expected export line: $expected"
done

rm -f "$secret_dir/gpt_uio_red_api_key"

if bash -c "source '$helper'; nono_secret_env_emit_exports '$secret_dir'" >"$tmp_root/missing.err" 2>&1; then
  fail "helper should fail-closed when any required secret file is missing"
fi

grep -F 'refused: missing nono provider secret file:' "$tmp_root/missing.err" >/dev/null || fail "helper should report missing secret file"

printf 'PASS test_nono_secret_helper_contract\n'
