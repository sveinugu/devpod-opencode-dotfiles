#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_secret_helper_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
helper="$repo_root/scripts/lib/nono-secret-env.sh"

[ -f "$helper" ] || fail "nono secret helper not found"
grep -F '/bin/cat' "$helper" >/dev/null || fail "helper must perform privileged reads via constrained sudo cat path"

tmp_root="$(mktemp -d "$repo_root/.tmp-nono-secret-helper-XXXXXX")"
trap 'sudo rm -rf "$tmp_root" >/dev/null 2>&1 || rm -rf "$tmp_root"' EXIT

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
HUB_NONO_SECRET_HELPER_SUDO='sudo -n' bash -c "source '$helper'; nono_secret_env_emit_exports '$secret_dir'" >"$out_exports" 2>&1 || fail "helper should emit exports when all secret files are present"

for expected in \
  'export OPENAI_API_KEY=' \
  'export ANTHROPIC_API_KEY=' \
  'export GITHUB_TOKEN=' \
  'export GPT_UIO_YELLOW_API_KEY=' \
  'export GPT_UIO_RED_API_KEY='; do
  grep -F "$expected" "$out_exports" >/dev/null || fail "helper missing expected export line: $expected"
done

if bash -c "source '$helper'; nono_secret_env_emit_exports '$secret_dir'" >"$tmp_root/no-sudo.err" 2>&1; then
  fail "helper should fail when HUB_NONO_SECRET_HELPER_SUDO is not set"
fi

grep -F 'refused: HUB_NONO_SECRET_HELPER_SUDO must be set to constrained non-interactive sudo invocation' "$tmp_root/no-sudo.err" >/dev/null || fail "helper should require explicit HUB_NONO_SECRET_HELPER_SUDO"

if HUB_NONO_SECRET_HELPER_SUDO='sudo -n -u root' bash -c "source '$helper'; nono_secret_env_emit_exports '$secret_dir'" >"$tmp_root/wrong-sudo.err" 2>&1; then
  fail "helper should fail when HUB_NONO_SECRET_HELPER_SUDO is not exactly sudo -n"
fi

grep -F 'refused: HUB_NONO_SECRET_HELPER_SUDO must equal "sudo -n"' "$tmp_root/wrong-sudo.err" >/dev/null || fail "helper should reject broadened sudo invocation"

out_with_sudo="$tmp_root/exports-with-sudo.out"
HUB_NONO_SECRET_HELPER_SUDO='sudo -n' bash -c "source '$helper'; nono_secret_env_emit_exports '$secret_dir'" >"$out_with_sudo" 2>&1 || fail "helper should emit exports when HUB_NONO_SECRET_HELPER_SUDO is set"

for expected in \
  'export OPENAI_API_KEY=' \
  'export ANTHROPIC_API_KEY=' \
  'export GITHUB_TOKEN=' \
  'export GPT_UIO_YELLOW_API_KEY=' \
  'export GPT_UIO_RED_API_KEY='; do
  grep -F "$expected" "$out_with_sudo" >/dev/null || fail "helper missing expected export line with sudo helper contract: $expected"
done

real_root_secret_dir="$tmp_root/root-only-secrets"
mkdir -p "$real_root_secret_dir"

cat >"$real_root_secret_dir/openai_api_key" <<'EOF'
openai-root-only
EOF
cat >"$real_root_secret_dir/anthropic_api_key" <<'EOF'
anthropic-root-only
EOF
cat >"$real_root_secret_dir/github_token" <<'EOF'
github-root-only
EOF
cat >"$real_root_secret_dir/gpt_uio_yellow_api_key" <<'EOF'
yellow-root-only
EOF
cat >"$real_root_secret_dir/gpt_uio_red_api_key" <<'EOF'
red-root-only
EOF

sudo chown root:root "$real_root_secret_dir"/*
sudo chmod 0400 "$real_root_secret_dir"/*

if cat "$real_root_secret_dir/openai_api_key" >/dev/null 2>&1; then
  fail "test setup invalid: direct non-root read must fail on root-owned 0400 secret files"
fi

out_root_only="$tmp_root/exports-root-only.out"
HUB_NONO_SECRET_HELPER_SUDO='sudo -n' bash -c "source '$helper'; nono_secret_env_emit_exports '$real_root_secret_dir'" >"$out_root_only" 2>&1 || fail "helper must read root-owned 0400 files via constrained sudo path"

grep -F 'export OPENAI_API_KEY=openai-root-only' "$out_root_only" >/dev/null || fail "helper must export OPENAI_API_KEY from root-owned 0400 secret file"
grep -F 'export GITHUB_TOKEN=github-root-only' "$out_root_only" >/dev/null || fail "helper must export GITHUB_TOKEN from root-owned 0400 secret file"

rm -f "$secret_dir/gpt_uio_red_api_key"

if HUB_NONO_SECRET_HELPER_SUDO='sudo -n' bash -c "source '$helper'; nono_secret_env_emit_exports '$secret_dir'" >"$tmp_root/missing.err" 2>&1; then
  fail "helper should fail-closed when any required secret file is missing"
fi

grep -F 'refused: missing nono provider secret file:' "$tmp_root/missing.err" >/dev/null || fail "helper should report missing secret file"

printf 'PASS test_nono_secret_helper_contract\n'
