# OpenCode local plugins

## `openai-compatible-fix.ts` debug logging

The `openai-compatible-fix` plugin supports lightweight, runtime debug logs in
its `chat.params` hook.

- Logging is **off by default**.
- Enable logging by setting `OPENCODE_PLUGIN_DEBUG` to one of:
  - `1`
  - `true`
  - `yes`
  - `on`

When enabled, the plugin logs only when it actually patches request options,
including model identifier and changed keys.
