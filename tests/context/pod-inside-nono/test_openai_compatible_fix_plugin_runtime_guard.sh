#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_openai_compatible_fix_plugin_runtime_guard: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/context/lib/context-guards.sh
source "$repo_root/tests/context/lib/context-guards.sh"
require_workspace_pod 'test_openai_compatible_fix_plugin_runtime_guard' 'bash tests/context/run.sh pod-inside-nono'
require_inside_nono_sandbox 'test_openai_compatible_fix_plugin_runtime_guard' 'bash tests/context/run.sh pod-inside-nono'

plugin_file="$repo_root/.config/opencode/plugins/openai-compatible-fix.ts"

[ -f "$plugin_file" ] || fail "plugin file not found at $plugin_file"

node - "$plugin_file" <<'NODE' || fail "runtime guard assertions failed"
const fs = require("node:fs")

const pluginFile = process.argv[2]
const source = fs.readFileSync(pluginFile, "utf8")

const transformed = source
  .replace(/export\s+const\s+OpenAICompatibleFix\s*=\s*/m, "const OpenAICompatibleFix = ")
  .replace(/\nexport\s+default\s+OpenAICompatibleFix\s*\n?/m, "\n")

const factory = new Function(`${transformed}\nreturn { OpenAICompatibleFix }`)
const { OpenAICompatibleFix } = factory()

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

async function captureDebugLogs(run) {
  const calls = []
  const previousDebug = console.debug
  console.debug = (...args) => {
    calls.push(args)
  }
  try {
    await run(calls)
    return calls
  } finally {
    console.debug = previousDebug
  }
}

async function withDebugEnv(value, run) {
  const previousValue = process.env.OPENCODE_PLUGIN_DEBUG
  if (value === undefined) {
    delete process.env.OPENCODE_PLUGIN_DEBUG
  } else {
    process.env.OPENCODE_PLUGIN_DEBUG = value
  }

  try {
    await run()
  } finally {
    if (previousValue === undefined) {
      delete process.env.OPENCODE_PLUGIN_DEBUG
    } else {
      process.env.OPENCODE_PLUGIN_DEBUG = previousValue
    }
  }
}

;(async () => {
  assert(typeof OpenAICompatibleFix === "function", "OpenAICompatibleFix export missing")

  const plugin = await OpenAICompatibleFix()
  const hook = plugin?.["chat.params"]
  assert(typeof hook === "function", "chat.params hook missing")

  // Regression guard: these used to throw when modelID was missing.
  const defensiveInputs = [
    {},
    { model: undefined },
    { model: null },
    { model: {} },
    { model: { name: "" } },
    { model: { modelID: undefined } },
    { model: { modelID: null } },
    { model: "" },
  ]

  for (const incoming of defensiveInputs) {
    const output = {
      maxOutputTokens: 64,
      options: { max_tokens: 64, reasoningSummary: true },
    }
    await hook(incoming, output)
  }

  // Reasoning model should be patched.
  {
    const output = {
      maxOutputTokens: 128,
      options: { max_tokens: 99, reasoningSummary: true },
    }
    await hook({ model: { modelID: "gpt-uio-yellow/gpt-5.1" } }, output)
    assert(!("max_tokens" in output.options), "max_tokens should be removed for reasoning model")
    assert(!("reasoningSummary" in output.options), "reasoningSummary should be removed for reasoning model")
    assert(output.options.max_completion_tokens === 128, "max_completion_tokens should be set from maxOutputTokens")
    assert(output.maxOutputTokens === undefined, "maxOutputTokens should be cleared to prevent provider remapping to max_tokens")
  }

  // Provider-delimited model identifiers should still be recognized.
  {
    const output = {
      maxOutputTokens: 64,
      options: { max_tokens: 10, reasoningSummary: true },
    }
    await hook({ model: { modelID: "gpt-uio-yellow:gpt-5.1" } }, output)
    assert(output.options.max_completion_tokens === 64, "provider-delimited model identifier should still patch")
    assert(!("max_tokens" in output.options), "provider-delimited model should remove max_tokens")
  }

  // Fallback should use options.max_tokens if maxOutputTokens is unavailable.
  {
    const output = {
      maxOutputTokens: undefined,
      options: { max_tokens: 42, reasoningSummary: true },
    }
    await hook({ model: { modelID: "o3-mini" } }, output)
    assert(output.options.max_completion_tokens === 42, "fallback should map options.max_tokens to max_completion_tokens")
    assert(!("max_tokens" in output.options), "max_tokens should be removed after fallback mapping")
  }

  // Non-reasoning model should not be patched.
  {
    const output = {
      maxOutputTokens: 256,
      options: { max_tokens: 11, reasoningSummary: true },
    }
    await hook({ model: { modelID: "moonshotai/Kimi-K2.6" } }, output)
    assert(output.options.max_tokens === 11, "non-reasoning model should keep max_tokens")
    assert(output.options.reasoningSummary === true, "non-reasoning model should keep reasoningSummary")
    assert(output.options.max_completion_tokens === undefined, "non-reasoning model should not get max_completion_tokens")
  }

  // Debug logging should be opt-in and emitted only when a patch is applied.
  await withDebugEnv(undefined, async () => {
    const logs = await captureDebugLogs(async () => {
      const output = {
        maxOutputTokens: 100,
        options: { max_tokens: 8, reasoningSummary: true },
      }
      await hook({ model: { modelID: "o1-mini" } }, output)
    })
    assert(logs.length === 0, "logging should be disabled by default")
  })

  await withDebugEnv("1", async () => {
    const logs = await captureDebugLogs(async () => {
      const output = {
        maxOutputTokens: 100,
        options: { max_tokens: 8, reasoningSummary: true },
      }
      await hook({ model: { modelID: "o1-mini" } }, output)
    })
    assert(logs.length === 1, "expected one debug log when patch is applied")

    const [label, payload] = logs[0]
    assert(label === "[openai-compatible-fix]", "debug log label mismatch")

    const data = JSON.parse(payload)
    assert(data.event === "openai-compatible-fix.patch", "debug log event mismatch")
    assert(data.model === "o1-mini", "debug log should include model identifier")
    assert(Array.isArray(data.changed), "debug log changed field must be an array")
    assert(data.changed.includes("max_completion_tokens"), "debug log should report max_completion_tokens change")
    assert(data.changed.includes("max_tokens"), "debug log should report max_tokens removal")
    assert(data.changed.includes("reasoningSummary"), "debug log should report reasoningSummary removal")
  })

  await withDebugEnv("1", async () => {
    const logs = await captureDebugLogs(async () => {
      const output = {
        maxOutputTokens: undefined,
        options: {},
      }
      await hook({ model: { modelID: "gpt-5.1" } }, output)
    })
    assert(logs.length === 0, "debug log should not emit for no-op reasoning-model pass")
  })

  await withDebugEnv("1", async () => {
    const logs = await captureDebugLogs(async () => {
      const output = {
        maxOutputTokens: 100,
        options: { max_tokens: 8, reasoningSummary: true },
      }
      await hook({ model: { modelID: "moonshotai/Kimi-K2.6" } }, output)
    })
    assert(logs.length === 0, "debug log should not emit for non-reasoning model")
  })
})().catch((error) => {
  console.error(error)
  process.exit(1)
})
NODE

printf 'PASS test_openai_compatible_fix_plugin_runtime_guard\n'
