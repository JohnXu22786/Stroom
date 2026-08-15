import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stroom/utils/system_pick_utils.dart';

/// A reusable widget that displays source code with line numbers and a
/// toolbar of copy / save / wrap buttons, providing a consistent "code
/// display area" UI form that matches what [HtmlCodeBlockWidget] uses.
///
/// ## Usage
///
/// Use this widget anywhere you need to show source code with line numbers:
/// - Plain code blocks in markdown rendering
/// - Mermaid's "show source code" toggle view
/// - HTML code block display
///
/// The built-in toolbar (top-right) holds, from left to right: a copy
/// button (copies the whole block, showing a fading checkmark feedback),
/// a save button (opens the system file save panel to pick location, name
/// and format), and the wrap toggle. Additional action buttons (e.g.
/// "full screen" for HTML, "view chart" for Mermaid) can be passed via
/// [actionButtons] and appear to the right of the wrap toggle.
class CodeBlockSourceView extends StatefulWidget {
  /// The source code to display.
  final String code;

  /// Optional fixed height. If null, uses adaptive height capped at
  /// 15 visible lines.
  final double? height;

  /// The language of the code (the info string after the opening fence,
  /// e.g. `html`, `python`, `mermaid`). Shown as a small label in the
  /// top-left corner. Hidden when empty (plain fences without a language).
  final String language;

  /// Optional additional action buttons placed in the top-right button
  /// row, to the right of the built-in wrap toggle.
  final List<Widget> actionButtons;

  /// True while this code block is the one currently being generated in a
  /// streaming reply (its fence is still open). While true, the block pins
  /// its scroll position to the bottom edge as the code grows; when the
  /// block finishes generating (this flips back to false) it animates back
  /// to the top so the finished code is read from the start.
  ///
  /// The user can interrupt the auto-scroll at any time: a manual scroll
  /// pauses it and shows a scroll-to-bottom button in the bottom-right
  /// corner; tapping the button resumes the auto-scroll. The button is
  /// hidden while the auto-scroll is engaged and once generation is
  /// complete. This mirrors the chat list's auto-scroll behavior.
  final bool isStreaming;

  const CodeBlockSourceView({
    super.key,
    required this.code,
    this.height,
    this.language = '',
    this.actionButtons = const [],
    this.isStreaming = false,
  });

  @override
  State<CodeBlockSourceView> createState() => _CodeBlockSourceViewState();
}

class _CodeBlockSourceViewState extends State<CodeBlockSourceView> {
  bool _wrapEnabled = false;

  /// Scroll controller of the vertical code-area scroll view, used by the
  /// streaming auto-scroll logic.
  final ScrollController _scrollController = ScrollController();

  /// Whether the code block is currently pinned to its bottom edge while
  /// its code is being generated (mirrors the chat list's auto-scroll:
  /// enabled at the bottom, disabled the moment the user scrolls away).
  bool _autoScrollEnabled = false;

  /// Whether the scroll-to-bottom button (bottom-right corner) is shown.
  /// Visible only while the block is still being generated AND the
  /// auto-scroll has been interrupted by a manual scroll.
  bool _showScrollButton = false;

  /// True while the user is touching/dragging the code area's vertical
  /// scroll view. The auto-scroll follow must not fight a finger scroll.
  bool _userIsDragging = false;

  /// Set once the block has finished generating (its fence closed). A
  /// closed fence can never reopen, so a finished block must never
  /// re-engage the auto-scroll. Only the content-based tail comparison can
  /// mislabel a closed block as generating (two identical blocks, see
  /// [isStreamingMermaidTail]); the latch keeps such a block static.
  ///
  /// Known limitation (documented in [isStreamingMermaidTail]): a block
  /// BORN already mislabeled — built fresh with isStreaming=true while
  /// actually closed, when two identical blocks arrive in one build — is
  /// indistinguishable from a real generating block and cannot be latched
  /// (there was no completion transition to observe).
  bool _hasCompleted = false;

  /// True while this block is actually the one currently being generated:
  /// the widget is marked streaming AND the block has not already finished
  /// generating (a closed fence can never reopen, so once completed a block
  /// is static forever — only the content-based tail comparison can
  /// mislabel it as generating again, see [isStreamingMermaidTail]).
  bool get _isGenerating => widget.isStreaming && !_hasCompleted;

  /// Distance from the bottom within which the code block counts as "at
  /// the bottom": the auto-scroll stays engaged and the scroll-to-bottom
  /// button stays hidden. Mirrors the chat list's at-bottom window, scaled
  /// down for the denser code content (about two code lines).
  static const double _atBottomWindowPx = 40;

