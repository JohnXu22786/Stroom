import 'package:flutter/material.dart';

@immutable
class JumpingDot extends AnimatedWidget {
  const JumpingDot({
    required Animation<double> animation,
    required this.color,
    required this.fontSize,
    super.key,
  }) : super(listenable: animation);

  final Color color;
  final double fontSize;

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: _animation.value + fontSize,
        child: Text(
          '.',
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            height: 1,
          ),
        ),
      );
}

@immutable
class JumpingDotsProgressIndicator extends StatefulWidget {
  const JumpingDotsProgressIndicator({
    required this.color,
    super.key,
    this.numberOfDots = 3,
    this.fontSize = 10.0,
    this.dotSpacing = 0.0,
    this.milliseconds = 250,
  });

  final int numberOfDots;
  final double fontSize;
  final double dotSpacing;
  final Color color;
  final int milliseconds;

  @override
  State<JumpingDotsProgressIndicator> createState() =>
      _JumpingDotsProgressIndicatorState();
}

class _JumpingDotsProgressIndicatorState
    extends State<JumpingDotsProgressIndicator> with TickerProviderStateMixin {
  final _controllers = <AnimationController>[];
  final _animations = <Animation<double>>[];
  final _widgets = <Widget>[];
  static const double _beginTweenValue = 0;
  static const double _endTweenValue = 8;

  @override
  void initState() {
    super.initState();

    for (var dot = 0; dot < widget.numberOfDots; dot++) {
      _controllers.add(
        AnimationController(
          duration: Duration(milliseconds: widget.milliseconds),
          vsync: this,
        ),
      );

      _animations.add(
        Tween(begin: _beginTweenValue, end: _endTweenValue).animate(
          _controllers[dot],
        )..addStatusListener((status) => _dotListener(status, dot)),
      );

      _widgets.add(
        Padding(
          padding: EdgeInsets.only(right: widget.dotSpacing),
          child: JumpingDot(
            animation: _animations[dot],
            fontSize: widget.fontSize,
            color: widget.color,
          ),
        ),
      );
    }

    _controllers[0].forward();
  }

  void _dotListener(AnimationStatus status, int dot) {
    if (status == AnimationStatus.completed) {
      _controllers[dot].reverse();
    }

    if (dot == widget.numberOfDots - 1 && status == AnimationStatus.dismissed) {
      _controllers[0].forward();
    }

    if (_animations[dot].value > _endTweenValue / 2 &&
        dot < widget.numberOfDots - 1) {
      _controllers[dot + 1].forward();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.fontSize + (widget.fontSize * 0.5),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center, children: _widgets),
      );

  @override
  void dispose() {
    for (var i = 0; i < widget.numberOfDots; i++) {
      _controllers[i].dispose();
    }
    super.dispose();
  }
}
