import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A Text-compatible label that reveals its full value when a single-line slot
/// clips it. It leaves text that fits untouched.
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
  }) : speed = 24,
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
  }) : data = text,
       strutStyle = null,
       textDirection = null,
       locale = null,
       textScaler = null,
       semanticsLabel = null,
       selectionColor = null;

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
  double _overflow = 0;
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
  void didUpdateWidget(covariant ConstrainedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.style != widget.style ||
        oldWidget.maxLines != widget.maxLines ||
        oldWidget.textAlign != widget.textAlign ||
        oldWidget.speed != widget.speed ||
        oldWidget.marqueeTextAlign != widget.marqueeTextAlign ||
        oldWidget.softWrap != widget.softWrap ||
        oldWidget.overflow != widget.overflow) {
      _reset();
    }
  }

  void _reset() {
    _startTimer?.cancel();
    _startTimer = null;
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
    final measurementChanged =
        width != _measuredWidth ||
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
      final vertical =
          (widget.maxLines != null && widget.maxLines! > 1) ||
          (widget.maxLines != null &&
              widget.data.contains('\n') &&
              widget.softWrap != false);
      final current = TextPainter(
        text: TextSpan(text: widget.data, style: style),
        textDirection: direction,
        textScaler: scaler,
        locale: widget.locale ?? locale,
        strutStyle: widget.strutStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: width);
      _overflow = 0;
      if (current.didExceedMaxLines) {
        final natural = TextPainter(
          text: TextSpan(text: widget.data, style: style),
          textDirection: direction,
          textScaler: scaler,
          locale: widget.locale ?? locale,
          strutStyle: widget.strutStyle,
          textAlign: textAlign,
          maxLines: vertical ? null : maxLines,
        )..layout(maxWidth: vertical ? width : double.infinity);
        if (vertical) {
          _vertical = true;
          _textWidth = width;
          _textHeight = current.height;
          _overflow = math.max(0, natural.height - current.height);
        } else if (!natural.didExceedMaxLines && natural.width > width) {
          var low = width;
          var high = natural.width;
          for (var i = 0; i < 20; i++) {
            final middle = (low + high) / 2;
            final candidate = TextPainter(
              text: TextSpan(text: widget.data, style: style),
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
            text: TextSpan(text: widget.data, style: style),
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
        }
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
    if (_motionAllowed && !_animating && _startTimer == null) {
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
      if (_animating) {
        _controller.stop();
        _animating = false;
      }
    }
  }

  void _startAnimation() {
    if (_animating || !_motionAllowed || _overflow <= 0) return;
    final travel = math
        .max(1, (_overflow / widget.speed * 1000).round())
        .toInt();
    _controller.duration = Duration(milliseconds: travel * 2 + 4000);
    _position = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 2000),
      TweenSequenceItem(
        tween: Tween(begin: 0, end: 1),
        weight: travel.toDouble(),
      ),
      TweenSequenceItem(tween: ConstantTween(1), weight: 2000),
      TweenSequenceItem(
        tween: Tween(begin: 1, end: 0),
        weight: travel.toDouble(),
      ),
    ]).animate(_controller);
    _controller.repeat();
    _animating = true;
    _started = true;
  }

  Widget _original() => Text(
    widget.data,
    style: widget.style,
    strutStyle: widget.strutStyle,
    textAlign: widget.textAlign,
    textDirection: widget.textDirection,
    locale: widget.locale,
    softWrap: widget.softWrap,
    overflow: widget.overflow,
    textScaler: widget.textScaler,
    maxLines: widget.maxLines,
    semanticsLabel: widget.semanticsLabel,
    selectionColor: widget.selectionColor,
  );

  @override
  void dispose() {
    _startTimer?.cancel();
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
    final animateable =
        (widget.maxLines != null || widget.softWrap == false) &&
        widget.maxLines != 0;
    if (!animateable) return _original();
    return CustomSingleChildLayout(
      delegate: _ConstrainedTextLayoutDelegate(
        data: widget.data,
        maxLines: widget.maxLines ?? 1,
        style: style,
        strutStyle: widget.strutStyle,
        textAlign: textAlign,
        textDirection: direction,
        locale: widget.locale ?? locale,
        textScaler: scaler,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (!width.isFinite || width <= 0) return _original();
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
            return _original();
          }
          return Semantics(
            label: widget.semanticsLabel ?? widget.data,
            child: SizedBox(
              width: width,
              height: _textHeight,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final progress = _position.value;
                    final horizontalOffset = _vertical
                        ? 0.0
                        : direction == TextDirection.ltr
                        ? -_overflow * progress
                        : -_overflow * (1 - progress);
                    final verticalOffset = _vertical
                        ? -_overflow * progress
                        : 0.0;
                    final painter = TextPainter(
                      text: TextSpan(text: widget.data, style: style),
                      textDirection: direction,
                      textScaler: scaler,
                      locale: locale,
                      strutStyle: widget.strutStyle,
                      textAlign: widget.marqueeTextAlign ?? textAlign,
                      maxLines: _vertical ? null : widget.maxLines ?? 1,
                    )..layout(maxWidth: _vertical ? width : _textWidth);
                    return CustomPaint(
                      size: Size(width, _textHeight),
                      painter: _ConstrainedTextPainter(
                        painter,
                        Offset(horizontalOffset, verticalOffset),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
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
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : preferredWidth;
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

class _ConstrainedTextPainter extends CustomPainter {
  const _ConstrainedTextPainter(this.textPainter, this.offset);
  final TextPainter textPainter;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) => textPainter.paint(canvas, offset);

  @override
  bool shouldRepaint(covariant _ConstrainedTextPainter oldDelegate) =>
      offset != oldDelegate.offset || textPainter != oldDelegate.textPainter;
}