  /// Duration and curve of the non-linear scroll back to the top when a
  /// code block finishes generating.
  static const Duration _returnToTopDuration = Duration(milliseconds: 300);
  static const Curve _returnToTopCurve = Curves.easeOutCubic;

  /// True while the copy button shows the checkmark feedback.
  bool _showCopyFeedback = false;

  /// Fires to revert the copy button from the checkmark back to the copy
  /// icon after a 1s hold.
  Timer? _copyFeedbackTimer;

  /// Guards against opening the save dialog twice from double taps.
  bool _isSaving = false;

  /// Monotonic copy-tap counter. A clipboard failure from an EARLIER tap
  /// whose write resolved late must not revert the checkmark or snackbar
  /// when a newer tap has already taken over.
  int _copyTapGeneration = 0;

  /// Cursor width passed to the code [SelectableText]. [RenderEditable]
  /// wraps its text at `available width - (_kCaretGap + cursorWidth)`, so the
  /// wrap-mode measurement below subtracts `1.0 + _selectableCursorWidth` to
  /// stay in lock-step with the actual render. Keep both in sync if this
  /// ever changes.
  static const double _selectableCursorWidth = 2.0;

  /// How long the copy checkmark stays visible before fading back.
  static const Duration _copyFeedbackHold = Duration(seconds: 1);

  /// Fade duration for the copy/check icon swap.
  static const Duration _copyFeedbackFade = Duration(milliseconds: 200);

  /// Maps a code language (the opening fence's info string) to its most
  /// common file extension. Unknown languages fall back to 'txt'.
  static const Map<String, String> _languageExtensions = {
    'python': 'py',
    'py': 'py',
    'javascript': 'js',
    'js': 'js',
    'typescript': 'ts',
    'ts': 'ts',
    'dart': 'dart',
    'java': 'java',
    'c': 'c',
    'cpp': 'cpp',
    'c++': 'cpp',
    'csharp': 'cs',
    'c#': 'cs',
    'go': 'go',
    'rust': 'rs',
    'ruby': 'rb',
    'php': 'php',
    'swift': 'swift',
    'kotlin': 'kt',
    'sql': 'sql',
    'html': 'html',
    'css': 'css',
    'json': 'json',
    'xml': 'xml',
    'yaml': 'yaml',
    'yml': 'yml',
    'markdown': 'md',
    'md': 'md',
    'bash': 'sh',
    'sh': 'sh',
    'shell': 'sh',
    'powershell': 'ps1',
    'ps1': 'ps1',
    'mermaid': 'mmd',
    'text': 'txt',
    'plaintext': 'txt',
  };

  /// The formats offered in the save dialog: the language's own extension
  /// first (the default), then the generic text formats.
  List<String> _saveExtensions() {
    final primary = _primaryExtension();
    return {primary, 'txt', 'md'}.toList();
  }

