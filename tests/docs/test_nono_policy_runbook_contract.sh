#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
policy="$repo_root/docs/superpowers/runbooks/nono-policy.md"
bare_hub="$repo_root/docs/superpowers/runbooks/devspace-bare-hub-usage.md"
lifecycle="$repo_root/docs/superpowers/runbooks/devspace-workspace-lifecycle.md"
fail=0

check_fixed() {
    local file="$1" pattern="$2" label="$3"
    if rg -qF -- "$pattern" "$file" 2>/dev/null; then
        printf '  PASS  %s\n' "$label"
    else
        printf '  FAIL  %s — missing in %s\n' "$label" "$file" >&2
        fail=1
    fi
}

echo "=== nono Policy Runbook Contract Test ==="

check_fixed "$policy" '# nono Policy' 'policy title'
check_fixed "$policy" 'This document is canonical policy summary; profile JSON + tests are enforcing artifacts.' 'policy canonical summary contract'
check_fixed "$policy" '## Quick orientation' 'policy quick orientation section'
check_fixed "$policy" '`nono` is a kernel-enforced sandbox for running commands with explicit filesystem, environment, and network permissions.' 'policy nono one-sentence intro'
check_fixed "$policy" 'This runbook explains the repo-supported secure `opencode` path for readers who need the practical policy before they dive into the spec, profile JSON, wrapper, or tests.' 'policy audience/problem statement'
check_fixed "$policy" '## Supported path at a glance' 'policy supported-path summary section'
check_fixed "$policy" '- `opencode` by name resolves to the repo wrapper, not directly to the raw binary.' 'policy supported-path wrapper bullet'
check_fixed "$policy" '- The wrapper reads only the provider secrets needed for the enabled routes through the constrained pre-sandbox helper.' 'policy supported-path helper bullet'
check_fixed "$policy" '- The wrapper drops from `vscode` to the non-sudo `agent` identity with `setpriv` before the sandboxed process starts.' 'policy supported-path setpriv bullet'
check_fixed "$policy" '- `nono` launches `/usr/local/bin/opencode-raw` with the reviewed generated profile and filtered runtime configuration.' 'policy supported-path nono bullet'
check_fixed "$policy" '## In scope vs. out of scope' 'policy scope-plain-language section'
check_fixed "$policy" '- In scope: the repo-supported secure path reached by invoking `opencode` from `PATH` after install.' 'policy in-scope bullet'
check_fixed "$policy" '- Out of scope: intentionally invoking `/usr/local/bin/opencode-raw` directly or using ad hoc user-defined providers outside this repo contract.' 'policy out-of-scope bullet'
check_fixed "$policy" '## Scope & authority' 'policy scope section'
check_fixed "$policy" 'Build-time sudoers toggle (workspace image only):' 'policy build-time sudoers toggle section'
check_fixed "$policy" '- `DOTFILES_ALLOW_VSCODE_NOPASSWD_ALL=0` (default) removes `/etc/sudoers.d/vscode` and keeps constrained sudoers rules only.' 'policy build-time toggle hardened default'
check_fixed "$policy" '- `DOTFILES_ALLOW_VSCODE_NOPASSWD_ALL=1` keeps broad `vscode` sudo for temporary local debugging.' 'policy build-time toggle debug override'
check_fixed "$policy" '- This toggle changes operator convenience only; the supported secure launch path and its constrained wrapper contracts remain the canonical production-like target.' 'policy build-time toggle scope clarification'
check_fixed "$policy" '## What nono does by default' 'policy upstream-defaults section'
check_fixed "$policy" 'The upstream engine default is not the same thing as the stock `default` profile or the stock `opencode` profile.' 'policy default-layer distinction'
check_fixed "$policy" '### Upstream engine defaults' 'policy upstream defaults subsection'
check_fixed "$policy" '### Stock profiles and groups' 'policy stock profiles subsection'
check_fixed "$policy" '### Repo-specific overrides' 'policy repo overrides subsection'
check_fixed "$policy" 'filesystem access is deny-by-default unless explicitly granted' 'policy upstream default filesystem behavior'
check_fixed "$policy" 'network access is allowed by default unless restricted' 'policy upstream default network behavior'
check_fixed "$policy" 'all environment variables are inherited by default unless filtered' 'policy upstream default environment behavior'
check_fixed "$policy" 'dangerous_commands' 'policy upstream default dangerous-command note'
check_fixed "$policy" '~/.ssh/' 'policy upstream default ssh deny example'
check_fixed "$policy" '~/.aws/' 'policy upstream default aws deny example'
check_fixed "$policy" '~/.gnupg/' 'policy upstream default gnupg deny example'
check_fixed "$policy" '~/.kube/' 'policy upstream default kube deny example'
check_fixed "$policy" '## Threat model / goals' 'policy threat-model section'
check_fixed "$policy" '- least privilege' 'policy least-privilege goal'
check_fixed "$policy" '- explicit credential routing' 'policy explicit-routing goal'
check_fixed "$policy" '- reproducible startup chain' 'policy reproducible-startup goal'
check_fixed "$policy" '## Filesystem policy' 'policy filesystem section'
check_fixed "$policy" '- no broad grants for `/home/agent` or `~/.local/share`' 'policy filesystem no-broad-grants rule'
check_fixed "$policy" '- explicit subdir grants only' 'policy filesystem explicit-subdir rule'
check_fixed "$policy" '- precreate runtime dirs via init container' 'policy filesystem init-container rule'
check_fixed "$policy" 'Plain-language summary: the sandbox gets the current worktree, a narrow set of OpenCode runtime directories under `/home/agent`, `/tmp`, and the single raw binary path — nothing broader.' 'policy filesystem plain-language summary'
check_fixed "$policy" 'Default path-variable values in this launch chain are:' 'policy path variable intro'
check_fixed "$policy" '- `$HOME` = `/home/agent`' 'policy home default path'
check_fixed "$policy" '- `$WORKDIR` = `<current active worktree>`' 'policy workdir default path'
check_fixed "$policy" '- `$XDG_CACHE_HOME` = `/home/agent/.cache`' 'policy xdg cache default path'
check_fixed "$policy" '- `$XDG_CONFIG_HOME` = `/home/agent/.config`' 'policy xdg config default path'
check_fixed "$policy" '- `$XDG_DATA_HOME` = `/home/agent/.local/share`' 'policy xdg data default path'
check_fixed "$policy" '- `$XDG_STATE_HOME` for the `nono` process = `/home/agent/.local/state/nono`' 'policy nono xdg state default path'
check_fixed "$policy" '- `$XDG_STATE_HOME` for the wrapped `opencode` child = `/home/agent/.local/state/opencode`' 'policy opencode xdg state default path'
check_fixed "$policy" 'Fixed-path grants for the sandboxed agent are exactly:' 'policy explicit fixed-path grant intro'
check_fixed "$policy" '- `/home/agent/.cache/opencode` (`$XDG_CACHE_HOME/opencode`) — read+write' 'policy xdg cache grant'
check_fixed "$policy" '- `/home/agent/.config/opencode` (`$XDG_CONFIG_HOME/opencode`) — read+write' 'policy xdg config grant'
check_fixed "$policy" '- `/home/agent/.local/share/opencode` (`$XDG_DATA_HOME/opencode`) — read+write' 'policy xdg data opencode grant'
check_fixed "$policy" '- `/home/agent/.local/share/opentui` (`$XDG_DATA_HOME/opentui`) — read+write' 'policy xdg data opentui grant'
check_fixed "$policy" '- `/home/agent/.local/state/opencode` (derived from `$HOME/.local/state/opencode` in the profile template) — read+write' 'policy xdg state grant'
check_fixed "$policy" '- `/home/agent/.opencode` (`$HOME/.opencode`) — read+write' 'policy home opencode grant'
check_fixed "$policy" '- `/home/agent/.gitconfig` (`$HOME/.gitconfig`) — read-only, so git `safe.directory` trust config is visible without granting write to home-level git config' 'policy home gitconfig read grant'
check_fixed "$policy" '- `/etc/gitconfig` — read-only, so system-level git `safe.directory` trust config remains readable to sandboxed git processes' 'policy system gitconfig read grant'
check_fixed "$policy" '- `/tmp` — read+write temporary workspace' 'policy tmp grant'
check_fixed "$policy" '- `/usr/local/bin/opencode-raw` (`allow_file`) — single-file read/execute target, not directory access' 'policy raw binary allow-file grant'
check_fixed "$policy" 'Worktree-dependent grants are:' 'policy worktree-dependent grant intro'
check_fixed "$policy" '- `<current active worktree>` (`$WORKDIR`) — read+write worktree access' 'policy workdir grant'
check_fixed "$policy" '- `<current active worktree>/.zprofile` (`$WORKDIR/.zprofile`) — read-only, with explicit bypass through the upstream shell-config deny group' 'policy zprofile grant'
check_fixed "$policy" '- `<current active worktree>/.zshrc` (`$WORKDIR/.zshrc`) — read-only, with explicit bypass through the upstream shell-config deny group' 'policy zshrc grant'
check_fixed "$policy" '- `<current active worktree>/../.bare` (`$WORKDIR/../.bare`) — read+write, for shared bare-repo operations when the active checkout is a default branch directory (for example `main`)' 'policy parent bare metadata grant'
check_fixed "$policy" '- `<current active worktree>/../../.bare` (`$WORKDIR/../../.bare`) — read+write, for shared bare-repo operations when the active checkout is a nested worktree directory (for example `work/<branch>`)' 'policy nested bare metadata grant'
check_fixed "$policy" 'The sandboxed agent is not granted broad access to `/home/agent`, `/home/agent/.local/share`, `/usr/local/bin`, or `/var/run/secrets/nono/providers`.' 'policy explicit non-grants'
check_fixed "$policy" '## Execution chain policy' 'policy execution-chain section'
check_fixed "$policy" '- wrapped launcher → constrained sudo → setpriv drop to `agent` → `nono` → raw `opencode`' 'policy execution chain overview'
check_fixed "$policy" '- raw binary path and ownership contract' 'policy raw binary contract overview'
check_fixed "$policy" '/usr/local/bin/opencode-raw' 'policy raw binary path'
check_fixed "$policy" '/usr/local/libexec/dotfiles-generate-nono-profile' 'policy generated profile writer path'
check_fixed "$policy" '## Credential policy' 'policy credential section'
check_fixed "$policy" '- provider-secret source, env mapping, generated runtime profile filtering' 'policy credential overview'
check_fixed "$policy" '/var/run/secrets/nono/providers' 'policy secret mount path'
check_fixed "$policy" 'OPENAI_API_KEY' 'policy env mapping example'
check_fixed "$policy" 'Allowed inherited environment variables in this profile are exactly:' 'policy env allow intro'
check_fixed "$policy" '`PATH`, `HOME`, `TERM`, `LANG`, `LC_ALL`, `USER`, `SHELL`, `PWD`' 'policy env allow base vars'
check_fixed "$policy" '`XDG_*`, `HUB_*`, `OPENCODE_*`' 'policy env allow prefix vars'
check_fixed "$policy" 'This profile explicitly strips `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `GPT_UIO_YELLOW_API_KEY`, and `GPT_UIO_RED_API_KEY` from inherited sandbox environment state.' 'policy env deny list'
check_fixed "$policy" 'Real provider secrets are loaded before sandbox entry by the constrained helper and are then consumed by the wrapped launch path, rather than being inherited from the caller shell.' 'policy env helper explanation'
check_fixed "$policy" 'The important handoff detail is that these secrets are not ordinary interactive-shell environment variables.' 'policy secret handoff intro'
check_fixed "$policy" 'They are read from `/var/run/secrets/nono/providers` during the constrained pre-sandbox helper step, preserved only across the one documented `sudo` handoff, and then consumed by the wrapped launch path for proxy setup and launch.' 'policy secret handoff explicit sentence'
check_fixed "$policy" 'The sudoers contract keeps only the launch-step provider variables needed for that handoff; it is not a general-purpose shell inheritance path.' 'policy sudoers handoff clarification'
check_fixed "$policy" '/usr/bin/env HOME=* XDG_CONFIG_HOME=* XDG_CACHE_HOME=* XDG_DATA_HOME=* XDG_STATE_HOME=* OPENCODE_CONFIG_CONTENT=* /usr/local/bin/opencode-raw *' 'policy sudoers runtime env contract anchor'
check_fixed "$policy" 'Credential routes configured in this profile are exactly `openai`, `anthropic`, `github-copilot`, `gpt-uio-yellow`, and `gpt-uio-red`.' 'policy credential route list'
check_fixed "$policy" '## Change policy' 'policy change section'
check_fixed "$policy" '- how to add a new writable path/provider safely' 'policy change writable-path rule'
check_fixed "$policy" '- required tests to update' 'policy change tests rule'
check_fixed "$policy" '## Verification checklist' 'policy verification section'
check_fixed "$policy" 'command -v opencode' 'policy verification command-v check'
check_fixed "$policy" 'type -a opencode' 'policy verification type-a check'
check_fixed "$policy" 'bash tests/devspace/test_nono_profile_layout.sh' 'policy verification profile-layout test'
check_fixed "$policy" 'bash tests/devspace/test_opencode_secure_wrapper_contract.sh' 'policy verification wrapper-contract test'
check_fixed "$policy" 'bash tests/devspace/test_nono_identity_integration_contract.sh' 'policy verification identity-contract test'
check_fixed "$policy" '.config/nono/profiles/devspace-opencode-secure.jsonc' 'policy profile artifact link'
check_fixed "$policy" 'docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md' 'policy spec artifact link'
check_fixed "$policy" 'https://nono.sh/docs/introduction' 'policy upstream intro link'
check_fixed "$policy" 'https://nono.sh/docs/cli/internals/overview' 'policy upstream architecture link'
check_fixed "$policy" 'https://nono.sh/docs/cli/features/profiles-groups' 'policy upstream profiles link'
check_fixed "$policy" 'https://nono.sh/docs/cli/features/environment' 'policy upstream environment link'
check_fixed "$policy" 'https://nono.sh/docs/cli/features/networking' 'policy upstream networking link'
check_fixed "$policy" 'https://nono.sh/docs/cli/features/credential-injection' 'policy upstream credential-injection link'

