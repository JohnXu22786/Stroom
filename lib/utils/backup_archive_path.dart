import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// Whether [path] is safe to write as a relative path on the current device.
bool isSafeBackupArchivePath(String path) {
  return _isSafeBackupArchivePath(
    path,
    isWindows: !kIsWeb && Platform.isWindows,
  );
}

@visibleForTesting
bool isSafeBackupArchivePathForTesting(
  String path, {
  required bool isWindows,
}) =>
    _isSafeBackupArchivePath(path, isWindows: isWindows);

bool _isSafeBackupArchivePath(String path, {required bool isWindows}) {
  if (path.codeUnits.contains(0) || path.contains(r'\')) return false;
  final segments = path.split(RegExp(r'[/\\]'));
  final hasInvalidWindowsSegment = isWindows &&
      segments.any((segment) => !_isSafeWindowsPathSegment(segment));
  return !hasInvalidWindowsSegment &&
      !segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      ) &&
      !RegExp(r'^[a-zA-Z]:').hasMatch(path) &&
      !path.startsWith('/');
}

bool _isSafeWindowsPathSegment(String segment) {
  if (segment.codeUnits.any((unit) => unit < 0x20) ||
      RegExp(r'[<>:"|?*]').hasMatch(segment) ||
      segment.endsWith('.') ||
      segment.endsWith(' ')) {
    return false;
  }

  final deviceName = segment
      .split('.')
      .first
      .replaceFirst(RegExp(r'[ .]+$'), '')
      .toLowerCase();
  return !const {
    'con',
    r'conin$',
    r'conout$',
    'prn',
    'aux',
    'nul',
    'com1',
    'com2',
    'com3',
    'com4',
    'com5',
    'com6',
    'com7',
    'com8',
    'com9',
    'com¹',
    'com²',
    'com³',
    'lpt1',
    'lpt2',
    'lpt3',
    'lpt4',
    'lpt5',
    'lpt6',
    'lpt7',
    'lpt8',
    'lpt9',
    'lpt¹',
    'lpt²',
    'lpt³',
  }.contains(deviceName);
}
