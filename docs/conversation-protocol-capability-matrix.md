# Stroom conversation protocol capability matrix

This matrix describes the protocol adapters used by normal Stroom conversation
requests. Conversation history remains protocol-neutral in `ChatMessage`; each
request rebuilds the history for the selected endpoint. Provider and model
endpoint settings select the wire format independently of the configured URL,
which is sent unchanged.

| Capability | OpenAI Chat Completions (`openai`) | Anthropic Messages (`anthropic`) | OpenAI Responses (`responses`) |
| --- | --- | --- | --- |
| Endpoint selection and route | `openai` selects Chat Completions; legacy configs without a value stay on this route | `anthropic` selects Messages | `responses` selects Responses. Provider default and per-model override both support it; the configured URL is sent unchanged |
| Text history | `messages` with `system`, `user`, `assistant`, and `tool` roles | `system` at request top level; user/assistant messages | `instructions` plus `input` message items; system prompt and compacted summary become instructions |
| Images and files | Image data URLs; audio, video, document, and text attachment parts where the compatible endpoint supports them | Base64 image and PDF document blocks; unsupported audio/video and non-PDF binary files become explicit text placeholders | User images use `input_image`; `input_audio`, `input_file`, and extracted text are sent where supported; video and other unsupported inputs become explicit placeholders. Previously generated assistant images replay as filename placeholders because `input_image` is user-input content |
| Model parameters | `max_tokens`, `temperature`, tools, reasoning-compatible provider extensions, and configured extra parameters | `max_tokens` (required fallback), optional temperature, thinking parameters, tools, and configured extra parameters | `max_output_tokens`, optional temperature, tools, reasoning effort/summary, and configured extra parameters |
| Reasoning | Compatible provider extensions such as `reasoning_content` / `reasoning`; stream deltas are displayed and retained in tool history | Extended-thinking blocks and signatures; signature is carried into tool-chain history when supplied | Streamed reasoning text and completed-response summary text are displayed and retained in tool history. Local history remains the source of conversation state |
| Function tools | Wrapped `function` definitions; assistant `tool_calls` followed by one `tool` result per call | `name`/`input_schema`; assistant `tool_use` blocks followed by a user message containing matching `tool_result` blocks | `type:function` definitions; `function_call` and matching `function_call_output` input items. Parallel calls are grouped, and each round's outputs precede the next round |
| Streamed output | `choices[].delta` text/reasoning/tool-call fragments; optional usage chunks | Typed content-block, thinking, signature, tool, usage, and error events | Typed output-text, reasoning, function-argument, image-item, usage, and error events |
| Non-streamed output | Choice message text and usage; `chat` returns text | Content blocks and usage; `chat` returns text | `chat` returns output text; `chatWithEvents` additionally exposes reasoning, image, function-call, and usage events |
| Provider image output | No standard image output item in the Chat Completions function-call shape | No standard image output item in the Messages `tool_use` / `tool_result` shape | The Responses `image_generation_call.result` output item is separate from function calls. Its image event can accompany text and function calls, is saved through attachment storage, appears in the assistant bubble, and reloads as attachment metadata |
| Other output items | Text, reasoning, and function calls are consumed by the conversation flow | Text, thinking, and function calls are consumed by the conversation flow | Unknown output-item types, message content parts, and audio stream events produce visible unsupported-type placeholders; Stroom does not silently discard them |
| Usage and diagnostics | Prompt/completion or input/output token fields and provider cost are normalized; response body, headers, status, and URL are captured | Input/output/cache token fields and provider cost are normalized; response body, headers, status, and URL are captured | Input/output and cached/reasoning token fields, plus provider cost when present, are normalized; response body, headers, status, and URL are captured with image bytes redacted from persisted diagnostics |
| Authentication | Bearer token | `x-api-key` plus `anthropic-version` | Bearer token |

The wire formats intentionally do not share request-body or stream parsing code:
their message roles, attachment blocks, tool-result pairing, reasoning data,
usage fields, and error events differ. Unsupported input types are surfaced as
placeholders in the sent history instead of being silently omitted. Responses
function calls execute through the same Stroom tool loop as the other formats;
the Responses image-generation output item is parsed independently so a reply
can retain both image output and sibling function calls. Generated image bytes
are stored as attachment files and never embedded in conversation JSON.
