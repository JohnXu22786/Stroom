import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/folder_path_utils.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/utils/sort_config.dart';
import 'package:stroom/widgets/file_manager_view.dart';

/// Minimal test record for widget tests
class _TestFileRecord
    with
        Hashable,
        Storable,
        Renamable<_TestFileRecord>,
        Movable<_TestFileRecord>
    implements FileRecord {
  @override
  final String id;
  @override
  final String name;
  @override
  final String hash;
  @override
  final String format;
  @override
  final DateTime createdAt;
  @override
  final DateTime modifiedAt;
  @override
  final int size;
  @override
  final String folder;

  _TestFileRecord({
    String? id,
    this.name = 'test',
    this.hash = 'test_hash',
    this.format = 'mp4',
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.size = 1024,
    this.folder = '',
  })  : id = id ?? 'file_${DateTime.now().millisecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? createdAt ?? DateTime.now();

  @override
  String get storagePath => '$hash.$format';

  @override
  _TestFileRecord copyWithName(String name) => _TestFileRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        size: size,
        folder: folder,
      );

  @override
  _TestFileRecord copyWithFolder(String folder) => _TestFileRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        size: size,
        folder: folder,
      );
}

Widget _buildTestApp(Widget body, {Size screenSize = const Size(800, 600)}) {
  return MediaQuery(
    data: MediaQueryData(size: screenSize),
    child: MaterialApp(
      home: Scaffold(body: body),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

final sortConfig = SortConfig(
  field: SortField.name,
  order: SortOrder.ascending,
);

ManifestBridge testBridge() => ManifestBridge(
      getFolderBaseName: FolderPathUtils.getFolderBaseName,
      getParentFolderPath: FolderPathUtils.getParentFolderPath,
      getChildFolderPaths: FolderPathUtils.getChildFolderPaths,
      validateFolderName: FolderPathUtils.validateFolderName,
      validateFileName: FolderPathUtils.validateFileName,
      getAllDescendantFolderPaths: FolderPathUtils.getAllDescendantFolderPaths,
    );

FileManagerView<_TestFileRecord> _buildFileManagerView({
  required List<_TestFileRecord> records,
  Set<String> folders = const {},
  Future<void> Function(String id, String newName)? onRenameFile,
  Future<void> Function(String oldName, String newName)? onRenameFolder,
}) {
  final config = FileManagerConfig<_TestFileRecord>(
    title: 'Test',
    fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
    onFileTap: (_) {},
  );
  return FileManagerView<_TestFileRecord>(
    sortedRecords: records,
    folders: folders,
    sortConfig: sortConfig,
    config: config,
    onRefresh: () async {},
    onRenameFile: onRenameFile ?? (_, __) async {},
    onMoveFile: (_, __) async {},
    onCopyFile: (_, __) async {},
    onDeleteFile: (_) async {},
    onDeleteFiles: (_) async {},
    onDeleteFolders: (_) async {},
    onMoveFiles: (_, __) async {},
    onMoveFolders: (_, __) async {},
    onExportFile: (_) async {},
    onRenameFolder: onRenameFolder ?? (_, __) async {},
    onMoveFolder: (_, __) async {},
    onCopyFolder: (_, __) async {},
    onDeleteFolder: (_) async {},
    onCreateFolder: (_) async {},
    onToggleSort: (_) {},
    manifestBridge: testBridge(),
  );
}

/// 进入选择模式并选中全部给定文件
Future<void> _selectFiles(WidgetTester tester, List<String> ids) async {
  for (final id in ids) {
    final item = find.byKey(Key('fm_file_$id'));
    if (find.byKey(const Key('fm_selection_copy_btn')).evaluate().isEmpty) {
      await tester.longPress(item);
    } else {
      await tester.tap(item);
    }
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('批量重命名：编号 → 预览 → 应用调用 onRenameFile', (tester) async {
    final renames = <(String, String)>[];
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(
              id: 'file_1',
              name: 'vacation',
              hash: 'h1',
              format: 'mp4',
            ),
            _TestFileRecord(
              id: 'file_2',
              name: 'party',
              hash: 'h2',
              format: 'mov',
            ),
          ],
          onRenameFile: (id, newName) async => renames.add((id, newName)),
        ),
      ),
    );

    await _selectFiles(tester, ['file_1', 'file_2']);

    // 打开批量重命名面板
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('batch_rename_dialog')), findsOneWidget);
    expect(find.text('批量重命名（2 项）'), findsOneWidget);

    // 未启用任何操作时，应用按钮禁用
    final applyBtn = find.byKey(const Key('batch_rename_apply_btn'));
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNull);

    // 启用编号
    await tester.tap(find.byKey(const Key('batch_num_switch')));
    await tester.pumpAndSettle();

    // 按名称升序：party → 1_party.mov，vacation → 2_vacation.mp4
    expect(find.text('1_party.mov'), findsOneWidget);
    expect(find.text('2_vacation.mp4'), findsOneWidget);

    // 应用
    await tester.tap(applyBtn);
    await tester.pumpAndSettle();

    expect(renames, [
      ('file_2', '1_party'),
      ('file_1', '2_vacation'),
    ]);
    // 面板已关闭
    expect(find.byKey(const Key('batch_rename_dialog')), findsNothing);
  });

  testWidgets('切换为降序后编号顺序反转', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(
              id: 'file_1',
              name: 'alpha',
              hash: 'h1',
              format: 'mp4',
            ),
            _TestFileRecord(
              id: 'file_2',
              name: 'beta',
              hash: 'h2',
              format: 'mov',
            ),
          ],
        ),
      ),
    );

    await _selectFiles(tester, ['file_1', 'file_2']);
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('batch_num_switch')));
    await tester.pumpAndSettle();
    // 升序：alpha → 1，beta → 2
    expect(find.text('1_alpha.mp4'), findsOneWidget);
    expect(find.text('2_beta.mov'), findsOneWidget);

    // 切换为降序
    await tester.tap(find.text('降序'));
    await tester.pumpAndSettle();
    expect(find.text('1_beta.mov'), findsOneWidget);
    expect(find.text('2_alpha.mp4'), findsOneWidget);
  });

  testWidgets('可按修改时间排序编号（四类排序字段均提供）', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(
              id: 'file_1',
              name: 'old',
              hash: 'h1',
              format: 'txt',
              createdAt: DateTime(2024, 1, 1),
              modifiedAt: DateTime(2024, 1, 3),
            ),
            _TestFileRecord(
              id: 'file_2',
              name: 'recent',
              hash: 'h2',
              format: 'txt',
              createdAt: DateTime(2024, 1, 2),
              modifiedAt: DateTime(2024, 1, 1),
            ),
          ],
        ),
      ),
    );

    await _selectFiles(tester, ['file_1', 'file_2']);
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();

    // 四个排序字段都在面板中
    expect(find.text('名称'), findsOneWidget);
    expect(find.text('创建时间'), findsOneWidget);
    expect(find.text('修改时间'), findsOneWidget);
    expect(find.text('大小'), findsOneWidget);

    // 切到「修改时间」升序：recent（1/1）→ 1，old（1/3）→ 2
    await tester.tap(find.text('修改时间'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('batch_num_switch')));
    await tester.pumpAndSettle();
    expect(find.text('1_recent.txt'), findsOneWidget);
    expect(find.text('2_old.txt'), findsOneWidget);
  });

  testWidgets('冲突时预览报错且应用按钮禁用', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(id: 'file_1', name: 'photo', hash: 'h1'),
            _TestFileRecord(id: 'file_2', name: 'pic', hash: 'h2'),
          ],
        ),
      ),
    );

    await _selectFiles(tester, ['file_1', 'file_2']);
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();

    // 启用替换：photo → pic（与未改名的 pic 冲突）
    await tester.tap(find.byKey(const Key('batch_replace_switch')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('batch_replace_find_field')),
      'photo',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('batch_replace_to_field')),
      'pic',
    );
    await tester.pumpAndSettle();

    // 预览中 photo 项出现冲突
    expect(find.text('同一文件夹内存在同名文件'), findsOneWidget);
    expect(find.text('存在冲突或非法名称，无法应用。请调整规则。'), findsOneWidget);
    final applyBtn = find.byKey(const Key('batch_rename_apply_btn'));
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNull);
  });

  testWidgets('文件夹与文件混合选择时可对文件夹编号并应用', (tester) async {
    final folderRenames = <(String, String)>[];
    final fileRenames = <(String, String)>[];
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(
              id: 'file_1',
              name: 'notes',
              hash: 'h1',
              format: 'txt',
            ),
          ],
          folders: {'MyFolder'},
          onRenameFolder: (oldName, newName) async =>
              folderRenames.add((oldName, newName)),
          onRenameFile: (id, newName) async => fileRenames.add((id, newName)),
        ),
      ),
    );

    // 选中文件夹与文件：长按文件夹进入选择模式，再点选文件
    await tester.longPress(find.byKey(const Key('fm_folder_MyFolder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fm_file_file_1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();

    // 文件夹在前：MyFolder → 1_MyFolder，notes → 2_notes.txt
    await tester.tap(find.byKey(const Key('batch_num_switch')));
    await tester.pumpAndSettle();
    expect(find.text('1_MyFolder'), findsOneWidget);
    expect(find.text('2_notes.txt'), findsOneWidget);

    await tester.tap(find.byKey(const Key('batch_rename_apply_btn')));
    await tester.pumpAndSettle();

    // 文件夹先执行，再执行文件
    expect(folderRenames, [('MyFolder', '1_MyFolder')]);
    expect(fileRenames, [('file_1', '2_notes')]);
  });

  testWidgets('取消或关闭面板不产生任何重命名，选择模式保持', (tester) async {
    final renames = <(String, String)>[];
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(id: 'file_1', name: 'alpha', hash: 'h1'),
          ],
          onRenameFile: (id, newName) async => renames.add((id, newName)),
        ),
      ),
    );
    await _selectFiles(tester, ['file_1']);
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('batch_rename_dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('batch_rename_cancel_btn')));
    await tester.pumpAndSettle();
    expect(renames, isEmpty);
    // 选择模式仍在（底部操作栏可见）
    expect(find.byKey(const Key('fm_selection_rename_btn')), findsOneWidget);
  });

  testWidgets('重命名回调失败时提示成功/失败数量', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(id: 'file_1', name: 'alpha', hash: 'h1'),
            _TestFileRecord(id: 'file_2', name: 'beta', hash: 'h2'),
          ],
          onRenameFile: (id, newName) async {
            if (id == 'file_2') throw Exception('disk full');
          },
        ),
      ),
    );
    await _selectFiles(tester, ['file_1', 'file_2']);
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('batch_num_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('batch_rename_apply_btn')));
    await tester.pumpAndSettle();

    expect(find.text('重命名完成：成功 1 项，失败 1 项'), findsOneWidget);
  });

  testWidgets('窄屏（320dp）下打开面板并启用编号不溢出', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(id: 'file_1', name: 'alpha', hash: 'h1'),
            _TestFileRecord(id: 'file_2', name: 'beta', hash: 'h2'),
          ],
        ),
        screenSize: const Size(320, 480),
      ),
    );
    await _selectFiles(tester, ['file_1', 'file_2']);
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('batch_rename_dialog')), findsOneWidget);

    // 启用编号与删除字符，预览正常（RenderFlex 溢出会令测试失败）。
    // 删除默认数量 1 → 编号后的 '1_alpha' 去掉首位 '1'。
    await tester.tap(find.byKey(const Key('batch_num_switch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('batch_delete_switch')));
    await tester.tap(find.byKey(const Key('batch_delete_switch')));
    await tester.pumpAndSettle();
    expect(find.text('_alpha.mp4'), findsOneWidget);

    // 数量输入 0 → 校验提示在窄屏下正常渲染（不溢出）
    await tester.enterText(
      find.byKey(const Key('batch_delete_count_field')),
      '0',
    );
    await tester.pumpAndSettle();
    expect(find.text('请输入大于 0 的数字'), findsOneWidget);
  });

  testWidgets('清空删除数量字段：提示不能为空且不强制回填，应用按钮禁用；输入新数字后恢复', (tester) async {
    final renames = <(String, String)>[];
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(id: 'file_1', name: 'abc', hash: 'h1'),
          ],
          onRenameFile: (id, newName) async => renames.add((id, newName)),
        ),
      ),
    );
    await _selectFiles(tester, ['file_1']);
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();

    // 操作顺序提示与删除区块说明文案
    expect(
      find.text('操作顺序：编号 → 替换 → 删除字符 → 插入 → 大小写'),
      findsOneWidget,
    );

    // 启用删除字符（默认数量 1）→ 有改动 → 应用按钮可用
    await tester.tap(find.byKey(const Key('batch_delete_switch')));
    await tester.pumpAndSettle();
    expect(find.text('删除后若名称为空则无法应用；可配合「插入」补充文本'), findsOneWidget);
    final applyBtn = find.byKey(const Key('batch_rename_apply_btn'));
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNotNull);

    // 清空数量字段：显示「不能为空」提示，字段内容不被强制回填，应用按钮禁用
    await tester.enterText(
      find.byKey(const Key('batch_delete_count_field')),
      '',
    );
    await tester.pumpAndSettle();
    expect(find.text('不能为空'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('batch_delete_count_field')),
    );
    expect(field.controller!.text, isEmpty);
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNull);

    // 非数字输入（如粘贴）：提示「请输入数字」，配置保持上一次有效值
    await tester.enterText(
      find.byKey(const Key('batch_delete_count_field')),
      'abc',
    );
    await tester.pumpAndSettle();
    expect(find.text('请输入数字'), findsOneWidget);
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNull);
    expect(find.text('bc.mp4'), findsOneWidget); // 预览仍按上次有效数量 1

    // 输入新数字（2）→ 提示消失，应用按钮恢复可用，
    // 且预览按新数量计算：abc 删除前 2 字符 → c.mp4
    await tester.enterText(
      find.byKey(const Key('batch_delete_count_field')),
      '2',
    );
    await tester.pumpAndSettle();
    expect(find.text('不能为空'), findsNothing);
    expect(find.text('请输入数字'), findsNothing);
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNotNull);
    expect(find.text('c.mp4'), findsOneWidget);

    // 应用后按新数量执行
    await tester.tap(applyBtn);
    await tester.pumpAndSettle();
    expect(renames, [('file_1', 'c')]);
    expect(find.byKey(const Key('batch_rename_dialog')), findsNothing);
  });

  testWidgets('清空数量字段后关掉再开启删除区块：提示重新出现且应用保持禁用', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(id: 'file_1', name: 'abc', hash: 'h1'),
          ],
        ),
      ),
    );
    await _selectFiles(tester, ['file_1']);
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();

    final applyBtn = find.byKey(const Key('batch_rename_apply_btn'));
    final countField = find.byKey(const Key('batch_delete_count_field'));

    // 启用删除并清空数量 → 提示出现、应用禁用
    await tester.tap(find.byKey(const Key('batch_delete_switch')));
    await tester.pumpAndSettle();
    await tester.enterText(countField, '');
    await tester.pumpAndSettle();
    expect(find.text('不能为空'), findsOneWidget);
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNull);

    // 关闭区块（字段隐藏、提示消失），再重新开启：
    // 字段仍为空 → 提示必须重新出现，应用仍禁用（不得按过期配置放行）
    await tester.tap(find.byKey(const Key('batch_delete_switch')));
    await tester.pumpAndSettle();
    expect(find.text('不能为空'), findsNothing);
    await tester.tap(find.byKey(const Key('batch_delete_switch')));
    await tester.pumpAndSettle();
    expect(find.text('不能为空'), findsOneWidget);
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNull);
  });

  testWidgets('插入位置从「指定位置」切走后，残留的无效位置字段不阻塞应用', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(id: 'file_1', name: 'abc', hash: 'h1'),
          ],
        ),
      ),
    );
    await _selectFiles(tester, ['file_1']);
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();

    final applyBtn = find.byKey(const Key('batch_rename_apply_btn'));

    // 启用插入，切到「指定位置」，输入文本 → 有改动 → 应用可用
    await tester.ensureVisible(find.byKey(const Key('batch_insert_switch')));
    await tester.tap(find.byKey(const Key('batch_insert_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('指定位置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('batch_insert_text_field')),
      'X',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNotNull);

    // 清空位置字段 → 提示出现、应用禁用
    await tester.enterText(
      find.byKey(const Key('batch_insert_index_field')),
      '',
    );
    await tester.pumpAndSettle();
    expect(find.text('不能为空'), findsOneWidget);
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNull);

    // 切回「开头」→ 位置字段隐藏，无效输入不再阻塞应用
    await tester.tap(find.text('开头'));
    await tester.pumpAndSettle();
    expect(find.text('不能为空'), findsNothing);
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNotNull);
  });

  testWidgets('删除数量输入 0：提示大于 0 且应用禁用', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        _buildFileManagerView(
          records: [
            _TestFileRecord(id: 'file_1', name: 'abc', hash: 'h1'),
          ],
        ),
      ),
    );
    await _selectFiles(tester, ['file_1']);
    await tester.tap(find.byKey(const Key('fm_selection_rename_btn')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('batch_delete_switch')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('batch_delete_count_field')),
      '0',
    );
    await tester.pumpAndSettle();
    expect(find.text('请输入大于 0 的数字'), findsOneWidget);
    final applyBtn = find.byKey(const Key('batch_rename_apply_btn'));
    expect(tester.widget<FilledButton>(applyBtn).onPressed, isNull);
    // ≤0 不提交配置：预览仍按上次有效数量 1 计算（abc → bc.mp4）
    expect(find.text('bc.mp4'), findsOneWidget);
  });
}
