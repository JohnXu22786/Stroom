import 'package:function_tree/function_tree.dart';

/// The type of a math expression.
enum MathExpressionType {
  /// Explicit y = f(x) — a single-valued function of x.
  explicit,

  /// Implicit f(x,y) = 0 — a contour/relation in the plane.
  implicit,
}

/// Represents a single math expression with its various forms.
///
/// Uses [function_tree] for expression parsing and evaluation, enabling
/// native Flutter rendering without WebView/JSXGraph dependencies.
///
/// For explicit functions (e.g. "x^2", "sin(x)"), [evaluator] is a
/// [double Function(double)] and [samplePoints] samples y = f(x).
///
/// For implicit equations (e.g. "x^2+y^2=1"), [implicitEvaluator] is a
/// [double Function(double, double)] and [sampleContour] finds the zero set.
class MathExpression {
  /// The raw expression as entered by the user (e.g. "x^2", "x=1").
  final String rawExpression;

  /// The normalized expression ready for [function_tree] parsing.
  final String normalizedExpression;

  /// The type of expression (explicit or implicit).
  final MathExpressionType type;

  /// LaTeX display string for rendering.
  final String latexDisplay;

  /// Set of parameter names extracted from the expression (e.g. {"a", "b"}).
  final Set<String> parameters;

  /// For explicit functions: evaluates at a given x value.
  /// For implicit equations: evaluates f(x, y) at a given x (y defaults to 0).
  final double Function(double) evaluator;

  /// For implicit equations: evaluates f(x, y). Null for explicit.
  final double Function(double, double)? implicitEvaluator;

  /// Whether this expression is valid (non-empty and parseable).
  bool get isValid => rawExpression.isNotEmpty && _parseError == null;

  /// If parsing failed, contains the error message.
  final String? _parseError;

  /// The error message if the expression is invalid.
  String? get parseError => _parseError;

  const MathExpression._({
    required this.rawExpression,
    required this.normalizedExpression,
    required this.type,
    required this.latexDisplay,
    required this.parameters,
    required this.evaluator,
    this.implicitEvaluator,
    String? parseError,
  }) : _parseError = parseError;

  /// Create a [MathExpression] from user input.
  ///
  /// Returns an instance with [isValid] = false and [parseError] set
  /// if the input cannot be parsed.
  factory MathExpression.fromInput(
    String input, {
    Map<String, double> parameterValues = const {},
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return MathExpression._(
        rawExpression: '',
        normalizedExpression: '',
        type: MathExpressionType.explicit,
        latexDisplay: '',
        parameters: {},
        evaluator: (_) => 0.0,
        parseError: null,
      );
    }

    // Strip prefix: y = ..., f(x) = ...
    final body = _stripPrefix(trimmed);
    if (body.isEmpty) {
      return MathExpression._(
        rawExpression: trimmed,
        normalizedExpression: '',
        type: MathExpressionType.explicit,
        latexDisplay: _toLatexDisplay(trimmed),
        parameters: {},
        evaluator: (_) => 0.0,
        parseError: '表达式为空',
      );
    }

    // Detect implicit equations: body contains '=' that's not part of y= or f(x)=
    final isEquation = _isEquation(body);

    // Normalize the expression for function_tree
    final normalized = _normalizeExpression(body);

    // Try to parse and create evaluator
    String? error;
    double Function(double)? evalFn;
    double Function(double, double)? implicitFn;

    try {
      if (isEquation) {
        // For equations like x=1 or x^2+y^2=1, create f(x,y) = left - right
        final eqParts = normalized.split('=');
        if (eqParts.length == 2) {
          final implicitExpr = '(${eqParts[0]})-(${eqParts[1]})';
          // Normalize the implicit expression
          final normalizedImplicit = _normalizeExpression(implicitExpr);
          // Create multi-variable evaluator with x and y
          implicitFn = _createImplicitEvaluator(normalizedImplicit, parameterValues);
          // Also create a backward-compat explicit evaluator (y=0 slice)
          evalFn = (double x) => implicitFn!(x, 0.0);
        } else {
          error = '无效的等式';
        }
      } else {
        evalFn = _createEvaluator(normalized, parameterValues);
      }
    } catch (e) {
      error = e.toString();
    }

    // Extract parameters from the original body
    final params = _extractParameters(body);

    return MathExpression._(
      rawExpression: trimmed,
      normalizedExpression: normalized,
      type: isEquation ? MathExpressionType.implicit : MathExpressionType.explicit,
      latexDisplay: _toLatexDisplay(trimmed),
      parameters: params,
      evaluator: evalFn ?? ((double x) {
        throw error ?? 'Unknown parse error';
      }),
      implicitEvaluator: implicitFn,
      parseError: error,
    );
  }

