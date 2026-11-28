# Round 13 fixed label controls

Production widgets rendered by `tests/qa/round13_fixed_label_controls_test.dart`.

| Component | Viewport | Locale | Text scale | Theme | Status | Capture |
|---|---:|---|---:|---|---|---|
| Gallery actions | 320 × 640 logical px, DPR 1 | de-DE | 1× | light | Pass; buttons remain 48 dp high | [PNG](gallery-de-320x640-scale1-light.png) |
| Gallery actions | 320 × 640 logical px, DPR 1 | de-DE | 2.5× | light | Pass; buttons grow for the scaled label line | [PNG](gallery-de-320x640-scale2_5-light.png) |
| Task Flow Add Block | 320 × 640 logical px, DPR 1 | de-DE | 1× | light | Pass; button remains 44 dp high | [PNG](task-flow-de-320x640-scale1-light.png) |
| Task Flow initial input header, before reflow | 320 × 640 logical px, DPR 1 | de-DE | 2.5× | light | Reproduced; heading collapsed to one character per line beside the dropdown | [PNG](task-flow-header-before-de-320x640-scale2_5-light.png) |
| Task Flow initial input header, after reflow | 320 × 640 logical px, DPR 1 | de-DE | 2.5× | light | Pass; readable wrapped heading and operable dropdown are on separate rows | [PNG](task-flow-de-320x640-scale2_5-light.png) |
| Task Flow initial input header, dark theme | 320 × 640 logical px, DPR 1 | de-DE | 2.5× | dark | Pass; same readable reflow with dark Material surfaces | [PNG](task-flow-de-320x640-scale2_5-dark.png) |
| Task Flow initial input header, measured fit boundary | 820 × 640 logical px, DPR 1 | de-DE | 2.5× | light | Pass; dropdown remains beside the full label when the measured contents fit | [PNG](task-flow-fit-de-820x640-scale2_5-light.png) |
| Task Flow initial input header, RTL reflow | 320 × 640 logical px, DPR 1 | de-DE strings with RTL direction | 2.5× | light | Pass; dropdown stays at the direction-aware trailing edge | [PNG](task-flow-rtl-de-320x640-scale2_5-light.png) |
| Task Flow Add Block | 320 × 640 logical px, DPR 1 | de-DE | 2.5× | light | Pass; button grows for the scaled label line | [PNG](task-flow-de-320x640-scale2_5-light.png) |
| Tutorial step badges | 320 × 640 logical px, DPR 1 | de-DE | 1× | light | Pass; badges remain 32 × 32 dp | [PNG](tutorial-de-320x640-scale1-light.png) |
| Tutorial step badges | 320 × 640 logical px, DPR 1 | de-DE | 2.5× | light | Pass; circular badges grow with the numeral | [PNG](tutorial-de-320x640-scale2_5-light.png) |

These are Flutter rendered screenshots of the production pages/components in isolated, in-memory fixtures. The capture test loads the Flutter SDK's Roboto and Material Icons fonts, so these are not Ahem/fallback text captures. The Task Flow dropdown uses the theme body font family for its selected value, keeping that value legible in the production-font captures. Gallery providers return empty records and folders; the Task Flow editor has no blocks. The before image preserves the original header layout, regenerated with the same visible selected value; the after image comes from the focused regression test. The Task Flow regression also opens the input dropdown and selects Audio to verify its callback. No account data, persistence, camera, file picker, or network request is used.

At 2.5×, the gallery and Add Block labels retain their one-line ConstrainedText treatment and scroll horizontally when their text exceeds the button's available width. The screenshots capture the stationary start state; widget assertions also verify that the complete German labels remain exposed to accessibility semantics.
