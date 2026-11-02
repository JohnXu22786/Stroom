import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ocr_batch_execution.dart';

void main() {
  group('ocrRequestSizeBudgetMib', () {
    test('distinguishes a one-byte overage near 1 MiB', () {
      const budgetBytes = 1024 * 1024;

      expect(
        ocrRequestSizeBudgetOverageMib(budgetBytes + 1, budgetBytes),
        '1.000001',
      );
      expect(ocrRequestSizeBudgetMib(20 * 1024 * 1024), '20.00');
      expect(ocrRequestSizeBudgetMib(3146), '0.00300026');
    });
  });
}
