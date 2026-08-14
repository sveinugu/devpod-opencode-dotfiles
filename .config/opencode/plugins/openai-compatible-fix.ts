/**
 * OpenAI-compatible fix plugin.
 *
 * Workaround for https://github.com/anomalyco/opencode/issues/25096
 *
 * The bundled @ai-sdk/openai-compatible provider can send `max_tokens` to
 * reasoning models that require `max_completion_tokens` instead.
 *
 * This plugin intercepts chat.params and patches the outgoing options for
 * affected models: remove `max_tokens`, copy token limit into
 * `max_completion_tokens`, and drop `reasoningSummary`.
 */

const REASONING_MODEL_PREFIXES = ["gpt-5", "o1", "o3", "o4"]

function normalizeModelText(value) {
  if (typeof value !== "string") return []
  const full = value.trim().toLowerCase()
  if (!full) return []
  const short = full.includes("/") ? full.slice(full.lastIndexOf("/") + 1) : full
  return short === full ? [full] : [full, short]
}

function modelLooksLikeReasoningModel(modelName) {
  if (typeof modelName !== "string") return false
  return REASONING_MODEL_PREFIXES.some((prefix) => modelName.startsWith(prefix))
}

function extractModelCandidates(incoming) {
  const model = incoming?.model
  const candidates = []

  if (typeof model === "string") candidates.push(model)

  if (model && typeof model === "object") {
    candidates.push(model.modelID, model.modelId, model.id, model.name, model.model)
    if (typeof model.providerID === "string" && typeof model.modelID === "string") {
      candidates.push(`${model.providerID}/${model.modelID}`)
    }
  }

  candidates.push(incoming?.modelID, incoming?.modelId, incoming?.modelName, incoming?.name)

  return candidates
    .flatMap(normalizeModelText)
    .filter(Boolean)
}

function shouldPatchForIncomingModel(incoming) {
  return extractModelCandidates(incoming).some(modelLooksLikeReasoningModel)
}

export const OpenAICompatibleFix = async () => {
  return {
    "chat.params": async (incoming, output) => {
      if (!shouldPatchForIncomingModel(incoming)) return

      const options = (output && typeof output.options === "object" && output.options !== null)
        ? output.options
        : {}

      if (output) output.options = options

      const maxOutputTokens = output?.maxOutputTokens
      if (typeof maxOutputTokens === "number" && Number.isFinite(maxOutputTokens)) {
        options.max_completion_tokens = maxOutputTokens
      } else if (typeof options.max_tokens === "number" && Number.isFinite(options.max_tokens)) {
        options.max_completion_tokens = options.max_tokens
      }

      delete options.max_tokens
      delete options.reasoningSummary
    },
  }
}

export default OpenAICompatibleFix
