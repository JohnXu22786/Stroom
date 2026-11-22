import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _ChmodNative = Int32 Function(Pointer<Utf8>, Uint32);
typedef _ChmodDart = int Function(Pointer<Utf8>, int);

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

final DynamicLibrary? _kernel32 =
    Platform.isWindows ? DynamicLibrary.open('kernel32.dll') : null;
final DynamicLibrary? _ntdll =
    Platform.isWindows ? DynamicLibrary.open('ntdll.dll') : null;

final _ChmodDart? _chmod = Platform.isWindows
    ? null
    : DynamicLibrary.process()
        .lookupFunction<_ChmodNative, _ChmodDart>('chmod');

bool get isWindows => Platform.isWindows;

String windowsOrdinalFold(String path) {
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

bool? isCaseSensitiveDirectory(String path) {
  // Windows can opt individual directories into case-sensitive names.
  // Query that flag before folding a path component so those directories keep
  // separate queues for names that differ only by case.
  try {
    final kernel32 = _kernel32!;
    final createFile = kernel32
        .lookupFunction<_CreateFileWNative, _CreateFileWDart>('CreateFileW');
    final getInfo = kernel32.lookupFunction<_GetFileInformationByHandleExNative,
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

Future<void> preservePermissions(File target, File replacement) async {
  if (Platform.isWindows || !await target.exists()) return;

  final mode = (await target.stat()).mode & 0xfff;
  final nativePath = replacement.path.toNativeUtf8();
  try {
    if (_chmod!(nativePath, mode) != 0) {
      throw FileSystemException(
        'Could not preserve existing file permissions',
        replacement.path,
      );
    }
  } finally {
    malloc.free(nativePath);
  }
}
