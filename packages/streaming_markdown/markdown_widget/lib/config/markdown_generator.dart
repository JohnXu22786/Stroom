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
    final emphasisCandidateSource =
        _withoutMarkdownLinkDestinations(sourceWithoutCode);
    final mayContainUnderscoreEmphasis =
        _mayContainUnderscoreEmphasis(emphasisCandidateSource);
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
  final listPrefix = RegExp(r'^ {0,3}(?:[-+*]|[0-9]{1,9}[.)])[ \t]');
  var fenceCharacter = 0;
  var fenceLength = 0;
  var fenceQuoteDepth = 0;
  var fenceListIndent = 0;
  final listContentIndents = <int>[];
  var lineStart = 0;
  while (lineStart < source.length) {
    var lineEnd = lineStart;
    while (lineEnd < source.length &&
        codeUnits[lineEnd] != 10 &&
        codeUnits[lineEnd] != 13) {
      lineEnd++;
    }
    final line = source.substring(lineStart, lineEnd);
    var content = line;
    var quoteDepth = 0;
    var listIndent = 0;
    while (true) {
      final match = quotePrefix.matchAsPrefix(content);
      if (match == null) break;
      quoteDepth++;
      content = content.substring(match.end);
    }
    var leadingSpaces = 0;
    while (leadingSpaces < content.length &&
        content.codeUnitAt(leadingSpaces) == 32) {
      leadingSpaces++;
    }
    if (fenceCharacter == 0 && content.trim().isNotEmpty) {
      while (listContentIndents.isNotEmpty &&
          leadingSpaces < listContentIndents.last) {
        listContentIndents.removeLast();
      }
    }
    if (listContentIndents.isNotEmpty &&
        leadingSpaces >= listContentIndents.last) {
      listIndent = listContentIndents.last;
      content = content.substring(listIndent);
    }
    var foundListItem = false;
    while (true) {
      final match = listPrefix.matchAsPrefix(content);
      if (match == null) break;
      foundListItem = true;
      listIndent += match.end;
      content = content.substring(match.end);
    }
    if (foundListItem && fenceCharacter == 0) {
      listContentIndents.add(listIndent);
    }

    if (fenceCharacter != 0 && quoteDepth < fenceQuoteDepth) {
      fenceCharacter = 0;
      fenceLength = 0;
      fenceQuoteDepth = 0;
      fenceListIndent = 0;
    }

    if (fenceCharacter != 0) {
      maskRange(lineStart, lineEnd);
      final listPrefix = ' ' * fenceListIndent;
      final fenceContent = fenceQuoteDepth == 0 && line.startsWith(listPrefix)
          ? line.substring(fenceListIndent)
          : fenceQuoteDepth == 0
              ? line
              : content;
      final match = fenceEnd.firstMatch(fenceContent);
      if (match != null &&
          match.group(1)!.codeUnitAt(0) == fenceCharacter &&
          match.group(1)!.length >= fenceLength) {
        fenceCharacter = 0;
        fenceLength = 0;
        fenceQuoteDepth = 0;
        fenceListIndent = 0;
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
          fenceListIndent = listIndent;
          maskRange(lineStart, lineEnd);
        }
      } else if (content.startsWith('    ') || content.startsWith('\t')) {
        maskRange(lineStart, lineEnd);
      }
    }
    lineStart = lineEnd;
    if (lineStart < source.length && codeUnits[lineStart] == 13) lineStart++;
    if (lineStart < source.length && codeUnits[lineStart] == 10) lineStart++;
  }

  final sourceWithoutFences = String.fromCharCodes(codeUnits);
  final runs = RegExp(r'`+').allMatches(sourceWithoutFences).toList();
  final paragraphSource = _withoutBlockQuotePrefixes(sourceWithoutFences);
  final paragraphBreaks = RegExp(
    r'(?:\r\n|\r|\n)[ \t]*(?:(?:\r\n|\r|\n)[ \t]*)+',
  ).allMatches(paragraphSource).toList();
  var paragraphIndex = 0;
  var paragraphBreakIndex = 0;
  final paragraphForRun = <int>[];
  for (final run in runs) {
    while (paragraphBreakIndex < paragraphBreaks.length &&
        run.start >= paragraphBreaks[paragraphBreakIndex].end) {
      paragraphIndex++;
      paragraphBreakIndex++;
    }
    paragraphForRun.add(paragraphIndex);
  }
  final runIndicesByLength = <int, List<int>>{};
  for (var i = 0; i < runs.length; i++) {
    final run = runs[i];
    runIndicesByLength.putIfAbsent(run.end - run.start, () => <int>[]).add(i);
  }

  int nextRunOfLength(int length, int afterIndex) {
    final indices = runIndicesByLength[length];
    if (indices == null) return -1;
    var low = 0;
    var high = indices.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (indices[middle] <= afterIndex) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low < indices.length ? indices[low] : -1;
  }

  var runIndex = 0;
  while (runIndex < runs.length) {
    final run = runs[runIndex];
    var backslashCount = 0;
    for (var i = run.start - 1; i >= 0 && codeUnits[i] == 92; i--) {
      backslashCount++;
    }
    final escapedFirstBacktick = backslashCount.isOdd;
    final openingLength = run.end - run.start - (escapedFirstBacktick ? 1 : 0);
    if (openingLength == 0) {
      runIndex++;
      continue;
    }

    final closingRunIndex = nextRunOfLength(openingLength, runIndex);
    if (closingRunIndex == -1 ||
        paragraphForRun[closingRunIndex] != paragraphForRun[runIndex]) {
      runIndex++;
      continue;
    }

    final openingStart = run.start + (escapedFirstBacktick ? 1 : 0);
    // Different-length runs inside a code span cannot pair with delimiters
    // that follow it. The next exact-length run closes even after a backslash.
    maskRange(openingStart, runs[closingRunIndex].end);
    runIndex = closingRunIndex + 1;
  }
  return String.fromCharCodes(codeUnits);
}

