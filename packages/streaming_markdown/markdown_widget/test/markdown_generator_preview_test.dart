import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';

void main() {
  testWidgets('does not pair code spans across Markdown block boundaries',
      (tester) async {
    final generator = MarkdownGenerator();
    for (final source in const [
      '- unmatched `\n- __bold__ then close `',
      '- unmatched `\n# __bold__ then close `',
    ]) {
      final widgets = generator.buildPlainTextPreview([source]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Column(children: widgets)),
      ));

      expect(find.textContaining('bold'), findsOneWidget);
      expect(find.textContaining('__bold__'), findsNothing);
    }
  });
}
