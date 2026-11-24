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
      style: TextStyle(color: color, fontSize: fontSize, height: 1),
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
    extends State<JumpingDotsProgressIndicator>
    with TickerProviderStateMixin {
  final _controllers = <AnimationController>[];
  final _animations = <Animation<double>>[];
  static const double _beginTweenValue = 0;
  static const double _endTweenValue = 8;
  bool _reconfiguring = false;

  @override
  void initState() {
    super.initState();

    for (var dot = 0; dot < _dotCount; dot++) {
      _addController(dot);
    }

    if (_controllers.isNotEmpty) {
      _controllers.first.forward();
    }
  }

  int get _dotCount => widget.numberOfDots.clamp(0, 0x7fffffff).toInt();

  void _addController(int dot) {
    final controller = AnimationController(
      duration: Duration(milliseconds: widget.milliseconds),
      vsync: this,
    );
    _controllers.add(controller);
    _animations.add(
      Tween(begin: _beginTweenValue, end: _endTweenValue).animate(controller)
        ..addStatusListener((status) => _dotListener(status, dot)),
    );
  }

  @override
  void didUpdateWidget(covariant JumpingDotsProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.numberOfDots != widget.numberOfDots) {
      _reconfiguring = true;
      while (_controllers.length > _dotCount) {
        _animations.removeLast();
        _controllers.removeLast().dispose();
      }
      while (_controllers.length < _dotCount) {
        _addController(_controllers.length);
      }
      for (final controller in _controllers) {
        controller.stop(canceled: true);
        controller.value = 0;
      }
      _reconfiguring = false;
      if (_controllers.isNotEmpty) {
        _controllers.first.forward();
      }
    }

    if (oldWidget.milliseconds != widget.milliseconds) {
      for (final controller in _controllers) {
        final value = controller.value;
        final status = controller.status;
        controller.duration = Duration(milliseconds: widget.milliseconds);
        if (status == AnimationStatus.forward) {
          controller.forward(from: value);
        } else if (status == AnimationStatus.reverse) {
          controller.reverse(from: value);
        }
      }
    }
  }

  void _dotListener(AnimationStatus status, int dot) {
    if (_reconfiguring || dot >= _controllers.length) {
      return;
    }

    if (status == AnimationStatus.completed) {
      _controllers[dot].reverse();
    }

    if (dot == _controllers.length - 1 &&
        status == AnimationStatus.dismissed &&
        _controllers.isNotEmpty) {
      _controllers.first.forward();
    }

    if (_animations[dot].value > _endTweenValue / 2 &&
        dot < _controllers.length - 1) {
      _controllers[dot + 1].forward();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.fontSize + (widget.fontSize * 0.5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        _controllers.length,
        (dot) => Padding(
          padding: EdgeInsets.only(right: widget.dotSpacing),
          child: JumpingDot(
            animation: _animations[dot],
            fontSize: widget.fontSize,
            color: widget.color,
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
