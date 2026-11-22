# Backup and Restore bounded title QA

The screenshots and video show the production `BackupRestorePage` at a narrow viewport. The title rows keep their icon, original style and full localized label; the constrained label moves only when the text scale makes it wider than the available slot.

| Condition | Value |
|---|---|
| Viewport | 320 × 640 CSS px, device scale factor 1 |
| Locale | German (`de`) |
| Text scale | 1.0× and 1.7× |
| Theme | Material 3 light |
| State | Backup and Restore page, scrolled to the clear-selected card |
| Renderer | Flutter 3.47.9 / Dart 3.13.7, Chromium headless |

- `clear-card_320x640_de_scale1.png` shows the clear-selected card at the default text scale.
- `clear-card_320x640_de_scale1.7_light.png` shows the title clipped to its finite row at 1.7× scale.
- `motion_preview.webm` is an 8-second 320 × 640 capture of the same page. It shows the German card title moving inside its row while the leading delete icon stays fixed.

The widget regression is in `tests/pages/backup_restore_constrained_text_test.dart`. It covers the clear card and restart alert at 320 × 640 / 1.7×, plus the existing 320/360 matrix for German and pt-BR in light and dark themes.
