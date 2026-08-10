import 'package:function_tree/function_tree.dart';

import 'math_3d_object.dart';

/// The type of a 3D expression.
enum Expression3DType {
  /// Surface z = f(x, y) — explicit function of x and y.
  surface,

  /// Implicit equation F(x, y, z) = 0 — plane, sphere, quadrics, any F.
  implicit,

  /// Parametric curve (x(t), y(t), z(t)).
  parametricCurve,

  /// Parametric surface (x(u,v), y(u,v), z(u,v)).
  parametricSurface,
}

/// Represents a 3D math expression — a surface, implicit equation,
/// parametric curve, or parametric surface.
///
/// Uses [function_tree] for expression parsing and evaluation.
class Expression3D {
  final String rawExpression;
  final String normalizedExpression;
  final Expression3DType type;
  final Set<String> parameters;

  // Surface: z = f(x, y)
  final double Function(double x, double y)? _surfaceEvaluator;

  // Implicit: F(x, y, z) = 0
  final double Function(double x, double y, double z)? _implicitEvaluator;

  // Parametric curve: (x(t), y(t), z(t))
  final double Function(double t)? _curveX;
  final double Function(double t)? _curveY;
  final double Function(double t)? _curveZ;
  final double tMin;
  final double tMax;

  // Parametric surface: (x(u,v), y(u,v), z(u,v))
  final double Function(double u, double v)? _surfX;
  final double Function(double u, double v)? _surfY;
  final double Function(double u, double v)? _surfZ;
  final double uMin;
  final double uMax;
  final double vMin;
  final double vMax;

  final String? _parseError;

  bool get isValid => rawExpression.isNotEmpty && _parseError == null;
  String? get parseError => _parseError;

  const Expression3D._({
    required this.rawExpression,
    required this.normalizedExpression,
    required this.type,
    required this.parameters,
    double Function(double, double)? surfaceEvaluator,
    double Function(double, double, double)? implicitEvaluator,
    double Function(double t)? curveX,
    double Function(double t)? curveY,
    double Function(double t)? curveZ,
    double Function(double u, double v)? surfX,
    double Function(double u, double v)? surfY,
    double Function(double u, double v)? surfZ,
    this.tMin = 0,
    this.tMax = 1,
    this.uMin = 0,
    this.uMax = 1,
    this.vMin = 0,
    this.vMax = 1,
    String? parseError,
  })  : _surfaceEvaluator = surfaceEvaluator,
        _implicitEvaluator = implicitEvaluator,
        _curveX = curveX,
        _curveY = curveY,
        _curveZ = curveZ,
        _surfX = surfX,
        _surfY = surfY,
        _surfZ = surfZ,
        _parseError = parseError;

  // ==================================================================
  // Surface z = f(x, y)
  // ==================================================================

  /// Create a surface expression from z = f(x, y) input.
  factory Expression3D.surface(
    String input, {
    Map<String, double> parameterValues = const {},
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return Expression3D._(
        rawExpression: '',
        normalizedExpression: '',
        type: Expression3DType.surface,
        parameters: {},
        parseError: '表达式为空',
      );
    }

    // Strip z = or f(x,y) = prefix
    final body = _stripSurfacePrefix(trimmed);
    if (body.isEmpty) {
      return Expression3D._(
        rawExpression: trimmed,
        normalizedExpression: '',
        type: Expression3DType.surface,
        parameters: {},
        parseError: '表达式为空',
      );
    }

    // Normalize
    final normalized = _normalizeExpression(body);

    // Create evaluator
    String? error;
    double Function(double, double)? evalFn;

    try {
      evalFn = _createSurfaceEvaluator(normalized, parameterValues);
    } catch (e) {
      error = e.toString();
    }

    final params = _extractParameters(body);

    return Expression3D._(
      rawExpression: trimmed,
      normalizedExpression: normalized,
      type: Expression3DType.surface,
      parameters: params,
      surfaceEvaluator: evalFn,
      parseError: error,
    );
  }

  /// Evaluate the surface at (x, y).
  double evaluateSurface(double x, double y) {
    if (_surfaceEvaluator == null) throw _parseError ?? '无效的曲面表达式';
    return _surfaceEvaluator!(x, y);
  }

