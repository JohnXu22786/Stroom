import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/batch_rename.dart';
import 'package:stroom/utils/batch_rename_regex.dart';
import 'batch_rename_test.dart' show bridge, file;

void main() {
  test('后台正则与有序规则共用编号、原名模板、排除和冲突校验', () async {
    final worker = BatchRenameRegexWorker();
    addTearDown(worker.dispose);
    final items = [
      file('a', 'photo1'),
      file('b', 'photo2'),
      file('c', 'photo3')
    ];
    final result = await computeBatchRenamePlanAsync(
        items: items,
        allFiles: [...items, file('occupied', 'photo1_01_X')],
        allFolders: {},
        bridge: bridge,
        regexWorker: worker,
        excludedKeys: {'file:b'},
        overrides: {'file:c': 'manual'},
        config: const BatchRenameConfig(rules: [
          BatchReplaceOp(
              enabled: true,
              useRegex: true,
              find: r'photo(\d)',
              replace: r'changed$1'),
          BatchTemplateOp(enabled: true, pattern: '{name}_{n}', digits: 2),
          BatchReplaceOp(
              enabled: true,
              useRegex: true,
              find: r'$',
              replace: '_X',
              firstOnly: true),
        ]));
    expect(result.results.map((r) => r.baseName),
        ['photo1_01_X', 'photo2', 'manual']);
    expect(result.results.first.error, contains('同名'));
    expect(result.canApply, isFalse);

    final replacements = await worker.replace(
        ['a12 a34', '👨‍👩‍👧‍👦'],
        const BatchReplaceOp(
            useRegex: true,
            find: r'a(\d+)',
            replace: r'$1$$',
            firstOnly: true));
    expect(replacements.map((r) => r.name), [r'12$ a34', '👨‍👩‍👧‍👦']);
    final invalid = await worker.replace(['a'],
        const BatchReplaceOp(useRegex: true, find: '(a)', replace: r'$2'));
    expect(invalid.single.error, contains('捕获组'));
  });

  test('灾难性回溯会超时终止，界面线程仍可响应且下次计算可恢复', () async {
    final worker =
        BatchRenameRegexWorker(timeout: const Duration(milliseconds: 150));
    addTearDown(worker.dispose);
    var ticked = false;
    final timer = Timer(const Duration(milliseconds: 10), () => ticked = true);
    addTearDown(timer.cancel);
    await expectLater(
        worker.replace(
            ['a' * 40],
            const BatchReplaceOp(
                useRegex: true, find: r'^(a*|b)*c', replace: 'x')),
        throwsA(isA<TimeoutException>()));
    expect(ticked, isTrue);
    final recovery = BatchRenameRegexWorker();
    addTearDown(recovery.dispose);
    final result = await recovery.replace(['photo'],
        const BatchReplaceOp(useRegex: true, find: '^', replace: 'new_'));
    expect(result.single.name, 'new_photo');
  });

  test('取消待启动或运行中的正则计算，结束 Future 并拒绝继续使用', () async {
    final worker = BatchRenameRegexWorker();
    final result = worker.replace(['a' * 40],
        const BatchReplaceOp(useRegex: true, find: r'^(a*|b)*c', replace: 'x'));
    final cancelled =
        expectLater(result, throwsA(isA<BatchRenameRegexCancelled>()));
    worker.dispose();
    await cancelled;
    await expectLater(worker.replace(['a'], const BatchReplaceOp(find: 'a')),
        throwsA(isA<BatchRenameRegexCancelled>()));
  });
}
