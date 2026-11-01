# LLM accounts and model groups

Stroom keeps provider credentials, routing configuration, and conversation history in separate stores. Configure connectors under **Settings → LLM accounts and model groups**. A saved account or visible model name does not prove that the provider will authorize a request or that the selected model supports every capability.

## Add, reconnect, edit, and delete an account

1. Open **LLM accounts and model groups**, add an account, and choose the connector and an authentication method shown as available for it.
2. Enter a display name, credential or enterprise settings, and endpoint/project/region values requested by that connector. For API accounts, discover or enter the upstream model ID.
3. Add the account model to a model group. Confirm the model's declared capabilities (streaming, tools, image, audio, or other supported content) before using matching features.
4. Select the model group in Chat or in a Task Flow chat block.

For a supported OAuth account, use **Reconnect** in the account editor when authorization expires or the provider reports an authentication error. Gemini Developer API and AI Studio OAuth reconnect through the Google loopback flow using the configured OAuth Desktop client. Codex uses its supported Sign in with ChatGPT flow. OAuth authorization is unavailable in the Web app; use a supported native app, or choose API-key authentication on Web. OAuth support is limited to these connectors; a provider's CLI login is not automatically an app login.

When editing, leaving an existing secret field blank retains its current secure-storage value. Deleting an account removes its model-group membership and local account record. Where a connector has a supported revocation flow, Stroom attempts provider-side revocation; revocation failure does not undo local deletion, so revoke the grant in the provider's account settings if the app reports that step. Removing an account does not delete conversation history.

`Unknown` usage or quota means Stroom has no verified observation. It does not mean unlimited quota. `Paused` and `Needs attention` accounts are not selected. A discovered or manually entered model ID can still be unavailable to that particular account or project.

## Connector and authentication support

The table separates account/authentication support from availability in the current Chat and Task Flow model-group request path. Authentication methods are account credentials, not client credentials for an external Stroom server. Model access, quotas, and supported content still depend on the provider, account, project, endpoint, and model.