python3 - "$policy" <<'PY' || fail=1
import sys

text = open(sys.argv[1], 'r', encoding='utf-8').read()

def assert_in_order(items, label):
    pos = -1
    for item in items:
        new_pos = text.find(item)
        if new_pos == -1:
            raise SystemExit(f"missing:{label}:{item}")
        if new_pos < pos:
            raise SystemExit(f"order:{label}:{item}")
        pos = new_pos

assert_in_order([
    '- `$HOME` = `/home/agent`',
    '- `$WORKDIR` = `<current active worktree>`',
    '- `$XDG_CACHE_HOME` = `/home/agent/.cache`',
    '- `$XDG_CONFIG_HOME` = `/home/agent/.config`',
    '- `$XDG_DATA_HOME` = `/home/agent/.local/share`',
    '- `$XDG_STATE_HOME` for the `nono` process = `/home/agent/.local/state/nono`',
    '- `$XDG_STATE_HOME` for the wrapped `opencode` child = `/home/agent/.local/state/opencode`',
], 'path-variable-values')

assert_in_order([
    '- `/home/agent/.cache/opencode` (`$XDG_CACHE_HOME/opencode`) — read+write',
    '- `/home/agent/.config/opencode` (`$XDG_CONFIG_HOME/opencode`) — read+write',
    '- `/home/agent/.local/share/opencode` (`$XDG_DATA_HOME/opencode`) — read+write',
    '- `/home/agent/.local/share/opentui` (`$XDG_DATA_HOME/opentui`) — read+write',
    '- `/home/agent/.local/state/opencode` (derived from `$HOME/.local/state/opencode` in the profile template) — read+write',
    '- `/home/agent/.opencode` (`$HOME/.opencode`) — read+write',
    '- `/home/agent/.gitconfig` (`$HOME/.gitconfig`) — read-only, so git `safe.directory` trust config is visible without granting write to home-level git config',
    '- `/etc/gitconfig` — read-only, so system-level git `safe.directory` trust config remains readable to sandboxed git processes',
    '- `/tmp` — read+write temporary workspace',
    '- `/usr/local/bin/opencode-raw` (`allow_file`) — single-file read/execute target, not directory access',
], 'fixed-path-grants')

