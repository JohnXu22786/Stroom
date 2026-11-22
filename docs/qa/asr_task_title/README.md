# ASR task title display

This capture shows the production `BackgroundTaskCard` with a task title derived from the safe synthetic source URL `https://media.example.test/recordings/recording-session-2026-11-22-interview-take-two-final-transcript.wav`. It uses Flutter Web Release, Chromium at 320 × 640 CSS pixels, device scale factor 1, English (United States), light Material 3, and 1× text scale. The screenshot uses reduced motion; focus is on no control and the keyboard is closed. The title remains at its original typography and alignment, and the compact card reveals the full task name through its existing constrained label behavior.

- [Production UI screenshot](asr-task-title-320x640-1x.png)
- [Playable title reveal](asr-task-title-motion-320x640-1x.webm)
- [Capture entrypoint](../../../tool/qa/asr_task_title_capture.dart)
- [Capture script](../../../tool/qa/capture_asr_task_title.py)

The capture is local fixture data only and makes no provider request. Chromium reported no page errors.