  /// Create an updated evaluator with new parameter values.
  MathExpression withParameters(Map<String, double> parameterValues) {
    if (!isValid) return this;

    double Function(double)? evalFn;
    double Function(double, double)? implicitFn;
    String? error;

    try {
      if (type == MathExpressionType.implicit) {
        final eqParts = normalizedExpression.split('=');
        if (eqParts.length == 2) {
          final implicitExpr = _normalizeExpression('(${eqParts[0]})-(${eqParts[1]})');
          implicitFn = _createImplicitEvaluator(implicitExpr, parameterValues);
          evalFn = (double x) => implicitFn!(x, 0.0);
        }
      } else {
        evalFn = _createEvaluator(normalizedExpression, parameterValues);
      }
    } catch (e) {
      error = e.toString();
    }

    return MathExpression._(
      rawExpression: rawExpression,
      normalizedExpression: normalizedExpression,
      type: type,
      latexDisplay: latexDisplay,
      parameters: parameters,
      evaluator: evalFn ?? ((double x) {
        throw error ?? 'Unknown parse error';
      }),
      implicitEvaluator: implicitFn,
      parseError: error,
    );
  }

  /// Sample the function at [numPoints] points within [xMin]..[xMax].
  ///
  /// Returns a list of (x, y) coordinate pairs. Points where the function
  /// is undefined (NaN, infinity) are filtered out.
  List<Map<String, double>> samplePoints({
    double xMin = -10,
    double xMax = 10,
    int numPoints = 200,
  }) {
    if (!isValid || xMax <= xMin || numPoints < 2) return [];

    final step = (xMax - xMin) / (numPoints - 1);
    final points = <Map<String, double>>[];

    for (int i = 0; i < numPoints; i++) {
      final x = xMin + i * step;
      try {
        final y = evaluator(x);
        if (y.isFinite) {
          points.add({'x': x, 'y': y});
        }
      } catch (_) {
        // Skip invalid points
      }
    }

    return points;
  }

