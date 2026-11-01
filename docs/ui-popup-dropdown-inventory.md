# Popup, dropdown, and selection overlay inventory

Generated from the tracked Stroom Dart source under `lib/`. To reproduce the API callsite inventory, run `rg -n "PopupMenuButton|showMenu|DropdownButton|DropdownMenu|MenuAnchor|OverlayEntry|CompositedTransformFollower" lib --glob '*.dart'`, then review each `OverlayEntry` owner to distinguish menus from unrelated drag feedback. The externally owned math component/package is excluded from this audit and from all code changes and renders.

## Shared visual system

`StroomMenuStyle` in `lib/widgets/stroom_menu_style.dart` is the shared source of menu surface and shape styling. The light and dark application themes both use it. Popup menus and `showMenu` inherit a `surfaceContainerHigh` surface, transparent tint, 16 dp rounded corners, and a subtle `outlineVariant` border. Dropdown menus built with `DropdownMenu` inherit a `MenuStyle` with the same surface/shape and 8 dp elevation. Every legacy `DropdownButton` / `DropdownButtonFormField` callsite sets the same themed surface and 16 dp `borderRadius`, because Flutter does not expose a global border-radius property for those legacy widgets. Flutter supplies the menu item hover, focus, disabled, and selected interaction states; existing destructive actions retain their `error` color and are separated from routine actions by `PopupMenuDivider` where both kinds appear.

## API families and callsites

| Family | Count | Styling applied | Notes |
|---|---:|---|---|
| `PopupMenuButton` | 26 | shared `PopupMenuThemeData` | All menu buttons inherit the app theme; destructive groups keep existing dividers. |
| `showMenu` | 1 | shared `PopupMenuThemeData` | Mermaid editor mode picker. |
| `DropdownButton` / `DropdownButtonFormField` | 33 | shared surface/radius token at each callsite | Legacy Flutter widget has no global menu-shape theme property. |
| `DropdownMenu` / `MenuAnchor` | 0 | shared `DropdownMenuThemeData` is configured | No current callsites. |
| App-authored suggestion `OverlayEntry` | 1 | shared surface/radius, outline, rounded rows | `LabeledTextField` model/context suggestions. |
| Other `OverlayEntry` | 1 | not menu styling | `DragSortArea` release animation renders drag feedback; it is not a menu or selection list. |

### Popup buttons

| Screen / component | Source file | Callsite(s) | Styling / exception |
|---|---|---:|---|
| batch rename dialog | `lib/widgets/batch_rename_dialog.dart` | 386 | shared popup theme; destructive separator preserved where applicable |
| batch rename dialog | `lib/widgets/batch_rename_dialog.dart` | 464 | shared popup theme; destructive separator preserved where applicable |
| batch rename dialog | `lib/widgets/batch_rename_dialog.dart` | 579 | shared popup theme; destructive separator preserved where applicable |
| file manager view | `lib/widgets/file_manager_view.dart` | 576 | shared popup theme; destructive separator preserved where applicable |
| file manager view | `lib/widgets/file_manager_view.dart` | 700 | shared popup theme; destructive separator preserved where applicable |
| file manager view | `lib/widgets/file_manager_view.dart` | 1003 | shared popup theme; destructive separator preserved where applicable |
| file manager view | `lib/widgets/file_manager_view.dart` | 1109 | shared popup theme; destructive separator preserved where applicable |
| file manager view | `lib/widgets/file_manager_view.dart` | 1205 | shared popup theme; destructive separator preserved where applicable |
| file manager view | `lib/widgets/file_manager_view.dart` | 1466 | shared popup theme; destructive separator preserved where applicable |
| batch rename rule editor | `lib/widgets/batch_rename_rule_editor.dart` | 329 | shared popup theme; destructive separator preserved where applicable |
| topic item | `lib/widgets/topic_item.dart` | 162 | shared popup theme; destructive separator preserved where applicable |
| anki page | `lib/pages/anki_page.dart` | 378 | shared popup theme; destructive separator preserved where applicable |
| provider config page | `lib/pages/provider_config_page.dart` | 1317 | shared popup theme; destructive separator preserved where applicable |
| conversations page | `lib/pages/conversations_page.dart` | 460 | shared popup theme; destructive separator preserved where applicable |
| ocr page | `lib/pages/ocr_page.dart` | 526 | shared popup theme; destructive separator preserved where applicable |
| ocr page | `lib/pages/ocr_page.dart` | 1153 | shared popup theme; destructive separator preserved where applicable |
| task list shared | `lib/pages/task_list_shared.dart` | 149 | shared popup theme; destructive separator preserved where applicable |
| task list shared | `lib/pages/task_list_shared.dart` | 198 | shared popup theme; destructive separator preserved where applicable |
| task list shared | `lib/pages/task_list_shared.dart` | 238 | shared popup theme; destructive separator preserved where applicable |
| task list shared | `lib/pages/task_list_shared.dart` | 279 | shared popup theme; destructive separator preserved where applicable |
| unified task list page | `lib/pages/unified_task_list_page.dart` | 299 | shared popup theme; destructive separator preserved where applicable |
| flow block card | `lib/task_flow/widgets/flow_block_card.dart` | 361 | shared popup theme; destructive separator preserved where applicable |
| synthesis task card | `lib/pages/unified_task_list/synthesis_task_card.dart` | 202 | shared popup theme; destructive separator preserved where applicable |
| synthesis task card | `lib/pages/unified_task_list/synthesis_task_card.dart` | 253 | shared popup theme; destructive separator preserved where applicable |
| synthesis task card | `lib/pages/unified_task_list/synthesis_task_card.dart` | 299 | shared popup theme; destructive separator preserved where applicable |
| synthesis task card | `lib/pages/unified_task_list/synthesis_task_card.dart` | 341 | shared popup theme; destructive separator preserved where applicable |