  /// Sample the surface on a grid and return a [MeshData].
  MeshData sampleSurfaceGrid({
    double xMin = -5,
    double xMax = 5,
    double yMin = -5,
    double yMax = 5,
    int gridX = 40,
    int gridY = 40,
  }) {
    if (!isValid || _surfaceEvaluator == null) {
      return const MeshData(vertices: [], indices: []);
    }

    return MeshBuilder.fromFunction(
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      gridX: gridX,
      gridY: gridY,
      f: _surfaceEvaluator!,
    );
  }

  // ==================================================================
  // Implicit equation F(x, y, z) = 0
  // ==================================================================

  /// Create an implicit-surface expression from F(x, y, z) = 0 input,
  /// e.g. "x^2 + y^2 + z^2 = 6", "x + y + z = 1", "x^2 + y^2 = 4".
  factory Expression3D.implicit(
    String input, {
    Map<String, double> parameterValues = const {},
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return Expression3D._(
        rawExpression: '',
        normalizedExpression: '',
        type: Expression3DType.implicit,
        parameters: {},
        parseError: '表达式为空',
      );
    }

    // Split on the first top-level '='.
    final eqIdx = _findTopLevelEquals(trimmed);
    if (eqIdx < 0) {
      return Expression3D._(
        rawExpression: trimmed,
        normalizedExpression: '',
        type: Expression3DType.implicit,
        parameters: {},
        parseError: '隐式方程需要等号，如 x^2 + y^2 + z^2 = 1',
      );
    }

    final lhsRaw = trimmed.substring(0, eqIdx).trim();
    final rhsRaw = trimmed.substring(eqIdx + 1).trim();

    String? error;
    double Function(double, double, double)? evalFn;
    try {
      final lhs = _normalizeExpression(lhsRaw);
      final rhs = _normalizeExpression(rhsRaw);
      // Auto-detect extra variables in the equation (parameters default 1).
      final varNames = _detectVariables('$lhs $rhs', ['x', 'y', 'z']);
      final mergedParams = Map<String, double>.from(parameterValues);
      for (final name in varNames) {
        if (name != 'x' &&
            name != 'y' &&
            name != 'z' &&
            !mergedParams.containsKey(name)) {
          mergedParams[name] = 1.0;
        }
      }
      final lhsFn = lhs.isEmpty ? null : lhs.toMultiVariableFunction(varNames);
      final rhsFn = rhs.isEmpty ? null : rhs.toMultiVariableFunction(varNames);
      evalFn = (x, y, z) {
        final args = <String, num>{'x': x, 'y': y, 'z': z, ...mergedParams};
        final l = lhsFn == null ? 0.0 : lhsFn(args).toDouble();
        final r = rhsFn == null ? 0.0 : rhsFn(args).toDouble();
        return l - r;
      };
    } catch (e) {
      error = e.toString();
    }

    final params = _extractParameters('$lhsRaw $rhsRaw');

    return Expression3D._(
      rawExpression: trimmed,
      normalizedExpression: '',
      type: Expression3DType.implicit,
      parameters: params,
      implicitEvaluator: evalFn,
      parseError: error,
    );
  }

  /// Evaluate the implicit function F(x, y, z) (lhs - rhs of the equation).
  double evaluateImplicit(double x, double y, double z) {
    if (_implicitEvaluator == null) throw _parseError ?? '无效的隐式方程';
    return _implicitEvaluator!(x, y, z);
  }

  /// Sample the implicit surface with marching tetrahedra.
  ///
  /// [box] is the sampling half-extent (default 5).
  /// [grid] is the number of cells per axis (default 32).
  MeshData sampleImplicitGrid({double box = 5, int grid = 32}) {
    if (!isValid || _implicitEvaluator == null) {
      return const MeshData(vertices: [], indices: []);
    }
    return _marchingTetrahedra(_implicitEvaluator!, box: box, grid: grid);
  }

  // ==================================================================
  // Parametric curve
  // ==================================================================

