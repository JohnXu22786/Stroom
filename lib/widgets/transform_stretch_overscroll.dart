import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// A transform-based stretch overscroll effect for scroll views.
///
/// Flutter's default Material 3 stretch overscroll on Android
/// ([StretchingOverscrollIndicator]) applies the stretch with an
/// [ImageFilter] fragment shader, which does NOT affect platform views
/// (e.g. the [InAppWebView](https://pub.dev/packages/flutter_inappwebview)
/// used to render mermaid diagrams): the platform-view area stays rigid
/// while the rest of the content stretches.
///
/// This widget applies the stretch with a plain [Transform] matrix
/// instead — ancestor transforms ARE honored by platform views — so the
/// whole content, including mermaid WebViews, stretches uniformly during
/// overscroll.
///
/// The notification handling, stretch intensity mapping, spring constants
/// and sign conventions mirror the framework's
/// [StretchingOverscrollIndicator] so the visual behavior matches the
/// platform default.
class TransformStretchOverscroll extends StatefulWidget {
  /// Creates a visual indication that a scroll view has overscrolled by
  /// applying a matrix stretch transformation to the content.
  ///
  /// In order for this widget to display an overscroll indication, the
  /// [child] must contain a widget that generates a [ScrollNotification]
  /// along [axisDirection], such as a [ListView].
  const TransformStretchOverscroll({
    super.key,
    required this.axisDirection,
    this.child,
  });

  /// The direction in which the scroll view is scrolling.
  final AxisDirection axisDirection;

  /// The scrollable whose overscroll should be stretched.
  final Widget? child;

  /// The axis along which the scroll view scrolls.
  Axis get axis =>
      axisDirection == AxisDirection.up || axisDirection == AxisDirection.down
          ? Axis.vertical
          : Axis.horizontal;

  @override
  State<TransformStretchOverscroll> createState() =>
      _TransformStretchOverscrollState();
}

