import 'dart:io';

bool get isWindows => false;

String windowsOrdinalFold(String path) => path;

bool? isCaseSensitiveDirectory(String path) => null;

Future<void> preservePermissions(File target, File replacement) async {}