  /// Create a parametric curve expression.
  ///
  /// Format: (x(t), y(t), z(t))
  factory Expression3D.parametricCurve(
    String input, {
    double tMin = 0,
    double tMax = 1,
    Map<String, double> parameterValues = const {},
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return Expression3D._(
        rawExpression: '',
        normalizedExpression: '',
        type: Expression3DType.parametricCurve,
        parameters: {},
        tMin: tMin,
        tMax: tMax,
        parseError: '表达式为空',
      );
    }

    // Parse (x(t), y(t), z(t)) format
    final components = _parseParametricComponents(trimmed);
    if (components == null) {
      return Expression3D._(
        rawExpression: trimmed,
        normalizedExpression: '',
        type: Expression3DType.parametricCurve,
        parameters: {},
        tMin: tMin,
        tMax: tMax,
        parseError: '参数曲线格式错误，应为 (x(t), y(t), z(t))',
      );
    }

    String? error;
    double Function(double)? curveX, curveY, curveZ;

    try {
      final varNames = ['t'];
      for (final key in parameterValues.keys) {
        if (!varNames.contains(key)) varNames.add(key);
      }

      curveX =
          _createParametricEvaluator(components[0], varNames, parameterValues);
      curveY =
          _createParametricEvaluator(components[1], varNames, parameterValues);
      curveZ =
          _createParametricEvaluator(components[2], varNames, parameterValues);
    } catch (e) {
      error = e.toString();
    }

    final params = _extractParameters(
        '${components[0]} ${components[1]} ${components[2]}');

    return Expression3D._(
      rawExpression: trimmed,
      normalizedExpression: trimmed,
      type: Expression3DType.parametricCurve,
      parameters: params,
      curveX: curveX,
      curveY: curveY,
      curveZ: curveZ,
      tMin: tMin,
      tMax: tMax,
      parseError: error,
    );
  }

  /// Evaluate the curve at parameter t.
  Point3D evaluateCurve(double t) {
    if (_curveX == null || _curveY == null || _curveZ == null) {
      throw _parseError ?? '无效的参数曲线';
    }
    return Point3D(_curveX!(t), _curveY!(t), _curveZ!(t));
  }

  /// Sample the curve at [numSamples] points.
  List<Point3D> sampleCurve({int numSamples = 120}) {
    if (!isValid || _curveX == null) return [];
    if (numSamples < 2) return [];

    final points = <Point3D>[];
    final step = (tMax - tMin) / (numSamples - 1);

    for (int i = 0; i < numSamples; i++) {
      final t = tMin + i * step;
      try {
        points.add(evaluateCurve(t));
      } catch (_) {
        // Skip invalid points
      }
    }
    return points;
  }

  // ==================================================================
  // Parametric surface
  // ==================================================================

  /// Create a parametric surface expression.
  ///
  /// Format: (x(u,v), y(u,v), z(u,v))
  factory Expression3D.parametricSurface(
    String input, {
    double uMin = 0,
    double uMax = 1,
    double vMin = 0,
    double vMax = 1,
    Map<String, double> parameterValues = const {},
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return Expression3D._(
        rawExpression: '',
        normalizedExpression: '',
        type: Expression3DType.parametricSurface,
        parameters: {},
        uMin: uMin,
        uMax: uMax,
        vMin: vMin,
        vMax: vMax,
        parseError: '表达式为空',
      );
    }

    // Parse (x(u,v), y(u,v), z(u,v)) format
    final components = _parseParametricComponents(trimmed);
    if (components == null) {
      return Expression3D._(
        rawExpression: trimmed,
        normalizedExpression: '',
        type: Expression3DType.parametricSurface,
        parameters: {},
        uMin: uMin,
        uMax: uMax,
        vMin: vMin,
        vMax: vMax,
        parseError: '参数曲面格式错误，应为 (x(u,v), y(u,v), z(u,v))',
      );
    }

    String? error;
    double Function(double, double)? surfX, surfY, surfZ;

    try {
      final varNames = ['u', 'v'];
      for (final key in parameterValues.keys) {
        if (!varNames.contains(key)) varNames.add(key);
      }

      surfX = _createSurfaceParametricEvaluator(
          components[0], varNames, parameterValues);
      surfY = _createSurfaceParametricEvaluator(
          components[1], varNames, parameterValues);
      surfZ = _createSurfaceParametricEvaluator(
          components[2], varNames, parameterValues);
    } catch (e) {
      error = e.toString();
    }

    final params = _extractParameters(
        '${components[0]} ${components[1]} ${components[2]}');

    return Expression3D._(
      rawExpression: trimmed,
      normalizedExpression: trimmed,
      type: Expression3DType.parametricSurface,
      parameters: params,
      surfX: surfX,
      surfY: surfY,
      surfZ: surfZ,
      uMin: uMin,
      uMax: uMax,
      vMin: vMin,
      vMax: vMax,
      parseError: error,
    );
  }