String _withoutBlockQuotePrefixes(String source) {
  final codeUnits = source.codeUnits.toList();
  final quotePrefix = RegExp(r'^ {0,3}>[ \t]?');
  var lineStart = 0;
  while (lineStart < source.length) {
    var lineEnd = lineStart;
    while (lineEnd < source.length &&
        codeUnits[lineEnd] != 10 &&
        codeUnits[lineEnd] != 13) {
      lineEnd++;
    }
    var prefixEnd = lineStart;
    var content = source.substring(lineStart, lineEnd);
    while (true) {
      final match = quotePrefix.matchAsPrefix(content);
      if (match == null) break;
      prefixEnd += match.end;
      content = content.substring(match.end);
    }
    for (var i = lineStart; i < prefixEnd; i++) {
      codeUnits[i] = 32;
    }
    lineStart = lineEnd;
    if (lineStart < source.length && codeUnits[lineStart] == 13) lineStart++;
    if (lineStart < source.length && codeUnits[lineStart] == 10) lineStart++;
  }
  return String.fromCharCodes(codeUnits);
}

String _withoutMarkdownLinkDestinations(String source) {
  final codeUnits = source.codeUnits.toList();
  final openingBrackets = <int>[];
  var i = 0;
  while (i < source.length) {
    final codeUnit = source.codeUnitAt(i);
    if (codeUnit == 92) {
      i += 2;
      continue;
    }
    if (codeUnit == 91) {
      openingBrackets.add(i);
    } else if (codeUnit == 93 && openingBrackets.isNotEmpty) {
      openingBrackets.removeLast();
      if (i + 1 < source.length && source.codeUnitAt(i + 1) == 40) {
        final destinationEnd = _inlineLinkDestinationEnd(source, i + 2);
        if (destinationEnd != -1) {
          for (var j = i + 1; j <= destinationEnd; j++) {
            if (codeUnits[j] != 10 && codeUnits[j] != 13) codeUnits[j] = 32;
          }
          i = destinationEnd + 1;
          continue;
        }
      }
    }
    i++;
  }
  return String.fromCharCodes(codeUnits);
}

