# Assistant defaults preview labels

## Change

The effect-preview rows pair a translated label with a right-aligned value. The label now uses `ConstrainedText` in a width measured against its natural rendered size, locale, direction and text scale. Fitting labels keep their original width and alignment; only a label that would leave less than 80 logical pixels for the value is clipped and revealed by the shared marquee. The value column remains right-aligned and naturally wraps.

## Rendered captures

The two screen captures show the production `AssistantDefaultsTab` in Chromium, captured through a temporary Flutter Web entrypoint that was removed after capture:

- `assistant-defaults-de-320x640-scale1_2-light.png`: de-DE, 320 × 640 CSS px, 1.2× text scale, light theme, scrolled to truncation controls and the effect preview. Both `Modell` and `Werkzeuge` fit in the label slots and remain stationary; the values preserve their right alignment. No browser console errors were reported.
- `assistant-defaults-en-393x844-scale1-dark.png`: English, 393 × 844 CSS px, 1× text scale, dark theme, scrolled through the tools list, truncation controls and effect preview. Both labels fit without motion. No browser console errors were reported.

`assistant-labels-overflow-and-fit.png` isolates the shared `ConstrainedText` in a row matching the effect-preview structure. Its narrow `Werkzeuge` slot scrolls while the adjacent value remains in place; the wider `Modell` label stays stationary. `assistant-label-marquee.webm` is an 8.2-second browser capture of the delayed horizontal reveal and endpoint pause. This focused component render uses the same widget and behavior as the production call site.

The layout takes a measured-width path so normal German and English labels remain visually unchanged. The component's existing widget tests cover initial delay, endpoint pause, fitting text, vertical reveal, reduced motion, and semantics; the assistant-page test now checks that the two preview labels are wired through `ConstrainedText`.