  /// Evaluate the parametric surface at (u, v).
  Point3D evaluateParametricSurface(double u, double v) {
    if (_surfX == null || _surfY == null || _surfZ == null) {
      throw _parseError ?? '无效的参数曲面';
    }
    return Point3D(_surfX!(u, v), _surfY!(u, v), _surfZ!(u, v));
  }

  /// Sample the parametric surface into a [MeshData].
  MeshData sampleParametricSurface({
    int gridU = 40,
    int gridV = 40,
  }) {
    if (!isValid || _surfX == null) {
      return const MeshData(vertices: [], indices: []);
    }
    return MeshBuilder.parametric(
      x: _surfX!,
      y: _surfY!,
      z: _surfZ!,
      uMin: uMin,
      uMax: uMax,
      vMin: vMin,
      vMax: vMax,
      gridU: gridU,
      gridV: gridV,
    );
  }

  // ==================================================================
  // Parameter support
  // ==================================================================

  /// Create an updated expression with new parameter values.
  Expression3D withParameters(Map<String, double> parameterValues) {
    if (!isValid) return this;

    switch (type) {
      case Expression3DType.surface:
        return Expression3D.surface(
          rawExpression,
          parameterValues: parameterValues,
        );
      case Expression3DType.implicit:
        return Expression3D.implicit(
          rawExpression,
          parameterValues: parameterValues,
        );
      case Expression3DType.parametricCurve:
        return Expression3D.parametricCurve(
          rawExpression,
          tMin: tMin,
          tMax: tMax,
          parameterValues: parameterValues,
        );
      case Expression3DType.parametricSurface:
        return Expression3D.parametricSurface(
          rawExpression,
          uMin: uMin,
          uMax: uMax,
          vMin: vMin,
          vMax: vMax,
          parameterValues: parameterValues,
        );
    }
  }

  // ==================================================================
  // Internal helpers
  // ==================================================================

  /// Strip z = or f(x,y) = prefix from a surface expression.
  static String _stripSurfacePrefix(String expr) {
    // f(x,y) = ...
    final fxyMatch =
        RegExp(r'^f\s*\(\s*x\s*,\s*y\s*\)\s*=\s*').firstMatch(expr);
    if (fxyMatch != null) {
      return expr.substring(fxyMatch.end);
    }
    // z = ...
    final zMatch = RegExp(r'^z\s*=\s*').firstMatch(expr);
    if (zMatch != null) {
      return expr.substring(zMatch.end);
    }
    return expr;
  }

  /// Find the first '=' that is not inside parentheses or brackets.
  static int _findTopLevelEquals(String expr) {
    var depth = 0;
    for (int i = 0; i < expr.length; i++) {
      final ch = expr[i];
      if (ch == '(' || ch == '[') {
        depth++;
      } else if (ch == ')' || ch == ']') {
        depth--;
      } else if (ch == '=' && depth == 0) {
        return i;
      }
    }
    return -1;
  }

  /// Parse a parametric expression like (x(t), y(t), z(t)) or
  /// (x(u,v), y(u,v), z(u,v)) into three component strings.
  ///
  /// Returns null if the format is invalid.
  static List<String>? _parseParametricComponents(String expr) {
    final trimmed = expr.trim();
    // Must be wrapped in parentheses
    if (!trimmed.startsWith('(') || !trimmed.endsWith(')')) return null;

    final inner = trimmed.substring(1, trimmed.length - 1).trim();
    if (inner.isEmpty) return null;

    // Split by commas, respecting parentheses
    final components = <String>[];
    var depth = 0;
    var start = 0;

    for (int i = 0; i < inner.length; i++) {
      if (inner[i] == '(') depth++;
      if (inner[i] == ')') depth--;
      if (inner[i] == ',' && depth == 0) {
        components.add(inner.substring(start, i).trim());
        start = i + 1;
      }
    }
    components.add(inner.substring(start).trim());

    if (components.length != 3) return null;
    return components;
  }

