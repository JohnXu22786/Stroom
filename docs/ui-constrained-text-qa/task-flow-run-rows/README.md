# Task-flow run rows QA

These captures show the production `TaskFlowBuilderPage` in run mode at 320 × 640 CSS px, device scale factor 1, de-DE, light theme, and 1× text scale. A long flow name exercises the bounded overview row and app-bar title. The selected input is a CatCatch URL with its editable duration fields and live preview visible.

## Captures

- [Long flow name in the run UI](task-flow-run-long-title-de-320x640-scale1-light.png)
- [Flow-name reveal motion](task-flow-run-long-title-motion-320x640-scale1.webm)

The motion preview is an 8-second Chromium recording showing the shared `ConstrainedText` reveal in the app bar and overview row. It retains the full label as its semantic value. The input description continues to wrap naturally, and the URL and duration fields remain editable.

## Verification

`tests/task_flow/pages/task_flow_builder_page_constrained_run_rows_test.dart` checks the long German-scale run rows at 320 × 640 and 1.6× text scale without layout exceptions, confirms both full flow-name semantics, changes the duration field and verifies the live preview, and confirms a fitting flow name stays stationary.
