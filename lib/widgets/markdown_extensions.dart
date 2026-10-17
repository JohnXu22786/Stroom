import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import '../utils/mhchem_syntax.dart';
import 'code_block_source_widget.dart';
import 'html_code_block_widget.dart';
import 'mermaid_render_widget.dart';

/// Tag used by the LaTeX custom generator.
const _latexTag = 'latex';

/// Scale factor for block/display math (`$$...$$`) relative to the
/// surrounding text size. Only display math is scaled; inline math
/// (`$...$`) keeps the regular text size.
const double _displayMathScaleFactor = 1.3;

/// Char code of '<', the start character of the HTML-like inline syntaxes
/// ([BrSyntax], [USyntax]).
const int _ltCharCode = 0x3C;

/// Custom [m.InlineSyntax] that parses HTML line-break tags (`<br>`,
/// `<br/>`, `<br />`, `</br>`) as hard line breaks.
///
/// The `markdown` package's [m.InlineHtmlSyntax] passes inline HTML through
/// as literal text, so without this syntax `<br>` in table cells (and
/// paragraphs) would render as the characters "<br>" instead of a line
/// break. Emitting a `br` element lets `markdown_widget`'s built-in
/// [BrNode] render it as a newline (`\n`).
///
/// Attributed forms (`<br class="x">`) are not matched and keep rendering
/// as literal text — models do not emit them, and keeping the match strict
/// avoids false positives.
class BrSyntax extends m.InlineSyntax {
  BrSyntax()
      : super(
          // Optional leading "/" for </br>, optional whitespace before an
          // optional self-closing "/". Case-insensitive: models also output
          // <BR> or <Br>.
          r'</?br\s*/?>',
          startCharacter: _ltCharCode,
          caseSensitive: false,
        );

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    parser.addNode(m.Element.text('br', ''));
    return true;
  }
}

/// Custom [m.InlineSyntax] that parses HTML underline tags (`<u>text</u>`)
/// into a `u` element.
///
/// The `markdown` package's [m.InlineHtmlSyntax] passes inline HTML through
/// as literal text, so without this syntax `<u>下划线文本</u>` would render
/// as the characters "<u>下划线文本</u>" instead of underlined text.
///
/// The inner content is re-parsed with the document's inline syntaxes, so
/// nested markdown (`<u>**加粗**</u>`) keeps rendering inside the
/// underline. Only the plain paired form is matched: attributed
/// (`<u class="x">`) and unclosed tags keep rendering as literal text —
/// models do not emit attributes, and keeping the match strict avoids
/// false positives.
///
/// Known limitation (CommonMark HTML-block rule): an opening `<u>` alone on
/// a line at block start (document start or right after a blank line)
/// begins an HTML block and renders literally. Everywhere else — including
/// `<u>text</u>` at the start of a line, or on a line following paragraph
/// text (an HTML block cannot interrupt a paragraph) — it underlines
/// normally.
class USyntax extends m.InlineSyntax {
  USyntax()
      : super(
          // Case-insensitive: models also output <U> or </U>. The inner
          // group is re-parsed by [m.Document.parseInline] in [onMatch].
          r'<u>([\s\S]*?)</u>',
          startCharacter: _ltCharCode,
          caseSensitive: false,
        );

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    // Parse the inner content with the same inline syntaxes as the rest of
    // the document so markdown inside the underline keeps working.
    final content = match.group(1) ?? '';
    final el = m.Element('u', parser.document.parseInline(content));
    parser.addNode(el);
    return true;
  }
}

/// A [SpanNode] that renders its children with an underline
/// ([TextDecoration.underline]), mirroring how `markdown_widget`'s
/// [DelNode] renders strikethrough for `<del>`.
class UNode extends ElementNode {
  @override
  TextStyle get style => parentStyle?.merge(_defaultUStyle) ?? _defaultUStyle;
}

/// See [UNode].
const _defaultUStyle = TextStyle(decoration: TextDecoration.underline);

/// [SpanNodeGeneratorWithTag] that creates [LatexNode] instances when
/// the markdown parser encounters a LaTeX element.
final SpanNodeGeneratorWithTag latexGenerator = SpanNodeGeneratorWithTag(
  tag: _latexTag,
  generator: (e, config, visitor) =>
      LatexNode(e.attributes, e.textContent, config),
);

/// [SpanNodeGeneratorWithTag] that creates [UNode] instances when
/// the markdown parser encounters a `u` (underline) element.
final SpanNodeGeneratorWithTag uGenerator = SpanNodeGeneratorWithTag(
  tag: 'u',
  generator: (e, config, visitor) => UNode(),
);

/// Custom [m.InlineSyntax] that parses LaTeX math expressions written
/// as `$...$` (inline) or `$$...$$` (block/display).
///
/// Block syntax (`$$...$$`) is checked first so it takes priority over
/// inline syntax when both `$$` delimiters are present.
class LatexSyntax extends m.InlineSyntax {
  /// The regex pattern used to match LaTeX expressions.
  /// Matches `$$...$$` (block) or `$...$` (inline).
  static const String latexPattern = r'(\$\$[\s\S]+?\$\$)|(\$.+?\$)';

  LatexSyntax()
      : super(
          latexPattern,
        );

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final input = match.input;
    final matchValue = input.substring(match.start, match.end);

    String content = '';
    bool isInline = true;

    const blockSyntax = r'$$';
    const inlineSyntax = r'$';

    if (matchValue.startsWith(blockSyntax) &&
        matchValue.endsWith(blockSyntax) &&
        matchValue != blockSyntax) {
      content = matchValue.substring(2, matchValue.length - 2);
      isInline = false;
    } else if (matchValue.startsWith(inlineSyntax) &&
        matchValue.endsWith(inlineSyntax) &&
        matchValue != inlineSyntax) {
      content = matchValue.substring(1, matchValue.length - 1);
    }

    final el = m.Element.text(_latexTag, matchValue);
    el.attributes['content'] = content;
    el.attributes['isInline'] = '$isInline';
    parser.addNode(el);
    return true;
  }
}

/// A [SpanNode] that renders LaTeX math content using [flutter_math_fork].
///
/// Inline math (`$...$`) is rendered as an inline [WidgetSpan] with
/// [PlaceholderAlignment.middle]. Block math (`$$...$$`) is rendered
/// centered in a full-width container with vertical margin.
class LatexNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;
  final MarkdownConfig config;

  LatexNode(this.attributes, this.textContent, this.config);

  @override
  InlineSpan build() {
    final content = attributes['content'] ?? '';
    final isInline = attributes['isInline'] == 'true';

    final style = parentStyle ?? config.p.textStyle;

    // Empty content → fall back to plain text
    if (content.isEmpty) {
      return TextSpan(style: style, text: textContent);
    }

    // Block/display math (`$$...$$`) is rendered [_displayMathScaleFactor]
    // larger than the surrounding text so it stands out as its own centered
    // line. Scaling the text style's font size scales the whole equation
    // (flutter_math_fork derives every dimension from `fontSize`), and the
    // [WidgetSpan] then grows with it — so the line height of that line
    // changes together with the formula. Inline math (`$...$`) keeps the
    // plain text style.
    final mathTextStyle = isInline
        ? style
        : style.copyWith(
            fontSize: (style.fontSize ?? config.p.textStyle.fontSize ?? 16.0) *
                _displayMathScaleFactor,
          );

    // mhchem (`\ce{...}`, `\pu{...}`) is expanded to plain KaTeX first;
    // flutter_math_fork does not load the mhchem extension.
    final latex = Math.tex(
      preprocessMhchem(content),
      textStyle: mathTextStyle,
      textScaleFactor: 1,
      mathStyle: MathStyle.text,
      onErrorFallback: (error) {
        return Text(
          textContent,
          style: style.copyWith(color: Colors.red),
        );
      },
    );

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: isInline
          ? latex
          : Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: latex,
            ),
    );
  }
}

