# Audio separation selected-video count row

The captures use the production `AudioSeparationPage` with one local retry video in French, rendered in Chromium at a 320 × 640 CSS viewport and device pixel ratio 1.

- [Normal text scale, 1×](french-320x640-scale1.png): `1 vidéo sélectionnée` is fully visible beside the video icon and remains stationary.
- [Normal-scale page clip](french-320x640-scale1-preview.webm): a short playable capture of the same fitting 1× state; the label stays still.
- [Enlarged text reveal, 2.5×](french-320x640-scale2_5-preview.webm): the count moves inside its footer slot when its natural width exceeds the available space. The clip includes the reveal at both endpoints; the icon and footer bounds remain fixed.

The preview uses a local fixture only and makes no provider requests. The enlarged-scale clip is supplementary; the primary acceptance state is the normal 1× capture.
