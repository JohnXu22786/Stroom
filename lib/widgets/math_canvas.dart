import 'dart:math' as dart_math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/math_expression.dart' show MathExpression, MathExpressionType;
import '../models/formula_entry.dart';

/// Callback types for canvas → parent communication.
typedef OnCoordinateUpdate = void Function(List<Map<String, double>> points);
typedef OnViewportChange = void Function(
    double xMin, double yMin, double xMax, double yMax);
typedef OnReady = void Function();
typedef OnError = void Function(String message);

/// A pure-Flutter canvas for plotting mathematical functions.
///
/// Uses [CustomPainter] for rendering and [GestureDetector] for
/// pan/zoom interactions — no WebView or external JS dependencies.
///
/// Features:
/// - Adaptive grid lines based on viewport range
/// - Axes with arrows and tick labels
/// - Smooth function curve rendering
/// - Touch/mouse pan and zoom
/// - Coordinate data export
class MathCanvas extends StatefulWidget {
  /// Initial expression to plot.
  final String? initialExpression;

  /// Called when the canvas is ready.
  final OnReady? onReady;

  /// Called when coordinate data is computed.
  final OnCoordinateUpdate? onCoordinateUpdate;

  /// Called when the viewport changes (user panned/zoomed).
  final OnViewportChange? onViewportChange;

  /// Called when an error occurs.
  final OnError? onError;

  const MathCanvas({
    super.key,
    this.initialExpression,
    this.onReady,
    this.onCoordinateUpdate,
    this.onViewportChange,
    this.onError,
  });

  @override
  State<MathCanvas> createState() => MathCanvasState();
}

/// Internal pairing of a formula entry with its sampled curve points.
///
/// For explicit functions, [polylines] has one entry (the y=f(x) curve).
/// For implicit equations, [polylines] has many short segments (the
/// zero-contour line segments from marching squares).
class _FormulaCurve {
  final FormulaEntry formula;
  final List<List<Map<String, double>>> polylines;
  const _FormulaCurve({required this.formula, this.polylines = const []});
}

/// The state class for [MathCanvas], exposing methods that can be
/// called from the parent widget to control the canvas.
class MathCanvasState extends State<MathCanvas> {
  // Viewport state (math coordinates)
  double _xMin = -10;
  double _yMin = -10;
  double _xMax = 10;
  double _yMax = 10;

  // Formula state (multi-formula support)
  final List<_FormulaCurve> _formulaCurves = [];

  // Gesture state
  double? _lastScale;
  bool _isReady = false;

  // Widget size
  double _canvasWidth = 1;
  double _canvasHeight = 1;

