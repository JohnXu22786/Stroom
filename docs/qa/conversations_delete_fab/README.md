# Conversations delete FAB QA

The captures use the production `ConversationsPage` in a Flutter Web release
build with Chromium's normal Flutter fonts. The fixture supplies 123
in-memory conversations, enables selection through the page's checklist action,
and selects each row through the UI.
The page shows `123 selected` / `123 sélectionné` in the screenshots. Flutter
Web virtualizes the list and does not expose each checkbox's checked value in
its row semantics, so the harness tracks 123 distinct row clicks and OCR-checks
the rendered numeric count in the app bar before accepting each screenshot.

The static captures cover fitting English at 800×640, text scale 1, and cramped
French at 320×640, text scale 3. The French capture shows all 123 conversations
selected, the visible delete icon, the clipped `Supprimer 123` label, and the
complete FAB within the viewport. Its measured red FAB bounds are x=16..303 and
y=568..623 CSS pixels. The English button is also fully visible. Chromium
reported no page errors.

The 36-second WebM shows a 288×56 crop of the French production FAB at two
frames per second. It includes the initial pause and the clipped FAB label's
reveal and return, with the icon and complete button bounds in every frame.
The static screenshots are captured before recording. To avoid the bottom FAB
covering unselected rows while building the 123-item fixture, the script
temporarily expands the viewport height, then restores 320×640 before capture.

Regenerate the screenshots and motion preview from the repository root with:

```sh
python3 tool/qa/capture_conversations_delete_fab.py
```

The script starts `flutter run --release --no-pub -d web-server`, drives the
production page with Playwright and system Chromium, checks that the red FAB
pixels remain inside each screenshot, checks the selected count with Tesseract
OCR, and encodes the motion preview with FFmpeg. It writes the two PNGs and WebM
in this directory. The in-memory app fixture is in
`tool/qa/conversations_delete_fab_capture.dart`.

The sub-100dp widget case checks only that the label width budget remains a
normalized nonnegative constraint. Its physical scaffold remains 320dp wide so
the test does not imply that the whole ConversationsPage supports an 80dp
viewport. A separate production-page widget test checks the complete FAB bounds
at a 240dp viewport, the smallest width tested with the ConversationsPage shell.
