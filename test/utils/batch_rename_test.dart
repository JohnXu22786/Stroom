import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/utils/batch_rename.dart';
import 'package:stroom/utils/folder_path_utils.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/utils/sort_config.dart';

/// Minimal manifest bridge for pure-logic tests (real validators).
final bridge = ManifestBridge(
  getFolderBaseName: FolderPathUtils.getFolderBaseName,
  getParentFolderPath: FolderPathUtils.getParentFolderPath,
  getChildFolderPaths: FolderPathUtils.getChildFolderPaths,
  validateFolderName: FolderPathUtils.validateFolderName,
  validateFileName: FolderPathUtils.validateFileName,
  getAllDescendantFolderPaths: FolderPathUtils.getAllDescendantFolderPaths,
);

/// 文件输入项
BatchRenameItem file(
  String id,
  String name, {
  String format = 'txt',
  String folder = '',
  DateTime? createdAt,
  DateTime? modifiedAt,
  int size = 0,
}) =>
    BatchRenameItem(
      id: id,
      isFolder: false,
      name: name,
      format: format,
      folder: folder,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      size: size,
    );

/// 文件夹输入项（id 即完整路径）
BatchRenameItem dir(String path) => BatchRenameItem(
      id: path,
      isFolder: true,
      name: FolderPathUtils.getFolderBaseName(path),
      folder: FolderPathUtils.getParentFolderPath(path),
    );

/// 便捷调用：以最简单的入参计算计划
BatchRenamePlan plan(
  List<BatchRenameItem> items, {
  BatchRenameConfig config = const BatchRenameConfig(),
  Set<String> allFolders = const {},
  List<BatchRenameItem> allFiles = const [],
}) =>
    computeBatchRenamePlan(
      items: items,
      config: config,
      bridge: bridge,
      allFolders: allFolders,
      allFiles: allFiles,
    );

/// 便捷：返回每个结果的新基础名（按显示顺序）
List<String> bases(BatchRenamePlan p) =>
    p.results.map((r) => r.baseName).toList();

/// 便捷：返回实际发生改名的项的新基础名
List<String> renamedBases(BatchRenamePlan p) =>
    p.results.where((r) => r.isChanged).map((r) => r.baseName).toList();

