import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A Text-compatible label that reveals values clipped by a finite line slot.
/// Single-line values move horizontally; clipped multi-line values move
/// vertically without changing their wrapping. Text that fits stays untouched.
class ConstrainedText extends StatefulWidget {
  const ConstrainedText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.selectionColor,
    this.highlightedText,
    this.useNaturalWidthLayout = false,
  })  : speed = 24,
        marqueeTextAlign = null;

  const ConstrainedText.home({
    super.key,
    required String text,
    required this.style,
    this.textAlign,
    this.speed = 24,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
    this.marqueeTextAlign,
  })  : data = text,
        strutStyle = null,
        textDirection = null,
        locale = null,
        textScaler = null,
        semanticsLabel = null,
        selectionColor = null,
        highlightedText = null,
        useNaturalWidthLayout = false;

  final String data;
  final double speed;
  final TextAlign? marqueeTextAlign;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final Color? selectionColor;

  /// Optional styled runs rendered in place of plain text while preserving
  /// [data] as the complete string used for measurement and semantics.
  final TextSpan? highlightedText;

  /// Uses a direct LayoutBuilder for contexts such as DropdownMenuItem, where
  /// a custom single-child layout can invalidate the parent baseline pass.
  final bool useNaturalWidthLayout;

  @override
  State<ConstrainedText> createState() => _ConstrainedTextState();
}

