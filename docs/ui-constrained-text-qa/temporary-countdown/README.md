# Temporary conversation countdown

These are Flutter-rendered production `ConversationsPage` captures using a safe
in-memory temporary conversation. No account data or network request is used.
Fixtures use a fixed updated-at time and the production paused-countdown state
at 20:00 so the captures remain deterministic.

- `temporary-conversations-fr-430x932-scale1-light.png` shows the existing
  fitting inline capsule and title layout at normal text size.
- `temporary-conversations-fr-320x640-scale4-light.png` shows the static full
  `MM:SS` capsule on its own line when the scaled timer cannot fit beside the
  title and row actions.
- `temporary-conversations-fr-320x640-scale4-reveal.png` captures the later
  frame of the existing title reveal after its initial still period.
- `conversation-reveal-preview.gif` shows the existing title marquee through
  its travel and return cycle. The countdown capsule remains static throughout.
- `topic-item-fr-320x640-scale4-light.png` captures the production topic card
  with the timer reflowed below the title/actions row.
- `topic-item-fr-320x640-scale4-reveal.png` captures the later frame of the
  existing topic date reveal.
- `topic-date-reveal-preview.gif` shows the existing date marquee through its
  travel and return cycle. The countdown capsule remains static throughout.
- `chat-header-fr-320x640-scale4-light.png` is cropped from the actual keyed
  `ChatPage` topbar at its initial stationary frame, with the static `20:00`
  timer below its title/actions row. The focused widget test checks that the
  title stays fixed through its first second, checks the header bounds, and
  captures later reveal frames. On unmodified main, the same temporary fixture
  had a 114px capsule-row overflow and a 2681px page-body Column overflow. The
  candidate uses bounded, scrollable header/composer regions and a bounded chat
  viewport; oversized chat state content also scrolls while preserving its
  centered layout when it fits. The final fixture has no header, state-view, or
  page-body overflow exceptions.
- `chat-page-fr-320x640-scale4-light.png` shows the complete production page in
  that constrained layout. The test confirms that the fitting header content
  stays within its slot and that the composer scroll region exposes its
  remaining controls.
- `chat-page-fr-320x640-scale4-scrolled-light.png` shows the full page after
  scrolling the seeded chat history and composer content; both regions remain
  reachable without layout exceptions. The page fixture includes a real user
  history message so loading and empty placeholders are not stacked together.
- `chat-page-fr-320x640-scale1-light.png` shows the complete production page
  with the existing inline header capsule at normal scale. The capture test
  verifies `TextScaler.linear(1)` at the ChatPage context. The shared state
  widget test separately checks its 4× scrolling and normal-scale centering.
- `chat-header-reveal-preview.gif` shows the existing title reveal across its
  travel and return cycle; the timer stays static.

Conversation and topic captures use
`tests/qa/temporary_countdown_capture_test.dart`. The real chat-header capture
and layout checks use `tests/pages/chat_page/chat_page_temporary_test.dart`.
Captures use Roboto and Material Icons at 320×640 with 4× text scaling for
cramped states, and a paused 20:00 countdown to keep timer digits deterministic.