/// A simple loading placeholder shown while a mermaid code block is still
/// being generated during streaming. The markdown parser strips the
/// backtick fences from the code content, so we cannot detect completion
/// by checking for closing backticks. Instead, during streaming the
/// placeholder shows only while the block's fence is still open (detected
/// via [unclosedFenceTail]); blocks whose fence has closed render
/// immediately, and the placeholder shows for the whole stream when the
/// streaming text is unavailable.
class _MermaidLoadingWidget extends StatelessWidget {
  const _MermaidLoadingWidget();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 8),
            Text(
              '正在生成...',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// True when [code] is the code of the block that is currently still being
/// generated: the message must be streaming AND [code] must be the
/// still-open trailing fence (or the streaming text must be unavailable,
/// the legacy whole-stream fallback).
///
/// Shares the fence-completion detection of mermaid/html blocks
/// ([isStreamingMermaidTail]). Mermaid builders supply [mermaidFenceIndex]
/// to distinguish identical blocks by their source order; calls without an
/// index retain the content-based comparison.
bool isCodeBlockStillGenerating({
  required bool isStreaming,
  String? streamingText,
  int? mermaidFenceIndex,
  required String code,
}) {
  return _isCodeBlockStillGenerating(
    isStreaming: isStreaming,
    streamingText: streamingText,
    mermaidFenceIndex: mermaidFenceIndex,
    code: code,
  );
}

bool _isCodeBlockStillGenerating({
  required bool isStreaming,
  String? streamingText,
  int? mermaidFenceIndex,
  required String code,
  _MermaidFenceInfo? fenceInfo,
}) {
  if (!isStreaming) return false;
  if (streamingText == null) return true;
  if (streamingText.isEmpty) return false;
  return _isStreamingMermaidTailWithInfo(
    code,
    fenceInfo ?? _unclosedFenceInfo(streamingText),
    mermaidFenceIndex: mermaidFenceIndex,
  );
}

/// Builds a code block widget for the given [code] and [language].
///
/// If [language] is `'mermaid'`, renders the code using [MermaidRenderWidget].
/// During streaming, shows a [_MermaidLoadingWidget] with a spinning
/// indicator and "正在生成..." text — but ONLY while the block's fence is
/// still open. A block whose fence has closed renders immediately (once),
/// even if the stream continues after it. This avoids repeatedly loading
/// the WebView on each incremental streaming update.
/// If [language] is `'html'`, renders the code using [HtmlCodeBlockWidget]
/// which shows an HTML card (with full-screen preview / view-code actions)
/// while streaming and a compact card with action buttons once the block
/// finishes generating; the user must tap "查看代码" to see the raw HTML
/// source (where the preview button renders the HTML in a dialog).
/// Otherwise, renders the code using [CodeBlockSourceView] which provides
/// a unified code display area with line numbers, copy / save / wrap
/// toolbar buttons and the language label in the top-left corner.
///
/// While the block is the one currently being generated
/// ([isCodeBlockStillGenerating]), [CodeBlockSourceView] receives
/// isStreaming=true and auto-scrolls to its bottom edge, animating back
/// to the top when the fence closes.
Widget _buildCodeBlock(
  String code,
  String language,
  PreConfig preConfig, {
  bool isStreaming = false,
  String? streamingText,
  int? mermaidFenceIndex,
  _MermaidFenceInfo? fenceInfo,
}) {
  if (language.toLowerCase() == 'mermaid') {
    // During streaming, show a loading animation only while the block's
    // fence is still open. The markdown parser strips backtick fences from
    // the code content and swallows the rest of the document into an
    // unclosed fence, so completion is detected by matching the builder's
    // Mermaid-fence position and code with the still-open trailing fence.
    // Callers that cannot provide the streaming text (streamingText ==
    // null) keep the legacy behavior: loading for the whole stream.
    if (_isCodeBlockStillGenerating(
      isStreaming: isStreaming,
      streamingText: streamingText,
      mermaidFenceIndex: mermaidFenceIndex,
      code: code,
      fenceInfo: fenceInfo,
    )) {
      return const _MermaidLoadingWidget();
    }
    return MermaidRenderWidget(mermaidCode: code);
  }

  if (language.toLowerCase() == 'html') {
    // The same fence-completion check as mermaid: the HTML card shows its
    // "正在生成中" state only while the block's fence is still open, so a
    // closed block renders as a finished card even mid-stream.
    return HtmlCodeBlockWidget(
      htmlCode: code,
      language: language,
      isStreaming: _isCodeBlockStillGenerating(
        isStreaming: isStreaming,
        streamingText: streamingText,
        code: code,
        fenceInfo: fenceInfo,
      ),
    );
  }

  // Fallback: render using the unified source code display widget
  // ([CodeBlockSourceView]) with line numbers, copy / save / wrap toolbar
  // buttons and the language label (from the opening fence's info string).
  //
  // The same fence-completion check as mermaid/html: only the block that
  // is currently the still-open trailing fence of the streaming reply gets
  // isStreaming=true, which makes it auto-scroll to its bottom edge while
  // generating and animate back to the top once its fence closes. Closed
  // blocks in the same message are untouched (each block owns its own
  // auto-scroll state), except for the known limitations of the unindexed
  // check (streamingText == null treats every block as generating; two
  // identical blocks, see [isStreamingMermaidTail]).
  return CodeBlockSourceView(
    code: code,
    language: language,
    isStreaming: _isCodeBlockStillGenerating(
      isStreaming: isStreaming,
      streamingText: streamingText,
      code: code,
      fenceInfo: fenceInfo,
    ),
  );
}

/// Returns the content of the still-OPEN trailing fenced code block in
/// [text], or `null` when every fenced block is closed.
///
/// While a message streams, the markdown parser treats an unclosed fence
/// as swallowing the rest of the document, so the parser hands the whole
/// tail (the partial code plus everything after the opening fence) to the
/// code-block builder as one block. Comparing the builder's code with this
/// tail identifies the still-open block.
///
/// Both backtick (```` ``` ````) and tilde (`~~~`) fences are detected,
/// with CommonMark rules: opening fences may have 1-3 leading spaces;
/// closing fences must be the same character with an equal-or-longer run
/// and no info string; backtick fences cannot contain backticks in their
/// info string. Line endings are normalized the same way the parser
/// normalizes them (`\r\n` / `\r` → `\n`).
String? unclosedFenceTail(String text) {
  return _unclosedFenceInfo(text).tail;
}

typedef _MermaidFenceInfo = ({
  String? tail,
  int? mermaidFenceIndex,
  int mermaidFenceCount,
  int mermaidFenceQuoteDepth,
  int mermaidFenceInnerQuoteDepth,
  int mermaidFenceListIndent,
  int mermaidFenceIndent,
});

_MermaidFenceInfo _unclosedFenceInfo(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  var inFence = false;
  String? fenceChar;
  var fenceLength = 0;
  var fenceQuoteDepth = 0;
  var fenceInnerQuoteDepth = 0;
  var fenceListIndent = 0;
  final listContentIndents = <int>[];
  var listQuoteDepth = 0;
  var listInnerQuoteDepth = 0;
  var mermaidFenceCount = 0;
  int? openMermaidFenceIndex;
  var openMermaidFenceQuoteDepth = 0;
  var openMermaidFenceInnerQuoteDepth = 0;
  var openMermaidFenceListIndent = 0;
  var openMermaidFenceIndent = 0;
  RegExp? htmlBlockTerminator;
  var htmlBlockUntilBlank = false;
  var htmlBlockQuoteDepth = 0;
  var htmlBlockListIndent = 0;
  var htmlBlockInnerQuoteDepth = 0;
  var paragraphOpen = false;
  var tailStart = 0;
  var offset = 0;

  void clearHtmlBlock() {
    htmlBlockTerminator = null;
    htmlBlockUntilBlank = false;
    htmlBlockQuoteDepth = 0;
    htmlBlockListIndent = 0;
    htmlBlockInnerQuoteDepth = 0;
  }

  void clearFence() {
    inFence = false;
    fenceChar = null;
    fenceLength = 0;
    fenceQuoteDepth = 0;
    fenceInnerQuoteDepth = 0;
    fenceListIndent = 0;
    openMermaidFenceIndex = null;
    openMermaidFenceQuoteDepth = 0;
    openMermaidFenceInnerQuoteDepth = 0;
    openMermaidFenceListIndent = 0;
    openMermaidFenceIndent = 0;
  }

  for (final line in lines) {
    final trimmed = _trimMarkdownTrailingWhitespace(line);
    if (htmlBlockTerminator != null || htmlBlockUntilBlank) {
      final htmlContainer = _stripActiveContainerPrefixes(
        trimmed,
        htmlBlockQuoteDepth,
        htmlBlockListIndent,
        htmlBlockInnerQuoteDepth,
      );
      if (htmlContainer.matches) {
        if (htmlBlockTerminator != null) {
          if (htmlBlockTerminator!.hasMatch(htmlContainer.line)) {
            clearHtmlBlock();
          }
        } else if (_isMarkdownBlankLine(htmlContainer.line)) {
          clearHtmlBlock();
        }
        paragraphOpen = false;
        offset += line.length + 1;
        continue;
      }
      clearHtmlBlock();
      paragraphOpen = false;
    }
    if (inFence) {
      final fenceContainer = _stripActiveContainerPrefixes(
        trimmed,
        fenceQuoteDepth,
        fenceListIndent,
        fenceInnerQuoteDepth,
      );
      if (fenceContainer.matches) {
        if (_isClosingFenceLine(
          fenceContainer.line,
          fenceChar!,
          fenceLength,
        )) {
          clearFence();
        }
        paragraphOpen = false;
        offset += line.length + 1;
        continue;
      }
      clearFence();
      paragraphOpen = false;
    }

    final quotedLine = _stripLeadingBlockQuotes(trimmed);
    if (quotedLine.depth != listQuoteDepth) {
      final lazyParagraphContinuation =
          quotedLine.depth < listQuoteDepth && paragraphOpen;
      listQuoteDepth = quotedLine.depth;
      listContentIndents.clear();
      listInnerQuoteDepth = 0;
      if (!lazyParagraphContinuation) paragraphOpen = false;
    }
    var listContainerIndent =
        listContentIndents.isEmpty ? 0 : listContentIndents.last;
    var listContent = quotedLine.line;
    if (!_isMarkdownBlankLine(listContent)) {
      final lineIndent = _leadingIndentColumns(listContent);
      while (listContentIndents.isNotEmpty &&
          lineIndent < listContentIndents.last &&
          !(paragraphOpen &&
              _isLazyListParagraphContinuation(
                listContent,
                listContentIndents.last,
              ))) {
        listContentIndents.removeLast();
      }
      listContainerIndent =
          listContentIndents.isEmpty ? 0 : listContentIndents.last;
      listContent = _stripListItemIndent(listContent, listContainerIndent);
    }
    final listLine = _stripListItemPrefix(
      listContent,
      paragraphOpen: paragraphOpen,
      isInsideList: listContentIndents.isNotEmpty,
      sourceColumnOffset: listContainerIndent,
    );
    final listItemIndent = listContainerIndent + listLine.indent;
    if (listLine.indent > 0) paragraphOpen = false;
    if (listLine.indent > 0 &&
        (listContentIndents.isEmpty ||
            listItemIndent > listContentIndents.last)) {
      listContentIndents.add(listItemIndent);
    }
    final innerQuotedLine = _stripLeadingBlockQuotes(listLine.line);
    if (innerQuotedLine.depth != listInnerQuoteDepth) {
      final lazyParagraphContinuation =
          innerQuotedLine.depth < listInnerQuoteDepth && paragraphOpen;
      listInnerQuoteDepth = innerQuotedLine.depth;
      if (!lazyParagraphContinuation) paragraphOpen = false;
    }
    final htmlBlock = _htmlBlockStart(innerQuotedLine.line);
    if (htmlBlock != null &&
        (htmlBlock.canInterruptParagraph || !paragraphOpen)) {
      paragraphOpen = false;
      htmlBlockQuoteDepth = quotedLine.depth;
      htmlBlockListIndent = listItemIndent;
      htmlBlockInnerQuoteDepth = innerQuotedLine.depth;
      if (htmlBlock.untilBlank) {
        htmlBlockUntilBlank = true;
      } else if (!htmlBlock.terminator!.hasMatch(innerQuotedLine.line)) {
        htmlBlockTerminator = htmlBlock.terminator;
      } else {
        htmlBlockQuoteDepth = 0;
        htmlBlockListIndent = 0;
        htmlBlockInnerQuoteDepth = 0;
      }
      offset += line.length + 1;
      continue;
    }
    final opening = _openingFence(innerQuotedLine.line);
    if (opening != null) {
      paragraphOpen = false;
      inFence = true;
      fenceChar = opening.fenceChar;
      fenceLength = opening.fenceLength;
      fenceQuoteDepth = quotedLine.depth;
      fenceInnerQuoteDepth = innerQuotedLine.depth;
      fenceListIndent = listItemIndent;
      if (_isMermaidFenceLanguage(
        opening.infoString,
        fenceChar: opening.fenceChar,
        fenceLength: opening.fenceLength,
      )) {
        openMermaidFenceIndex = mermaidFenceCount++;
        openMermaidFenceQuoteDepth = quotedLine.depth;
        openMermaidFenceInnerQuoteDepth = innerQuotedLine.depth;
        openMermaidFenceListIndent = listItemIndent;
        openMermaidFenceIndent = opening.indent;
      } else {
        openMermaidFenceIndex = null;
        openMermaidFenceQuoteDepth = 0;
        openMermaidFenceInnerQuoteDepth = 0;
        openMermaidFenceListIndent = 0;
        openMermaidFenceIndent = 0;
      }
      // Content starts after the fence line and its newline.
      tailStart = offset + line.length + 1;
    } else {
      paragraphOpen = !_isParagraphBoundaryLine(
            innerQuotedLine.line,
            paragraphOpen: paragraphOpen,
          ) &&
          !_isMarkdownBlankLine(innerQuotedLine.line);
    }
    offset += line.length + 1;
  }
  if (!inFence) {
    return (
      tail: null,
      mermaidFenceIndex: null,
      mermaidFenceCount: mermaidFenceCount,
      mermaidFenceQuoteDepth: 0,
      mermaidFenceInnerQuoteDepth: 0,
      mermaidFenceListIndent: 0,
      mermaidFenceIndent: 0,
    );
  }
  final tail =
      tailStart >= normalized.length ? '' : normalized.substring(tailStart);
  return (
    tail: tail,
    mermaidFenceIndex: openMermaidFenceIndex,
    mermaidFenceCount: mermaidFenceCount,
    mermaidFenceQuoteDepth: openMermaidFenceQuoteDepth,
    mermaidFenceInnerQuoteDepth: openMermaidFenceInnerQuoteDepth,
    mermaidFenceListIndent: openMermaidFenceListIndent,
    mermaidFenceIndent: openMermaidFenceIndent,
  );
}

/// True when [code] is the still-open trailing fenced code block of the
/// streaming [text] (see [unclosedFenceTail]).
///
/// [text] must be the raw text that the markdown parser is rendering;
/// pass `null` when the text is unavailable (falls back to the legacy
/// always-loading behavior in [_buildCodeBlock]).
///
/// When supplied, [mermaidFenceIndex] identifies this Mermaid block in
/// document order, so an earlier block with identical content is not
/// mistaken for the open tail. Calls without an index retain the
/// content-based check for compatibility.
bool isStreamingMermaidTail(
  String code,
  String? text, {
  int? mermaidFenceIndex,
}) {
  if (text == null || text.isEmpty) return false;
  return _isStreamingMermaidTailWithInfo(
    code,
    _unclosedFenceInfo(text),
    mermaidFenceIndex: mermaidFenceIndex,
  );
}

bool _isStreamingMermaidTailWithInfo(
  String code,
  _MermaidFenceInfo fenceInfo, {
  int? mermaidFenceIndex,
}) {
  var tail = fenceInfo.tail;
  if (mermaidFenceIndex != null &&
      mermaidFenceIndex == fenceInfo.mermaidFenceIndex) {
    tail = _stripFenceContainerPrefix(
      tail!,
      fenceInfo.mermaidFenceQuoteDepth,
      fenceInfo.mermaidFenceListIndent,
      fenceInfo.mermaidFenceInnerQuoteDepth,
      fenceInfo.mermaidFenceIndent,
    );
  }
  if (tail == null || code.trim() != tail.trim()) return false;
  return mermaidFenceIndex == null ||
      mermaidFenceIndex == fenceInfo.mermaidFenceIndex;
}

bool _isMermaidFenceLanguage(
  String infoString, {
  required String fenceChar,
  required int fenceLength,
}) {
  final info = infoString.trim();
  if (info.isEmpty) return false;
  if (info.contains('&')) {
    // FencedCodeBlockSyntax decodes HTML character references in the first
    // info-string word before CodeBlockNode derives its language. Reuse the
    // Markdown parser for entity-bearing tokens so the scanner counts the
    // same Mermaid blocks as the builder. Keep the source fence marker because
    // CommonMark allows backticks in a tilde-fence info string.
    final fenceMarker = List.filled(fenceLength, fenceChar).join();
    final parsed =
        m.Document(encodeHtml: false).parseLines(['$fenceMarker$info']);
    for (final node in parsed) {
      if (node is! m.Element || node.tag != 'pre') continue;
      final children = node.children;
      if (children == null ||
          children.isEmpty ||
          children.first is! m.Element) {
        continue;
      }
      final codeClass = (children.first as m.Element).attributes['class'];
      if (codeClass != null && codeClass.startsWith('language-')) {
        return codeClass
                .substring('language-'.length)
                .split('-')
                .last
                .trim()
                .toLowerCase() ==
            'mermaid';
      }
      return false;
    }
    return false;
  }
  final firstSpace = info.indexOf(' ');
  final firstWord = firstSpace == -1 ? info : info.substring(0, firstSpace);
  return firstWord.split('-').last.trim().toLowerCase() == 'mermaid';
}

final _htmlRawTagStart = RegExp(
  r'^ {0,3}<(?:pre|script|style|textarea)(?:\s|>|$)',
  caseSensitive: false,
);
final _htmlCommentStart = RegExp(r'^ {0,3}<!--');
final _htmlProcessingInstructionStart = RegExp(r'^ {0,3}<\?');
final _htmlDeclarationStart = RegExp(r'^ {0,3}<![a-z]', caseSensitive: false);
final _htmlCdataStart = RegExp(
  r'^ {0,3}<!\[CDATA\[',
  caseSensitive: false,
);
final _htmlBlockTagStart = RegExp(
  r'^ {0,3}</?(?:address|article|aside|base|basefont|blockquote|body|'
  r'caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|'
  r'figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|'
  r'header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|'
  r'optgroup|option|p|param|section|source|summary|table|tbody|td|tfoot|th|'
  r'thead|title|tr|track|ul)(?:\s|>|/>|$)',
  caseSensitive: false,
);
final _standaloneHtmlTag = RegExp(
  r'''^ {0,3}(?:<[a-zA-Z][a-zA-Z0-9-]*(?:\s+[a-zA-Z_:][a-zA-Z0-9._:-]*(?:\s*=\s*(?:[^\s"'=<>`]+|'[^']*?'|"[^"]*?"))?)*\s*/?>|</[a-zA-Z][a-zA-Z0-9-]*\s*>)\s*$''',
  caseSensitive: false,
);

({RegExp? terminator, bool untilBlank, bool canInterruptParagraph})?
    _htmlBlockStart(String line) {
  if (_htmlRawTagStart.hasMatch(line)) {
    return (
      terminator: RegExp(
        r'</(?:pre|script|style|textarea)>',
        caseSensitive: false,
      ),
      untilBlank: false,
      canInterruptParagraph: true,
    );
  }
  if (_htmlCommentStart.hasMatch(line)) {
    return (
      terminator: RegExp(r'-->'),
      untilBlank: false,
      canInterruptParagraph: true,
    );
  }
  if (_htmlProcessingInstructionStart.hasMatch(line)) {
    return (
      terminator: RegExp(r'\?>'),
      untilBlank: false,
      canInterruptParagraph: true,
    );
  }
  if (_htmlDeclarationStart.hasMatch(line)) {
    return (
      terminator: RegExp(r'>'),
      untilBlank: false,
      canInterruptParagraph: true,
    );
  }
  if (_htmlCdataStart.hasMatch(line)) {
    return (
      terminator: RegExp(r'\]\]>'),
      untilBlank: false,
      canInterruptParagraph: true,
    );
  }
  if (_htmlBlockTagStart.hasMatch(line)) {
    return (terminator: null, untilBlank: true, canInterruptParagraph: true);
  }
  if (_standaloneHtmlTag.hasMatch(line)) {
    return (terminator: null, untilBlank: true, canInterruptParagraph: false);
  }
  return null;
}

bool _isParagraphBoundaryLine(
  String line, {
  required bool paragraphOpen,
}) {
  if (!paragraphOpen && _leadingIndentColumns(line) >= 4) return true;
  if (RegExp(r'^ {0,3}#{1,6}(?:[ \t\x0b\x0c]|$)').hasMatch(line) ||
      (!paragraphOpen && _isLinkReferenceDefinitionStart(line)) ||
      _footnoteDefinitionStart.hasMatch(line) ||
      _thematicBreakLine.hasMatch(line)) {
    return true;
  }
  return paragraphOpen && RegExp(r'^ {0,3}(?:=+|-+)[ \t]*$').hasMatch(line);
}

bool _isMarkdownBlankLine(String line) {
  for (final codeUnit in line.codeUnits) {
    if (codeUnit != 0x20 && codeUnit != 0x09) return false;
  }
  return true;
}

String _trimMarkdownTrailingWhitespace(String line) {
  var end = line.length;
  while (end > 0) {
    final codeUnit = line.codeUnitAt(end - 1);
    if (codeUnit != 0x20 && codeUnit != 0x09) break;
    end--;
  }
  return line.substring(0, end);
}

final _thematicBreakLine = RegExp(
  r'^ {0,3}(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})$',
);
final _footnoteDefinitionStart = RegExp(
  r'^ {0,3}\[\^[^\] \r\n\x00\t]+\]:[ \t]*',
);
final _linkReferenceDefinitionCandidate = RegExp(
  r'^ {0,3}\[(?:\\.|[^\[\]])+\]:',
);

bool _isLinkReferenceDefinitionStart(String line) {
  if (!_linkReferenceDefinitionCandidate.hasMatch(line)) return false;
  final document = m.Document(encodeHtml: false)..parseLines([line]);
  return document.linkReferences.isNotEmpty;
}

String _stripFenceContainerPrefix(
  String text,
  int quoteDepth,
  int listIndent,
  int innerQuoteDepth,
  int fenceIndent,
) {
  if (quoteDepth == 0 &&
      listIndent == 0 &&
      innerQuoteDepth == 0 &&
      fenceIndent == 0) {
    return text;
  }
  return text.split('\n').map((line) {
    final outerQuoteStripped = _stripBlockQuoteDepth(line, quoteDepth);
    final listStripped = _stripListItemIndent(outerQuoteStripped, listIndent);
    final innerQuoteStripped =
        _stripBlockQuoteDepth(listStripped, innerQuoteDepth);
    return _stripFenceContentIndent(innerQuoteStripped, fenceIndent);
  }).join('\n');
}

String _stripFenceContentIndent(String line, int indent) {
  var spaces = 0;
  while (spaces < indent && spaces < line.length && line[spaces] == ' ') {
    spaces++;
  }
  return line.substring(spaces);
}

({String fenceChar, int fenceLength, String infoString, int indent})?
    _openingFence(String line) {
  // CommonMark allows 1-3 leading spaces on fences.
  final stripped = _stripUpTo3Spaces(line);
  if (stripped.length < 3) return null;
  final char = stripped[0];
  if (char != '`' && char != '~') return null;
  var run = 0;
  while (run < stripped.length && stripped[run] == char) {
    run++;
  }
  if (run < 3) return null;
  // CommonMark: backtick fences cannot have backticks in the info string.
  if (char == '`' && stripped.substring(run).contains('`')) return null;
  return (
    fenceChar: char,
    fenceLength: run,
    infoString: stripped.substring(run),
    indent: line.length - stripped.length,
  );
}

({String line, int depth}) _stripLeadingBlockQuotes(String line) {
  var remaining = line;
  var depth = 0;
  while (true) {
    final stripped = _stripOneBlockQuotePrefix(remaining);
    if (!stripped.matched) {
      return (line: remaining, depth: depth);
    }
    remaining = stripped.line;
    depth++;
  }
}

String _stripBlockQuoteDepth(String line, int depth) {
  var remaining = line;
  for (var quote = 0; quote < depth; quote++) {
    final stripped = _stripOneBlockQuotePrefix(remaining);
    if (!stripped.matched) {
      return line;
    }
    remaining = stripped.line;
  }
  return remaining;
}

({String line, bool matches}) _stripActiveContainerPrefixes(
  String line,
  int quoteDepth,
  int listIndent,
  int innerQuoteDepth,
) {
  final outerQuoteStripped = _stripBlockQuoteDepth(line, quoteDepth);
  if (quoteDepth > 0 && outerQuoteStripped == line) {
    return (line: line, matches: false);
  }
  final listStripped = _stripListItemIndent(outerQuoteStripped, listIndent);
  final blankLineInList =
      listIndent > 0 && _isMarkdownBlankLine(outerQuoteStripped);
  if (listIndent > 0 &&
      listStripped == outerQuoteStripped &&
      !blankLineInList) {
    return (line: line, matches: false);
  }
  final innerQuoteStripped =
      _stripBlockQuoteDepth(listStripped, innerQuoteDepth);
  if (innerQuoteDepth > 0 && innerQuoteStripped == listStripped) {
    return (line: line, matches: false);
  }
  return (line: innerQuoteStripped, matches: true);
}

({String line, bool matched}) _stripOneBlockQuotePrefix(String line) {
  var markerIndex = 0;
  while (markerIndex < line.length &&
      markerIndex < 3 &&
      line[markerIndex] == ' ') {
    markerIndex++;
  }
  if (markerIndex >= line.length || line[markerIndex] != '>') {
    return (line: line, matched: false);
  }

  var consumed = markerIndex + 1;
  if (consumed < line.length &&
      (line[consumed] == ' ' || line[consumed] == '\t')) {
    consumed++;
  }
  return (
    // The Markdown parser strips each quote prefix into a new child line.
    // Any remaining tab therefore expands from column zero of that line.
    line: _expandLeadingTabs(line.substring(consumed), 0),
    matched: true,
  );
}

String _expandLeadingTabs(String line, int column) {
  var index = 0;
  final expanded = StringBuffer();
  while (index < line.length && (line[index] == ' ' || line[index] == '\t')) {
    if (line[index] == '\t') {
      final nextColumn = (column ~/ 4 + 1) * 4;
      expanded.write(List.filled(nextColumn - column, ' ').join());
      column = nextColumn;
    } else {
      expanded.write(' ');
      column++;
    }
    index++;
  }
  expanded.write(line.substring(index));
  return expanded.toString();
}

({String line, int indent}) _stripListItemPrefix(
  String line, {
  bool paragraphOpen = false,
  bool isInsideList = false,
  int sourceColumnOffset = 0,
}) {
  if (_thematicBreakLine.hasMatch(line)) return (line: line, indent: 0);

  var markerStart = 0;
  var markerStartIndent = 0;
  while (markerStart < line.length &&
      (line[markerStart] == ' ' || line[markerStart] == '\t')) {
    final nextIndent = _indentColumnsAfter(
          line,
          markerStart,
          sourceColumnOffset + markerStartIndent,
        ) -
        sourceColumnOffset;
    if (nextIndent > 3) return (line: line, indent: 0);
    markerStartIndent = nextIndent;
    markerStart++;
  }
  if (markerStart >= line.length) return (line: line, indent: 0);

  var markerEnd = markerStart;
  final first = line[markerStart];
  if (first == '-' || first == '+' || first == '*') {
    markerEnd++;
  } else if (RegExp(r'[0-9]').hasMatch(first)) {
    final numberStart = markerStart;
    while (markerEnd < line.length &&
        markerEnd - markerStart < 9 &&
        RegExp(r'[0-9]').hasMatch(line[markerEnd])) {
      markerEnd++;
    }
    if (paragraphOpen &&
        !isInsideList &&
        line.substring(numberStart, markerEnd) != '1') {
      return (line: line, indent: 0);
    }
    if (markerEnd >= line.length ||
        (line[markerEnd] != '.' && line[markerEnd] != ')')) {
      return (line: line, indent: 0);
    }
    markerEnd++;
  } else {
    return (line: line, indent: 0);
  }

  final markerIndent = markerStartIndent + markerEnd - markerStart;
  var separatorEnd = markerEnd;
  var separatorIndent = markerIndent;
  while (separatorEnd < line.length &&
      (line[separatorEnd] == ' ' || line[separatorEnd] == '\t')) {
    separatorIndent = _indentColumnsAfter(
          line,
          separatorEnd,
          sourceColumnOffset + separatorIndent,
        ) -
        sourceColumnOffset;
    separatorEnd++;
  }
  if (separatorEnd == markerEnd) {
    if (paragraphOpen || markerEnd < line.length) {
      return (line: line, indent: 0);
    }
    return (line: '', indent: markerIndent + 1);
  }

  final separatorColumns = separatorIndent - markerIndent;
  final consumesWholeSeparator = separatorColumns <= 4;
  final consumedSeparator =
      consumesWholeSeparator ? separatorEnd - markerEnd : 1;
  final consumed = markerEnd + consumedSeparator;
  final consumedIndent =
      consumesWholeSeparator ? separatorIndent : markerIndent + 1;
  var contentLine = line.substring(consumed);
  if (!consumesWholeSeparator) {
    if (line[markerEnd] == '\t') {
      final markerEndColumn = sourceColumnOffset + markerIndent;
      final tabWidth = _indentColumnsAfter(line, markerEnd, markerEndColumn) -
          markerEndColumn;
      contentLine = '${List.filled(tabWidth - 1, ' ').join()}$contentLine';
    }
    contentLine = _expandLeadingTabs(
      contentLine,
      sourceColumnOffset + consumedIndent,
    );
  }
  return (
    line: contentLine,
    indent: consumedIndent,
  );
}

String _stripListItemIndent(String line, int indent) {
  if (indent == 0) return line;
  var index = 0;
  var columns = 0;
  while (index < line.length &&
      columns < indent &&
      (line[index] == ' ' || line[index] == '\t')) {
    columns = _indentColumnsAfter(line, index, columns);
    index++;
  }
  if (columns < indent) return line;
  final remainingIndent = List.filled(columns - indent, ' ').join();
  return _expandLeadingTabs('$remainingIndent${line.substring(index)}', indent);
}

bool _isLazyListParagraphContinuation(String line, int listIndent) {
  final listContent = _stripListItemIndent(line, listIndent);
  final listLine = _stripListItemPrefix(
    listContent,
    paragraphOpen: true,
    isInsideList: true,
    sourceColumnOffset: listIndent,
  );
  if (listLine.indent > 0 ||
      _stripLeadingBlockQuotes(listLine.line).depth > 0 ||
      _openingFence(listLine.line) != null ||
      _isParagraphBoundaryLine(listLine.line, paragraphOpen: true)) {
    return false;
  }
  final htmlBlock = _htmlBlockStart(listLine.line);
  return htmlBlock == null || !htmlBlock.canInterruptParagraph;
}

int _leadingIndentColumns(String line) {
  var index = 0;
  var columns = 0;
  while (index < line.length && (line[index] == ' ' || line[index] == '\t')) {
    columns = _indentColumnsAfter(line, index, columns);
    index++;
  }
  return columns;
}

int _indentColumnsAfter(String line, int index, int columns) {
  return line[index] == '\t' ? (columns ~/ 4 + 1) * 4 : columns + 1;
}

String _stripUpTo3Spaces(String line) {
  var i = 0;
  while (i < line.length && i < 3 && line[i] == ' ') {
    i++;
  }
  return line.substring(i);
}

bool _isClosingFenceLine(String line, String char, int openingLength) {
  // CommonMark allows 1-3 leading spaces on closing fences too.
  final stripped = _stripUpTo3Spaces(line).trimRight();
  if (stripped.isEmpty || stripped[0] != char) return false;
  var run = 0;
  while (run < stripped.length && stripped[run] == char) {
    run++;
  }
  if (run < openingLength) return false;
  // Closing fences cannot carry an info string (CommonMark).
  return stripped.substring(run).trim().isEmpty;
}

/// Returns a [PreConfig] for code blocks that adapts to dark/light mode.
///
/// - Dark mode: uses a dark grey background (`0xff555555`).
/// - Light mode: uses a light grey background (`0xffeff1f3`).
///
/// Mermaid code blocks (```` ```mermaid ````) are rendered using
/// [MermaidRenderWidget].
///
/// HTML code blocks (```` ```html ````) are rendered using
/// [HtmlCodeBlockWidget] which shows an HTML card (with full-screen preview
/// and view-code actions) instead of the raw source by default; the user
/// must tap the "查看代码" button to see the raw HTML source.
///
/// All other code blocks are rendered using [CodeBlockSourceView] which
/// provides a unified code display area with line numbers, copy / save /
/// wrap toolbar buttons and the language label (from the opening fence)
/// in the top-left corner.
PreConfig codeBlockPreConfig({
  required bool isDark,
  bool isStreaming = false,
  String? streamingText,
}) {
  final baseConfig = PreConfig(
    theme: draculaTheme,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xff555555) : const Color(0xffeff1f3),
      borderRadius: BorderRadius.all(Radius.circular(8.0)),
    ),
  );
  final streamingFenceInfo = isStreaming && streamingText != null
      ? _unclosedFenceInfo(streamingText)
      : null;
  final mermaidFenceCount = streamingFenceInfo?.mermaidFenceCount ?? 0;
  var nextMermaidFenceIndex = 0;
  // Use a builder so mermaid and html code blocks get rendered via WebView
  // while all other code blocks still get syntax highlighting.
  return PreConfig(
    theme: baseConfig.theme,
    decoration: baseConfig.decoration,
    margin: baseConfig.margin,
    padding: baseConfig.padding,
    textStyle: baseConfig.textStyle,
    styleNotMatched: baseConfig.styleNotMatched,
    language: baseConfig.language,
    builder: (code, language) {
      int? mermaidFenceIndex;
      if (language.trim().toLowerCase() == 'mermaid') {
        if (mermaidFenceCount > 0 &&
            nextMermaidFenceIndex >= mermaidFenceCount) {
          nextMermaidFenceIndex = 0;
        }
        mermaidFenceIndex = nextMermaidFenceIndex++;
      }
      return _buildCodeBlock(
        code,
        language,
        baseConfig,
        isStreaming: isStreaming,
        streamingText: streamingText,
        mermaidFenceIndex: mermaidFenceIndex,
        fenceInfo: streamingFenceInfo,
      );
    },
  );
}

