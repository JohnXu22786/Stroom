import 'package:flutter/material.dart';
import 'package:stroom/widgets/markdown_extensions.dart';
import 'package:markdown_widget/markdown_widget.dart';

const _markdown = '''
9999. The preceding item keeps its complete ordered marker.
10000. This item shows that a five-digit marker gets enough room while this body wraps naturally across the available width.

1. Parent item
   7. Nested item keeps its ordered marker and readable text.
''';

void main() {
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  runApp(_MarkdownMarkerCapture(scale: scale));
}

class _MarkdownMarkerCapture extends StatelessWidget {
  const _MarkdownMarkerCapture({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      theme: ThemeData.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MarkdownWidget(
              data: _markdown,
              config: buildMarkdownConfig(isDark: false),
              shrinkWrap: true,
              selectable: false,
              physics: const NeverScrollableScrollPhysics(),
            ),
          ),
        ),
      ),
    );
  }
}
