# In-App Agent Tools for v0.7

**Status:** v0.7 design proposal  
**Baseline reviewed:** `v0.7` at `47b39099131b3e82e8923b9eb6e65e69db88341e` (2026-10-18)

## Goal

Make Stroom's existing application capabilities available to the assistant as a small, dependable set of first-party tools. The assistant should be able to work with user-provided images and audio, run saved task flows, keep a useful task list, and read or write documents in Stroom's own file space.

Reuse the services and data models that already implement these features. The tool layer should connect them to the existing chat tool-call pipeline; it should not duplicate their provider, persistence, or task execution logic.

## Current state

### MCP and chat tools

Stroom currently acts as an **MCP client**. `McpClient` discovers and calls tools on configured external servers; the chat adapter publishes those tools to the model when enabled. The implementation handles remote Streamable HTTP and legacy SSE, plus stdio on desktop platforms. See `lib/models/mcp.dart`, `lib/services/mcp_client.dart`, and `lib/services/chat_adapter_mcp.dart`.

Stroom does not currently host an MCP server. The in-app chat also has a separate local tool registry: `ChatService.registerTool` is used for built-in tools such as web search and `todowrite`, and for direct HTTP search tools. See `lib/services/chat_service_tools.dart` and `lib/services/chat_adapter_http_tools.dart`.

The existing `todowrite` tool is a useful starting point, but its list is held in a static in-memory collection, shared by the running app, and writes replace the whole list. It is not persisted per conversation. See `lib/services/todo_tool_service.dart`.

### Reusable application capabilities

- **OCR:** `OcrService` supports single-image and batch recognition using configured OCR models.
- **ASR:** `AsrService` transcribes configured audio inputs, including supported file uploads and URL-based requests.
- **TTS:** configured TTS providers synthesize audio; the existing TTS UI and storage flow save generated audio into Stroom's audio library.
- **Task flows:** saved flow definitions and execution records are persisted. Existing blocks include OCR, ASR, TTS, chat, and other media operations. The execution service already supports launch, status tracking, pause, resume, cancel, and retry.
- **In-app files:** the Files area has separate text, image, audio, and video records and folders. Text Storage supports `txt`, `md`, and `mmd`, and has existing create, import, preview, and export paths. File records are managed through manifests; native files and web IndexedDB have different storage implementations.

Relevant sources include `lib/services/ocr_service.dart`, `lib/services/asr_service.dart`, `lib/providers/tts_provider.dart`, `lib/task_flow/services/task_flow_execution_service.dart`, `lib/task_flow/models/block_type_definition.dart`, and `lib/utils/text_manifest.dart`.

## v0.7 design

### One local capability registry

Add a first-party tool registry with validated JSON Schema definitions and handlers that call existing Stroom services directly. Connect it to the current chat tool-call loop alongside the existing built-ins.

Do not route an in-app tool call out through Stroom's remote MCP client and back over a loopback server. That adds a transport hop without adding value, complicates mobile and web support, and can make local data handling less reliable. Keep the current MCP client for user-configured external servers.

The first-party tool definitions should use stable, namespaced names such as `stroom_ocr` and be easy to wrap in a true MCP server adapter later. That adapter is a separate capability: it would let *external MCP clients* call Stroom. It is not implied by making tools available to the assistant inside Stroom.

### Proposed first-party tools

| Group | Proposed tools | v0.7 behavior |
|---|---|---|
| Todo | Existing `todowrite`, revised | Keep the familiar tool concept, but make state conversation-scoped and persisted. Support read and validated item updates without allowing one conversation to overwrite another's list. Preserve existing status and priority fields. |
| OCR | `stroom_ocr` | Recognize one or more image attachments selected for the current conversation. Return extracted text; optionally save the result to Text Storage when requested. |
| ASR | `stroom_asr` | Transcribe audio attached to the current conversation or explicitly selected from Stroom's audio library. Reuse configured ASR model and supported upload settings. Return text and available timestamps. |
| TTS | `stroom_tts` | Synthesize user-requested text with an already configured TTS provider. Save output through the existing audio storage path and return an app file record ID and playback metadata, not raw audio bytes. |
| Task flows | `stroom_task_flow_list`, `stroom_task_flow_run`, `stroom_task_flow_status`, `stroom_task_flow_control` | List saved flows, run a selected flow with an explicit input, inspect execution progress, and pause, resume, or cancel an execution. Keep flow creation and editing in the existing builder UI for the first release. |
| Text Storage | `stroom_space_list`, `stroom_space_search`, `stroom_space_read`, `stroom_space_write` | List, search, read, and write user-visible text documents in Stroom Text Storage (`txt`, `md`, `mmd`) using manifest record IDs and app-relative folders. |

Tool names are proposals; final names should be checked against provider naming limits and external MCP name collisions before implementation.

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
- Add a per-conversation tool control surface for first-party tool groups, separate from the external MCP server groups.
- Treat reading as available within the selected Stroom area. Writing creates a new document by default; replacing an existing document requires an explicit user request and a matching file ID.
- Running a task flow can start background work and may create or modify files. The assistant should identify the selected flow and its input in the tool call; it must not silently create or edit flow definitions.
- Keep tool execution scoped to the conversation that invoked it. Tool results must not reveal another conversation's attachments or TODO state.

## Implementation order

1. Define the local tool registry, common result/error handling, namespacing, and per-conversation enablement. Keep existing external MCP behavior unchanged.
2. Upgrade `todowrite` to conversation-scoped persisted state and add the Text Storage tools through current manifest APIs.
3. Add OCR, ASR, and TTS handlers that delegate to their existing services and return Stroom file references where applicable.
4. Add saved task-flow list/run/status/control tools using the existing execution service and background task tracking.
5. Verify behavior on web, Android, iOS, Linux, Windows, and macOS. The web path must use manifests and IndexedDB; native paths must stay inside app-managed storage.

## v0.7 acceptance criteria

- The in-app assistant can discover and call enabled first-party tools without configuring an external MCP server.
- Existing external MCP servers and HTTP tools continue to work and name collisions are handled predictably.
- TODO state is persisted and isolated per conversation.
- OCR and ASR operate only on current-conversation attachments or explicitly selected Stroom files; TTS output appears in the existing audio library.
- Saved task flows can be run and their progress inspected or controlled without bypassing the existing scheduler and persistence.
- Text Storage tools can safely list, search, read, create, and explicitly replace supported text formats on all platforms.
- No tool can access arbitrary OS paths, provider secrets, or another conversation's private data.

## Deferred

- A standalone MCP server endpoint for other applications to connect to Stroom.
- Arbitrary device filesystem access, shell execution, hidden settings access, and tool-driven flow editing.
- Additional app capabilities (for example, image/video generation or browser control) until their user-facing scope and permission model are defined.

