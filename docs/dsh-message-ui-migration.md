# Stroom DSH Message UI Migration

## Confirmed decisions

On October 9, 2026, we chose the DeepSeek Harness (DSH) web message renderer for the chat transcript. Flutter embeds the web message area; React is the renderer DSH uses to draw its web interface. The target platforms are Android, iOS, Windows, macOS, Linux, and Web. Linux support is part of this work.

Only message content is being replaced: Markdown, code, reasoning, multi-step tool calls, and attachment entry points. The composer, top bar, conversation management, and other application screens remain Flutter UI. Existing content capabilities must be retained. The message UI may be redrawn; it does not need to keep the old Flutter bubble design. Reasoning panels and existing full-screen previews continue to use Flutter.

Remove DSH's thumbs-up and thumbs-down actions. Keep copy, save Markdown, retry, edit user message, request/response inspection, developer JSON inspection, and delete. Icons and placement may change. Merge duplicate actions and connect the remaining DSH actions to Stroom's existing capabilities.

Migrate older chat data explicitly at startup. The renderer reads only the latest message structure. Streaming autosaves and final saves use that same structure so an interrupted response does not leave a partial legacy record.

## Implementation approach

A shared web message area renders the transcript instead of creating a WebView for each message. Flutter owns conversations, generation, persistence, permissions, and application actions. The renderer receives snapshots and incremental updates, and asks Flutter to perform actions using stable message IDs. Front-end assets ship with Stroom, work offline, and do not require the DSH Node service or replacement of Stroom's Agent.

The renderer reuses DSH Markdown, syntax highlighting, tool output, JSON tree, and icon components. The upstream package source is pinned to `d743267388641bc76f17c45ce8b4c231aed1d32c`. Display-layer adaptations are built against that fixed source. The MIT license text and notices for distributed fonts and dependencies are stored under `assets/vendor/dsh_message_view/`.

The new message area retains Mermaid, formulas, chemistry notation, line wrapping, underlining, and Stroom message actions. Full-screen HTML, Mermaid, attachment, code, and reasoning views continue to open their existing Flutter screens. Inline visual HTML runs in an isolated preview context without Stroom's message bridge.

### HTML examples and inline visual content

Use separate Markdown fences for HTML source and generated visual content:

- `html` is ordinary HTML source. It keeps the DSH code block, line numbers, and code actions. It never executes.
- `html-preview` is visual content intended to appear in the message. Its HTML is not mounted until the closing fence arrives. While the fence is open, the message area shows a small generating state and does not execute partial scripts.

Inline HTML previews have no persistent toolbar or border. Inline JavaScript and external network resources are allowed. On Web, the preview runs in a sandboxed iframe. On native platforms, an app-generated WebView wrapper loads the answer inside a nested `iframe` with only `allow-scripts`; it does not grant same-origin access, file access, Stroom's JavaScript bridge, or top-level navigation. The wrapper accepts height and error reports only from that child frame and with the current preview token. Content taller than the conversation viewport offers Stroom's existing full-screen Flutter preview. Rendering errors fall back to the DSH source block.

The model may decide to add an `html-preview` block when a visual materially clarifies an answer. The answer remains readable Markdown, and the visual supplements the reasoning rather than replacing it. HTML code examples use the inert `html` fence. This uses the answering model itself; it does not add a second model selector or a component schema.

## Work sequence and acceptance

1. Set up an isolated worktree and record decisions and task status.
2. Add active chat-data migration and unify assistant messages; update streaming and final persistence. Verify plain text, tool rounds without reasoning, parallel tools, read-after-save, and repeated migration.
3. Add the renderer-to-Flutter bridge. Verify conversation switching, stale update rejection, message actions, and recovery after page recreation.
4. Integrate DSH rendering and adapt message actions. Retain content extensions and full-screen entry points. Verify open streaming code fences, long answers, formulas, and ordered multi-step tools.
5. Connect history pagination, search highlights and positioning, initial scroll position, follow-to-bottom, return-to-bottom, theme, font size, and keyboard focus.
6. Support all six platforms and package renderer assets. Register Linux plugin and install dependencies; embed Web with a sandboxed iframe and a restricted message channel.
7. Run focused checks, review the complete task diff, commit, and open draft PRs. Record checks that were run and any remaining device-only validation.

## Status

The DSH message area, Flutter action bridge, active chat-v2 migration, streaming and final persistence, history pagination, search positioning, theme synchronization, and core message extensions are merged to `v0.7`. The fixed DSH renderer package is `@deepseek-ai/dsh-client-ui-primitives@0.2.1-alpha.2`. Build scripts add bounded code-block and safe inline-tag support and fail if the expected upstream anchors change.

Native platforms load the renderer from Flutter assets to avoid Windows WebView2's inline HTML size limit. Web uses a sandboxed iframe and a restricted message channel. Scripts, styles, and formula fonts ship in the app assets. The MIT text and dependency notices are under `assets/vendor/dsh_message_view/`.

The DSH front-end source and locked dependencies are in `tools/message_renderer/`. Run `npm ci` and then `npm test` to rebuild the bundled renderer and run its behavior checks. App builds use the checked-in assets and do not start a Node service.

