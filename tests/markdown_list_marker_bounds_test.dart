import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  testWidgets('ordered markers make room for their text at narrow widths', (
    tester,
  ) async {
    Future<void> pumpMarkdown(
      String data, {
      double textScale = 1,
      Brightness brightness = Brightness.light,
      MarkdownConfig? config,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: MarkdownWidget(
                  data: data,
                  config: config,
                  shrinkWrap: true,
                  selectable: false,
                  physics: const NeverScrollableScrollPhysics(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder marker(String value) => find.text(value);

    Finder itemText(String value) => find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(value),
    );

    void expectMarkerSeparated(
      String markerText,
      String bodyText, {
      int markerIndex = 0,
    }) {
      final markerFinder = marker(markerText).at(markerIndex);
      final bodyFinder = itemText(bodyText);
      expect(markerFinder, findsOneWidget);
      expect(bodyFinder, findsWidgets);
      final markerBox = tester.renderObject<RenderBox>(markerFinder);
      final bodyBox = tester.renderObject<RenderBox>(bodyFinder.first);
      expect(
        tester.getTopRight(markerFinder).dx,
        lessThanOrEqualTo(tester.getTopLeft(bodyFinder.first).dx),
      );
      expect(markerBox.size.width, greaterThan(0));
      expect(bodyBox.size.width, greaterThan(0));
    }

    await pumpMarkdown('''
9999. A short item
10000. A longer item that wraps naturally without being compressed.
''');
    expectMarkerSeparated('10000.', 'A longer item');

    await pumpMarkdown(
      '10000. A default ordered marker after a custom unordered marker.',
      config: MarkdownConfig(
        configs: [
          ListConfig(
            marker: (isOrdered, depth, index) =>
                isOrdered ? null : const SizedBox(width: 6, height: 6),
          ),
        ],
      ),
    );
    expectMarkerSeparated('10000.', 'A default ordered marker');

    await pumpMarkdown('''
1. Parent item
   7. Nested item
''', textScale: 1.8);
    expectMarkerSeparated('1.', 'Parent item');
    expectMarkerSeparated('7.', 'Nested item');

    await pumpMarkdown('''
1. Short item
2. Another short item
''');
    expectMarkerSeparated('1.', 'Short item');
    expectMarkerSeparated('2.', 'Another short item');

    await pumpMarkdown(
      '10000. Dark-theme marker keeps its full width and body text.',
      brightness: Brightness.dark,
    );
    expectMarkerSeparated('10000.', 'Dark-theme marker');
  });
}