class _TransformStretchOverscrollState extends State<TransformStretchOverscroll>
    with TickerProviderStateMixin {
  // Physical constants ported from Android's EdgeEffect, matching the
  // framework's StretchingOverscrollIndicator.
  static const double _kExponentialScalar = math.e / 0.33;
  static const double _kStretchIntensity = 0.016;
  static const double _kAbsorbImpactVelocityFriction = 1 / 3000;
  static const double _kMaxAbsorbImpactVelocity = 1.25;
  static const double _kFlingVelocityFriction = 1 / 6000;
  static const double _kMaxFlingVelocity = 0.5;
  static const double _kNaturalFrequency = 24.657;
  static const double _kDampingRatio = 0.98;
  static const double _kTimeCorrectionFactor = 0.8;
  static const double _kStiffness = _kNaturalFrequency * _kNaturalFrequency;

  /// Spring used for the release/fling return animation. The stiffness is
  /// corrected by the time-correction factor squared (equivalent to
  /// slowing the simulation time by 0.8), matching the framework.
  final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: _kStiffness * _kTimeCorrectionFactor * _kTimeCorrectionFactor,
    ratio: _kDampingRatio,
  );

  /// Current stretch strength in the intensity-mapped range (about
  /// [-0.032, 0.032], like the framework). Positive = end overscroll for
  /// the configured axis direction.
  double _overscroll = 0.0;

  /// Accumulated overscroll while a drag is in progress, normalized by
  /// the viewport dimension to bound the pull (mirrors the framework).
  double _totalOverscroll = 0.0;

  /// The stretch value at the moment a spring-back animation was
  /// interrupted by a new pull, so the next pull continues smoothly.
  double _interruptedOverscroll = 0.0;

  /// Non-null only while a spring-back animation is running.
  AnimationController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != widget.axis) {
      return false;
    }
    if (notification is OverscrollNotification) {
      _totalOverscroll += notification.overscroll;
      if (notification.velocity != 0.0) {
        // Overscroll from a ballistic/driven activity (fling).
        _absorbImpact(notification.velocity);
      } else if (notification.dragDetails != null) {
        final viewportDimension = notification.metrics.viewportDimension;
        final distanceForPull =
            viewportDimension == 0 ? 0.0 : _totalOverscroll / viewportDimension;
        _pull(distanceForPull.clamp(-1.0, 1.0));
      }
    } else if (notification is ScrollEndNotification) {
      var velocity = switch (widget.axis) {
        Axis.vertical =>
          notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0.0,
        Axis.horizontal =>
          notification.dragDetails?.velocity.pixelsPerSecond.dx ?? 0.0,
      };
      // Reverse axis directions report dragDetails velocity in the
      // opposite screen coordinate, so the value must be inverted
      // (keyed on the NOTIFICATION's direction, like the framework).
      if (notification.metrics.axisDirection == AxisDirection.left ||
          notification.metrics.axisDirection == AxisDirection.up) {
        velocity = -velocity;
      }
      _totalOverscroll = 0.0;
      _scrollEnd(velocity);
    } else if (notification is ScrollUpdateNotification) {
      _totalOverscroll = 0.0;
      _scrollEnd(0.0);
    }
    return false;
  }

  /// Handle a user-driven overscroll drag (mirrors the framework's
  /// `_StretchController.pull`, including the intensity curve that keeps
  /// the stretch subtle).
  void _pull(double normalizedOverscroll) {
    if (_controller != null) {
      _interruptedOverscroll = _controller!.value;
      _controller!.dispose();
      _controller = null;
    }
    final absDistance = normalizedOverscroll.abs();
    final linearIntensity = _kStretchIntensity * absDistance;
    final exponentialIntensity =
        _kStretchIntensity * (1 - math.exp(-absDistance * _kExponentialScalar));
    final newOverscroll =
        normalizedOverscroll.sign * (linearIntensity + exponentialIntensity);
    setState(() {
      _overscroll = (newOverscroll + _interruptedOverscroll).clamp(-1.0, 1.0);
    });
  }

  /// Handle a fling to the edge of the viewport at a particular velocity
  /// (mirrors the framework's `absorbImpact`).
  void _absorbImpact(double velocity) {
    if (velocity == 0.0) return;
    final scaledVelocity = (velocity * _kAbsorbImpactVelocityFriction)
        .clamp(-_kMaxAbsorbImpactVelocity, _kMaxAbsorbImpactVelocity);
    _animate(_createStretchSimulation(scaledVelocity));
  }

  /// Called when the overscroll ends to trigger a fling animation if
  /// needed (mirrors the framework's `scrollEnd`; an in-flight spring is
  /// kept, not restarted).
  void _scrollEnd(double velocity) {
    if (velocity == 0.0 && _overscroll == 0.0) return;
    final scaledVelocity = (-(velocity * _kFlingVelocityFriction))
        .clamp(-_kMaxFlingVelocity, _kMaxFlingVelocity);
    if (_controller == null) {
      _animate(_createStretchSimulation(scaledVelocity));
    }
  }

  SpringSimulation _createStretchSimulation(double velocity) {
    // The velocity is scaled by the time-correction factor too — the
    // framework applies the same to its simulation input.
    return SpringSimulation(
      _spring,
      _overscroll,
      0.0,
      velocity * _kTimeCorrectionFactor,
    );
  }

  /// Starts a spring-back animation, replacing any running one.
  void _animate(Simulation simulation) {
    final controller = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted) {
          setState(() {
            _overscroll = (_controller?.value ?? 0.0).clamp(-1.0, 1.0);
          });
        }
      })
      ..animateWith(simulation).whenComplete(() {
        _interruptedOverscroll = 0.0;
        _controller?.dispose();
        _controller = null;
        if (mounted) {
          setState(() => _overscroll = 0.0);
        }
      });
    _controller?.dispose();
    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    final stretch = _overscroll;

    // Mirror the framework's stretch strength mapping.
    double overscroll = -stretch;
    if (widget.axisDirection == AxisDirection.up ||
        widget.axisDirection == AxisDirection.left) {
      overscroll = -overscroll;
    }

    final isForward = overscroll > 0;
    final direction = Directionality.of(context);
    final AlignmentGeometry alignmentGeometry;
    if (widget.axis == Axis.vertical) {
      alignmentGeometry = isForward
          ? AlignmentDirectional.topCenter
          : AlignmentDirectional.bottomCenter;
    } else {
      alignmentGeometry = isForward
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd;
    }
    final alignment = alignmentGeometry.resolve(direction);

    final scale = 1.0 + overscroll.abs();
    final isStretching = stretch.abs() > 0.001;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ClipRect(
        clipBehavior: isStretching ? Clip.hardEdge : Clip.none,
        child: Transform(
          alignment: alignment,
          transform: Matrix4.diagonal3Values(
            widget.axis == Axis.vertical ? 1.0 : scale,
            widget.axis == Axis.vertical ? scale : 1.0,
            1.0,
          ),
          child: widget.child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