| Connector or service | Supported account authentication | Request path and practical limits |
| --- | --- | --- |
| OpenAI Codex / ChatGPT | Supported OAuth account flow; legacy/API-key records may be retained | Codex OAuth model groups use the OpenAI Responses protocol and the Codex upstream endpoint/account identity headers. OpenAI API-key accounts are separate and keep their Chat Completions default. |
| OpenAI API | API key | Chat/Task Flow defaults to OpenAI Chat Completions. The supplier protocol can select Responses, and a model can override its supplier protocol. This is API billing/authentication, separate from ChatGPT OAuth. |
| Anthropic API | API key | Anthropic Messages. Claude Code OAuth is shown as unsupported: Stroom does not import CLI login state or use CLI-only inference endpoints. |
| Google Gemini Developer API | API key or supported Google OAuth | Google Generative Language `generateContent` and streaming `streamGenerateContent`; OAuth uses a user-managed Cloud project. |
| Google AI Studio | API key or supported Google OAuth | The same public Google Generative Language HTTP API and Gemini `generateContent` bridge. It does not log into the AI Studio website or relay a WebView session. See [AI Studio setup](#google-ai-studio-and-gemini-oauth-setup). |
| Google Gemini Interactions | API key | Google Gemini Developer API `/v1beta/interactions` contract, with its own request, continuation, and stream mapping. This is a separate Google API adapter, not a general fifth wire protocol. The current account catalog does not offer OAuth for this connector. |
| OpenAI-compatible endpoint | API key or no authentication, if the endpoint allows it | Configurable Chat Completions endpoint. The Responses bridge also exists; select its protocol at the supplier level or override it for a model. This is a user-configured endpoint, not automatic support for every service. |
| Moonshot AI / Kimi API, GLM, DeepSeek, MiniMax, Qwen Cloud | API key | Routed through their configured OpenAI-compatible Chat Completions endpoints. Kimi Code CLI OAuth is not supported. |
| AWS Bedrock | AWS access key/secret credentials or the platform AWS credential chain | Stroom converts the chat request to Bedrock Converse. The selected AWS region, IAM policy, model ID, and account access must permit the request. |
| Ollama | No credential or API key | Ollama's service-specific `/api/chat` adapter; it is not a general OpenAI wire protocol. The configured Ollama host must be reachable from this device. The adapter accepts mapped local image data and tools but rejects unsupported content such as remote image URLs or image-detail hints. |
| Google Vertex AI | Service-account JSON or Vertex API key | Vertex Gemini models that support `generateContent` can be selected in Chat and Task Flow model groups. Service-account credentials use refreshed Google access tokens; API keys use Vertex key authentication. The project and location must match the model and credential. Vertex OAuth is not supported. |
| Legacy/first-party subscription labels (Claude Code, Antigravity, Grok Build, Kimi Code, Devin, Meta Muse) | No supported Chat/Task Flow OAuth account in this release | Legacy records may remain visible for migration or deletion, but Stroom does not reuse CLI/private session credentials. Use a provider's documented API key through a supported connector when available. This does not add account-specific protocol or quota support for those legacy labels. |

OpenAI Realtime and xAI Voice Realtime have separate API-key WebSocket adapters in the Gateway library. They are not model-group Chat/Task Flow connectors and do not create a Stroom external gateway or local listener.

### Google Vertex AI setup

1. In **LLM accounts and model groups**, add **Google Vertex AI** and choose **Service account** or **API key**.
2. For a service account, paste its JSON key. Stroom keeps it in secure storage and refreshes its access token when needed. The JSON `project_id` can supply the project automatically; otherwise enter the Google Cloud project ID. For an API key, enter the project ID explicitly.
3. Set the Vertex location (the default is `us-central1`), then discover or enter a conversational Gemini model available to that project and location.
4. Add the model to a group and select that group in Chat or a Task Flow chat block. Requests use Vertex's native Gemini `generateContent` protocol, with streaming when the selected model supports it.

The Google Gemini Interactions connector calls the Google Generative Language API. It is separate from Vertex AI and does not make Vertex Interactions requests. Vertex OAuth is not available through this account flow.

## Request formats and capability limits

Stroom stores a provider-neutral conversation and translates each request to the connector's upstream contract:

- **OpenAI Chat Completions** uses message arrays, tool calls, and Chat Completions streaming events. It is the default for OpenAI-compatible and several API-key account types.
- **OpenAI Responses** uses Responses input items, output items, tool results, and typed events. Its bridge is implemented separately from Chat Completions. Codex OAuth model groups select Responses by default. OpenAI API-key accounts keep the Chat Completions default; API protocol is configured independently from authentication.
- **Anthropic Messages** uses Anthropic content blocks, tool-use/result blocks, thinking data, and Anthropic stream events. It is used for Anthropic API-key accounts.
- **Gemini GenerateContent** uses Gemini `contents`/`parts`, `generateContent` or `streamGenerateContent`, function calls, and Gemini usage/safety fields.
- **Gemini Interactions** uses `/v1beta/interactions`, interaction steps/outputs, and `previous_interaction_id` continuation. It has its own mapper and limits; a Gemini GenerateContent account is not silently treated as an Interactions account.
- **Ollama Chat** is Ollama's own `/api/chat` service adapter. Its options and content mappings are specific to Ollama.

Text and tool calls are translated when the selected account/model declares the required capability. Image, audio, video, and file/document data are mapped only for content the selected bridge can represent. Gemini GenerateContent handles supported image/audio/video/file inputs and tool calls; its media references must be supported data or an allowed HTTPS/`gs://` source. Anthropic Messages maps supported image and PDF document blocks. Ollama accepts mapped image data but not arbitrary remote image URLs. Gemini Interactions currently rejects image input when no supported mapping exists. These statements describe the Stroom bridge, not the provider's full product capability.

Chat and Task Flow chat requests inspect required capabilities from the prompt, tools, and requested output. OCR routing requires the selected model to declare image support. A candidate account/model whose declared capabilities do not match is excluded. If a provider accepts the request but rejects a particular model, region, modality, or tool, Stroom surfaces the request error; correct the account/model capability or choose a compatible model. Do not infer entitlement from a model catalog entry.

## Google AI Studio and Gemini OAuth setup

AI Studio accounts now call Google's Generative Language HTTP API directly. Stroom does not use a WebView, website page session, browser cookies, or a copied AI Studio login. Legacy AI Studio relay records are disabled; edit one and create an API Key or OAuth account instead. Web can use API-key authentication, but the app cannot complete the OAuth loopback flow there.

### API key

1. Create a Google AI Studio/Gemini API key in a Google Cloud project where the Generative Language API is enabled and the project has the required quota/billing configuration.
2. Add a **Google Gemini API** or **Google AI Studio** account and select **API key**.
3. Enter the key and select/discover the requested model. Requests send the key using the API's key authentication.
4. Verify the account can use the selected model and that its project quota permits the request.

### OAuth

1. Use a Google Cloud project you administer. Enable the Generative Language API, configure its OAuth consent screen and permitted test users/production settings, and create an OAuth **Desktop application** client.
2. In a supported native Stroom app, select Google Gemini API or AI Studio and **OAuth**. Enter the Cloud project ID, OAuth Desktop client ID, and its matching client secret. Web does not support OAuth authorization.
3. Start authorization and finish Google's loopback consent flow in the browser. The account uses a bearer token and sends project attribution (`x-goog-user-project`); API usage and billing apply to that Cloud project.
4. If the OAuth client ID or matching secret changes, reconnect using that pair. If access is revoked or expires, reconnect the account.

This flow is the documented Gemini Developer API OAuth path. It is separate from Google Code Assist, Antigravity, and AI Studio website login. A key or OAuth account can still be rejected if the API is disabled, the project is not authorized, billing/quota is unavailable, or the requested model is not enabled for that account.

## Chat, Task Flow, and account routing

A model group maps a stable Stroom model ID to one or more upstream account/model IDs. Set member priority tiers and an account-selection strategy (least used, round robin, or comparable known-balance preference). Unknown quota stays unknown; balance-based ordering cannot assume that an unknown balance is available.

Chat uses the conversation's selected model group. Task Flow chat blocks use the model/assistant captured by that flow execution, so a later picker change does not silently rewrite an already running task's model selection. In Chat, **Use account for this turn** chooses one eligible account for the next model request. Choosing **Route by model group** returns to policy routing. A successful request updates the conversation's preferred account for later requests.

Manual OCR and Task Flow OCR send their image-capable model requests through the selected account/model group. The selected account's configured chat protocol determines the image request format; models without the declared image capability are not routed the OCR request. Task Flow captures its OCR group and model when the run starts, so changing the model selection does not redirect an active run.

Stroom keeps a soft affinity for the same conversation, model group, and local model for up to one hour after a successful request. It is a preference, not a lock: an unavailable, paused, ineligible, authentication-expired, or concurrency-limited account can be bypassed. An explicit account choice takes precedence for that request. When fallback is enabled, retries stay inside the configured model group; account-scope fallback can further restrict attempts to the same connector/provider. Stroom does not silently route outside the selected group.

Authentication, rate-limit, quota, connection, and server failures can cause a bounded retry/cooldown decision. Stroom stops automatic retry after output is visible, after a request may have been processed without a definitive rejection, or after a tool side effect, to avoid duplicating work. If all candidates fail, the request error appears in Chat/Task Flow; account diagnostics show the last or successful account and the routing reasons. Check that account's credentials, status, model access, group membership, region, and usage limits.

The conversation repository retains the full Stroom history independently of account IDs. Switching accounts does not delete or shorten the local history, attachments, tool results, or preserved protocol extensions. Provider-side prompt/KV cache is separate and may miss after switching accounts; Stroom cannot transfer that cache between upstream accounts.

## Conversation format, migration, and rollback

The legacy app `Conversation` and `ChatMessage` records use schema version **1**. The neutral `StroomConversation` record also currently uses schema version **1**; `StroomMessage` has no separate version field and is interpreted within its conversation schema. Missing version fields on the versioned records are read as the current schema. Unknown fields are retained on save where the model supports legacy-field preservation. Provider/account identifiers are not required conversation foreign keys.

Existing `conversations` preference data is migrated resumably into the conversation repository with stable record IDs. The migration verifies counts/order/integrity and keeps the original source JSON and attachment manifest as recovery copies while migration is in progress. An interrupted migration resumes from that source; a failed migration must be diagnosed from the app's error/log. Malformed legacy JSON is preserved under a timestamped corrupt-data preference key before the broken value is isolated. Do not manually delete migration or corrupt-data keys.

Before restoring a backup or doing manual data repair, export a fresh backup. Restore validates the archive and its file inventory before applying selected categories. A category with missing required files is skipped with a warning; unselected categories remain untouched. The repository does not provide a general user-facing “downgrade database” operation. If a newer app has written data, use the app version that created it or restore a compatible backup; do not assume installing an older build can safely read or rewrite newer data.

## Back up and restore data, including media

1. Open **Settings → Backup and Restore** and choose **Export backup**. Keep **Chat records and attachments** selected for message history and its attached files. Select Pictures, Audio, Videos, Texts, and Tasks when those files are part of the data you need.
2. The manual export includes file bytes for selected categories by default. Wait for export to finish and keep the ZIP in a separate location. The archive manifest records the included file inventory so restore can detect missing files.
3. To restore, first export the current device's data. Choose the ZIP, select only the categories you intend to restore, review the confirmation, and import. Most selected categories replace their matching data. Browser cookies are merged by domain, name, and path; cookies on this device that are absent from the archive remain. A missing/incomplete category is skipped and reported; unselected categories remain unchanged.
4. To verify an attachment backup, inspect the ZIP for its relevant `attachments/` or `task_flow_attachments/` entries (and the media category folders you selected), restore to a test device/profile, then open a message or task that references the file. Confirm it previews/opens. An attachment reference without the corresponding bytes is not a recoverable media file.

On Android, backup export uses the selected public location through the Storage Access Framework. iOS export writes to the app Documents backup location. Desktop manual export opens a native Save dialog initialized to Documents and writes to the location you choose; it does not force a Documents/Stroom folder. The configured backup root used by other backup operations defaults to a Documents/Stroom/AutoBackups folder on desktop where available. Web manual export uses a browser file picker and in-memory archive processing; it does not provide the native automatic backup location. Native archive IO streams large files; browser/device limits still apply. Move the exported ZIP itself when transferring platforms; platform keystore values and secure-storage keys are not exported.

## Credential storage and recovery

API keys, OAuth tokens, OAuth client secrets, and enterprise credentials are held through the platform secure-storage boundary. Ordinary account records contain account metadata and opaque credential references; exported settings/backups redact secret values and cannot transfer a device keystore. On Web, encrypted storage is origin-bound and requires a secure WebCrypto context; same-origin script compromise can still access app secrets. Linux requires a working Secret Service/libsecret session. Secure-storage availability depends on the device and its runtime configuration.

If a credential is missing after migration or restore, reopen the account, enter the API key or enterprise credential, or reconnect supported OAuth. A blank secret field while editing means “keep the saved value”; it is not a way to clear it. Delete the account if you need to remove its local credential and then re-add it with a new secret. If OAuth revocation fails, revoke the app grant from the provider's security/account page.

Common recovery steps:

- **401/403 or authentication required:** check that the account's credential type is supported for this connector, reconnect OAuth or replace the API key, and confirm the provider has not revoked access.
- **402/429, rate limit, or quota exhausted:** check the provider/project quota and reset time; wait for cooldown or choose another eligible account in the same model group.
- **Model unavailable or invalid request:** confirm the exact upstream model ID, account entitlement, region, tool settings, and declared media capability. A model can exist in the catalog but be denied for one account.
- **Unsupported media/protocol:** use a compatible connector/model or remove the unsupported content. The bridge reports unsupported mappings rather than promising that every model accepts every modality.
- **Connection or secure-storage unavailable:** verify endpoint/network access; on Linux verify Secret Service is running, and on Web use a secure supported browser origin. Re-enter a credential only after the account record can save it successfully.
- **No eligible route:** check model-group membership, account status, priority tier, policy limits, required capabilities, concurrency, and cooldowns. Fallback cannot leave the configured group.

Connector errors and routing diagnostics avoid retaining credentials or request content. `AppLogService` stores caller-provided log text as supplied and does not offer general secret scrubbing; never put API keys, tokens, private prompts, or attachment content in a custom log message.

For versioned connector evidence see the [v0.6 connector inventory](roadmap/v0.6-connector-matrix-and-callsite-audit.md). For data-storage design see [data safety architecture](data-safety-architecture.md) and the [v0.6 M11 release acceptance](roadmap/v0.6-m11-release-acceptance.md).
