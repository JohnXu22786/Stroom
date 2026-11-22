# Math keyboard active labels

The screenshot shows the production `MathKeyboard` at 320 × 640 CSS pixels, device pixel ratio 1, Simplified Chinese (`zh-CN`), Material 3 light theme, and normal 1× text scale. A local math-expression fixture supplies long active-formula and nested-location values to its combined header label, showing the clipped state. No field is focused, the software keyboard is closed, and no account data or network request is used.

- [320 × 640 screenshot](math-keyboard-zh-cn-320x640-scale1-light.png)
- [Playable clipped-label preview](math-keyboard-label-reveal-320x640.webm)

The screenshot honors reduced motion and records the initial clipped state. The preview uses normal motion and shows the active label revealing within the existing header while the undo, redo, menu, and dismiss controls remain in place.

Capture with:

```sh
flutter build web --release --no-pub --target tool/qa/math_keyboard_capture.dart --output /tmp/math-keyboard-web --no-wasm-dry-run
python3 -m http.server 8878 --directory /tmp/math-keyboard-web
python3 tool/qa/capture_math_keyboard.py
```
