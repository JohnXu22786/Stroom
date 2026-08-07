import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/utils/model_order.dart';

void main() {
  group('applySavedOrder', () {
    test('returns names unchanged (in order) when saved order is null/empty',
        () {
      const names = ['a', 'b', 'c'];
      expect(applySavedOrder(names, null), ['a', 'b', 'c']);
      expect(applySavedOrder(names, const []), ['a', 'b', 'c']);
      // Must not mutate the input list
      expect(applySavedOrder(names, null), isNot(same(names)));
    });

    test('brings known names to the front in saved order, keeps the rest '
        'appended in their original order', () {
      const names = ['a', 'b', 'c', 'd'];
      expect(applySavedOrder(names, ['c', 'a']), ['c', 'a', 'b', 'd']);
    });

    test('skips saved names that no longer exist', () {
      const names = ['a', 'b'];
      expect(applySavedOrder(names, ['x', 'b', 'y']), ['b', 'a']);
    });

    test('appends newly added names at the end in their original order', () {
      const names = ['a', 'b', 'new1', 'new2'];
      expect(applySavedOrder(names, ['b', 'a']), ['b', 'a', 'new1', 'new2']);
    });
  });

  group('rebuildGlobalOrder', () {
    test('replaces the provider subsequence in place, keeping other '
        'providers in their exact positions', () {
      const global = ['A1 | A', 'B1 | B', 'A2 | A', 'B2 | B'];
      final result = rebuildGlobalOrder(
        currentGlobal: global,
        inProvider: {'A1 | A', 'A2 | A'},
        newProviderOrder: ['A2 | A', 'A1 | A'],
      );
      expect(result, ['A2 | A', 'B1 | B', 'A1 | A', 'B2 | B']);
    });

    test('a single-provider global list is fully reorderable', () {
      const global = ['A1 | A', 'A2 | A', 'A3 | A'];
      final result = rebuildGlobalOrder(
        currentGlobal: global,
        inProvider: {'A1 | A', 'A2 | A', 'A3 | A'},
        newProviderOrder: ['A3 | A', 'A1 | A', 'A2 | A'],
      );
      expect(result, ['A3 | A', 'A1 | A', 'A2 | A']);
    });

    test('appends provider models missing from the global list at the end',
        () {
      // 该供应商的模型此前从未出现在全局顺序中（如新建的模型），
      // 拖动后应追加到全局顺序末尾，而不是丢弃。
      const global = ['B1 | B'];
      final result = rebuildGlobalOrder(
        currentGlobal: global,
        inProvider: {'A1 | A', 'A2 | A'},
        newProviderOrder: ['A2 | A', 'A1 | A'],
      );
      expect(result, ['B1 | B', 'A2 | A', 'A1 | A']);
    });

    test('does not reorder models of other providers relative to each other',
        () {
      const global = ['B1 | B', 'C1 | C', 'B2 | B', 'C2 | C'];
      final result = rebuildGlobalOrder(
        currentGlobal: global,
        inProvider: {'B1 | B', 'B2 | B'},
        newProviderOrder: ['B2 | B', 'B1 | B'],
      );
      expect(result, ['B2 | B', 'C1 | C', 'B1 | B', 'C2 | C']);
    });
  });
}
