import 'dart:math';

/// Represents a single math expression with its various forms.
///
/// The [rawExpression] is the user's input (LaTeX-style).
/// [jsExpression] is the JavaScript-evaluable form for JSXGraph.
/// [latexDisplay] is the LaTeX display string for flutter_math_fork.
class MathExpression {
  /// The raw expression as entered by the user (e.g. "x^2", "sin(x)").
  final String rawExpression;

  /// JavaScript-evaluable expression (e.g. "Math.pow(x,2)", "Math.sin(x)").
  final String jsExpression;

  /// LaTeX display string for rendering (e.g. "y = x^2", "y = sin(x)").
  final String latexDisplay;

  /// Set of parameter names extracted from the expression (e.g. {"a", "b"}).
  final Set<String> parameters;

  /// Whether this expression is valid (non-empty).
  bool get isValid => rawExpression.isNotEmpty;

  const MathExpression({
    required this.rawExpression,
    required this.jsExpression,
    required this.latexDisplay,
    required this.parameters,
  });

  /// Create a [MathExpression] from user input.
  factory MathExpression.fromInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const MathExpression(
        rawExpression: '',
        jsExpression: '',
        latexDisplay: '',
        parameters: {},
      );
    }

    final jsExpression = toJsExpression(trimmed);
    final latexDisplay = toLatexDisplay(trimmed);
    final parameters = extractParameters(jsExpression);

    return MathExpression(
      rawExpression: trimmed,
      jsExpression: jsExpression,
      latexDisplay: latexDisplay,
      parameters: parameters,
    );
  }

  // ==================================================================
  // Conversion: LaTeX-style input → JavaScript expression
  // ==================================================================

  /// Known LaTeX function → JavaScript Math.* mapping.
  static const Map<String, String> _functionMap = {
    'sin': 'Math.sin',
    'cos': 'Math.cos',
    'tan': 'Math.tan',
    'sqrt': 'Math.sqrt',
    'abs': 'Math.abs',
    'ln': 'Math.log',
    'log': 'Math.log',
    'exp': 'Math.exp',
  };

  /// Convert a user-input LaTeX-style expression to a JavaScript expression.
  ///
  /// Handles:
  /// - Prefix stripping: `y = `, `f(x) = `
  /// - Whitespace removal
  /// - LaTeX function → `Math.*` conversion (sin, cos, tan, sqrt, etc.)
  /// - `^` operator → `Math.pow(base, exponent)`
  /// - `e^x` → `Math.exp(x)`
  /// - `pi` → `Math.PI`
  /// - Implicit multiplication: `2x` → `2*x`, `2(x+1)` → `2*(x+1)`
  static String toJsExpression(String input) {
    var expr = input.trim();
    if (expr.isEmpty) return '';

    // Strip prefix: y = ..., f(x) = ...
    expr = _stripPrefix(expr);
    if (expr.isEmpty) return '';

    // Remove all whitespace
    expr = expr.replaceAll(RegExp(r'\s+'), '');
    if (expr.isEmpty) return '';

    // 1. Replace LaTeX backslash functions (\sin → sin for matching)
    for (final entry in _functionMap.entries) {
      expr = expr.replaceAll('\\${entry.key}', entry.key);
    }

    // 2. Replace function names with Math.* equivalents
    //    Use lookahead for '(' to ensure it's a function call.
    //    Use negative lookbehind to avoid double-wrapping (e.g., Math.log → Math.Math.log).
    for (final entry in _functionMap.entries) {
      expr = expr.replaceAllMapped(
        RegExp('(?<!Math\\.)${RegExp.escape(entry.key)}(?=\\()'),
        (_) => entry.value,
      );
    }

    // 3. Handle pi constant
    expr = expr.replaceAllMapped(
      RegExp(r'\bpi\b'),
      (_) => 'Math.PI',
    );

    // 4. Handle e^x → Math.exp(x)
    //    First handle e^(expr) with parenthesized exponent
    expr = expr.replaceAllMapped(
      RegExp(r'e\^\(([^()]+)\)'),
      (m) => 'Math.exp(${m[1]!})',
    );
    //    Then handle e^simple (identifier or number)
    expr = expr.replaceAllMapped(
      RegExp(r'e\^([a-zA-Z0-9]+)'),
      (m) => 'Math.exp(${m[1]!})',
    );

    // 5. Convert ^ operator to Math.pow() — handle simple identifiers first,
    //    then parenthesized expressions. Iterate to handle multiple powers.
    expr = _convertPowers(expr);

    // 6. Handle implicit multiplication
    expr = _addImplicitMultiplication(expr);

    return expr;
  }

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

  /// Convert `^` operators to `Math.pow(base, exponent)` form.
  ///
  /// Works iteratively from left to right, handling both simple
  /// identifiers and parenthesized bases.
  static String _convertPowers(String expr) {
    // First pass: handle (parenthesized base)^exponent
    bool changed;
    var result = expr;
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

    // Second pass: handle simple_identifier^exponent
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

  /// Insert explicit `*` operators for implicit multiplication.
  ///
  /// Cases:
  /// - `2x` → `2*x` (number followed by letter)
  /// - `2(x+1)` → `2*(x+1)` (number followed by paren)
  /// - `)x` → `)*x` (closing paren followed by letter)
  /// - `)(` → `)*(` (closing paren followed by opening paren)
  /// - `x(` → `x*(` (letter followed by paren, but not Math.)
  /// - `x(y+1)` → `x*(y+1)`
  static String _addImplicitMultiplication(String expr) {
    var result = expr;

    // number → letter or '('
    result = result.replaceAllMapped(
      RegExp(r'(\d)([a-zA-Z(])'),
      (m) => '${m[1]!}*${m[2]!}',
    );

    // ')' → letter or '(' or number or function start
    result = result.replaceAllMapped(
      RegExp(r'(\))\s*([a-zA-Z(])'),
      (m) => '${m[1]!}*${m[2]!}',
    );

    // letter → '(' (but not after Math. which indicates a method call)
    // Negative lookbehind prevents matching Math.sin( Math.log( etc.
    result = result.replaceAllMapped(
      RegExp(r'(?<!\bMath\b)(?<![a-zA-Z])[a-zA-Z]\('),
      (match) {
        final ch = match[0]![0]; // The letter before paren
        return '${ch}*(';
      },
    );

    return result;
  }

  // ==================================================================
  // Conversion: user input → LaTeX display string
  // ==================================================================

  /// Convert a user expression to a LaTeX display string.
  ///
  /// Adds `y = ` prefix if not already present.
  /// Normalizes spacing around `=`.
  static String toLatexDisplay(String input) {
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

  /// Known function names that should not be treated as parameters.
  static const Set<String> _knownFunctions = {
    'sin', 'cos', 'tan', 'sqrt', 'abs', 'ln', 'log', 'exp',
    'Math', 'PI', 'E',
    'pow',
  };

  /// Extract parameter names from a JavaScript expression.
  ///
  /// Returns single-letter variable names that are not `x` or `e`
  /// and not known function names.
  static Set<String> extractParameters(String expr) {
    if (expr.isEmpty) return {};

    final params = <String>{};
    // Match single-letter variables (a-z, A-Z) that are whole words
    final matches = RegExp(r'\b([a-zA-Z])\b').allMatches(expr);
    for (final m in matches) {
      final name = m[1]!;
      // Exclude x (the variable), e (Euler's number),
      // and known function names
      if (name == 'x' || name == 'e') continue;
      if (_knownFunctions.contains(name)) continue;
      params.add(name);
    }
    return params;
  }

  // ==================================================================
  // JS function body generation
  // ==================================================================

  /// Generate a JavaScript function body from a JS expression.
  ///
  /// Returns `return <jsExpression>;` or `return 0;` for empty.
  static String generateFunctionBody(String jsExpression) {
    if (jsExpression.isEmpty) return 'return 0;';
    return 'return $jsExpression;';
  }
}
