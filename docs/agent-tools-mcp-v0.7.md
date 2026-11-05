# In-App Agent Tools for v0.7

**Status:** v0.7 implementation record; delivery status is tracked per PR
**Baseline reviewed:** `v0.7` at `6f8834c50c6d51b1a89dc44093b408756465faea` (2026-11-05)

## Goal

Make Stroom's existing application capabilities available to the assistant as a small, dependable set of first-party tools. The assistant should be able to work with user-provided images and audio, run saved task flows, keep a useful task list, and read or write documents in Stroom's own file space.

Reuse the services and data models that already implement these features. The tool layer should connect them to the existing chat tool-call pipeline; it should not duplicate their provider, persistence, or task execution logic.

## Current state

### MCP and chat tools

Stroom currently acts as an **MCP client**. `McpClient` discovers and calls tools on configured external servers; the chat adapter publishes those tools to the model when enabled. The implementation handles remote Streamable HTTP and legacy SSE, plus stdio on desktop platforms. See `lib/models/mcp.dart`, `lib/services/mcp_client.dart`, and `lib/services/chat_adapter_mcp.dart`.

Stroom does not currently host an MCP server. The in-app chat also has a separate local tool registry: `ChatService.registerTool` is used for built-in tools such as web search and first-party tools, and for direct HTTP search tools. See `lib/services/chat_service_tools.dart` and `lib/services/chat_adapter_http_tools.dart`.

### Delivery status

- PR #1436 is merged to `v0.7` as `1ab1fc82a992b2ab79d15641dbe9f71dfb6fb65a`. It adds persisted, conversation-scoped `todowrite`; `stroom_media_list`, `stroom_ocr`, and `stroom_asr`; `stroom_tts`; and `stroom_taskflow_list`, `stroom_taskflow_run`, `stroom_taskflow_status`, and `stroom_taskflow_control`.
- Text Storage tools (`stroom_space_list`, `stroom_space_search`, `stroom_space_read`, and `stroom_space_write`) were merged in PR #1395 as `6f8834c50c6d51b1a89dc44093b408756465faea`. CI run [42086514364](https://github.com/JohnXu22786/Stroom/actions/runs/42086514364) passed all checks, including the six platform message-view smoke tests and Text Storage service tests.
- Stroom remains an MCP client for configured external servers. These in-app tools do not add a local MCP server endpoint or promise arbitrary npm package compatibility.

### Reusable application capabilities

- **OCR:** `OcrService` supports single-image and batch recognition using configured OCR models.
- **ASR:** `AsrService` transcribes configured audio inputs, including supported file uploads and URL-based requests.
- **TTS:** configured TTS providers synthesize audio; the existing TTS UI and storage flow save generated audio into Stroom's audio library.
- **Task flows:** saved flow definitions and execution records are persisted. Existing blocks include OCR, ASR, TTS, chat, and other media operations. The execution service already supports launch, status tracking, pause, resume, cancel, and retry.
- **In-app files:** the Files area has separate text, image, audio, and video records and folders. Text Storage supports `txt`, `md`, and `mmd`, and has existing create, import, preview, and export paths. File records are managed through manifests; native files and web IndexedDB have different storage implementations.

Relevant sources include `lib/services/ocr_service.dart`, `lib/services/asr_service.dart`, `lib/providers/tts_provider.dart`, `lib/task_flow/services/task_flow_execution_service.dart`, `lib/task_flow/models/block_type_definition.dart`, and `lib/utils/text_manifest.dart`.

## v0.7 implementation plan

### Local capability registry

First-party tools use validated JSON Schema definitions and handlers that call existing Stroom services directly through the current chat tool-call loop alongside other built-ins.

Do not route an in-app tool call out through Stroom's remote MCP client and back over a loopback server. That adds a transport hop without adding value, complicates mobile and web support, and can make local data handling less reliable. Keep the current MCP client for user-configured external servers.

The first-party tool definitions use stable names such as `stroom_ocr` and can be wrapped in a true MCP server adapter later. That adapter is a separate capability: it would let *external MCP clients* call Stroom. It is not implied by making tools available to the assistant inside Stroom.

### First-party tools

