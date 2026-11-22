# Bounded reasoning dialog header

The production `ReasoningSection` opens the actual reasoning panel in Chromium at 320 × 640, 1×, French, and light theme. The completed title is longer than its measured header slot beside section index 6, so only the title moves horizontally; the psychology icon, index, empty completed-status slot, and close action remain in place. The markdown body stays naturally wrapped.

- [Production dialog capture, 320 × 640, 1×](french-dialog-header-320x640-1x.png)
- [Playable title reveal preview](french-dialog-header-motion-preview.webm)

The capture used a temporary Flutter Web entrypoint with local reasoning text and a completed conversation state. It made no provider or network request and was removed after capture. The targeted header widget test opens the dialog at 320 × 640 for running and completed states with a nonzero section index, checking the spinner, close action, and absence of layout exceptions. It exercises a large index to verify the index also stays bounded. At 700 × 640 the French completed heading fits and stays stationary after two seconds. `tests/reasoning_section_animation_test.dart` verifies the spinner fade, checkmark pop and shrink sequence. Chromium reported no page errors during capture.

Targeted checks:

- `flutter test --no-pub tests/pages/chat/widgets/reasoning_section_test.dart --plain-name 'narrow reasoning dialog bounds localized header and keeps controls'`
- `flutter test --no-pub tests/reasoning_section_animation_test.dart --plain-name 'corner spinner fades out, checkmark pops in with jelly overshoot, holds, then pops out and disappears'`
