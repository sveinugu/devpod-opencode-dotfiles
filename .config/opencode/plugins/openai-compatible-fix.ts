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
const DEBUG_ENV_KEY = "OPENCODE_PLUGIN_DEBUG"
const DEBUG_LOG_LABEL = "[openai-compatible-fix]"

function normalizeModelText(value) {
  if (typeof value !== "string") return []
  const full = value.trim().toLowerCase()
  if (!full) return []
  const tailSlash = full.includes("/") ? full.slice(full.lastIndexOf("/") + 1) : full
  const tailColon = full.includes(":") ? full.slice(full.lastIndexOf(":") + 1) : full
  const variants = [full, tailSlash, tailColon]
  return [...new Set(variants)].filter(Boolean)
}

function modelLooksLikeReasoningModel(modelName) {
  if (typeof modelName !== "string") return false
  return REASONING_MODEL_PREFIXES.some((prefix) => modelName.startsWith(prefix))
}

function isDebugEnabled() {
  const env = typeof process === "object" && process && process.env
    ? process.env
    : undefined
  const raw = env?.[DEBUG_ENV_KEY]
  if (typeof raw !== "string") return false
  return ["1", "true", "yes", "on"].includes(raw.trim().toLowerCase())
}

function firstModelIdentifier(incoming) {
  const model = incoming?.model
  if (typeof model === "string" && model.trim()) return model.trim()

  if (model && typeof model === "object") {
    const direct = [model.modelID, model.modelId, model.id, model.name, model.model]
      .find((value) => typeof value === "string" && value.trim())
    if (typeof direct === "string") return direct.trim()

    if (typeof model.providerID === "string" && typeof model.modelID === "string") {
      const provider = model.providerID.trim()
      const modelID = model.modelID.trim()
      if (provider && modelID) return `${provider}/${modelID}`
    }
  }

  const fallback = [incoming?.modelID, incoming?.modelId, incoming?.modelName, incoming?.name]
    .find((value) => typeof value === "string" && value.trim())

  return typeof fallback === "string" ? fallback.trim() : "unknown"
}

function logPatch(model, changed) {
  if (!isDebugEnabled()) return
  if (!Array.isArray(changed) || changed.length === 0) return

  const payload = {
    event: "openai-compatible-fix.patch",
    model,
    changed,
  }

  console.debug(DEBUG_LOG_LABEL, JSON.stringify(payload))
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
      const changed = []

      if (output) output.options = options

      const maxOutputTokens = output?.maxOutputTokens
      if (typeof maxOutputTokens === "number" && Number.isFinite(maxOutputTokens)) {
        if (options.max_completion_tokens !== maxOutputTokens) changed.push("max_completion_tokens")
        options.max_completion_tokens = maxOutputTokens
        if (output && Object.hasOwn(output, "maxOutputTokens")) {
          output.maxOutputTokens = undefined
        }
      } else if (typeof options.max_tokens === "number" && Number.isFinite(options.max_tokens)) {
        if (options.max_completion_tokens !== options.max_tokens) changed.push("max_completion_tokens")
        options.max_completion_tokens = options.max_tokens
      }

      if (Object.hasOwn(options, "max_tokens")) changed.push("max_tokens")
      delete options.max_tokens

      if (Object.hasOwn(options, "reasoningSummary")) changed.push("reasoningSummary")
      delete options.reasoningSummary

      logPatch(firstModelIdentifier(incoming), [...new Set(changed)])
    },
  }
}

export default OpenAICompatibleFix