  /// Sample the contour of an implicit equation f(x,y)=0 within the viewport.
  ///
  /// Uses marching squares on a fine grid and returns line segments
  /// (pairs of points). Each inner list has exactly 2 {x, y} maps
  /// forming one segment of the contour. For non-implicit expressions,
  /// falls back to [samplePoints].
  ///
  /// The segment-based output avoids the "scattered points" issue
  /// where unordered contour points get connected incorrectly.
  List<List<Map<String, double>>> sampleContourSegments({
    double xMin = -10,
    double xMax = 10,
    double yMin = -10,
    double yMax = 10,
    int gridX = 80,
    int gridY = 80,
  }) {
    final result = <List<Map<String, double>>>[];
    if (!isValid || xMax <= xMin || yMax <= yMin) return result;
    if (type == MathExpressionType.explicit) return result;

    final evaluator2D = implicitEvaluator;
    if (evaluator2D == null) return result;

    final stepX = (xMax - xMin) / gridX;
    final stepY = (yMax - yMin) / gridY;

    // Evaluate f at each grid point
    final grid = <List<double>>[];
    for (int i = 0; i <= gridX; i++) {
      grid.add(List<double>.filled(gridY + 1, double.nan));
    }
    for (int ix = 0; ix <= gridX; ix++) {
      final x = xMin + ix * stepX;
      for (int iy = 0; iy <= gridY; iy++) {
        final y = yMin + iy * stepY;
        try {
          grid[ix][iy] = evaluator2D(x, y);
        } catch (_) {
          grid[ix][iy] = double.nan;
        }
      }
    }

    // Marching squares: for each cell, find zero-crossing edge pairs.
    for (int ix = 0; ix < gridX; ix++) {
      for (int iy = 0; iy < gridY; iy++) {
        final v00 = grid[ix][iy];
        final v10 = grid[ix + 1][iy];
        final v01 = grid[ix][iy + 1];
        final v11 = grid[ix + 1][iy + 1];

        if (v00.isNaN || v10.isNaN || v01.isNaN || v11.isNaN) continue;

        final x = xMin + ix * stepX;
        final y = yMin + iy * stepY;

        // Collect crossing info for each edge
        double? bottomT, topT, leftT, rightT;

        // Bottom edge (v00-v10)
        if (v00 * v10 < 0) {
          bottomT = v00.abs() / (v00.abs() + v10.abs());
        }
        // Top edge (v01-v11)
        if (v01 * v11 < 0) {
          topT = v01.abs() / (v01.abs() + v11.abs());
        }
        // Left edge (v00-v01)
        if (v00 * v01 < 0) {
          leftT = v00.abs() / (v00.abs() + v01.abs());
        }
        // Right edge (v10-v11)
        if (v10 * v11 < 0) {
          rightT = v10.abs() / (v10.abs() + v11.abs());
        }

        // Count crossings and connect pairs
        final crossings = [
          if (bottomT != null) 'bottom',
          if (topT != null) 'top',
          if (leftT != null) 'left',
          if (rightT != null) 'right',
        ];

        // With 2 crossings, connect them as a segment
        // With 4 (ambiguous), connect bottom-top and left-right
        // as a reasonable heuristic (works for most smooth curves)
        if (crossings.length == 2) {
          final p1 = _crossingPoint(
              crossings[0], bottomT, topT, leftT, rightT,
              x, y, stepX, stepY);
          final p2 = _crossingPoint(
              crossings[1], bottomT, topT, leftT, rightT,
              x, y, stepX, stepY);
          if (p1 != null && p2 != null) {
            result.add([p1, p2]);
          }
        } else if (crossings.length == 4) {
          // Ambiguous case: pair opposite edges
          final pBottom = _crossingPoint('bottom', bottomT, topT, leftT, rightT,
              x, y, stepX, stepY);
          final pTop = _crossingPoint('top', bottomT, topT, leftT, rightT,
              x, y, stepX, stepY);
          final pLeft = _crossingPoint('left', bottomT, topT, leftT, rightT,
              x, y, stepX, stepY);
          final pRight = _crossingPoint('right', bottomT, topT, leftT, rightT,
              x, y, stepX, stepY);
          if (pBottom != null && pTop != null) result.add([pBottom, pTop]);
          if (pLeft != null && pRight != null) result.add([pLeft, pRight]);
        }
      }
    }

    return result;
  }

  /// Compute the (x,y) coordinates of a crossing on the specified edge.
  Map<String, double>? _crossingPoint(
      String edge, double? bT, double? tT, double? lT, double? rT,
      double x, double y, double stepX, double stepY) {
    switch (edge) {
      case 'bottom':
        return bT == null ? null : {'x': x + bT * stepX, 'y': y};
      case 'top':
        return tT == null ? null : {'x': x + tT * stepX, 'y': y + stepY};
      case 'left':
        return lT == null ? null : {'x': x, 'y': y + lT * stepY};
      case 'right':
        return rT == null ? null : {'x': x + stepX, 'y': y + rT * stepY};
    }
    return null;
  }

  /// Check whether [expr] contains `=` as an equation (not y= / f(x)= prefix).
  static bool _isEquation(String expr) {
    if (!expr.contains('=')) return false;
    // If it starts with y= or f(x)=, it's explicit (already stripped prefix).
    // We already stripped those, so any remaining '=' is a true equation.
    // But x=1 is an equation, while things like "==" are malformed.
    return expr.contains('=');
  }