  @override
  void initState() {
    super.initState();
    // Defer initial setup to next frame to avoid setState during parent build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialExpression != null &&
          widget.initialExpression!.isNotEmpty) {
        final expr = MathExpression.fromInput(widget.initialExpression!);
        if (expr.isValid) {
          final formula = FormulaEntry(
            rawExpression: widget.initialExpression!,
            parsed: expr,
            color: formulaPalette[0],
            autoColor: true,
          );
          _formulaCurves.add(_FormulaCurve(
            formula: formula,
            polylines: _sampleCurve(formula),
          ));
        }
      }
      _sampleAnchorX = (_xMin + _xMax) / 2.0;
      if (!_isReady) {
        setState(() => _isReady = true);
        widget.onReady?.call();
      }
    });
  }

  // ==================================================================
  // Public API
  // ==================================================================

  /// Set all formulas to plot (replaces any existing formulas).
  Future<void> setFormulas(List<FormulaEntry> newFormulas) async {
    setState(() {
      _formulaCurves
        ..clear()
        ..addAll(newFormulas.map((f) => _FormulaCurve(
              formula: f,
              polylines: _sampleCurve(f),
            )));
      _sampleAnchorX = (_xMin + _xMax) / 2.0;
    });
    final allPoints =
        _formulaCurves.expand((fc) => fc.polylines.expand((pl) => pl)).toList();
    widget.onCoordinateUpdate?.call(allPoints);
  }

  /// Backward-compat: set a single expression.
  Future<void> setExpression(
      String expression, Map<String, double>? parameters) async {
    if (expression.isEmpty) {
      await setFormulas([]);
      return;
    }
    final parsed =
        MathExpression.fromInput(expression, parameterValues: parameters ?? {});
    if (!parsed.isValid) {
      widget.onError?.call(parsed.parseError ?? '表达式错误');
      return;
    }
    final formula = FormulaEntry(
      rawExpression: expression,
      parsed: parsed,
      color: Colors.blue,
      autoColor: true,
      parameterValues: parameters ?? {},
    );
    await setFormulas([formula]);
  }

  /// Reset the viewport to the default bounds.
  Future<void> resetView() async {
    setState(() {
      _xMin = -10;
      _yMin = -10;
      _xMax = 10;
      _yMax = 10;
      _resampleAll();
    });
    widget.onViewportChange?.call(_xMin, _yMin, _xMax, _yMax);
  }

  /// Set the viewport to specific bounds.
  Future<void> setViewport(
      double xMin, double yMin, double xMax, double yMax) async {
    if (xMax <= xMin || yMax <= yMin) return;
    setState(() {
      _xMin = xMin;
      _yMin = yMin;
      _xMax = xMax;
      _yMax = yMax;
      _resampleAll();
    });
    widget.onViewportChange?.call(_xMin, _yMin, _xMax, _yMax);
  }

  /// Get the current viewport bounds.
  (double xMin, double yMin, double xMax, double yMax) get viewport =>
      (_xMin, _yMin, _xMax, _yMax);

  /// Get all current curve points (from all formulas).
  List<Map<String, double>> get curvePoints =>
      _formulaCurves.expand((fc) => fc.polylines.expand((pl) => pl)).toList();

  // ==================================================================
  // Build helpers for painter
  // ==================================================================

  /// Flatten all formula polylines into a list for the painter.
  List<List<Map<String, double>>> _buildCurvesList() {
    final result = <List<Map<String, double>>>[];
    for (final fc in _formulaCurves) {
      for (final poly in fc.polylines) {
        if (poly.length >= 2) result.add(poly);
      }
    }
    return result;
  }

  /// Build a parallel list of colors matching [_buildCurvesList].
  List<Color> _buildColorsList() {
    final result = <Color>[];
    for (final fc in _formulaCurves) {
      for (final poly in fc.polylines) {
        if (poly.length >= 2) result.add(fc.formula.color);
      }
    }
    return result;
  }

  // ==================================================================
  // Internal: expression handling
  // ==================================================================

  /// Margin ratio for curve sampling, as a fraction of the viewport range.
  ///
  /// When the user pans the canvas, the viewport changes but curves are only
  /// re-sampled after the gesture ends ([_onScaleEnd]). To avoid large empty
  /// areas at the edges during a drag, we sample over a wider range than the
  /// current viewport. A margin of 1.0 means we sample 100% beyond each edge
  /// (3× total range), providing headroom for panning up to one full viewport
  /// width before needing to re-sample during the gesture.
  static const double _sampleMargin = 1.0;

  /// Viewport center X when curves were last sampled.
  /// Used during gesture to detect when viewport has drifted beyond the
  /// sampled margin and trigger an inline resample.
  double? _sampleAnchorX;

  /// Sample a single formula at the current viewport (with margin).
  /// Returns polylines (list of point lists). For explicit functions this
  /// is a single polyline; for implicit equations it's many short segments.
  List<List<Map<String, double>>> _sampleCurve(FormulaEntry formula) {
    if (!formula.isValid) return [];
    final parsed = formula.parsed!;

    final xRange = _xMax - _xMin;
    final yRange = _yMax - _yMin;
    final marginX = xRange * _sampleMargin;
    final marginY = yRange * _sampleMargin;

    if (parsed.type == MathExpressionType.implicit) {
      // Contour segments — each is a short line across one grid cell
      return parsed.sampleContourSegments(
        xMin: _xMin - marginX,
        xMax: _xMax + marginX,
        yMin: _yMin - marginY,
        yMax: _yMax + marginY,
        // Keep grid density the same by increasing cells proportionally
        gridX: (80 * (1 + 2 * _sampleMargin)).round(),
        gridY: (80 * (1 + 2 * _sampleMargin)).round(),
      );
    }
    // Single explicit polyline — sample over extended range with more points
    // to maintain resolution in the visible area.
    final scale = (1 + 2 * _sampleMargin);
    final pts = parsed.samplePoints(
      xMin: _xMin - marginX,
      xMax: _xMax + marginX,
      numPoints: (300 * scale).round(),
    );
    return pts.isEmpty ? [] : [pts];
  }

  // ==================================================================
  // Gesture handling (pan + zoom)
  // ==================================================================

  void _onScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final focalPoint = details.focalPoint;
    final scale = details.scale;

    if (details.pointerCount == 1 || scale == 1.0) {
      // Pan: use focalPointDelta directly (no damping) for 1:1 tracking
      final dx = details.focalPointDelta.dx;
      final dy = details.focalPointDelta.dy;

      final xRange = _xMax - _xMin;
      final yRange =
          _effectiveYRange(); // Use effective Y range for correct delta

      setState(() {
        _xMin -= (dx / _canvasWidth) * xRange;
        _xMax -= (dx / _canvasWidth) * xRange;
        _yMin += (dy / _canvasHeight) * yRange;
        _yMax += (dy / _canvasHeight) * yRange;
      });

      // If the viewport center has drifted beyond the sample margin,
      // resample inline so the panning area stays populated.
      if (_sampleAnchorX != null) {
        final currentCenterX = (_xMin + _xMax) / 2.0;
        final threshold = (_sampleMargin * xRange) / 2.0;
        if ((currentCenterX - _sampleAnchorX!).abs() > threshold) {
          _resampleAll();
        }
      }
    } else if (scale != 1.0 && _lastScale != null) {
      // Zoom: scale around focal point
      final scaleChange = scale / _lastScale!;
      final fx = _screenToMathX(focalPoint.dx);
      final fy = _screenToMathY(focalPoint.dy); // Uses effective Y bounds

      final xRange = _xMax - _xMin;

      // Convert effective Y focal point to raw Y coordinate space so the
      // zoom operation preserves the correct screen position under the finger.
      final fyRaw = _effectiveYToRawY(fy);

      final newXRange = xRange / scaleChange;
      final newYRange = (_yMax - _yMin) / scaleChange;

      setState(() {
        _xMin = fx - (fx - _xMin) / scaleChange;
        _xMax = _xMin + newXRange;
        _yMin = fyRaw - (fyRaw - _yMin) / scaleChange;
        _yMax = _yMin + newYRange;
      });
    }

    _lastScale = scale;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastScale = null;
    // Resample all formulas after gesture ends for smooth result
    setState(() {
      _resampleAll();
    });
    final allPoints = curvePoints;
    widget.onCoordinateUpdate?.call(allPoints);
    widget.onViewportChange?.call(_xMin, _yMin, _xMax, _yMax);
  }

  /// Resample all formulas at the current viewport (updates _formulaCurves).
  void _resampleAll() {
    _sampleAnchorX = (_xMin + _xMax) / 2.0;
    for (int i = 0; i < _formulaCurves.length; i++) {
      _formulaCurves[i] = _FormulaCurve(
        formula: _formulaCurves[i].formula,
        polylines: _sampleCurve(_formulaCurves[i].formula),
      );
    }
  }

  // Mouse wheel zoom
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final scrollDelta = event.scrollDelta;
      final focalPoint = event.localPosition;

      final fx = _screenToMathX(focalPoint.dx);
      final fy = _screenToMathY(focalPoint.dy); // Uses effective Y bounds

      // Scroll down (negative dy on some platforms / positive on others):
      // we want scroll UP = zoom in, scroll DOWN = zoom out.
      // Use + so that scrolling away from user (negative trackpad direction)
      // results in zoom in (smaller factor = smaller viewport).
      final zoomFactor = 1.0 + scrollDelta.dy * 0.001;
      final clampedFactor = zoomFactor.clamp(0.1, 10.0);

      final xRange = _xMax - _xMin;

      // Convert effective Y focal point to raw Y coordinate space
      final fyRaw = _effectiveYToRawY(fy);

      final newXRange = xRange * clampedFactor;
      final newYRange = (_yMax - _yMin) * clampedFactor;

      setState(() {
        _xMin = fx - (fx - _xMin) * clampedFactor;
        _xMax = _xMin + newXRange;
        _yMin = fyRaw - (fyRaw - _yMin) * clampedFactor;
        _yMax = _yMin + newYRange;
        _resampleAll();
      });
      final allPoints = curvePoints;
      widget.onCoordinateUpdate?.call(allPoints);
      widget.onViewportChange?.call(_xMin, _yMin, _xMax, _yMax);
    }
  }

  // ==================================================================
  // Coordinate conversion (gesture helpers)
  // ==================================================================

  /// Convert an effective-Y coordinate (from [_screenToMathY]) to the
  /// corresponding raw Y coordinate in the [_yMin, _yMax] space.
  ///
  /// The painter renders using effective Y bounds (aspect-ratio-corrected,
  /// derived from xRange and canvas aspect ratio) centered on the raw Y center.
  /// Gesture focal points are computed in effective Y space, but the viewport
  /// is stored in raw Y space. This conversion bridges the two.
  double _effectiveYToRawY(double fy) {
    final yCenter = (_yMin + _yMax) / 2.0;
    final effYRange = _effectiveYRange();
    final rawYRange = _yMax - _yMin;
    if (effYRange > 0 && rawYRange > 0) {
      return yCenter + (fy - yCenter) * rawYRange / effYRange;
    }
    return fy;
  }

  /// The effective Y minimum that maintains 1:1 pixel aspect ratio.
  /// Matches [GraphPainter._effectiveYMin] exactly.
  double _effectiveYMin() {
    if (_canvasWidth <= 0 || _canvasHeight <= 0) return _yMin;
    final aspectRatio = _canvasWidth / _canvasHeight;
    final xRange = _xMax - _xMin;
    if (xRange <= 0) return _yMin;
    final targetYRange = xRange / aspectRatio;
    final yCenter = (_yMin + _yMax) / 2.0;
    return yCenter - targetYRange / 2.0;
  }

  /// The effective Y maximum that maintains 1:1 pixel aspect ratio.
  /// Matches [GraphPainter._effectiveYMax] exactly.
  double _effectiveYMax() {
    if (_canvasWidth <= 0 || _canvasHeight <= 0) return _yMax;
    final aspectRatio = _canvasWidth / _canvasHeight;
    final xRange = _xMax - _xMin;
    if (xRange <= 0) return _yMax;
    final targetYRange = xRange / aspectRatio;
    final yCenter = (_yMin + _yMax) / 2.0;
    return yCenter + targetYRange / 2.0;
  }

  /// The effective Y range (always equals xRange / aspectRatio).
  double _effectiveYRange() {
    return _effectiveYMax() - _effectiveYMin();
  }

  /// Convert screen X coordinate to math X coordinate.
  /// Uses raw X bounds (direct 1:1 mapping).
  double _screenToMathX(double screenX) {
    return screenX / _canvasWidth * (_xMax - _xMin) + _xMin;
  }

  /// Convert screen Y coordinate to math Y coordinate in the **effective**
  /// (aspect-ratio-corrected) Y space — matching what the user actually sees.
  ///
  /// The painter uses [_effectiveYMin]/[_effectiveYMax] for rendering, so
  /// gesture focal points must also use this same coordinate system.
  double _screenToMathY(double screenY) {
    final eYMin = _effectiveYMin();
    final eYMax = _effectiveYMax();
    return (1.0 - screenY / _canvasHeight) * (eYMax - eYMin) + eYMin;
  }

  // ==================================================================
  // @visibleForTesting accessors
  // ==================================================================

  @visibleForTesting
  double testEffectiveYMin() => _effectiveYMin();

  @visibleForTesting
  double testEffectiveYMax() => _effectiveYMax();

  @visibleForTesting
  double testEffectiveYRange() => _effectiveYRange();

  @visibleForTesting
  double testScreenToMathY(double screenY) => _screenToMathY(screenY);

  @visibleForTesting
  double testCanvasWidth() => _canvasWidth;

  @visibleForTesting
  double testCanvasHeight() => _canvasHeight;

  /// Simulates a pan delta by directly shifting the viewport.
  /// Used in gesture tests to verify 1:1 pan tracking (no damping).
  @visibleForTesting
  void testApplyPanDelta(double dx, double dy) {
    final xRange = _xMax - _xMin;
    final yRange = _effectiveYRange();
    setState(() {
      _xMin -= (dx / _canvasWidth) * xRange;
      _xMax -= (dx / _canvasWidth) * xRange;
      _yMin += (dy / _canvasHeight) * yRange;
      _yMax += (dy / _canvasHeight) * yRange;
    });
  }

  /// Simulates a zoom delta around the given screen focal point.
  /// Uses the same zoom math as [_onScaleUpdate] with correct Y coordinate
  /// space (effective Y bounds).
  @visibleForTesting
  void testApplyZoomDelta(
      double scale, double focalPointX, double focalPointY) {
    final fx = _screenToMathX(focalPointX);
    final fy = _screenToMathY(focalPointY);
    final scaleChange = scale;

    final xRange = _xMax - _xMin;

    // Convert effective Y focal point to raw Y coordinate space
    final fyRaw = _effectiveYToRawY(fy);

    final newXRange = xRange / scaleChange;
    final newYRange = (_yMax - _yMin) / scaleChange;

    setState(() {
      _xMin = fx - (fx - _xMin) / scaleChange;
      _xMax = _xMin + newXRange;
      _yMin = fyRaw - (fyRaw - _yMin) / scaleChange;
      _yMax = _yMin + newYRange;
    });
  }

  /// Simulates a mouse wheel zoom at the given screen focal point.
  @visibleForTesting
  void testApplyScrollZoom(
      double zoomFactor, double focalPointX, double focalPointY) {
    final fx = _screenToMathX(focalPointX);
    final fy = _screenToMathY(focalPointY);
    final clampedFactor = zoomFactor.clamp(0.1, 10.0);

    final xRange = _xMax - _xMin;

    // Convert effective Y focal point to raw Y coordinate space
    final fyRaw = _effectiveYToRawY(fy);

    final newXRange = xRange * clampedFactor;
    final newYRange = (_yMax - _yMin) * clampedFactor;

    setState(() {
      _xMin = fx - (fx - _xMin) * clampedFactor;
      _xMax = _xMin + newXRange;
      _yMin = fyRaw - (fyRaw - _yMin) * clampedFactor;
      _yMax = _yMin + newYRange;
    });
  }

  // ==================================================================
  // Build
  // ==================================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasWidth = constraints.maxWidth;
        _canvasHeight = constraints.maxHeight;

        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: GraphPainter(
                  xMin: _xMin,
                  yMin: _yMin,
                  xMax: _xMax,
                  yMax: _yMax,
                  curves: _buildCurvesList(),
                  curveColors: _buildColorsList(),
                  backgroundColor: cs.surface,
                  gridColor: cs.outlineVariant.withValues(alpha: 0.5),
                  axisColor: cs.onSurface,
                  labelColor: cs.onSurfaceVariant,
                ),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Arrow direction for axis tips.
