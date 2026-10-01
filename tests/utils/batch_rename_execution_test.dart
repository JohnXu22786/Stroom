import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/batch_rename.dart';
import 'package:stroom/utils/batch_rename_execution.dart';
import 'batch_rename_test.dart' show bridge, dir, file;

class _Disk {
  List<BatchRenameItem> files;
  Set<String> folders;
  final calls = <String>[];
  String? failId;
  _Disk(this.files, this.folders);
  Future<BatchRenameSnapshot> read() async =>
      BatchRenameSnapshot(files, folders);
  Future<void> renameFile(String id, String name) async {
    calls.add(id);
    if (id == failId) throw StateError('disk full');
    files = files
        .map((f) => file(f.id, f.id == id ? name : f.name,
            folder: f.folder, format: f.format))
        .toList();
  }

  Future<void> renameFolder(String path, String name) async {
    calls.add(path);
    if (path == failId) throw StateError('disk full');
    final parent = bridge.getParentFolderPath(path);
    final target = parent.isEmpty ? name : '$parent/$name';
    if (folders.contains(target)) throw StateError('occupied');
    String move(String p) => p == path || p.startsWith('$path/')
        ? '$target${p.substring(path.length)}'
        : p;
    folders = folders.map(move).toSet();
    files = files
        .map(
            (f) => file(f.id, f.name, folder: move(f.folder), format: f.format))
        .toList();
  }

  Future<BatchRenameExecution> run(BatchRenamePlan plan,
          {bool Function()? cancel}) =>
      executeBatchRename(
          plan: plan,
          bridge: bridge,
          readSnapshot: read,
          renameFile: renameFile,
          renameFolder: renameFolder,
          shouldCancel: cancel);
  Future<BatchRenameExecution> undo(BatchRenameExecution run) =>
      undoBatchRename(
          execution: run,
          readSnapshot: read,
          renameFile: renameFile,
          renameFolder: renameFolder);
}

