import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/batch_rename_presets.dart';
import 'package:stroom/utils/batch_rename.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('并发保存不同方案不会互相覆盖，失败后仍可继续保存', () async {
    SharedPreferences.setMockInitialValues({});
    final first = BatchRenamePresets();
    final second = BatchRenamePresets();
    await Future.wait([
      first.save('A', const BatchRenameConfig()),
      second.save('B', const BatchRenameConfig()),
    ]);
    expect((await first.load()).keys, containsAll(['A', 'B']));
    await expectLater(
        first.save('', const BatchRenameConfig()), throwsFormatException);
    await first.delete('A');
    expect((await second.load()).keys, ['B']);
  });
  test('保存、覆盖和删除方案保留规则顺序，坏方案不影响有效方案', () async {
    SharedPreferences.setMockInitialValues({});
    final store = BatchRenamePresets();
    const config = BatchRenameConfig(rules: [
      BatchInsertOp(enabled: true, text: '课件_'),
      BatchNumberOp(enabled: true, digits: 3),
    ]);
    await store.save('课程', config);
    var loaded = await store.load();
    expect(loaded['课程']!.operations.first, isA<BatchInsertOp>());
    await store.save('课程', const BatchRenameConfig());
    expect((await store.load()).length, 1);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(BatchRenamePresets.storageKey)!;
    await prefs
        .setStringList(BatchRenamePresets.storageKey, [...raw, 'broken']);
    loaded = await store.load();
    expect(loaded.keys, ['课程']);
    await store.delete('课程');
    expect(await store.load(), isEmpty);
  });
}
