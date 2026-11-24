# OAuth subscription connectors

OAuth is offered only when an authorization flow and a compatible inference route are available to Stroom. Local CLI sign-in state and browser sessions are not treated as transferable credentials. OAuth state, PKCE verifiers, tokens, and client secrets stay in memory during authorization or in platform secure storage. Ordinary account preferences contain only safe metadata and credential references.

Account registration does not by itself make a model available to Chat or Task Flow. The [account and model-group guide](../llm-accounts-and-model-groups.md) explains route eligibility and fallback behavior.

## Supported flows

| Account | Flow and Chat/Task Flow route | Limits |
| --- | --- | --- |
| OpenAI Codex / ChatGPT | OpenAI's published Sign in with ChatGPT flow uses a loopback callback, state, nonce, PKCE S256, and the `chatgpt.tokens.use.direct` scope. The verified token is stored securely and used with the public Responses API. | Requires provider approval for the direct-token scope and an eligible plan. OAuth and API-key accounts remain separate account types. |
| Zed Hosted Models | Browser sign-in on a loopback port; the callback token is decrypted in memory. Chat and Task Flow use Zed's native streaming API and account model catalog. | Availability follows the Zed account entitlement. Only advertised tool and image capabilities are sent; unsupported media is rejected. |
| Gemini Developer API / Google AI Studio | Desktop OAuth client with a loopback IP redirect. Requests use the Gemini Developer API and `x-goog-user-project`. The user provides a Google Cloud project and the matching OAuth client configuration. | Requires a user-managed Cloud project, enabled Generative Language API, consent configuration, and any required billing/quota. This is distinct from AI Studio web login and Google Code Assist. |
| Kimi Code CLI | Device-code authorization stores access and refresh tokens securely. The Coding Plan account can use its supported conversational model catalog through Chat and Task Flow. | This is separate from a Moonshot public API Key account. Local CLI files, browser cookies, and web sessions are not imported. |
| Grok Build subscription | Public-client device authorization; requests use the account's Grok Build route and provider-specific Responses dialect. | Model availability follows the authenticated account catalog. This is distinct from a native xAI API Key account. |
| Native xAI API OAuth | Public-client device authorization; models are discovered for the account and requests go to the native xAI API using Responses. | Kept separate from Grok Build and API-key accounts. Availability follows the account entitlement. |
| Meta Muse Code | Device authorization exchanges the grant for a Muse API key stored in secure storage. Chat and Task Flow use the supported conversational catalog and Responses adapter. | Kept separate from Meta API-key accounts. |

## API-key-only account types

The current Qwen, GLM, DeepSeek, and MiniMax connectors use their supported API-key or provider-issued key modes. Stroom does not expose OAuth account flows for these four providers in this version. A key-based account can still use a compatible upstream protocol when the provider supports it.

## Unavailable flows

| Provider or login | Status |
| --- | --- |
| Antigravity | Unavailable for Chat and Task Flow. Stroom does not have a supported public third-party authorization and inference route for this login. Existing records can be inspected or deleted; they are not eligible for model groups. |
| Claude Code login | Unavailable as a subscription OAuth route. Use a supported Anthropic API credential for the public Messages API. Stroom does not import Claude CLI state or call CLI-only endpoints. |
| Cline account login | Unavailable as an OAuth inference route. Configure a supported provider credential instead. |
| Google Code Assist | Unavailable as a Gemini Developer API credential. Use Gemini API Key or the documented user-managed Cloud Desktop OAuth setup. |

OAuth account deletion removes Stroom's local credentials. A provider-side revocation is attempted only when that provider offers a supported revocation endpoint; a failure is shown to the user. Existing unsupported legacy records remain readable for review or deletion, but are not advertised as usable Chat or Task Flow routes.