class _ConstrainedTextState extends State<ConstrainedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  Animation<double> _position = const AlwaysStoppedAnimation(0);
  Timer? _startTimer;
  Timer? _endpointTimer;
  double _overflow = 0;
  double _layoutWidth = 0;
  double _textWidth = 0;
  double _textHeight = 0;
  bool _vertical = false;
  bool _animating = false;
  bool _started = false;
  bool _motionAllowed = false;
  double _measuredWidth = -1;
  TextDirection? _measuredDirection;
  TextScaler? _measuredScaler;
  TextStyle? _measuredStyle;
  Locale? _measuredLocale;
  TextAlign? _measuredAlign;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleAnimationStatus);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (!_motionAllowed ||
        (status != AnimationStatus.completed &&
            status != AnimationStatus.dismissed)) {
      return;
    }
    _animating = false;
    _endpointTimer?.cancel();
    _endpointTimer = Timer(const Duration(seconds: 2), () {
      _endpointTimer = null;
      if (!mounted || !_motionAllowed) return;
      _animating = true;
      if (_controller.status == AnimationStatus.completed) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ConstrainedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.style != widget.style ||
        oldWidget.maxLines != widget.maxLines ||
        oldWidget.textAlign != widget.textAlign ||
        oldWidget.speed != widget.speed ||
        oldWidget.marqueeTextAlign != widget.marqueeTextAlign ||
        oldWidget.softWrap != widget.softWrap ||
        oldWidget.highlightedText != widget.highlightedText ||
        oldWidget.overflow != widget.overflow) {
      _reset();
    }
  }

  void _reset() {
    _startTimer?.cancel();
    _startTimer = null;
    _endpointTimer?.cancel();
    _endpointTimer = null;
    _controller.stop();
    _controller.value = 0;
    _animating = false;
    _started = false;
    _measuredWidth = -1;
    _measuredDirection = null;
    _measuredScaler = null;
    _measuredStyle = null;
    _measuredLocale = null;
    _measuredAlign = null;
  }

  void _measure(
    double width,
    TextDirection direction,
    TextScaler scaler,
    TextStyle style,
    Locale? locale,
    TextAlign textAlign,
    bool allowMotion,
  ) {
    final measurementChanged = width != _measuredWidth ||
        direction != _measuredDirection ||
        scaler != _measuredScaler ||
        style != _measuredStyle ||
        locale != _measuredLocale ||
        textAlign != _measuredAlign;
    if (measurementChanged) {
      _measuredWidth = width;
      _measuredDirection = direction;
      _measuredScaler = scaler;
      _measuredStyle = style;
      _measuredLocale = locale;
      _measuredAlign = textAlign;
      final previousOverflow = _overflow;
      final maxLines = widget.maxLines ?? 1;
      final singleLine = maxLines == 1 || widget.softWrap == false;
      final vertical = (widget.maxLines != null && widget.maxLines! > 1) ||
          (widget.maxLines != null &&
              widget.data.contains('\n') &&
              widget.softWrap != false);
      final current = TextPainter(
        text: _textSpan(style),
        textDirection: direction,
        textScaler: scaler,
        locale: widget.locale ?? locale,
        strutStyle: widget.strutStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: width);
      _layoutWidth = current.didExceedMaxLines ? width : current.width;
      final natural = TextPainter(
        text: _textSpan(style),
        textDirection: direction,
        textScaler: scaler,
        locale: widget.locale ?? locale,
        strutStyle: widget.strutStyle,
        textAlign: textAlign,
        maxLines: singleLine ? maxLines : null,
      )..layout(maxWidth: singleLine ? double.infinity : width);
      final horizontallyClipped = singleLine && natural.width > width + 0.01;
      _overflow = 0;
      if (vertical && current.didExceedMaxLines) {
        final fullWrapped = TextPainter(
          text: _textSpan(style),
          textDirection: direction,
          textScaler: scaler,
          locale: widget.locale ?? locale,
          strutStyle: widget.strutStyle,
          textAlign: textAlign,
        )..layout(maxWidth: width);
        _vertical = true;
        _textWidth = width;
        _textHeight = current.height;
        _overflow = math.max(0, fullWrapped.height - current.height);
      } else if (horizontallyClipped) {
        var low = width;
        var high = natural.width;
        for (var i = 0; i < 20; i++) {
          final middle = (low + high) / 2;
          final candidate = TextPainter(
            text: _textSpan(style),
            textDirection: direction,
            textScaler: scaler,
            locale: widget.locale ?? locale,
            strutStyle: widget.strutStyle,
            textAlign: textAlign,
            maxLines: maxLines,
          )..layout(maxWidth: middle);
          if (candidate.didExceedMaxLines) {
            low = middle;
          } else {
            high = middle;
          }
        }
        final complete = TextPainter(
          text: _textSpan(style),
          textDirection: direction,
          textScaler: scaler,
          locale: widget.locale ?? locale,
          strutStyle: widget.strutStyle,
          textAlign: textAlign,
          maxLines: maxLines,
        )..layout(maxWidth: high);
        _textWidth = high;
        _textHeight = complete.height;
        _overflow = math.max(0, high - width);
        _vertical = false;
      } else {
        _vertical = false;
      }
      if ((previousOverflow > 0) != (_overflow > 0)) {
        _startTimer?.cancel();
        _startTimer = null;
        _controller.stop();
        _controller.value = 0;
        _animating = false;
        _started = false;
      } else if (previousOverflow != _overflow && _animating) {
        // A resize can change the travel distance while the label still
        // overflows. Restart the cycle so its duration continues to match the
        // configured logical-pixels-per-second speed.
        _controller.stop();
        _controller.value = 0;
        _animating = false;
      }
    }
    _motionAllowed = allowMotion && _overflow > 0;
    if (_motionAllowed &&
        !_animating &&
        _startTimer == null &&
        _endpointTimer == null) {
      if (_started) {
        _startAnimation();
      } else {
        _startTimer = Timer(const Duration(seconds: 1), () {
          _startTimer = null;
          if (mounted && _motionAllowed) _startAnimation();
        });
      }
    } else if (!_motionAllowed) {
      _startTimer?.cancel();
      _startTimer = null;
      _endpointTimer?.cancel();
      _endpointTimer = null;
      if (_animating) {
        _controller.stop();
        _animating = false;
      }
    }
  }

  void _startAnimation() {
    if (_animating || !_motionAllowed || _overflow <= 0) return;
    final travel =
        math.max(1, (_overflow / widget.speed * 1000).round()).toInt();
    _controller.duration = Duration(milliseconds: travel);
    _position = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward(from: 0);
    _animating = true;
    _started = true;
  }

  Widget _original(
    TextStyle style,
    TextScaler scaler,
    TextAlign textAlign,
  ) {
    if (widget.highlightedText == null) {
      return Text(
        widget.data,
        style: widget.style,
        strutStyle: widget.strutStyle,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
        locale: widget.locale,
        softWrap: widget.softWrap,
        overflow: widget.overflow,
        textScaler: scaler,
        maxLines: widget.maxLines,
        semanticsLabel: widget.semanticsLabel,
        selectionColor: widget.selectionColor,
      );
    }
    return Text.rich(
      _textSpan(style),
      strutStyle: widget.strutStyle,
      textAlign: textAlign,
      textDirection: widget.textDirection,
      locale: widget.locale,
      softWrap: widget.softWrap ?? true,
      overflow: widget.overflow ?? TextOverflow.clip,
      textScaler: scaler,
      maxLines: widget.maxLines,
      semanticsLabel: widget.semanticsLabel ?? widget.data,
      selectionColor: widget.selectionColor,
    );
  }

  TextSpan _textSpan(TextStyle style) => TextSpan(
        text: widget.highlightedText == null ? widget.data : null,
        style: style,
        children: widget.highlightedText?.children,
      );

  @override
  void dispose() {
    _startTimer?.cancel();
    _endpointTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = widget.textDirection ?? Directionality.of(context);
    final scaler = widget.textScaler ?? MediaQuery.textScalerOf(context);
    final defaultTextStyle = DefaultTextStyle.of(context);
    final style = defaultTextStyle.style.merge(widget.style);
    final textAlign =
        widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start;
    final locale = widget.locale ?? Localizations.maybeLocaleOf(context);
    final animateable = (widget.maxLines != null || widget.softWrap == false) &&
        widget.maxLines != 0;
    if (!animateable) return _original(style, scaler, textAlign);
    final measuredLayout = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) {
          return _original(style, scaler, textAlign);
        }
        _measure(
          width,
          direction,
          scaler,
          style,
          locale,
          textAlign,
          !MediaQuery.disableAnimationsOf(context) &&
              TickerMode.valuesOf(context).enabled,
        );
        if (_overflow <= 0 ||
            MediaQuery.disableAnimationsOf(context) ||
            !TickerMode.valuesOf(context).enabled) {
          return SizedBox(
            width: _layoutWidth,
            child: _original(style, scaler, textAlign),
          );
        }
        return Semantics(
          label: widget.semanticsLabel ?? widget.data,
          excludeSemantics: true,
          child: SizedBox(
            width: width,
            height: _textHeight,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: _vertical ? width : _textWidth,
                maxWidth: _vertical ? width : _textWidth,
                minHeight: _vertical ? _textHeight + _overflow : _textHeight,
                maxHeight: _vertical ? _textHeight + _overflow : _textHeight,
                child: AnimatedBuilder(
                  animation: _controller,
                  child: SizedBox(
                    width: _vertical ? width : _textWidth,
                    child: widget.highlightedText == null
                        ? Text(
                            widget.data,
                            style: style,
                            strutStyle: widget.strutStyle,
                            textAlign: widget.marqueeTextAlign ?? textAlign,
                            textDirection: direction,
                            locale: locale,
                            softWrap: _vertical,
                            overflow: TextOverflow.clip,
                            textScaler: scaler,
                            maxLines: _vertical ? null : widget.maxLines ?? 1,
                            semanticsLabel: widget.semanticsLabel,
                            selectionColor: widget.selectionColor,
                          )
                        : Text.rich(
                            _textSpan(style),
                            strutStyle: widget.strutStyle,
                            textAlign: widget.marqueeTextAlign ?? textAlign,
                            textDirection: direction,
                            locale: locale,
                            softWrap: _vertical,
                            overflow: TextOverflow.clip,
                            textScaler: scaler,
                            maxLines: _vertical ? null : widget.maxLines ?? 1,
                            semanticsLabel:
                                widget.semanticsLabel ?? widget.data,
                            selectionColor: widget.selectionColor,
                          ),
                  ),
                  builder: (context, child) {
                    final progress = _position.value;
                    final horizontalOffset = _vertical
                        ? 0.0
                        : direction == TextDirection.ltr
                            ? -_overflow * progress
                            : -_overflow * (1 - progress);
                    final verticalOffset =
                        _vertical ? -_overflow * progress : 0.0;
                    return Transform.translate(
                      offset: Offset(horizontalOffset, verticalOffset),
                      child: child,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
    final isDropdownItem =
        context.findAncestorWidgetOfExactType<DropdownMenuItem<dynamic>>() !=
            null;
    final isInputDecorator =
        context.findAncestorWidgetOfExactType<InputDecorator>() != null;
    final layout =
        widget.useNaturalWidthLayout || isDropdownItem || isInputDecorator
            ? measuredLayout
            : CustomSingleChildLayout(
                delegate: _ConstrainedTextLayoutDelegate(
                  data: widget.data,
                  maxLines: widget.maxLines ?? 1,
                  style: style,
                  strutStyle: widget.strutStyle,
                  textAlign: textAlign,
                  textDirection: direction,
                  locale: locale,
                  textScaler: scaler,
                ),
                child: measuredLayout,
              );
    return _ConstrainedTextIntrinsicLayout(
      data: widget.data,
      style: style,
      strutStyle: widget.strutStyle,
      textAlign: textAlign,
      textDirection: direction,
      locale: locale,
      textScaler: scaler,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      child: layout,
    );
  }
}

class _ConstrainedTextLayoutDelegate extends SingleChildLayoutDelegate {
  const _ConstrainedTextLayoutDelegate({
    required this.data,
    required this.maxLines,
    required this.style,
    required this.strutStyle,
    required this.textAlign,
    required this.textDirection,
    required this.locale,
    required this.textScaler,
  });

  final String data;
  final int maxLines;
  final TextStyle style;
  final StrutStyle? strutStyle;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final Locale? locale;
  final TextScaler textScaler;

  TextPainter _painter({int? lines, String? ellipsis}) => TextPainter(
        text: TextSpan(text: data, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
        strutStyle: strutStyle,
        textAlign: textAlign,
        maxLines: lines,
        ellipsis: ellipsis,
      );

  @override
  Size getSize(BoxConstraints constraints) {
    final intrinsic = _painter()..layout();
    final preferredWidth = intrinsic.maxIntrinsicWidth;
    final width =
        constraints.maxWidth.isFinite ? constraints.maxWidth : preferredWidth;
    final bounded = _painter(lines: maxLines, ellipsis: '…')
      ..layout(maxWidth: width);
    return constraints.constrain(
      Size(bounded.didExceedMaxLines ? width : bounded.width, bounded.height),
    );
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tight(getSize(constraints));

  @override
  bool shouldRelayout(covariant _ConstrainedTextLayoutDelegate oldDelegate) =>
      data != oldDelegate.data ||
      maxLines != oldDelegate.maxLines ||
      style != oldDelegate.style ||
      strutStyle != oldDelegate.strutStyle ||
      textAlign != oldDelegate.textAlign ||
      textDirection != oldDelegate.textDirection ||
      locale != oldDelegate.locale ||
      textScaler != oldDelegate.textScaler;
}

class _ConstrainedTextIntrinsicLayout extends SingleChildRenderObjectWidget {
  const _ConstrainedTextIntrinsicLayout({
    required this.data,
    required this.style,
    required this.strutStyle,
    required this.textAlign,
    required this.textDirection,
    required this.locale,
    required this.textScaler,
    required this.maxLines,
    required this.overflow,
    required super.child,
  });

  final String data;
  final TextStyle style;
  final StrutStyle? strutStyle;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final Locale? locale;
  final TextScaler textScaler;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderConstrainedTextIntrinsicLayout(
        data: data,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        textScaler: textScaler,
        maxLines: maxLines,
        overflow: overflow,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderConstrainedTextIntrinsicLayout renderObject,
  ) {
    renderObject.updateText(
      data: data,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      textScaler: textScaler,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class _RenderConstrainedTextIntrinsicLayout extends RenderProxyBox {
  _RenderConstrainedTextIntrinsicLayout({
    required this._data,
    required this._style,
    required this._strutStyle,
    required this._textAlign,
    required this._textDirection,
    required this._locale,
    required this._textScaler,
    required this._maxLines,
    required this._overflow,
  });

  String _data;
  TextStyle _style;
  StrutStyle? _strutStyle;
  TextAlign _textAlign;
  TextDirection _textDirection;
  Locale? _locale;
  TextScaler _textScaler;
  int? _maxLines;
  TextOverflow? _overflow;

  void updateText({
    required String data,
    required TextStyle style,
    required StrutStyle? strutStyle,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required Locale? locale,
    required TextScaler textScaler,
    required int? maxLines,
    required TextOverflow? overflow,
  }) {
    if (_data == data &&
        _style == style &&
        _strutStyle == strutStyle &&
        _textAlign == textAlign &&
        _textDirection == textDirection &&
        _locale == locale &&
        _textScaler == textScaler &&
        _maxLines == maxLines &&
        _overflow == overflow) {
      return;
    }
    _data = data;
    _style = style;
    _strutStyle = strutStyle;
    _textAlign = textAlign;
    _textDirection = textDirection;
    _locale = locale;
    _textScaler = textScaler;
    _maxLines = maxLines;
    _overflow = overflow;
    markNeedsLayout();
  }

  TextPainter _painter() => TextPainter(
        text: TextSpan(text: _data, style: _style),
        textDirection: _textDirection,
        textScaler: _textScaler,
        locale: _locale,
        strutStyle: _strutStyle,
        textAlign: _textAlign,
        maxLines: _maxLines,
        ellipsis: _overflow == TextOverflow.ellipsis ? '…' : null,
      );

  double _intrinsicWidth(double height, {required bool minimum}) {
    final painter = _painter()..layout();
    return minimum ? painter.minIntrinsicWidth : painter.maxIntrinsicWidth;
  }

  double _intrinsicHeight(double width) {
    final painter = _painter()
      ..layout(maxWidth: width.isFinite ? width : double.infinity);
    return painter.height;
  }

  double? _baseline(double width, TextBaseline baseline) {
    final painter = _painter()
      ..layout(maxWidth: width.isFinite ? width : double.infinity);
    return painter.computeDistanceToActualBaseline(baseline);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicWidth(height, minimum: true);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicWidth(height, minimum: false);

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _baseline(size.width, baseline);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final drySize = computeDryLayout(constraints);
    return _baseline(drySize.width, baseline);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final painter = _painter()
      ..layout(maxWidth: width.isFinite ? width : double.infinity);
    final preferredWidth = painter.didExceedMaxLines ? width : painter.width;
    return constraints.constrain(Size(preferredWidth, painter.height));
  }
}
