# Bounded task dialog titles

The production `TaskCard` opens the original-exchange dialog with the full German title in a flexible `ConstrainedText` slot. The icon and title remain aligned, the title moves only because its measured text exceeds the available width, and the request/response bodies continue to wrap and scroll as selectable text.

- [Original-exchange dialog at 320 × 640, 1×, light theme](original-exchange-320x640-1x.png)
- [Playable title reveal](original-exchange-title-reveal.webm), captured at 320 × 640, 1×, with normal motion

The capture used a temporary Flutter Web fixture with a local failed task and the production `TaskCard`; no provider request was made. The widget regression test covers long German titles at 320 × 640 and 1.5× in dark theme, plus a fitting English title at 700 × 640 and 1× in light theme. It verifies the full title string remains available and that fitting text does not move after the marquee delay.
