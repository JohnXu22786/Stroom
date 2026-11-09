# Popup, dropdown, and selection overlay inventory

This is the production-source inventory for Stroom-owned Flutter UI in `lib/` and the first-party [`packages/streaming_markdown/`](../packages/streaming_markdown/) package. Tests are counted for repository coverage but not as app call sites; `tool/` and `integration_test/` were also searched and contain no in-scope production call sites. The external math component is excluded. See the [UI guidelines](ui-guidelines.md) for the broader design and review patterns. To reproduce tracked source counts, run `git ls-files '*.dart'` and group by the first path segment. To reproduce the menu-family search, run `rg -n "PopupMenuButton|showMenu|DropdownButton|DropdownMenu|MenuAnchor|MenuItemButton|Autocomplete|OverlayEntry|OverlayPortal|CompositedTransformFollower|CompositedTransformTarget" lib tests integration_test tool packages --glob '*.dart'`, then review overlay owners to distinguish menus from unrelated drag feedback.

## Repository-wide Dart-source coverage

The tracked repository contains 1,275 Dart files across five top-level roots: `lib/` (650 application and built-in-module source files), `tests/` (536 test files), `packages/` (87 files in the tracked `streaming_markdown` package), `integration_test/` (1 test file), and `tool/` (1 utility). `lib/` is the application source root; the built-in Stroom modules, including Anki and CatCatch, are inside it. The repository-wide search includes every tracked source root. The `packages/` results contain no in-scope menu or selection overlay callsite. The `tool/` file (`tool/asr_evaluate.dart`) and integration test (`integration_test/app_smoke_test.dart`) also contain none. Test files are counted above but are not treated as application source callsites.

The repository-wide search found no relevant popup, dropdown, menu, autocomplete, or menu-like overlay callsites outside `lib/` (including in `packages/`). In `lib/`, it found 32 `PopupMenuButton` callsites, 1 `showMenu` callsite, 49 legacy `DropdownButton` / `DropdownButtonFormField` callsites, and 2 `OverlayEntry` callsites. The two overlays are the LabeledTextField suggestion menu and DragSortArea drag feedback, respectively. No `DropdownMenu`, `MenuAnchor`, `MenuItemButton`, `Autocomplete`, or `RawAutocomplete` callsites were found.

## Shared visual system

`StroomMenuStyle` in `lib/widgets/stroom_menu_style.dart` is the shared source of menu surface and shape styling. The light and dark application themes both use it. Popup menus and `showMenu` inherit a `surfaceContainerHigh` surface, transparent tint, 16 dp rounded corners, and a subtle `outlineVariant` border. Dropdown menus built with `DropdownMenu` inherit a `MenuStyle` with the same surface/shape and 8 dp elevation. Every legacy `DropdownButton` / `DropdownButtonFormField` callsite sets the same themed surface and 16 dp `borderRadius`, because Flutter does not expose a global border-radius property for those legacy widgets. Flutter supplies the menu item hover, focus, disabled, and selected interaction states; existing destructive actions retain their `error` color and are separated from routine actions by `PopupMenuDivider` where both kinds appear.

## API families and callsites

| Family | Count | Styling applied | Notes |
|---|---:|---|---|
| `PopupMenuButton` | 32 | shared `PopupMenuThemeData` | All menu buttons inherit the app theme; destructive groups keep existing dividers. |
| `showMenu` | 1 | shared `PopupMenuThemeData` | Mermaid editor mode picker. |
| `DropdownButton` / `DropdownButtonFormField` | 49 | shared surface/radius token at each callsite | Legacy Flutter widget has no global menu-shape theme property. |
| `DropdownMenu` / `MenuAnchor` | 0 | shared `DropdownMenuThemeData` is configured | No current callsites. |
| App-authored suggestion `OverlayEntry` | 1 | shared surface/radius, outline, rounded rows | `LabeledTextField` model/context suggestions. |
| Other `OverlayEntry` | 1 | not menu styling | `DragSortArea` release animation renders drag feedback; it is not a menu or selection list. |

### Popup buttons

| Source file | Callsite lines | Count |
|---|---:|---:|
| `lib/pages/anki_page.dart` | 396 | 1 |
| `lib/pages/conversations_page.dart` | 569 | 1 |
| `lib/pages/llm_account_management_page.dart` | 1440, 1597 | 2 |
| `lib/pages/ocr_page.dart` | 619, 1299 | 2 |
| `lib/pages/provider_config_page.dart` | 1537 | 1 |
| `lib/pages/task_list_shared.dart` | 165, 223, 271, 320 | 4 |
| `lib/pages/unified_task_list/synthesis_task_card.dart` | 209, 269, 324, 375 | 4 |
| `lib/pages/unified_task_list_page.dart` | 331 | 1 |
| `lib/task_flow/widgets/catcatch_policy_menu.dart` | 32 | 1 |
| `lib/task_flow/widgets/flow_block_card.dart` | 393 | 1 |
| `lib/widgets/batch_rename_dialog.dart` | 457, 573, 710 | 3 |
| `lib/widgets/batch_rename_rule_editor.dart` | 518 | 1 |
| `lib/widgets/file_manager_view.dart` | 578, 725, 1054, 1160, 1259, 1529 | 6 |
| `lib/widgets/math_canvas_3d.dart` | 4851 | 1 |
| `lib/widgets/math_keyboard.dart` | 161, 217 | 2 |
| `lib/widgets/topic_item.dart` | 205 | 1 |
| **Total PopupMenuButton** |  | **32** |