  /// Normalize expression for function_tree.
  static String _normalizeExpression(String expr) {
    var result = expr.trim();
    if (result.isEmpty) return '';

    // Replace LaTeX commands
    result = _convertLatex(result);
    result = result.replaceAll('{', '(').replaceAll('}', ')');
    result = result.replaceAll(RegExp(r'\s+'), '');
    if (result.isEmpty) return '';

    result = _addImplicitMultiplication(result);
    return result;
  }

  /// Create a two-variable evaluator for surface f(x, y).
  static double Function(double, double) _createSurfaceEvaluator(
    String normalized,
    Map<String, double> parameterValues,
  ) {
    // Auto-detect extra variables (a, b, k, …) like the 2D parser does;
    // missing values default to 1.0 so e.g. z = a*x*y draws immediately.
    final allVars = _detectVariables(normalized, ['x', 'y']);
    final mergedParams = Map<String, double>.from(parameterValues);
    for (final name in allVars) {
      if (name != 'x' && name != 'y' && !mergedParams.containsKey(name)) {
        mergedParams[name] = 1.0;
      }
    }

    final multiFunc = normalized.toMultiVariableFunction(allVars);
    return (double x, double y) {
      final args = Map<String, num>.from(mergedParams);
      args['x'] = x;
      args['y'] = y;
      return multiFunc(args).toDouble();
    };
  }

  /// Create a single-variable evaluator for parametric curve components.
  static double Function(double) _createParametricEvaluator(
    String expr,
    List<String> variableNames,
    Map<String, double> parameterValues,
  ) {
    final normalized = _normalizeExpression(expr);

    // Auto-detect additional variables in the expression.
    final allVars = _detectVariables(normalized, ['t']);

    final mergedParams = Map<String, double>.from(parameterValues);
    for (final name in allVars) {
      if (name != 't' && !mergedParams.containsKey(name)) {
        mergedParams[name] = 1.0;
      }
    }

    final multiFunc = normalized.toMultiVariableFunction(allVars);
    return (double t) {
      final args = Map<String, num>.from(mergedParams);
      args['t'] = t;
      return multiFunc(args).toDouble();
    };
  }

  /// Create a two-variable evaluator for parametric surface components.
  static double Function(double, double) _createSurfaceParametricEvaluator(
    String expr,
    List<String> variableNames,
    Map<String, double> parameterValues,
  ) {
    final normalized = _normalizeExpression(expr);

    // Auto-detect additional variables in the expression
    final allVars = _detectVariables(normalized, variableNames);
    final mergedParams = Map<String, double>.from(parameterValues);
    for (final name in allVars) {
      if (name != 'u' && name != 'v' && !mergedParams.containsKey(name)) {
        mergedParams[name] = 1.0;
      }
    }

    final multiFunc = normalized.toMultiVariableFunction(allVars);
    return (double u, double v) {
      final args = Map<String, num>.from(mergedParams);
      args['u'] = u;
      args['v'] = v;
      return multiFunc(args).toDouble();
    };
  }

  /// Detect all variable names in an expression.
  static List<String> _detectVariables(String expr, List<String> knownVars) {
    const builtinConstants = {
      'e',
      'pi',
      'ln2',
      'ln10',
      'log2e',
      'log10e',
      'sqrt1_2',
      'sqrt2'
    };
    const knownFunctions = {
      'sin',
      'cos',
      'tan',
      'sqrt',
      'abs',
      'ln',
      'log',
      'exp',
      'asin',
      'acos',
      'atan',
      'sinh',
      'cosh',
      'tanh',
      'sec',
      'csc',
      'cot',
      'pow',
      'nrt',
    };

    final result = <String>[...knownVars];
    final matches = RegExp(r'\b([a-zA-Z]\w*)\b').allMatches(expr);
    for (final m in matches) {
      final name = m[1]!;
      if (!result.contains(name) &&
          !knownFunctions.contains(name.toLowerCase()) &&
          !builtinConstants.contains(name)) {
        result.add(name);
      }
    }
    return result;
  }