/// Cached [MarkdownGenerator] pre-configured with LaTeX support.
///
/// Adds the [LatexSyntax] parser and [latexGenerator] so that
/// `$...$` and `$$...$$` expressions in markdown content are
/// rendered as mathematical formulas.
///
/// Adds the [BrSyntax] parser so that `<br>` in table cells (and
/// paragraphs) renders as a line break instead of literal text.
///
/// Adds the [USyntax] parser and [uGenerator] so that `<u>text</u>`
/// renders as underlined text instead of literal characters.
///
/// Created once and reused to avoid re-allocation on every
/// [MarkdownWidget] build.
final MarkdownGenerator markdownGenerator = MarkdownGenerator(
  inlineSyntaxList: [LatexSyntax(), BrSyntax(), USyntax()],
  generators: [latexGenerator, uGenerator],
);

/// Counts case-insensitive occurrences of [lowerQuery] in [text].
///
/// [lowerQuery] must already be lower-cased. Used to keep search-match
/// ordinals aligned across the multiple markdown widgets a single message is
/// split into (text segments around tool calls).
int countOccurrences(String text, String lowerQuery) {
  if (lowerQuery.isEmpty) return 0;
  final lower = text.toLowerCase();
  var count = 0;
  var start = 0;
  while (true) {
    final idx = lower.indexOf(lowerQuery, start);
    if (idx == -1) break;
    count++;
    start = idx + lowerQuery.length;
  }
  return count;
}

