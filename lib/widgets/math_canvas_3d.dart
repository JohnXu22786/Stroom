import 'dart:math' as dart_math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/math_3d_construction.dart';
import '../models/math_3d_object.dart';
import '../models/math_3d_scene.dart';
import '../models/math_3d_tool.dart';

export '../models/math_3d_scene.dart' show ProjectionType, StandardView;
export '../models/math_3d_tool.dart' show ConstructionTool;

// ======================================================================
// Callbacks
// ======================================================================

typedef On3DReady = void Function();
typedef On3DViewportChange = void Function();
typedef On3DSceneChanged = void Function();
typedef On3DToolInstruction = void Function(String instruction);
typedef On3DNumericInput = Future<double?> Function(
    String prompt, double initial);

/// Point capturing modes (GeoGebra: Automatic / Snap to Grid / Fixed to Grid / Off).
enum PointCapturing {
  off,
  automatic,
  snapToGrid,
  fixedToGrid,
}

/// The 3D rendering canvas — a software 3D renderer on Flutter's Canvas.
///
/// Features:
/// - Z-up coordinate system with xOy ground plane, adaptive grid and ticked axes
/// - Parallel / perspective / oblique projections, auto-rotation
/// - Filled surfaces with back-face culling and simple diffuse lighting
/// - Painter's-algorithm depth sorting of faces, lines, points and labels
/// - GeoGebra-style interactions: drag to orbit, pinch to zoom, two-finger
///   pan, click to select, drag to move, tap-and-hold to place points with
///   height adjustment, keyboard control, click existing objects as
///   construction inputs.
class MathCanvas3D extends StatefulWidget {
  final On3DReady? onReady;
  final On3DViewportChange? onViewportChange;
  final On3DSceneChanged? onSceneChanged;
  final On3DToolInstruction? onToolInstruction;
  final On3DNumericInput? onNumericInput;
  final ConstructionTool initialTool;

  const MathCanvas3D({
    super.key,
    this.onReady,
    this.onViewportChange,
    this.onSceneChanged,
    this.onToolInstruction,
    this.onNumericInput,
    this.initialTool = ConstructionTool.move,
  });

  @override
  State<MathCanvas3D> createState() => MathCanvas3DState();
}

