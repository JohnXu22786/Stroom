import 'package:flutter/material.dart';

/// Shared surfaces for Stroom-owned popup menus and dropdown menus.
abstract final class StroomMenuStyle {
  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(16),
  );

  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  static PopupMenuThemeData popupMenu(ColorScheme colorScheme) {
    return PopupMenuThemeData(
      color: colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
    );
  }

  static MenuStyle dropdownMenu(ColorScheme colorScheme) {
    return MenuStyle(
      backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
      ),
      elevation: const WidgetStatePropertyAll(8),
    );
  }
}
