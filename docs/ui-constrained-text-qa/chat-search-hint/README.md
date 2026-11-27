# Chat current-search hint

These focused crops show the search controls from the production `ChatPage` with a safe in-memory conversation. The fixture makes no provider request and uses no saved account data. The text field is empty and focused after opening search; the pointer is moved away from the controls, and the browser has no software keyboard. Crops exclude the unrelated chat body and its unconfigured-provider notice.

- French at 320 × 640 CSS px, 2× text scale, light and dark theme: `chat-search-hint-fr-320x640-scale2-{light,dark}.png`.
- German at 320 × 640 CSS px, 1× text scale, light theme: `chat-search-hint-de-320x640-scale1-light.png`.
- Fitting English at 1000 × 700 CSS px, 1× text scale, light theme: `chat-search-hint-en-1000x700-scale1-light.png`.
- `chat-search-hint-fr-reveal-return.webm` is a 23-second real-time crop that records the French 1-second initial delay, about 9 seconds of travel in each direction, both 2-second endpoint holds, and complete return using the production component at 24 logical px/s.

The static images use `MediaQuery.disableAnimations` so the initial clipped position is stable. The video uses regular motion. The production capture fixture and Chromium script are `tool/qa/chat_search_hint_capture.dart` and `tool/qa/capture_chat_search_hint.py`.