  /// Create a multi-variable evaluator for implicit equations f(x,y).
  static double Function(double, double) _createImplicitEvaluator(
    String normalized,
    Map<String, double> parameterValues,
  ) {
    final variableNames = ['x', 'y'];
    // Add any additional parameters from parameterValues
    for (final key in parameterValues.keys) {
      if (!variableNames.contains(key)) {
        variableNames.add(key);
      }
    }
    final multiFunc = normalized.toMultiVariableFunction(variableNames);
    return (double x, double y) {
      final args = Map<String, num>.from(parameterValues);
      args['x'] = x;
      args['y'] = y;
      return multiFunc(args).toDouble();
    };
  }

  // ==================================================================
  // Internal helpers
  // ==================================================================

  /// Strip common prefixes like "y = ", "f(x) = " from the expression.
  static String _stripPrefix(String expr) {
    // Try f(x) = (with optional spaces)
    final fxMatch = RegExp(r'^f\s*\(\s*x\s*\)\s*=\s*').firstMatch(expr);
    if (fxMatch != null) {
      return expr.substring(fxMatch.end);
    }
    // Try y = (with optional spaces)
    final yMatch = RegExp(r'^y\s*=\s*').firstMatch(expr);
    if (yMatch != null) {
      return expr.substring(yMatch.end);
    }
    return expr;
  }

  /// Normalize an expression for [function_tree] parsing.
  ///
  /// Handles:
  /// - LaTeX braces `{}` → `()` so that `2^{x-1}` becomes `2^(x-1)`
  /// - Whitespace removal
  /// - Insertion of explicit `*` for implicit multiplication (e.g., `2x` → `2*x`)
  static String _normalizeExpression(String expr) {
    var result = expr.trim();
    if (result.isEmpty) return '';

    // Step 1: Convert LaTeX commands (including \frac{}{} with braces)
    result = _convertLatex(result);

    // Step 2: Remaining braces → parentheses (for ^{...} superscript, etc.)
    result = result.replaceAll('{', '(').replaceAll('}', ')');

    // Step 3: Remove whitespace
    result = result.replaceAll(RegExp(r'\s+'), '');
    if (result.isEmpty) return '';

    // Step 4: Handle implicit multiplication
    result = _addImplicitMultiplication(result);

    return result;
  }

  /// Replace `\frac{numerator}{denominator}` with `(num)/(denom)`.
  /// Supports nested braces via brace-level counting.
  static String _replaceFrac(String expr) {
    final fracRegex = RegExp(r'\\frac\b');
    var result = expr;
    int pos;

    while ((pos = result.indexOf(fracRegex, 0)) != -1) {
      // Found \frac at pos
      final start1 = pos + 5; // skip past \frac
      var idx = start1;
      // Skip whitespace before first {
      while (idx < result.length && result[idx] == ' ') {
        idx++;
      }
      if (idx >= result.length || result[idx] != '{') break; // malformed

      // Extract first {…} content with brace counting
      int depth = 1;
      idx++; // move past opening {
      final contentStart1 = idx;
      while (idx < result.length && depth > 0) {
        if (result[idx] == '{') {
          depth++;
        } else if (result[idx] == '}') {
          depth--;
        }
        if (depth > 0) idx++;
      }
      if (depth != 0) break; // unmatched brace
      final content1 = result.substring(contentStart1, idx);
      // Move past first }
      idx++;
      // Skip whitespace before second {
      while (idx < result.length && result[idx] == ' ') {
        idx++;
      }
      if (idx >= result.length || result[idx] != '{') break;

      // Extract second {…}
      depth = 1;
      idx++; // move past opening {
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

      // Replace \frac{content1}{content2} with (content1)/(content2)
      final before = result.substring(0, pos);
      final after = result.substring(braceEnd2 + 1);
      result = '$before($content1)/($content2)$after';
    }

    return result;
  }

