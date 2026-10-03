import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _MoveFileExWNative = Int32 Function(
  Pointer<Utf16> oldPath,
  Pointer<Utf16> newPath,
  Uint32 flags,
);

typedef _MoveFileExWDart = int Function(
  Pointer<Utf16> oldPath,
  Pointer<Utf16> newPath,
  int flags,
);

/// Replace an existing Windows file with the fully staged file in one move.
/// Both paths are in the same storage directory, so no copy is required.
Future<bool> replaceExistingBlob(String stagedPath, String targetPath) async {
  if (!Platform.isWindows) return false;
  const moveFileReplaceExisting = 0x1;
  final moveFileEx = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<_MoveFileExWNative, _MoveFileExWDart>('MoveFileExW');
  final oldPath = stagedPath.toNativeUtf16();
  final newPath = targetPath.toNativeUtf16();
  try {
    return moveFileEx(oldPath, newPath, moveFileReplaceExisting) != 0;
  } finally {
    malloc.free(oldPath);
    malloc.free(newPath);
  }
}
