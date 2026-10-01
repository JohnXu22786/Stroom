import 'batch_rename.dart';
import 'manifest_bridge.dart';

/// A detached view of the names and paths affected by a batch. File contents,
/// timestamps and storage hashes are deliberately outside rename history.
class BatchRenameSnapshot {
  final List<BatchRenameItem> files;
  final Set<String> folders;
  BatchRenameSnapshot(List<BatchRenameItem> files, Set<String> folders)
      : files = List.unmodifiable(files),
        folders = Set.unmodifiable(folders);

  bool sameNames(BatchRenameSnapshot other) {
    if (folders.length != other.folders.length ||
        !folders.containsAll(other.folders) ||
        files.length != other.files.length) return false;
    final byId = {for (final f in other.files) f.id: f};
    return files.every((f) {
      final other = byId[f.id];
      return other != null &&
          f.name == other.name &&
          f.folder == other.folder &&
          f.format == other.format;
    });
  }

  BatchRenameSnapshot renamed(BatchRenameEntry entry) {
    final parent = entry.isFolder && entry.id.contains('/')
        ? entry.id.substring(0, entry.id.lastIndexOf('/'))
        : '';
    final target =
        parent.isEmpty ? entry.newBaseName : '$parent/${entry.newBaseName}';
    String move(String path) =>
        entry.isFolder && (path == entry.id || path.startsWith('${entry.id}/'))
            ? '$target${path.substring(entry.id.length)}'
            : path;
    return BatchRenameSnapshot([
      for (final f in files)
        BatchRenameItem(
            id: f.id,
            isFolder: false,
            name: !entry.isFolder && f.id == entry.id
                ? entry.newBaseName
                : f.name,
            folder: move(f.folder),
            format: f.format,
            createdAt: f.createdAt,
            modifiedAt: f.modifiedAt,
            size: f.size),
    ], folders.map(move).toSet());
  }
}

class BatchRenameChange {
  final BatchRenameEntry forward;
  final BatchRenameEntry reverse;
  final String oldName;
  final String sourcePath;
  final String targetPath;
  BatchRenameChange(this.forward, this.reverse, this.oldName, this.sourcePath,
      this.targetPath);
}

class BatchRenameExecution {
  final List<BatchRenameChange> completed;
  final BatchRenameSnapshot after;
  final int total;
  final String? error;
  final BatchRenameEntry? failed;
  final bool cancelled;
  final bool verified;
  BatchRenameExecution(
      {required this.completed,
      required this.after,
      required this.total,
      this.error,
      this.failed,
      this.cancelled = false,
      this.verified = true});

  int get remaining => total - completed.length - (failed == null ? 0 : 1);
  bool get canUndo => completed.isNotEmpty && verified;
}

typedef RenameCallback = Future<void> Function(String id, String name);
typedef RenameSnapshotReader = Future<BatchRenameSnapshot> Function();
typedef RenameProgress = void Function(int done, int total, String name);

Future<BatchRenameExecution> executeBatchRename({
  required BatchRenamePlan plan,
  required ManifestBridge bridge,
  required RenameSnapshotReader readSnapshot,
  required RenameCallback renameFile,
  required RenameCallback renameFolder,
  bool Function()? shouldCancel,
  RenameProgress? onProgress,
}) async {
  final initial = await readSnapshot();
  final entries = [...plan.folderEntries, ...plan.fileEntries];
  String? error;
  final byId = {for (final f in initial.files) f.id: f};
  for (final r in plan.results) {
    final item = r.item;
    if (item.isFolder
        ? !initial.folders.contains(item.id)
        : byId[item.id]?.name != item.name ||
            byId[item.id]?.folder != item.folder ||
            byId[item.id]?.format != item.format) {
      error = '文件列表已变化，请重新打开重命名预览';
      break;
    }
  }
  if (error == null) {
    // Revalidate the exact previewed names. Never silently recompute numbering
    // or choose new suffixes after the user has confirmed the preview.
    final latest = computeBatchRenamePlan(
        items: plan.results.map((r) => r.item).toList(),
        config: const BatchRenameConfig(),
        bridge: bridge,
        allFiles: initial.files,
        allFolders: initial.folders,
        overrides: {for (final r in plan.results) r.item.key: r.baseName});
    if (!plan.canApply || !latest.canApply) error = '名称或目标目录已发生冲突，请重新预览';
  }
  if (error != null)
    return BatchRenameExecution(
        completed: [], after: initial, total: entries.length, error: error);
  return _run(entries, initial, readSnapshot, renameFile, renameFolder,
      shouldCancel, onProgress);
}

