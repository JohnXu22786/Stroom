import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// ====================================================================
// 桌面平台磁盘剩余空间（dart:ffi）
// ====================================================================
//
// - Windows: GetDiskFreeSpaceExW (kernel32)
// - macOS/Linux: statvfs (libc)
//
// 结构体布局：
// - struct statvfs 前 5 个字段（f_bsize/f_frsize/f_blocks/f_bfree/f_bavail）
//   在 64 位 macOS（unsigned long）与 Linux（unsigned long / fsblkcnt_t）
//   上均为 8 字节，故两种平台共用同一布局。
// - 剩余空间 = f_bavail × f_frsize（f_frsize 为 0 时用 f_bsize）。
//
// 注意：FFI 的 Struct 子类不能声明为 final（否则布局无法合成）。
// ====================================================================

/// 获取 [path] 所在文件系统的剩余可用空间（字节），失败返回 null。
int? getFreeDiskSpaceBytes(String path) {
  try {
    if (Platform.isWindows) {
      return _windowsFreeSpace(path);
    }
    if (Platform.isMacOS || Platform.isLinux) {
      return _posixFreeSpace(path);
    }
    return null;
  } catch (_) {
    return null;
  }
}

// --------------------------------------------------------------------
// Windows: GetDiskFreeSpaceExW
// --------------------------------------------------------------------

typedef _GetDiskFreeSpaceExWNative = Int32 Function(
  Pointer<Utf16> lpDirectoryName,
  Pointer<Uint64> lpFreeBytesAvailableToCaller,
  Pointer<Uint64> lpTotalNumberOfBytes,
  Pointer<Uint64> lpTotalNumberOfFreeBytes,
);

typedef _GetDiskFreeSpaceExWDart = int Function(
  Pointer<Utf16> lpDirectoryName,
  Pointer<Uint64> lpFreeBytesAvailableToCaller,
  Pointer<Uint64> lpTotalNumberOfBytes,
  Pointer<Uint64> lpTotalNumberOfFreeBytes,
);

int? _windowsFreeSpace(String path) {
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final fn = kernel32.lookupFunction<_GetDiskFreeSpaceExWNative,
      _GetDiskFreeSpaceExWDart>('GetDiskFreeSpaceExW');
  final free = calloc<Uint64>(1);
  try {
    final pathPtr = path.toNativeUtf16();
    try {
      final ok = fn(pathPtr, free, nullptr, nullptr);
      if (ok == 0) return null;
      return free.value;
    } finally {
      malloc.free(pathPtr);
    }
  } finally {
    malloc.free(free);
  }
}

// --------------------------------------------------------------------
// macOS / Linux: statvfs
// --------------------------------------------------------------------

final class _StatVfs extends Struct {
  @Uint64()
  external int bsize;

  @Uint64()
  external int frsize;

  @Uint64()
  external int blocks;

  @Uint64()
  external int bfree;

  @Uint64()
  external int bavail;
}

typedef _StatvfsNative = Int32 Function(
  Pointer<Utf8> path,
  Pointer<_StatVfs> buf,
);

typedef _StatvfsDart = int Function(
  Pointer<Utf8> path,
  Pointer<_StatVfs> buf,
);

int? _posixFreeSpace(String path) {
  final lib = Platform.isMacOS
      ? DynamicLibrary.open('/usr/lib/libSystem.B.dylib')
      : DynamicLibrary.process();
  final statvfs = lib.lookupFunction<_StatvfsNative, _StatvfsDart>('statvfs');

  // 注意：statvfs 会写入完整的 struct statvfs（Linux x86_64 约 112 字节，
  // macOS 约 104 字节），而 [_StatVfs] 只声明了前 5 个字段（40 字节）。
  // 若只按声明大小分配，原生侧会越界写坏堆内存（SIGABRT）。
  // 因此分配 256 字节的原始缓冲，再以 [_StatVfs] 视图读取前 5 个字段。
  final buf = calloc<Uint8>(256);
  final st = Pointer<_StatVfs>.fromAddress(buf.address);
  final pathPtr = path.toNativeUtf8();
  try {
    final result = statvfs(pathPtr, st);
    if (result != 0) return null;
    final stvfs = st.ref;
    final frsize = stvfs.frsize != 0 ? stvfs.frsize : stvfs.bsize;
    if (frsize == 0) return null;
    return stvfs.bavail * frsize;
  } finally {
    malloc.free(pathPtr);
    malloc.free(buf);
  }
}
