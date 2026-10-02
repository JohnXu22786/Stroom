import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_expression.dart';

void main() {
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
    expect(root.isValid, isTrue);
    expect(log.isValid, isTrue);
    expect(root.evaluator(-27), closeTo(3, 0.0001));
    expect(log.evaluator(-8), closeTo(3, 0.0001));
  });
  test('incomplete and display-only math is rejected without fake curves', () {
    for (final source in [
      r'\frac{x}{\placeholder{}}',
      r'\int_{0}^{1}x\,dx',
      r'\begin{pmatrix}1&2\\3&4\end{pmatrix}'
    ]) {
      expect(MathExpression.fromInput(source).isValid, isFalse, reason: source);
    }
  });
}