int _inlineLinkDestinationEnd(String source, int start) {
  var i = start;
  while (i < source.length && _isLinkWhitespace(source.codeUnitAt(i))) {
    i++;
  }
  if (i >= source.length || source.codeUnitAt(i) == 41) return -1;

  if (source.codeUnitAt(i) == 60) {
    i++;
    while (i < source.length) {
      final codeUnit = source.codeUnitAt(i);
      if (codeUnit == 10 || codeUnit == 13) return -1;
      if (codeUnit == 92) {
        i += 2;
      } else if (codeUnit == 62) {
        i++;
        break;
      } else if (codeUnit == 60) {
        return -1;
      } else {
        i++;
      }
    }
    if (i > source.length || source.codeUnitAt(i - 1) != 62) return -1;
  } else {
    var depth = 0;
    while (i < source.length) {
      final codeUnit = source.codeUnitAt(i);
      if (codeUnit == 10 || codeUnit == 13) return -1;
      if (codeUnit == 92) {
        i += 2;
      } else if (_isLinkWhitespace(codeUnit)) {
        break;
      } else if (codeUnit == 40) {
        depth++;
        i++;
      } else if (codeUnit == 41) {
        if (depth == 0) break;
        depth--;
        i++;
      } else if (codeUnit == 60) {
        return -1;
      } else {
        i++;
      }
    }
    if (depth != 0) return -1;
  }

  var separatedTitle = false;
  while (i < source.length && _isLinkWhitespace(source.codeUnitAt(i))) {
    separatedTitle = true;
    i++;
  }
  if (i >= source.length) return -1;
  if (source.codeUnitAt(i) == 41) return i;
  if (!separatedTitle) return -1;

  final titleDelimiter = source.codeUnitAt(i);
  final titleEndDelimiter = switch (titleDelimiter) {
    34 => 34,
    39 => 39,
    40 => 41,
    _ => -1,
  };
  if (titleEndDelimiter == -1) return -1;
  i++;
  var previousWasLineBreak = false;
  while (i < source.length) {
    final codeUnit = source.codeUnitAt(i);
    if (codeUnit == 92) {
      i++;
    } else if (codeUnit == titleEndDelimiter) {
      i++;
      while (i < source.length && _isLinkWhitespace(source.codeUnitAt(i))) {
        i++;
      }
      return i < source.length && source.codeUnitAt(i) == 41 ? i : -1;
    } else if (titleDelimiter == 40 && codeUnit == 41) {
      return -1;
    } else if (codeUnit == 10 || codeUnit == 13) {
      if (previousWasLineBreak) return -1;
      previousWasLineBreak = true;
      if (codeUnit == 13 &&
          i + 1 < source.length &&
          source.codeUnitAt(i + 1) == 10) {
        i++;
      }
    } else if (!_isLinkWhitespace(codeUnit)) {
      previousWasLineBreak = false;
    }
    i++;
  }
  return -1;
}

bool _isLinkWhitespace(int codeUnit) =>
    codeUnit == 32 ||
    codeUnit == 9 ||
    codeUnit == 10 ||
    codeUnit == 11 ||
    codeUnit == 12 ||
    codeUnit == 13;

bool _isEscapedMarkdownCharacter(String source, int offset) {
  var backslashCount = 0;
  for (var i = offset - 1; i >= 0 && source.codeUnitAt(i) == 92; i--) {
    backslashCount++;
  }
  return backslashCount.isOdd;
}

bool _mayContainUnderscoreEmphasis(String source) {
  final paragraphs = source.split(
    RegExp(r'(?:\r\n|\r|\n)[ \t]*(?:(?:\r\n|\r|\n)[ \t]*)+'),
  );
  for (final paragraph in paragraphs) {
    var hasOpeningDelimiter = false;
    var i = 0;
    while (i + 1 < paragraph.length) {
      if (paragraph.codeUnitAt(i) != 95 || paragraph.codeUnitAt(i + 1) != 95) {
        i++;
        continue;
      }

      var runEnd = i + 2;
      while (runEnd < paragraph.length && paragraph.codeUnitAt(runEnd) == 95) {
        runEnd++;
      }
      final escaped = _isEscapedMarkdownCharacter(paragraph, i);
      if (!escaped && runEnd - i >= 2) {
        final before = _markdownCharacterBefore(paragraph, i);
        final after = _markdownCharacterAfter(paragraph, runEnd);
        final canOpen =
            !_isMarkdownWordCharacter(before) && !_isMarkdownWhitespace(after);
        final canClose =
            !_isMarkdownWhitespace(before) && !_isMarkdownWordCharacter(after);
        if (canClose && hasOpeningDelimiter) return true;
        if (canOpen) hasOpeningDelimiter = true;
      }
      i = runEnd;
    }
  }
  return false;
}

String _markdownCharacterBefore(String source, int offset) {
  if (offset == 0) return '';
  final previous = source.codeUnitAt(offset - 1);
  if (previous >= 0xdc00 && previous <= 0xdfff && offset > 1) {
    final high = source.codeUnitAt(offset - 2);
    if (high >= 0xd800 && high <= 0xdbff) {
      return source.substring(offset - 2, offset);
    }
  }
  return source.substring(offset - 1, offset);
}

String _markdownCharacterAfter(String source, int offset) {
  if (offset >= source.length) return '';
  final first = source.codeUnitAt(offset);
  if (first >= 0xd800 && first <= 0xdbff && offset + 1 < source.length) {
    final second = source.codeUnitAt(offset + 1);
    if (second >= 0xdc00 && second <= 0xdfff) {
      return source.substring(offset, offset + 2);
    }
  }
  return source.substring(offset, offset + 1);
}

bool _isMarkdownWordCharacter(String character) =>
    character.isNotEmpty &&
    RegExp(r'[\p{L}\p{M}\p{N}_]', unicode: true).hasMatch(character);

bool _isMarkdownWhitespace(String character) =>
    character.isEmpty || RegExp(r'\s', unicode: true).hasMatch(character);

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
