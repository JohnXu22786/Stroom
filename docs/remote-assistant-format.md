# Stroom remote assistant format

Stroom assistant files have one versioned schema with three encodings:

- `stroom-json-v1`: JSON object.
- `stroom-yaml-v1`: YAML object.
- `stroom-markdown-yaml-v1`: YAML front matter followed by the prompt body.

The field names and types are identical across encodings. Stroom does not map
aliases from other agent formats. Unknown core fields are rejected. Optional
namespaced extension data belongs under `extensions`; Stroom preserves it but
does not activate unsupported extensions.

## Assistant fields

Required: `schemaVersion` (currently `1`), `id`, `name`, `version`, and
`prompt`. Optional fields are `description`, `emoji`, `settings`,
`defaultModelName`, `defaultModelId`, `defaultProviderName`,
`defaultToolNames`, and `extensions`.

The `settings` keys match the assistant editor UI and persisted model:

| Key | Type / accepted value |
| --- | --- |
| `temperature` | Number from 0 to 2 |
| `enableTemperature` | Boolean |
| `topP` | Number from 0 to 1 |
| `enableTopP` | Boolean |
| `maxTokens` | Integer from 256 to 32768 |
| `enableMaxTokens` | Boolean |
| `maxToolCalls` | Positive integer; runtime uses values from 1 to 100, otherwise it falls back to the default of 20 |
| `enableMaxToolCalls` | Boolean; false disables the configured limit, with a hard safety limit of 1,000 rounds |
| `maxToolOutputChars` | Integer from 100 to 100000 characters |
| `enableMaxToolOutputChars` | Boolean |
| `streamOutput` | Boolean |
| `enableWebSearch` | Boolean |
| `frequencyPenalty` | Number from -2 to 2 |
| `enableFrequencyPenalty` | Boolean |
| `presencePenalty` | Number from -2 to 2 |
| `enablePresencePenalty` | Boolean |
| `seed` | Integer |
| `enableSeed` | Boolean |
| `customParameters` | List of `{ "name", "type", "value" }`; types are `string`, `number`, `boolean`, or `json` |

`defaultModelName`, `defaultModelId`, and `defaultProviderName` must resolve to
a model configured on the device to be applied. `defaultToolNames` must contain
tool names known to the current Stroom installation. An omitted list preserves
the existing default behavior; an empty list explicitly disables all tools.

## JSON example

```json
{
  "schemaVersion": 1,
  "id": "stroom.homework-tutor",
  "name": "作业辅导老师",
  "description": "引导学生理解题目并逐步解答",
  "emoji": "📚",
  "version": "1.2.0",
  "settings": {
    "temperature": 0.4,
    "enableTemperature": true,
    "maxTokens": 4096,
    "enableMaxTokens": true,
    "customParameters": []
  },
  "defaultToolNames": [],
  "extensions": {},
  "prompt": "你是一位耐心的作业辅导老师。先帮助学生理解题目，再循序渐进地引导解题。"
}
```

## YAML example

```yaml
schemaVersion: 1
id: stroom.homework-tutor
name: 作业辅导老师
description: 引导学生理解题目并逐步解答
emoji: 📚
version: 1.2.0
settings:
  temperature: 0.4
  enableTemperature: true
  maxTokens: 4096
  enableMaxTokens: true
  customParameters: []
defaultToolNames: []
extensions: {}
prompt: >-
  你是一位耐心的作业辅导老师。先帮助学生理解题目，再循序渐进地引导解题。
```

## Markdown example

```markdown
---
schemaVersion: 1
id: stroom.homework-tutor
name: 作业辅导老师
description: 引导学生理解题目并逐步解答
emoji: 📚
version: 1.2.0
settings:
  temperature: 0.4
  enableTemperature: true
  maxTokens: 4096
  enableMaxTokens: true
  customParameters: []
defaultToolNames: []
extensions: {}
---
你是一位耐心的作业辅导老师。先帮助学生理解题目，再循序渐进地引导解题。
```

For Markdown, the body after the closing `---` is the schema's `prompt` value.

## Catalog manifest

A catalog is a JSON or YAML object with `schemaVersion`, `catalogId`,
`updatedAt`, and `assistants`; catalog-level `extensions` may be included for
future Stroom use. Each assistant entry has `id`, `name`,
`description`, `emoji`, `version`, `file`, `format`, and `sha256`; it may also
include `requiresCapabilities` and `extensions`. Currently recognized required
capabilities are `stroom.assistant.v1`, `stroom.settings.v1`, and
`stroom.defaultTools.v1`; unknown required capabilities are rejected. Extension
data is preserved but is not executed. The listing metadata (`id`, `name`,
`description`, `emoji`, and `version`) must match the downloaded assistant
file. `file` is a relative path on the catalog's HTTPS origin. `sha256` is the
lowercase hexadecimal SHA-256 digest of the exact file bytes.

The app's catalog URL is supplied through the compile-time
`STROOM_ASSISTANT_CATALOG_URL` value; user-added catalog URLs are entered in the
assistant market. Update policy and safety-review preference are stored locally
and are not controlled by a remote assistant definition.
