import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'markdown_stream_session.dart';

class MarkdownWidget extends StatefulWidget {
  ///the markdown data
  final String data;

  ///if [tocController] is not null, you can use [tocListener] to get current TOC index
  final TocController? tocController;

  ///set the desired scroll physics for the markdown item list
  final ScrollPhysics? physics;

  ///set shrinkWrap to obtained [ListView] (only available when [tocController] is null)
  final bool shrinkWrap;

  /// [ListView] padding
  final EdgeInsetsGeometry? padding;

  ///make text selectable
  final bool selectable;

  ///the configs of markdown
  final MarkdownConfig? config;

  ///config for [MarkdownGenerator]
  final MarkdownGenerator? markdownGenerator;

  /// When true, retain widgets for sealed top-level Markdown blocks and
  /// reparse a bounded active block while [data] grows. An oversized active
  /// block switches to a plain-text live preview until final rendering.
  /// Incremental mode requires [fullTextOnInvalidation] so streamed link and
  /// footnote definitions can replace stale sealed widgets with their source.
  final bool incremental;

  /// Stable identity for the current append-only stream and its rendering
  /// configuration. Changing it resets the incremental document session.
  final Object? incrementalKey;

  /// Builds the configuration for the active source block. This lets custom
  /// streaming renderers derive fence-local state without rescanning or
  /// rebuilding widgets for sealed blocks.
  final MarkdownIncrementalConfigBuilder? activeConfigBuilder;

  /// Stable identity for equivalent [activeConfigBuilder] closures recreated
  /// during rebuilds. Change this when the builder's rendering behavior changes.
  final Object? activeConfigBuilderKey;

  /// A single append event for delta-driven stream rendering.
  final String? incrementalAppend;

  /// Monotonic append sequence used to avoid applying an event twice.
  final int? incrementalSequence;

  /// Number of append events already applied to this chunk before a session
  /// reset. A recreated session can then preserve the existing parse budget.
  final int incrementalInitialUpdateCount;

  /// Materializes the current section when an incremental session is reset or
  /// a document-wide reference change invalidates earlier blocks. The value
  /// must include the latest append event already reflected by its sequence.
  final String Function()? fullTextOnInvalidation;

  const MarkdownWidget({
    Key? key,
    required this.data,
    this.tocController,
    this.physics,
    this.shrinkWrap = false,
    this.selectable = true,
    this.padding,
    this.config,
    this.markdownGenerator,
    this.incremental = false,
    this.incrementalKey,
    this.activeConfigBuilder,
    this.activeConfigBuilderKey,
    this.incrementalAppend,
    this.incrementalSequence,
    this.incrementalInitialUpdateCount = 0,
    this.fullTextOnInvalidation,
  })  : assert(!incremental || fullTextOnInvalidation != null),
        super(key: key);

  @override
  MarkdownWidgetState createState() => MarkdownWidgetState();
}

class MarkdownWidgetState extends State<MarkdownWidget> {
  ///use [markdownGenerator] to transform markdown data to [Widget] list
  late MarkdownGenerator markdownGenerator;

  ///The markdown string converted by MarkdownGenerator will be retained in the [_widgets]
  final List<Widget> _widgets = [];

  ///[TocController] combines [TocWidget] and [MarkdownWidget]
  TocController? _tocController;

  ///[AutoScrollController] provides the scroll to index mechanism
  final AutoScrollController controller = AutoScrollController();

  ///every [VisibilityDetector]'s child which is visible will be kept with [indexTreeSet]
  final indexTreeSet = SplayTreeSet<int>((a, b) => a - b);

  MarkdownStreamSession? _streamSession;
  int _activeWidgetCount = 0;
  int? _lastIncrementalSequence;

  ///if the [ScrollDirection] of [ListView] is [ScrollDirection.forward], [isForward] will be true
  bool isForward = true;

  @override
  void initState() {
    super.initState();
    _attachTocController(widget.tocController);
    if (_usesIncrementalSession(widget)) {
      _startIncrementalSession(widget.data);
    } else {
      updateState();
    }
  }

