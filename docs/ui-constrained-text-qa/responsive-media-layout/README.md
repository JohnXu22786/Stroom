# Responsive media layout captures

These screenshots render the production multi-select media picker and the
production streaming Mermaid code-block builder. They use local fixtures only;
no account data or network requests are involved.

All captures use a 320 × 640 CSS px viewport, DPR 1, French (France), and the
light Material 3 theme. Each component has a fitting 1× text-scale control and
an affected 3× text-scale capture:

- [Media picker preview bar at 1×](media-picker-fr-320x640-scale1-light.png)
- [Media picker preview bar at 3×](media-picker-fr-320x640-scale3-light.png)
- [Playable 3× selected-chip filename reveal](media-picker-fr-320x640-scale3-reveal.webm)
- [Mermaid loading card at 1×](mermaid-loading-fr-320x640-scale1-light.png)
- [Mermaid loading card at 3×](mermaid-loading-fr-320x640-scale3-light.png)

The picker fixture starts at 1× so the local file can be selected, then applies
3× text scaling to the open production dialog. The static 3× screenshot uses
reduced motion to show stable ellipsis. The selected chip uses the existing
vertically scrolling `ConstrainedText` behavior to reveal its full filename;
the 32-second preview starts while the selected dialog still fits at 1×, then
captures the stationary first second after the labels become clipped at 3×. It
covers the complete reveal, endpoint pause, and reverse pass for the filename,
title, and clear action. The Mermaid fixture places the production loading card
between adjacent Markdown-like content so its expanded height remains visible in
context. Its wrapped status is static, so there is no Mermaid motion preview.

At 3× the clear-selection AppBar action uses a finite responsive slot and
reveals its complete label while staying inside the viewport. The 1× layout
retains the original action bounds. The title and clear action also reveal
within their AppBar bounds in the 3× motion preview.

Regenerate all captures with:

```sh
python3 tools/qa/capture_responsive_media_layout.py
```
