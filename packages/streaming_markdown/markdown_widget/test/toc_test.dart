import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';

void main() {
  testWidgets('building TOC entries preserves source heading child styles',
      (tester) async {
    const sourceStyle = TextStyle(color: Colors.red, fontSize: 28);
    const tocStyle = TextStyle(color: Colors.blue, fontSize: 12);
    final config = MarkdownConfig(
      configs: const [H1Config(style: sourceStyle)],
    );
    List<Toc>? tocList;
    MarkdownGenerator().buildWidgets(
      '# Heading',
      config: config,
      onTocList: (list) => tocList = list,
    );
    final heading = tocList!.single.node;
    final controller = TocController()..setTocList(tocList!);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TocWidget(
          controller: controller,
          shrinkWrap: true,
          tocTextStyle: tocStyle,
          currentTocTextStyle: tocStyle,
        ),
      ),
    ));

    final sourceText = heading.children.single.build() as TextSpan;
    final tocText = tester
        .widgetList<ProxyRichText>(find.byType(ProxyRichText))
        .firstWhere((widget) => widget.textSpan is TextSpan);
    final tocSpan = (tocText.textSpan as TextSpan).children!.single as TextSpan;

    expect(
      heading.children.single.parent,
      same(heading),
      reason: 'TOC copies must not reparent nodes in the source heading tree',
    );
    expect(sourceText.style?.color, Colors.red);
    expect(tocSpan.style?.color, Colors.blue);
    expect(sourceText.style?.fontSize, 28);
    expect(tocSpan.style?.fontSize, 12);
  });
}
