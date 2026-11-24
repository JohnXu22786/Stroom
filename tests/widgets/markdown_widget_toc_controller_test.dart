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
      VisibilityDetectorController.instance.updateInterval = const Duration(
        milliseconds: 500,
      );
    });
    final firstController = TocController();
    final nextController = TocController();

    Widget build(
      TocController tocController, {
      String data = '# First heading\n\n## Second heading',
    }) => MaterialApp(
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
              child: MarkdownWidget(data: data, tocController: tocController),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(build(firstController));
    expect(firstController.tocList, hasLength(2));

    firstController.onIndexChanged(1);
    await tester.pump();
    expect(find.text('item:1,current:1'), findsOneWidget);

    await tester.pumpWidget(build(nextController));
    await tester.pump();
    expect(nextController.tocList, hasLength(2));
    expect(find.text('item:0,current:0'), findsOneWidget);

    nextController.onIndexChanged(1);
    await tester.pump();
    expect(find.text('item:1,current:1'), findsOneWidget);

    await tester.pumpWidget(build(nextController, data: '# First heading'));
    await tester.pump();
    expect(nextController.tocList, hasLength(1));
    expect(find.text('item:0,current:0'), findsOneWidget);

    nextController.onIndexChanged(0);
    await tester.pump();
    expect(find.text('item:0,current:0'), findsOneWidget);

    firstController.onIndexChanged(1);
    await tester.pump();
    expect(find.text('item:0,current:0'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    nextController.onIndexChanged(0);
    expect(tester.takeException(), isNull);
    nextController.dispose();
    firstController.dispose();
  });

  testWidgets('custom TOC rows scroll with the active Markdown heading', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval = const Duration(
        milliseconds: 500,
      );
    });
    final tocController = TocController();
    final headings = List.generate(
      12,
      (index) => '${'#' * (index == 0 ? 1 : 2)} Heading $index',
    ).join('\n\n');
    var currentIndexAfterMarkdownScroll = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 100,
                child: TocWidget(
                  controller: tocController,
                  itemBuilder: (data) {
                    currentIndexAfterMarkdownScroll = data.currentIndex;
                    return SizedBox(
                      height: 40,
                      child: Text('custom:${data.index}:${data.currentIndex}'),
                    );
                  },
                ),
              ),
              SizedBox(
                height: 180,
                child: MarkdownWidget(
                  data: headings,
                  tocController: tocController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tocController.tocList, hasLength(12));

    final markdownState = tester.state<MarkdownWidgetState>(
      find.byType(MarkdownWidget),
    );
    markdownState.controller.jumpTo(
      markdownState.controller.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    expect(currentIndexAfterMarkdownScroll, greaterThan(0));
    tocController.onIndexChanged(tocController.tocList.last.widgetIndex);
    await tester.pumpAndSettle();

    expect(find.text('custom:11:11'), findsOneWidget);
    final tocViewport = tester.getRect(find.byType(TocWidget));
    final activeRow = tester.getRect(find.text('custom:11:11'));
    expect(activeRow.overlaps(tocViewport), isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    tocController.dispose();
  });

  testWidgets('MarkdownWidget reconnects when its TOC controller changes', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval = const Duration(
        milliseconds: 500,
      );
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