### Programmatic popup menus

| Source file | Callsite lines | Count |
|---|---:|---:|
| `lib/pages/mermaid_chart_page.dart` | 312 | 1 |
| **Total showMenu** |  | **1** |

### Dropdown buttons and form fields

| Source file | Callsite lines | Count |
|---|---:|---:|
| `lib/pages/anki_page.dart` | 250 | 1 |
| `lib/pages/asr_model_config_page.dart` | 535, 705, 819 | 3 |
| `lib/pages/asr_page.dart` | 693 | 1 |
| `lib/pages/assistant_selection_page_add_custom_param.dart` | 59 | 1 |
| `lib/pages/assistant_selection_page_edit_custom_param.dart` | 70 | 1 |
| `lib/pages/llm_account_management_page.dart` | 2531, 2689, 2739, 3230, 3250, 3271, 3286, 4458, 4581, 4604, 4623, 4721, 4736, 4797, 4852 | 15 |
| `lib/pages/llm_model_config_page_reasoning_builders.dart` | 431 | 1 |
| `lib/pages/llm_model_config_page_sections.dart` | 196, 412 | 2 |
| `lib/pages/model_config_page.dart` | 1183 | 1 |
| `lib/pages/ocr_model_config_page.dart` | 731 | 1 |
| `lib/pages/ocr_page.dart` | 951, 1100 | 2 |
| `lib/pages/provider_settings_panel_custom_params.dart` | 241 | 1 |
| `lib/pages/provider_settings_panel_reasoning.dart` | 638 | 1 |
| `lib/pages/provider_settings_panel_tab_asr.dart` | 45, 138 | 2 |
| `lib/pages/provider_settings_panel_tab_basic.dart` | 56, 205, 344, 443 | 4 |
| `lib/pages/simple_model_config_page.dart` | 276 | 1 |
| `lib/pages/text_storage_shared.dart` | 123 | 1 |
| `lib/pages/tts_create_page.dart` | 574, 1045 | 2 |
| `lib/pages/voice_batch_add_page.dart` | 354 | 1 |
| `lib/task_flow/widgets/block_chain_editor.dart` | 231 | 1 |
| `lib/task_flow/widgets/block_editor_dialog.dart` | 509, 677 | 2 |
| `lib/widgets/batch_rename_dialog.dart` | 691, 756 | 2 |
| `lib/widgets/file_manager_view.dart` | 2990 | 1 |
| `lib/widgets/math_3d_toolbar.dart` | 229 | 1 |
| **Total DropdownButton / DropdownButtonFormField** |  | **49** |

## Custom overlay and reviewed exclusions

- `lib/pages/llm_model_config_shared.dart:135` creates the `LabeledTextField` suggestion list overlay at line 191. It now shares the theme surface, border, and 16 dp corner radius, with rounded interactive rows. This is the only menu-like app-authored overlay found outside Flutter menu APIs.
- `lib/widgets/drag_sort_area.dart:329` creates a release-animation overlay for drag feedback. It has no menu or selectable list and is outside this styling pass.
- Source search found no app-owned `DropdownMenu`, `MenuAnchor`, `Autocomplete`, or `RawAutocomplete` callsites.
- Search sheets, media/action sheets, and dialogs opened with `showModalBottomSheet` / `showDialog` were reviewed separately. They are structured sheets/dialogs with their own actions, search, or content rather than popup/dropdown menus. Existing picker sheets keep their placement and sheet-specific design.
- External math UI is excluded because it is owned by the external math component; no math-owned source was changed or rendered.

## Render captures

Actual widget-test renders are saved (the Files, task-list, and OCR frames use 1280 × 800; the taller model-settings screen uses 800 × 1400) outside the repository at `/tmp/stroom-popup-overlay-renders/`: `files-popup.png`, `task-list-menu.png`, `ocr-model-dropdown.png`, and `model-suggestions.png`. `contact-sheet.png` shows all four families side by side. The focused short-viewport suggestion test also checks that its list remains inside the viewport. The container test renderer lacks the app locale fonts, so its glyphs appear as fallback boxes; the frames still show actual Stroom screens, menu placement, surfaces, and row spacing.