  /// Convert LaTeX command sequences to plain math notation.
  ///
  /// Handles `\frac`, `\times`, `\cdot`, `\div`, `\sin`, `\cos`, `\tan`,
  /// `\ln`, `\log`, `\sqrt`, `\left`/`\right`, `\pi`, Greek letters,
  /// spacing commands, and any unknown command by stripping the backslash.
  ///
  /// This runs BEFORE `{}` → `()` conversion, so braces are still intact.
  static String _convertLatex(String expr) {
    var result = expr;

    // 1) \frac{numerator}{denominator} → (numerator)/(denominator)
    //    Uses a simple brace-matcher: find first {…} and second {…}
    //    after \frac. Works with nested braces.
    result = _replaceFrac(result);

    // 2) Remove \left and \right (they add no meaning for function_tree)
    result = result.replaceAll(RegExp(r'\\left\b'), '');
    result = result.replaceAll(RegExp(r'\\right\b'), '');

    // 3) Operators
    result = result.replaceAll(RegExp(r'\\times\b'), '*');
    result = result.replaceAll(RegExp(r'\\cdot\b'), '*');
    result = result.replaceAll(RegExp(r'\\div\b'), '/');
    result = result.replaceAll(RegExp(r'\\pm\b'), '+-'); // ± → +-
    result = result.replaceAll(RegExp(r'\\mp\b'), '-+'); // ∓ → -+

    // 4) Functions (known to function_tree)
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

    // 5) Constants
    result = result.replaceAll(RegExp(r'\\pi\b'), 'pi');
    result = result.replaceAll(RegExp(r'\\infty\b'), 'Infinity');

    // 6) Greek letters → single ASCII letters (for parameter usage)
    result = result.replaceAll(RegExp(r'\\alpha\b'), 'alpha');
    result = result.replaceAll(RegExp(r'\\beta\b'), 'beta');
    result = result.replaceAll(RegExp(r'\\gamma\b'), 'gamma');
    result = result.replaceAll(RegExp(r'\\delta\b'), 'delta');
    result = result.replaceAll(RegExp(r'\\epsilon\b'), 'epsilon');
    result = result.replaceAll(RegExp(r'\\theta\b'), 'theta');
    result = result.replaceAll(RegExp(r'\\phi\b'), 'phi');

    // 7) Spacing commands → space (will be stripped later, but
    //    keeps token separation for the implicit multiplication pass)
    result = result.replaceAll(RegExp(r'\\;\b'), ' ');
    result = result.replaceAll(RegExp(r'\\:\b'), ' ');
    result = result.replaceAll(RegExp(r'\\,\b'), ' ');
    result = result.replaceAll(RegExp(r'\\!\b'), '');
    result = result.replaceAll(RegExp(r'\\quad\b'), ' ');
    result = result.replaceAll(RegExp(r'\\qquad\b'), '  ');
    result = result.replaceAll(RegExp(r'\\space\b'), ' ');

    // 8) Superscript/subscript notation: x^{n} already handled by
    //    brace conversion above. Handle x_n notation: x_n → x_n
    //    (subscript is kept as-is for parameter naming)

    // 9) Catch-all: any remaining \command → just command
    //    (function_tree will likely reject it, but won't crash)
    result = result.replaceAllMapped(
      RegExp(r'\\([a-zA-Z]+)'),
      (m) => m[1]!,
    );

    return result;
  }

