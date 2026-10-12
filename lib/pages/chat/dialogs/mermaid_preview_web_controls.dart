import 'package:flutter/widgets.dart';
import 'mermaid_preview_web_controls_stub.dart'
    if (dart.library.html) 'mermaid_preview_web_controls_web.dart' as platform;

Widget buildMermaidPreviewWebControls({
  Key? key,
  required VoidCallback onZoomOut,
  required VoidCallback onZoomIn,
  required VoidCallback onClose,
  required Color backgroundColor,
  required Color foregroundColor,
}) =>
    platform.buildMermaidPreviewWebControls(
      key: key,
      onZoomOut: onZoomOut,
      onZoomIn: onZoomIn,
      onClose: onClose,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
