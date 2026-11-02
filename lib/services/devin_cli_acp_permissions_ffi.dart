import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

Future<void> restrictDirectory(String path) async {
  if (Platform.isWindows) {
    // Application Support on Windows is rooted in the current user's AppData,
    // whose inherited ACL grants access to that user and system administrators.
    return;
  }
  if (!Platform.isLinux && !Platform.isMacOS) {
    throw UnsupportedError(
      'Private CLI storage is unavailable on this platform.',
    );
  }
  final library = DynamicLibrary.process();
  final chmod = library.lookupFunction<Int32 Function(Pointer<Utf8>, Uint32),
      int Function(Pointer<Utf8>, int)>('chmod');
  final nativePath = path.toNativeUtf8();
  try {
    if (chmod(nativePath, 0x1c0) != 0) {
      throw FileSystemException('Could not secure CLI account storage.', path);
    }
  } finally {
    malloc.free(nativePath);
  }
}

Future<void> restrictExecutable(String path) async {
  if (Platform.isWindows) return;
  if (!Platform.isLinux && !Platform.isMacOS) {
    throw UnsupportedError(
      'Private CLI storage is unavailable on this platform.',
    );
  }
  final library = DynamicLibrary.process();
  final chmod = library.lookupFunction<Int32 Function(Pointer<Utf8>, Uint32),
      int Function(Pointer<Utf8>, int)>('chmod');
  final nativePath = path.toNativeUtf8();
  try {
    if (chmod(nativePath, 0x140) != 0) {
      throw FileSystemException('Could not secure the Devin CLI copy.', path);
    }
  } finally {
    malloc.free(nativePath);
  }
}
