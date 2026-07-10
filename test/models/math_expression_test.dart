import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_expression.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MathExpression - toJsExpression', () {
    test('converts simple power expression', () {
      expect(MathExpression.toJsExpression('x^2'), equals('Math.pow(x,2)'));
    });

    test('converts expression with y= prefix', () {
      expect(
        MathExpression.toJsExpression('y = x^2'),
        equals('Math.pow(x,2)'),
      );
    });

    test('converts expression with f(x)= prefix', () {
      expect(
        MathExpression.toJsExpression('f(x) = x^2'),
        equals('Math.pow(x,2)'),
      );
    });

    test('converts sin function', () {
      expect(
        MathExpression.toJsExpression('sin(x)'),
        equals('Math.sin(x)'),
      );
    });

    test('converts cos function', () {
      expect(
        MathExpression.toJsExpression('cos(x)'),
        equals('Math.cos(x)'),
      );
    });

    test('converts tan function', () {
      expect(
        MathExpression.toJsExpression('tan(x)'),
        equals('Math.tan(x)'),
      );
    });

    test('converts sqrt function', () {
      expect(
        MathExpression.toJsExpression('sqrt(x)'),
        equals('Math.sqrt(x)'),
      );
    });

    test('converts ln to Math.log', () {
      expect(
        MathExpression.toJsExpression('ln(x)'),
        equals('Math.log(x)'),
      );
    });

    test('converts abs function', () {
      expect(
        MathExpression.toJsExpression('abs(x)'),
        equals('Math.abs(x)'),
      );
    });

    test('converts complex polynomial expression', () {
      expect(
        MathExpression.toJsExpression('x^3 + 2*x^2 - 5*x + 1'),
        equals('Math.pow(x,3)+2*Math.pow(x,2)-5*x+1'),
      );
    });

    test('converts expression with multiple trig functions', () {
      expect(
        MathExpression.toJsExpression('sin(x) + cos(x)'),
        equals('Math.sin(x)+Math.cos(x)'),
      );
    });

    test('converts implicit multiplication: 2x to 2*x', () {
      expect(
        MathExpression.toJsExpression('2x'),
        equals('2*x'),
      );
    });

    test('converts implicit multiplication in parentheses: 2(x+1)', () {
      expect(
        MathExpression.toJsExpression('2(x+1)'),
        equals('2*(x+1)'),
      );
    });

    test('handles empty string', () {
      expect(MathExpression.toJsExpression(''), equals(''));
    });

    test('handles whitespace-only string', () {
      expect(MathExpression.toJsExpression('   '), equals(''));
    });

    test('handles expression with e (Euler number)', () {
      expect(
        MathExpression.toJsExpression('e^x'),
        equals('Math.exp(x)'),
      );
    });

    test('handles pi constant', () {
      expect(
        MathExpression.toJsExpression('sin(x + pi)'),
        equals('Math.sin(x+Math.PI)'),
      );
    });

    test('strips whitespace in conversion', () {
      expect(
        MathExpression.toJsExpression('  x ^ 2  '),
        equals('Math.pow(x,2)'),
      );
    });
  });

  group('MathExpression - toLatexDisplay', () {
    test('adds y= prefix when not present', () {
      expect(MathExpression.toLatexDisplay('x^2'), equals('y = x^2'));
    });

    test('preserves existing y= prefix', () {
      expect(MathExpression.toLatexDisplay('y = x^2'), equals('y = x^2'));
    });

    test('preserves existing y= with spaces', () {
      expect(MathExpression.toLatexDisplay('y =   x^2'), equals('y = x^2'));
    });

    test('preserves existing f(x)= prefix', () {
      expect(
        MathExpression.toLatexDisplay('f(x) = sin(x)'),
        equals('f(x) = sin(x)'),
      );
    });

    test('returns original trimmed string for latex with backslashes', () {
      expect(
        MathExpression.toLatexDisplay('y = \\frac{1}{x}'),
        equals('y = \\frac{1}{x}'),
      );
    });

    test('handles empty input', () {
      expect(MathExpression.toLatexDisplay(''), equals(''));
    });
  });

  group('MathExpression - extractParameters', () {
    test('extracts no parameters from simple x expression', () {
      expect(MathExpression.extractParameters('x^2'), isEmpty);
    });

    test('extracts single parameter a', () {
      expect(MathExpression.extractParameters('a*x^2'), equals({'a'}));
    });

    test('extracts multiple parameters', () {
      final params = MathExpression.extractParameters('a*x^2 + b*x + c');
      expect(params, equals({'a', 'b', 'c'}));
    });

    test('excludes x and e from parameters', () {
      expect(MathExpression.extractParameters('e^x'), isEmpty);
    });

    test('excludes trig function names from parameters', () {
      final params = MathExpression.extractParameters('a*sin(b*x)');
      expect(params, equals({'a', 'b'}));
      expect(params, isNot(contains('sin')));
    });

    test('returns empty set for empty input', () {
      expect(MathExpression.extractParameters(''), isEmpty);
    });

    test('returns empty set for expression without parameters', () {
      expect(MathExpression.extractParameters('cos(x) + sin(x)'), isEmpty);
    });
  });

  group('MathExpression - fromInput', () {
    test('creates MathExpression from simple input', () {
      final expr = MathExpression.fromInput('x^2');
      expect(expr.rawExpression, equals('x^2'));
      expect(expr.jsExpression, equals('Math.pow(x,2)'));
      expect(expr.latexDisplay, equals('y = x^2'));
      expect(expr.parameters, isEmpty);
    });

    test('creates MathExpression with parameters', () {
      final expr = MathExpression.fromInput('a*x^2 + b');
      expect(expr.rawExpression, equals('a*x^2 + b'));
      expect(expr.parameters, equals({'a', 'b'}));
    });

    test('creates MathExpression with trig functions', () {
      final expr = MathExpression.fromInput('sin(x)');
      expect(expr.jsExpression, equals('Math.sin(x)'));
      expect(expr.latexDisplay, equals('y = sin(x)'));
    });

    test('handles empty input', () {
      final expr = MathExpression.fromInput('');
      expect(expr.rawExpression, equals(''));
      expect(expr.jsExpression, equals(''));
      expect(expr.latexDisplay, equals(''));
      expect(expr.parameters, isEmpty);
      expect(expr.isValid, isFalse);
    });

    test('reports valid expression', () {
      final expr = MathExpression.fromInput('x^2');
      expect(expr.isValid, isTrue);
    });
  });

  group('MathExpression - generateFunctionBody', () {
    test('generates correct function body for simple power', () {
      final js = MathExpression.toJsExpression('x^2');
      final body = MathExpression.generateFunctionBody(js);
      expect(body, equals('return Math.pow(x,2);'));
    });

    test('generates function body with parameters', () {
      final js = MathExpression.toJsExpression('a*x + b');
      final body = MathExpression.generateFunctionBody(js);
      expect(body, equals('return a*x+b;'));
    });

    test('handles empty expression', () {
      expect(
        MathExpression.generateFunctionBody(''),
        equals('return 0;'),
      );
    });
  });
}