  bool _usesIncrementalSession(MarkdownWidget target) =>
      target.incremental && target.tocController == null;

  void _startIncrementalSession(String data) {
    indexTreeSet.clear();
    markdownGenerator = widget.markdownGenerator ?? MarkdownGenerator();
    final session = MarkdownStreamSession(
      generator: markdownGenerator,
      activeConfigBuilder: widget.activeConfigBuilder,
    );
    _streamSession = session;
    final currentText = widget.fullTextOnInvalidation?.call() ?? data;
    _applyStreamUpdate(
      session.reset(
        currentText,
        config: widget.config,
        updatesAlreadyReceived: widget.incrementalInitialUpdateCount,
      ),
    );
    // The lazy current-text callback includes the newest manager delta. Mark
    // its sequence as consumed so the initial widget mount cannot append it
    // a second time.
    _lastIncrementalSequence = widget.incrementalSequence;
  }

  void _applyStreamUpdate(MarkdownStreamUpdate update) {
    if (update.resetAll) {
      _widgets
        ..clear()
        ..addAll(update.sealedWidgets)
        ..addAll(update.activeWidgets);
    } else {
      if (_activeWidgetCount > 0) {
        _widgets.removeRange(
          _widgets.length - _activeWidgetCount,
          _widgets.length,
        );
      }
      _widgets
        ..addAll(update.sealedWidgets)
        ..addAll(update.activeWidgets);
    }
    _activeWidgetCount = update.activeWidgets.length;
  }

  ///when we've got the data, we need update data without setState() to avoid the flicker of the view
  void updateState() {
    indexTreeSet.clear();
    _streamSession?.dispose();
    _streamSession = null;
    markdownGenerator = widget.markdownGenerator ?? MarkdownGenerator();
    final result = markdownGenerator.buildWidgets(
      widget.data,
      onTocList: (tocList) {
        _tocController?.setTocList(tocList);
      },
      config: widget.config,
    );
    _widgets.addAll(result);
  }

  ///this method will be called when [updateState] or [dispose]
  void clearState() {
    indexTreeSet.clear();
    _widgets.clear();
    _streamSession?.dispose();
    _streamSession = null;
    _activeWidgetCount = 0;
    _lastIncrementalSequence = null;
  }

