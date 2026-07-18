import 'package:function_tree/function_tree.dart';

/// Represents a single math expression with its various forms.
///
/// Uses [function_tree] for expression parsing and evaluation, enabling
/// native Flutter rendering without WebView/JSXGraph dependencies.
///
/// The [rawExpression] is the user's input (LaTeX-style).
/// [evaluator] is a callable function [double Function(double)] with
/// parameters baked in.
/// [latexDisplay] is the LaTeX display string for flutter_math_fork.
class MathExpression {
  /// The raw expression as entered by the user (e.g. "x^2", "sin(x)").
  final String rawExpression;

  /// The normalized expression ready for [function_tree] parsing.
  /// For example "pow(x,2)" instead of "x^2" if needed by function_tree —
  /// but function_tree supports ^ natively, so this is just the normalized form.
  final String normalizedExpression;

  /// LaTeX display string for rendering (e.g. "y = x^2", "y = sin(x)").
  final String latexDisplay;

  /// Set of parameter names extracted from the expression (e.g. {"a", "b"}).
  final Set<String> parameters;

  /// A callable function that evaluates this expression at a given x value,
  /// with current parameter values baked in.
  final double Function(double) evaluator;

  /// Whether this expression is valid (non-empty and parseable).
  bool get isValid => rawExpression.isNotEmpty && _parseError == null;

  /// If parsing failed, contains the error message.
  final String? _parseError;

  /// The error message if the expression is invalid.
  String? get parseError => _parseError;

  const MathExpression._({
    required this.rawExpression,
    required this.normalizedExpression,
    required this.latexDisplay,
    required this.parameters,
    required this.evaluator,
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
        latexDisplay: _toLatexDisplay(trimmed),
        parameters: {},
        evaluator: (_) => 0.0,
        parseError: '表达式为空',
      );
    }

    // Normalize the expression for function_tree
    final normalized = _normalizeExpression(body);

    // Try to parse and create evaluator
    String? error;
    double Function(double)? evalFn;

    try {
      evalFn = _createEvaluator(normalized, parameterValues);
    } catch (e) {
      error = e.toString();
    }

    // Extract parameters from the original body
    final params = _extractParameters(body);

    return MathExpression._(
      rawExpression: trimmed,
      normalizedExpression: normalized,
      latexDisplay: _toLatexDisplay(trimmed),
      parameters: params,
      evaluator: evalFn ?? ((double x) {
        throw error ?? 'Unknown parse error';
      }),
      parseError: error,
    );
  }

  /// Create an updated evaluator with new parameter values.
  MathExpression withParameters(Map<String, double> parameterValues) {
    if (!isValid) return this;

    double Function(double)? evalFn;
    String? error;

    try {
      evalFn = _createEvaluator(normalizedExpression, parameterValues);
    } catch (e) {
      error = e.toString();
    }

    return MathExpression._(
      rawExpression: rawExpression,
      normalizedExpression: normalizedExpression,
      latexDisplay: latexDisplay,
      parameters: parameters,
      evaluator: evalFn ?? ((double x) {
        throw error ?? 'Unknown parse error';
      }),
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
  /// - Whitespace removal
  /// - Insertion of explicit `*` for implicit multiplication (e.g., `2x` → `2*x`)
  static String _normalizeExpression(String expr) {
    var result = expr.trim();
    if (result.isEmpty) return '';

    // Remove whitespace
    result = result.replaceAll(RegExp(r'\s+'), '');
    if (result.isEmpty) return '';

    // Handle implicit multiplication
    result = _addImplicitMultiplication(result);

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
