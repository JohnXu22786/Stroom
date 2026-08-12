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
  TextStyle get style =>
      parentStyle?.merge(_defaultUStyle) ?? _defaultUStyle;
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
/// Adds the [USyntax] parser and [uGenerator] so that `<u>text</u>`
/// renders as underlined text instead of literal characters.
///
/// Created once and reused to avoid re-allocation on every
/// [MarkdownWidget] build.
final MarkdownGenerator markdownGenerator = MarkdownGenerator(
  inlineSyntaxList: [LatexSyntax(), BrSyntax(), USyntax()],
  generators: [latexGenerator, uGenerator],
);

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
