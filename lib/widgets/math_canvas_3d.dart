import 'dart:math' as dart_math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

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

enum _NavigationGesture { none, orbit, pan }

enum _ViewAction {
  toggleAxes,
  togglePlane,
  toggleGrid,
  parallelProjection,
  perspectiveProjection,
  standardView,
  topView,
  frontView,
  sideView,
}

/// A 3D rendering canvas using Flutter's CustomPainter.
///
/// Renders a 3D scene with:
/// - Orbital camera controls (drag to rotate, scroll to zoom)
/// - Coordinate axes with labels
/// - Coordinate plane and optional grid on the xOy-plane
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
  static const double _defaultDistance = 10;
  static const double _defaultTheta = dart_math.pi * 0.75;
  static const double _defaultPhi = dart_math.pi / 6;
  static const double _orthographicDistanceScale = 0.6;

  // Camera state
  double _cameraDistance = _defaultDistance;
  double _cameraTheta = _defaultTheta;
  double _cameraPhi = _defaultPhi;
  Point3D _cameraTarget = Point3D.origin;

  // Visual state
  ProjectionType _projectionType = ProjectionType.parallel;
  bool _showAxes = true;
  bool _showPlane = true;
  bool _showGrid = false;

  // Scene objects
  final List<Object3D> _objects = [];
  int _objectsVersion = 0;

  /// Get the list of objects (unmodifiable).
  List<Object3D> get objects => List.unmodifiable(_objects);

  // Construction state
  ConstructionState? _construction;
  Object3D? _constructionPreview;
  ConstructionTool _currentTool = ConstructionTool.move;

  // Construction gesture tracking (for 3D point placement with height)
  Point3D? _constGroundPos; // ground (z=0) position during construction
  double _constHeight = 0; // height offset from ground during drag
  Offset? _constStartPoint; // screen position where point gesture started
  bool _constPointPlaced = false; // whether the point was committed

  // Gesture state
  Offset? _lastFocalPoint;
  double?
      _initialScaleDistance; // camera distance at gesture start (for stable zoom)
  final FocusNode _focusNode = FocusNode(debugLabel: 'MathCanvas3D');
  int? _mousePointer;
  Offset? _lastMousePosition;
  _NavigationGesture _mouseGesture = _NavigationGesture.none;
  double? _panZoomInitialDistance;
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

  /// Whether the xOy coordinate plane is visible.
  bool get showPlane => _showPlane;

  /// Number of objects in the scene.
  int get objectCount => _objects.length;

  /// Set the projection type.
  void setProjectionType(ProjectionType type) {
    setState(() {
      _projectionType = type;
    });
    widget.onViewportChange?.call();
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

  /// Toggle xOy-plane visibility.
  void togglePlane() {
    setState(() {
      _showPlane = !_showPlane;
    });
  }

  /// Reset the camera to the default view.
  void resetView() {
    setState(() {
      _cameraDistance = _defaultDistance;
      _cameraTheta = _defaultTheta;
      _cameraPhi = _defaultPhi;
      _cameraTarget = Point3D.origin;
    });
    widget.onViewportChange?.call();
  }

  /// Zoom in by one GeoGebra-style toolbar step.
  void zoomIn() => _zoomBy(1.2);

  /// Zoom out by one GeoGebra-style toolbar step.
  void zoomOut() => _zoomBy(1 / 1.2);

  /// Fit finite scene objects into the current viewport.
  void fitToView() {
    final points = <Point3D>[];
    for (final object in _objects) {
      switch (object.type) {
        case Object3DType.point:
          points.add(object.point);
        case Object3DType.line:
          points.addAll([object.pointA, object.pointB]);
        case Object3DType.plane:
          break;
        case Object3DType.surface:
        case Object3DType.polyhedron:
        case Object3DType.curve:
          points.addAll(object.vertices);
        case Object3DType.sphere:
          final c = object.sphereCenter;
          final r = object.sphereRadius;
          points.addAll([
            Point3D(c.x - r, c.y - r, c.z - r),
            Point3D(c.x + r, c.y + r, c.z + r),
          ]);
        case Object3DType.vector:
          points.addAll([object.point, object.point + object.vector]);
      }
    }

    if (points.isEmpty) {
      resetView();
      return;
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var minZ = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    var maxZ = -double.infinity;
    for (final point in points) {
      if (!point.x.isFinite || !point.y.isFinite || !point.z.isFinite) continue;
      minX = dart_math.min(minX, point.x);
      minY = dart_math.min(minY, point.y);
      minZ = dart_math.min(minZ, point.z);
      maxX = dart_math.max(maxX, point.x);
      maxY = dart_math.max(maxY, point.y);
      maxZ = dart_math.max(maxZ, point.z);
    }
    if (!minX.isFinite) return;

    final maxExtent = dart_math.max(
      dart_math.max(maxX - minX, maxY - minY),
      maxZ - minZ,
    );
    setState(() {
      _cameraTarget = Point3D(
        (minX + maxX) / 2,
        (minY + maxY) / 2,
        (minZ + maxZ) / 2,
      );
      _cameraDistance = dart_math.max(4.0, maxExtent * 1.35);
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
      _objects.add(
        Object3D.surface(
          vertices: vertices,
          indices: indices,
          normals: normals,
          color: color,
          opacity: opacity,
        ),
      );
      _objectsVersion++;
    });
  }

  /// Get the current construction state (null if no tool is active).
  ConstructionState? get constructionState => _construction;

  /// Get the transient object shown while the active tool awaits input.
  Object3D? get constructionPreview => _constructionPreview;

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
        _constructionPreview = null;
      } else {
        _construction = ConstructionState(tool: tool);
        _constructionPreview = null;
      }
      _constPointPlaced = false;
      _constGroundPos = null;
      _constStartPoint = null;
      _constructionPreview = null;
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
    _focusNode.dispose();
    super.dispose();
  }

  // ==================================================================
  // Gesture handling
  // ==================================================================

  bool get _panModifierPressed {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight) ||
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
  }

  void _onPointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    if (event.kind != PointerDeviceKind.mouse) return;

    final secondary = event.buttons & kSecondaryMouseButton != 0;
    final primary = event.buttons & kPrimaryMouseButton != 0;
    final mayNavigate = _currentTool == ConstructionTool.move || secondary;
    if (!mayNavigate || (!primary && !secondary)) return;

    _mousePointer = event.pointer;
    _lastMousePosition = event.localPosition;
    _mouseGesture = secondary
        ? _NavigationGesture.orbit
        : (_panModifierPressed
            ? _NavigationGesture.pan
            : _NavigationGesture.orbit);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _mousePointer || _lastMousePosition == null) return;
    final delta = event.localPosition - _lastMousePosition!;
    _lastMousePosition = event.localPosition;
    if (delta == Offset.zero) return;

    switch (_mouseGesture) {
      case _NavigationGesture.orbit:
        _orbitBy(delta);
      case _NavigationGesture.pan:
        _panBy(delta);
      case _NavigationGesture.none:
        break;
    }
  }

  void _onPointerUp(PointerEvent event) {
    if (event.pointer != _mousePointer) return;
    _mousePointer = null;
    _lastMousePosition = null;
    _mouseGesture = _NavigationGesture.none;
    widget.onViewportChange?.call();
  }

  void _orbitBy(Offset delta) {
    setState(() {
      _cameraTheta -= delta.dx * 0.008;
      _cameraPhi = (_cameraPhi - delta.dy * 0.008).clamp(
        -dart_math.pi * 0.49,
        dart_math.pi * 0.49,
      );
    });
  }

  void _panBy(Offset delta) {
    final panned = camera.pan(deltaX: delta.dx, deltaY: delta.dy);
    setState(() => _cameraTarget = panned.target);
  }

  void _zoomBy(double factor, {Offset? focalPoint}) {
    if (!factor.isFinite || factor <= 0) return;
    final oldDistance = _cameraDistance;
    final newDistance = (oldDistance / factor).clamp(0.25, 500.0).toDouble();
    if ((newDistance - oldDistance).abs() < 1e-10) return;

    var newTarget = _cameraTarget;
    if (focalPoint != null &&
        _projectionType == ProjectionType.parallel &&
        _canvasWidth > 0 &&
        _canvasHeight > 0) {
      final view = camera.viewMatrix();
      final right = Vector3D(view[0], view[4], view[8]);
      final up = Vector3D(view[1], view[5], view[9]);
      final ndcX = 2 * focalPoint.dx / _canvasWidth - 1;
      final ndcY = 1 - 2 * focalPoint.dy / _canvasHeight;
      final aspect = _canvasWidth / _canvasHeight;
      final oldHalfHeight = oldDistance * _orthographicDistanceScale;
      final newHalfHeight = newDistance * _orthographicDistanceScale;
      final difference = oldHalfHeight - newHalfHeight;
      final shift =
          right * (ndcX * difference * aspect) + up * (ndcY * difference);
      newTarget = _cameraTarget + shift;
    }

    setState(() {
      _cameraDistance = newDistance;
      _cameraTarget = newTarget;
    });
    widget.onViewportChange?.call();
  }

  void _setView({required double theta, required double phi}) {
    setState(() {
      _cameraTheta = theta;
      _cameraPhi = phi;
    });
    widget.onViewportChange?.call();
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_mousePointer != null) return;
    _lastFocalPoint = details.localFocalPoint;
    _initialScaleDistance = _cameraDistance;

    // In construction mode, start tracking for point + height placement
    if (_currentTool != ConstructionTool.move && _construction != null) {
      _constStartPoint = details.localFocalPoint;
      _constGroundPos = _screenToPointOnPlane(
        details.localFocalPoint.dx,
        details.localFocalPoint.dy,
      );
      _constHeight = 0;
      _constPointPlaced = false;
      _constructionPreview = _construction?.previewForPoint(
        _constGroundPos ?? Point3D.origin,
      );
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_mousePointer != null) return;
    final focalPoint = details.localFocalPoint;
    final scale = details.scale;

    // ===== Construction mode: tap → point on ground, drag → adjust height
    if (_currentTool != ConstructionTool.move &&
        _construction != null &&
        !_constPointPlaced) {
      if (_constGroundPos != null && _constStartPoint != null) {
        // GeoGebra fixes x/y at press time, then uses vertical movement for z.
        final pixelsPerWorldUnit =
            _canvasHeight / (_cameraDistance * _orthographicDistanceScale * 2);
        _constHeight =
            -((focalPoint.dy - _constStartPoint!.dy) / pixelsPerWorldUnit);
        _constructionPreview = _construction?.previewForPoint(
          Point3D(_constGroundPos!.x, _constGroundPos!.y, _constHeight),
        );
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

      _orbitBy(Offset(dx, dy));
    } else if (details.pointerCount >= 2) {
      // GeoGebra combines two-finger translation and pinch in one gesture.
      final delta =
          _lastFocalPoint == null ? Offset.zero : focalPoint - _lastFocalPoint!;
      final startDistance = _initialScaleDistance ?? _cameraDistance;
      final newDistance = (startDistance / scale).clamp(0.25, 500.0).toDouble();
      final panned = Camera3D(
        target: _cameraTarget,
        distance: newDistance,
        theta: _cameraTheta,
        phi: _cameraPhi,
      ).pan(deltaX: delta.dx, deltaY: delta.dy);
      setState(() {
        _cameraDistance = newDistance;
        _cameraTarget = panned.target;
      });
    }

    _lastFocalPoint = focalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_mousePointer != null) return;
    // ===== Construction mode: finalize the point with height
    if (_currentTool != ConstructionTool.move &&
        _construction != null &&
        !_constPointPlaced &&
        _constGroundPos != null) {
      _constPointPlaced = true;
      final finalPos = Point3D(
        _constGroundPos!.x,
        _constGroundPos!.y,
        _constHeight,
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
      final groundPos = _screenToPointOnPlane(
        _constStartPoint!.dx,
        _constStartPoint!.dy,
      );
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
    _constructionPreview = null;
    widget.onViewportChange?.call();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Wheel up zooms in, wheel down zooms out. Exponential scaling keeps
      // mouse wheels and high-resolution touchpads consistent.
      final factor = dart_math.exp(-event.scrollDelta.dy * 0.0015);
      _zoomBy(factor, focalPoint: event.localPosition);
    }
  }

  void _onPointerPanZoomStart(PointerPanZoomStartEvent event) {
    _focusNode.requestFocus();
    _panZoomInitialDistance = _cameraDistance;
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final initialDistance = _panZoomInitialDistance ?? _cameraDistance;
    final newDistance =
        (initialDistance / event.scale).clamp(0.25, 500.0).toDouble();
    final panned = Camera3D(
      target: _cameraTarget,
      distance: newDistance,
      theta: _cameraTheta,
      phi: _cameraPhi,
    ).pan(deltaX: event.panDelta.dx, deltaY: event.panDelta.dy);
    setState(() {
      _cameraDistance = newDistance;
      _cameraTarget = panned.target;
    });
  }

  void _onPointerPanZoomEnd(PointerPanZoomEndEvent event) {
    _panZoomInitialDistance = null;
    widget.onViewportChange?.call();
  }

  // ==================================================================
  // Construction click handling
  // ==================================================================

  /// Compute the orthographic scale matching the painter's projection.
  double _computeScaleForCanvas() {
    return _cameraDistance.clamp(0.25, 500) * _orthographicDistanceScale;
  }

  /// Convert a local canvas position to a 3D point on the xOy ground plane.
  Point3D _screenToPointOnPlane(double screenX, double screenY) {
    final cam = Camera3D(
      target: _cameraTarget,
      distance: _cameraDistance,
      theta: _cameraTheta,
      phi: _cameraPhi,
    );

    final viewMatrix = cam.viewMatrix();
    final pos = cam.position;
    final right = Vector3D(viewMatrix[0], viewMatrix[4], viewMatrix[8]);
    final up = Vector3D(viewMatrix[1], viewMatrix[5], viewMatrix[9]);
    final forward = (_cameraTarget - pos).normalized();

    final ndcX = 2 * screenX / _canvasWidth - 1;
    final ndcY = 1 - 2 * screenY / _canvasHeight;
    final aspect = _canvasWidth / _canvasHeight;
    late Point3D rayOrigin;
    late Vector3D rayDirection;

    if (_projectionType == ProjectionType.parallel) {
      final halfHeight = _computeScaleForCanvas();
      final offset =
          right * (ndcX * halfHeight * aspect) + up * (ndcY * halfHeight);
      rayOrigin = pos + offset;
      rayDirection = forward;
    } else {
      final tanHalfFov = dart_math.tan(dart_math.pi / 6); // 60° FOV
      rayOrigin = pos;
      rayDirection = (forward +
              right * (ndcX * tanHalfFov * aspect) +
              up * (ndcY * tanHalfFov))
          .normalized();
    }

    if (rayDirection.z.abs() < 1e-10) {
      return Point3D(_cameraTarget.x, _cameraTarget.y, 0);
    }
    final distance = -rayOrigin.z / rayDirection.z;
    if (!distance.isFinite) {
      return Point3D(_cameraTarget.x, _cameraTarget.y, 0);
    }
    return Point3D(
      rayOrigin.x + rayDirection.x * distance,
      rayOrigin.y + rayDirection.y * distance,
      0,
    );
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
    _constructionPreview = _construction?.previewObject;
  }

  // ==================================================================
  // Build
  // ==================================================================

  void _handleViewAction(_ViewAction action) {
    switch (action) {
      case _ViewAction.toggleAxes:
        toggleAxes();
      case _ViewAction.togglePlane:
        togglePlane();
      case _ViewAction.toggleGrid:
        toggleGrid();
      case _ViewAction.parallelProjection:
        setProjectionType(ProjectionType.parallel);
      case _ViewAction.perspectiveProjection:
        setProjectionType(ProjectionType.perspective);
      case _ViewAction.standardView:
        resetView();
      case _ViewAction.topView:
        _setView(theta: _defaultTheta, phi: dart_math.pi * 0.49);
      case _ViewAction.frontView:
        _setView(theta: dart_math.pi, phi: 0);
      case _ViewAction.sideView:
        _setView(theta: dart_math.pi / 2, phi: 0);
    }
  }

  Widget _floatingControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 2,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, size: 21),
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            fixedSize: const Size(40, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_ViewAction> _menuToggle({
    required _ViewAction value,
    required IconData icon,
    required String label,
    required bool selected,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (selected) const Icon(Icons.check, size: 18),
        ],
      ),
    );
  }

  List<PopupMenuEntry<_ViewAction>> _viewMenuItems() => [
        _menuToggle(
          value: _ViewAction.toggleAxes,
          icon: Icons.straighten,
          label: '坐标轴',
          selected: _showAxes,
        ),
        _menuToggle(
          value: _ViewAction.togglePlane,
          icon: Icons.crop_square,
          label: 'xOy 平面',
          selected: _showPlane,
        ),
        _menuToggle(
          value: _ViewAction.toggleGrid,
          icon: Icons.grid_on,
          label: '网格',
          selected: _showGrid,
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _ViewAction.parallelProjection,
          child: Row(
            children: [
              const Icon(Icons.view_in_ar, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('平行投影')),
              if (_projectionType == ProjectionType.parallel)
                const Icon(Icons.check, size: 18),
            ],
          ),
        ),
        PopupMenuItem(
          value: _ViewAction.perspectiveProjection,
          child: Row(
            children: [
              const Icon(Icons.vrpano, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('透视投影')),
              if (_projectionType == ProjectionType.perspective)
                const Icon(Icons.check, size: 18),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _ViewAction.standardView,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.home_outlined, size: 20),
            title: Text('标准视图'),
          ),
        ),
        const PopupMenuItem(
          value: _ViewAction.topView,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.vertical_align_bottom, size: 20),
            title: Text('俯视 xOy'),
          ),
        ),
        const PopupMenuItem(
          value: _ViewAction.frontView,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.crop_landscape, size: 20),
            title: Text('正视 xOz'),
          ),
        ),
        const PopupMenuItem(
          value: _ViewAction.sideView,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.crop_portrait, size: 20),
            title: Text('侧视 yOz'),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasWidth = constraints.maxWidth;
        _canvasHeight = constraints.maxHeight;

        return Focus(
          focusNode: _focusNode,
          child: MouseRegion(
            cursor: _currentTool == ConstructionTool.move
                ? SystemMouseCursors.grab
                : SystemMouseCursors.precise,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              onPointerSignal: _onPointerSignal,
              onPointerPanZoomStart: _onPointerPanZoomStart,
              onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
              onPointerPanZoomEnd: _onPointerPanZoomEnd,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: MathCanvas3DPainter(
                          cameraDistance: _cameraDistance,
                          cameraTheta: _cameraTheta,
                          cameraPhi: _cameraPhi,
                          cameraTarget: _cameraTarget,
                          projectionType: _projectionType,
                          showAxes: _showAxes,
                          showPlane: _showPlane,
                          showGrid: _showGrid,
                          objects: _objects,
                          constructionPreview: _constructionPreview,
                          objectsVersion: _objectsVersion,
                          canvasWidth: _canvasWidth,
                          canvasHeight: _canvasHeight,
                          backgroundColor: cs.surface,
                          axisColor: cs.onSurface,
                          gridColor: cs.outlineVariant.withValues(alpha: 0.45),
                          labelColor: cs.onSurfaceVariant,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: cs.surface,
                          elevation: 2,
                          shape: const CircleBorder(),
                          child: PopupMenuButton<_ViewAction>(
                            tooltip: '3D 视图设置',
                            icon: const Icon(Icons.settings, size: 21),
                            onSelected: _handleViewAction,
                            itemBuilder: (_) => _viewMenuItems(),
                            style: IconButton.styleFrom(
                              fixedSize: const Size(40, 40),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Column(
                          children: [
                            _floatingControl(
                              icon: Icons.filter_center_focus,
                              tooltip: '缩放至适合',
                              onPressed: fitToView,
                            ),
                            _floatingControl(
                              icon: Icons.zoom_in,
                              tooltip: '放大',
                              onPressed: zoomIn,
                            ),
                            _floatingControl(
                              icon: Icons.zoom_out,
                              tooltip: '缩小',
                              onPressed: zoomOut,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
  final bool showPlane;
  final bool showGrid;
  final List<Object3D> objects;
  final Object3D? constructionPreview;
  final int objectsVersion;
  final double canvasWidth;
  final double canvasHeight;
  final Color backgroundColor;
  final Color axisColor;
  final Color gridColor;
  final Color labelColor;

  const MathCanvas3DPainter({
    this.cameraDistance = 10,
    this.cameraTheta = dart_math.pi * 0.75,
    this.cameraPhi = dart_math.pi / 6,
    this.cameraTarget = Point3D.origin,
    this.projectionType = ProjectionType.parallel,
    this.showAxes = true,
    this.showPlane = true,
    this.showGrid = false,
    this.objects = const [],
    this.constructionPreview,
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

    if (showPlane) {
      _drawCoordinatePlane(canvas, camera, projection);
    }

    // Draw grid on the xOy-plane.
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
    return cameraDistance.clamp(0.25, 500) *
        MathCanvas3DState._orthographicDistanceScale;
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

  void _drawCoordinatePlane(
    Canvas canvas,
    Camera3D camera,
    Projection3D projection,
  ) {
    final extent = dart_math.max(6.0, camera.distance * 1.2);
    final center = camera.target;
    final corners = [
      Point3D(center.x - extent, center.y - extent, 0),
      Point3D(center.x + extent, center.y - extent, 0),
      Point3D(center.x + extent, center.y + extent, 0),
      Point3D(center.x - extent, center.y + extent, 0),
    ].map((point) => worldToScreen(point, camera, projection)).toList();
    final path = Path()
      ..moveTo(corners[0].x, corners[0].y)
      ..lineTo(corners[1].x, corners[1].y)
      ..lineTo(corners[2].x, corners[2].y)
      ..lineTo(corners[3].x, corners[3].y)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = axisColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    Camera3D camera,
    Projection3D projection,
  ) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Keep the grid around the view target so panning does not reveal a blank
    // canvas while retaining the same world-unit spacing.
    final gridRange = dart_math.max(10.0, camera.distance * 1.5);
    final gridCenter = camera.target;
    const step = 1.0;
    final lines = <List<Offset>>[];

    // Lines along X (constant Y).
    for (double y = gridCenter.y - gridRange;
        y <= gridCenter.y + gridRange;
        y += step) {
      if ((y - gridCenter.y).abs() < 1e-10) continue;
      final p1 = worldToScreen(
        Point3D(gridCenter.x - gridRange, y, 0),
        camera,
        projection,
      );
      final p2 = worldToScreen(
        Point3D(gridCenter.x + gridRange, y, 0),
        camera,
        projection,
      );
      lines.add([Offset(p1.x, p1.y), Offset(p2.x, p2.y)]);
    }

    // Lines along Y (constant X).
    for (double x = gridCenter.x - gridRange;
        x <= gridCenter.x + gridRange;
        x += step) {
      if ((x - gridCenter.x).abs() < 1e-10) continue;
      final p1 = worldToScreen(
        Point3D(x, gridCenter.y - gridRange, 0),
        camera,
        projection,
      );
      final p2 = worldToScreen(
        Point3D(x, gridCenter.y + gridRange, 0),
        camera,
        projection,
      );
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
    const axisLength = 6.0;
    const origin = Point3D.origin;

    final axes = [
      (
        'x',
        const Point3D(-axisLength, 0, 0),
        const Point3D(axisLength, 0, 0),
        const Color(0xFFE32636),
        const Offset(9, 1),
      ),
      (
        'y',
        const Point3D(0, -axisLength, 0),
        const Point3D(0, axisLength, 0),
        const Color(0xFF18862A),
        const Offset(7, -10),
      ),
      (
        'z',
        const Point3D(0, 0, -axisLength),
        const Point3D(0, 0, axisLength),
        const Color(0xFF1649E8),
        const Offset(7, -4),
      ),
    ];

    for (final (label, start, tip, color, labelOffset) in axes) {
      final startScreen = worldToScreen(start, camera, projection);
      final tipScreen = worldToScreen(tip, camera, projection);
      final startPt = Offset(startScreen.x, startScreen.y);
      final tipPt = Offset(tipScreen.x, tipScreen.y);
      final axisPaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final arrowPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawLine(startPt, tipPt, axisPaint);
      _drawArrowHead(canvas, startPt, tipPt, arrowPaint);

      for (var value = -5; value <= 5; value++) {
        if (value == 0) continue;
        final point = switch (label) {
          'x' => Point3D(value.toDouble(), 0, 0),
          'y' => Point3D(0, value.toDouble(), 0),
          _ => Point3D(0, 0, value.toDouble()),
        };
        final screen = worldToScreen(point, camera, projection);
        final axisDirection = (tipPt - startPt);
        if (axisDirection.distance < 1) continue;
        final normal = Offset(-axisDirection.dy, axisDirection.dx) /
            axisDirection.distance;
        final center = Offset(screen.x, screen.y);
        canvas.drawLine(center - normal * 3, center + normal * 3, axisPaint);

        final tickPainter = TextPainter(
          text: TextSpan(
            text: '$value',
            style: TextStyle(color: color, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tickPainter.paint(canvas, center + normal * 5);
      }

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, tipPt + labelOffset);
    }

    final originScreen = worldToScreen(origin, camera, projection);
    canvas.drawCircle(
      Offset(originScreen.x, originScreen.y),
      2.5,
      Paint()..color = labelColor,
    );
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

    final preview = constructionPreview;
    if (preview != null) {
      switch (preview.type) {
        case Object3DType.point:
          _collectPoint(renderables, preview, camera, projection);
        case Object3DType.line:
          _collectLine(renderables, preview, camera, projection);
        case Object3DType.plane:
          _collectPlane(renderables, preview, camera, projection);
        case Object3DType.surface:
          _collectSurface(renderables, preview, camera, projection);
        case Object3DType.sphere:
          _collectSphere(renderables, preview, camera, projection);
        case Object3DType.polyhedron:
          _collectPolyhedron(renderables, preview, camera, projection);
        case Object3DType.vector:
          _collectVector(renderables, preview, camera, projection);
        case Object3DType.curve:
          _collectCurve(renderables, preview, camera, projection);
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
    final objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withValues(alpha: objAlpha * obj.opacity);
    renderables.add(
      _Renderable(
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
      ),
    );
  }

  void _collectLine(
    List<_Renderable> renderables,
    Object3D obj,
    Camera3D camera,
    Projection3D projection,
  ) {
    final a = worldToScreen(obj.pointA, camera, projection);
    final b = worldToScreen(obj.pointB, camera, projection);
    final objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withValues(alpha: objAlpha * obj.opacity);
    final avgZ = (a.z + b.z) / 2;

    renderables.add(
      _Renderable(
        depth: avgZ,
        draw: (canvas) {
          final paint = Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;
          canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
        },
      ),
    );
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
    final objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withValues(alpha: objAlpha * obj.opacity);

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

    renderables.add(
      _Renderable(
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
      ),
    );
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

    final objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withValues(alpha: objAlpha * obj.opacity);
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
      projected.add(
        _ProjectedPoint(screen: Offset(s.x, s.y), depth: s.z, world: v),
      );
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

      renderables.add(
        _Renderable(
          depth: avgDepth,
          draw: (canvas) {
            canvas.drawPath(triPath, fillPaint);
            canvas.drawPath(triPath, strokePaint);
          },
        ),
      );
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
    final objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withValues(alpha: objAlpha * obj.opacity);
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

    renderables.add(
      _Renderable(
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
      ),
    );
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
    final objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withValues(alpha: objAlpha * obj.opacity);

    final originScreen = worldToScreen(origin, camera, projection);
    final tipScreen = worldToScreen(tip, camera, projection);
    final avgZ = (originScreen.z + tipScreen.z) / 2;

    renderables.add(
      _Renderable(
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
      ),
    );
  }

  void _drawArrowHeadStatic(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
  ) {
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

    final objAlpha = ((obj.color >> 24) & 0xFF) / 255.0;
    final color = Color(obj.color).withValues(alpha: objAlpha * obj.opacity);

    // Project all points
    final projected = <Offset>[];
    var totalZ = 0.0;
    for (final v in vertices) {
      final s = worldToScreen(v, camera, projection);
      projected.add(Offset(s.x, s.y));
      totalZ += s.z;
    }
    final avgZ = totalZ / vertices.length;

    renderables.add(
      _Renderable(
        depth: avgZ,
        draw: (canvas) {
          final paint = Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;
          canvas.drawPoints(PointMode.polygon, projected, paint);
        },
      ),
    );
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
        oldDelegate.showPlane != showPlane ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.objectsVersion != objectsVersion ||
        oldDelegate.canvasWidth != canvasWidth ||
        oldDelegate.canvasHeight != canvasHeight ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.constructionPreview != constructionPreview;
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

  const _Renderable({required this.depth, required this.draw});
}
