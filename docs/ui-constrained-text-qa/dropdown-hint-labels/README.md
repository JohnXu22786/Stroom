# Dropdown hint label captures

These captures use the real OCR page and Task Flow block editor at `HEAD` `baab36dd90f4302123bbef2fc953f3e28b0c1f1b` (before) and the candidate build (after). The Task Flow editor displays both stale model and voice selection hints in the same French TTS block.

## Capture conditions

- Browser viewport: 360 × 800 CSS pixels; device scale factor: 2 (source screenshots are 720 × 1600).
- Text scale: 2× through the QA app's `MediaQuery`.
- Theme: light; browser reduced-motion preference: no preference (`false`).
- OCR locale/state: de-DE; `OcrPage` retry state with legacy model id `legacy-model`, version 999, and no selected model.
- Task Flow locale/state: fr-FR; open TTS block editor with deleted model and voice references.
- Before images came from a static web build compiled with the production files at the required base commit. After images came from the candidate static web build. Full source captures are retained in `before/` and `after/`.

## Comparisons

Each comparison keeps the full control row and shows the baseline plus the leading and terminal portions of the after-state label. The animated strings are longer than their one-line slots, so head and tail panels together show the full localized value.

- [OCR model hint comparison](comparisons/ocr_model_hint.png): baseline `Der ursprüng…`; after head `Der ursprüng…`; tail `…res Modell.` at 45 seconds after canvas render.
- [Task Flow model hint comparison](comparisons/task_flow_model_hint.png): baseline wraps and clips; after head `Aucun modèle n’est sé…`; tail `…un autre modèle.` at 35 seconds after canvas render.
- [Task Flow voice hint comparison](comparisons/task_flow_voice_hint.png): baseline wraps and clips; after head `La voix n’est pas dispo…`; tail `…une autre voix.` at 18 seconds after canvas render.

## Playable motion preview

[selection_hints_motion_preview.webm](video/selection_hints_motion_preview.webm) combines 11.1 seconds of the real OCR page (`de-DE`) and 12.6 seconds of the real Task Flow dialog (`fr-FR`). It is 360 × 800 at 7 fps, captured at device scale 2 with reduced motion disabled. The overlay labels the two segments. The preview shows live movement; the terminal captures above and endpoint regression tests establish that the final glyphs stay inside each clipping viewport.

## Full source captures

- Before: `before/ocr_full.png`, `before/task_flow_full.png`.
- After head: `after/ocr_head_full.png`, `after/task_flow_head_full.png`.
- After terminal: `after/ocr_tail_full.png`, `after/task_flow_model_tail_full.png`, `after/task_flow_voice_tail_full.png`.
- Cropped control rows used in the composites are retained in `crops/`.
