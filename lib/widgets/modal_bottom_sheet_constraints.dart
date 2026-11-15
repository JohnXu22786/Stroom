import 'package:flutter/material.dart';

/// Returns width constraints for modal bottom sheets on wide viewports.
///
/// Compact viewports keep Flutter's existing bottom-sheet width behavior.
BoxConstraints? modalBottomSheetWidthConstraints(BuildContext context) {
  final availableWidth = MediaQuery.sizeOf(context).width;
  if (availableWidth < 600) return null;

  final gutterBound = availableWidth - 48.0;
  final maxWidth = gutterBound < 640.0 ? gutterBound : 640.0;
  return BoxConstraints(maxWidth: maxWidth);
}
