# Scaled voice batch separator

The screenshots capture the production `VoiceBatchAddPage` in Flutter Web in
German (`de_DE`) with the light Material 3 theme and no focused control. The
first screenshot is the parse settings card at 500 × 640 CSS pixels, device
scale 1, and 2.5× text scale. Its separator label and dropdown stack so the
full selected value fits the available width. The second screenshot is the
same card at 700 × 640 CSS pixels, device scale 1, and 1× text scale; the
fitting selector remains inline. The screenshot crops show only the parse
settings card. No provider or synthesis calls are made.

- [Scaled stacked state](separator-de-500x640-scale2_5-light.png)
- [Fitting inline baseline](separator-de-700x640-scale1-light.png)

Reproduce the captures with Flutter Web release mode. Build first, run the
server in one terminal, then run the capture script in another:

```sh
flutter build web --no-pub --release --target tool/qa/voice_batch_separator_capture.dart --output build/scaled-voice-batch-separator
python3 -m http.server 8876 --bind 127.0.0.1 --directory build/scaled-voice-batch-separator
python3 tool/qa/scaled_voice_batch_separator_capture.py
```

The scaled selected label fits without motion in the captured stacked state,
so the capture has no time-dependent preview. The focused widget regression
test also verifies the complete selected value and card bounds at 500 × 640
and 2.5× text scale; the existing wide-state test verifies the inline
alignment at normal scale.