| Group | Tool names | Delivered behavior |
|---|---|---|
| Todo | `todowrite` | Read or replace a persisted list scoped to the current conversation. |
| Media and recognition | `stroom_media_list`, `stroom_ocr`, `stroom_asr` | List bounded image/audio metadata from Stroom's library and recognize an image or transcribe audio from a current-conversation attachment or an explicitly selected library record. |
| Speech | `stroom_tts` | Synthesize text with a configured TTS provider and save the result through the existing audio library. |
| Task flows | `stroom_taskflow_list`, `stroom_taskflow_run`, `stroom_taskflow_status`, `stroom_taskflow_control` | List saved flows, run supported text or attachment inputs, inspect execution status, and pause, resume, or cancel execution. Keep flow creation and editing in the existing builder UI. |
| Text Storage | `stroom_space_list`, `stroom_space_search`, `stroom_space_read`, `stroom_space_write` | List, search, read, create, and explicitly replace user-visible `txt`, `md`, and `mmd` documents using Stroom manifest IDs and app-relative folders. The first-party tool set does not include deletion. |

### Tool inputs and results

- Use opaque app record IDs or current-conversation attachment references. Do not ask the model to supply a host filesystem path.
- For model-backed operations, resolve a model from the user's configured Stroom providers. Tool arguments must not accept API keys, arbitrary endpoints, or unconfigured provider credentials.
- Keep large binary data in Stroom storage. Return concise text and structured metadata such as record ID, media type, filename, duration, and transcript or OCR text as appropriate.
- Validate inputs at the tool boundary and return a clear tool error for missing files, unsupported formats, unavailable providers, invalid flow IDs, and cancelled work.
- Propagate cancellation and progress for long-running OCR, ASR, TTS, and flow operations through the existing task/progress mechanisms where available.

## App-space boundary

For v0.7, “app space” means the user's visible Stroom Text Storage, not the device's entire filesystem. The tools should use `TextManifest` and the existing manifest/storage abstractions so the same behavior works across native platforms and web.

- Accept only normalized, app-relative folder paths; reject absolute paths, parent traversal, and paths outside the selected Stroom area.
- Require an explicit file ID when replacing an existing document, and detect if its content changed since it was read before saving. Do not expose file deletion in the first tool set.
- Keep user-selected conversation attachments distinct from persistent Text Storage. OCR/ASR should only read an attachment available to the current conversation or a file the user explicitly selected from Stroom's library.
- Do not expose provider settings, API credentials, conversation databases, browser cookies, raw manifests, or internal app configuration through workspace tools.

The existing web file store uses IndexedDB and does not provide a general raw-file listing API. Listing and search must therefore be based on Stroom's manifest records, not by scanning storage keys.

## Availability and permissions

- Expose only tools whose required provider or capability is configured and enabled.
- Per-conversation controls enable first-party tool groups separately from external MCP server groups.
- Treat reading as available within the selected Stroom area. Writing creates a new document by default; replacing an existing document requires an explicit user request and a matching file ID.
- Running a task flow can start background work and may create or modify files. The assistant should identify the selected flow and its input in the tool call; it must not silently create or edit flow definitions.
- Keep tool execution scoped to the conversation that invoked it. Tool results must not reveal another conversation's attachments or TODO state.

## Implementation order

1. Keep the existing local tool registry and external MCP routing intact; share the current validation, result handling, and per-conversation settings with first-party tools.
2. Persist TODO state per conversation and add OCR, ASR, TTS, media-list, and task-flow tools through the existing services (merged in PR #1436).
3. Complete Text Storage tools through the current manifest APIs (merged in PR #1395).
4. Verify the tools on Web, Android, iOS, Linux, Windows, and macOS. The Web path uses manifests and IndexedDB; native paths stay inside app-managed storage.

## v0.7 acceptance criteria

- The in-app assistant can discover and call enabled first-party tools without configuring an external MCP server.
- Existing external MCP servers and HTTP tools continue to work and name collisions are handled predictably.
- TODO state is persisted and isolated per conversation (merged in PR #1436).
- OCR and ASR operate only on current-conversation attachments or explicitly selected Stroom files; TTS output appears in the existing audio library (merged in PR #1436).
- Saved task flows can be run and their progress inspected or controlled without bypassing the existing scheduler and persistence (merged in PR #1436).
- Text Storage tools can safely list, search, read, create, and explicitly replace supported text formats on all platforms (merged in PR #1395).
- No tool can access arbitrary OS paths, provider secrets, or another conversation's private data.

## Deferred

- A standalone MCP server endpoint for other applications to connect to Stroom.
- Arbitrary device filesystem access, shell execution, hidden settings access, and tool-driven flow editing.
- Additional app capabilities (for example, image/video generation or browser control) until their user-facing scope and permission model are defined.
- Running arbitrary user-installed npm MCP packages on mobile is a separate runtime feasibility effort; this first-party tool plan does not claim that capability.