void main() {
  test('首次撤销写入后报错且状态不明时保留记录但禁用自动撤销', () async {
    final disk = _Disk([file('a', 'a')], {});
    final original = await disk.run(computeBatchRenamePlan(
        items: disk.files,
        allFiles: disk.files,
        allFolders: {},
        bridge: bridge,
        config:
            const BatchRenameConfig(numbering: BatchNumberOp(enabled: true))));
    final attempt = await undoBatchRename(
        execution: original,
        readSnapshot: disk.read,
        renameFolder: disk.renameFolder,
        renameFile: (id, name) async {
          await disk.renameFile(id, name);
          throw StateError('failed after writing');
        });
    expect(attempt.completed, isEmpty);
    expect(attempt.verified, isFalse);
    final remaining = remainingBatchRenameHistory(original, attempt)!;
    expect(remaining.completed.single.forward.id, 'a');
    expect(remaining.canUndo, isFalse);
  });
  test('撤销部分失败或被拒绝时保留剩余历史，可继续恢复原名', () async {
    final disk = _Disk([file('a', 'a'), file('b', 'b')], {});
    final plan = computeBatchRenamePlan(
        items: disk.files,
        allFiles: disk.files,
        allFolders: {},
        bridge: bridge,
        config:
            const BatchRenameConfig(numbering: BatchNumberOp(enabled: true)));
    final original = await disk.run(plan);
    disk.failId = 'a';
    final attempt = await disk.undo(original);
    expect(attempt.completed.length, 1);
    final remaining = remainingBatchRenameHistory(original, attempt)!;
    expect(remaining.completed.single.forward.id, 'a');
    disk.files = [file('a', 'external_edit'), file('b', 'b')];
    final rejected = await disk.undo(remaining);
    expect(remainingBatchRenameHistory(remaining, rejected), same(remaining));
    disk.files = [file('a', '1_a'), file('b', 'b')];
    disk.failId = null;
    final retry = await disk.undo(remaining);
    expect(retry.error, isNull);
    expect(remainingBatchRenameHistory(remaining, retry), isNull);
    expect(disk.files.map((f) => f.name), ['a', 'b']);
  });
  test('嵌套目录及文件执行后按逆序撤销，不丢路径或扩展名', () async {
    final disk =
        _Disk([file('f', 'photo', folder: 'a/x', format: 'jpg')], {'a', 'a/x'});
    final plan = computeBatchRenamePlan(
        items: [dir('a'), dir('a/x'), ...disk.files],
        allFiles: disk.files,
        allFolders: disk.folders,
        bridge: bridge,
        config: const BatchRenameConfig(
            insert: BatchInsertOp(enabled: true, text: 'new_')));
    final result = await disk.run(plan);
    expect(result.error, isNull);
    expect(disk.folders, {'new_a', 'new_a/new_x'});
    expect(disk.files.single.displayName, 'new_photo.jpg');
    expect(result.canUndo, isTrue);
    final undo = await disk.undo(result);
    expect(undo.error, isNull);
    expect(disk.folders, {'a', 'a/x'});
    expect(disk.files.single.name, 'photo');
    expect(disk.files.single.folder, 'a/x');
    expect(disk.calls, ['a/x', 'a', 'f', 'f', 'new_a', 'a/new_x']);
  });

  test('失败立即停止后续改名并可撤销已成功的部分', () async {
    final disk = _Disk([file('a', 'a'), file('b', 'b'), file('c', 'c')], {})
      ..failId = 'b';
    final plan = computeBatchRenamePlan(
        items: disk.files,
        allFiles: disk.files,
        allFolders: {},
        bridge: bridge,
        config:
            const BatchRenameConfig(numbering: BatchNumberOp(enabled: true)));
    final result = await disk.run(plan);
    expect(disk.calls, ['a', 'b']);
    expect(result.completed.length, 1);
    expect(result.remaining, 1);
    expect(result.error, contains('disk full'));
    expect(result.canUndo, isTrue);
    await disk.undo(result);
    expect(disk.files.map((f) => f.name), ['a', 'b', 'c']);
  });

  test('预览之后名称变化或新增冲突时整批拒绝，不调用写入', () async {
    final disk = _Disk([file('a', 'a')], {});
    final plan = computeBatchRenamePlan(
        items: disk.files,
        allFiles: disk.files,
        allFolders: {},
        bridge: bridge,
        config:
            const BatchRenameConfig(numbering: BatchNumberOp(enabled: true)));
    disk.files = [file('a', 'edited')];
    expect((await disk.run(plan)).error, isNotNull);
    disk.files = [file('a', 'a'), file('b', '1_a')];
    expect((await disk.run(plan)).error, isNotNull);
    expect(disk.calls, isEmpty);
  });

  test('取消只在项目之间生效，保留已完成明细以供撤销', () async {
    final disk = _Disk([file('a', 'a'), file('b', 'b')], {});
    final plan = computeBatchRenamePlan(
        items: disk.files,
        allFiles: disk.files,
        allFolders: {},
        bridge: bridge,
        config:
            const BatchRenameConfig(numbering: BatchNumberOp(enabled: true)));
    final result = await disk.run(plan, cancel: () => disk.calls.isNotEmpty);
    expect(result.cancelled, isTrue);
    expect(result.remaining, 1);
    expect(result.canUndo, isTrue);
    expect(disk.calls, ['a']);
  });

  test('后续编辑阻止撤销，回调静默未生效不能报告成功', () async {
    final disk = _Disk([file('a', 'a')], {});
    final plan = computeBatchRenamePlan(
        items: disk.files,
        allFiles: disk.files,
        allFolders: {},
        bridge: bridge,
        config:
            const BatchRenameConfig(numbering: BatchNumberOp(enabled: true)));
    final noop = await executeBatchRename(
        plan: plan,
        bridge: bridge,
        readSnapshot: disk.read,
        renameFile: (_, __) async {},
        renameFolder: disk.renameFolder);
    expect(noop.error, isNotNull);
    expect(noop.completed, isEmpty);
    final result = await disk.run(plan);
    disk.files = [file('a', 'user_edit')];
    expect((await disk.undo(result)).error, isNotNull);
    expect(disk.files.single.name, 'user_edit');
  });
}
