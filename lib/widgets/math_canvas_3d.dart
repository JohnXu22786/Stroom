import 'dart:math' as dart_math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../models/math_3d_object.dart';
import '../models/math_3d_scene.dart';
import '../models/math_3d_tool.dart';
import '../models/math_3d_construction.dart';

// Re-export so pages can use these without direct imports
export '../models/math_3d_scene.dart' show ProjectionType;
export '../models/math_3d_tool.dart' show ConstructionTool;

/// Callback types for canvas → parent communication.
typedef On3DReady = void Function();
typedef On3DViewportChange = void Function();
typedef On3DObjectCreated = void Function(Object3D object);
typedef On3DToolInstruction = void Function(String instruction);

/// A 3D rendering canvas using Flutter's CustomPainter.
///
/// Renders a 3D scene with:
/// - Orbital camera controls (drag to rotate, scroll to zoom)
/// - Coordinate axes with labels
/// - Grid on the xOz-plane
/// - Points, lines, planes, surfaces, spheres, polyhedra
/// - Parallel and perspective projection
///
/// Uses painter's algorithm (back-to-front sorting) for correct occlusion
/// since we don't have a depth buffer on 2D Canvas.
class MathCanvas3D extends StatefulWidget {
  final On3DReady? onReady;
  final On3DViewportChange? onViewportChange;
  final On3DObjectCreated? onObjectCreated;
  final On3DToolInstruction? onToolInstruction;
  final ConstructionTool currentTool;

  const MathCanvas3D({
    super.key,
    this.onReady,
    this.onViewportChange,
    this.onObjectCreated,
    this.onToolInstruction,
    this.currentTool = ConstructionTool.move,
  });

  @override
  State<MathCanvas3D> createState() => MathCanvas3DState();
}

/// The state class for [MathCanvas3D], exposing methods for parent control.
class MathCanvas3DState extends State<MathCanvas3D> {
  // Camera state
  double _cameraDistance = 10;
  double _cameraTheta = 0;
  double _cameraPhi = dart_math.pi / 4;
  Point3D _cameraTarget = Point3D.origin;

  // Visual state
  ProjectionType _projectionType = ProjectionType.parallel;
  bool _showAxes = true;
  bool _showGrid = true;

  // Scene objects
  final List<Object3D> _objects = [];
  int _objectsVersion = 0;

  /// Get the list of objects (unmodifiable).
  List<Object3D> get objects => List.unmodifiable(_objects);

  // Construction state
  ConstructionState? _construction;
  ConstructionTool _currentTool = ConstructionTool.move;

  // Construction gesture tracking (for 3D point placement with height)
  Point3D? _constGroundPos; // ground (y=0) position during construction
  double _constHeight = 0; // height offset from ground during drag
  Offset? _constStartPoint; // screen position where point gesture started
  bool _constPointPlaced = false; // whether the point was committed

  // Gesture state
  Offset? _lastFocalPoint;
  double?
      _initialScaleDistance; // camera distance at gesture start (for stable zoom)
  bool _isReady = false;

  // Canvas size
  double _canvasWidth = 1;
  double _canvasHeight = 1;

  // ==================================================================
  // Public API
  // ==================================================================

  /// Get the current camera state.
  Camera3D get camera => Camera3D(
        target: _cameraTarget,
        distance: _cameraDistance,
        theta: _cameraTheta,
        phi: _cameraPhi,
      );

  /// Get the current projection type.
  ProjectionType get projectionType => _projectionType;

  /// Whether axes are visible.
  bool get showAxes => _showAxes;

  /// Whether grid is visible.
  bool get showGrid => _showGrid;

  /// Number of objects in the scene.
  int get objectCount => _objects.length;

  /// Set the projection type.
  void setProjectionType(ProjectionType type) {
    setState(() {
      _projectionType = type;
    });
  }

  /// Toggle axis visibility.
  void toggleAxes() {
    setState(() {
      _showAxes = !_showAxes;
    });
  }

  /// Toggle grid visibility.
  void toggleGrid() {
    setState(() {
      _showGrid = !_showGrid;
    });
  }

  /// Reset the camera to the default view.
  void resetView() {
    setState(() {
      _cameraDistance = 10;
      _cameraTheta = 0;
      _cameraPhi = dart_math.pi / 4;
      _cameraTarget = Point3D.origin;
    });
    widget.onViewportChange?.call();
  }