Future<BatchRenameExecution> undoBatchRename({
  required BatchRenameExecution execution,
  required RenameSnapshotReader readSnapshot,
  required RenameCallback renameFile,
  required RenameCallback renameFolder,
  RenameProgress? onProgress,
}) async {
  final current = await readSnapshot();
  if (!execution.canUndo || !execution.after.sameNames(current)) {
    return BatchRenameExecution(
        completed: [],
        after: current,
        total: execution.completed.length,
        error: '文件列表已变化，无法安全撤销；请重新预览后改名');
  }
  return _run(execution.completed.reversed.map((c) => c.reverse).toList(),
      current, readSnapshot, renameFile, renameFolder, null, onProgress);
}

/// Keep the prefix that an interrupted reverse-order undo has not restored.
/// A rejected attempt has no writes and must not discard the original snapshot.
BatchRenameExecution? remainingBatchRenameHistory(
    BatchRenameExecution original, BatchRenameExecution attempt) {
  if (attempt.completed.isEmpty && attempt.verified) return original;
  final left = original.completed.length - attempt.completed.length;
  if (left == 0) return null;
  return BatchRenameExecution(
      completed: original.completed.take(left).toList(),
      after: attempt.completed.isEmpty ? original.after : attempt.after,
      total: left,
      verified: attempt.verified);
}

Future<BatchRenameExecution> _run(
    List<BatchRenameEntry> entries,
    BatchRenameSnapshot initial,
    RenameSnapshotReader readSnapshot,
    RenameCallback renameFile,
    RenameCallback renameFolder,
    bool Function()? shouldCancel,
    RenameProgress? onProgress) async {
  var expected = initial;
  final completed = <BatchRenameChange>[];
  for (final entry in entries) {
    if (shouldCancel?.call() ?? false)
      return BatchRenameExecution(
          completed: completed,
          after: expected,
          total: entries.length,
          cancelled: true);
    try {
      if (!expected.sameNames(await readSnapshot())) {
        return BatchRenameExecution(
            completed: completed,
            after: expected,
            total: entries.length,
            error: '执行期间文件列表已变化，已停止后续操作',
            verified: false);
      }
      final oldName = entry.isFolder
          ? entry.id.split('/').last
          : expected.files.firstWhere((f) => f.id == entry.id).name;
      final parent = entry.isFolder && entry.id.contains('/')
          ? entry.id.substring(0, entry.id.lastIndexOf('/'))
          : '';
      final reverse = BatchRenameEntry(
          isFolder: entry.isFolder,
          id: entry.isFolder
              ? (parent.isEmpty
                  ? entry.newBaseName
                  : '$parent/${entry.newBaseName}')
              : entry.id,
          newBaseName: oldName);
      final next = expected.renamed(entry);
      String filePath(BatchRenameSnapshot snapshot) {
        final f = snapshot.files.firstWhere((f) => f.id == entry.id);
        return f.folder.isEmpty
            ? f.displayName
            : '${f.folder}/${f.displayName}';
      }

      final sourcePath = entry.isFolder ? entry.id : filePath(expected);
      final targetPath = entry.isFolder ? reverse.id : filePath(next);
      onProgress?.call(completed.length, entries.length, sourcePath);
      await (entry.isFolder ? renameFolder : renameFile)(
          entry.id, entry.newBaseName);
      final actual = await readSnapshot();
      if (!next.sameNames(actual)) {
        return BatchRenameExecution(
            completed: completed,
            after: expected,
            total: entries.length,
            failed: entry,
            verified: expected.sameNames(actual),
            error: '改名未完全生效或文件列表已变化，已停止；请检查该项目');
      }
      completed.add(
          BatchRenameChange(entry, reverse, oldName, sourcePath, targetPath));
      expected = next;
      onProgress?.call(completed.length, entries.length, entry.newBaseName);
    } catch (e) {
      var verified = false;
      try {
        verified = expected.sameNames(await readSnapshot());
      } catch (_) {/* Keep history read-only if state cannot be verified. */}
      return BatchRenameExecution(
          completed: completed,
          after: expected,
          total: entries.length,
          error: '$e',
          failed: entry,
          verified: verified);
    }
  }
  return BatchRenameExecution(
      completed: completed, after: expected, total: entries.length);
}
