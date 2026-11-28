# Vertical topic metadata at narrow width

The production `TopicItem` keeps the date, message count, and topic actions visible at a 320 dp viewport. Its date moves only when the available metadata slot clips it; the title and adjacent actions keep their existing style and behavior.

- [Production screenshot at 320 × 640, 1×](topic-metadata-fr-320x640-1x-light.png)
- [Playable date reveal preview, 2× text scale](topic-metadata-reveal-fr-320x640-2x-light.webm)

The Flutter Web captures use the production `TopicItem` in a local fixture at 320 × 640 CSS pixels, device pixel ratio 1, French (`fr_FR`), and light theme. The screenshot uses 1× text scale and shows the normal topic row with its message count and pin/overflow actions. The motion preview uses 2× text scale to show the date reveal in its clipped slot. The topic and its one message are synthetic local data; no account data or network services are used.

Recreate the captures with:

```sh
flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 8878 --target tool/qa/vertical_topic_metadata_bounds_capture.dart
python3 tool/qa/vertical_topic_metadata_bounds_capture.py
```
