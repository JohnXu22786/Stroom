import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../config/configs.dart';
import '../../proxy_rich_text.dart';
import '../../span_node.dart';
import '../../widget_visitor.dart';

Alignment? _tableCellAlignment(String? align) {
  if (align?.contains('left') ?? false) return Alignment.centerLeft;
  if (align?.contains('center') ?? false) return Alignment.center;
  if (align?.contains('right') ?? false) return Alignment.centerRight;
  return null;
}

class TableConfig implements ContainerConfig {
  final Map<int, TableColumnWidth>? columnWidths;
  final TableColumnWidth? defaultColumnWidth;
  final TextDirection? textDirection;
  final TableBorder? border;
  final TableCellVerticalAlignment? defaultVerticalAlignment;
  final TextBaseline? textBaseline;
  final Decoration? headerRowDecoration;
  final Decoration? bodyRowDecoration;
  final TextStyle? headerStyle;
  final TextStyle? bodyStyle;
  final EdgeInsets headPadding;
  final EdgeInsets bodyPadding;
  final WidgetWrapper? wrapper;

  const TableConfig({
    this.columnWidths,
    this.defaultColumnWidth,
    this.textDirection,
    this.border,
    this.defaultVerticalAlignment,
    this.textBaseline,
    this.headerRowDecoration,
    this.bodyRowDecoration,
    this.headerStyle,
    this.bodyStyle,
    this.wrapper,
    this.headPadding = const EdgeInsets.fromLTRB(8, 4, 8, 4),
    this.bodyPadding = const EdgeInsets.fromLTRB(8, 4, 8, 4),
  });

  @nonVirtual
  @override
  String get tag => MarkdownTag.table.name;
}

class TableNode extends ElementNode {
  final MarkdownConfig config;

  TableNode(this.config);

  TableConfig get tbConfig => config.table;

  @override
  InlineSpan build() {
    List<TableRow> rows = [];

    int cellCount = 0;

    for (var child in children) {
      if (child is THeadNode) {
        cellCount = child.cellCount;
        rows.addAll(child.rows);
      } else if (child is TBodyNode) {
        rows.addAll(child.buildRows(cellCount));
      }
    }

    final tableWidget = Table(
      columnWidths: tbConfig.columnWidths,
      defaultColumnWidth: tbConfig.defaultColumnWidth ?? IntrinsicColumnWidth(),
      textBaseline: tbConfig.textBaseline,
      textDirection: tbConfig.textDirection,
      border: tbConfig.border ??
          TableBorder.all(
              color: parentStyle?.color ??
                  config.p.textStyle.color ??
                  Colors.grey),
      defaultVerticalAlignment: tbConfig.defaultVerticalAlignment ??
          TableCellVerticalAlignment.middle,
      children: rows,
    );

    return WidgetSpan(
        child: config.table.wrapper?.call(tableWidget) ?? tableWidget);
  }
}

class THeadNode extends ElementNode {
  final MarkdownConfig config;
  final WidgetVisitor visitor;

  THeadNode(this.config, this.visitor);

  List<TableRow> get rows => List.generate(children.length, (index) {
        final trChild = children[index] as TrNode;
        return TableRow(
            decoration: config.table.headerRowDecoration,
            children: List.generate(trChild.children.length, (index) {
              final currentTh = trChild.children[index] as ThNode;
              final cell = Padding(
                padding: config.table.headPadding,
                child: ProxyRichText(
                  currentTh.build(),
                  richTextBuilder: visitor.richTextBuilder,
                ),
              );
              final alignment =
                  _tableCellAlignment(currentTh.attribute['align']);
              return alignment == null
                  ? Center(child: cell)
                  : Align(alignment: alignment, child: cell);
            }));
      });

  int get cellCount => (children.first as TrNode).children.length;

  @override
  TextStyle? get style =>
      config.table.headerStyle?.merge(parentStyle) ??
      parentStyle ??
      config.p.textStyle.copyWith(fontWeight: FontWeight.bold);
}

class TBodyNode extends ElementNode {
  final MarkdownConfig config;
  final WidgetVisitor visitor;

  TBodyNode(this.config, this.visitor);

  List<TableRow> buildRows(int cellCount) {
    return List.generate(children.length, (index) {
      final child = children[index] as TrNode;
      final List<Widget> widgets =
          List.generate(cellCount, (index) => Container());
      for (var i = 0; i < child.children.length && i < cellCount; ++i) {
        var c = child.children[i];
        widgets[i] = Padding(
            padding: config.table.bodyPadding,
            child: ProxyRichText(
              c.build(),
              richTextBuilder: visitor.richTextBuilder,
            ));
      }
      return TableRow(
          decoration: config.table.bodyRowDecoration, children: widgets);
    });
  }

  @override
  TextStyle? get style =>
      config.table.bodyStyle?.merge(parentStyle) ??
      parentStyle ??
      config.p.textStyle;
}

class TrNode extends ElementNode {
  @override
  TextStyle? get style => parentStyle;
}

class ThNode extends ElementNode {
  final Map<String, String> attribute;

  ThNode(this.attribute);

  @override
  TextStyle? get style => parentStyle;
}

class TdNode extends ElementNode {
  final Map<String, String> attribute;
  final WidgetVisitor visitor;

  TdNode(this.attribute, this.visitor);

  @override
  InlineSpan build() {
    final alignment = _tableCellAlignment(attribute['align']);
    InlineSpan result = childrenSpan;
    if (alignment != null) {
      result = WidgetSpan(
          child: Align(
              alignment: alignment,
              child: ProxyRichText(
                childrenSpan,
                richTextBuilder: visitor.richTextBuilder,
              )));
    }
    return result;
  }

  @override
  TextStyle? get style => parentStyle;
}