enum ArrowDirection { up, right }

// ======================================================================
// GraphPainter — CustomPainter that renders the math graph
// ======================================================================

/// A [CustomPainter] that renders a mathematical graph with:
/// - Adaptive grid lines
/// - Coordinate axes with arrows
/// - Tick labels
/// - One or more function curves
class GraphPainter extends CustomPainter {
  /// Viewport bounds in math coordinates.
  final double xMin, yMin, xMax, yMax;

  /// Curve data: list of (x, y) coordinate pairs per curve.
  final List<List<Map<String, double>>> curves;

  /// Colors for each curve.
  final List<Color> curveColors;

  final Color backgroundColor;
  final Color gridColor;
  final Color axisColor;
  final Color labelColor;

  const GraphPainter({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    this.curves = const [],
    this.curveColors = const [],
    this.backgroundColor = Colors.white,
    this.gridColor = const Color(0x80CCCCCC),
    this.axisColor = Colors.black87,
    this.labelColor = Colors.grey,
  });

  /// The effective yMin that maintains 1:1 pixel aspect ratio.
  /// Computed from the canvas aspect ratio to avoid stretching.
  double _effectiveYMin(double canvasWidth, double canvasHeight) {
    if (canvasWidth <= 0 || canvasHeight <= 0) return yMin;
    final aspectRatio = canvasWidth / canvasHeight;
    final xRange = xMax - xMin;
    if (xRange <= 0) return yMin;
    final targetYRange = xRange / aspectRatio;
    final yCenter = (yMin + yMax) / 2.0;
    return yCenter - targetYRange / 2.0;
  }

