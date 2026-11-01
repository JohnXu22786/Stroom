# OAuth subscription connectors

The Gateway only exposes an OAuth option when a provider documents an
authorization flow for a third-party application and a compatible inference
contract. CLI sign-in state is not a transferable model credential. OAuth state,
PKCE verifier, access keys and refresh tokens stay in memory during the flow or
in platform secure storage after it. Account preferences contain only safe
connector metadata and opaque credential references. OAuth/account registration
and Chat/Task Flow model-group availability are separate: see the [connector
and routing guide](../llm-accounts-and-model-groups.md) for the exact routes
that can be selected in Chat and Task Flow.

## Enabled flows

| Connector | Authorization and inference | Lifecycle limits |
| --- | --- | --- |
| OpenAI Codex / ChatGPT | Uses OpenAI's published Sign in with ChatGPT flow, loopback callback, dynamic issued client ID, state, nonce, PKCE S256 and the `chatgpt.tokens.use.direct` scope. ID-token signature, issuer, audience, expiry and nonce are verified before saving. The verified token and subject stay in secure storage; reauthorization sends the token as `id_token_hint` and rejects a different subject. Inference uses the public OpenAI Responses API and can be selected as a Chat/Task Flow model-group member. | Requires an eligible ChatGPT plan and the provider granting the direct-token scope. The app creates a stable `ext_agent_host_id`; OpenAI's issued client ID is retained securely and reused. Refresh and OIDC-discovery revocation use that issued client ID. Codex groups default to the Responses bridge; the OpenAI API-key connector remains a separate account type with its existing Chat Completions default. [OpenAI SIWC quickstart](https://developers.openai.com/siwc/quickstart), [token sharing](https://developers.openai.com/siwc/token-sharing-open-source/sign-in), [profiles and sessions](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions). |
| Gemini Developer API / Google AI Studio | Both account types use Google's OAuth Desktop client with a loopback IP redirect URI containing no path, then call the public Generative Language API `generateContent` endpoint with a bearer token and `x-goog-user-project` attribution. The user supplies the Cloud project ID and OAuth client configuration; the OAuth client secret and token bundle are stored in secure storage. | Requires a developer-owned Cloud project, the Generative Language API, and a configured consent screen and test users. Project usage is attributed and billed under that project. Changing the Desktop client ID requires a new authorization with its matching client secret. Google describes this OAuth setup as a simplified/testing flow. It is distinct from API-key auth, Code Assist and browser sessions. Gemini content uses the existing Gemini protocol bridge. [Gemini API OAuth](https://ai.google.dev/gemini-api/docs/oauth). |
| Kimi Code CLI | Uses the pinned CLIProxyAPI Kimi device-code flow: request a device code, show the Kimi verification URL and user code, then poll the token endpoint. Access and refresh tokens plus a Stroom-generated device ID stay in secure storage. The supported Coding Plan model catalog is available through Chat and Task Flow; supplier/model configuration chooses Chat Completions, Responses, or Anthropic Messages. | This flow does not import local CLI files, browser cookies, or page sessions. It uses the fixed public OAuth client identifier from the upstream implementation; no client secret, callback, state, or PKCE is used by the device grant. The source has token refresh but no revocation endpoint; deleting the account removes Stroom's local credentials. [pinned CLIProxyAPI auth](https://github.com/router-for-me/CLIProxyAPI/blob/ad8bdd3f20bef44f0684b8a6096a216b2c76040d/internal/auth/kimi/kimi.go), [authenticator](https://github.com/router-for-me/CLIProxyAPI/blob/ad8bdd3f20bef44f0684b8a6096a216b2c76040d/sdk/auth/kimi.go), [executor](https://github.com/router-for-me/CLIProxyAPI/blob/ad8bdd3f20bef44f0684b8a6096a216b2c76040d/internal/runtime/executor/kimi_executor.go). |
| Grok Build / Grok subscription (`grok-cli`) | Uses the pinned CLIProxyAPI xAI public-client OIDC device grant and stores its tokens in secure storage. Chat and Task Flow use the Grok Build chat proxy and the provider-specific Responses dialect; the editor accepts only models returned by the authenticated Grok Build catalog. | This fixed source contract uses OIDC discovery, device authorization, polling and refresh, with no client secret. Stroom does not import CLI files or send these tokens to `api.x.ai`. The source exposes no revocation endpoint, so deleting the account removes local credentials. [pinned xAI auth](https://github.com/router-for-me/CLIProxyAPI/blob/ad8bdd3f20bef44f0684b8a6096a216b2c76040d/sdk/auth/xai.go), [authenticator](https://github.com/router-for-me/CLIProxyAPI/blob/ad8bdd3f20bef44f0684b8a6096a216b2c76040d/internal/auth/xai/xai.go), [executor](https://github.com/router-for-me/CLIProxyAPI/blob/ad8bdd3f20bef44f0684b8a6096a216b2c76040d/internal/runtime/executor/xai_executor.go). |
| Native xAI API OAuth (`xai-oauth`) | Uses the same pinned public-client xAI OIDC device grant but is stored as a separate account mode and calls only `https://api.x.ai/v1`. Models are discovered from that account's authenticated `/models` endpoint and the Responses adapter uses bearer OAuth. | The public client uses no client secret. Stroom keeps this grant separate from Grok Build OAuth and xAI API-key records. The source exposes no revocation endpoint; deletion removes local credentials. Model availability follows the xAI account entitlement. [pinned xAI auth](https://github.com/router-for-me/CLIProxyAPI/blob/ad8bdd3f20bef44f0684b8a6096a216b2c76040d/sdk/auth/xai.go), [xAI executor](https://github.com/router-for-me/CLIProxyAPI/blob/ad8bdd3f20bef44f0684b8a6096a216b2c76040d/internal/runtime/executor/xai_executor.go). |

## Unavailable OAuth routes

| Provider / route | Why it is unavailable |
| --- | --- |
| Claude Code | Anthropic documents Claude Code OAuth as CLI authentication. Its public third-party Messages API uses Console API keys or configured workload identity federation. Stroom does not import Claude CLI state or call CLI-only endpoints. [Authentication](https://platform.claude.com/docs/en/manage-claude/authentication), [Claude Code CLI authentication](https://platform.claude.com/docs/en/cli-sdks-libraries/cli/authentication). |
| Antigravity | Antigravity's user OAuth and `cloudcode-pa.googleapis.com` endpoints are first-party tool flows, not a public third-party inference API. Google documents its enterprise gateway as an administrator-configured, centralized service-account route billed as PAYG; it does not use a user's Antigravity seat quota. That admin route is unavailable here and is outside this unit. [Enterprise gateway](https://docs.cloud.google.com/gemini/enterprise/docs/ai-developer-tools/deploy-enterprise-gateway). |
| Cline / ClinePass | Cline account login and Cline-provided credits route inference through Cline's infrastructure. The public extension integration documents provider API keys and the Cline provider, but no third-party OAuth inference-client contract that Stroom can use. No ClinePass session or private API is imported. [Cline FAQ](https://cline.bot/faq), [Cline terms](https://cline.bot/tos). |
| Google Code Assist | Code Assist is a separate Google product and login/CLI flow. This connector registers only Gemini Developer API OAuth; it does not substitute Code Assist credentials, Antigravity tokens or browser sessions. |
| OpenRouter OAuth | OpenRouter's public PKCE flow can create an API key, but OpenRouter is absent from the frozen M0 OAuth connector matrix and is excluded from this unit. Users can configure a separately obtained OpenRouter API key through the generic OpenAI-compatible endpoint account. |

Unsupported legacy OAuth accounts remain readable for migration and deletion,
but the Gateway will not send their credentials to upstream providers. The
account editor shows the applicable limitation. OAuth is not inferred from a
provider name, CLI token shape or a successful browser login.

## Chat and Task Flow protocol boundary

The Gateway contains distinct Codex and xAI Responses adapters, a provider-specific
Grok Build Responses adapter, and the Gemini `generateContent` adapter. Codex
OAuth uses the Codex account/session identity headers. xAI API-key, xAI API OAuth,
and Grok Build OAuth remain separate accounts with fixed, distinct request hosts.
OpenAI API-key accounts retain their Chat Completions default. Gemini accounts
use Stroom's Gemini protocol bridge for neutral conversation history and supported
media. Conversation storage remains neutral and does not persist account identifiers.
