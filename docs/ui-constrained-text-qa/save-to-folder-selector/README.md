# Save-to folder selector

The ASR, OCR, TTS, and audio-separation save-to rows use the production `SaveToFolderSelector` widget. It bounds the localized action label and selected folder beside the fixed folder and chevron icons. Both text slots use `ConstrainedText`; strings that fit stay still, while clipped values reveal their complete text. The existing picker callbacks and OCR disabled state stay at their page call sites.

## Visual checks

- `save-to-de-320x640-scale1-light.png`: production widget in de-DE, Chromium release build, 320×640 CSS pixels at device scale 1, light theme, with a long selected path.
- `save-to-ar-320x640-scale1_7-dark.png`: production widget in Arabic at 1.7× text scale, dark theme, 320×640 CSS pixels at device scale 1.
- `save-to-de-path-marquee.webm`: recorded de-DE light-theme motion of the long selected path in the same 320×640 viewport.
- `audio-separation-de-320x640-scale1-light.png`: production audio-separation page in de-DE at 320×640 CSS pixels and device scale 1, showing the shared selector with the root folder selected.

The selector screenshots and motion capture were rendered from `lib/widgets/save_to_folder_selector.dart` with the localized OCR save-to label and a long folder value. The audio-separation screenshot shows the production page with its root-folder default. Temporary QA entry points are not part of the application.

Widget coverage: fitting text remains stationary; long text retains full semantics and the selector remains tappable; German, Brazilian Portuguese, and Arabic labels lay out at 1.7× in light and dark themes. Audio-separation page coverage checks the production selector and that tapping it opens the existing folder picker.