/// Returns [text] with the markdown constructs whose content is never
/// rendered as visited text removed: fenced code blocks (also inside
/// blockquotes), inline code spans and display math (`$$...$$`).
///
/// Chat search counts matches on the raw message text, but the render-time
/// highlight generator can only paint occurrences inside visited text nodes
/// — code blocks, inline code and math are rendered as dedicated widgets and
/// never visited as text. Without stripping, those raw matches would shift
/// the highlight ordinals (the orange "current" match would land on the
/// wrong occurrence) and overstate the match counter. Line structure is
/// preserved so the occurrence ORDER matches the rendered text's order.
///
/// Known limitations (matches there keep shifting ordinals, an uncommon
/// case for real search queries): matches inside link/image URLs, inline
/// `$...$` math, and 4-space-indented code blocks are still not stripped
/// (the renderer does not visit them as text either, but this function does
/// not detect them).
String stripSearchIrrelevantMarkdown(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  final kept = <String>[];
  var inFence = false;
  String? fenceChar;
  var fenceLength = 0;
  for (final line in lines) {
    final trimmed = line.trimRight();
    // Fence detection ignores a leading blockquote marker (">"), so fences
    // inside blockquotes are stripped too — matching the renderer, which
    // parses them as code blocks.
    final withoutQuote = _stripBlockquoteMarker(trimmed);
    if (inFence) {
      if (_isClosingFenceLine(withoutQuote, fenceChar!, fenceLength)) {
        inFence = false;
        // Keep the line count so later occurrences keep their relative
        // order; the fence content itself is dropped.
        kept.add('');
      }
      // Content inside the fence is dropped.
    } else {
      final opening = _openingFence(withoutQuote);
      if (opening != null) {
        inFence = true;
        fenceChar = opening.fenceChar;
        fenceLength = opening.fenceLength;
        kept.add(''); // The opening fence line is replaced by a blank line.
      } else {
        kept.add(line);
      }
    }
  }
  if (inFence) {
    // Unclosed trailing fence: drop everything after its opening fence.
    kept.add('');
  }
  final withoutFences = kept.join('\n');
  // Inline pass: drop inline code spans and display math. The renderer
  // inline-parses each paragraph separately, so the code-span scan is split
  // per paragraph (a span can never cross a blank line). Matches are walked
  // manually instead of replaceAll because the parser refuses to start a
  // span right after a backtick — a regex scan would otherwise strip prose
  // on ragged backtick runs. Unmatched backticks/`$` are left alone: the
  // renderer treats them as literal text too, so search and rendering stay
  // consistent.
  final paragraphs = withoutFences.split('\n\n');
  final inlineStripped = paragraphs.map((paragraph) {
    final buffer = StringBuffer();
    var last = 0;
    for (final match in _codeSpanPattern.allMatches(paragraph)) {
      if (match.start > 0 && paragraph[match.start - 1] == '`') continue;
      buffer.write(paragraph.substring(last, match.start));
      last = match.end;
    }
    buffer.write(paragraph.substring(last));
    return buffer.toString();
  }).join('\n\n');
  return inlineStripped.replaceAll(_displayMathPattern, '');
}