  /// Insert explicit `*` operators for implicit multiplication.
  ///
  /// Cases:
  /// - `2x` → `2*x` (number followed by letter)
  /// - `2(x+1)` → `2*(x+1)` (number followed by paren)
  /// - `)x` → `)*x` (closing paren followed by letter)
  /// - `)(` → `)*(` (closing paren followed by opening paren)
  /// - `x(y+1)` → `x*(y+1)` (single variable letter followed by paren)
  ///
  /// Known function names (sin, cos, sqrt, etc.) are NOT modified.
  static String _addImplicitMultiplication(String expr) {
    var result = expr;

    // number → letter or '('
    result = result.replaceAllMapped(
      RegExp(r'(\d)([a-zA-Z(])'),
      (m) => '${m[1]!}*${m[2]!}',
    );

    // ')' → letter or '(' or number
    result = result.replaceAllMapped(
      RegExp(r'(\))\s*([a-zA-Z(])'),
      (m) => '${m[1]!}*${m[2]!}',
    );

    // Single letter → '(' (implicit multiplication like x(2) → x*(2))
    // Only match standalone single letters (not part of a longer identifier
    // like sin, cos, sqrt). Uses negative lookbehind (not preceded by letter)
    // and negative lookahead (not followed by letter).
    result = result.replaceAllMapped(
      RegExp(r'(?<![a-zA-Z])([a-zA-Z])(?![a-zA-Z])\('),
      (match) {
        return '${match[1]}*(';
      },
    );

    return result;
  }

  /// Known function names that should not trigger implicit multiplication
  /// insertion when followed by '('.
  static const Set<String> _knownFunctions = {
    'sin', 'cos', 'tan', 'sqrt', 'abs', 'ln', 'log', 'exp',
    'asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh',
    'sec', 'csc', 'cot', 'pow', 'nrt',
  };

  /// Create an evaluator [double Function(double)] from a normalized expression.
  ///
  /// Uses [function_tree] to parse the expression into a callable function.
  /// [parameterValues] provides values for parameters (e.g., a, b, c).
  /// The variable `x` is the independent variable.
  static double Function(double) _createEvaluator(
    String normalized,
    Map<String, double> parameterValues,
  ) {
    // Detect all variable names in the expression (excluding known functions
    // and built-in constants like e and pi).
    // This ensures we handle parameters like a, b, c even if no values provided.
    final variableNames = <String>['x'];
    // Built-in constants in function_tree that should not be treated as variables
    const builtinConstants = {'e', 'pi', 'ln2', 'ln10', 'log2e', 'log10e', 'sqrt1_2', 'sqrt2'};
    // Use a simple regex to find potential variable names
    final varMatches = RegExp(r'\b([a-zA-Z]\w*)\b').allMatches(normalized);
    for (final m in varMatches) {
      final name = m[1]!;
      if (name != 'x' &&
          !_knownFunctions.contains(name.toLowerCase()) &&
          !builtinConstants.contains(name)) {
        if (!variableNames.contains(name)) {
          variableNames.add(name);
        }
      }
    }

    // If there are additional variables (parameters), use multi-variable function.
    // Otherwise use the simpler single-variable function.
    if (variableNames.length > 1 || parameterValues.isNotEmpty) {
      // Merge provided parameter values with defaults for any unset variables
      final mergedParams = Map<String, double>.from(parameterValues);
      for (final name in variableNames) {
        if (name != 'x' && !mergedParams.containsKey(name)) {
          mergedParams[name] = 1.0; // Default value for parameters
        }
      }

      final multiFunc = normalized.toMultiVariableFunction(variableNames);
      return (double x) {
        final args = Map<String, num>.from(mergedParams);
        args['x'] = x;
        final result = multiFunc(args);
        return result.toDouble();
      };
    } else {
      // Simple single-variable function (just x)
      final singleFunc = normalized.toSingleVariableFunction();
      return (double x) => singleFunc(x).toDouble();
    }
  }

  // ==================================================================
  // LaTeX display
  // ==================================================================

  /// Convert a user expression to a LaTeX display string.
  static String _toLatexDisplay(String input) {
    var expr = input.trim();
    if (expr.isEmpty) return '';

    // Check if it already has a prefix like y = or f(x) =
    if (RegExp(r'^[a-zA-Z]+\s*\(\s*[a-zA-Z]*\s*\)\s*=').hasMatch(expr) ||
        RegExp(r'^[a-zA-Z]\s*=').hasMatch(expr)) {
      // Normalize spacing around =
      expr = expr.replaceAllMapped(
        RegExp(r'^([a-zA-Z]+\s*\(\s*[a-zA-Z]*\s*\))\s*=\s*(.*)'),
        (m) => '${m[1]!.trim()} = ${m[2]!.trim()}',
      );
      expr = expr.replaceAllMapped(
        RegExp(r'^([a-zA-Z])\s*=\s*(.*)'),
        (m) => '${m[1]!.trim()} = ${m[2]!.trim()}',
      );
      return expr;
    }

    // No prefix — add y =
    return 'y = $expr';
  }

