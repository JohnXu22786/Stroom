// Model IDs from CLIProxyAPI’s pinned registry; Gemini CLI is intentionally
// omitted because the snapshot has no corresponding authenticator/executor.
// Refresh this catalog only when the selected upstream reference revision changes.

/// Offline fallback IDs from the pinned Cline provider catalog. These IDs do
/// not imply that the connected account has plan access to every model.
const kPinnedClineModels = <String>[
  'z-ai/glm-5.2',
  'x-ai/grok-4.5',
  'openai/gpt-5.6-sol',
  'moonshotai/kimi-k3',
  'anthropic/claude-opus-4.8',
  'cline-free/deepseek-v4.1-flash',
  'cline-free/mimo-v2.6-flash',
  'cline-free/muse-spark-1.3-contributor',
  'stealth/space-bunny-alpha',
  'openrouter/free',
  'deepseek/deepseek-v4-flash',
  'tencent/hy3:free',
  'stepfun/step-3.7-flash',
  'poolside/laguna-m.1:free',
  'google/gemma-4-31b-it:free',
  'nvidia/nemotron-3-ultra-550b-a55b:free',
  'minimax/minimax-m3',
];

/// Offline fallback IDs from the pinned ClinePass `clinePass` catalog bucket.
const kPinnedClinePassModels = <String>[
  'cline-pass/glm-5.2',
  'cline-pass/minimax-m3',
  'cline-pass/deepseek-v4-pro',
  'cline-pass/deepseek-v4-flash',
  'cline-pass/kimi-k3',
  'cline-pass/kimi-k2.7-code',
  'cline-pass/mimo-v2.5-pro',
  'cline-pass/mimo-v2.5',
  'cline-pass/qwen3.8-max',
  'cline-pass/qwen3.7-max',
  'cline-pass/qwen3.7-plus',
];

const kPinnedCodexModels = <String>[
  'gpt-6-luna',
  'gpt-5.5',
  'gpt-5.6-terra',
  'gpt-5.6-luna',
  'codex-auto-review',
  'gpt-6-astra',
  'gpt-6-sol',
  'gpt-6.1-sol',
  'gpt-5.6-sol',
  'gpt-image-1.5',
  'gpt-image-2',
  'gpt-image-2.5-flare',
  'gpt-image-2.5-sunburst',
  'gpt-image-2.5',
];

const kPinnedClaudeModels = <String>[
  'claude-haiku-4-5-20251001',
  'claude-sonnet-4-5-20250929',
  'claude-sonnet-4-6',
  'claude-opus-4-6',
  'claude-opus-4-7',
  'claude-opus-4-8',
  'claude-opus-5',
  'claude-sonnet-5',
  'claude-fable-5',
  'claude-fable-5-1',
  'claude-opus-5-5',
  'claude-sonnet-5-5',
  'claude-opus-4-5-20251101',
  'claude-opus-4-1-20250805',
  'claude-opus-4-20250514',
  'claude-sonnet-4-20250514',
  'claude-3-7-sonnet-20250219',
  'claude-3-5-haiku-20241022',
];

const kPinnedAntigravityModels = <String>[
  'claude-opus-4-6-thinking',
  'claude-sonnet-4-6',
  'claude-opus-5-5-high',
  'claude-sonnet-5-5-high',
  'gemini-3.6-flash-high',
  'gemini-3.7-flash-high',
  'gemini-3.8-flash-high',
  'gemini-3-flash',
  'gemini-3.1-flash-image',
  'gemini-pro-agent',
  'gemini-3.1-pro-low',
  'gpt-oss-120b-medium',
  'gemini-3.1-flash-lite',
  'gemini-3.5-flash-lite',
];

const kPinnedKimiModels = <String>[
  'kimi-k2',
  'kimi-k2-thinking',
  'kimi-k2.5',
  'kimi-k2.6',
  'kimi-k2.7-code',
  'kimi-k2.7-code-highspeed',
  'kimi-k2.8',
  'kimi-k2.8-code',
  'kimi-k3',
  'kimi-k3-256k',
];

// CLIProxyAPI's Kimi executor normalizes coding-plan aliases to these IDs.
const kPinnedKimiCodeModels = <String>[
  'kimi-for-coding',
  'kimi-for-coding-highspeed',
];

// Conversational models exposed by the pinned Tencent CodeBuddy registries.
// WorkBuddy uses its authenticated `/v3/config` catalog instead.
const kPinnedCodeBuddyCnModels = <String>[
  'glm-5.2',
  'glm-5.1',
  'glm-5.0',
  'glm-5.0-turbo',
  'glm-5v-turbo',
  'minimax-m3',
  'minimax-m2.7',
  'kimi-k2.7',
  'kimi-k2.6',
  'kimi-k2.5',
  'hy3-preview',
  'hy3',
  'deepseek-v4-pro',
  'deepseek-v4-flash',
  'deepseek-v3-2-volc',
];

const kPinnedCodeBuddyIntlModels = <String>[
  'hy4-preview',
  'hy3',
  'gpt-6-astra',
  'gpt-6-luna',
  'gpt-6-sol',
  'gpt-5.6-sol',
  'gpt-5.6-terra',
  'gpt-5.6-luna',
  'gpt-5.5',
  'gpt-5.4',
  'gpt-5.3-codex',
  'gemini-3.5-flash',
  'glm-5v-turbo',
  'glm-5.3',
  'glm-5.3-flash',
  'glm-5.2',
  'glm-5.1',
  'minimax-m3',
  'kimi-k3',
  'kimi-k2.7',
  'kimi-k2.6',
  'deepseek-v4.1-flash',
];