  String _primaryExtension() =>
      _languageExtensions[widget.language.toLowerCase()] ?? 'txt';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_reconcileScrollState);
    if (widget.isStreaming) {
      // Entering mid-stream (e.g. page re-entry while a block streams):
      // engage the auto-scroll. The first ScrollMetricsNotification after
      // the view attaches lands the block at the bottom edge.
      _autoScrollEnabled = true;
    }
  }

  @override
  void didUpdateWidget(CodeBlockSourceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming) {
      if (!oldWidget.isStreaming) {
        // The block just became (or was re-labeled as) the one currently
        // being generated. A block that was static and is now marked
        // generating with UNCHANGED code can only be the content-based
        // mislabel — a closed block whose content matches a later open
        // tail (see isStreamingMermaidTail); a real block that starts
        // generating always arrives with the tail's new content. A
        // completed block never re-engages either (a closed fence can
        // never reopen). Both cases latch the block as finished so it
        // stays static.
        if (_hasCompleted || widget.code == oldWidget.code) {
          _hasCompleted = true;
        } else {
          _autoScrollEnabled = true;
          _showScrollButton = false;
          // The follow's extent tracker belongs to the previous session
          // (if any) — reset so the next content growth re-pins.
          _lastFollowContentExtent = null;
        }
      }
      // Content growth needs no explicit handling: it always goes through
      // layout, and [_followContentGrowth] re-pins from the resulting
      // ScrollMetricsNotification.
    } else if (oldWidget.isStreaming) {
      // The block finished generating. If the auto-scroll session is still
      // engaged (the user never interrupted it), return to the top so the
      // finished code is read from the start. The scroll-to-bottom button
      // is always hidden once generation is complete.
      _hasCompleted = true;
      final returnToTop = _autoScrollEnabled && !_userIsDragging;
      _autoScrollEnabled = false;
      _showScrollButton = false;
      if (returnToTop) _animateToTop();
    }
  }

  @override
  void dispose() {
    _copyFeedbackTimer?.cancel();
    _scrollController.removeListener(_reconcileScrollState);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xff555555) : const Color(0xffeff1f3);
    final textColor =
        isDark ? const Color(0xfff8f8f2) : const Color(0xff000000);
    final borderColor = cs.outlineVariant;

    const lineHeight = 13.0 * 1.5; // fontSize * height

    if (widget.height != null) {
      return _buildSizedCodeBlock(
        height: widget.height!,
        bgColor: bgColor,
        textColor: textColor,
        borderColor: borderColor,
        isDark: isDark,
      );
    }

    // Adaptive height: cap at 15 visible lines so long code blocks do not
    // grow unbounded; shorter blocks stay compact (fit to their content).
    const verticalPadding = 40.0 + 12.0;
    const maxVisibleLines = 15;
    final lineCount = widget.code.isEmpty ? 0 : widget.code.split('\n').length;
    final contentHeight =
        lineCount > 0 ? lineCount * lineHeight + verticalPadding : 40.0;
    final maxAllowedHeight = maxVisibleLines * lineHeight + verticalPadding;
    final effectiveMax = maxAllowedHeight < 40.0 ? 40.0 : maxAllowedHeight;
    final adaptiveHeight = contentHeight.clamp(40.0, effectiveMax).toDouble();

    return _buildSizedCodeBlock(
      height: adaptiveHeight,
      bgColor: bgColor,
      textColor: textColor,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildSizedCodeBlock({
    required double height,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.code.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: SelectableText(
                        '(empty)',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: textColor,
                          height: 1.5,
                        ),
                      ),
                    )
                  : _buildCodeContent(textColor, isDark),
            ),
            // Language label (top-left): the info string from the
            // opening fence (e.g. `html`, `python`), shown as-is.
            // Hidden while the code is empty so it cannot cover the
            // "(empty)" placeholder.
            if (widget.language.isNotEmpty && widget.code.isNotEmpty)
              Positioned(
                top: 8,
                left: 12,
                child: _buildLanguageLabel(),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: _buildButtonRow(),
            ),
            // Scroll-to-bottom overlay button (bottom-right corner), shown
            // only while the block is still being generated AND the user
            // has interrupted the auto-scroll.
            if (_showScrollButton && _isGenerating)
              Positioned(
                right: 8,
                bottom: 8,
                child: _buildScrollToBottomButton(),
              ),
          ],
        ),
      ),
    );
  }

  /// Streaming auto-scroll state machine (mirrors the chat list's):
  ///
  /// - While the block is being generated, [_autoScrollEnabled] stays
  ///   engaged as long as the user is at the bottom; content growth
  ///   re-pins the scroll position to the bottom edge.
  /// - A manual scroll away from the bottom disables the auto-scroll and
  ///   surfaces the scroll-to-bottom button.
  /// - Scrolling back to the bottom re-engages the auto-scroll and hides
  ///   the button; tapping the button jumps to the bottom and re-engages.
  ///
  /// Programmatic jumps (the follow itself, the resume tap) settle at the
  /// bottom, so they keep the auto-scroll engaged — only user scrolls can
  /// interrupt it.

  /// Recomputes the auto-scroll state from the CURRENT scroll metrics
  /// ("is the user at the bottom?"), not from the last scroll action.
  ///
  /// Scroll events can be swallowed or never fire at all for metric-only
  /// changes — a content shrink (wrap toggle, shorter code) clamps the
  /// position without notifying the controller listeners — so the state is
  /// reconciled both from scroll events (the controller listener) and from
  /// [ScrollMetricsNotification] (which fires for every metric change).
  /// Idempotent: no setState when nothing changed.
  void _reconcileScrollState() {
    // The auto-scroll session only exists while the block is the one
    // being generated. After completion the block scrolls like any
    // static code block.
    if (!_isGenerating) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final isAtBottom = (pos.maxScrollExtent - pos.pixels) <= _atBottomWindowPx;
    if (isAtBottom) {
      if (_showScrollButton || !_autoScrollEnabled) {
        setState(() {
          _showScrollButton = false;
          if (_scrollController.hasClients &&
              _scrollController.position.maxScrollExtent > 0) {
            _autoScrollEnabled = true;
          }
        });
      }
    } else {
      if (!_showScrollButton || _autoScrollEnabled) {
        setState(() {
          _autoScrollEnabled = false;
          _showScrollButton = true;
        });
      }
    }
  }

  /// Tracks user drags on the code area's scroll views. Only the
  /// drag-initiating [ScrollStartNotification] carries [dragDetails]; a
  /// fling's ballistic phase and programmatic jumps carry null and are
  /// ignored, so [_userIsDragging] stays true only while the user's finger
  /// is actually touching the scroll view.
  ///
  /// Notifications from the NESTED horizontal scroll view (no-wrap mode)
  /// are ignored: a horizontal pan must neither count as a drag on the
  /// vertical axis nor recompute the vertical auto-scroll state.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification) {
      _userIsDragging = notification.dragDetails != null;
    } else if (notification is ScrollEndNotification) {
      _userIsDragging = false;
    }
    return false;
  }

  /// Reconciles the auto-scroll state and re-pins from metric-only changes.
  ///
  /// [ScrollMetricsNotification] is a separate notification type from
  /// [ScrollNotification] and is dispatched (via a microtask, after the
  /// frame in which the metrics changed) whenever ANY metric moves — this
  /// is the ONLY signal for content changes that never fire scroll events:
  /// a content shrink clamps the position without notifying controller
  /// listeners (the wrap toggle), and content growth re-pins the block.
  /// Mirrors the chat list's [_updateScrollToBottomState] +
  /// [_followContentGrowth] handling of the same notification.
  bool _onMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    // Re-pin first (mirrors the chat list): the follow must run before the
    // button recompute, otherwise a content growth would read as "not at
    // the bottom" and flash the button on for a frame until the jump lands
    // and _reconcileScrollState is re-run by the jump's own scroll events.
    _followContentGrowth();
    _reconcileScrollState();
    return false;
  }

  /// Last OBSERVED content extent (maxScrollExtent + viewportDimension —
  /// the scroll view's total content height) from [_followContentGrowth].
  /// The metrics notification fires for every metric change (pixels during
  /// ordinary scrolls included), so the follow only acts when the observed
  /// content extent strictly grows — a pure pixel change (a user scroll,
  /// even one stopping within the at-bottom window) or a viewport-only
  /// change never re-pins; a content shrink re-arms the gate for the next
  /// growth. Mirrors the chat list's [_lastFollowContentExtent].
  double? _lastFollowContentExtent;

  /// Follows content growth while the auto-scroll is engaged: once the
  /// user is following (at the bottom, or the block just started
  /// generating), the block must keep its bottom edge pinned to the newest
  /// code. Content growth goes through layout, so it always surfaces here
  /// via [ScrollMetricsNotification] — including growth that carries no
  /// code change (e.g. the wrap toggle making wrapped lines taller).
  ///
  /// The jump itself is guarded like the chat list's: skipped while the
  /// user is dragging, while a ballistic animation (their fling) is
  /// running — jumping mid-fling would cancel the fling — and when the
  /// auto-scroll has been interrupted.
  void _followContentGrowth() {
    if (!_isGenerating) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final contentExtent = pos.maxScrollExtent + pos.viewportDimension;
    final previous = _lastFollowContentExtent;
    _lastFollowContentExtent = contentExtent;
    if (previous != null && contentExtent <= previous) return;
    if (!_autoScrollEnabled || _userIsDragging) return;
    if (pos.isScrollingNotifier.value) return;
    // The microtask dispatches after the frame, so the layout is final and
    // the jump targets the true bottom directly.
    _scrollController.jumpTo(pos.maxScrollExtent);
  }

  /// Non-linear scroll back to the top when the block finishes generating.
  ///
  /// Known cosmetic limitation: when the closing fence is the very last
  /// token the model emits, the message finalization rebuild replaces the
  /// whole streaming subtree in the same frame batch, disposing this
  /// State mid-animation — the block snaps to the top instead of
  /// animating. The end state (top) is identical either way.
  void _animateToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.maxScrollExtent <= 0) return;
      pos.animateTo(
        0,
        duration: _returnToTopDuration,
        curve: _returnToTopCurve,
      );
    });
  }

  /// Called when the user taps the scroll-to-bottom button: jumps to the
  /// bottom edge and re-engages the auto-scroll (mirrors the chat list's
  /// scroll-to-bottom button).
  void _onScrollToBottomTap() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
    setState(() {
      _autoScrollEnabled = true;
      _showScrollButton = false;
    });
  }

  /// The scroll-to-bottom overlay button shown in the bottom-right corner
  /// while the auto-scroll is interrupted during generation. Same visual
  /// language as the chat list's scroll-to-bottom button, sized down for
  /// the code block.
  Widget _buildScrollToBottomButton() {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Material(
      elevation: 3,
      shape: const CircleBorder(),
      color: isDark ? Colors.grey[700] : Colors.grey[300],
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _onScrollToBottomTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_downward,
            size: 18,
            color: isDark ? Colors.grey[200] : Colors.grey[700],
            semanticLabel: '滚动到底部',
          ),
        ),
      ),
    );
  }

  /// Builds the small language badge shown in the top-left corner.
  Widget _buildLanguageLabel() {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        widget.language,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: isDark ? const Color(0xffcccccc) : const Color(0xff555555),
        ),
      ),
    );
  }

  Widget _buildCodeContent(Color textColor, bool isDark) {
    final lines = widget.code.split('\n');

    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: textColor,
      height: 1.5,
    );

    final lineNumStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: isDark ? const Color(0xff999999) : const Color(0xff888888),
      height: 1.5,
    );

    final digitCount = lines.length.toString().length;
    final lineNumWidth = (digitCount * 8.0 + 12.0).clamp(32.0, 80.0);

    return _buildCodeBlock(
      lines: lines,
      wrap: _wrapEnabled,
      lineNumWidth: lineNumWidth,
      lineNumStyle: lineNumStyle,
      codeStyle: codeStyle,
    );
  }

  /// Measures the actual rendered height of every logical code line when laid
  /// out at [maxWidth] with [codeStyle]. The code is shown in a single
  /// [SelectableText] (so a drag selection can span multiple lines), which
  /// means the line-number gutter can no longer align per-line inside the
  /// layout; instead each gutter entry is sized to the measured height of its
  /// logical line. Using the same style, text scaler and width constraint as
  /// the [SelectableText] keeps the gutter pixel-aligned with the rendered
  /// code lines in both wrap and no-wrap modes.
  List<double> _measureLineHeights(
    List<String> lines,
    TextStyle codeStyle,
    double maxWidth,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    return lines.map((line) {
      // An empty line still occupies one full line box in the rendered code;
      // measuring an empty string would report zero height instead.
      final painter = TextPainter(
        text: TextSpan(text: line.isEmpty ? ' ' : line, style: codeStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      return painter.height;
    }).toList();
  }

  /// Builds the line-number gutter. Each entry is [height] tall with the
  /// number pinned to its top-right, so the numbers line up with the first
  /// visual line of the corresponding (possibly wrapped) code line.
  Widget _buildLineNumberGutter(
    List<double> heights,
    double lineNumWidth,
    TextStyle lineNumStyle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < heights.length; i++)
          SizedBox(
            width: lineNumWidth,
            height: heights[i],
            child: Align(
              alignment: Alignment.topRight,
              child: Text(
                '${i + 1}',
                textAlign: TextAlign.right,
                style: lineNumStyle,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the code area: a line-number gutter next to a single
  /// [SelectableText] holding the whole code.
  ///
  /// In wrap mode the code wraps at the available width (the measurement
  /// width comes from a [LayoutBuilder]); in no-wrap mode the code sits in a
  /// horizontal scroll view, so every logical line is one visual line and the
  /// measurement width is unbounded.
  Widget _buildCodeBlock({
    required List<String> lines,
    required bool wrap,
    required double lineNumWidth,
    required TextStyle lineNumStyle,
    required TextStyle codeStyle,
  }) {
    // Two notification listeners: [ScrollNotification] (drag tracking) and
    // [ScrollMetricsNotification] (a distinct notification type, dispatched
    // after every metric change — reconciles the auto-scroll state for
    // metric-only changes that never fire scroll events).
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetricsNotification,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 40, 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The SelectableText (RenderEditable) reserves a caret
                // margin of _kCaretGap (1.0) + cursorWidth and wraps text at
                // `available width - caretMargin`, so the measurement must
                // use the same width or lines falling in that narrow band
                // wrap in the render but not in the measurement, drifting
                // the numbers below them.
                final codeAreaWidth = wrap
                    ? (constraints.maxWidth -
                            lineNumWidth -
                            8.0 -
                            1.0 -
                            _selectableCursorWidth)
                        .clamp(1.0, double.infinity)
                        .toDouble()
                    : double.infinity;
                final visualHeights =
                    _measureLineHeights(lines, codeStyle, codeAreaWidth);

                final codeSelectable = SelectableText(
                  widget.code,
                  style: codeStyle,
                  cursorWidth: _selectableCursorWidth,
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLineNumberGutter(
                      visualHeights,
                      lineNumWidth,
                      lineNumStyle,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: wrap
                          ? codeSelectable
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: codeSelectable,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the top-right toolbar row.
  ///
  /// Toolbar buttons are PURE ICONS (no text labels) — accessibility is
  /// preserved through the icon [Icon.semanticLabel]. The built-in buttons
  /// follow the fixed order copy → save → wrap; additional action buttons
  /// (common buttons like fullscreen / view-chart) are placed on the right
  /// in the order given by the consumer.
  Widget _buildButtonRow() {
    final cs = Theme.of(context).colorScheme;

    // The pill just wraps its buttons (no forced minimum size), so a
    // single-button toolbar collapses into a circle with no trailing
    // blank space. Radius 18 = half of the 36px button circle.
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy button (with checkmark feedback)
          _buildCopyButton(),
          // Save button — opens the system file save panel
          _buildActionButton(
            icon: Icons.save,
            label: '保存',
            onTap: _saveCode,
          ),
          // Wrap toggle button (always present)
          _buildActionButton(
            icon: Icons.wrap_text,
            label: _wrapEnabled ? '取消换行' : '换行显示',
            onTap: () {
              setState(() {
                _wrapEnabled = !_wrapEnabled;
              });
            },
          ),
          // Additional action buttons from consumer
          ...widget.actionButtons,
        ],
      ),
    );
  }

  /// Copies the whole code block to the clipboard and shows a checkmark
  /// feedback on the button: the icon fades to a check, holds for 1s, then
  /// fades back to the copy icon.
  ///
  /// The feedback shows immediately at tap time (not after the clipboard
  /// write resolves) so a slow write cannot delay or flicker it; a failed
  /// write (e.g. web permission denial) reverts the icon and reports the
  /// error. Re-tapping while the feedback shows restarts the hold.
  Future<void> _copyCode() async {
    _copyFeedbackTimer?.cancel();
    if (!_showCopyFeedback) {
      setState(() {
        _showCopyFeedback = true;
      });
    }
    _copyFeedbackTimer = Timer(_copyFeedbackHold, () {
      if (!mounted) return;
      setState(() {
        _showCopyFeedback = false;
      });
    });

    final generation = ++_copyTapGeneration;
    try {
      await Clipboard.setData(ClipboardData(text: widget.code));
    } catch (e) {
      // Ignore failures from superseded taps (a newer tap re-armed the
      // feedback and may still succeed).
      if (!mounted || generation != _copyTapGeneration) return;
      _copyFeedbackTimer?.cancel();
      setState(() {
        _showCopyFeedback = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('复制失败: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// The copy button with the fade-swapping copy/check icon.
  Widget _buildCopyButton() {
    return _buildToolbarButton(
      onTap: _copyCode,
      child: AnimatedSwitcher(
        duration: _copyFeedbackFade,
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: Icon(
          _showCopyFeedback ? Icons.check : Icons.copy,
          key: ValueKey<bool>(_showCopyFeedback),
          size: 20,
          semanticLabel: _showCopyFeedback ? '已复制' : '复制',
        ),
      ),
    );
  }

  /// Opens the system file save panel so the user can pick where to save
  /// the whole code block, its file name and its format (extension).
  /// The default name and format come from the block's language.
  Future<void> _saveCode() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      if (widget.code.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('代码为空，无法保存'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final bytes = Uint8List.fromList(utf8.encode(widget.code));
      final outputPath = await FilePicker.saveFile(
        dialogTitle: '保存代码',
        fileName: 'code.${_primaryExtension()}',
        type: FileType.custom,
        allowedExtensions: _saveExtensions(),
        bytes: bytes,
        initialDirectory: SystemPickDirectories.documents(),
      );
      if (outputPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存到: $outputPath'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  /// Shared toolbar button chrome: a compact circular icon button (36x36)
  /// with a circular ripple via [CircleBorder].
  Widget _buildToolbarButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: child,
        ),
      ),
    );
  }

  /// A static-icon variant of the toolbar button.
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _buildToolbarButton(
      onTap: onTap,
      child: Icon(icon, size: 20, semanticLabel: label),
    );
  }
}
