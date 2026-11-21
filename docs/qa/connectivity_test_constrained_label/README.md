# Connectivity test JSON field label

The capture entrypoint [`tool/qa/connectivity_test_dialog_capture.dart`](../../../tool/qa/connectivity_test_dialog_capture.dart) opens the production `ConnectivityTestDialog` with local-only callbacks at a 320 × 640 logical viewport and 1× device scale. It uses the German locale and the app's blue-seeded Material 3 light theme. No save or connection action is invoked.

- [Normal-scale focused screenshot](connectivity-test-de-320x640-1x-light-focused.png): the localized `Testinhalt (JSON)` label fits and remains stationary. The field is focused; headless Chromium does not display a software keyboard.
- [Play the clipped-label preview](connectivity-test-de-json-label-2_2x-320x640-light-preview.webm): 2.2× text scale clips the localized label in the real field slot and shows its reveal motion. The JSON remains native editable text. The larger scale also constrains the dialog title and action labels.

The sample JSON contains a reserved `.invalid` endpoint and is never submitted. The preview callback returns a local result without making a network request.
