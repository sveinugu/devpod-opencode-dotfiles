/**
 * OpenAI-compatible fix plugin.
 *
 * Workaround for https://github.com/anomalyco/opencode/issues/25096
 *
 * The bundled @ai-sdk/openai-compatible provider hardcodes max_tokens in
 * chat-completions requests. OpenAI's reasoning-model family (GPT-5.x, o1,
 * o3, o4) rejects that parameter and requires max_completion_tokens instead.
 * Those same models also reject reasoningSummary.
 *
 * This plugin intercepts chat.params and patches the options for affected
 * models: removes max_tokens, copies maxOutputTokens into
 * max_completion_tokens, and drops reasoningSummary.
 */

/**
 * Model-name patterns that indicate a reasoning model requiring
 * max_completion_tokens instead of max_tokens.
 *
 * We match the full modelID (which may include provider prefix) plus the
 * short name portion after the last slash, to handle both
 * "gpt-uio-yellow/gpt-5.1" and bare "gpt-5.1" forms.
 */
const REASONING_MODEL_PREFIXES = [
  "gpt-5",
  "o1",
  "o3",
  "o4",
];

function isReasoningModel(modelID: string): boolean {
  // Strip provider prefix (e.g. "gpt-uio-yellow/gpt-5.1" → "gpt-5.1")
  const short = modelID.includes("/") ? modelID.slice(modelID.lastIndexOf("/") + 1) : modelID
  return REASONING_MODEL_PREFIXES.some((prefix) => short.startsWith(prefix))
}

export const OpenAICompatibleFix = async (input: {
  client: unknown
  project: unknown
  directory: string
  worktree: string
  experimental_workspace: unknown
  serverUrl: URL
  $: unknown
}) => {
  return {
    "chat.params": async (
      incoming: {
        sessionID: string
        agent: string
        model: { providerID: string; modelID: string }
        provider: unknown
        message: unknown
      },
      output: {
        temperature: number
        topP: number
        topK: number
        maxOutputTokens: number | undefined
        options: Record<string, unknown>
      },
    ) => {
      // Only patch for reasoning models (gpt-5*, o1*, o3*, o4*)
      if (!isReasoningModel(incoming.model.modelID)) return

      // Remove max_tokens (the openai-compatible adapter injects this
      // automatically; reasoning models reject it)
      delete output.options.max_tokens

      // Set max_completion_tokens from maxOutputTokens
      if (output.maxOutputTokens !== undefined) {
        output.options.max_completion_tokens = output.maxOutputTokens
      }

      // Remove reasoningSummary (some reasoning models via openai-compatible
      // proxy do not support this parameter)
      delete output.options.reasoningSummary
    },
  }
}

export default OpenAICompatibleFix