  // ==================================================================
  // Parameter extraction
  // ==================================================================

  /// Extract parameter names from a user expression body.
  ///
  /// [expr] should already have the `y = ` or `f(x) = ` prefix stripped.
  /// Returns single-letter variable names that are not `x` or `e`
  /// and not known function names.
  static Set<String> _extractParameters(String expr) {
    if (expr.isEmpty) return {};

    final params = <String>{};
    // Match single-letter variables (a-z, A-Z) that are whole words
    final matches = RegExp(r'\b([a-zA-Z])\b').allMatches(expr);
    for (final m in matches) {
      final name = m[1]!;
      // Exclude x (the variable), e (Euler's number),
      // and known function names
      if (name == 'x' || name == 'e') continue;
      if (_knownFunctions.contains(name.toLowerCase())) continue;
      params.add(name);
    }
    return params;
  }

  // ==================================================================
  // Backward compatibility: JS expression conversion
  // (used by the deprecated WebView-based canvas)
  // ==================================================================

  /// Convert a normalized expression to a JavaScript-evaluable form.
  ///
  /// This is kept for backward compatibility with the old WebView-based
  /// [math_canvas_webview] widget. New code should use [evaluator] directly.
  static String toJsExpression(String input) {
    var expr = input.trim();
    if (expr.isEmpty) return '';

    // Strip prefix
    expr = _stripPrefix(expr);
    if (expr.isEmpty) return '';

    // Remove all whitespace
    expr = expr.replaceAll(RegExp(r'\s+'), '');
    if (expr.isEmpty) return '';

    // Handle implicit multiplication
    expr = _addImplicitMultiplication(expr);

    // Convert known functions to Math.* equivalents
    expr = expr.replaceAllMapped(
      RegExp(r'\b(sin|cos|tan|sqrt|abs|ln|log|exp|asin|acos|atan|sinh|cosh|tanh)\('),
      (m) => 'Math.${m[1]}(',
    );

    // Handle ^ operator
    expr = _convertPowersForJS(expr);

    // Handle e^x
    expr = expr.replaceAllMapped(
      RegExp(r'e\^\(([^()]+)\)'),
      (m) => 'Math.exp(${m[1]!})',
    );
    expr = expr.replaceAllMapped(
      RegExp(r'e\^([a-zA-Z0-9]+)'),
      (m) => 'Math.exp(${m[1]!})',
    );

    // Handle pi
    expr = expr.replaceAllMapped(
      RegExp(r'\bpi\b'),
      (_) => 'Math.PI',
    );

    return expr;
  }

  /// Convert `^` to `Math.pow()` for JavaScript evaluation.
  static String _convertPowersForJS(String expr) {
    var result = expr;
    // Parenthesized base: (expr)^power
    bool changed;
    do {
      changed = false;
      result = result.replaceAllMapped(
        RegExp(r'\(([^()]+)\)\^([a-zA-Z0-9]+)'),
        (m) {
          changed = true;
          return 'Math.pow((${m[1]!}),${m[2]!})';
        },
      );
    } while (changed);

    // Simple base: identifier^power
    do {
      changed = false;
      result = result.replaceAllMapped(
        RegExp(r'([a-zA-Z0-9]+)\^([a-zA-Z0-9]+)'),
        (m) {
          changed = true;
          return 'Math.pow(${m[1]!},${m[2]!})';
        },
      );
    } while (changed);

    return result;
  }

  /// Generate a JavaScript function body from a JS expression.
  ///
  /// Kept for backward compatibility with the deprecated WebView canvas.
  static String generateFunctionBody(String jsExpression) {
    if (jsExpression.isEmpty) return 'return 0;';
    return 'return $jsExpression;';
  }
}
