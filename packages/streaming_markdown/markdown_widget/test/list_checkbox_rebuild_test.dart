import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/blocks/container/list.dart';
import 'package:markdown_widget/widget/proxy_rich_text.dart';
import 'package:markdown_widget/widget/span_node.dart';
import 'package:markdown_widget/widget/widget_visitor.dart';

void main() {
  test('building a task list repeatedly preserves its checkbox marker', () {
    final config = MarkdownConfig.defaultConfig;
    final nodes = m.Document(
      extensionSet: m.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parseLines(['- [ ] task']);
    final spans = WidgetVisitor(config: config).visit(nodes);
    final taskList = _findTaskList(spans)!;

    final firstBuild = taskList.build() as WidgetSpan;
    final secondBuild = taskList.build() as WidgetSpan;

    expect(_marker(firstBuild), isA<ProxyRichText>());
    expect(_containsWidgetSpan(_contentSpan(firstBuild)), isFalse);
    expect(
      _marker(secondBuild),
      isA<ProxyRichText>(),
      reason:
          'building a list must not remove its checkbox from stored children',
    );
    expect(_containsWidgetSpan(_contentSpan(secondBuild)), isFalse);
  });
}

ListNode? _findTaskList(List<SpanNode> nodes) {
  for (final node in nodes) {
    if (node is ListNode && node.isCheckbox) return node;
    if (node is ElementNode) {
      final descendant = _findTaskList(node.children);
      if (descendant != null) return descendant;
    }
  }
  return null;
}

Widget? _marker(WidgetSpan span) {
  final row = (span.child as Padding).child as Row;
  return (row.children.first as SizedBox).child;
}

InlineSpan _contentSpan(WidgetSpan span) {
  final row = (span.child as Padding).child as Row;
  return ((row.children[1] as Flexible).child as ProxyRichText).textSpan;
}

bool _containsWidgetSpan(InlineSpan span) {
  if (span is WidgetSpan) return true;
  return span is TextSpan && (span.children?.any(_containsWidgetSpan) ?? false);
}
