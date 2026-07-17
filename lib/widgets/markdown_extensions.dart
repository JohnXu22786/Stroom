import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'code_block_source_widget.dart';
import 'html_code_block_widget.dart';
import 'mermaid_render_widget.dart';

/// Tag used by the LaTeX custom generator.
const _latexTag = 'latex';

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

    final latex = Math.tex(
      content,
      textStyle: style,
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

/// Builds a code block widget for the given [code] and [language].
///
/// If [language] is `'mermaid'`, renders the code using [MermaidRenderWidget]
/// (or [CodeBlockSourceView] when [isStreaming] is true, to avoid repeatedly
/// reloading the WebView during incremental streaming updates).
/// If [language] is `'html'`, renders the code using [HtmlCodeBlockWidget]
/// (which shows the raw HTML source without inline rendering; the user must
/// tap the full-screen button to render the HTML in a dialog).
/// Otherwise, renders the code using [CodeBlockSourceView] which provides
/// a unified code display area with line numbers and a wrap toggle (matching
/// the HTML code block's UI form).
Widget _buildCodeBlock(
  String code,
  String language,
  PreConfig preConfig, {
  bool isStreaming = false,
}) {
  if (language == 'mermaid') {
    // During streaming, show the raw source code instead of repeatedly
    // reloading the WebView on each incremental update. The Mermaid
    // rendering happens after streaming completes.
    if (isStreaming) {
      return CodeBlockSourceView(code: code);
    }
    return MermaidRenderWidget(mermaidCode: code);
  }

  if (language == 'html') {
    return HtmlCodeBlockWidget(htmlCode: code);
  }

  // Fallback: render using the unified source code display widget
  // ([CodeBlockSourceView]) with line numbers, same as the HTML code
  // block style.
  return CodeBlockSourceView(code: code);
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
/// [HtmlCodeBlockWidget] to show the raw HTML source without inline
/// rendering; the user must tap the full-screen button to render the
/// HTML in a dialog.
///
/// All other code blocks are rendered using [CodeBlockSourceView] which
/// provides a unified code display area with line numbers and a wrap
/// toggle, matching the HTML code block's UI form.
PreConfig codeBlockPreConfig({required bool isDark, bool isStreaming = false}) {
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
    builder: (code, language) =>
        _buildCodeBlock(code, language, baseConfig, isStreaming: isStreaming),
  );
}

/// Cached [MarkdownGenerator] pre-configured with LaTeX support.
///
/// Adds the [LatexSyntax] parser and [latexGenerator] so that
/// `$...$` and `$$...$$` expressions in markdown content are
/// rendered as mathematical formulas.
///
/// Created once and reused to avoid re-allocation on every
/// [MarkdownWidget] build.
final MarkdownGenerator markdownGenerator = MarkdownGenerator(
  inlineSyntaxList: [LatexSyntax()],
  generators: [latexGenerator],
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

MarkdownConfig buildMarkdownConfig({required bool isDark, bool isStreaming = false}) {
  final base =
      isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
  return base.copy(configs: [
    codeBlockPreConfig(isDark: isDark, isStreaming: isStreaming),
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