  /// The effective yMax that maintains 1:1 pixel aspect ratio.
  double _effectiveYMax(double canvasWidth, double canvasHeight) {
    if (canvasWidth <= 0 || canvasHeight <= 0) return yMax;
    final aspectRatio = canvasWidth / canvasHeight;
    final xRange = xMax - xMin;
    if (xRange <= 0) return yMax;
    final targetYRange = xRange / aspectRatio;
    final yCenter = (yMin + yMax) / 2.0;
    return yCenter + targetYRange / 2.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    final eYMin = _effectiveYMin(size.width, size.height);
    final eYMax = _effectiveYMax(size.width, size.height);
    _drawGrid(canvas, size, eYMin, eYMax);
    _drawAxes(canvas, size, eYMin, eYMax);
    _drawCurves(canvas, size, eYMin, eYMax);
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.xMin != xMin ||
        oldDelegate.yMin != yMin ||
        oldDelegate.xMax != xMax ||
        oldDelegate.yMax != yMax ||
        oldDelegate.curves != curves ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.curveColors != curveColors;
  }

  // ==================================================================
  // Coordinate conversion
  // ==================================================================

  double _mathToScreenX(double mathX, double width) {
    return (mathX - xMin) / (xMax - xMin) * width;
  }

  double _mathToScreenY(
      double mathY, double height, double eYMin, double eYMax) {
    return (1.0 - (mathY - eYMin) / (eYMax - eYMin)) * height;
  }

