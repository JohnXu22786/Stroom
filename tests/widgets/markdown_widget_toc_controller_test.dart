import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/config/toc.dart';
import 'package:markdown_widget/widget/markdown.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  testWidgets('TocWidget reconnects when its controller changes', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval =
          const Duration(milliseconds: 500);
    });
    final firstController = TocController();
    final nextController = TocController();

    Widget build(TocController tocController) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: 160,
              child: TocWidget(
                controller: tocController,
                itemBuilder: (data) =>
                    Text('item:${data.index},current:${data.currentIndex}'),
              ),
            ),
            Expanded(
              child: MarkdownWidget(
                data: '# First heading\n\n## Second heading',
                tocController: tocController,
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(build(firstController));
    expect(firstController.tocList, hasLength(2));

    await tester.pumpWidget(build(nextController));
    await tester.pump();
    expect(nextController.tocList, hasLength(2));
    expect(find.text('item:0,current:0'), findsOneWidget);

    nextController.onIndexChanged(1);
    await tester.pump();
    expect(find.text('item:1,current:1'), findsOneWidget);

    firstController.onIndexChanged(0);
    await tester.pump();
    expect(find.text('item:1,current:1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    nextController.onIndexChanged(0);
    expect(tester.takeException(), isNull);
    nextController.dispose();
    firstController.dispose();
  });

  testWidgets('MarkdownWidget reconnects when its TOC controller changes', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval =
          const Duration(milliseconds: 500);
    });
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
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    nextController.dispose();
    firstController.dispose();
  });
}
