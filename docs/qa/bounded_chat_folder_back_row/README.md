# Chat picker folder back rows

Both production chat pickers bound the localized parent-folder label and current-folder basename to separate row slots. Short names remain stationary, with the parent label at the leading edge and the current name at the trailing edge. Long names reveal their full value inside those slots after the shared delayed motion start. The back icon, folder navigation, existing 15 px/13 px label sizes, and full semantics remain intact. The selected-file/image count heading keeps its existing 11 px style and leading alignment in a one-line finite slot.

## Captures

- [File picker, fitting names, 320 × 640, 1×](file-fitting-320x640-1x.png)
- [File picker, long names, 320 × 640, 1×](file-long-320x640-1x.png)
- [Album picker, fitting names, 320 × 640, 1×](album-fitting-320x640-1x.png)
- [Album picker, long names, 320 × 640, 1×](album-long-320x640-1x.png)
- [Playable file-picker back-row reveal](back-row-motion-320x640-1x.webm)

The screenshots show the actual `showAppFilePickerDialog` and `showAppAlbumPickerDialog` production routes in Chromium, Flutter 3.47.9 / Dart 3.13.7, English, light theme, device scale factor 1, and normal text scale. A temporary entrypoint seeded short and long folder paths; it was removed after capture. The motion preview records the actual file picker at the same viewport and includes the delayed bidirectional reveal. Chromium reported no console or page errors during the captures. The widget regressions use Arabic locale to verify the trailing label stays at the physical left edge in RTL layout.

Targeted widget regressions run each real dialog at 320 × 640, open a nested folder with long path segments, verify the current-folder label remains aligned to the row's trailing content edge, and navigate up without a layout exception.