void main() {
  group('排序先行：编号按排序后的顺序分配', () {
    test('默认按名称升序编号', () {
      final p = plan(
        [
          file('a', 'zulu'),
          file('b', 'alpha'),
          file('c', 'mike'),
        ],
        config: const BatchRenameConfig(
          numbering: BatchNumberOp(enabled: true, start: 1, step: 1),
        ),
      );
      expect(p.results.map((r) => r.item.id).toList(), ['b', 'c', 'a']);
      expect(renamedBases(p), ['1_alpha', '2_mike', '3_zulu']);
    });

    test('按名称降序编号', () {
      final p = plan(
        [file('a', 'zulu'), file('b', 'alpha'), file('c', 'mike')],
        config: const BatchRenameConfig(
          sortOrder: SortOrder.descending,
          numbering: BatchNumberOp(enabled: true),
        ),
      );
      expect(p.results.map((r) => r.item.id).toList(), ['a', 'c', 'b']);
      expect(renamedBases(p), ['1_zulu', '2_mike', '3_alpha']);
    });

    test('按时间升序编号', () {
      final p = plan(
        [
          file('a', 'x', createdAt: DateTime(2024, 1, 3)),
          file('b', 'y', createdAt: DateTime(2024, 1, 1)),
          file('c', 'z', createdAt: DateTime(2024, 1, 2)),
        ],
        config: const BatchRenameConfig(
          sortField: SortField.createdAt,
          numbering: BatchNumberOp(enabled: true),
        ),
      );
      expect(p.results.map((r) => r.item.id).toList(), ['b', 'c', 'a']);
      expect(renamedBases(p), ['1_y', '2_z', '3_x']);
    });

    test('按修改时间升序编号', () {
      final p = plan(
        [
          file('a', 'x',
              createdAt: DateTime(2024, 1, 1),
              modifiedAt: DateTime(2024, 1, 3)),
          file('b', 'y',
              createdAt: DateTime(2024, 1, 2),
              modifiedAt: DateTime(2024, 1, 1)),
          file('c', 'z',
              createdAt: DateTime(2024, 1, 3),
              modifiedAt: DateTime(2024, 1, 2)),
        ],
        config: const BatchRenameConfig(
          sortField: SortField.modifiedAt,
          numbering: BatchNumberOp(enabled: true),
        ),
      );
      expect(p.results.map((r) => r.item.id).toList(), ['b', 'c', 'a']);
      expect(renamedBases(p), ['1_y', '2_z', '3_x']);
    });

    test('按修改时间降序编号', () {
      final p = plan(
        [
          file('a', 'x',
              createdAt: DateTime(2024, 1, 1),
              modifiedAt: DateTime(2024, 1, 3)),
          file('b', 'y',
              createdAt: DateTime(2024, 1, 2),
              modifiedAt: DateTime(2024, 1, 1)),
        ],
        config: const BatchRenameConfig(
          sortField: SortField.modifiedAt,
          sortOrder: SortOrder.descending,
          numbering: BatchNumberOp(enabled: true),
        ),
      );
      expect(p.results.map((r) => r.item.id).toList(), ['a', 'b']);
      expect(renamedBases(p), ['1_x', '2_y']);
    });

    test('按大小降序编号', () {
      final p = plan(
        [file('a', 's', size: 10), file('b', 'l', size: 999)],
        config: const BatchRenameConfig(
          sortField: SortField.size,
          sortOrder: SortOrder.descending,
          numbering: BatchNumberOp(enabled: true),
        ),
      );
      expect(renamedBases(p), ['1_l', '2_s']);
    });

    test('文件夹始终排在文件之前（各自组内按规则排序）', () {
      final p = plan(
        [file('f', 'fileB'), file('f2', 'fileA'), dir('dirC'), dir('dirA')],
        config: const BatchRenameConfig(
          numbering: BatchNumberOp(enabled: true),
        ),
      );
      expect(p.results.map((r) => r.item.id).toList(), [
        'dirA',
        'dirC',
        'f2',
        'f',
      ]);
      expect(renamedBases(p), ['1_dirA', '2_dirC', '3_fileA', '4_fileB']);
    });
  });

  group('编号操作', () {
    test('前缀 + 分隔符 + 起始值 + 步长 + 补零', () {
      final p = plan(
        [file('a', 'x'), file('b', 'y'), file('c', 'z')],
        config: const BatchRenameConfig(
          numbering: BatchNumberOp(
            enabled: true,
            position: BatchRenameNumberPos.prefix,
            start: 10,
            step: 5,
            digits: 3,
            separator: '_',
          ),
        ),
      );
      expect(renamedBases(p), ['010_x', '015_y', '020_z']);
    });

    test('后缀编号', () {
      final p = plan(
        [file('a', 'x'), file('b', 'y')],
        config: const BatchRenameConfig(
          numbering: BatchNumberOp(
            enabled: true,
            position: BatchRenameNumberPos.suffix,
            separator: '-',
            digits: 2,
          ),
        ),
      );
      expect(renamedBases(p), ['x-01', 'y-02']);
    });

    test('编号操作禁用时不改变名称', () {
      final p = plan([file('a', 'x')]);
      expect(renamedBases(p), isEmpty);
      expect(p.results.single.isChanged, isFalse);
    });
  });

  group('替换操作', () {
    test('区分大小写：只替换完全匹配', () {
      final p = plan(
        [file('a', 'Photo PHOTO photo')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(
            enabled: true,
            find: 'Photo',
            replace: 'Pic',
            caseSensitive: true,
          ),
        ),
      );
      expect(renamedBases(p), ['Pic PHOTO photo']);
    });

    test('不区分大小写：替换所有出现', () {
      final p = plan(
        [file('a', 'Photo PHOTO photo')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(
            enabled: true,
            find: 'PHOTO',
            replace: 'pic',
            caseSensitive: false,
          ),
        ),
      );
      expect(renamedBases(p), ['pic pic pic']);
    });

    test('查找内容为空时替换无效', () {
      final p = plan(
        [file('a', 'hello')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: '', replace: 'x'),
        ),
      );
      expect(p.results.single.isChanged, isFalse);
    });

    test('替换为空的场景（删除文字）', () {
      final p = plan(
        [file('a', '2024_report')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: '2024_', replace: ''),
        ),
      );
      expect(renamedBases(p), ['report']);
    });
  });

  group('插入操作', () {
    test('开头 / 结尾 / 指定位置（1 基）', () {
      final start = plan(
        [file('a', 'xy')],
        config: const BatchRenameConfig(
          insert: BatchInsertOp(
            enabled: true,
            position: BatchRenameInsertPos.start,
            text: 'pre_',
          ),
        ),
      );
      expect(renamedBases(start), ['pre_xy']);

      final end = plan(
        [file('a', 'xy')],
        config: const BatchRenameConfig(
          insert: BatchInsertOp(
            enabled: true,
            position: BatchRenameInsertPos.end,
            text: '_post',
          ),
        ),
      );
      expect(renamedBases(end), ['xy_post']);

      final atIndex = plan(
        [file('a', 'abcd')],
        config: const BatchRenameConfig(
          insert: BatchInsertOp(
            enabled: true,
            position: BatchRenameInsertPos.atIndex,
            index: 3,
            text: 'X',
          ),
        ),
      );
      expect(renamedBases(atIndex), ['abXcd']);
    });

    test('指定位置越界时收拢到边界', () {
      final p = plan(
        [file('a', 'abc')],
        config: const BatchRenameConfig(
          insert: BatchInsertOp(
            enabled: true,
            position: BatchRenameInsertPos.atIndex,
            index: 99,
            text: '!',
          ),
        ),
      );
      expect(renamedBases(p), ['abc!']);
    });

    test('文本为空时插入无效', () {
      final p = plan(
        [file('a', 'abc')],
        config: const BatchRenameConfig(
          insert: BatchInsertOp(enabled: true, text: ''),
        ),
      );
      expect(p.results.single.isChanged, isFalse);
    });

    test('指定位置插入按字符计数（emoji 代理对不被拆散）', () {
      final p = plan(
        [file('a', '📷xy')],
        config: const BatchRenameConfig(
          insert: BatchInsertOp(
            enabled: true,
            position: BatchRenameInsertPos.atIndex,
            index: 2,
            text: 'X',
          ),
        ),
      );
      expect(renamedBases(p), ['📷Xxy']);
    });
  });

  group('删除字符操作', () {
    test('从开头删除 / 从结尾删除', () {
      final fromStart = plan(
        [file('a', '2024x')],
        config: const BatchRenameConfig(
          delete: BatchDeleteOp(
            enabled: true,
            position: BatchRenameDeletePos.start,
            count: 4,
          ),
        ),
      );
      expect(renamedBases(fromStart), ['x']);

      final fromEnd = plan(
        [file('a', 'x2024')],
        config: const BatchRenameConfig(
          delete: BatchDeleteOp(
            enabled: true,
            position: BatchRenameDeletePos.end,
            count: 4,
          ),
        ),
      );
      expect(renamedBases(fromEnd), ['x']);
    });

    test('删除数量不小于长度时结果为空（随后被校验拒绝）', () {
      final p = plan(
        [file('a', 'ab')],
        config: const BatchRenameConfig(
          delete: BatchDeleteOp(enabled: true, count: 5),
        ),
      );
      expect(p.results.single.baseName, isEmpty);
      expect(p.results.single.error, isNotNull);
      expect(p.canApply, isFalse);
    });

    test('删除数量为 0 时无效', () {
      final p = plan(
        [file('a', 'abc')],
        config: const BatchRenameConfig(
          delete: BatchDeleteOp(enabled: true, count: 0),
        ),
      );
      expect(p.results.single.isChanged, isFalse);
    });

    test('删除字符按字符计数（emoji 代理对不被拆散）', () {
      final p = plan(
        [file('a', '📷photo')],
        config: const BatchRenameConfig(
          delete: BatchDeleteOp(enabled: true, count: 1),
        ),
      );
      expect(renamedBases(p), ['photo']);
    });
  });

  group('大小写操作', () {
    test('全大写 / 全小写 / 首字母大写', () {
      final upper = plan(
        [file('a', 'my File')],
        config: const BatchRenameConfig(
          caseOp: BatchCaseOp(enabled: true, mode: BatchRenameCaseMode.upper),
        ),
      );
      expect(renamedBases(upper), ['MY FILE']);

      final lower = plan(
        [file('a', 'MY FILE')],
        config: const BatchRenameConfig(
          caseOp: BatchCaseOp(enabled: true, mode: BatchRenameCaseMode.lower),
        ),
      );
      expect(renamedBases(lower), ['my file']);

      final first = plan(
        [file('a', 'hello world')],
        config: const BatchRenameConfig(
          caseOp: BatchCaseOp(
            enabled: true,
            mode: BatchRenameCaseMode.firstUpper,
          ),
        ),
      );
      expect(renamedBases(first), ['Hello world']);
    });
  });

  group('操作链：按 编号→替换→插入→删除→大小写 顺序应用', () {
    test('先编号再替换', () {
      final p = plan(
        [file('a', 'report')],
        config: const BatchRenameConfig(
          numbering: BatchNumberOp(enabled: true, separator: '_'),
          replace: BatchReplaceOp(
            enabled: true,
            find: '1_report',
            replace: 'one',
          ),
        ),
      );
      expect(renamedBases(p), ['one']);
    });

    test('编号后删除开头序号再大小写', () {
      final p = plan(
        [file('a', 'report')],
        config: const BatchRenameConfig(
          numbering: BatchNumberOp(enabled: true, separator: '_'),
          delete: BatchDeleteOp(enabled: true, count: 2),
          caseOp: BatchCaseOp(enabled: true, mode: BatchRenameCaseMode.upper),
        ),
      );
      // 编号 → 1_report → 删除前 2 字符 → report → 全大写
      expect(renamedBases(p), ['REPORT']);
    });
  });

  group('显示名', () {
    test('文件显示名包含扩展名，文件夹不含', () {
      final p = plan([file('a', 'photo', format: 'jpg'), dir('folder')]);
      // 排序：文件夹在前，文件在后
      expect(p.results[0].oldDisplay, 'folder');
      expect(p.results[1].oldDisplay, 'photo.jpg');
      expect(p.results[0].newDisplay, 'folder');
      expect(p.results[1].newDisplay, 'photo.jpg');
    });
  });

  group('冲突检测：文件', () {
    test('与未选中的同文件夹同名文件冲突', () {
      final p = plan(
        [file('a', 'x')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'x', replace: 'new'),
        ),
        allFiles: [file('other', 'new', format: 'txt', folder: '')],
      );
      expect(p.results.single.error, isNotNull);
      expect(p.canApply, isFalse);
    });

    test('批内两个文件重名到同一名称', () {
      final p = plan(
        [file('a', 'x'), file('b', 'y')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'y', replace: 'x'),
        ),
      );
      // a('x') 不变；b('y')→'x' 与 a 冲突
      final errors = p.results.where((r) => r.error != null).toList();
      expect(errors, hasLength(1));
      expect(p.canApply, isFalse);
    });

    test('不同文件夹允许同名', () {
      final p = plan(
        [
          file('a', 'same', folder: 'dir1'),
          file('b', 'same', folder: 'dir2'),
        ],
        config: const BatchRenameConfig(
          numbering: BatchNumberOp(enabled: true, separator: '_'),
        ),
      );
      expect(p.canApply, isTrue);
    });

    test('改名项让出原名后可被另一选中项占用（最终状态语义，不误报）', () {
      // A('ab') → 'abb'（让出 'ab'）；B('a') → 'ab'（占用 'ab'）。
      // 最终状态无冲突：A 不再占用 'ab'。
      final p = plan(
        [file('a', 'ab'), file('b', 'a')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'a', replace: 'ab'),
        ),
      );
      expect(p.results.where((r) => r.error != null), isEmpty);
      expect(p.canApply, isTrue);
    });
  });

  group('冲突检测：文件夹', () {
    test('新路径与未选中文件夹重复', () {
      final p = plan(
        [dir('a')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'a', replace: 'x'),
        ),
        allFolders: {'a', 'x'},
      );
      expect(p.results.single.error, isNotNull);
      expect(p.canApply, isFalse);
    });

    test('新路径与未选中子文件夹存在包含关系', () {
      final p = plan(
        [dir('a')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'a', replace: 'x'),
        ),
        allFolders: {'a', 'x/b'},
      );
      expect(p.results.single.error, isNotNull);
      expect(p.canApply, isFalse);
    });

    test('批内两个文件夹重名到同一路径', () {
      // a → b，而 b 未改名（保持 'b'）：两者最终都叫 b → 冲突
      final p = plan(
        [dir('a'), dir('b')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'a', replace: 'b'),
        ),
        allFolders: {'a', 'b'},
      );
      expect(p.results.where((r) => r.error != null), hasLength(1));
      expect(p.canApply, isFalse);
    });

    test('父文件夹与其子文件夹同时改名可应用，且子文件夹先执行', () {
      final p = plan(
        [dir('a'), dir('a/b')],
        config: const BatchRenameConfig(
          numbering: BatchNumberOp(enabled: true, separator: '_'),
        ),
        allFolders: {'a', 'a/b'},
      );
      expect(p.canApply, isTrue);
      // 应用顺序：深的先（a/b 的改名先于 a，避免 a 改名后找不到 a/b）
      expect(p.folderEntries.map((e) => e.id).toList(), ['a/b', 'a']);
      expect(p.folderEntries.map((e) => e.newBaseName).toList(), [
        '2_b',
        '1_a',
      ]);
    });

    test('文件夹名称互换（a→x, x→a）判为冲突', () {
      // replace a→x：a 变成 'x'，与未改名的文件夹 x 撞名
      final p = plan(
        [dir('a'), dir('x')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'a', replace: 'x'),
        ),
        allFolders: {'a', 'x'},
      );
      expect(p.canApply, isFalse);
    });

    test('改名项让出文件夹名后可被另一选中项占用，且应用顺序安全', () {
      // 编号：'2_x' → '1_2_x'（让出 '2_x'）；'x' → '2_x'（占用 '2_x'）。
      // 必须先执行 '2_x' 的改名，再执行 'x' 的改名。
      final p = plan(
        [dir('2_x'), dir('x')],
        config: const BatchRenameConfig(
          numbering: BatchNumberOp(enabled: true, separator: '_'),
        ),
        allFolders: {'2_x', 'x'},
      );
      expect(p.canApply, isTrue);
      expect(p.folderEntries.map((e) => e.id).toList(), ['2_x', 'x']);
    });

    test('未改名文件夹随改名祖先级联移动时不误报冲突', () {
      // a→x、x→xx：x 的子文件夹 x/b 随 x 级联到 xx/b，
      // 因此 a 改名为 x 不会与任何现存路径冲突。
      final p = plan(
        [dir('a'), dir('x')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'a', replace: ''),
          insert: BatchInsertOp(
            enabled: true,
            position: BatchRenameInsertPos.start,
            text: 'x',
          ),
        ),
        allFolders: {'a', 'x', 'x/b'},
      );
      expect(p.canApply, isTrue);
      // 先 x→xx 腾出 'x'，再 a→x
      expect(p.folderEntries.map((e) => e.id).toList(), ['x', 'a']);
    });

    test('未改名文件夹级联后撞上改名项目标路径时判定冲突', () {
      // a→a1、a/x→b（最终 a1/b）；未选中的 a/b 随 a 级联到 a1/b → 冲突
      final p = plan(
        [dir('a'), dir('a/x')],
        config: const BatchRenameConfig(
          numbering: BatchNumberOp(
            enabled: true,
            position: BatchRenameNumberPos.suffix,
            separator: '',
          ),
          replace: BatchReplaceOp(enabled: true, find: 'x2', replace: 'b'),
        ),
        allFolders: {'a', 'a/x', 'a/b'},
      );
      expect(p.results.where((r) => r.error != null).map((r) => r.item.id),
          ['a/x']);
      expect(p.canApply, isFalse);
    });
  });

  group('名称校验', () {
    test('非法文件名被拒绝', () {
      final p = plan(
        [file('a', 'ok')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'ok', replace: 'a/b'),
        ),
      );
      expect(p.results.single.error, isNotNull);
      expect(p.canApply, isFalse);
    });

    test('非法文件夹名被拒绝', () {
      final p = plan(
        [dir('a')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'a', replace: 'b<c'),
        ),
      );
      expect(p.results.single.error, isNotNull);
      expect(p.canApply, isFalse);
    });
  });

  group('计划统计', () {
    test('changeCount / fileEntries 只包含实际改名的项', () {
      final p = plan(
        [file('a', 'x'), file('b', 'keep')],
        config: const BatchRenameConfig(
          replace: BatchReplaceOp(enabled: true, find: 'x', replace: 'z'),
        ),
      );
      expect(p.changeCount, 1);
      expect(p.fileEntries, hasLength(1));
      expect(p.fileEntries.single.id, 'a');
      expect(p.fileEntries.single.newBaseName, 'z');
      expect(p.folderEntries, isEmpty);
    });

    test('hasActiveOps：无有效操作时为 false', () {
      const cfg = BatchRenameConfig();
      expect(cfg.hasActiveOps, isFalse);
      const cfg2 = BatchRenameConfig(
        replace: BatchReplaceOp(enabled: true, find: '', replace: 'x'),
      );
      expect(cfg2.hasActiveOps, isFalse);
    });
  });
}