assert_in_order([
    '- `<current active worktree>` (`$WORKDIR`) — read+write worktree access',
    '- `<current active worktree>/.zprofile` (`$WORKDIR/.zprofile`) — read-only, with explicit bypass through the upstream shell-config deny group',
    '- `<current active worktree>/.zshrc` (`$WORKDIR/.zshrc`) — read-only, with explicit bypass through the upstream shell-config deny group',
    '- `<current active worktree>/../.bare` (`$WORKDIR/../.bare`) — read+write, for shared bare-repo operations when the active checkout is a default branch directory (for example `main`)',
    '- `<current active worktree>/../../.bare` (`$WORKDIR/../../.bare`) — read+write, for shared bare-repo operations when the active checkout is a nested worktree directory (for example `work/<branch>`)',
], 'worktree-grants')
PY

check_fixed "$bare_hub" '[nono Policy](nono-policy.md)' 'bare-hub cross-link to nono policy'
check_fixed "$lifecycle" '[nono Policy](nono-policy.md)' 'lifecycle cross-link to nono policy'
check_fixed "$bare_hub" '/home/agent/.config/opencode' 'bare-hub notes agent opencode config symlink'
check_fixed "$bare_hub" 'OPENCODE_CONFIG_CONTENT' 'bare-hub notes runtime config-content override'
check_fixed "$bare_hub" 'DOTFILES_ALLOW_VSCODE_NOPASSWD_ALL=1 devspace build' 'bare-hub notes debug sudo override build command'
check_fixed "$lifecycle" 'DOTFILES_ALLOW_VSCODE_NOPASSWD_ALL=1 devspace build' 'lifecycle notes debug sudo override build command'

if [ "$fail" -eq 0 ]; then
    printf 'PASS test_nono_policy_runbook_contract\n'
else
    printf 'FAIL test_nono_policy_runbook_contract\n' >&2
    exit 1
fi
