import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as m;

import '../widget/blocks/leaf/heading.dart';
import '../widget/blocks/leaf/link.dart';
import '../widget/link_recognizer_lifecycle.dart';
import '../widget/span_node.dart';
import '../widget/widget_visitor.dart';
import 'configs.dart';
import 'toc.dart';

typedef HeadingNodeFilter = bool Function(HeadingNode toc);

///use [MarkdownGenerator] to transform markdown data to [Widget] list, so you can render it by any type of [ListView]
class MarkdownGenerator {
  final Iterable<m.InlineSyntax> inlineSyntaxList;
  final Iterable<m.BlockSyntax> blockSyntaxList;
  final EdgeInsets linesMargin;
  final List<SpanNodeGeneratorWithTag> generators;
  final SpanNodeAcceptCallback? onNodeAccepted;
  final m.ExtensionSet? extensionSet;
  final TextNodeGenerator? textGenerator;
  final SpanNodeBuilder? spanNodeBuilder;
  final RichTextBuilder? richTextBuilder;
  final RegExp? splitRegExp;
  final HeadingNodeFilter headingNodeFilter;

  /// Use [headingNodeFilter] to filter the levels of headings you want to show.
  /// e.g.
  /// ```dart
  /// (HeadingNode node) => {'h1', 'h2'}.contains(node.headingConfig.tag)
  /// ```
  MarkdownGenerator({
    this.inlineSyntaxList = const [],
    this.blockSyntaxList = const [],
    this.linesMargin = const EdgeInsets.symmetric(vertical: 8),
    this.generators = const [],
    this.onNodeAccepted,
    this.extensionSet,
    this.textGenerator,
    this.spanNodeBuilder,
    this.richTextBuilder,
    this.splitRegExp,
    headingNodeFilter,
  }) : headingNodeFilter = headingNodeFilter ?? allowAll;

  ///convert [data] to widgets
  ///[onTocList] can provider [Toc] list
  List<Widget> buildWidgets(
    String data, {
    ValueCallback<List<Toc>>? onTocList,
    MarkdownConfig? config,
  }) {
    final mdConfig = config ?? MarkdownConfig.defaultConfig;
    return buildWidgetsFromNodes(
      _parseNodes(data),
      onTocList: onTocList,
      config: mdConfig,
    );
  }

  List<m.Node> _parseNodes(String data) {
    final document = m.Document(
      extensionSet: extensionSet ?? m.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
      inlineSyntaxes: inlineSyntaxList,
      blockSyntaxes: blockSyntaxList,
    );
    final regExp = splitRegExp ?? WidgetVisitor.defaultSplitRegExp;
    return document.parseLines(data.split(regExp));
  }

  /// Converts already parsed nodes to widgets using the same visitor and
  /// generator configuration as [buildWidgets]. This is used by a live
  /// streaming session to keep widgets for sealed blocks and replace only the
  /// active block's widgets.
  List<Widget> buildWidgetsFromNodes(
    List<m.Node> nodes, {
    ValueCallback<List<Toc>>? onTocList,
    MarkdownConfig? config,
  }) {
    final mdConfig = config ?? MarkdownConfig.defaultConfig;
    final regExp = splitRegExp ?? WidgetVisitor.defaultSplitRegExp;
    final List<Toc> tocList = [];
    final visitor = WidgetVisitor(
      config: mdConfig,
      generators: generators,
      textGenerator: textGenerator,
      richTextBuilder: richTextBuilder,
      splitRegExp: regExp,
      onNodeAccepted: (node, index) {
        onNodeAccepted?.call(node, index);
        if (node is HeadingNode && headingNodeFilter(node)) {
          final listLength = tocList.length;
          tocList.add(
            Toc(node: node, widgetIndex: index, selfIndex: listLength),
          );
        }
      },
    );
    final spans = visitor.visit(nodes);
    onTocList?.call(tocList);
    final List<Widget> widgets = [];
    for (var span in spans) {
      final recognizerOwner = LinkRecognizerOwner();
      _attachLinkRecognizerOwner(span, recognizerOwner);
      final textSpan = spanNodeBuilder?.call(span) ?? span.build();
      final richText = richTextBuilder?.call(textSpan) ?? Text.rich(textSpan);
      widgets.add(Padding(
        padding: linesMargin,
        child: LinkRecognizerLifecycle(
          span: textSpan,
          owner: recognizerOwner,
          disposeOwner: true,
          child: richText,
        ),
      ));
    }
    return widgets;
  }

  /// Builds a bounded live preview without reparsing ordinary long text.
  /// Excerpts containing strong emphasis or display math go through the full
  /// parser so those visible constructs do not fall back to literal markers.
  List<Widget> buildPlainTextPreview(
    List<String> fragments, {
    MarkdownConfig? config,
  }) {
    if (fragments.isEmpty) return const [];
    final mdConfig = config ?? MarkdownConfig.defaultConfig;
    final source = fragments.join();
    if (source.contains('**') || source.contains(r'$$')) {
      return buildWidgets(source, config: mdConfig);
    }
    final sourceWithoutCode = _withoutMarkdownCode(source);
    final mayContainUnderscoreEmphasis = RegExp(
      r'(?<!\w)__(?=\S).*?\S__(?!\w)',
      dotAll: true,
    ).hasMatch(sourceWithoutCode);
    if (mayContainUnderscoreEmphasis) {
      final nodes = _parseNodes(source);
      if (_containsStrongEmphasis(nodes)) {
        return buildWidgetsFromNodes(nodes, config: mdConfig);
      }
    }
    final sourceSpan = TextSpan(
      style: mdConfig.p.textStyle,
      text: source,
    );
    return [
      Padding(
        padding: linesMargin,
        child: richTextBuilder?.call(sourceSpan) ?? Text.rich(sourceSpan),
      ),
    ];
  }