// Conversational models published by the pinned Qoder provider registry.
// The Qoder PAT catalog is discovered through qodercli; this list is the
// source-declared fallback for account setup and DashScope-backed accounts.
const kPinnedQoderModels = <String>[
  'qwen3.8-max-preview',
  'qwen3.7-max',
  'qwen3.7-plus',
  'kimi-k3',
  'kimi-k2.7-code',
  'glm-5.2',
  'deepseek-v4-pro',
  'deepseek-v4-flash',
  'minimax-m3',
];

/// Models listed by the provider's pinned conversational catalog.
const kPinnedKiloCodeModels = <String>[
  'openrouter/free',
  'openai/gpt-5.6-sol',
  'openai/gpt-5.6-terra',
  'openai/gpt-5.6-luna',
  'anthropic/claude-opus-5',
  'anthropic/claude-sonnet-5',
  'anthropic/claude-haiku-4.5',
  'google/gemini-3.1-pro-preview',
  'google/gemini-3.7-flash',
  'google/gemini-3.5-flash-lite',
  'qwen/qwen3.8-max',
  'qwen/qwen3.7-plus',
  'deepseek/deepseek-v4-pro-0813',
  'deepseek/deepseek-v4-flash-0731',
  'moonshotai/kimi-k3',
];

/// Exact source-declared model IDs safe for Kilo's anonymous fallback.
const kKiloCodeAnonymousFreeModelIds = <String>{'openrouter/free'};

const kPinnedXaiModels = <String>[
  'grok-4.7',
  'grok-4.7-build-fast',
  'grok-4.6',
  'grok-build-0.1',
  'grok-4.5',
  'grok-4.3',
  'grok-4.20-0309-reasoning',
  'grok-4.20-0309-non-reasoning',
  'grok-4.20-multi-agent-0309',
  'grok-3-mini',
  'grok-3-mini-fast',
  'grok-composer-2.5-fast',
];

// Grok Build exposes its own model endpoint. These are its pinned conversational
// models; active availability and plan entitlement come from /v1/models.
const kPinnedGrokBuildModels = <String>['grok-4.7', 'grok-4.6', 'grok-4.5'];

const kPinnedMetaModels = <String>[
  'muse-spark-1.3',
  'muse-spark-1.3-contributor',
  'muse-spark-1.2',
  'muse-spark-1.2-contributor',
  'muse-spark-1.1',
];

// Meta Muse subscription models are registered on their own OAuth account;
// they are not inherited from Meta's API-key connector.
const kPinnedMuseCodeModels = <String>[
  'muse-spark-1.3',
  'muse-spark-1.3-contributor',
  'muse-spark-1.2',
  'muse-spark-1.2-contributor',
  'muse-spark-1.1',
];

/// Offline fallback models declared by the Openference conversational catalog.
/// Live `/v1/models` discovery remains the source of account availability.
const kPinnedOpenferenceModels = <String>[
  'GLM-5.2',
  'Qwen3.8 27b',
  'Llama 3.2 3B',
];

const kPinnedGeminiModels = <String>[
  'gemini-2.5-pro',
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-3-pro-preview',
  'gemini-3.1-pro-preview',
  'gemini-3.1-flash-image-preview',
  'gemini-3-flash-preview',
  'gemini-3.1-flash-lite-preview',
  'gemini-3-pro-image-preview',
  'gemini-3.5-flash',
  'gemini-3.5-flash-lite',
  'gemini-3.6-flash',
  'gemini-3.7-flash',
  'gemini-3.8-flash',
];

const kPinnedAistudioModels = <String>[
  'gemini-2.5-pro',
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-3-pro-preview',
  'gemini-3.1-pro-preview',
  'gemini-3-flash-preview',
  'gemini-3.1-flash-lite-preview',
  'gemini-pro-latest',
  'gemini-flash-latest',
  'gemini-flash-lite-latest',
  'gemini-2.5-flash-image',
  'gemini-3.5-flash',
  'gemini-3.5-flash-lite',
  'gemini-3.6-flash',
  'gemini-3.7-flash',
  'gemini-3.8-flash',
];

const kPinnedVertexModels = <String>[
  'gemini-2.5-pro',
  'gemini-2.5-flash',
  'gemini-2.5-flash-image',
  'gemini-2.5-flash-lite',
  'gemini-3-pro',
  'gemini-3-flash',
  'gemini-3.1-pro',
  'gemini-3.1-pro-preview',
  'gemini-3.1-flash-image',
  'gemini-3.1-flash-lite',
  'gemini-3-pro-image',
  'imagen-3.0-generate-002',
  'imagen-3.0-fast-generate-001',
  'imagen-4.0-generate-001',
  'imagen-4.0-ultra-generate-001',
  'imagen-4.0-fast-generate-001',
  'gemini-3.5-flash',
  'gemini-3.5-flash-lite',
  'gemini-3.6-flash',
  'gemini-3.7-flash',
  'gemini-3.8-flash',
];

const kPinnedDevinModels = <String>[
  'devin/swe-2',
  'devin/claude-fable-5-1',
  'devin/gpt-6-astra',
  'devin/glm-5-2',
  'devin/glm-5-3',
  'devin/glm-5-3-flash',
  'devin/gpt-5-6-sol',
  'devin/gemini-3-8-flash',
  'devin/grok-4-6',
  'devin/deepseek-v4-flash',
  'devin/deepseek-v4-1-flash',
];

// Devin CLI does not expose a stable account model catalog through ACP; this
// account selects the CLI's configured default model without forwarding an
// arbitrary model name to the subprocess.
const kPinnedDevinCliModels = <String>['devin-cli-default'];
