import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/partial_import_refresh.dart';

void main() {
  test('refreshes persisted state when a later item fails', () async {
    final storedItems = <String>[];
    var providerItems = <String>[];

    await expectLater(
      importBatchWithPartialRefresh(
        items: ['first', 'second'],
        importItem: (item) async {
          if (item == 'second') throw StateError('later item failed');
          storedItems.add(item);
          return true;
        },
        refresh: () async {
          providerItems = List.of(storedItems);
        },
      ),
      throwsA(isA<StateError>()),
    );

    expect(providerItems, ['first']);
  });

  test('does not refresh when no item was imported', () async {
    var refreshCount = 0;

    await importBatchWithPartialRefresh<String>(
      items: const [],
      importItem: (_) async => true,
      refresh: () async => refreshCount++,
    );

    expect(refreshCount, 0);
  });
}
