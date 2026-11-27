# Constrained static input hints

This audit covers the Round 10 R10-07 finite-field candidates and measured
analogous model-name fields. The repository contains 122 `hintText:` matches;
this report does not claim all 122 were visually audited. Natural-flow helper
copy, editable content, and unrelated hint families are excluded.

## Confirmed clipped and migrated

| Call site | Production render measurement | Disposition |
| --- | --- | --- |
| `mcp_server_config_page.dart` server name | en, 320×640 at 1x; slot 172×24, intrinsic 396 px | Clipped by 224 px; constrained hint |
| MCP command example | en, 320×640 at 1x; slot 172×24, intrinsic 198 px | Clipped by 26 px; constrained hint |
| MCP SSE URL | en, 320×640 at 1x; slot width 172, intrinsic 561 px | Clipped; constrained hint |
| MCP API key | en, 320×640 at 1x; slot 136×24, intrinsic 445.5 px | Clipped by 309.5 px; constrained hint |
| MCP description | en, 320×640 at 1x; slot 172×48, natural height 120 px, maxLines 2 | Clipped by 72 px; constrained hint |
| `asr_model_config_page.dart` language example | de, 320×640 at 1.8x; slot width 232, intrinsic 468.75 px, maxLines 1 | Clipped; constrained hint |
| ASR prompt | de, 320×640 at 1.8x; slot width 232, intrinsic 996.09 px, maxLines 1 | Clipped; constrained hint |
| `llm_model_config_page_reasoning.dart` option example | fr-FR, 360×900 at 1.8x; slot 225.6×43, intrinsic 703.125 px | Clipped in add/edit dialogs; shared constrained dialog hint |
| `assistant_remote_source_dialog.dart` catalog URL | 320×640 at 2x; slot 156×48, intrinsic 715 px | Clipped; constrained hint |
| `assistant_defaults_tab.dart` tool-output default | pt-BR, 320×640 at 2x; slot 208×48, intrinsic 390 px | Clipped; constrained hint |
| `asr_page.dart` public audio URL | de-DE, 320×900 at 2x; slot 192×48, intrinsic 475.2 px | Clipped; constrained hint |
| `topic_selection_page.dart` conversation rename | de-DE, 320×640 at 1.8x; slot 185.6×43, maxLines 1, didExceedMaxLines true | Clipped; constrained hint, original one-line geometry retained |
| `anki_sync_page.dart` self-hosted URL | de-DE, 320×900 at 2x; slot 180×48, intrinsic 975 px | Clipped; constrained hint |
| `simple_model_config_page.dart` model name | de, 320×640 at 1.8x; one-line slot width 256, intrinsic 937.5 px | Clipped; constrained hint |

## Measured fit and preserved native

| Call site/family | Production render measurement | Disposition |
| --- | --- | --- |
| ASR model name | de, 320×640 at 1.8x; slot 256×215, intrinsic 937.5 px, wraps to 215 px, no max-line overflow | Natural multiline fit; unchanged |
| ASR model ID | de, 320×640 at 1.8x; slot 256×129, intrinsic 439.45 px, wraps to 129 px, no max-line overflow | Natural multiline fit; unchanged |
| ASR custom-parameter example | 320×640 at 1.8x; slot 180×105, maxLines 8, no overflow | Natural multiline fit; unchanged |
| Anki PEM certificate | de-DE, 320×900 at 2x; slot 216×240, intrinsic 877.5 px, maxLines 6, field 248×256, didExceedMaxLines false | Natural multiline fit; unchanged |
| LLM and OCR model-name siblings | de, 320×640 at 1.8x; slot 256×215, intrinsic 937.5 px, no max-line overflow | Natural multiline fit; unchanged |
| MCP arguments helper | 320×640; natural-flow helper copy, not a static decoration hint | Excluded |

## Semantics and styling

Route tests inspect the real `EditableText` node before and after typing,
including tap, setText, and setSelection actions. The visual hint is excluded
from semantics; a field-level semantics hint carries the full string once.
Tests also compare the shared hint style to `InputDecorator` across M2/M3,
local/theme hint styles, focus, hover, disabled and error states. The ASR URL
route checks focused and validation-error colors on the production field.

## Browser captures

Captures use production Flutter routes/widgets, not a static mock, and were refreshed on base `fa9e99c7`:

- `mcp-config-en-320x640-1x.png`: clipped MCP form hints.
- `asr-audio-url-de-DE-320x900-2x.png`: clipped audio URL hint and focused field.
- `asr-audio-url-reveal-de-DE-320x900-2x.png` and the matching `.webm`: reveal in progress.
- `llm-model-name-fit-fr-FR-360x900-1.8x.png`: naturally multiline fitting model-name hint, left unchanged.
- `reasoning-option-fr-FR-360x900-1.8x.png`: reasoning-option dialog's clipped example.

The ASR URL web route renders one full `aria-description="https://example.com/audio.mp3"` on the native input, without a duplicate placeholder or aria-label. The recording shows the hint moving through the bounded field at the reported viewport and locale.
