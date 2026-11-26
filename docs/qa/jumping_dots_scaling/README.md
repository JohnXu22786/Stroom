# Jumping dots text scaling capture

The screenshots and motion preview use the production
`JumpingDotsProgressIndicator` widget with the same 14 px font size and vertical
padding used by the chat waiting state. A local Flutter Web fixture displays it
at 1× and 2× text scale together. It uses no account data, provider request, or
network-backed content.

- [Production component screenshot at 1× and 2×](jumping-dots-1x-and-2x.png)
- [Playable bounce preview at 1× and 2×](jumping-dots-motion.webm)

The capture uses a 360 × 280 CSS pixel viewport, DPR 1, and the light Material
theme. Recreate it with `python3 tool/qa/capture_jumping_dots_scaling.py`.