  /// Set the objects to render.
  void setObjects(List<Object3D> objects) {
    setState(() {
      _objects
        ..clear()
        ..addAll(objects);
      _objectsVersion++;
    });
  }

  /// Clear all objects.
  void clearObjects() {
    setState(() {
      _objects.clear();
      _objectsVersion++;
    });
  }

  /// Add a surface mesh to the scene.
  void setSurface({
    required List<Point3D> vertices,
    required List<int> indices,
    List<Vector3D>? normals,
    int color = 0xFFAAAAAA,
    double opacity = 1.0,
  }) {
    setState(() {
      _objects.add(Object3D.surface(
        vertices: vertices,
        indices: indices,
        normals: normals,
        color: color,
        opacity: opacity,
      ));
      _objectsVersion++;
    });
  }

  /// Get the current construction state (null if no tool is active).
  ConstructionState? get constructionState => _construction;

  /// Get the active construction tool.
  ConstructionTool get activeTool => _currentTool;

  /// Get the current construction instruction.
  String? get constructionInstruction => _construction?.currentInstruction;

  /// Set the active construction tool.
  void setTool(ConstructionTool tool) {
    setState(() {
      _currentTool = tool;
      if (tool == ConstructionTool.move) {
        _construction = null;
      } else {
        _construction = ConstructionState(tool: tool);
      }
      _constPointPlaced = false;
      _constGroundPos = null;
      _constStartPoint = null;
    });
    widget.onToolInstruction?.call(_construction?.currentInstruction ?? '');
  }