/// The markdown parser's inline code pattern (see `CodeSyntax`): a run of
/// backticks, non-greedy content ending in a non-backtick, then a
/// same-length run of backticks.
final RegExp _codeSpanPattern = RegExp(
  r'(`+(?!`))((?:.|\n)*?[^`])\1(?!`)',
);

/// Display math (`$$...$$`) pattern used by the search stripper.
final RegExp _displayMathPattern = RegExp(r'\$\$[\s\S]*?\$\$');

/// Strips one leading blockquote marker (`>`), with up to 3 leading spaces
/// and an optional space after it, from [line]. Returns [line] unchanged when
/// it is not a blockquote line.
String _stripBlockquoteMarker(String line) {
  var i = 0;
  // CommonMark allows up to 3 leading spaces before the '>'.
  while (i < line.length && i < 3 && line[i] == ' ') {
    i++;
  }
  if (i >= line.length || line[i] != '>') return line;
  i++; // consume '>'
  if (i < line.length && line[i] == ' ') i++; // optional space after '>'
  return line.substring(i);
}

/// A [TextNode] that highlights every case-insensitive occurrence of the
/// search query within its own text.
///
/// The surrounding markdown structure (headings, emphasis, links, math, ...)
/// is preserved because only the text node's content is split into
/// highlighted spans.
///
/// [startGlobalIndex] is the global index (into the search's flat match list)
/// of the first occurrence inside this node; the occurrence whose global
/// index equals [currentGlobalIndex] is drawn as the "current" match.
class SearchHighlightTextNode extends SpanNode {
  final String text;
  final String lowerQuery;
  final int startGlobalIndex;
  final int currentGlobalIndex;

