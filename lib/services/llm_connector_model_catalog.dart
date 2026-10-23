// Model IDs from CLIProxyAPI’s pinned registry; Gemini CLI is intentionally
// omitted because the snapshot has no corresponding authenticator/executor.
// Refresh this catalog only when the selected upstream reference revision changes.

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

const kPinnedMetaModels = <String>[
  'muse-spark-1.3',
  'muse-spark-1.3-contributor',
  'muse-spark-1.2',
  'muse-spark-1.2-contributor',
  'muse-spark-1.1',
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
  'imagen-4.0-generate-001',
  'imagen-4.0-ultra-generate-001',
  'imagen-3.0-generate-002',
  'imagen-3.0-fast-generate-001',
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
