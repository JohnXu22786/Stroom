import 'dart:math' as dart_math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_expression.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MathExpression - fromInput (evaluator)', () {
    test('evaluates simple power expression', () {
      final expr = MathExpression.fromInput('x^2');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(0), closeTo(0, 1e-10));
      expect(expr.evaluator(2), closeTo(4, 1e-10));
      expect(expr.evaluator(-2), closeTo(4, 1e-10));
    });

    test('evaluates expression with y= prefix', () {
      final expr = MathExpression.fromInput('y = x^2');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(2), closeTo(4, 1e-10));
    });

    test('evaluates expression with f(x)= prefix', () {
      final expr = MathExpression.fromInput('f(x) = x^2');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(2), closeTo(4, 1e-10));
    });

    test('evaluates sin function', () {
      final expr = MathExpression.fromInput('sin(x)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(0), closeTo(0, 1e-10));
      expect(expr.evaluator(3.14159 / 2), closeTo(1, 1e-4));
    });

    test('evaluates cos function', () {
      final expr = MathExpression.fromInput('cos(x)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(0), closeTo(1, 1e-10));
    });

    test('evaluates tan function', () {
      final expr = MathExpression.fromInput('tan(x)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(0), closeTo(0, 1e-10));
    });

    test('evaluates sqrt function', () {
      final expr = MathExpression.fromInput('sqrt(x)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(4), closeTo(2, 1e-10));
    });

    test('evaluates ln/log function', () {
      final expr = MathExpression.fromInput('ln(x)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(1), closeTo(0, 1e-10));
      expect(expr.evaluator(dart_math.e), closeTo(1, 1e-4));
    });

    test('evaluates abs function', () {
      final expr = MathExpression.fromInput('abs(x)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(-5), closeTo(5, 1e-10));
      expect(expr.evaluator(3), closeTo(3, 1e-10));
    });

    test('evaluates complex polynomial expression', () {
      final expr = MathExpression.fromInput('x^3 + 2*x^2 - 5*x + 1');
      expect(expr.isValid, isTrue);
      // x=0: 1
      // x=1: 1 + 2 - 5 + 1 = -1
      // x=2: 8 + 8 - 10 + 1 = 7
      expect(expr.evaluator(0), closeTo(1, 1e-10));
      expect(expr.evaluator(1), closeTo(-1, 1e-10));
      expect(expr.evaluator(2), closeTo(7, 1e-10));
    });

    test('evaluates expression with multiple trig functions', () {
      final expr = MathExpression.fromInput('sin(x) + cos(x)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(0), closeTo(1, 1e-10)); // sin(0)+cos(0)=0+1=1
    });

    test('evaluates implicit multiplication: 2x equals 2*x', () {
      final expr = MathExpression.fromInput('2x');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(3), closeTo(6, 1e-10));
    });

    test('evaluates implicit multiplication: 2(x+1) equals 2*(x+1)', () {
      final expr = MathExpression.fromInput('2(x+1)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(4), closeTo(10, 1e-10));
    });

    test('evaluates implicit multiplication: x(2) equals x*(2)', () {
      final expr = MathExpression.fromInput('x(2)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(3), closeTo(6, 1e-10));
      expect(expr.evaluator(5), closeTo(10, 1e-10));
    });

    test('evaluates implicit multiplication: a(x+1) equals a*(x+1)', () {
      final expr = MathExpression.fromInput('a(x+1)');
      expect(expr.isValid, isTrue);
      expect(expr.parameters, equals({'a'}));
      expect(expr.evaluator(4), closeTo(5, 1e-10)); // a=1 (default): 1*(4+1)=5
    });

    test('implicit multiplication does not break function names', () {
      final expr = MathExpression.fromInput('sin(x) + cos(x)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(0), closeTo(1, 1e-10));
    });

    test('implicit multiplication does not break sqrt', () {
      final expr = MathExpression.fromInput('sqrt(4)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(0), closeTo(2, 1e-10)); // sqrt(4)=2 (x not used)
    });

    test('implicit multiplication: )( pattern', () {
      final expr = MathExpression.fromInput('(x+1)(x+2)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(0), closeTo(2, 1e-10)); // (0+1)*(0+2)=2
    });

    test('handles empty string', () {
      final expr = MathExpression.fromInput('');
      expect(expr.isValid, isFalse);
    });

    test('handles whitespace-only string', () {
      final expr = MathExpression.fromInput('   ');
      expect(expr.isValid, isFalse);
    });

    test('evaluates e^x (Euler number exponent)', () {
      final expr = MathExpression.fromInput('e^x');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(0), closeTo(1, 1e-10));
      expect(expr.evaluator(1), closeTo(dart_math.e, 1e-4));
    });

    test('evaluates pi constant', () {
      final expr = MathExpression.fromInput('sin(x + pi)');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(0), closeTo(0, 1e-10));
    });

    test('strips whitespace in conversion', () {
      final expr = MathExpression.fromInput('  x ^ 2  ');
      expect(expr.isValid, isTrue);
      expect(expr.evaluator(3), closeTo(9, 1e-10));
    });

    test('returns error for invalid expression', () {
      final expr = MathExpression.fromInput('x ^^ 2');
      expect(expr.isValid, isFalse);
      expect(expr.parseError, isNot(isNull));
    });

    test('returns error for malformed expression', () {
      final expr = MathExpression.fromInput('sin( + cos(x)');
      expect(expr.isValid, isFalse);
      expect(expr.parseError, isNot(isNull));
    });
  });

  group('MathExpression - withParameters', () {
    test('creates evaluator with parameter values', () {
      final expr = MathExpression.fromInput('a*x^2 + b',
          parameterValues: {'a': 2, 'b': 1});
      expect(expr.isValid, isTrue);
      // a=2, b=1: 2*x^2 + 1
      // x=0: 1
      // x=1: 3
      // x=2: 9
      expect(expr.evaluator(0), closeTo(1, 1e-10));
      expect(expr.evaluator(1), closeTo(3, 1e-10));
      expect(expr.evaluator(2), closeTo(9, 1e-10));
    });

    test('updates evaluator with new parameter values', () {
      final expr = MathExpression.fromInput('a*x + b',
          parameterValues: {'a': 2, 'b': 3});
      expect(expr.evaluator(5), closeTo(13, 1e-10)); // 2*5+3=13

      final updated = expr.withParameters({'a': 3, 'b': 1});
      expect(updated.evaluator(5), closeTo(16, 1e-10)); // 3*5+1=16
    });

    test('withParameters on invalid expression returns self', () {
      final expr = MathExpression.fromInput('');
      final updated = expr.withParameters({'a': 1});
      expect(identical(expr, updated), isTrue);
    });
  });

  group('MathExpression - latexDisplay', () {
    test('adds y= prefix when not present', () {
      expect(MathExpression.fromInput('x^2').latexDisplay, equals('y = x^2'));
    });

    test('preserves existing y= prefix', () {
      expect(
        MathExpression.fromInput('y = x^2').latexDisplay,
        equals('y = x^2'),
      );
    });

    test('preserves existing y= with spaces', () {
      expect(
        MathExpression.fromInput('y =   x^2').latexDisplay,
        equals('y = x^2'),
      );
    });

    test('preserves existing f(x)= prefix', () {
      expect(
        MathExpression.fromInput('f(x) = sin(x)').latexDisplay,
        equals('f(x) = sin(x)'),
      );
    });

    test('handles empty input', () {
      expect(MathExpression.fromInput('').latexDisplay, equals(''));
    });
  });

  group('MathExpression - parameters', () {
    test('extracts no parameters from simple x expression', () {
      expect(
        MathExpression.fromInput('x^2').parameters,
        isEmpty,
      );
    });

    test('extracts single parameter a', () {
      expect(
        MathExpression.fromInput('a*x^2').parameters,
        equals({'a'}),
      );
    });

    test('extracts multiple parameters', () {
      final expr = MathExpression.fromInput('a*x^2 + b*x + c');
      expect(expr.parameters, equals({'a', 'b', 'c'}));
    });

    test('excludes x and e from parameters', () {
      expect(MathExpression.fromInput('e^x').parameters, isEmpty);
    });

    test('excludes trig function names from parameters', () {
      final expr = MathExpression.fromInput('a*sin(b*x)');
      expect(expr.parameters, equals({'a', 'b'}));
      expect(expr.parameters, isNot(contains('sin')));
    });

    test('returns empty set for empty input', () {
      expect(MathExpression.fromInput('').parameters, isEmpty);
    });
  });

  group('MathExpression - samplePoints', () {
    test('samples correct number of points', () {
      final expr = MathExpression.fromInput('x^2');
      final points = expr.samplePoints(xMin: -10, xMax: 10, numPoints: 100);
      expect(points.length, 100);
    });

    test('first and last points are correct', () {
      final expr = MathExpression.fromInput('x^2');
      final points = expr.samplePoints(xMin: -2, xMax: 2, numPoints: 5);
      expect(points.length, 5);
      expect(points.first['x'], closeTo(-2, 1e-10));
      expect(points.first['y'], closeTo(4, 1e-10));
      expect(points.last['x'], closeTo(2, 1e-10));
      expect(points.last['y'], closeTo(4, 1e-10));
    });

    test('returns empty list for invalid expression', () {
      final expr = MathExpression.fromInput('');
      expect(expr.samplePoints(), isEmpty);
    });

    test('filters out NaN/Infinity points', () {
      final expr = MathExpression.fromInput('1/(x-0.5)');
      final points = expr.samplePoints(xMin: 0, xMax: 1, numPoints: 101);
      // x-0.5 = 0 at x=0.5, which should be one of the sample points
      // since 101 points from 0 to 1 includes 0.5 exactly.
      // At x=0.5, 1/0 = Infinity (non-finite), so it should be filtered.
      expect(points.length, lessThan(101));
    });

    test('returns empty list for invalid parameters', () {
      final expr = MathExpression.fromInput('x^2');
      expect(expr.samplePoints(xMin: 10, xMax: -10, numPoints: 5), isEmpty);
      expect(expr.samplePoints(xMin: -10, xMax: 10, numPoints: 1), isEmpty);
    });
  });

  group('MathExpression - isValid', () {
    test('is false for empty expression', () {
      expect(MathExpression.fromInput('').isValid, isFalse);
    });

    test('is true for valid expression', () {
      expect(MathExpression.fromInput('x^2').isValid, isTrue);
    });

    test('is false for invalid syntax', () {
      expect(MathExpression.fromInput('x + )').isValid, isFalse);
    });
  });

  group('MathExpression - toJsExpression (backward compat)', () {
    test('converts simple power expression', () {
      expect(
        MathExpression.toJsExpression('x^2'),
        equals('Math.pow(x,2)'),
      );
    });

    test('converts expression with y= prefix', () {
      expect(
        MathExpression.toJsExpression('y = x^2'),
        equals('Math.pow(x,2)'),
      );
    });

    test('converts sin function to Math.sin', () {
      expect(
        MathExpression.toJsExpression('sin(x)'),
        equals('Math.sin(x)'),
      );
    });

    test('converts complex expression', () {
      expect(
        MathExpression.toJsExpression('x^3 + 2*x^2 - 5*x + 1'),
        equals('Math.pow(x,3)+2*Math.pow(x,2)-5*x+1'),
      );
    });

    test('handles empty string', () {
      expect(MathExpression.toJsExpression(''), equals(''));
    });
  });

  group('MathExpression - generateFunctionBody (backward compat)', () {
    test('generates return statement from JS expression', () {
      expect(
        MathExpression.generateFunctionBody('Math.pow(x,2)'),
        equals('return Math.pow(x,2);'),
      );
    });

    test('defaults to return 0 for empty', () {
      expect(
        MathExpression.generateFunctionBody(''),
        equals('return 0;'),
      );
    });
  });

  group('MathExpression - LaTeX conversion', () {
    test('\\times is converted to *', () {
      final e = MathExpression.fromInput(r'x \times e^x');
      expect(e.isValid, isTrue, reason: '\times should be converted to *');
      expect(e.evaluator(0), closeTo(0, 1e-10)); // 0 * e^0 = 0
      expect(e.evaluator(1), closeTo(dart_math.e, 1e-4)); // 1 * e^1 = e
    });

    test('\\frac{x}{y} works', () {
      final e = MathExpression.fromInput(r'\frac{x}{2}');
      expect(e.isValid, isTrue);
      expect(e.evaluator(4), closeTo(2, 1e-10)); // 4/2 = 2
    });

    test('\\frac with nested braces works: \\frac{x^{2}}{y}', () {
      final e = MathExpression.fromInput(r'\frac{x^{2}}{2}');
      expect(e.isValid, isTrue);
      // x^2 / 2
      expect(e.evaluator(4), closeTo(8, 1e-10)); // 4^2/2 = 8
    });

    test('\\sin, \\cos work', () {
      final e = MathExpression.fromInput(r'\sin(x) + \cos(x)');
      expect(e.isValid, isTrue);
      expect(e.evaluator(0), closeTo(1, 1e-10)); // sin(0)+cos(0)=1
    });

    test('\\sqrt works', () {
      final e = MathExpression.fromInput(r'\sqrt{x}');
      expect(e.isValid, isTrue);
      expect(e.evaluator(16), closeTo(4, 1e-10));
    });

    test('\\pi constant works', () {
      final e = MathExpression.fromInput(r'\pi');
      expect(e.isValid, isTrue);
      expect(e.evaluator(0), closeTo(dart_math.pi, 1e-10));
    });

    test('\\ln works', () {
      final e = MathExpression.fromInput(r'\ln(x)');
      expect(e.isValid, isTrue);
      expect(e.evaluator(1), closeTo(0, 1e-10));
    });

    test('x \\times \\sin(x) works', () {
      final e = MathExpression.fromInput(r'x \times \sin(x)');
      expect(e.isValid, isTrue);
      expect(e.evaluator(dart_math.pi / 2), closeTo(dart_math.pi / 2, 1e-4));
      // (pi/2) * sin(pi/2) = (pi/2) * 1 = pi/2
    });

    test('\\left and \\right are stripped', () {
      final e = MathExpression.fromInput(r'\left(x^2\right)');
      expect(e.isValid, isTrue);
      expect(e.evaluator(3), closeTo(9, 1e-10));
    });
  });
}
