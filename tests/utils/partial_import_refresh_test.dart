import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/partial_import_refresh.dart';

void main() {
  test('refreshes persisted state after a later item fails', () async {
    var importedCount = 0;
    var refreshCount = 0;

    try {
      for (var item = 0; item < 2; item++) {
        if (item == 1) throw StateError('later item failed');
        importedCount++;
      }
    } catch (_) {
      await refreshAfterPartialImport(importedCount, () async {
        refreshCount++;
      });
    }

    expect(importedCount, 1);
    expect(refreshCount, 1);
  });

  test('does not refresh when no item was imported', () async {
    var refreshCount = 0;

    await refreshAfterPartialImport(0, () async {
      refreshCount++;
    });

    expect(refreshCount, 0);
  });
}
