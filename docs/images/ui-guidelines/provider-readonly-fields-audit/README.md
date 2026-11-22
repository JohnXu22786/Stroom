# MCP read-only field audit

## Method

Captured the production `showMcpServerConfigDialog` from `lib/pages/mcp_server_config_page.dart` in Chromium. `ProviderConfigPage` opens the same function for MCP entries (`lib/pages/provider_config_page.dart`); the temporary QA entrypoint seeded the provider state to keep the route deterministic and opened the production dialog directly. The screenshots show the MCP dialog, not the Settings root page.

The audit used a 380 × 900 CSS-pixel viewport, device scale factor 1, and Flutter text scale 1.5. It covered de-DE and ar-SA with both light and dark Material themes. Captures use the system font stack.

## Findings

- The SSE URL is 237 characters, including a 192-character unbroken token-like segment. It wraps within the `ReadOnlyField` width; no horizontal clipping is visible.
- The 133-character description wraps naturally within its read-only field. The full description remains visible after scrolling the dialog.
- Section headings, field labels, values, and adjacent icons remain visible. The API key is intentionally masked by the production dialog.
- The dialog scrolls vertically to reveal later fields. No finite-slot clipping was found in `SectionHeader` or `ReadOnlyField`, so production UI code was left unchanged.
- The existing dialog title uses `ConstrainedText`. `title-head.png` captures the initial text position at 1.0 s, `title-tail.png` captures the later position at 3.5 s, and `title-reveal.webm` shows its normal horizontal reveal.

The screenshot filenames encode locale, theme, and scroll position: `{de,ar}-{light,dark}-{top,middle,bottom}.png`.
