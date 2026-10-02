import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/batch_rename.dart';
import 'package:stroom/utils/sort_config.dart';

import 'batch_rename_test.dart' show bridge, dir, file, plan, bases;

void main() {
  test('规则可重复并按用户给定顺序执行，方案往返不丢配置', () {
    const config = BatchRenameConfig(rules: [
      BatchReplaceOp(enabled: true, find: 'photo', replace: 'image'),
      BatchReplaceOp(enabled: true, find: 'image', replace: 'pic'),
      BatchNumberOp(enabled: true, digits: 2),
      BatchDeleteOp(enabled: false, count: 3),
    ]);
    final restored = BatchRenameConfig.fromJson(config.toJson());
    expect(bases(plan([file('a', 'photo')], config: restored)), ['01_pic']);
    expect(restored.operations.length, 4);
    expect(restored.operations.last.enabled, isFalse);
    expect(() => BatchRenameConfig.fromJson({'version': 999}),
        throwsFormatException);
  });

  test('自动编号消除冲突尊重未选中和未变化项目占用的名称', () {
    final items = [file('a', 'a'), file('b', 'b')];
    final p = computeBatchRenamePlan(
      items: items,
      allFiles: [...items, file('c', 'same'), file('d', 'same (2)')],
      allFolders: {},
      bridge: bridge,
      config: const BatchRenameConfig(
        conflictStrategy: BatchRenameConflictStrategy.numberSuffix,
        template: BatchTemplateOp(enabled: true, pattern: 'same'),
      ),
    );
    expect(bases(p), ['same (3)', 'same (4)']);
    expect(p.canApply, isTrue);
  });

  test('删除和插入按完整可见字符处理组合 emoji 与重音字符', () {
    const names = ['👨‍👩‍👧‍👦照片', '🇨🇳照片', 'e\u0301照片'];
    for (final name in names) {
      final item = file('a', name);
      expect(
        bases(plan([item],
            config: const BatchRenameConfig(
              delete: BatchDeleteOp(enabled: true),
            ))),
        ['照片'],
      );
      expect(
        bases(plan([item],
            config: const BatchRenameConfig(
              insert: BatchInsertOp(
                  enabled: true,
                  position: BatchRenameInsertPos.atIndex,
                  index: 2,
                  text: '-'),
            ))).single,
        name.replaceFirst('照片', '-照片'),
      );
    }
  });

  test('父文件夹改名时仍先腾出子文件夹的当前目标路径', () {
    final p = computeBatchRenamePlan(
      items: [dir('a'), dir('a/x'), dir('a/y')],
      config: const BatchRenameConfig(),
      bridge: bridge,
      allFolders: {'a', 'a/x', 'a/y'},
      allFiles: [],
      overrides: {'folder:a': 'b', 'folder:a/x': 'y', 'folder:a/y': 'z'},
    );
    expect(p.canApply, isTrue);
    expect(p.folderEntries.map((e) => e.id), ['a/y', 'a/x', 'a']);
  });

  test('模板使用原名、目录、日期及补零编号并保留扩展名', () {
    final p = plan([
      file('a', '照片',
          folder: '旅行/海边', format: 'jpg', createdAt: DateTime(2026, 9, 3)),
    ],
        config: const BatchRenameConfig(
          template: BatchTemplateOp(
              enabled: true,
              pattern: '{folder}_{created}_{n}_{name}',
              start: 7,
              digits: 3),
        ));
    expect(p.canApply, isTrue);
    expect(p.results.single.newDisplay, '海边_2026-09-03_007_照片.jpg');
  });

  test('未知模板变量、缺少日期和非法正则会阻止应用且不抛异常', () {
    for (final config in [
      const BatchRenameConfig(
          template: BatchTemplateOp(enabled: true, pattern: '{unknown}')),
      const BatchRenameConfig(
          template: BatchTemplateOp(enabled: true, pattern: '{created}')),
      const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, useRegex: true, find: '[')),
    ]) {
      final p = plan([file('a', 'name')], config: config);
      expect(p.canApply, isFalse);
      expect(p.results.single.error, isNotNull);
      expect(p.fileEntries, isEmpty);
    }
  });

  test('正则支持捕获组、字面美元符号、首次匹配与大小写选项', () {
    final p = plan([file('a', 'IMG12-img34')],
        config: const BatchRenameConfig(
            replace: BatchReplaceOp(
          enabled: true,
          useRegex: true,
          find: r'img(\d+)',
          replace: r'photo_$1_$$',
          firstOnly: true,
        )));
    expect(bases(p), [r'photo_12_$-img34']);
    final literal = plan([file('a', 'a.a.a')],
        config: const BatchRenameConfig(
            replace: BatchReplaceOp(
          enabled: true,
          find: '.',
          replace: r'$1',
          firstOnly: true,
        )));
    expect(bases(literal), [r'a$1a.a']);
  });

  test('不存在的捕获组不能静默删除文件名内容', () {
    final p = plan([file('a', 'abc')],
        config: const BatchRenameConfig(
            replace: BatchReplaceOp(
          enabled: true,
          useRegex: true,
          find: '(a)',
          replace: r'$2',
        )));
    expect(p.canApply, isFalse);
    expect(p.results.single.error, contains('捕获组'));
  });

  test('排除项目保留原名并重新分配连续编号，按目录重启编号', () {
    final items = [
      file('a', 'a', folder: 'x'),
      file('b', 'b', folder: 'x'),
      file('c', 'c', folder: 'x'),
      file('d', 'd', folder: 'y')
    ];
    final p = computeBatchRenamePlan(
      items: items,
      config: const BatchRenameConfig(
          numbering:
              BatchNumberOp(enabled: true, restartPerFolder: true, digits: 2)),
      bridge: bridge,
      allFolders: {'x', 'y'},
      allFiles: items,
      excludedKeys: {'file:b'},
    );
    expect(bases(p), ['01_a', 'b', '02_c', '01_d']);
    expect(p.results[1].included, isFalse);
    expect(p.fileEntries.map((e) => e.id), ['a', 'c', 'd']);
  });

  test('排除项占用的原名仍参与冲突检测，手动改名也需要校验', () {
    final items = [file('a', 'a'), file('b', 'b')];
    BatchRenamePlan compute(String name) => computeBatchRenamePlan(
          items: items,
          config: const BatchRenameConfig(),
          bridge: bridge,
          allFolders: {},
          allFiles: items,
          excludedKeys: {'file:b'},
          overrides: {'file:a': name, 'file:b': 'c'},
        );
    expect(compute('b').canApply, isFalse);
    expect(compute('bad/name').results.first.error, isNotNull);
    expect(bases(compute('c')), ['c', 'b']);
    expect(compute('c').canApply, isTrue);
  });

  test('按时间排序遇到缺失时间或同名时结果稳定', () {
    final items = [
      file('z', 'same', folder: 'z'),
      file('a', 'same', folder: 'a'),
      file('b', 'other', createdAt: DateTime(2026))
    ];
    const config = BatchRenameConfig(
        sortField: SortField.createdAt,
        numbering: BatchNumberOp(enabled: true));
    final first = plan(items, config: config).results.map((r) => r.item.id);
    final second = plan(items.reversed.toList(), config: config)
        .results
        .map((r) => r.item.id);
    expect(first, second);
    expect(first, ['b', 'a', 'z']);
  });

  test('指定位置删字与空白清理不会拆开字符或破坏扩展名', () {
    final p = plan([file('a', '  A👩🏽‍💻B   C  ', format: 'PNG')],
        config: const BatchRenameConfig(
          delete: BatchDeleteOp(
              enabled: true,
              position: BatchRenameDeletePos.atIndex,
              index: 4,
              count: 1),
          cleanup: BatchCleanupOp(enabled: true, collapseWhitespace: true),
        ));
    expect(p.results.single.newDisplay, 'AB C.PNG');
  });

  test('拒绝过大的编号位数与非法位置，避免预览分配巨量内存', () {
    for (final config in [
      const BatchRenameConfig(
          numbering: BatchNumberOp(enabled: true, digits: 999999999)),
      const BatchRenameConfig(
          numbering: BatchNumberOp(enabled: true, digits: 0)),
      const BatchRenameConfig(
          delete: BatchDeleteOp(
              enabled: true, position: BatchRenameDeletePos.atIndex, index: 0)),
    ]) {
      final p = plan([file('a', 'abc')], config: config);
      expect(p.canApply, isFalse);
      expect(p.configError, isNotNull);
    }
  });

  test('文件夹首尾空格和控制字符不能使执行结果偏离预览', () {
    for (final text in [' ', '\n', '\u0000']) {
      final p = plan([dir('a')],
          config: BatchRenameConfig(
            insert: BatchInsertOp(enabled: true, text: text),
          ),
          allFolders: {'a'});
      expect(p.canApply, isFalse);
    }
  });
}
