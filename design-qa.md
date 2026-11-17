# Assistant panel redesign — design QA

- **Selected direction:** generated design option 3.
- **Implementation:** `lib/pages/assistant/built_in_prompt_selector.dart`, using the real selector widget and existing import flow.
- **Reference comparison:** [selected option 3 beside the rendered implementation](docs/images/assistant-market-option3-qa.png). The reference is scaled to 393 × 630 for comparison; the implementation capture is a real Flutter Web rendering at 393 × 630.
- **States checked:** Built-in tab, Import tab, existing remote catalog/file dialog opened from Import, dark theme, and 320 × 640 narrow viewport.
- **Interactions checked:** switching source tabs, back arrow returning from Import to Built-in, and Import action opening the existing remote source dialog. Flutter widget tests cover existing info/detail/add behavior and dismissal.
- **Visual findings:** the Built-in and Import choices read as peer actions; list rows retain name, description, info, and Add affordances at narrow widths; typography and surfaces follow the active Material color scheme in both light and dark themes. The representative capture shows only the panel content.
- **Runtime:** no browser page errors during captures. Existing WebAssembly dry-run warning about `get_thumbnail_video` using `dart:html` is unrelated to this change.
- **Result:** passed for the checked states.