### Programmatic popup menus

| Screen / component | Source file | Callsite(s) | Styling / exception |
|---|---|---:|---|
| mermaid chart page | `lib/pages/mermaid_chart_page.dart` | 296 | shared popup theme |

### Dropdown buttons and form fields

| Screen / component | Source file | Callsite(s) | Styling / exception |
|---|---|---:|---|
| batch rename dialog | `lib/widgets/batch_rename_dialog.dart` | 562 | shared dropdown surface and 16 dp menu radius |
| batch rename dialog | `lib/widgets/batch_rename_dialog.dart` | 607 | shared dropdown surface and 16 dp menu radius |
| file manager view | `lib/widgets/file_manager_view.dart` | 2828 | shared dropdown surface and 16 dp menu radius |
| provider settings panel tab basic | `lib/pages/provider_settings_panel_tab_basic.dart` | 55 | shared dropdown surface and 16 dp menu radius |
| provider settings panel tab basic | `lib/pages/provider_settings_panel_tab_basic.dart` | 210 | shared dropdown surface and 16 dp menu radius |
| provider settings panel tab basic | `lib/pages/provider_settings_panel_tab_basic.dart` | 346 | shared dropdown surface and 16 dp menu radius |
| provider settings panel tab basic | `lib/pages/provider_settings_panel_tab_basic.dart` | 436 | shared dropdown surface and 16 dp menu radius |
| simple model config page | `lib/pages/simple_model_config_page.dart` | 246 | shared dropdown surface and 16 dp menu radius |
| anki page | `lib/pages/anki_page.dart` | 239 | shared dropdown surface and 16 dp menu radius |
| llm model config page reasoning builders | `lib/pages/llm_model_config_page_reasoning_builders.dart` | 416 | shared dropdown surface and 16 dp menu radius |
| tts create page | `lib/pages/tts_create_page.dart` | 563 | shared dropdown surface and 16 dp menu radius |
| tts create page | `lib/pages/tts_create_page.dart` | 1008 | shared dropdown surface and 16 dp menu radius |
| voice batch add page | `lib/pages/voice_batch_add_page.dart` | 351 | shared dropdown surface and 16 dp menu radius |
| model config page | `lib/pages/model_config_page.dart` | 1113 | shared dropdown surface and 16 dp menu radius |
| ocr page | `lib/pages/ocr_page.dart` | 813 | OCR model selector; shared dropdown surface and rounded menu |
| ocr page | `lib/pages/ocr_page.dart` | 960 | shared dropdown surface and 16 dp menu radius |
| assistant selection page edit custom param | `lib/pages/assistant_selection_page_edit_custom_param.dart` | 63 | shared dropdown surface and 16 dp menu radius |
| llm model config page sections | `lib/pages/llm_model_config_page_sections.dart` | 199 | shared dropdown surface and 16 dp menu radius |
| llm model config page sections | `lib/pages/llm_model_config_page_sections.dart` | 409 | shared dropdown surface and 16 dp menu radius |
| provider settings panel custom params | `lib/pages/provider_settings_panel_custom_params.dart` | 228 | shared dropdown surface and 16 dp menu radius |
| asr page | `lib/pages/asr_page.dart` | 670 | shared dropdown surface and 16 dp menu radius |
| provider settings panel tab asr | `lib/pages/provider_settings_panel_tab_asr.dart` | 48 | shared dropdown surface and 16 dp menu radius |
| provider settings panel tab asr | `lib/pages/provider_settings_panel_tab_asr.dart` | 132 | shared dropdown surface and 16 dp menu radius |
| asr model config page | `lib/pages/asr_model_config_page.dart` | 512 | shared dropdown surface and 16 dp menu radius |
| asr model config page | `lib/pages/asr_model_config_page.dart` | 671 | shared dropdown surface and 16 dp menu radius |
| asr model config page | `lib/pages/asr_model_config_page.dart` | 771 | shared dropdown surface and 16 dp menu radius |
| assistant selection page add custom param | `lib/pages/assistant_selection_page_add_custom_param.dart` | 52 | shared dropdown surface and 16 dp menu radius |
| text storage shared | `lib/pages/text_storage_shared.dart` | 118 | shared dropdown surface and 16 dp menu radius |
| ocr model config page | `lib/pages/ocr_model_config_page.dart` | 631 | shared dropdown surface and 16 dp menu radius |
| provider settings panel reasoning | `lib/pages/provider_settings_panel_reasoning.dart` | 635 | shared dropdown surface and 16 dp menu radius |
| block chain editor | `lib/task_flow/widgets/block_chain_editor.dart` | 213 | shared dropdown surface and 16 dp menu radius |
| block editor dialog | `lib/task_flow/widgets/block_editor_dialog.dart` | 437 | shared dropdown surface and 16 dp menu radius |
| block editor dialog | `lib/task_flow/widgets/block_editor_dialog.dart` | 596 | shared dropdown surface and 16 dp menu radius |

