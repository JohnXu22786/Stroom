import 'dart:io';

import 'package:path/path.dart' as p;

/// 原子文件写入工具。
///
/// 当前 isolate 内对同一路径的写入按调用顺序执行。先将完整内容刷新到
/// 独立的临时文件，再通过同一文件系统内的 rename 替换目标文件。
/// 写入或替换失败会抛出异常，保留目标文件的旧内容供调用方重试。
class AtomicFile {
  AtomicFile._();

  static final Map<String, Future<void>> _pendingWrites = {};

  /// 将 [data] 原子写入 [file]，失败时抛出文件系统异常。
  static Future<void> writeString(File file, String data) =>
      _enqueue(file, (f) => f.writeAsString(data, flush: true));

  /// 将 [bytes] 原子写入 [file]，失败时抛出文件系统异常。
  static Future<void> writeBytes(File file, List<int> bytes) {
    final snapshot = List<int>.of(bytes);
    return _enqueue(file, (f) => f.writeAsBytes(snapshot, flush: true));
  }

  static Future<void> _enqueue(
    File file,
    Future<void> Function(File) write,
  ) {
    final key = p.normalize(file.absolute.path);
    final previous = _pendingWrites[key] ?? Future<void>.value();
    final operation = previous.then((_) => _write(file, write));
    // 调用方收到原始异常；队列本身始终继续，失败不会阻塞后续重试。
    late final Future<void> settled;
    settled = operation
        .then<void>((_) {}, onError: (Object error) {})
        .whenComplete(() {
      if (identical(_pendingWrites[key], settled)) _pendingWrites.remove(key);
    });
    _pendingWrites[key] = settled;
    return operation;
  }

  static Future<void> _write(
    File file,
    Future<void> Function(File) write,
  ) async {
    final tempDir =
        await file.parent.createTemp('.${p.basename(file.path)}.tmp-');
    final tmpFile = File(p.join(tempDir.path, 'data'));
    try {
      await write(tmpFile);
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          // rename 自身替换已有文件，不能先删除目标或回退到直接覆盖。
          await tmpFile.rename(file.path);
          return;
        } on FileSystemException {
          if (attempt == 2) rethrow;
          // Windows 上文件可能被防病毒扫描短暂锁定。
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
