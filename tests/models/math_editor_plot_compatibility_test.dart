import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_expression.dart';

void main() {
  test(
      'missing Greek forms stay distinct adjustable parameters after rendering',
      () {
    for (final name in [
      'omicron',
      'varpi',
      'varrho',
      'varsigma',
      'varkappa',
      'digamma',
      'Alpha',
      'Beta',
      'Epsilon',
      'Zeta',
      'Eta',
      'Iota',
      'Kappa',
      'Mu',
      'Nu',
      'Omicron',
      'Rho',
      'Tau',
      'Chi',
    ]) {
      final formula =
          MathExpression.fromInput('\\${name}x', parameterValues: {name: 2});
      // A LaTeX control word needs separation from an adjacent letter.
      final separated =
          MathExpression.fromInput('\\$name x', parameterValues: {name: 2});
      expect(separated.isValid, isTrue, reason: name);
      expect(separated.parameters, {name});
      expect(separated.evaluator(3), 6);
      expect(formula.isValid, isFalse, reason: 'invalid joined command: $name');
      final implicit = MathExpression.fromInput('x\\${name}_{2}+y=1',
          parameterValues: {'${name}_2': 2});
      expect(implicit.isValid, isTrue, reason: name);
      expect(implicit.parameters, {'${name}_2'});
      expect(implicit.implicitEvaluator!(3, 1), 6);
    }
  });
  test('postfixes, fences and remainder preserve grouping and boundary values',
      () {
    for (final entry in <String, double>{
      r'\left\lfloor x-0.2\right\rfloor': -1,
      r'\left\lceil x+0.2\right\rceil': 1,
      r'\operatorname{round}\left(x+0.6\right)': 1,
      r'\left(x+3\right)!': 6,
      r'\frac{\left(x+3\right)!}{2}': 3,
      r'\frac{6}{2}!': 6,
      r'\frac{5}{2}\%': 0.025,
      r'\frac{6}{2}^{2}': 9,
      r'\frac{\frac{12}{2}}{2}!': 6,
      r'\left(x+2\right)^{2}!': 24,
      r'2^{3!}': 64,
      r'\left(x+5\right)\bmod2': 1,
      r'\left(x+25\right)\%': 0.25,
      r'100\%\cdot2': 2,
      r'1e-3+2E-3': 0.003,
      'log2e': 1.4426950408889634,
      'log10e': 0.4342944819032518,
      'PI': 3.141592653589793,
      r'\pi2': 6.283185307179586,
      r'2\ln\left(2\right)+1': 2.386294361119891,
      r'2\frac{1}{\sqrt{2}}+1': 2.414213562373095,
      'a2ln2+1': 2,
    }.entries) {
      final formula = MathExpression.fromInput(entry.key);
      expect(formula.isValid, isTrue, reason: entry.key);
      expect(formula.evaluator(0), closeTo(entry.value, 1e-10),
          reason: entry.key);
    }
    expect(MathExpression.fromInput('fact(-1)').samplePoints(), isEmpty);
  });

  test('Greek and subscript parameters work in explicit and implicit formulas',
      () {
    final explicit = MathExpression.fromInput(r'\alpha x+a_{12}',
        parameterValues: {'alpha': 2, 'a_12': 3});
    expect(explicit.isValid, isTrue);
    expect(explicit.parameters, {'alpha', 'a_12'});
    expect(explicit.evaluator(4), 11);
    expect(explicit.withParameters({'alpha': 3, 'a_12': 1}).evaluator(4), 13);
    final implicit = MathExpression.fromInput(r'\alpha x+y=a_{12}');
    expect(implicit.isValid, isTrue);
    expect(implicit.parameters, {'alpha', 'a_12'});
    expect(implicit.implicitEvaluator!(2, 1), 2);
    expect(
        implicit.withParameters({'alpha': 2, 'a_12': 3}).implicitEvaluator!(
            1, 1),
        0);
    for (final entry in {
      r'a_{12}x': 'a_12',
      r'\alpha_{12}x': 'alpha_12',
      r'x\alpha_{12}': 'alpha_12',
      r'xa_{12}': 'a_12',
      r'a_{pi}x': 'a_pi',
      r'\alpha_{ln2}x': 'alpha_ln2',
      r'a_{asin}x': 'a_asin',
      r'a_{1e3}x': 'a_1e3',
      r'\mathrm{foo}_{12}x': 'foo_12',
      r'\mathrm{alpha}_{12}x': 'alpha_12',
      r'\mathrm{pi}_{1}x': 'pi_1',
    }.entries) {
      final adjacent = MathExpression.fromInput(entry.key,
          parameterValues: {entry.value: 2});
      expect(adjacent.isValid, isTrue);
      expect(adjacent.parameters, {entry.value});
      expect(adjacent.evaluator(4), 8, reason: entry.key);
    }
  });

  test('multivalued and unknown function syntax does not produce a fake curve',
      () {
    for (final latex in [r'x\pm1', r'x\mp1', '3!!', 'unknown(x)']) {
      expect(MathExpression.fromInput(latex).isValid, isFalse, reason: latex);
    }
  });
  test('MathLive delimiters, fractions and roots preserve graph meaning', () {
    for (final entry in <String, double>{
      r'f\left(x\right)=\frac{x^{2}+1}{2}': 5,
      r'\sqrt[3]{x}': 3,
      r'\left|x-5\right|': 2,
      r'\log_{2}\left(x+1\right)': 2,
    }.entries) {
      final formula = MathExpression.fromInput(entry.key);
      expect(formula.isValid, isTrue, reason: entry.key);
      final x = entry.key.contains('sqrt') ? 27.0 : 3.0;
      expect(formula.evaluator(x), closeTo(entry.value, 0.0001),
          reason: entry.key);
    }
  });
  test('indexed roots and logs keep nested absolute-value delimiters', () {
    final root = MathExpression.fromInput(r'\sqrt[3]{\left|x\right|}');
    final log =
        MathExpression.fromInput(r'\log_{2}\left(\left|x\right|\right)');
    final variableBase = MathExpression.fromInput(r'\log_{x+1}\left(16\right)');
    expect(root.isValid, isTrue);
    expect(log.isValid, isTrue);
    expect(variableBase.isValid, isTrue);
    expect(root.evaluator(-27), closeTo(3, 0.0001));
    expect(log.evaluator(-8), closeTo(3, 0.0001));
    expect(variableBase.evaluator(3), closeTo(2, 0.0001));
  });
  test('incomplete and display-only math is rejected without fake curves', () {
    for (final source in [
      r'\frac{x}{\placeholder{}}',
      r'\int_{0}^{1}x\,dx',
      r'\begin{pmatrix}1&2\\3&4\end{pmatrix}',
      r'a_{x+1}',
      r'\alpha_{\frac{1}{2}}x',
      r'a_{\pi}x',
      r'a_{(x)}',
      r'a_{}',
      r'a_\pi x',
      r'\alpha_\theta x',
    ]) {
      expect(MathExpression.fromInput(source).isValid, isFalse, reason: source);
    }
  });
}