## Custom overlay and reviewed exclusions

- `lib/pages/llm_model_config_shared.dart:135` creates the `LabeledTextField` suggestion list overlay at line 191. It now shares the theme surface, border, and 16 dp corner radius, with rounded interactive rows. This is the only menu-like app-authored overlay found outside Flutter menu APIs.
- `lib/widgets/drag_sort_area.dart:329` creates a release-animation overlay for drag feedback. It has no menu or selectable list and is outside this styling pass.
- Source search found no app-owned `DropdownMenu`, `MenuAnchor`, `Autocomplete`, or `RawAutocomplete` callsites.
- Search sheets, media/action sheets, and dialogs opened with `showModalBottomSheet` / `showDialog` were reviewed separately. They are structured sheets/dialogs with their own actions, search, or content rather than popup/dropdown menus. Existing picker sheets keep their placement and sheet-specific design.
- External math UI is excluded because it is owned by the external math component; no math-owned source was changed or rendered.

## Render captures

Actual widget-test renders are saved (the Files, task-list, and OCR frames use 1280 × 800; the taller model-settings screen uses 800 × 1400) outside the repository at `/tmp/stroom-popup-overlay-renders/`: `files-popup.png`, `task-list-menu.png`, `ocr-model-dropdown.png`, and `model-suggestions.png`. `contact-sheet.png` shows all four families side by side. The focused short-viewport suggestion test also checks that its list remains inside the viewport. The container test renderer lacks the app locale fonts, so its glyphs appear as fallback boxes; the frames still show actual Stroom screens, menu placement, surfaces, and row spacing.