  /// Extract parameter names from expression body.
  static Set<String> _extractParameters(String expr) {
    if (expr.isEmpty) return {};
    const knownFunctions = {
      'sin',
      'cos',
      'tan',
      'sqrt',
      'abs',
      'ln',
      'log',
      'exp',
      'asin',
      'acos',
      'atan',
      'sinh',
      'cosh',
      'tanh',
      'sec',
      'csc',
      'cot',
    };

    final params = <String>{};
    final matches = RegExp(r'\b([a-zA-Z]\w*)\b').allMatches(expr);
    for (final m in matches) {
      final name = m[1]!;
      if (name == 'x' || name == 'y' || name == 'z' || name == 'e') continue;
      if (knownFunctions.contains(name.toLowerCase())) continue;
      params.add(name);
    }
    return params;
  }

  // ==================================================================
  // Marching tetrahedra (implicit surfaces)
  // ==================================================================

  /// Builds a triangle mesh of the isosurface F = 0 over the box
  /// [-box, box]³ using marching tetrahedra on a [grid]³ lattice.
  static MeshData _marchingTetrahedra(
    double Function(double, double, double) f, {
    required double box,
    required int grid,
  }) {
    final n = grid + 1;
    final step = 2 * box / grid;

    // Sample values at lattice points.
    final values = List<double>.filled(n * n * n, 0);
    for (int iz = 0; iz < n; iz++) {
      final z = -box + iz * step;
      for (int iy = 0; iy < n; iy++) {
        final y = -box + iy * step;
        for (int ix = 0; ix < n; ix++) {
          final x = -box + ix * step;
          final v = f(x, y, z);
          // Exactly-zero samples are nudged to the positive side so the
          // isosurface never passes through a lattice vertex (that would
          // produce degenerate triangles in the tetrahedron subdivision).
          values[(iz * n + iy) * n + ix] =
              v.isFinite ? (v == 0 ? 1e-12 : v) : double.infinity;
        }
      }
    }

    Point3D vertex(int ix, int iy, int iz) =>
        Point3D(-box + ix * step, -box + iy * step, -box + iz * step);

    // Cell corners and the 12 edges connecting them.
    final corners = List.generate(8, (i) => Point3D.origin);
    final cornerVals = List<double>.filled(8, 0);

    // Subdivide each cell into 6 tetrahedra (Kuhn/Freudenthal decomposition):
    // a fan around the body diagonal 0–7 (corner 7 = (1,1,1)). Seen from
    // that diagonal the six outer corners form a hexagon 1→3→2→6→4→5, and
    // each wedge {0,7,vi,vi+1} tiles the cube exactly once with consistent
    // face diagonal choices (e.g. every y=0 face is split along 0–5, every
    // adjacent cell's y=1 face along its 2–7 — the same geometric diagonal).
    // Any other fan ordering overlaps the wedges and leaves grid edges
    // uncovered, which produces cracks against neighboring cells.
    // NOTE: some tetrahedra contain face/body diagonals, so each tetrahedron
    // interpolates its own 6 edges (shared via a cell-level cache so the
    // mesh stays watertight without duplicate vertices).
    const tetras = [
      [0, 1, 3, 7],
      [0, 3, 2, 7],
      [0, 2, 6, 7],
      [0, 6, 4, 7],
      [0, 4, 5, 7],
      [0, 5, 1, 7],
    ];

    final verts = <Point3D>[];
    final indices = <int>[];

    // Lazily-created global grid-vertex indices: adjacent cells share the
    // same lattice vertices so the mesh is index-watertight, and edge
    // intersections that land (numerically) on a corner snap to that corner
    // instead of producing a degenerate sliver triangle.
    final gridVertexIdx = <int, int>{};
    int cornerVertex(int posIdx) {
      final cached = gridVertexIdx[posIdx];
      if (cached != null) return cached;
      final idx = verts.length;
      final ix = posIdx % n, iy = (posIdx ~/ n) % n, iz = posIdx ~/ (n * n);
      verts.add(vertex(ix, iy, iz));
      gridVertexIdx[posIdx] = idx;
      return idx;
    }

    for (int iz = 0; iz < grid; iz++) {
      for (int iy = 0; iy < grid; iy++) {
        for (int ix = 0; ix < grid; ix++) {
          final cornerPos = List<int>.filled(8, 0);
          for (int i = 0; i < 8; i++) {
            final dx = i & 1, dy = (i >> 1) & 1, dz = (i >> 2) & 1;
            corners[i] = vertex(ix + dx, iy + dy, iz + dz);
            cornerPos[i] = ((iz + dz) * n + (iy + dy)) * n + (ix + dx);
            cornerVals[i] = values[cornerPos[i]];
          }

          // Edge intersection cache for this cell: key = a*8+b (a<b).
          final edgeIdx = <int, int>{};

          int interp(int a, int b) {
            final key = a < b ? a * 8 + b : b * 8 + a;
            final cached = edgeIdx[key];
            if (cached != null) return cached;
            final fa = cornerVals[a], fb = cornerVals[b];
            if ((fa < 0 && fb >= 0) || (fa >= 0 && fb < 0)) {
              final k = fa / (fa - fb);
              // Snap intersections within 1e-9 of a corner to the corner
              // itself: a sliver at 1e-13 is a degenerate triangle.
              const eps = 1e-9;
              if (k <= eps) {
                final idx = cornerVertex(cornerPos[a]);
                edgeIdx[key] = idx;
                return idx;
              }
              if (k >= 1 - eps) {
                final idx = cornerVertex(cornerPos[b]);
                edgeIdx[key] = idx;
                return idx;
              }
              final idx = verts.length;
              verts.add(corners[a].lerp(corners[b], k));
              edgeIdx[key] = idx;
              return idx;
            }
            edgeIdx[key] = -1;
            return -1;
          }

          for (final t in tetras) {
            final tv = [
              cornerVals[t[0]],
              cornerVals[t[1]],
              cornerVals[t[2]],
              cornerVals[t[3]],
            ];
            final neg = <int>[];
            for (int i = 0; i < 4; i++) {
              if (tv[i] < 0) neg.add(i);
            }
            if (neg.isEmpty || neg.length == 4) continue;

            void addTri(int va, int vb, int vc) {
              if (va < 0 || vb < 0 || vc < 0) return;
              // Drop slivers that collapsed onto a corner (isosurface
              // grazing a lattice vertex): zero-area faces break rendering.
              if (va == vb || vb == vc || va == vc) return;
              indices.addAll([va, vb, vc]);
            }

            if (neg.length == 1) {
              final i = neg[0];
              final other = [0, 1, 2, 3]..remove(i);
              addTri(
                interp(t[i], t[other[0]]),
                interp(t[i], t[other[1]]),
                interp(t[i], t[other[2]]),
              );
            } else if (neg.length == 3) {
              final pos = [0, 1, 2, 3].firstWhere((e) => !neg.contains(e));
              addTri(
                interp(t[pos], t[neg[0]]),
                interp(t[pos], t[neg[1]]),
                interp(t[pos], t[neg[2]]),
              );
            } else {
              final i = neg[0];
              final j = neg[1];
              final k = [0, 1, 2, 3].firstWhere((e) => !neg.contains(e));
              final l = [0, 1, 2, 3].lastWhere((e) => !neg.contains(e));
              addTri(
                interp(t[i], t[k]),
                interp(t[j], t[k]),
                interp(t[j], t[l]),
              );
              addTri(
                interp(t[i], t[k]),
                interp(t[j], t[l]),
                interp(t[i], t[l]),
              );
            }
          }
        }
      }
    }

    return MeshData(vertices: verts, indices: indices);
  }