  static bool allowAll(HeadingNode toc) => true;
}

String _withoutMarkdownCode(String source) {
  final codeUnits = source.codeUnits.toList();
  void maskRange(int start, int end) {
    for (var i = start; i < end; i++) {
      if (codeUnits[i] != 10 && codeUnits[i] != 13) codeUnits[i] = 32;
    }
  }

  final fenceStart = RegExp(r'^ {0,3}(`{3,}|~{3,})');
  final fenceEnd = RegExp(r'^ {0,3}(`{3,}|~{3,})[ \t]*$');
  final quotePrefix = RegExp(r'^ {0,3}>[ \t]?');
  final listPrefix = RegExp(r'^ {0,3}(?:[-+*]|[0-9]{1,9}[.)])[ \t]+');
  var fenceCharacter = 0;
  var fenceLength = 0;
  var fenceQuoteDepth = 0;
  var lineStart = 0;
  while (lineStart < source.length) {
    var lineEnd = source.indexOf('\n', lineStart);
    if (lineEnd == -1) lineEnd = source.length;
    final line = source.substring(lineStart, lineEnd);
    var content = line;
    var quoteDepth = 0;
    while (true) {
      final match = quotePrefix.matchAsPrefix(content);
      if (match == null) break;
      quoteDepth++;
      content = content.substring(match.end);
    }
    while (true) {
      final match = listPrefix.matchAsPrefix(content);
      if (match == null) break;
      content = content.substring(match.end);
    }

    if (fenceCharacter != 0 && quoteDepth < fenceQuoteDepth) {
      fenceCharacter = 0;
      fenceLength = 0;
      fenceQuoteDepth = 0;
    }

    if (fenceCharacter != 0) {
      maskRange(lineStart, lineEnd);
      final fenceContent = fenceQuoteDepth == 0 ? line : content;
      final match = fenceEnd.firstMatch(fenceContent);
      if (match != null &&
          match.group(1)!.codeUnitAt(0) == fenceCharacter &&
          match.group(1)!.length >= fenceLength) {
        fenceCharacter = 0;
        fenceLength = 0;
        fenceQuoteDepth = 0;
      }
    } else {
      final match = fenceStart.firstMatch(content);
      if (match != null) {
        final fence = match.group(1)!;
        final infoString = content.substring(match.end);
        if (fence.startsWith('~') || !infoString.contains('`')) {
          fenceCharacter = fence.codeUnitAt(0);
          fenceLength = fence.length;
          fenceQuoteDepth = quoteDepth;
          maskRange(lineStart, lineEnd);
        }
      } else if (content.startsWith('    ') || content.startsWith('\t')) {
        maskRange(lineStart, lineEnd);
      }
    }
    lineStart = lineEnd + 1;
  }

  final sourceWithoutFences = String.fromCharCodes(codeUnits);
  final runs = RegExp(r'`+').allMatches(sourceWithoutFences).toList();
  final nextRunByLength = <int, int>{};
  final nextMatchingRun = List<int>.filled(runs.length, -1);
  for (var i = runs.length - 1; i >= 0; i--) {
    final run = runs[i];
    final runLength = run.end - run.start;
    nextMatchingRun[i] = nextRunByLength[runLength] ?? -1;
    nextRunByLength[runLength] = i;
  }

  var runIndex = 0;
  while (runIndex < runs.length) {
    final run = runs[runIndex];
    var backslashCount = 0;
    for (var i = run.start - 1; i >= 0 && codeUnits[i] == 92; i--) {
      backslashCount++;
    }
    final closingRunIndex = nextMatchingRun[runIndex];
    if (backslashCount.isOdd || closingRunIndex == -1) {
      runIndex++;
      continue;
    }

    // Once a run opens a code span, different-length runs inside it cannot
    // pair with delimiters that follow the span.
    maskRange(run.start, runs[closingRunIndex].end);
    runIndex = closingRunIndex + 1;
  }
  return String.fromCharCodes(codeUnits);
}

bool _containsStrongEmphasis(Iterable<m.Node> nodes) {
  for (final node in nodes) {
    if (node is m.Element) {
      if (node.tag == 'strong' ||
          _containsStrongEmphasis(node.children ?? const <m.Node>[])) {
        return true;
      }
    }
  }
  return false;
}

void _attachLinkRecognizerOwner(
  SpanNode node,
  LinkRecognizerOwner owner,
) {
  if (node is LinkNode) node.recognizerOwner = owner;
  if (node is ElementNode) {
    for (final child in node.children) {
      _attachLinkRecognizerOwner(child, owner);
    }
  }
}

typedef SpanNodeBuilder = TextSpan Function(SpanNode spanNode);

typedef RichTextBuilder = Widget Function(InlineSpan span);