  Offset _mathToScreen(
      double mathX, double mathY, Size size, double eYMin, double eYMax) {
    return Offset(
      _mathToScreenX(mathX, size.width),
      _mathToScreenY(mathY, size.height, eYMin, eYMax),
    );
  }

  // ==================================================================
  // Background
  // ==================================================================

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  // ==================================================================
  // Adaptive grid
  // ==================================================================

  /// Calculate a "nice" grid spacing based on the viewport range.
  /// Returns values like 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50...
  static double _niceStep(double range, int targetTicks) {
    if (range <= 0) return 1.0;
    final roughStep = range / targetTicks;
    final magnitude =
        dart_math.pow(10, (dart_math.log(roughStep) / dart_math.ln10).floor());
    final residual = roughStep / magnitude;

    double niceStep;
    if (residual <= 1.5) {
      niceStep = 1;
    } else if (residual <= 3.5) {
      niceStep = 2;
    } else if (residual <= 7.5) {
      niceStep = 5;
    } else {
      niceStep = 10;
    }

    return niceStep * magnitude;
  }

  void _drawGrid(Canvas canvas, Size size, double eYMin, double eYMax) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Use the same step for both axes so they have the same number of cells.
    final step = _niceStep((xMax - xMin + eYMax - eYMin) / 2, 8);