  @override
  void dispose() {
    clearState();
    controller.dispose();
    _tocController?.jumpToIndexCallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildMarkdownWidget();

  ///
  Widget buildMarkdownWidget() {
    final markdownWidget = NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        final ScrollDirection direction = notification.direction;
        isForward = direction == ScrollDirection.forward;
        return true;
      },
      child: ListView.builder(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        controller: controller,
        itemBuilder: (ctx, index) => wrapByAutoScroll(
          index,
          wrapByVisibilityDetector(index, _widgets[index]),
          controller,
        ),
        itemCount: _widgets.length,
        padding: widget.padding,
      ),
    );
    return widget.selectable
        ? SelectionArea(child: markdownWidget)
        : markdownWidget;
  }

  ///wrap widget by [VisibilityDetector] that can know if [child] is visible
  Widget wrapByVisibilityDetector(int index, Widget child) {
    return VisibilityDetector(
      key: ValueKey(index.toString()),
      onVisibilityChanged: (VisibilityInfo info) {
        final visibleFraction = info.visibleFraction;
        if (isForward) {
          visibleFraction == 0
              ? indexTreeSet.remove(index)
              : indexTreeSet.add(index);
        } else {
          visibleFraction == 1.0
              ? indexTreeSet.add(index)
              : indexTreeSet.remove(index);
        }
        if (indexTreeSet.isNotEmpty) {
          _tocController?.onIndexChanged(indexTreeSet.first);
        }
      },
      child: child,
    );
  }

  @override
  void didUpdateWidget(MarkdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tocController, widget.tocController)) {
      _attachTocController(widget.tocController);
    }
    final sameSession = _usesIncrementalSession(widget) &&
        _usesIncrementalSession(oldWidget) &&
        oldWidget.incrementalKey == widget.incrementalKey &&
        identical(oldWidget.markdownGenerator, widget.markdownGenerator) &&
        !(oldWidget.incrementalAppend != null &&
            widget.incrementalAppend == null);
    final hasNewDelta = widget.incrementalAppend != null &&
        widget.incrementalSequence != _lastIncrementalSequence;
    final activeConfigBuilderChanged =
        oldWidget.activeConfigBuilderKey != widget.activeConfigBuilderKey ||
            (!identical(
                  oldWidget.activeConfigBuilder,
                  widget.activeConfigBuilder,
                ) &&
                (oldWidget.activeConfigBuilderKey == null ||
                    widget.activeConfigBuilderKey == null));
    final configChanged =
        !_sameMarkdownConfig(oldWidget.config, widget.config) ||
            activeConfigBuilderChanged;
    final skippedDeltas = sameSession &&
        widget.incrementalSequence != null &&
        _lastIncrementalSequence != null &&
        widget.incrementalSequence! > _lastIncrementalSequence! + 1;

    if (sameSession && _streamSession != null && configChanged) {
      // Existing widgets were built with the old config. Rebuild the session
      // from the current snapshot so sealed and active content use one config,
      // including append events coalesced with this widget update.
      clearState();
      _startIncrementalSession(widget.data);
    } else if (sameSession && _streamSession != null && skippedDeltas) {
      // Provider notifications and Flutter rebuilds can coalesce. If one or
      // more append events were replaced before this widget updated, rebuild
      // from the published chunk snapshot so the skipped bytes remain visible.
      final update = _streamSession!.reset(
        widget.fullTextOnInvalidation!.call(),
        config: widget.config,
        updatesAlreadyReceived: widget.incrementalInitialUpdateCount,
      );
      _lastIncrementalSequence = widget.incrementalSequence;
      _applyStreamUpdate(update);
    } else if (sameSession && _streamSession != null && hasNewDelta) {
      final update = _streamSession!.append(
        widget.incrementalAppend!,
        fullTextOnInvalidation: widget.fullTextOnInvalidation!,
        config: widget.config,
      );
      _lastIncrementalSequence = widget.incrementalSequence;
      indexTreeSet.clear();
      _applyStreamUpdate(update);
    } else if (sameSession &&
        _streamSession != null &&
        widget.data.length >= oldWidget.data.length) {
      final delta = widget.data.substring(oldWidget.data.length);
      if (delta.isNotEmpty) {
        final update = _streamSession!.append(
          delta,
          fullTextOnInvalidation: widget.fullTextOnInvalidation!,
          config: widget.config,
        );
        indexTreeSet.clear();
        _applyStreamUpdate(update);
      }
    } else {
      clearState();
      if (_usesIncrementalSession(widget)) {
        _startIncrementalSession(widget.data);
      } else {
        updateState();
      }
    }
  }

  void _attachTocController(TocController? tocController) {
    _tocController?.jumpToIndexCallback = null;
    _tocController = tocController;
    _tocController?.jumpToIndexCallback = (index) {
      controller.scrollToIndex(index, preferPosition: AutoScrollPosition.begin);
    };
  }

  bool _sameMarkdownConfig(MarkdownConfig? first, MarkdownConfig? second) {
    final left = first ?? MarkdownConfig.defaultConfig;
    final right = second ?? MarkdownConfig.defaultConfig;

    final leftPre = left.pre;
    final rightPre = right.pre;
    final samePreBuilder = leftPre.incrementalConfigKey != null ||
            rightPre.incrementalConfigKey != null
        ? leftPre.incrementalConfigKey == rightPre.incrementalConfigKey
        : identical(leftPre.builder, rightPre.builder);

    return left.incrementalConfigKey == right.incrementalConfigKey &&
        left.hr.runtimeType == right.hr.runtimeType &&
        left.hr.height == right.hr.height &&
        left.hr.color == right.hr.color &&
        _sameHeadingConfig(left.h1, right.h1) &&
        _sameHeadingConfig(left.h2, right.h2) &&
        _sameHeadingConfig(left.h3, right.h3) &&
        _sameHeadingConfig(left.h4, right.h4) &&
        _sameHeadingConfig(left.h5, right.h5) &&
        _sameHeadingConfig(left.h6, right.h6) &&
        leftPre.runtimeType == rightPre.runtimeType &&
        leftPre.padding == rightPre.padding &&
        leftPre.decoration == rightPre.decoration &&
        leftPre.margin == rightPre.margin &&
        leftPre.textStyle == rightPre.textStyle &&
        leftPre.styleNotMatched == rightPre.styleNotMatched &&
        identical(leftPre.wrapper, rightPre.wrapper) &&
        mapEquals(leftPre.theme, rightPre.theme) &&
        leftPre.language == rightPre.language &&
        samePreBuilder &&
        left.a.runtimeType == right.a.runtimeType &&
        left.a.style == right.a.style &&
        identical(left.a.onTap, right.a.onTap) &&
        left.p.runtimeType == right.p.runtimeType &&
        left.p.textStyle == right.p.textStyle &&
        left.blockquote.runtimeType == right.blockquote.runtimeType &&
        left.blockquote.sideColor == right.blockquote.sideColor &&
        left.blockquote.textColor == right.blockquote.textColor &&
        left.blockquote.sideWith == right.blockquote.sideWith &&
        left.blockquote.padding == right.blockquote.padding &&
        left.blockquote.margin == right.blockquote.margin &&
        left.li.runtimeType == right.li.runtimeType &&
        left.li.marginLeft == right.li.marginLeft &&
        left.li.marginBottom == right.li.marginBottom &&
        identical(left.li.marker, right.li.marker) &&
        _sameTableConfig(left.table, right.table) &&
        left.code.runtimeType == right.code.runtimeType &&
        left.code.style == right.code.style &&
        left.img.runtimeType == right.img.runtimeType &&
        identical(left.img.builder, right.img.builder) &&
        identical(left.img.errorBuilder, right.img.errorBuilder) &&
        left.input.runtimeType == right.input.runtimeType &&
        identical(left.input.builder, right.input.builder);
  }

  bool _sameHeadingConfig(HeadingConfig first, HeadingConfig second) {
    final leftDivider = first.divider;
    final rightDivider = second.divider;
    return first.runtimeType == second.runtimeType &&
        first.style == second.style &&
        first.padding == second.padding &&
        (identical(leftDivider, rightDivider) ||
            (leftDivider != null &&
                rightDivider != null &&
                leftDivider.space == rightDivider.space &&
                leftDivider.color == rightDivider.color &&
                leftDivider.height == rightDivider.height));
  }

  bool _sameTableConfig(TableConfig first, TableConfig second) =>
      first.runtimeType == second.runtimeType &&
      mapEquals(first.columnWidths, second.columnWidths) &&
      first.defaultColumnWidth == second.defaultColumnWidth &&
      first.textDirection == second.textDirection &&
      first.border == second.border &&
      first.defaultVerticalAlignment == second.defaultVerticalAlignment &&
      first.textBaseline == second.textBaseline &&
      first.headerRowDecoration == second.headerRowDecoration &&
      first.bodyRowDecoration == second.bodyRowDecoration &&
      first.headerStyle == second.headerStyle &&
      first.bodyStyle == second.bodyStyle &&
      first.headPadding == second.headPadding &&
      first.bodyPadding == second.bodyPadding &&
      identical(first.wrapper, second.wrapper);
}

///wrap widget by [AutoScrollTag] that can use [AutoScrollController] to scrollToIndex
Widget wrapByAutoScroll(
  int index,
  Widget child,
  AutoScrollController controller,
) {
  return AutoScrollTag(
    key: Key(index.toString()),
    controller: controller,
    index: index,
    child: child,
    highlightColor: Colors.black.toOpacity(0.1),
  );
}
