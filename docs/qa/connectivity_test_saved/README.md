# Connectivity test saved status

`ConnectivityTestDialog` is opened from both provider configuration and built-in tool details. Its saved state previously placed the localized confirmation beside a fixed icon in a `Row` without giving the text a finite width. In a de-DE widget test at 320 × 640 and 1.8× text scale, the row caused a 364 px horizontal `RenderFlex` overflow. The label now receives the remaining row width through `Expanded` and uses the shared `ConstrainedText`; its complete localized value, original primary color, icon, and leading alignment are preserved.

The [production dialog capture](german-saved-320x640-dpr1-text1_8.png) is 320 × 640 CSS pixels at device-pixel ratio 1, with de-DE, light theme, and 1.8× text scale. The dialog content is scrolled to show the saved state. The [playable reveal](german-saved-status-reveal.webm) shows the same production component and the full saved label moving inside its finite slot. The local fixture's save callback completes without a provider/network request; Chromium reported no page errors.

`tests/widgets/connectivity_test_dialog_test.dart` measures the long German string against its actual slot, checks the icon and absence of layout exceptions, and confirms that a fitting English label has enough room in dark theme. Existing dialog tests continue to cover JSON editing, save/run state, and returned response content.
