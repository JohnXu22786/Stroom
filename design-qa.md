# Assistant panel redesign — design QA

- **Selected direction:** generated design option 3.
- **Implementation:** `lib/pages/assistant/built_in_prompt_selector.dart`, using the real selector widget and existing import flow.
- **Reference comparison:** [selected option 3 beside the rendered implementation](docs/images/assistant-market-option3-qa.png). The reference is scaled to 393 × 630 for comparison; the implementation capture is a real Flutter Web rendering at 393 × 630.
- **States checked:** Built-in tab, Import tab, existing remote catalog/file dialog opened from Import, dark theme, and 320 × 640 narrow viewport.
- **Interactions checked:** switching source tabs, back arrow returning from Import to Built-in, and Import action opening the existing remote source dialog. Flutter widget tests cover existing info/detail/add behavior and dismissal.
- **Visual findings:** the Built-in and Import choices read as peer actions; list rows retain name, description, info, and Add affordances at narrow widths; typography and surfaces follow the active Material color scheme in both light and dark themes. The representative capture shows only the panel content.
- **Runtime:** no browser page errors during captures. Existing WebAssembly dry-run warning about `get_thumbnail_video` using `dart:html` is unrelated to this change.
- **Result:** passed for the checked states.


## Assistant edit dialog — parameter heading

- **Surface and method:** the real `showAssistantFullEditDialog` and `_buildEditParamsTab` rendered in Chromium from the audit entrypoint; system fonts loaded from the Flutter web build. The temporary entrypoint and initial-tab selector were removed after capture.
- **Before:** at 320 × 640 CSS px, de-DE, 1.8× text scale, light theme, the `Benutzerdefinierte Parameter` heading overran its finite `Row` by 8.3 px beside the add action. The capture shows Flutter’s red overflow marker.
- **After:** the same dialog data, locale, viewport, scale, theme and scroll position. The heading gets all remaining row width after a fixed 8 px gap, stays on one line at 15 px / 600 weight, and uses the shared `ConstrainedText` horizontal reveal only when needed; the add action remains at the trailing edge and semantics retain the full translated label. No translation, font size, or editable field changed.
- **Other tab content checked:** the long assistant override helper and enabled SwitchListTile labels remained readable; seed label/value fields were not clipped; long custom parameter name and value wrapped naturally. pt-BR dark theme wrapped `Pesquisa na web`; Arabic dark theme used RTL alignment and kept the controls visible. The change does not touch an editable value field, so keyboard/caret behavior is unchanged.
- **Motion:** the component waits 1 s before moving at 24 logical px/s and holds 2 s at each endpoint before reversing. The 16.12 s WebM spans a full prefix-to-suffix reveal and the trailing-end hold. Start endpoint is offset 0 (leading text); end endpoint is offset −overflow (trailing text).

| Before, de-DE light | After, de-DE light — leading endpoint |
|---|---|
| ![Before: 8.3 px overflow at 320 × 640 and 1.8×](docs/images/assistant-param-before.png) | ![After: constrained heading at the leading endpoint](docs/images/assistant-param-after.png) |

The after tail endpoint is saved separately at [assistant-param-after-endpoint.png](docs/images/assistant-param-after-endpoint.png). Additional Chromium captures: [English at 1×](docs/images/assistant-param-after-en-1x.png), [pt-BR dark](docs/images/assistant-param-after-pt-dark.png) and [Arabic dark / RTL](docs/images/assistant-param-after-ar-dark.png). The shorter English label uses the same reveal at the narrow size; no locale branch was added. [Play the 16.12 s heading reveal preview](docs/videos/assistant-param-heading-motion.webm).
