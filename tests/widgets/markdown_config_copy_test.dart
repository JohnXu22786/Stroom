import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  test('MarkdownConfig.copy preserves the original config', () {
    final original = MarkdownConfig(
      configs: [
        const PConfig(textStyle: TextStyle(color: Colors.red)),
        const PreConfig(language: 'dart'),
      ],
      incrementalConfigKey: 'original',
    );

    final copy = original.copy(
      configs: [const PConfig(textStyle: TextStyle(color: Colors.blue))],
      incrementalConfigKey: 'copy',
    );

    expect(original.p.textStyle.color, Colors.red);
    expect(original.pre.language, 'dart');
    expect(original.incrementalConfigKey, 'original');
    expect(copy.p.textStyle.color, Colors.blue);
    expect(copy.pre.language, 'dart');
    expect(copy.incrementalConfigKey, 'copy');
  });

  testWidgets('MarkdownWidget rebuilds when a copied config changes', (
    WidgetTester tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval = const Duration(
        milliseconds: 500,
      );
    });
    final original = MarkdownConfig(
      configs: [const PConfig(textStyle: TextStyle(color: Colors.red))],
    );
    Widget build(MarkdownConfig config) => MaterialApp(
      home: Scaffold(
        body: MarkdownWidget(
          data: 'Paragraph',
          selectable: false,
          incremental: true,
          incrementalKey: 'config-copy',
          fullTextOnInvalidation: () => 'Paragraph',
          config: config,
        ),
      ),
    );

    await tester.pumpWidget(build(original));

    final updated = original.copy(
      configs: [const PConfig(textStyle: TextStyle(color: Colors.blue))],
    );
    await tester.pumpWidget(build(updated));

    final paragraph = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.textSpan?.toPlainText() == 'Paragraph',
      ),
    );
    TextStyle? paragraphStyle(InlineSpan span) {
      if (span is! TextSpan) return null;
      if (span.text == 'Paragraph' && span.style != null) return span.style;
      for (final child in span.children ?? const <InlineSpan>[]) {
        final style = paragraphStyle(child);
        if (style != null) return style;
      }
      return null;
    }

    expect(paragraphStyle(paragraph.textSpan!)!.color, Colors.blue);
  });
}
