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
const double _displayMathScaleFactor = 1.5;

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

  static const int _ltCharCode = 0x3C; // '<'

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    parser.addNode(m.Element.text('br', ''));
    return true;
  }
}

/// [SpanNodeGeneratorWithTag] that creates [LatexNode] instances when
/// the markdown parser encounters a LaTeX element.
final SpanNodeGeneratorWithTag latexGenerator = SpanNodeGeneratorWithTag(
  tag: _latexTag,
  generator: (e, config, visitor) =>
      LatexNode(e.attributes, e.textContent, config),
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
/// a unified code display area with line numbers, a wrap toggle and the
/// language label in the top-left corner.
Widget _buildCodeBlock(
  String code,
  String language,
  PreConfig preConfig, {
  bool isStreaming = false,
  String? streamingText,
}) {
  if (language.toLowerCase() == 'mermaid') {
    // During streaming, show a loading animation only while the block's
    // fence is still open. The markdown parser strips backtick fences from
    // the code content and swallows the rest of the document into an
    // unclosed fence, so completion is detected by comparing the builder's
    // code with the still-open trailing tail (see [unclosedFenceTail]).
    // Callers that cannot provide the streaming text (streamingText ==
    // null) keep the legacy behavior: loading for the whole stream.
    if (isStreaming &&
        (streamingText == null ||
            isStreamingMermaidTail(code, streamingText))) {
      return const _MermaidLoadingWidget();
    }
    return MermaidRenderWidget(mermaidCode: code);
  }

  if (language.toLowerCase() == 'html') {
    // The same fence-completion check as mermaid: the HTML card shows its
    // "正在生成中" state only while the block's fence is still open, so a
    // closed block renders as a finished card even mid-stream.
    final stillGenerating = isStreaming &&
        (streamingText == null || isStreamingMermaidTail(code, streamingText));
    return HtmlCodeBlockWidget(
      htmlCode: code,
      language: language,
      isStreaming: stillGenerating,
    );
  }

  // Fallback: render using the unified source code display widget
  // ([CodeBlockSourceView]) with line numbers, a wrap toggle and the
  // language label (from the opening fence's info string).
  return CodeBlockSourceView(code: code, language: language);
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
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  var inFence = false;
  String? fenceChar;
  var fenceLength = 0;
  var tailStart = 0;
  var offset = 0;
  for (final line in lines) {
    final trimmed = line.trimRight();
    if (inFence) {
      if (_isClosingFenceLine(trimmed, fenceChar!, fenceLength)) {
        inFence = false;
      }
    } else {
      final opening = _openingFence(trimmed);
      if (opening != null) {
        inFence = true;
        fenceChar = opening.fenceChar;
        fenceLength = opening.fenceLength;
        // Content starts after the fence line and its newline.
        tailStart = offset + line.length + 1;
      }
    }
    offset += line.length + 1;
  }
  if (!inFence) return null;
  return tailStart >= normalized.length ? '' : normalized.substring(tailStart);
}

/// True when [code] is the still-open trailing fenced code block of the
/// streaming [text] (see [unclosedFenceTail]).
///
/// [text] must be the raw text that the markdown parser is rendering;
/// pass `null` when the text is unavailable (falls back to the legacy
/// always-loading behavior in [_buildCodeBlock]).
///
/// Known limitation: the comparison is content-based, so a CLOSED block
/// whose trimmed content is identical to the still-open tail's content
/// (e.g. two identical diagrams in one message where the second is still
/// streaming) keeps the loading placeholder until the open fence closes
/// or the stream ends. This is transient and rare; the builder has no
/// positional information to distinguish the blocks.
bool isStreamingMermaidTail(String code, String? text) {
  if (text == null || text.isEmpty) return false;
  final tail = unclosedFenceTail(text);
  return tail != null && code.trim() == tail.trim();
}

({String fenceChar, int fenceLength})? _openingFence(String line) {
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
  return (fenceChar: char, fenceLength: run);
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
/// provides a unified code display area with line numbers, a wrap toggle
/// and the language label (from the opening fence) in the top-left corner.
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
    builder: (code, language) => _buildCodeBlock(
      code,
      language,
      baseConfig,
      isStreaming: isStreaming,
      streamingText: streamingText,
    ),
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
/// Created once and reused to avoid re-allocation on every
/// [MarkdownWidget] build.
final MarkdownGenerator markdownGenerator = MarkdownGenerator(
  inlineSyntaxList: [LatexSyntax(), BrSyntax()],
  generators: [latexGenerator],
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