  @override
  void initState() {
    super.initState();
    // Initialize tool from widget, which also creates construction state
    _currentTool = widget.currentTool;
    if (_currentTool != ConstructionTool.move) {
      _construction = ConstructionState(tool: _currentTool);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isReady) {
        setState(() => _isReady = true);
        widget.onReady?.call();
      }
    });
  }

  @override
  void didUpdateWidget(MathCanvas3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTool != oldWidget.currentTool) {
      setTool(widget.currentTool);
    }
  }

  @override
  void dispose() {
    _construction = null;
    super.dispose();
  }

  // ==================================================================
  // Gesture handling
  // ==================================================================
  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    _initialScaleDistance = _cameraDistance;

    // In construction mode, start tracking for point + height placement
    if (_currentTool != ConstructionTool.move && _construction != null) {
      _constStartPoint = details.focalPoint;
      _constGroundPos = null;
      _constHeight = 0;
      _constPointPlaced = false;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final focalPoint = details.focalPoint;
    final scale = details.scale;

    // ===== Construction mode: tap → point on ground, drag → adjust height
    if (_currentTool != ConstructionTool.move &&
        _construction != null &&
        !_constPointPlaced) {
      if (_constGroundPos == null) {
        // First movement: compute the ground position from the current point
        _constGroundPos = _screenToPointOnPlane(focalPoint.dx, focalPoint.dy);
        _constHeight = 0;
      } else if (_lastFocalPoint != null) {
        // Subsequent movement: vertical drag adjusts height
        final dy = focalPoint.dy - _lastFocalPoint!.dy;
        _constHeight -= dy * 0.08; // sensitivity: pixels → world units
        // Recompute ground x,z from current pointer (allows moving point around)
        _constGroundPos = _screenToPointOnPlane(focalPoint.dx, focalPoint.dy);
      }
      _lastFocalPoint = focalPoint;
      return; // Don't orbit during construction
    }

    // ===== Standard orbit/pan/zoom (Move tool or no construction active)
    if (details.pointerCount == 1) {
      // Single finger: orbit
      final dx =
          _lastFocalPoint == null ? 0.0 : (focalPoint.dx - _lastFocalPoint!.dx);
      final dy =
          _lastFocalPoint == null ? 0.0 : (focalPoint.dy - _lastFocalPoint!.dy);

      setState(() {
        _cameraTheta += dx * 0.01;
        _cameraPhi = (_cameraPhi + dy * 0.01)
            .clamp(-dart_math.pi * 0.49, dart_math.pi * 0.49);
      });
    } else if (details.pointerCount >= 2) {
      // Two fingers: detect scale change (zoom) vs focal point change (pan)
      // Use cumulative scale relative to gesture start for zoom detection
      final hasScaleChange =
          (scale - 1.0).abs() > 0.02 && _initialScaleDistance != null;
      final hasPanMovement = _lastFocalPoint != null &&
          (focalPoint - _lastFocalPoint!).distance > 2.0;

      if (hasScaleChange) {
        // Pinch zoom: use cumulative scale from gesture start for stability
        final newDistance =
            (_initialScaleDistance! / scale).clamp(0.1, 1000).toDouble();
        setState(() {
          _cameraDistance = newDistance;
        });
      } else if (hasPanMovement) {
        // Two-finger drag without scale change = pan
        final dx = _lastFocalPoint == null
            ? 0.0
            : (focalPoint.dx - _lastFocalPoint!.dx);
        final dy = _lastFocalPoint == null
            ? 0.0
            : (focalPoint.dy - _lastFocalPoint!.dy);

        // Build camera for pan computation
        final cam = Camera3D(
          target: _cameraTarget,
          distance: _cameraDistance,
          theta: _cameraTheta,
          phi: _cameraPhi,
        );
        final panned = cam.pan(deltaX: dx, deltaY: dy);
        setState(() {
          _cameraTarget = panned.target;
        });
      }
    }

    _lastFocalPoint = focalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // ===== Construction mode: finalize the point with height
    if (_currentTool != ConstructionTool.move &&
        _construction != null &&
        !_constPointPlaced &&
        _constGroundPos != null) {
      _constPointPlaced = true;
      final finalPos = Point3D(
        _constGroundPos!.x,
        _constHeight,
        _constGroundPos!.z,
      );
      _handleConstructionPoint(finalPos);

      _constGroundPos = null;
      _constStartPoint = null;
      _lastFocalPoint = null;
      widget.onViewportChange?.call();
      return;
    }

    // Handle the case where user just tapped without dragging
    if (_currentTool != ConstructionTool.move &&
        _construction != null &&
        !_constPointPlaced &&
        _constGroundPos == null &&
        _constStartPoint != null) {
      // Place point on the ground plane at the tap position
      _constPointPlaced = true;
      final groundPos =
          _screenToPointOnPlane(_constStartPoint!.dx, _constStartPoint!.dy);
      _handleConstructionPoint(groundPos);

      _constGroundPos = null;
      _constStartPoint = null;
      _lastFocalPoint = null;
      widget.onViewportChange?.call();
      return;
    }

    _lastFocalPoint = null;
    _constStartPoint = null;
    _constGroundPos = null;
    widget.onViewportChange?.call();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final scrollDelta = event.scrollDelta;
      final zoomFactor = 1.0 + scrollDelta.dy * 0.002;
      final clampedFactor = zoomFactor.clamp(0.1, 10.0);

      setState(() {
        _cameraDistance = (_cameraDistance * clampedFactor).clamp(0.1, 1000);
      });
      widget.onViewportChange?.call();
    }
  }

  // ==================================================================
  // Construction click handling
  // ==================================================================

  /// Compute the orthographic scale matching the painter's projection.
  double _computeScaleForCanvas() {
    return 800 / _cameraDistance.clamp(0.1, 1000);
  }

  /// Convert a screen position to a 3D point on the y=0 (ground) plane.
  ///
  /// Uses the camera view matrix and orthographic projection to compute
  /// the inverse mapping from screen coordinates to world coordinates.
  /// Solves the 2×2 linear system: given viewX, viewY, and worldY=0,
  /// find worldX and worldZ.
  Point3D _screenToPointOnPlane(double screenX, double screenY) {
    final cam = Camera3D(
      target: _cameraTarget,
      distance: _cameraDistance,
      theta: _cameraTheta,
      phi: _cameraPhi,
    );

    // Step 1: Build the view matrix (world → view transform)
    final viewMatrix = cam.viewMatrix();
    // viewMatrix is column-major: [right.x, up.x, -fwd.x, 0,
    //                               right.y, up.y, -fwd.y, 0,
    //                               right.z, up.z, -fwd.z, 0,
    //                               -R·pos, -U·pos, F·pos, 1]
    final pos = cam.position;
    final right = Vector3D(viewMatrix[0], viewMatrix[4], viewMatrix[8]);
    final up = Vector3D(viewMatrix[1], viewMatrix[5], viewMatrix[9]);

    // Step 2: Screen → NDC
    final ndcX = 2 * screenX / _canvasWidth - 1;
    final ndcY = 1 - 2 * screenY / _canvasHeight;

    // Step 3: NDC → view space (inverse orthographic projection)
    final scale = _computeScaleForCanvas();
    final aspect = _canvasWidth / _canvasHeight;
    final halfW = scale * aspect;
    final halfH = scale;
    final viewX = ndcX * halfW;
    final viewY = ndcY * halfH;

    // Step 4: View space → world space on y=0 plane.
    // The view matrix transforms: viewPoint = R·(worldPoint) + T
    // where R = [right, up, -forward]^T and T is the translation.
    //
    // viewX = right·worldPoint + right·(-pos)
    // viewY = up·worldPoint + up·(-pos)
    //
    // Given worldY = 0:
    // viewX = right.x·worldX + right.z·worldZ - right·pos
    // viewY = up.x·worldX + up.z·worldZ - up·pos
    //
    // Rearranged:
    // right.x·worldX + right.z·worldZ = viewX + right·pos
    // up.x·worldX + up.z·worldZ = viewY + up·pos

    final rhsX = viewX + right.dot(pos.toVector());
    final rhsY = viewY + up.dot(pos.toVector());

    // Solve the 2×2 system
    final a = right.x; // coefficient of worldX in first eq
    final b = right.z; // coefficient of worldZ in first eq
    final c = up.x; // coefficient of worldX in second eq
    final d = up.z; // coefficient of worldZ in second eq

    final det = a * d - b * c;
    if (det.abs() < 1e-10) {
      // Degenerate case — fall back to camera target on ground
      return Point3D(_cameraTarget.x, 0, _cameraTarget.z);
    }

    final worldX = (rhsX * d - b * rhsY) / det;
    final worldZ = (a * rhsY - rhsX * c) / det;

    return Point3D(worldX, 0, worldZ);
  }

  /// Handle a placed 3D point during construction.
  /// Advances the construction state and creates the object when ready.
  void _handleConstructionPoint(Point3D worldPt) {
    if (_construction == null) return;

    final action = _construction!.addPoint(worldPt);
    switch (action) {
      case ConstructionAction.complete:
        final obj = _construction!.result;
        if (obj != null) {
          widget.onObjectCreated?.call(obj);
        }
        _construction = ConstructionState(tool: _currentTool);
        break;
      case ConstructionAction.advanceStep:
        // Continue to next step
        break;
      case ConstructionAction.awaitInput:
        // Wait for more input
        break;
      case ConstructionAction.reset:
        _construction = ConstructionState(tool: _currentTool);
        break;
    }
    widget.onToolInstruction?.call(_construction?.currentInstruction ?? '');

    // Reset the placement guard so the next gesture can place a point
    // (needed for tap-based construction where _onScaleStart won't fire again)
    _constPointPlaced = false;

    // Update preview objects
    _objectsVersion++;
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
                painter: MathCanvas3DPainter(
                  cameraDistance: _cameraDistance,
                  cameraTheta: _cameraTheta,
                  cameraPhi: _cameraPhi,
                  cameraTarget: _cameraTarget,
                  projectionType: _projectionType,
                  showAxes: _showAxes,
                  showGrid: _showGrid,
                  objects: _objects,
                  objectsVersion: _objectsVersion,
                  canvasWidth: _canvasWidth,
                  canvasHeight: _canvasHeight,
                  backgroundColor: cs.surface,
                  axisColor: cs.onSurface,
                  gridColor: cs.outlineVariant.withValues(alpha: 0.3),
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

// ======================================================================
// MathCanvas3DPainter
// ======================================================================

/// CustomPainter that renders a 3D scene onto a 2D Canvas.
///
/// Uses painter's algorithm (back-to-front sorting) for correct occlusion.
class MathCanvas3DPainter extends CustomPainter {
  final double cameraDistance;
  final double cameraTheta;
  final double cameraPhi;
  final Point3D cameraTarget;
  final ProjectionType projectionType;
  final bool showAxes;
  final bool showGrid;
  final List<Object3D> objects;
  final int objectsVersion;
  final double canvasWidth;
  final double canvasHeight;
  final Color backgroundColor;
  final Color axisColor;
  final Color gridColor;
  final Color labelColor;

  const MathCanvas3DPainter({
    this.cameraDistance = 10,
    this.cameraTheta = 0,
    this.cameraPhi = 0.785,
    this.cameraTarget = Point3D.origin,
    this.projectionType = ProjectionType.parallel,
    this.showAxes = true,
    this.showGrid = true,
    this.objects = const [],
    this.objectsVersion = 0,
    this.canvasWidth = 800,
    this.canvasHeight = 600,
    this.backgroundColor = Colors.white,
    this.axisColor = Colors.black87,
    this.gridColor = const Color(0x4DCCCCCC),
    this.labelColor = Colors.grey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    // Build camera and projection
    final camera = Camera3D(
      target: cameraTarget,
      distance: cameraDistance,
      theta: cameraTheta,
      phi: cameraPhi,
    );
    final projection = projectionType == ProjectionType.parallel
        ? Projection3D.parallel(
            width: size.width,
            height: size.height,
            scale: _computeScale(),
          )
        : Projection3D.perspective(
            width: size.width,
            height: size.height,
            fov: 60,
          );

    // Draw grid (on xOz-plane)
    if (showGrid) {
      _drawGrid(canvas, size, camera, projection);
    }

    // Draw axes
    if (showAxes) {
      _drawAxes(canvas, size, camera, projection);
    }

    // Draw objects (sorted back-to-front)
    _drawObjects(canvas, size, camera, projection);
  }

  /// Compute a reasonable scale based on camera distance.
  double _computeScale() {
    return 800 / cameraDistance.clamp(0.1, 1000);
  }

  // ==================================================================
  // Background
  // ==================================================================

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  // ==================================================================
  // Grid
  // ==================================================================

  void _drawGrid(
    Canvas canvas,
    Size size,
    Camera3D camera,
    Projection3D projection,
  ) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Draw grid lines on the xOz-plane (y=0) from -10 to 10
    const gridRange = 10.0;
    const step = 1.0;
    final lines = <List<Offset>>[];

    // Lines along X (constant Z), at y=0
    for (double z = -gridRange; z <= gridRange; z += step) {
      if (z.abs() < 1e-10) continue; // Skip axis line
      final p1 = worldToScreen(Point3D(-gridRange, 0, z), camera, projection);
      final p2 = worldToScreen(Point3D(gridRange, 0, z), camera, projection);
      lines.add([Offset(p1.x, p1.y), Offset(p2.x, p2.y)]);
    }

    // Lines along Z (constant X), at y=0
    for (double x = -gridRange; x <= gridRange; x += step) {
      if (x.abs() < 1e-10) continue; // Skip axis line
      final p1 = worldToScreen(Point3D(x, 0, -gridRange), camera, projection);
      final p2 = worldToScreen(Point3D(x, 0, gridRange), camera, projection);
      lines.add([Offset(p1.x, p1.y), Offset(p2.x, p2.y)]);
    }

    for (final line in lines) {
      canvas.drawLine(line[0], line[1], paint);
    }
  }

  // ==================================================================
  // Axes
  // ==================================================================

  void _drawAxes(
    Canvas canvas,
    Size size,
    Camera3D camera,
    Projection3D projection,
  ) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = axisColor
      ..style = PaintingStyle.fill;

    final labelStyle = TextStyle(
      color: labelColor,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    const axisLength = 8.0;
    const origin = Point3D.origin;

    final axes = [
      ('X', Point3D(axisLength, 0, 0), const Offset(12, 0)),
      ('Y', Point3D(0, axisLength, 0), const Offset(0, -12)),
      ('Z', Point3D(0, 0, axisLength), const Offset(0, 12)),
    ];

    for (final (label, tip, labelOffset) in axes) {
      final originScreen = worldToScreen(origin, camera, projection);
      final tipScreen = worldToScreen(tip, camera, projection);
      final originPt = Offset(originScreen.x, originScreen.y);
      final tipPt = Offset(tipScreen.x, tipScreen.y);

      // Draw axis line
      canvas.drawLine(originPt, tipPt, axisPaint);

      // Draw arrow head
      _drawArrowHead(canvas, originPt, tipPt, arrowPaint);

      // Draw label
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, tipPt + labelOffset);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = (to - from);
    final length = direction.distance;
    if (length < 1) return;

    final unit = direction / length;
    final perp = Offset(-unit.dy, unit.dx);
    final arrowSize = 8.0;

    final tip = to;
    final base = to - unit * arrowSize;
    final left = base + perp * arrowSize * 0.4;
    final right = base - perp * arrowSize * 0.4;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  // ==================================================================
  // Objects rendering with painter's algorithm
  // ==================================================================

  void _drawObjects(
    Canvas canvas,
    Size size,
    Camera3D camera,
    Projection3D projection,
  ) {
    // Collect all renderables with depth info
    final renderables = <_Renderable>[];

    for (final obj in objects) {
      switch (obj.type) {
        case Object3DType.point:
          _collectPoint(renderables, obj, camera, projection);
        case Object3DType.line:
          _collectLine(renderables, obj, camera, projection);
        case Object3DType.plane:
          _collectPlane(renderables, obj, camera, projection);
        case Object3DType.surface:
          _collectSurface(renderables, obj, camera, projection);
        case Object3DType.sphere:
          _collectSphere(renderables, obj, camera, projection);
        case Object3DType.polyhedron:
          _collectPolyhedron(renderables, obj, camera, projection);
        case Object3DType.vector:
          _collectVector(renderables, obj, camera, projection);
        case Object3DType.curve:
          _collectCurve(renderables, obj, camera, projection);
      }
    }

    // Sort back-to-front (larger z = farther = drawn first)
    renderables.sort((a, b) => b.depth.compareTo(a.depth));

    // Draw in order
    for (final r in renderables) {
      r.draw(canvas);
    }
  }

  void _collectPoint(
    List<_Renderable> renderables,
    Object3D obj,
    Camera3D camera,
    Projection3D projection,
  ) {
    final screen = worldToScreen(obj.point, camera, projection);
    final _objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withOpacity(_objAlpha * obj.opacity);
    renderables.add(_Renderable(
      depth: screen.z,
      draw: (canvas) {
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(screen.x, screen.y), 4, paint);

        if (obj.label != null) {
          final tp = TextPainter(
            text: TextSpan(
              text: obj.label,
              style: TextStyle(color: color, fontSize: 11),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(screen.x + 6, screen.y - 6));
        }
      },
    ));
  }

  void _collectLine(
    List<_Renderable> renderables,
    Object3D obj,
    Camera3D camera,
    Projection3D projection,
  ) {
    final a = worldToScreen(obj.pointA, camera, projection);
    final b = worldToScreen(obj.pointB, camera, projection);
    final _objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withOpacity(_objAlpha * obj.opacity);
    final avgZ = (a.z + b.z) / 2;

    renderables.add(_Renderable(
      depth: avgZ,
      draw: (canvas) {
        final paint = Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
      },
    ));
  }

  void _collectPlane(
    List<_Renderable> renderables,
    Object3D obj,
    Camera3D camera,
    Projection3D projection,
  ) {
    // Render a plane as a grid of lines on the plane surface
    final a = obj.planeA;
    final b = obj.planeB;
    final c = obj.planeC;
    final d = obj.planeD;
    final _objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withOpacity(_objAlpha * obj.opacity);

    // Generate grid points on the plane within a range
    // Plane: ax + by + cz = d
    // Solve for the axis with largest coefficient for numeric stability
    const range = 5.0;
    const step = 1.0;
    final lines = <List<Offset>>[];
    var totalZ = 0.0;
    var count = 0;

    if (c.abs() > 1e-10) {
      // z = (d - ax - by) / c
      // Lines along X (constant Y)
      for (double y = -range; y <= range; y += step) {
        final pts = <Offset>[];
        for (double x = -range; x <= range; x += step * 0.5) {
          final z = (d - a * x - b * y) / c;
          final screen = worldToScreen(Point3D(x, y, z), camera, projection);
          pts.add(Offset(screen.x, screen.y));
          totalZ += screen.z;
          count++;
        }
        if (pts.length >= 2) lines.add(pts);
      }
      // Lines along Y (constant X)
      for (double x = -range; x <= range; x += step) {
        final pts = <Offset>[];
        for (double y = -range; y <= range; y += step * 0.5) {
          final z = (d - a * x - b * y) / c;
          final screen = worldToScreen(Point3D(x, y, z), camera, projection);
          pts.add(Offset(screen.x, screen.y));
        }
        if (pts.length >= 2) lines.add(pts);
      }
    } else if (b.abs() > 1e-10) {
      // y = (d - ax - cz) / b  — vertical plane, free variable z
      for (double z = -range; z <= range; z += step) {
        final pts = <Offset>[];
        for (double x = -range; x <= range; x += step * 0.5) {
          final y = (d - a * x - c * z) / b;
          final screen = worldToScreen(Point3D(x, y, z), camera, projection);
          pts.add(Offset(screen.x, screen.y));
          totalZ += screen.z;
          count++;
        }
        if (pts.length >= 2) lines.add(pts);
      }
      for (double x = -range; x <= range; x += step) {
        final pts = <Offset>[];
        for (double z = -range; z <= range; z += step * 0.5) {
          final y = (d - a * x - c * z) / b;
          final screen = worldToScreen(Point3D(x, y, z), camera, projection);
          pts.add(Offset(screen.x, screen.y));
        }
        if (pts.length >= 2) lines.add(pts);
      }
    } else if (a.abs() > 1e-10) {
      // x = (d - by - cz) / a  — vertical plane, free variable z
      for (double z = -range; z <= range; z += step) {
        final pts = <Offset>[];
        for (double y = -range; y <= range; y += step * 0.5) {
          final x = (d - b * y - c * z) / a;
          final screen = worldToScreen(Point3D(x, y, z), camera, projection);
          pts.add(Offset(screen.x, screen.y));
          totalZ += screen.z;
          count++;
        }
        if (pts.length >= 2) lines.add(pts);
      }
      for (double y = -range; y <= range; y += step) {
        final pts = <Offset>[];
        for (double z = -range; z <= range; z += step * 0.5) {
          final x = (d - b * y - c * z) / a;
          final screen = worldToScreen(Point3D(x, y, z), camera, projection);
          pts.add(Offset(screen.x, screen.y));
        }
        if (pts.length >= 2) lines.add(pts);
      }
    }

    final avgZ = count > 0 ? totalZ / count : 0.0;

    renderables.add(_Renderable(
      depth: avgZ,
      draw: (canvas) {
        final paint = Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        for (final pts in lines) {
          if (pts.length >= 2) {
            canvas.drawPoints(PointMode.polygon, pts, paint);
          }
        }
      },
    ));
  }

  void _collectSurface(
    List<_Renderable> renderables,
    Object3D obj,
    Camera3D camera,
    Projection3D projection,
  ) {
    final vertices = obj.vertices;
    final indices = obj.indices;
    if (vertices.isEmpty || indices.length < 3) return;

    final _objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withOpacity(_objAlpha * obj.opacity);
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Project all vertices
    final projected = <_ProjectedPoint>[];
    for (final v in vertices) {
      final s = worldToScreen(v, camera, projection);
      projected.add(_ProjectedPoint(
        screen: Offset(s.x, s.y),
        depth: s.z,
        world: v,
      ));
    }

    // Create triangle renderables
    for (int i = 0; i < indices.length; i += 3) {
      if (i + 2 >= indices.length) break;
      final p0 = projected[indices[i]];
      final p1 = projected[indices[i + 1]];
      final p2 = projected[indices[i + 2]];

      final avgDepth = (p0.depth + p1.depth + p2.depth) / 3;
      final triPath = Path()
        ..moveTo(p0.screen.dx, p0.screen.dy)
        ..lineTo(p1.screen.dx, p1.screen.dy)
        ..lineTo(p2.screen.dx, p2.screen.dy)
        ..close();

      renderables.add(_Renderable(
        depth: avgDepth,
        draw: (canvas) {
          canvas.drawPath(triPath, fillPaint);
          canvas.drawPath(triPath, strokePaint);
        },
      ));
    }
  }

  void _collectSphere(
    List<_Renderable> renderables,
    Object3D obj,
    Camera3D camera,
    Projection3D projection,
  ) {
    final center = obj.sphereCenter;
    final radius = obj.sphereRadius;
    final _objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withOpacity(_objAlpha * obj.opacity);
    final segments = 16;

    // Generate wireframe sphere: latitude and longitude lines
    final lines = <List<Offset>>[];
    var totalZ = 0.0;
    var count = 0;

    // Longitude lines (around Y axis)
    for (int i = 0; i < segments; i++) {
      final theta = i * 2 * dart_math.pi / segments;
      final pts = <Offset>[];
      for (int j = 0; j <= segments; j++) {
        final phi = -dart_math.pi / 2 + j * dart_math.pi / segments;
        final x = center.x + radius * dart_math.cos(phi) * dart_math.cos(theta);
        final y = center.y + radius * dart_math.sin(phi);
        final z = center.z + radius * dart_math.cos(phi) * dart_math.sin(theta);
        final screen = worldToScreen(Point3D(x, y, z), camera, projection);
        pts.add(Offset(screen.x, screen.y));
        totalZ += screen.z;
        count++;
      }
      if (pts.length >= 2) lines.add(pts);
    }

    // Latitude lines
    for (int j = 1; j < segments; j++) {
      final phi = -dart_math.pi / 2 + j * dart_math.pi / segments;
      final pts = <Offset>[];
      for (int i = 0; i <= segments; i++) {
        final theta = i * 2 * dart_math.pi / segments;
        final x = center.x + radius * dart_math.cos(phi) * dart_math.cos(theta);
        final y = center.y + radius * dart_math.sin(phi);
        final z = center.z + radius * dart_math.cos(phi) * dart_math.sin(theta);
        final screen = worldToScreen(Point3D(x, y, z), camera, projection);
        pts.add(Offset(screen.x, screen.y));
      }
      if (pts.length >= 2) lines.add(pts);
    }

    final avgZ = count > 0
        ? totalZ / count
        : (worldToScreen(center, camera, projection).z);

    renderables.add(_Renderable(
      depth: avgZ,
      draw: (canvas) {
        final paint = Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        for (final pts in lines) {
          canvas.drawPoints(PointMode.polygon, pts, paint);
        }
      },
    ));
  }

  void _collectPolyhedron(
    List<_Renderable> renderables,
    Object3D obj,
    Camera3D camera,
    Projection3D projection,
  ) {
    // Same as surface: triangulated faces
    _collectSurface(renderables, obj, camera, projection);
  }

  void _collectVector(
    List<_Renderable> renderables,
    Object3D obj,
    Camera3D camera,
    Projection3D projection,
  ) {
    final origin = obj.point;
    final tip = origin + obj.vector;
    final _objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withOpacity(_objAlpha * obj.opacity);

    final originScreen = worldToScreen(origin, camera, projection);
    final tipScreen = worldToScreen(tip, camera, projection);
    final avgZ = (originScreen.z + tipScreen.z) / 2;

    renderables.add(_Renderable(
      depth: avgZ,
      draw: (canvas) {
        final paint = Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        final from = Offset(originScreen.x, originScreen.y);
        final to = Offset(tipScreen.x, tipScreen.y);
        canvas.drawLine(from, to, paint);

        // Arrow head
        _drawArrowHeadStatic(canvas, from, to, color);
      },
    ));
  }

  void _drawArrowHeadStatic(
      Canvas canvas, Offset from, Offset to, Color color) {
    final direction = (to - from);
    final length = direction.distance;
    if (length < 5) return;

    final unit = direction / length;
    final perp = Offset(-unit.dy, unit.dx);
    final arrowSize = 10.0;

    final tip = to;
    final base = to - unit * arrowSize;
    final left = base + perp * arrowSize * 0.4;
    final right = base - perp * arrowSize * 0.4;

    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _collectCurve(
    List<_Renderable> renderables,
    Object3D obj,
    Camera3D camera,
    Projection3D projection,
  ) {
    final vertices = obj.vertices;
    if (vertices.length < 2) return;

    final _objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withOpacity(_objAlpha * obj.opacity);

    // Project all points
    final projected = <Offset>[];
    var totalZ = 0.0;
    for (final v in vertices) {
      final s = worldToScreen(v, camera, projection);
      projected.add(Offset(s.x, s.y));
      totalZ += s.z;
    }
    final avgZ = totalZ / vertices.length;

    renderables.add(_Renderable(
      depth: avgZ,
      draw: (canvas) {
        final paint = Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawPoints(PointMode.polygon, projected, paint);
      },
    ));
  }

  // ==================================================================
  // shouldRepaint
  // ==================================================================

  @override
  bool shouldRepaint(MathCanvas3DPainter oldDelegate) {
    return oldDelegate.cameraDistance != cameraDistance ||
        oldDelegate.cameraTheta != cameraTheta ||
        oldDelegate.cameraPhi != cameraPhi ||
        oldDelegate.cameraTarget != cameraTarget ||
        oldDelegate.projectionType != projectionType ||
        oldDelegate.showAxes != showAxes ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.objectsVersion != objectsVersion ||
        oldDelegate.canvasWidth != canvasWidth ||
        oldDelegate.canvasHeight != canvasHeight ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.gridColor != gridColor;
  }
}

// ======================================================================
// Internal types
// ======================================================================

/// A projected point with screen position and depth.
class _ProjectedPoint {
  final Offset screen;
  final double depth;
  final Point3D world;

  const _ProjectedPoint({
    required this.screen,
    required this.depth,
    required this.world,
  });
}

/// A renderable element with depth for z-sorting.
class _Renderable {
  final double depth;
  final void Function(Canvas canvas) draw;

  const _Renderable({
    required this.depth,
    required this.draw,
  });
}