    // Vertical grid lines
    double gx = (xMin / step).ceil() * step;
    while (gx <= xMax) {
      if (gx.abs() > 1e-10) {
        // Skip axis line (drawn separately)
        final screenX = _mathToScreenX(gx, size.width);
        canvas.drawLine(
          Offset(screenX, 0),
          Offset(screenX, size.height),
          gridPaint,
        );
      }
      gx += step;
    }

    // Horizontal grid lines (using effective y bounds for 1:1 aspect ratio)
    double gy = (eYMin / step).ceil() * step;
    while (gy <= eYMax) {
      if (gy.abs() > 1e-10) {
        // Skip axis line
        final screenY = _mathToScreenY(gy, size.height, eYMin, eYMax);
        canvas.drawLine(
          Offset(0, screenY),
          Offset(size.width, screenY),
          gridPaint,
        );
      }
      gy += step;
    }
  }

  // ==================================================================
  // Axes
  // ==================================================================

  void _drawAxes(Canvas canvas, Size size, double eYMin, double eYMax) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = axisColor
      ..style = PaintingStyle.fill;

    final labelTextStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w400,
    );

    // X-axis (y = 0)
    if (eYMin <= 0 && eYMax >= 0) {
      final y0 = _mathToScreenY(0, size.height, eYMin, eYMax);
      canvas.drawLine(
        Offset(0, y0),
        Offset(size.width, y0),
        axisPaint,
      );

      // X-axis arrow
      _drawArrow(canvas, Offset(size.width, y0), arrowPaint,
          direction: ArrowDirection.right);

      // X-axis label
      final textPainter = TextPainter(
        text: TextSpan(text: 'x', style: labelTextStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(size.width - textPainter.width - 4, y0 - 16));
    }

    // Y-axis (x = 0)
    if (xMin <= 0 && xMax >= 0) {
      final x0 = _mathToScreenX(0, size.width);
      canvas.drawLine(
        Offset(x0, 0),
        Offset(x0, size.height),
        axisPaint,
      );

      // Y-axis arrow
      _drawArrow(canvas, Offset(x0, 0), arrowPaint,
          direction: ArrowDirection.up);

      // Y-axis label
      final textPainter = TextPainter(
        text: TextSpan(text: 'y', style: labelTextStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x0 + 6, 4));
    }

    // Tick labels
    _drawTickLabels(canvas, size, labelTextStyle, eYMin, eYMax);
  }

  void _drawTickLabels(
      Canvas canvas, Size size, TextStyle style, double eYMin, double eYMax) {
    // Use the same step for both axes so they have the same number of cells.
    final step = _niceStep((xMax - xMin + eYMax - eYMin) / 2, 8);

    // X-axis tick labels
    final y0 = (eYMin <= 0 && eYMax >= 0)
        ? _mathToScreenY(0, size.height, eYMin, eYMax)
        : size.height - 8;

    double tx = (xMin / step).ceil() * step;
    while (tx <= xMax) {
      if (tx.abs() > 1e-10) {
        final screenX = _mathToScreenX(tx, size.width);
        final label = _formatNumber(tx);
        final textPainter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            screenX - textPainter.width / 2,
            y0 + 4,
          ),
        );

        // Small tick mark
        canvas.drawLine(
          Offset(screenX, y0 - 3),
          Offset(screenX, y0 + 3),
          Paint()
            ..color = axisColor
            ..strokeWidth = 1,
        );
      }
      tx += step;
    }

    // Y-axis tick labels
    final x0 = (xMin <= 0 && xMax >= 0) ? _mathToScreenX(0, size.width) : 8;

    double ty = (eYMin / step).ceil() * step;
    while (ty <= eYMax) {
      if (ty.abs() > 1e-10) {
        final screenY = _mathToScreenY(ty, size.height, eYMin, eYMax);
        final label = _formatNumber(ty);
        final textPainter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x0 - textPainter.width - 6,
            screenY - textPainter.height / 2,
          ),
        );

        // Small tick mark
        canvas.drawLine(
          Offset(x0 - 3, screenY),
          Offset(x0 + 3, screenY),
          Paint()
            ..color = axisColor
            ..strokeWidth = 1,
        );
      }
      ty += step;
    }

    // Origin label
    if (xMin <= 0 && xMax >= 0 && eYMin <= 0 && eYMax >= 0) {
      final x0v = _mathToScreenX(0, size.width);
      final y0v = _mathToScreenY(0, size.height, eYMin, eYMax);
      final textPainter = TextPainter(
        text: TextSpan(text: '0', style: style),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x0v + 4, y0v + 4),
      );
    }
  }

  // ==================================================================
  // Arrow helper
  // ==================================================================

  void _drawArrow(Canvas canvas, Offset tip, Paint paint,
      {required ArrowDirection direction}) {
    final arrowSize = 8.0;
    final path = Path();

    if (direction == ArrowDirection.right) {
      path.moveTo(tip.dx, tip.dy);
      path.lineTo(tip.dx - arrowSize, tip.dy - arrowSize / 2);
      path.lineTo(tip.dx - arrowSize, tip.dy + arrowSize / 2);
    } else {
      path.moveTo(tip.dx, tip.dy);
      path.lineTo(tip.dx - arrowSize / 2, tip.dy + arrowSize);
      path.lineTo(tip.dx + arrowSize / 2, tip.dy + arrowSize);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  // ==================================================================
  // Curves
  // ==================================================================

  void _drawCurves(Canvas canvas, Size size, double eYMin, double eYMax) {
    for (int c = 0; c < curves.length; c++) {
      final points = curves[c];
      if (points.length < 2) continue;

      final color = c < curveColors.length ? curveColors[c] : Colors.blue;

      final curvePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      bool inSegment = false;
      bool pathHasContent = false;

      for (int i = 0; i < points.length; i++) {
        final x = points[i]['x']!;
        final y = points[i]['y']!;
        final screenPos = _mathToScreen(x, y, size, eYMin, eYMax);

        // Check if point is within reasonable screen bounds
        if (screenPos.dx.isFinite &&
            screenPos.dy.isFinite &&
            screenPos.dx >= -10000 &&
            screenPos.dx <= size.width + 10000 &&
            screenPos.dy >= -10000 &&
            screenPos.dy <= size.height + 10000) {
          if (!inSegment) {
            path.moveTo(screenPos.dx, screenPos.dy);
            inSegment = true;
            pathHasContent = true;
          } else {
            path.lineTo(screenPos.dx, screenPos.dy);
          }
        } else {
          inSegment = false;
        }
      }

      if (pathHasContent) {
        canvas.drawPath(path, curvePaint);
      }
    }
  }

  // ==================================================================
  // Number formatting
  // ==================================================================

  static String _formatNumber(double value) {
    if (value.abs() < 1e-10) return '0';
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // Show up to 2 significant decimal digits
    final abs = value.abs();
    if (abs >= 1) {
      return value.toStringAsFixed(1);
    } else if (abs >= 0.1) {
      return value.toStringAsFixed(2);
    } else {
      return value.toStringAsExponential(1);
    }
  }
}
