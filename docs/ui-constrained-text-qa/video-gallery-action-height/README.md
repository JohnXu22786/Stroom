# Video gallery top actions

These captures show the production `VideoGalleryPage` using an empty in-memory fixture. No account data, video file, camera, gallery picker, or network request is used. Locale is en-US, theme is light, no control is focused, and the software keyboard is closed. The viewport is 320 × 640 logical pixels at device pixel ratio 1.

- [Normal text scale (1×)](video-gallery-actions-en-us-320x640-scale1-light.png): the two top actions retain their standard 48 dp minimum height.
- [Large text scale (2.5×)](video-gallery-actions-en-us-320x640-scale2_5-light.png): both action buttons expand vertically to fit the larger labels. The labels remain at their existing 15 dp base style and continue using the shared constrained-label reveal when width clips them.

The screenshots were captured from the Flutter web build with Chromium. The focused widget test also checks both action buttons at 320 × 640 for 1× and 2.5× text scaling.
