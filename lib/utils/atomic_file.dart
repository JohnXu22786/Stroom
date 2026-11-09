import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

final class _FileCaseSensitiveInfo extends Struct {
  @Uint32()
  external int flags;
}

typedef _CreateFileWNative = IntPtr Function(
  Pointer<Utf16>,
  Uint32,
  Uint32,
  Pointer<Void>,
  Uint32,
  Uint32,
  IntPtr,
);
typedef _CreateFileWDart = int Function(
  Pointer<Utf16>,
  int,
  int,
  Pointer<Void>,
  int,
  int,
  int,
);
typedef _GetFileInformationByHandleExNative = Int32 Function(
  IntPtr,
  Uint32,
  Pointer<Void>,
  Uint32,
);
typedef _GetFileInformationByHandleExDart = int Function(
  int,
  int,
  Pointer<Void>,
  int,
);
typedef _CloseHandleNative = Int32 Function(IntPtr);
typedef _CloseHandleDart = int Function(int);

/// 原子文件写入工具。
///
/// 当前 isolate 内对同一路径的写入按调用顺序执行。先将完整内容刷新到
/// 独立的临时文件，再通过同一文件系统内的 rename 替换目标文件。
/// 写入或替换失败会抛出异常，保留目标文件的旧内容供调用方重试。
class AtomicFile {
  AtomicFile._();

  static final Map<String, Future<void>> _pendingWrites = {};
  static final DynamicLibrary? _kernel32 =
      Platform.isWindows ? DynamicLibrary.open('kernel32.dll') : null;
  static final DynamicLibrary? _ntdll =
      Platform.isWindows ? DynamicLibrary.open('ntdll.dll') : null;
  static final p.Context _windowsPath = p.Context(style: p.Style.windows);

  /// 将 [data] 原子写入 [file]，失败时抛出文件系统异常。
  static Future<void> writeString(File file, String data) =>
      _enqueue(file, (f) => f.writeAsString(data, flush: true));

  /// 将 [bytes] 原子写入 [file]，失败时抛出文件系统异常。
  static Future<void> writeBytes(
    File file,
    List<int> bytes, {
    void Function()? beforeCommit,
  }) {
    final snapshot = List<int>.of(bytes);
    return _enqueue(
      file,
      (f) => f.writeAsBytes(snapshot, flush: true),
      beforeCommit: beforeCommit,
    );
  }

  static Future<void> _enqueue(
    File file,
    Future<void> Function(File) write, {
    void Function()? beforeCommit,
  }) {
    final path = p.normalize(file.absolute.path);
    final key = Platform.isWindows ? _windowsPathKey(path) : path;
    final previous = _pendingWrites[key] ?? Future<void>.value();
    final operation = previous.then(
      (_) => _write(file, write, beforeCommit: beforeCommit),
    );
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

  static String _windowsOrdinalFold(String path) {
    final upcase =
        _ntdll!.lookupFunction<Uint16 Function(Uint16), int Function(int)>(
      'RtlUpcaseUnicodeChar',
    );
    final nativePath = path.toNativeUtf16();
    try {
      final pathUnits = nativePath.cast<Uint16>();
      final foldedUnits = <int>[];
      for (var index = 0; pathUnits[index] != 0; index++) {
        foldedUnits.add(upcase(pathUnits[index]));
      }
      return String.fromCharCodes(foldedUnits);
    } finally {
      malloc.free(nativePath);
    }
  }

  static String _windowsPathKey(String path) => _computeWindowsPathKey(
        path,
        directoryIsCaseSensitive: _isCaseSensitiveDirectory,
        fold: _windowsOrdinalFold,
      );

  @visibleForTesting
  static String windowsPathKeyForTesting(
    String path, {
    required bool? Function(String) directoryIsCaseSensitive,
    required String Function(String) fold,
  }) =>
      _computeWindowsPathKey(
        path,
        directoryIsCaseSensitive: directoryIsCaseSensitive,
        fold: fold,
      );

  static String _computeWindowsPathKey(
    String path, {
    required bool? Function(String) directoryIsCaseSensitive,
    required String Function(String) fold,
  }) {
    final components = _windowsPath.split(path);
    if (components.length < 2) return path;

    var currentDirectory = components.first;
    final keyComponents = <String>[fold(components.first)];
    for (final component in components.skip(1)) {
      final sensitivity = directoryIsCaseSensitive(currentDirectory);
      final normalized = sensitivity == false ? fold(component) : component;
      keyComponents.add(normalized);
      currentDirectory = _windowsPath.join(currentDirectory, component);
    }
    return _windowsPath.joinAll(keyComponents);
  }

  static bool? _isCaseSensitiveDirectory(String path) {
    // Windows can opt individual directories into case-sensitive names.
    // Query that flag before folding the leaf path so those directories keep
    // separate queues for names that differ only by case.
    try {
      final kernel32 = _kernel32!;
      final createFile = kernel32
          .lookupFunction<_CreateFileWNative, _CreateFileWDart>('CreateFileW');
      final getInfo = kernel32.lookupFunction<
          _GetFileInformationByHandleExNative,
          _GetFileInformationByHandleExDart>('GetFileInformationByHandleEx');
      final closeHandle = kernel32
          .lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');
      final nativePath = path.toNativeUtf16();
      try {
        // FILE_READ_ATTRIBUTES, shared read/write/delete, OPEN_EXISTING,
        // FILE_FLAG_BACKUP_SEMANTICS (required to open a directory).
        final handle = createFile(
          nativePath,
          0x80,
          0x7,
          nullptr,
          3,
          0x02000000,
          0,
        );
        if (handle == -1) return null;
        try {
          final info = calloc<_FileCaseSensitiveInfo>();
          try {
            const fileCaseSensitiveInfo = 23;
            final succeeded = getInfo(
                  handle,
                  fileCaseSensitiveInfo,
                  info.cast<Void>(),
                  sizeOf<_FileCaseSensitiveInfo>(),
                ) !=
                0;
            const caseSensitiveDirectory = 0x1;
            if (!succeeded) return null;
            return (info.ref.flags & caseSensitiveDirectory) != 0;
          } finally {
            calloc.free(info);
          }
        } finally {
          closeHandle(handle);
        }
      } finally {
        malloc.free(nativePath);
      }
    } catch (_) {
      // Unknown directories must retain case to avoid merging distinct paths.
      return null;
    }
  }

  static Future<void> _write(
    File file,
    Future<void> Function(File) write, {
    void Function()? beforeCommit,
  }) async {
    final tempDir = await file.parent.createTemp(
      '.${p.basename(file.path)}.tmp-',
    );
    final tmpFile = File(p.join(tempDir.path, 'data'));
    try {
      await write(tmpFile);
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          // rename 自身替换已有文件，不能先删除目标或回退到直接覆盖。
          beforeCommit?.call();
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
