# Assistant card text-scale check

These artifacts capture the production `AssistantSelectionPage` at 320×640 in
French. The 1× image is the fitting-text comparison; the 2× image shows the
larger-text card and its preserved menu control.

The 73-second GIF plays the real `ConstrainedText` reveal cycle from the
production page. It shows the 2× starting layout, the one-second initial still
period, the full description at its far endpoint, both two-second endpoint
holds, and its return to the starting text. The fitting 1× comparison follows
the animation. The timeline was measured in the widget capture test: the far
endpoint is reached at 33 seconds, return starts at 36 seconds, the start
endpoint is reached at 67 seconds, and the next cycle begins at 70 seconds.

`assistant_card_scaled_grid_capture_test.dart` regenerates the 1× and 2×
captures and the selected production frames. The GIF combines per-second
frames captured from that same widget-test timeline.