  SearchHighlightTextNode({
    required this.text,
    required this.lowerQuery,
    required this.startGlobalIndex,
    required this.currentGlobalIndex,
    required TextStyle? baseStyle,
  }) {
    style = baseStyle;
  }

  @override
  InlineSpan build() {
    final effectiveStyle = style?.merge(parentStyle);
    // An empty query must not loop forever (indexOf('') matches everywhere).
    if (lowerQuery.isEmpty) {
      return TextSpan(text: text, style: effectiveStyle);
    }
    final spans = <InlineSpan>[];
    final lower = text.toLowerCase();
    var start = 0;
    var ordinal = 0;
    while (true) {
      final idx = lower.indexOf(lowerQuery, start);
      if (idx == -1) break;
      if (idx > start) {
        spans.add(
          TextSpan(text: text.substring(start, idx), style: effectiveStyle),
        );
      }
      final isCurrent = startGlobalIndex + ordinal == currentGlobalIndex;
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + lowerQuery.length),
          style: effectiveStyle?.copyWith(
            backgroundColor: isCurrent ? Colors.orangeAccent : Colors.yellow,
            color: Colors.black87,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
      ordinal++;
      start = idx + lowerQuery.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: effectiveStyle));
    }
    return TextSpan(children: spans);
  }
}

