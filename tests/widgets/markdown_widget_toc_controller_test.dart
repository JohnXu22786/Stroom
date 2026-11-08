import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/config/toc.dart';
import 'package:markdown_widget/widget/markdown.dart';

void main() {
  testWidgets('MarkdownWidget reconnects when its TOC controller changes', (
    tester,
  ) async {
    final firstController = TocController();
    final nextController = TocController();

    Widget buildMarkdown(TocController tocController) => MaterialApp(
          home: Scaffold(
            body: MarkdownWidget(
              data: '# First heading\n\n## Second heading',
              tocController: tocController,
            ),
          ),
        );

    await tester.pumpWidget(buildMarkdown(firstController));
    expect(firstController.tocList, hasLength(2));

    await tester.pumpWidget(buildMarkdown(nextController));
    expect(nextController.tocList, hasLength(2));

    nextController.jumpToIndex(1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
