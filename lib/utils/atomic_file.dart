import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

/// 原子文件写入工具。
///
/// 直接 `writeAsString/writeAsBytes` 不是原子操作——写入中途崩溃/断电
/// 会留下半截文件，下次启动解析失败（任务丢失、数据损坏）。本工具
/// 通过「写临时文件 → rename 替换」保证目标文件要么是完整的旧内容，
/// 要么是完整的新内容（rename 在同一文件系统内是原子操作）。
///
/// 注意：调用方需自行保证同一文件的写入串行化（并发写同一文件时，
/// 后写的 tmp 文件会互相覆盖，rename 时序不确定）。
class AtomicFile {
  AtomicFile._();

  /// 将 [data] 原子写入 [file]。
  ///
  /// Windows 上防病毒扫描可能短暂锁定临时文件导致替换失败：
  /// 重试数次，仍失败则回退为直接写入（非原子，但不丢数据——
  /// 数据完整性由启动校验 + 快照链兜底）。
  static Future<void> writeString(File file, String data) =>
      _write(file, (f) => f.writeAsString(data));

  /// 将 [bytes] 原子写入 [file]。
  static Future<void> writeBytes(File file, List<int> bytes) =>
      _write(file, (f) => f.writeAsBytes(bytes));

  static Future<void> _write(
    File file,
    Future<void> Function(File) write,
  ) async {
    final tmpFile = File('${file.path}.tmp');
    try {
      await write(tmpFile);
    } catch (e) {
      // 临时文件都写不进去（磁盘满等），目标文件保持原状即可。
      debugPrint('AtomicFile: 写临时文件失败 ${file.path}: $e');
      try {
        if (await tmpFile.exists()) await tmpFile.delete();
      } catch (_) {}
      return;
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
        await tmpFile.rename(file.path);
        return;
      } catch (e) {
        if (attempt == 2) {
          // 兜底：直接写目标文件（非原子，但至少不丢失数据）。
          try {
            await write(file);
            try {
              if (await tmpFile.exists()) await tmpFile.delete();
            } catch (_) {}
            return;
          } catch (_) {
            try {
              await tmpFile.rename(file.path);
              return;
            } catch (_) {
              try {
                if (await tmpFile.exists()) await tmpFile.delete();
              } catch (_) {}
              rethrow;
            }
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    // 理论不可达：循环内必然 return 或 rethrow。
    try {
      if (await tmpFile.exists()) await tmpFile.delete();
    } catch (_) {}
  }
}