/// Renders inline code the same way the library's [CodeNode] does, but as a
/// plain (non-element) span that never accepts child text nodes.
///
/// The library's [CodeNode] is an [ElementNode], so its content is still
/// visited — which would make the search generator count (and try to
/// highlight) text inside inline code or fenced code blocks even though that
/// text is never painted. Code content is rendered by dedicated widgets, so
/// it must never contribute to the highlight ordinals.
class _SearchCodeNode extends SpanNode {
  final String text;

  _SearchCodeNode(this.text, CodeConfig codeConfig) {
    style = codeConfig.style;
  }

  @override
  InlineSpan build() => TextSpan(text: text, style: style?.merge(parentStyle));
}

/// Builds a [MarkdownGenerator] that renders the search [query]'s occurrences
/// highlighted inside the markdown text while keeping the markdown structure
/// intact.
///
/// Matches are matched again inside every text node, so raw offsets do not
/// need to survive markdown parsing. [messageFirstMatchIndex] is the global
/// index (into the search's flat match list) of this message's first match;
/// [occurrenceOffset] is how many occurrences appeared in earlier text
/// segments of the same message. Together they align the "current" (orange)
/// highlight with the navigation cursor across messages and segments.
MarkdownGenerator buildSearchMarkdownGenerator({
  required String query,
  required int messageFirstMatchIndex,
  required int occurrenceOffset,
  required int currentMatchIndex,
}) {
  final lowerQuery = query.toLowerCase();
  var counter = occurrenceOffset;
  return MarkdownGenerator(
    inlineSyntaxList: [LatexSyntax(), BrSyntax()],
    generators: [
      latexGenerator,
      // Inline/fenced code must not be counted or highlighted: the library's
      // CodeNode accepts (and discards) child text nodes, which would advance
      // the ordinal counter for content that can never be painted.
      SpanNodeGeneratorWithTag(
        tag: MarkdownTag.code.name,
        generator: (e, config, visitor) =>
            _SearchCodeNode(e.textContent, config.code),
      ),
    ],
    textGenerator: (node, config, visitor) {
      if (node is! m.Text) return null;
      final count = countOccurrences(node.text, lowerQuery);
      final startIndex = counter;
      counter += count;
      if (count == 0) return null;
      return SearchHighlightTextNode(
        text: node.text,
        lowerQuery: lowerQuery,
        startGlobalIndex: messageFirstMatchIndex + startIndex,
        currentGlobalIndex: currentMatchIndex,
        baseStyle: config.p.textStyle,
      );
    },
  );
}