The app uses `flutter_inappwebview 6.2.0-beta.3`, whose prerelease includes the Linux implementation. Linux requires WPE WebKit API 2.0, version 2.40 or later. Ubuntu 22.04's API 1.0 package cannot build this plugin, and Ubuntu 24.04's official repositories do not provide WPE. Linux CI, release, and nightly builds use Debian 13 (trixie) with `libwpewebkit-2.0-dev`, `libwpebackend-fdo-1.0-dev`, `libepoxy-dev`, and `libsecret-1-dev`. The Linux package baseline is therefore Debian 13; older Ubuntu compatibility is not claimed. An optional web theme-color API was added in WPE 2.50, so older WPE versions return “no theme color” for that optional API while the message area continues using Flutter's theme. WPE libraries, subprocesses, and resources remain system packages; incomplete WebKit libraries are not copied into the app bundle. Debian 13 runtime packages include `libwpewebkit-2.0-1`, `libwpebackend-fdo-1.0-1`, `libepoxy0`, and `libsecret-1-0`, plus Stroom's existing GTK, mpv, and tray dependencies. Other distributions need a matching WPE runtime and must build against it.

The new Web message area is enabled by default. `--dart-define=STROOM_NATIVE_MESSAGES=true` temporarily restores the old Flutter message renderer; the stored data remains v2. Legacy Flutter bubble tests run with that explicit build define, while the new renderer has direct bundled-HTML JavaScript checks and Flutter bridge checks.

CI covers Android, iOS, Windows, macOS, Linux, and Web. Each platform builds the app and runs message-view and Flutter bridge smoke tests. Android and iOS use simulators; desktop uses native runners; Web uses Chromium. The DSH renderer has its own behavior and bundle-reproducibility checks.

## Targeted validation recorded

- Native migration: plain messages, one reasoning segment, empty reasoning rounds, tool order, compaction marker, repeated execution, migration failure, and corrupt entries.
- Web worker migration: ordering and body restoration, repeated execution, and invalid JSON errors.
- Real periodic persistence: pause generation across the five-second save interval and compare intermediate and final message blocks.
- Message rendering: safe line breaks and underlines, chemistry formulas, streaming HTML, tool order, conversation replacement, stale event rejection, search, and interleaved updates.
- Flutter bridge: incremental sends, conversation generations, rejection of stale actions, source ranges for code actions, closed fences, quoted/list/indented code.
- Stop generation: freeze body, reasoning, and tool blocks before saving an incomplete answer; merge the final result by message ID to avoid duplicate messages or overwriting later actions.

Remote CI is configured to build and smoke-test all six platforms for each relevant PR. Each change still needs its own passing CI result. Simulator and desktop smoke tests are not equivalent to full interaction testing on physical devices. Scrolling, keyboard, file selection, and full-screen preview still need broader device testing.

For macOS 11 WebKit, the renderer includes `Array.at` and `Object.hasOwn` polyfills. Syntax highlighting uses bundled Oniguruma WASM and does not require a network connection. The old WebKit CSP permits this compilation path; model output is rendered from Markdown AST and cannot enter the script or message-action bridge.

## Intelligent UI research notes

The earlier sample review found that Thesys's default pipeline returns OpenUI structured content: the answer model uses a component protocol to organize the answer and display. Six natural-language question types were generated repeatedly for 22 samples, including follow-up questions and interactive controls. They all parsed as OpenUI, but that exercise did not include browser screenshots or control-click testing.

CopilotKit selects a display class with Jev (for example text, table, chart, diagram, interactive diagram, map, or calculator) and then asks the answer model to generate for that class. Jev is a backend call; the end user does not write rules. The public demo's bring-your-own-key path asks for both OpenAI and Jev keys.

The prompt-length review found a Thesys system-prompt snapshot of about 33,400 characters and a CopilotKit base answer prompt of about 6,200 characters. CopilotKit's router is program code and should not be counted as prompt text; its SVG and advanced-visualization guidance is separately available as skills. CopilotKit did not produce a model sample in that review, so those samples do not establish equal generation quality between the products.

Stroom's initial implementation uses the answer model directly, with a short appended instruction rather than an extra selector model or a large component protocol. It decides whether a visual would help and uses `html-preview` for that output. A dedicated skill or richer visual contract can be evaluated later using real generated answers, screenshots, and interaction tests.

## Current follow-up status (2026-11-05)

- PR #800 was merged into `v0.7` on 2026-11-01 as commit `c90c50f259c09cc456eaae1661347f24519293ef`. The message-area migration, chat-v2 block migration, streaming persistence, Flutter bridge, and six-platform host coverage are implemented.
- PR run [41331836925](https://github.com/JohnXu22786/Stroom/actions/runs/41331836925) passed Android, iOS Simulator, Windows, macOS, Linux, and Web message-view smoke jobs and associated test jobs.
- The later Mermaid toolbar layout gives preview mode zoom out, zoom in, full-screen, and source actions. Source mode keeps the DSH code block and line numbers with copy, save, wrap, and chart actions. Request/response and JSON inspection use distinct icons.
- The HTML source/visual distinction and concise answer-model visualization instruction are implemented in a separate follow-up. Native preview isolation uses a sandboxed child frame inside an app-generated WebView wrapper; it is covered by focused document-boundary tests. Tests and CI for that follow-up must be reported from its own PR rather than inferred from PR #800.
- Physical-device interaction checks remain separate from simulator and desktop CI.