  // ==================================================================
  // LaTeX conversion (reused from MathExpression)
  // ==================================================================

  static String _convertLatex(String expr) {
    var result = expr;

    // \frac
    result = _replaceFrac(result);
    result = result.replaceAll(RegExp(r'\\left\b'), '');
    result = result.replaceAll(RegExp(r'\\right\b'), '');
    result = result.replaceAll(RegExp(r'\\times\b'), '*');
    result = result.replaceAll(RegExp(r'\\cdot\b'), '*');
    result = result.replaceAll(RegExp(r'\\div\b'), '/');

    // Functions
    result = result.replaceAll(RegExp(r'\\sin\b'), 'sin');
    result = result.replaceAll(RegExp(r'\\cos\b'), 'cos');
    result = result.replaceAll(RegExp(r'\\tan\b'), 'tan');
    result = result.replaceAll(RegExp(r'\\cot\b'), 'cot');
    result = result.replaceAll(RegExp(r'\\sec\b'), 'sec');
    result = result.replaceAll(RegExp(r'\\csc\b'), 'csc');
    result = result.replaceAll(RegExp(r'\\sqrt\b'), 'sqrt');
    result = result.replaceAll(RegExp(r'\\ln\b'), 'ln');
    result = result.replaceAll(RegExp(r'\\log\b'), 'log');
    result = result.replaceAll(RegExp(r'\\exp\b'), 'exp');
    result = result.replaceAll(RegExp(r'\\sinh\b'), 'sinh');
    result = result.replaceAll(RegExp(r'\\cosh\b'), 'cosh');
    result = result.replaceAll(RegExp(r'\\tanh\b'), 'tanh');
    result = result.replaceAll(RegExp(r'\\arcsin\b'), 'asin');
    result = result.replaceAll(RegExp(r'\\arccos\b'), 'acos');
    result = result.replaceAll(RegExp(r'\\arctan\b'), 'atan');
    result = result.replaceAll(RegExp(r'\\abs\b'), 'abs');

    // Constants
    result = result.replaceAll(RegExp(r'\\pi\b'), 'pi');
    result = result.replaceAll(RegExp(r'\\infty\b'), 'Infinity');

    // Greek
    result = result.replaceAll(RegExp(r'\\alpha\b'), 'alpha');
    result = result.replaceAll(RegExp(r'\\beta\b'), 'beta');
    result = result.replaceAll(RegExp(r'\\gamma\b'), 'gamma');
    result = result.replaceAll(RegExp(r'\\delta\b'), 'delta');

    // Strip any remaining backslash commands
    result = result.replaceAllMapped(
      RegExp(r'\\([a-zA-Z]+)'),
      (m) => m[1]!,
    );

    return result;
  }