/// A custom [H1Config] that removes the bottom divider line.
/// Accepts an optional [style] to preserve dark-mode text color.
class NoDividerH1Config extends H1Config {
  const NoDividerH1Config({super.style});

  @override
  HeadingDivider? get divider => null;
}

/// A custom [H2Config] that removes the bottom divider line.
/// Accepts an optional [style] to preserve dark-mode text color.
class NoDividerH2Config extends H2Config {
  const NoDividerH2Config({super.style});

  @override
  HeadingDivider? get divider => null;
}

/// A custom [H3Config] that removes the bottom divider line.
/// Accepts an optional [style] to preserve dark-mode text color.
class NoDividerH3Config extends H3Config {
  const NoDividerH3Config({super.style});

  @override
  HeadingDivider? get divider => null;
}

/// Builds a [MarkdownConfig] suitable for the current brightness.
///
/// [isDark] controls whether dark or default markdown styling is used.
/// The [PreConfig] for code blocks is overridden to use [draculaTheme]
/// with a background colour that matches the brightness.
///
/// Headers h1/h2/h3 use custom configs that remove the bottom divider
/// line (light gray `---` under each heading), while the thematic break
/// (`---` in markdown) remains unaffected. Dark-mode text colour is
/// preserved by passing the dark config's style when applicable.

/// Wraps a [Table] widget in a horizontally scrollable container so that
/// wide tables can be dragged/scrolled left-right without affecting the
/// layout of other markdown content. The container clips to prevent
/// overflow beyond the chat bubble boundary.
Widget _wrapTableWithHorizontalScroll(Widget child) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.hardEdge,
    child: child,
  );
}

MarkdownConfig buildMarkdownConfig({
  required bool isDark,
  bool isStreaming = false,
  String? streamingText,
}) {
  final base =
      isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
  return base.copy(configs: [
    codeBlockPreConfig(
      isDark: isDark,
      isStreaming: isStreaming,
      streamingText: streamingText,
    ),
    TableConfig(
      wrapper: _wrapTableWithHorizontalScroll,
    ),
    if (isDark) ...[
      NoDividerH1Config(style: H1Config.darkConfig.style),
      NoDividerH2Config(style: H2Config.darkConfig.style),
      NoDividerH3Config(style: H3Config.darkConfig.style),
    ] else ...[
      const NoDividerH1Config(),
      const NoDividerH2Config(),
      const NoDividerH3Config(),
    ],
  ]);
}

/// Builds the [MarkdownConfig] used to render a single chat message.
///
/// Only the message that is currently being generated
/// ([messageId] == [streamingMsgId] while [conversationIsStreaming]) uses
/// the streaming config, which shows a loading placeholder for mermaid
/// code blocks. Every other message uses the regular config so that
/// already-rendered mermaid diagrams keep their rendered state and are
/// NOT rebuilt (or shown as "正在生成...") when a new message starts
/// streaming.
///
/// [streamingText] is the message's raw text at the current stream
/// position; it lets the streaming config render mermaid blocks whose
/// fence has already closed (only the still-open trailing block keeps the
/// loading placeholder).
MarkdownConfig buildMessageMarkdownConfig({
  required bool isDark,
  required bool conversationIsStreaming,
  required String? streamingMsgId,
  required String messageId,
  String? streamingText,
}) {
  final isThisMessageStreaming =
      conversationIsStreaming && streamingMsgId == messageId;
  return buildMarkdownConfig(
    isDark: isDark,
    isStreaming: isThisMessageStreaming,
    streamingText: isThisMessageStreaming ? streamingText : null,
  );
}
