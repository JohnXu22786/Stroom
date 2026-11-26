# Scaled voice batch separator

The screenshots capture the production `VoiceBatchAddPage` in Flutter Web in
German (`de_DE`) with the light Material 3 theme and no focused control. The
first screenshot is the parse settings card at 500 × 640 CSS pixels, device
scale 1, and 2.5× text scale. Its separator label and dropdown stack so the
full selected value fits the available width. At 320 × 640 and 2.5×, the
selected value exceeds the dropdown slot and uses the existing `ConstrainedText`
reveal. The fitting baseline is captured at 700 × 640 and 1× text scale; its
selector remains inline. Screenshot and preview crops show only the parse
settings card. No provider or synthesis calls are made.

- [Scaled stacked state](separator-de-500x640-scale2_5-light.png)
- [Clipped selected label](separator-de-320x640-scale2_5-light.png)
- [Play the real-time clipped-label reveal](separator-de-320x640-scale2_5-reveal.webm) — 9 seconds at 10 fps, without speed adjustment.
- [Fitting inline baseline](separator-de-700x640-scale1-light.png)

Reproduce the captures with Flutter Web release mode. Build first, run the
server in one terminal, then run the capture script in another:

```sh
flutter build web --no-pub --release --target tool/qa/voice_batch_separator_capture.dart --output build/scaled-voice-batch-separator
python3 -m http.server 8876 --bind 127.0.0.1 --directory build/scaled-voice-batch-separator
python3 tool/qa/scaled_voice_batch_separator_capture.py
```

The focused widget regression tests verify that the scaled wide-card row
reflows without overflow, the clipped value keeps its full semantic label at
320 × 640 / 2.5×, and the fitting 700px state keeps its inline alignment.