/// The state class for [MathCanvas3D], exposing methods for parent control.
class MathCanvas3DState extends State<MathCanvas3D>
    with SingleTickerProviderStateMixin {
  final Scene3D _scene = Scene3D();
  late final Ticker _autoRotateTicker;
  bool _autoRotating = false;

  // View settings
  bool _showAxes = true;
  bool _showGrid = true;
  bool _showPlane = true;
  PointCapturing _capturing = PointCapturing.off;

  // Tool state
  ConstructionTool _tool = ConstructionTool.move;
  ConstructionState? _construction;

  // Selection & dragging
  Object3D? _selected;
  Object3D? _prevSelected; // selection at gesture start
  bool _dragModeZ = false; // false: move in xOy plane; true: along Z axis
  bool _draggingObject = false;
  bool _pausedAutoRotate = false;

  // Construction: the object hit by the current gesture (if any).
  (Object3D, Point3D)? _pendingObjectHit;

  // Gesture state
  Offset? _lastFocalPoint;
  double? _initialScaleDistance;
  bool _tapCandidate = false;
  Offset? _tapStart;
  Point3D? _constGroundPos;
  double _constHeight = 0;
  bool _gestureHadMultiPointer = false; // pinch started during this gesture
  bool _gestureDragged = false; // an object was actually moved this gesture
  bool _constCommitted = false;

  // Canvas size
  double _canvasWidth = 1;
  double _canvasHeight = 1;

  bool _isReady = false;

  /// Bumped on every setState so the painter repaints (the Scene3D instance
  /// itself is mutated in place and reference comparison alone won't work).
  int _repaintVersion = 0;

  void _bump() => _repaintVersion++;

  @override
  void initState() {
    super.initState();
    _autoRotateTicker = createTicker((elapsed) {
      if (_autoRotating && mounted) {
        setState(() {
          _scene.setCamera(_scene.camera.orbit(deltaTheta: 0.003, deltaPhi: 0));
        });
      }
    });
    _tool = widget.initialTool;
    if (_tool != ConstructionTool.move) {
      _construction = ConstructionState(tool: _tool);
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
  void dispose() {
    _autoRotateTicker.dispose();
    super.dispose();
  }

  // ==================================================================
  // Public API
  // ==================================================================

  Scene3D get scene => _scene;
  Camera3D get camera => _scene.camera;
  ProjectionType get projectionType => _scene.projectionType;
  bool get showAxes => _showAxes;
  bool get showGrid => _showGrid;
  bool get showPlane => _showPlane;
  PointCapturing get capturing => _capturing;
  bool get autoRotating => _autoRotating;
  List<Object3D> get objects => _scene.objects;
  ConstructionTool get activeTool => _tool;
  ConstructionState? get construction => _construction;
  Object3D? get selected => _selected;

  void setProjectionType(ProjectionType type) {
    setState(() => _scene.setProjectionType(type));
  }

  void toggleAxes() => setState(() => _showAxes = !_showAxes);
  void toggleGrid() => setState(() => _showGrid = !_showGrid);
  void togglePlane() => setState(() => _showPlane = !_showPlane);

  void setPointCapturing(PointCapturing mode) {
    setState(() => _capturing = mode);
  }

  void setAutoRotate(bool on) {
    setState(() => _autoRotating = on);
    if (on) {
      _autoRotateTicker.start();
    } else {
      _autoRotateTicker.stop();
    }
  }

  void resetView() {
    setState(() {
      _scene.setCamera(const Camera3D());
    });
    widget.onViewportChange?.call();
  }

  void setStandardView(StandardView view) {
    setState(() {
      _scene.setCamera(_scene.camera.withStandardView(view));
    });
    widget.onViewportChange?.call();
  }

  void fitView() {
    setState(() {
      _scene.fitToView();
    });
    widget.onViewportChange?.call();
  }

  void setObjects(List<Object3D> objects) {
    setState(() {
      _scene.clear();
      for (final o in objects) {
        _scene.add(o);
      }
      _selected = null;
      _expressionObjects = List.from(objects);
    });
    _notifySceneChanged();
  }

  /// The objects currently owned by expression input (kept separate from
  /// objects created with construction tools).
  List<Object3D> _expressionObjects = [];

  /// Number of expression-owned objects (used to detect first plot).
  int get expressionObjectCount => _expressionObjects.length;

  /// Replace only the expression-created objects, keeping construction
  /// objects intact. Removal matches by name because the stored objects may
  /// have been replaced in place (drag / style edits).
  void setExpressionObjects(List<Object3D> objects) {
    setState(() {
      for (final o in _expressionObjects) {
        _scene.removeWhere((x) => x.name == o.name);
        if (_selected != null && _selected!.name == o.name) _selected = null;
      }
      for (final o in objects) {
        _scene.add(o);
      }
      _expressionObjects = List.from(objects);
    });
    _notifySceneChanged();
  }

  void clearObjects() {
    setState(() {
      _scene.clear();
      _selected = null;
      _expressionObjects = [];
    });
    _notifySceneChanged();
  }

  void addObject(Object3D obj) {
    setState(() => _scene.add(obj));
    _notifySceneChanged();
  }

  void removeObject(Object3D obj) {
    setState(() {
      _scene.remove(obj);
      if (_selected == obj) _selected = null;
    });
    _notifySceneChanged();
  }

  void setObjectVisible(String name, bool visible) {
    final obj = _scene.byName(name);
    if (obj == null) return;
    setState(() {
      final updated = obj.withVisible(visible);
      _scene.replace(obj, updated);
      if (identical(_selected, obj)) _selected = updated;
    });
    _notifySceneChanged();
  }

  void setObjectStyle(String name, ObjectStyle style) {
    final obj = _scene.byName(name);
    if (obj == null) return;
    setState(() {
      final updated = obj.withStyle(style);
      _scene.replace(obj, updated);
      if (identical(_selected, obj)) _selected = updated;
    });
    _notifySceneChanged();
  }

  void setTool(ConstructionTool tool) {
    setState(() {
      _tool = tool;
      if (tool == ConstructionTool.move) {
        _construction = null;
      } else {
        _construction = ConstructionState(tool: tool);
      }
      _constCommitted = false;
      _constGroundPos = null;
    });
    widget.onToolInstruction?.call(_construction?.currentInstruction ?? '');
  }

  void selectObject(Object3D? obj) {
    setState(() {
      _selected = obj;
      _dragModeZ = false;
    });
  }

  void _notifySceneChanged() {
    widget.onSceneChanged?.call();
  }

  // ==================================================================
  // Helpers
  // ==================================================================

  Projection3D get _projection => _scene.projection;

  /// Snaps a world point according to the capturing mode.
  Point3D _capture(Point3D p) {
    switch (_capturing) {
      case PointCapturing.off:
        return p;
      case PointCapturing.automatic:
      case PointCapturing.snapToGrid:
        // Snap to the nearest multiple of 0.5 world units when close enough.
        const snap = 0.5;
        if (_capturing == PointCapturing.automatic) {
          // Only snap when within 20% of a grid point.
          final dx = (p.x / snap).roundToDouble() * snap;
          final dy = (p.y / snap).roundToDouble() * snap;
          final dz = (p.z / snap).roundToDouble() * snap;
          if ((p.x - dx).abs() < 0.1 &&
              (p.y - dy).abs() < 0.1 &&
              (p.z - dz).abs() < 0.1) {
            return Point3D(dx, dy, dz);
          }
          return p;
        }
        return Point3D(
          (p.x / snap).roundToDouble() * snap,
          (p.y / snap).roundToDouble() * snap,
          (p.z / snap).roundToDouble() * snap,
        );
      case PointCapturing.fixedToGrid:
        const snap = 0.5;
        return Point3D(
          (p.x / snap).roundToDouble() * snap,
          (p.y / snap).roundToDouble() * snap,
          (p.z / snap).roundToDouble() * snap,
        );
    }
  }

  /// The ground point under a screen position (z = 0 by default, or the
  /// current height of the construction drag).
  Point3D? _groundAt(Offset pos, {double z0 = 0}) {
    final proj = _projection;
    return proj.screenToGround(pos.dx, pos.dy, z0: z0);
  }

  // ==================================================================
  // Gesture handling
  // ==================================================================

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    _initialScaleDistance = _scene.camera.distance;
    _tapCandidate = true;
    _tapStart = details.focalPoint;
    _constGroundPos = null;
    _constHeight = 0;
    _constCommitted = false;
    _draggingObject = false;
    _pendingObjectHit = null;
    _prevSelected = _selected;
    _gestureHadMultiPointer = false;
    _gestureDragged = false;

    // Pause auto-rotation while interacting (resumed on scale end).
    if (_autoRotating) {
      _pausedAutoRotate = true;
      setAutoRotate(false);
    }

    if (_tool == ConstructionTool.move) {
      // Try to grab an object under the pointer.
      final hit = _scene.pick(details.focalPoint.dx, details.focalPoint.dy);
      if (hit != null) {
        final obj = hit.$1;
        // Keep the previous drag mode when the object was already selected;
        // otherwise start in the xOy-plane mode.
        final keepMode = identical(obj, _prevSelected);
        setState(() {
          _selected = obj;
          if (!keepMode) _dragModeZ = false;
          _draggingObject = true;
        });
      } else {
        setState(() => _selected = null);
      }
    } else if (_construction != null && !_construction!.isComplete) {
      // Construction: clicking an existing object feeds it as an input
      // (GeoGebra behavior); clicking empty space places a new point.
      final hit = _scene.pick(details.focalPoint.dx, details.focalPoint.dy);
      if (hit != null) {
        _pendingObjectHit = hit;
      } else {
        _constGroundPos = _groundAt(details.focalPoint);
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final focalPoint = details.focalPoint;
    final scale = details.scale;
    if (details.pointerCount >= 2) _gestureHadMultiPointer = true;

    // ---- Construction: place point on ground, drag changes height ----
    // Only single-pointer gestures place points; pinch is camera control.
    if (_tool != ConstructionTool.move &&
        _construction != null &&
        !_construction!.isComplete &&
        !_constCommitted &&
        details.pointerCount == 1) {
      // A drag that moves away from a hit object converts the gesture into
      // a free point placement (so users can drag near existing objects).
      if (_pendingObjectHit != null && _tapStart != null) {
        if ((focalPoint - _tapStart!).distance > 8) {
          _pendingObjectHit = null;
          _constGroundPos = _groundAt(focalPoint);
        }
      }
      if (_constGroundPos != null) {
        final dy =
            _lastFocalPoint == null ? 0.0 : focalPoint.dy - _lastFocalPoint!.dy;
        _constHeight = (_constHeight - dy * 0.06).clamp(-50.0, 50.0);
        // Re-anchor ground x,y from pointer so the point can be dragged around.
        _constGroundPos = _groundAt(focalPoint) ?? _constGroundPos;
      }
      _lastFocalPoint = focalPoint;
      return;
    }

    // ---- Move tool: dragging a selected object ----
    if (_tool == ConstructionTool.move &&
        _draggingObject &&
        _selected != null) {
      if (details.pointerCount == 1) {
        // Moving the object means this is a drag, not a tap.
        if (_tapStart != null && (focalPoint - _tapStart!).distance > 4) {
          _tapCandidate = false;
        }
        _moveSelectedObject(focalPoint);
        _gestureDragged = true;
        _lastFocalPoint = focalPoint;
        return;
      }
    }

    // ---- Camera navigation ----
    if (details.pointerCount == 1) {
      final dx =
          _lastFocalPoint == null ? 0.0 : (focalPoint.dx - _lastFocalPoint!.dx);
      final dy =
          _lastFocalPoint == null ? 0.0 : (focalPoint.dy - _lastFocalPoint!.dy);
      if (dx.abs() > 1 || dy.abs() > 1) _tapCandidate = false;

      setState(() {
        _scene.setCamera(
            _scene.camera.orbit(deltaTheta: -dx * 0.01, deltaPhi: -dy * 0.01));
      });
    } else if (details.pointerCount >= 2) {
      final hasScaleChange =
          (scale - 1.0).abs() > 0.02 && _initialScaleDistance != null;
      final hasPanMovement = _lastFocalPoint != null &&
          (focalPoint - _lastFocalPoint!).distance > 2.0;

      if (hasScaleChange) {
        // Cumulative scale from gesture start → new distance = initial × scale.
        final initial = _initialScaleDistance ?? _scene.camera.distance;
        setState(() {
          _scene.setCamera(_scene.camera
              .copyWith(distance: (initial * scale).clamp(0.05, 5000.0)));
        });
      } else if (hasPanMovement) {
        final dx = _lastFocalPoint == null
            ? 0.0
            : (focalPoint.dx - _lastFocalPoint!.dx);
        final dy = _lastFocalPoint == null
            ? 0.0
            : (focalPoint.dy - _lastFocalPoint!.dy);
        setState(() {
          _scene.setCamera(_scene.camera.pan(deltaX: dx, deltaY: dy));
        });
      }
    }

    _lastFocalPoint = focalPoint;
  }

  void _moveSelectedObject(Offset focalPoint) {
    final obj = _selected!;
    final proj = _projection;
    final ray = proj.screenRay(focalPoint.dx, focalPoint.dy);

    if (_dragModeZ) {
      // Move along the vertical line through the object's current x,y.
      final d = ray.direction;
      final anchor = obj.anchorPoint;
      if (d.x.abs() < 1e-9 && d.y.abs() < 1e-9) return; // straight top view
      final tx = d.x.abs() > d.y.abs()
          ? (anchor.x - ray.origin.x) / d.x
          : (anchor.y - ray.origin.y) / d.y;
      final z = ray.origin.z + tx * d.z;
      final delta = Vector3D(0, 0, z - anchor.z);
      setState(() {
        _scene.replace(obj, obj.translated(delta));
        _selected = obj.translated(delta);
      });
    } else {
      // Move in the xOy plane (preserve z): delta relative to the CURRENT
      // anchor so repeated updates do not accumulate drift.
      final anchor = obj.anchorPoint;
      final hit = ray.intersectPlane(Vector3D.unitZ, anchor.z);
      if (hit != null) {
        final moved = obj.translated(hit - anchor);
        setState(() {
          _scene.replace(obj, moved);
          _selected = moved;
        });
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // ---- Construction: commit the picked object or placed point ----
    // A pinch that started as one finger and lost the second mid-gesture
    // must not commit a point at the pinch's final position.
    if (_tool != ConstructionTool.move &&
        _construction != null &&
        !_construction!.isComplete &&
        !_constCommitted &&
        details.pointerCount <= 1 &&
        !_gestureHadMultiPointer) {
      _constCommitted = true;
      if (_pendingObjectHit != null) {
        // Clicked an existing object: feed it as the construction input.
        final (obj, world) = _pendingObjectHit!;
        _handleConstructionInput(ObjectInput(obj, snapPoint: world));
      } else {
        final ground = _constGroundPos ?? _groundAt(_tapStart ?? Offset.zero);
        if (ground != null) {
          // Z-up: the ground position supplies x/y, the drag sets the height z.
          var world = Point3D(ground.x, ground.y, _constHeight);
          world = _capture(world);
          _handleConstructionInput(NewPointInput(world));
        }
      }
      _constGroundPos = null;
      _constHeight = 0;
      _pendingObjectHit = null;
      _resumeAutoRotate();
      return;
    }

    // ---- Move tool: tap selects, second tap toggles drag mode ----
    if (_tool == ConstructionTool.move) {
      final wasTap =
          _tapCandidate && _tapStart != null && details.pointerCount <= 1;
      if (wasTap) {
        final hit = _scene.pick(_tapStart!.dx, _tapStart!.dy);
        setState(() {
          if (hit == null) {
            _selected = null;
          } else if (identical(_prevSelected, hit.$1) && _selected == hit.$1) {
            // Second tap on the object already selected BEFORE this gesture
            // toggles the drag mode (xOy plane ↔ z axis).
            _dragModeZ = !_dragModeZ;
          } else {
            _selected = hit.$1;
            _dragModeZ = false;
          }
        });
      }
      _draggingObject = false;
      // Only a drag that actually replaced an object needs to notify the
      // panel; a plain camera-orbit gesture must not rebuild it.
      if (_gestureDragged) {
        _notifySceneChanged();
      }
    }

    // Resume auto-rotation that was paused for this interaction.
    _resumeAutoRotate();

    _lastFocalPoint = null;
    _tapStart = null;
    _constGroundPos = null;
    _constHeight = 0;
    _pendingObjectHit = null;
    _prevSelected = null;
    widget.onViewportChange?.call();
  }

  void _resumeAutoRotate() {
    if (_pausedAutoRotate) {
      _pausedAutoRotate = false;
      setAutoRotate(true);
    }
  }

  /// Route a click into the active construction workflow.
  void _handleConstructionInput(ConstructionInput input) {
    final state = _construction;
    if (state == null) return;

    final step = state.currentStep;
    // Object-step requires an ObjectInput; if the user clicked empty space
    // on an object-step, treat the clicked position as a new point only for
    // point-kind steps. For strict object steps, ignore free-space clicks.
    if (step != null && step.kind == InputKind.object) {
      if (input is NewPointInput) return; // free click on object step: ignore
    }

    final completed = state.addInput(input);
    if (state.awaitingNumber && !completed) {
      _requestNumberInput();
    }
    if (completed) {
      _applyConstructionResult();
    }
    widget.onToolInstruction?.call(state.currentInstruction);
    setState(() {});
  }

  Future<void> _requestNumberInput() async {
    final state = _construction;
    if (state == null) return;
    final step = state.currentStep;
    if (step == null || step.kind != InputKind.number) return;

    final prompt = step.instruction;
    double? value;
    if (widget.onNumericInput != null) {
      value = await widget.onNumericInput!(prompt, 1);
    }
    if (!mounted) return;
    if (value == null) {
      // User cancelled: reset the construction so the tool stays usable.
      state.reset();
      widget.onToolInstruction?.call(state.currentInstruction);
      setState(() {});
      return;
    }
    final completed = state.addInput(NumberInput(value));
    if (completed) {
      _applyConstructionResult();
    }
    widget.onToolInstruction?.call(state.currentInstruction);
    setState(() {});
  }

  void _applyConstructionResult() {
    final state = _construction;
    final result = state?.result;
    if (result == null) return;

    setState(() {
      for (final o in result.created) {
        _scene.add(_renameIfNeeded(o));
      }
      for (final o in result.removed) {
        _scene.remove(o);
        if (_selected == o) _selected = null;
      }
      for (final o in result.modified) {
        // Match by name; rebuild with the new visibility.
        final existing = _scene.byName(o.name);
        if (existing != null) {
          _scene.replace(existing, o);
          // Keep the selection on the updated instance so keyboard
          // Delete / dragging still operate on the live object.
          if (identical(_selected, existing)) _selected = o;
        }
      }
      // Start a fresh construction for the same tool (GeoGebra behavior:
      // the tool stays active and can create multiple objects).
      _construction = ConstructionState(tool: _tool);
    });
    _notifySceneChanged();
  }

  /// Reassign GeoGebra-style labels so that construction objects never
  /// collide with expression objects. The new label matches the object kind
  /// (points A/B/C…, lines l, curves/segments c, solids/surfaces their
  /// GeoGebra names) instead of always falling back to point labels.
  Object3D _renameIfNeeded(Object3D obj) {
    if (_scene.byName(obj.name) == null) return obj;
    final name = switch (obj.type) {
      Object3DType.point => _scene.nextPointName(),
      Object3DType.measurement => _scene.nextMeasurementName(),
      Object3DType.segment ||
      Object3DType.line ||
      Object3DType.ray ||
      Object3DType.vector =>
        _scene.nextLineName(),
      Object3DType.circle || Object3DType.arc => _scene.nextCurveName(),
      Object3DType.polygon => _scene.nextCurveName(),
      Object3DType.curve => _scene.nextCurveName(),
      Object3DType.polyhedron ||
      Object3DType.sphere ||
      Object3DType.cone ||
      Object3DType.cylinder ||
      Object3DType.plane ||
      Object3DType.surface =>
        _scene.nextSolidName(),
    };
    return obj.withRenamed(name);
  }

  // ==================================================================
  // Pointer signal (scroll wheel) & keyboard
  // ==================================================================

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      if (shift) {
        // Shift + scroll: pan.
        setState(() {
          _scene.setCamera(_scene.camera.pan(
              deltaX: -event.scrollDelta.dx * 2,
              deltaY: -event.scrollDelta.dy * 2));
        });
      } else {
        // Wheel up (negative dy) zooms in, matching GeoGebra/map apps.
        final zoomFactor = 1.0 - event.scrollDelta.dy * 0.002;
        setState(() {
          _scene.setCamera(_scene.camera.zoom(factor: zoomFactor));
        });
      }
      widget.onViewportChange?.call();
    }
  }

  /// Handle keyboard input for object manipulation (GeoGebra-style).
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_selected == null) return KeyEventResult.ignored;

    final step = 0.1 * (HardwareKeyboard.instance.isShiftPressed ? 10 : 1);
    Point3D? target;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        target = _selected!.anchorPoint + Vector3D.unitX * (-step);
      case LogicalKeyboardKey.arrowRight:
        target = _selected!.anchorPoint + Vector3D.unitX * step;
      case LogicalKeyboardKey.arrowUp:
        target = _selected!.anchorPoint + Vector3D.unitY * (-step);
      case LogicalKeyboardKey.arrowDown:
        target = _selected!.anchorPoint + Vector3D.unitY * step;
      case LogicalKeyboardKey.pageUp:
        target = _selected!.anchorPoint + Vector3D.unitZ * step;
      case LogicalKeyboardKey.pageDown:
        target = _selected!.anchorPoint + Vector3D.unitZ * (-step);
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.backspace:
        removeObject(_selected!);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
    final obj = _selected!;
    final delta = target - obj.anchorPoint;
    setState(() {
      _scene.replace(obj, obj.translated(delta));
      _selected = obj.translated(delta);
    });
    _notifySceneChanged();
    return KeyEventResult.handled;
  }

  // ==================================================================
  // Build
  // ==================================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    _bump(); // ensure every rebuild triggers a repaint

    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasWidth = constraints.maxWidth;
        _canvasHeight = constraints.maxHeight;
        _scene.setViewport(_canvasWidth, _canvasHeight);

        return Focus(
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: Listener(
              onPointerSignal: _onPointerSignal,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: _ScenePainter(
                    scene: _scene,
                    showAxes: _showAxes,
                    showGrid: _showGrid,
                    showPlane: _showPlane,
                    selected: _selected,
                    construction: _construction,
                    repaintVersion: _repaintVersion,
                    backgroundColor: cs.surface,
                    axisColor: cs.onSurface.withValues(alpha: 0.85),
                    gridColor: cs.outlineVariant.withValues(alpha: 0.35),
                    planeColor: const Color(0xFF64B5F6),
                    labelColor: cs.onSurfaceVariant,
                    highlightColor: cs.primary,
                  ),
                  size: Size(_canvasWidth, _canvasHeight),
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
// Rendering
// ======================================================================

/// Render primitives with depth, collected then sorted back-to-front.
sealed class _Prim {
  final double depth;
  const _Prim({required this.depth});
}

class _FacePrim extends _Prim {
  final Path path;
  final Color color;
  final Vector3D normal; // world-space, for lighting
  final Paint fillPaint;
  final Paint strokePaint;

  _FacePrim({
    required super.depth,
    required this.path,
    required this.color,
    required this.normal,
    Paint? fillPaint,
    Paint? strokePaint,
  })  : fillPaint = fillPaint ?? Paint()
          ..color = color,
        strokePaint = strokePaint ?? Paint()
          ..style = PaintingStyle.stroke
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 0.5;
}

class _LinePrim extends _Prim {
  final List<Offset> points;
  final Color color;
  final double width;
  final LineStyle style;
  final Paint paint;

  _LinePrim({
    required super.depth,
    required this.points,
    required this.color,
    this.width = 2,
    this.style = LineStyle.solid,
  }) : paint = Paint()
          ..color = color
          ..strokeWidth = width
          ..style = PaintingStyle.stroke;
}

class _PointPrim extends _Prim {
  final Offset pos;
  final Color color;
  final double size;
  final PointStyle style;
  final Paint paint;

  _PointPrim({
    required super.depth,
    required this.pos,
    required this.color,
    this.size = 5,
    this.style = PointStyle.dot,
  }) : paint = Paint()..color = color;
}

class _LabelPrim extends _Prim {
  final Offset pos;
  final String text;
  final Color color;
  final bool bold;
  final Offset anchor; // screen-space offset of the text from the point

  _LabelPrim({
    required super.depth,
    required this.pos,
    required this.text,
    required this.color,
    this.bold = false,
    this.anchor = const Offset(7, -7),
  });
}

/// The painter for the 3D scene.
class _ScenePainter extends CustomPainter {
  final Scene3D scene;
  final bool showAxes;
  final bool showGrid;
  final bool showPlane;
  final Object3D? selected;
  final ConstructionState? construction;
  final Color backgroundColor;
  final Color axisColor;
  final Color gridColor;
  final Color planeColor;
  final Color labelColor;
  final Color highlightColor;
  final int repaintVersion;

  const _ScenePainter({
    required this.scene,
    required this.showAxes,
    required this.showGrid,
    required this.showPlane,
    required this.selected,
    required this.construction,
    required this.repaintVersion,
    required this.backgroundColor,
    required this.axisColor,
    required this.gridColor,
    required this.planeColor,
    required this.labelColor,
    required this.highlightColor,
  });

  Projection3D get proj => scene.projection;

  static const _lightDir = Vector3D(-0.45, -0.5, 0.74);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final prims = <_Prim>[];

    // Ground plane + grid.
    if (showPlane) {
      _collectPlane(prims, size);
    }
    if (showGrid) {
      _collectGrid(prims);
    }
    if (showAxes) {
      _collectAxes(prims);
    }

    // Objects.
    for (final obj in scene.objects) {
      if (!obj.visible) continue;
      _collectObject(prims, obj);
    }

    // Construction preview.
    if (construction != null && !construction!.isComplete) {
      _collectConstructionPreview(prims, construction!);
    }

    // Sort back-to-front (far = larger depth drawn first).
    prims.sort((a, b) => b.depth.compareTo(a.depth));
    for (final p in prims) {
      _drawPrim(canvas, p);
    }
  }

  // ==================================================================
  // Ground plane & grid
  // ==================================================================

  /// Visible world extents around the camera target.
  (double, double, double, double) _visibleRange() {
    final cam = scene.camera;
    final height = proj.height;
    final worldUnits =
        (cam.distance * (height / 800)).clamp(0.5, 200.0).toDouble();
    final halfW = worldUnits * (proj.width / proj.height);
    return (
      cam.target.x - halfW,
      cam.target.x + halfW,
      cam.target.y - worldUnits / 2,
      cam.target.y + worldUnits / 2,
    );
  }

  double _niceStep(double worldPerPixel) {
    // Target ~70 px between lines; snap to 1/2/5 × 10^k.
    final target = 70 * worldPerPixel;
    final pow10 = dart_math
        .pow(10, (dart_math.log(target) / dart_math.ln10).floor())
        .toDouble();
    for (final m in [1.0, 2.0, 5.0, 10.0]) {
      if (m * pow10 >= target) return m * pow10;
    }
    return 10 * pow10;
  }

  void _collectGrid(List<_Prim> prims) {
    final (xMin, xMax, yMin, yMax) = _visibleRange();
    final worldPerPixel = scene.camera.distance / 800;
    var step = _niceStep(worldPerPixel);
    // Never let the step exceed a quarter of the visible range, otherwise
    // no grid lines appear when zoomed far out.
    final rangeX = (xMax - xMin).abs();
    if (rangeX > 1e-9 && step > rangeX / 4) step = rangeX / 4;
    // Keep line counts sane (per direction).
    final maxLines = 60;
    final iMin = (xMin / step).ceil();
    final iMax = (xMax / step).floor();
    final jMin = (yMin / step).ceil();
    final jMax = (yMax / step).floor();

    var count = 0;
    for (int i = iMin; i <= iMax && count < maxLines; i++) {
      if (i == 0) continue;
      final a = proj.project(Point3D(i * step, yMin, 0));
      final b = proj.project(Point3D(i * step, yMax, 0));
      if (a == null || b == null || a.x.isNaN || b.x.isNaN) continue;
      prims.add(_LinePrim(
        depth: (a.z + b.z) / 2,
        points: [Offset(a.x, a.y), Offset(b.x, b.y)],
        color: gridColor,
        width: 0.5,
      ));
      count++;
    }
    count = 0;
    for (int j = jMin; j <= jMax && count < maxLines; j++) {
      if (j == 0) continue;
      final a = proj.project(Point3D(xMin, j * step, 0));
      final b = proj.project(Point3D(xMax, j * step, 0));
      if (a == null || b == null || a.x.isNaN || b.x.isNaN) continue;
      prims.add(_LinePrim(
        depth: (a.z + b.z) / 2,
        points: [Offset(a.x, a.y), Offset(b.x, b.y)],
        color: gridColor,
        width: 0.5,
      ));
      count++;
    }

    // Tick labels along the axes.
    for (int i = iMin; i <= iMax; i++) {
      if (i == 0) continue;
      final p = proj.project(Point3D(i * step, 0, 0));
      if (p == null || p.x.isNaN) continue;
      final label = _fmtTick(i * step);
      prims.add(_LabelPrim(
        depth: p.z,
        pos: Offset(p.x, p.y + 12),
        text: label,
        color: gridColor,
        anchor: Offset.zero,
      ));
    }
    for (int j = jMin; j <= jMax; j++) {
      if (j == 0) continue;
      final p = proj.project(Point3D(0, j * step, 0));
      if (p == null || p.x.isNaN) continue;
      final label = _fmtTick(j * step);
      prims.add(_LabelPrim(
        depth: p.z,
        pos: Offset(p.x + 4, p.y),
        text: label,
        color: gridColor,
        anchor: Offset.zero,
      ));
    }
  }

  static String _fmtTick(double v) {
    if (v.abs() < 1e-9) return '0';
    if (v.abs() >= 100) return v.round().toString();
    if ((v * 100).roundToDouble() == v * 100) {
      return v
          .toStringAsFixed(v.abs() >= 10 ? 0 : 2)
          .replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// The translucent xOy plane with a boundary rectangle.
  void _collectPlane(List<_Prim> prims, Size size) {
    final (xMin, xMax, yMin, yMax) = _visibleRange();
    final corners = [
      Point3D(xMin, yMin, 0),
      Point3D(xMax, yMin, 0),
      Point3D(xMax, yMax, 0),
      Point3D(xMin, yMax, 0),
    ];
    final projected = corners.map((p) => proj.project(p)).toList();
    if (projected.any((p) => p == null || p.x.isNaN)) return;

    final path = Path()
      ..moveTo(projected[0]!.x, projected[0]!.y)
      ..lineTo(projected[1]!.x, projected[1]!.y)
      ..lineTo(projected[2]!.x, projected[2]!.y)
      ..lineTo(projected[3]!.x, projected[3]!.y)
      ..close();

    // The plane lies on z = 0: use the average corner depth so it sorts
    // consistently with the grid lines and ground objects.
    final depth = projected.map((p) => p?.z ?? 0).reduce((a, b) => a + b) /
        projected.length;
    prims.add(_FacePrim(
      depth: depth,
      path: path,
      color: planeColor.withValues(alpha: 0.08),
      normal: Vector3D.unitZ,
    ));
    // Boundary (drawn per segment so partially clipped corners don't
    // remove the whole border).
    final pts = <Offset>[];
    for (int i = 0; i < projected.length; i++) {
      final a = projected[i];
      final b = projected[(i + 1) % projected.length];
      if (a == null || b == null || a.x.isNaN || b.x.isNaN) continue;
      pts.add(Offset(a.x, a.y));
      pts.add(Offset(b.x, b.y));
    }
    if (pts.isNotEmpty) {
      prims.add(_LinePrim(
        depth: depth,
        points: pts,
        color: planeColor.withValues(alpha: 0.55),
        width: 1.2,
      ));
    }
  }

  void _collectAxes(List<_Prim> prims) {
    final (xMin, xMax, yMin, yMax) = _visibleRange();
    // Axis extent = visible range (both directions).
    final zNeg = -(yMin.abs()).clamp(2, 20).toDouble();
    final zPos = yMax.abs().clamp(2, 20).toDouble();
    final axes = <(String, Point3D, Point3D, Offset)>[
      ('X', Point3D(xMin, 0, 0), Point3D(xMax, 0, 0), const Offset(0, 14)),
      ('Y', Point3D(0, yMin, 0), Point3D(0, yMax, 0), const Offset(14, 0)),
      ('Z', Point3D(0, 0, zNeg), Point3D(0, 0, zPos), const Offset(8, -8)),
    ];

    final originScreen = proj.project(Point3D.origin);
    for (final (label, from, to, labelOff) in axes) {
      final a = proj.project(from);
      final b = proj.project(to);
      if (a == null || b == null || a.x.isNaN || b.x.isNaN) continue;
      final depth = (a.z + b.z) / 2;
      prims.add(_LinePrim(
        depth: depth,
        points: [Offset(a.x, a.y), Offset(b.x, b.y)],
        color: axisColor,
        width: 1.6,
      ));
      // Arrow head.
      final dir = Offset(b.x - a.x, b.y - a.y);
      final len = dir.distance;
      if (len > 4) {
        final unit = dir / len;
        final perp = Offset(-unit.dy, unit.dx);
        final tip = Offset(b.x, b.y);
        final base = tip - unit * 7;
        final p1 = base + perp * 3;
        final p2 = base - perp * 3;
        final head = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close();
        prims.add(_FacePrim(
          depth: depth,
          path: head,
          color: axisColor,
          normal: Vector3D.unitZ,
        ));
      }
      // Label (b is guaranteed non-null here since the NaN check passed).
      prims.add(_LabelPrim(
        depth: depth,
        pos: Offset(b.x, b.y) + labelOff,
        text: label,
        color: axisColor,
        bold: true,
        anchor: Offset.zero,
      ));
    }

    // Origin marker.
    if (originScreen != null && !originScreen.x.isNaN) {
      prims.add(_PointPrim(
        depth: originScreen.z,
        pos: Offset(originScreen.x, originScreen.y),
        color: axisColor,
        size: 2.5,
      ));
    }
  }

  // ==================================================================
  // Objects
  // ==================================================================

  void _collectObject(List<_Prim> prims, Object3D obj) {
    final style = obj.style;
    final isSelected = identical(obj, selected);
    final baseColor = Color(style.color).withValues(alpha: style.opacity);
    final strokeColor = isSelected
        ? highlightColor
        : Color(style.color).withValues(alpha: style.opacity);

    switch (obj.type) {
      case Object3DType.point:
        final s = proj.project(obj.pointValue);
        if (s == null || s.x.isNaN) return;
        final c = isSelected ? highlightColor : baseColor;
        final size = style.pointSize * (isSelected ? 1.4 : 1.0);
        prims.add(_PointPrim(
          depth: s.z,
          pos: Offset(s.x, s.y),
          color: c,
          size: size,
          style: style.pointStyle,
        ));
        if (isSelected) {
          prims.add(_PointPrim(
            depth: s.z - 0.01,
            pos: Offset(s.x, s.y),
            color: highlightColor.withValues(alpha: 0.35),
            size: size + 6,
            style: PointStyle.dot,
          ));
        }
        _addLabel(prims, obj, Offset(s.x, s.y), s.z);

      case Object3DType.segment:
        _collectSegment(prims, obj, strokeColor, style);

      case Object3DType.line:
        // Draw a long but clipped line: fixed length, extending both ways.
        final dir = obj.vectorValue.normalized();
        if (dir.isZero) return;
        _collectSegment(
          prims,
          Object3D.segment(
              obj.pointAValue + dir * (-20), obj.pointAValue + dir * 20,
              name: obj.name, style: style),
          strokeColor,
          style,
        );

      case Object3DType.ray:
        final dir = obj.vectorValue.normalized();
        if (dir.isZero) return;
        _collectSegment(
          prims,
          Object3D.segment(obj.pointAValue, obj.pointAValue + dir * 40,
              name: obj.name, style: style),
          strokeColor,
          style,
        );

      case Object3DType.vector:
        final from = proj.project(obj.pointValue);
        final to = proj.project(obj.pointValue + obj.vectorValue);
        if (from == null || to == null || from.x.isNaN || to.x.isNaN) return;
        final pts = [Offset(from.x, from.y), Offset(to.x, to.y)];
        prims.add(_LinePrim(
          depth: (from.z + to.z) / 2,
          points: pts,
          color: strokeColor,
          width: style.lineWidth,
          style: style.lineStyle,
        ));
        _drawArrowHead(prims, pts, strokeColor, (from.z + to.z) / 2);
        _addLabel(prims, obj, Offset(to.x, to.y), (from.z + to.z) / 2);

      case Object3DType.circle:
      case Object3DType.arc:
        _collectCircle(prims, obj, strokeColor, style);

      case Object3DType.polygon:
        _collectPolygon(prims, obj, baseColor, strokeColor, style);

      case Object3DType.polyhedron:
        _collectMesh(prims, obj.mesh, baseColor, strokeColor, style, isSelected,
            owner: obj);

      case Object3DType.sphere:
        _collectMesh(
            prims,
            MeshBuilder.sphere(obj.sphereRadius)
                .transformed((p) => p + obj.sphereCenter.toVector()),
            baseColor,
            strokeColor,
            style,
            isSelected,
            owner: obj);

      case Object3DType.cone:
        _collectMesh(
            prims,
            Object3D.alignSolidMesh(
                    MeshBuilder.cone(obj.solidRadius, obj.solidHeight),
                    obj.solidAxisValue)
                .transformed((p) => p + obj.solidCenter.toVector()),
            baseColor,
            strokeColor,
            style,
            isSelected,
            owner: obj);

      case Object3DType.cylinder:
        _collectMesh(
            prims,
            Object3D.alignSolidMesh(
                    MeshBuilder.cylinder(obj.solidRadius, obj.solidHeight),
                    obj.solidAxisValue)
                .transformed((p) => p + obj.solidCenter.toVector()),
            baseColor,
            strokeColor,
            style,
            isSelected,
            owner: obj);

      case Object3DType.plane:
        _collectPlaneObject(prims, obj, baseColor, strokeColor);

      case Object3DType.surface:
        _collectMesh(prims, obj.mesh, baseColor, strokeColor, style, isSelected,
            owner: obj);

      case Object3DType.curve:
        _collectCurve(prims, obj, strokeColor, style);

      case Object3DType.measurement:
        final anchor = proj.project(obj.measureAnchor ?? Point3D.origin);
        if (anchor == null || anchor.x.isNaN) return;
        prims.add(_LabelPrim(
          depth: anchor.z,
          pos: Offset(anchor.x, anchor.y),
          text: obj.measureText ?? '',
          color: Color(style.color),
          bold: true,
          anchor: const Offset(8, -8),
        ));
    }
  }

  void _collectSegment(
      List<_Prim> prims, Object3D seg, Color color, ObjectStyle style) {
    final a = proj.project(seg.pointAValue);
    final b = proj.project(seg.pointBValue);
    if (a == null || b == null || a.x.isNaN || b.x.isNaN) return;
    final pts = [Offset(a.x, a.y), Offset(b.x, b.y)];
    prims.add(_LinePrim(
      depth: (a.z + b.z) / 2,
      points: pts,
      color: color,
      width: style.lineWidth,
      style: style.lineStyle,
    ));
    _addLabel(
        prims, seg, Offset((a.x + b.x) / 2, (a.y + b.y) / 2), (a.z + b.z) / 2);
  }

  void _drawArrowHead(
      List<_Prim> prims, List<Offset> pts, Color color, double depth) {
    final from = pts[0];
    final to = pts[1];
    final dir = to - from;
    final len = dir.distance;
    if (len < 6) return;
    final unit = dir / len;
    final perp = Offset(-unit.dy, unit.dx);
    final tip = to;
    final base = to - unit * 9;
    final p1 = base + perp * 4;
    final p2 = base - perp * 4;
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    prims.add(_FacePrim(
      depth: depth,
      path: head,
      color: color,
      normal: Vector3D.unitZ,
    ));
  }

  void _collectCircle(
      List<_Prim> prims, Object3D obj, Color color, ObjectStyle style) {
    final c = obj.circleCenter ?? Point3D.origin;
    final n = (obj.circleNormal ?? Vector3D.unitZ).normalized();
    final r = obj.circleRadius ?? 1;
    final pts = obj.samplePoints();
    if (pts.length < 2) return;
    final projected = <Offset>[];
    var totalZ = 0.0;
    var count = 0;
    for (final p in pts) {
      final s = proj.project(p);
      if (s == null || s.x.isNaN) continue;
      projected.add(Offset(s.x, s.y));
      totalZ += s.z;
      count++;
    }
    if (projected.length < 2) return;
    prims.add(_LinePrim(
      depth: totalZ / count,
      points: projected,
      color: color,
      width: style.lineWidth,
      style: style.lineStyle,
    ));
    // Center marker.
    final cs = proj.project(c);
    if (cs != null && !cs.x.isNaN) {
      prims.add(_PointPrim(
        depth: cs.z,
        pos: Offset(cs.x, cs.y),
        color: color.withValues(alpha: 0.6),
        size: 3,
      ));
    }
    // Label on the circle rim: a basis point (u) is always on the circle,
    // unlike n × ẑ which vanishes for horizontal circles.
    final (uBasis, _) = Object3D.circleBasis(n);
    final top = proj.project(c + uBasis * r);
    if (top != null && !top.x.isNaN) {
      _addLabel(prims, obj, Offset(top.x, top.y), top.z);
    }
  }

  void _collectPolygon(List<_Prim> prims, Object3D obj, Color baseColor,
      Color strokeColor, ObjectStyle style) {
    final v = obj.polygonVertices;
    if (v.length < 3) return;
    final projected = <Offset>[];
    var totalZ = 0.0;
    for (final p in v) {
      final s = proj.project(p);
      if (s == null || s.x.isNaN) return;
      projected.add(Offset(s.x, s.y));
      totalZ += s.z;
    }
    final avgZ = totalZ / v.length;

    final path = Path()..addPolygon(projected, true);
    final normal = (v[1] - v[0]).cross(v[2] - v[0]).normalized();
    final faceColor = _shaded(baseColor, normal);
    prims.add(_FacePrim(
      depth: avgZ,
      path: path,
      color: faceColor,
      normal: normal,
    ));
    // Border.
    prims.add(_LinePrim(
      depth: avgZ - 0.001,
      points: [...projected, projected.first],
      color: strokeColor,
      width: style.lineWidth,
      style: style.lineStyle,
    ));
    // Label at the polygon anchor.
    final anchor = proj.project(obj.anchorPoint);
    if (anchor != null && !anchor.x.isNaN) {
      _addLabel(prims, obj, Offset(anchor.x, anchor.y), anchor.z);
    }
  }

  void _collectPlaneObject(
      List<_Prim> prims, Object3D obj, Color baseColor, Color strokeColor) {
    // Render as a grid of lines on the plane (GeoGebra-style). The grid is
    // centered on the camera target so it follows the view.
    final n = obj.planeNormal.normalized();
    final d = obj.planeDValue;
    final (xMin, xMax, yMin, yMax) = _visibleRange();
    final range = (xMax - xMin).abs().clamp(4, 30).toDouble();
    final p0 = scene.camera.target.projectedOnPlane(n, d);

    // Build two tangent directions.
    final ref = n.cross(Vector3D.unitZ);
    final u =
        ref.isZero ? n.cross(Vector3D.unitX).normalized() : ref.normalized();
    final v = n.cross(u).normalized();

    final step = _niceStep(scene.camera.distance / 800);
    final half = range;
    final maxLines = 60;
    final lines = <(double, List<Offset>)>[];
    var count = 0;
    for (double t = -half; t <= half + 1e-9 && count < maxLines; t += step) {
      final a = proj.project(p0 + u * t + v * (-half));
      final b = proj.project(p0 + u * t + v * half);
      if (a == null || b == null || a.x.isNaN || b.x.isNaN) continue;
      lines.add(((a.z + b.z) / 2, [Offset(a.x, a.y), Offset(b.x, b.y)]));
      count++;
    }
    count = 0;
    for (double t = -half; t <= half + 1e-9 && count < maxLines; t += step) {
      final a = proj.project(p0 + v * t + u * (-half));
      final b = proj.project(p0 + v * t + u * half);
      if (a == null || b == null || a.x.isNaN || b.x.isNaN) continue;
      lines.add(((a.z + b.z) / 2, [Offset(a.x, a.y), Offset(b.x, b.y)]));
      count++;
    }
    for (final (depth, pts) in lines) {
      prims.add(_LinePrim(
        depth: depth,
        points: pts,
        color: baseColor.withValues(alpha: 0.9),
        width: 1.2,
      ));
    }
    // Plane label at the projected plane center.
    final cs = proj.project(p0);
    if (cs != null && !cs.x.isNaN) {
      _addLabel(prims, obj, Offset(cs.x, cs.y), cs.z,
          anchor: const Offset(0, -14));
    }
  }

  void _collectMesh(List<_Prim> prims, MeshData? mesh, Color baseColor,
      Color strokeColor, ObjectStyle style, bool isSelected,
      {Object3D? owner}) {
    if (mesh == null || mesh.isEmpty) return;
    final normals =
        mesh.normals.length == mesh.vertices.length ? mesh.normals : null;
    final opaque = style.opacity >= 0.99;
    final viewDir = (scene.camera.target - scene.camera.position).normalized();

    // Faces.
    for (int i = 0; i < mesh.indices.length; i += 3) {
      final i0 = mesh.indices[i];
      final i1 = mesh.indices[i + 1];
      final i2 = mesh.indices[i + 2];
      // Skip triangles with non-finite vertices (e.g. formula surfaces
      // hitting a singularity like z=1/x) BEFORE projecting: they produce
      // NaN normals that crash shading below.
      final v0 = mesh.vertices[i0];
      final v1 = mesh.vertices[i1];
      final v2 = mesh.vertices[i2];
      if (!v0.isFinite || !v1.isFinite || !v2.isFinite) continue;
      final p0 = proj.project(v0);
      final p1 = proj.project(v1);
      final p2 = proj.project(v2);
      if (p0 == null ||
          p1 == null ||
          p2 == null ||
          p0.x.isNaN ||
          p1.x.isNaN ||
          p2.x.isNaN) {
        continue;
      }
      final path = Path()
        ..moveTo(p0.x, p0.y)
        ..lineTo(p1.x, p1.y)
        ..lineTo(p2.x, p2.y)
        ..close();
      final normal = normals != null
          ? (normals[i0] + normals[i1] + normals[i2]).normalized()
          : (mesh.vertices[i1] - mesh.vertices[i0])
              .cross(mesh.vertices[i2] - mesh.vertices[i0])
              .normalized();
      final avgZ = (p0.z + p1.z + p2.z) / 3;
      // Back-face culling for opaque closed solids.
      final facing = normal.dot(viewDir) < 0;
      if (opaque && !facing) continue;
      final faceColor = _shaded(baseColor, normal);
      prims.add(_FacePrim(
        depth: avgZ,
        path: path,
        color: faceColor,
        normal: normal,
      ));
    }

    // Label at the object anchor.
    if (owner != null) {
      final s = proj.project(owner.anchorPoint);
      if (s != null && !s.x.isNaN) {
        _addLabel(prims, owner, Offset(s.x, s.y), s.z);
      }
    }
  }

  void _collectCurve(
      List<_Prim> prims, Object3D obj, Color color, ObjectStyle style) {
    final pts = obj.curveSamplePoints;
    if (pts.length < 2) return;
    final projected = <Offset>[];
    var totalZ = 0.0;
    for (final p in pts) {
      final s = proj.project(p);
      if (s == null || s.x.isNaN) continue;
      projected.add(Offset(s.x, s.y));
      totalZ += s.z;
    }
    if (projected.length < 2) return;
    prims.add(_LinePrim(
      depth: totalZ / projected.length,
      points: projected,
      color: color,
      width: style.lineWidth,
      style: style.lineStyle,
    ));
    if (projected.isNotEmpty) {
      _addLabel(prims, obj, projected.first, totalZ / projected.length);
    }
  }

  // ==================================================================
  // Construction preview
  // ==================================================================

  void _collectConstructionPreview(List<_Prim> prims, ConstructionState state) {
    const previewColor = Color(0xFF808080);
    final pts = state.previewPoints;
    for (final p in pts) {
      final s = proj.project(p);
      if (s == null || s.x.isNaN) continue;
      prims.add(_PointPrim(
        depth: s.z,
        pos: Offset(s.x, s.y),
        color: previewColor.withValues(alpha: 0.8),
        size: 5,
      ));
    }
    for (final (a, b) in state.previewSegments) {
      final pa = proj.project(a);
      final pb = proj.project(b);
      if (pa == null || pb == null || pa.x.isNaN || pb.x.isNaN) continue;
      prims.add(_LinePrim(
        depth: (pa.z + pb.z) / 2,
        points: [Offset(pa.x, pa.y), Offset(pb.x, pb.y)],
        color: previewColor.withValues(alpha: 0.7),
        width: 1.5,
        style: LineStyle.shortDash,
      ));
    }
  }

  // ==================================================================
  // Labels
  // ==================================================================

  void _addLabel(List<_Prim> prims, Object3D obj, Offset pos, double depth,
      {Offset anchor = const Offset(7, -7)}) {
    final mode = obj.style.labelMode;
    if (mode == LabelMode.hidden) return;
    final text = switch (mode) {
      LabelMode.hidden => '',
      LabelMode.name => obj.name,
      LabelMode.value => _valueOf(obj),
      LabelMode.nameValue => '${obj.name} = ${_valueOf(obj)}',
    };
    if (text.isEmpty) return;
    prims.add(_LabelPrim(
      depth: depth - 0.001,
      pos: pos,
      text: text,
      color: labelColor,
      anchor: anchor,
    ));
  }

  static String _valueOf(Object3D obj) {
    switch (obj.type) {
      case Object3DType.point:
        final p = obj.pointValue;
        return '(${_fmtNum(p.x)}, ${_fmtNum(p.y)}, ${_fmtNum(p.z)})';
      case Object3DType.segment:
        return _fmtNum(obj.pointAValue.distanceTo(obj.pointBValue));
      case Object3DType.circle:
      case Object3DType.arc:
        return 'r=${_fmtNum(obj.circleRadius ?? 1)}';
      case Object3DType.sphere:
        return 'r=${_fmtNum(obj.sphereRadius)}';
      case Object3DType.plane:
        return '${_fmtNum(obj.planeNormalA)}x+${_fmtNum(obj.planeNormalB)}y+${_fmtNum(obj.planeNormalC)}z=${_fmtNum(obj.planeDValue)}';
      default:
        return '';
    }
  }

  static String _fmtNum(double v) {
    if (v.abs() < 1e-9) return '0';
    return v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  // ==================================================================
  // Drawing
  // ==================================================================

  void _drawPrim(Canvas canvas, _Prim prim) {
    switch (prim) {
      case _FacePrim p:
        canvas.drawPath(p.path, p.fillPaint);
        canvas.drawPath(p.path, p.strokePaint);
      case _LinePrim p:
        if (p.style == LineStyle.solid) {
          if (p.points.length == 2) {
            canvas.drawLine(p.points[0], p.points[1], p.paint);
          } else {
            final path = Path()..moveTo(p.points.first.dx, p.points.first.dy);
            for (final pt in p.points.skip(1)) {
              path.lineTo(pt.dx, pt.dy);
            }
            canvas.drawPath(path, p.paint);
          }
        } else {
          _drawDashedLine(canvas, p);
        }
      case _PointPrim p:
        _drawPoint(canvas, p);
      case _LabelPrim p:
        final tp = TextPainter(
          text: TextSpan(
            text: p.text,
            style: TextStyle(
              color: p.color,
              fontSize: 11,
              fontWeight: p.bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p.pos + p.anchor);
    }
  }

  void _drawPoint(Canvas canvas, _PointPrim p) {
    final pos = p.pos;
    switch (p.style) {
      case PointStyle.dot:
        canvas.drawCircle(pos, p.size / 2, p.paint);
      case PointStyle.cross:
        final r = p.size / 2;
        canvas.drawLine(Offset(pos.dx - r, pos.dy - r),
            Offset(pos.dx + r, pos.dy + r), p.paint..strokeWidth = 1.5);
        canvas.drawLine(Offset(pos.dx - r, pos.dy + r),
            Offset(pos.dx + r, pos.dy - r), p.paint);
      case PointStyle.square:
        canvas.drawRect(
            Rect.fromCenter(center: pos, width: p.size, height: p.size),
            p.paint);
      case PointStyle.diamond:
        final r = p.size / 2;
        final path = Path()
          ..moveTo(pos.dx, pos.dy - r)
          ..lineTo(pos.dx + r, pos.dy)
          ..lineTo(pos.dx, pos.dy + r)
          ..lineTo(pos.dx - r, pos.dy)
          ..close();
        canvas.drawPath(path, p.paint);
    }
  }

  void _drawDashedLine(Canvas canvas, _LinePrim p) {
    const dashLen = 8.0;
    const gapLen = 5.0;
    final paint = p.paint;
    paint.strokeWidth = p.width;

    for (int seg = 0; seg < p.points.length - 1; seg++) {
      final a = p.points[seg];
      final b = p.points[seg + 1];
      final dir = b - a;
      final len = dir.distance;
      if (len < 1e-6) continue;
      final unit = dir / len;
      double t = 0;
      while (t < len) {
        final t2 = dart_math.min(t + dashLen, len);
        canvas.drawLine(a + unit * t, a + unit * t2, paint);
        t = t2 + gapLen;
      }
    }
  }

  Color _shaded(Color color, Vector3D normal) {
    final n = normal.normalized();
    if (!n.isFinite) return color; // NaN/Inf normal: skip shading.
    final diff = dart_math.max(0.0, n.dot(_lightDir));
    final shade = 0.45 + 0.55 * diff;
    int ch(double v) => (v * shade).round().clamp(0, 255);
    return Color.fromARGB(
      (color.a * 255).round(),
      ch(color.r),
      ch(color.g),
      ch(color.b),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) {
    return oldDelegate.repaintVersion != repaintVersion ||
        oldDelegate.showAxes != showAxes ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showPlane != showPlane ||
        oldDelegate.selected != selected ||
        oldDelegate.construction != construction ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.highlightColor != highlightColor;
  }
}