  static String _replaceFrac(String expr) {
    final fracRegex = RegExp(r'\\frac\b');
    var result = expr;
    int pos;

    while ((pos = result.indexOf(fracRegex, 0)) != -1) {
      final start1 = pos + 5;
      var idx = start1;
      while (idx < result.length && result[idx] == ' ') {
        idx++;
      }
      if (idx >= result.length || result[idx] != '{') break;

      int depth = 1;
      idx++;
      final contentStart1 = idx;
      while (idx < result.length && depth > 0) {
        if (result[idx] == '{') {
          depth++;
        } else if (result[idx] == '}') {
          depth--;
        }
        if (depth > 0) idx++;
      }
      if (depth != 0) break;
      final content1 = result.substring(contentStart1, idx);
      idx++;
      while (idx < result.length && result[idx] == ' ') {
        idx++;
      }
      if (idx >= result.length || result[idx] != '{') break;

      depth = 1;
      idx++;
      final contentStart2 = idx;
      while (idx < result.length && depth > 0) {
        if (result[idx] == '{') {
          depth++;
        } else if (result[idx] == '}') {
          depth--;
        }
        if (depth > 0) idx++;
      }
      if (depth != 0) break;
      final content2 = result.substring(contentStart2, idx);
      final braceEnd2 = idx;

      final before = result.substring(0, pos);
      final after = result.substring(braceEnd2 + 1);
      result = '$before($content1)/($content2)$after';
    }

    return result;
  }

  static String _addImplicitMultiplication(String expr) {
    var result = expr;
    result = result.replaceAllMapped(
      RegExp(r'(\d)([a-zA-Z(])'),
      (m) => '${m[1]!}*${m[2]!}',
    );
    result = result.replaceAllMapped(
      RegExp(r'(\))\s*([a-zA-Z(])'),
      (m) => '${m[1]!}*${m[2]!}',
    );
    result = result.replaceAllMapped(
      RegExp(r'(?<![a-zA-Z])([a-zA-Z])(?![a-zA-Z])\('),
      (match) => '${match[1]}*(',
    );
    return result;
  }
}
