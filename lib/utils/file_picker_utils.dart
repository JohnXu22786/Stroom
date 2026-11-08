import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Opens a save dialog filtered to [extensions] and writes [bytes] to the
/// selected location.
///
/// Desktop file_picker 13 save dialogs no longer forward extension filters to
/// their platform interface, so use file_selector there. Browser and mobile
/// save flows keep file_picker's byte-save behavior; the suggested filename
/// includes the selected extension.
Future<Uri?> saveFileWithType({
  required String fileName,
  required Uint8List bytes,
  required List<String> extensions,
  String? dialogTitle,
  String mimeType = 'application/octet-stream',
  String? initialDirectory,
}) async {
  final isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);
  if (!isDesktop) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
    );
  }

  final location = await getSaveLocation(
    acceptedTypeGroups: [XTypeGroup(extensions: extensions)],
    initialDirectory: initialDirectory,
    suggestedName: fileName,
  );
  if (location == null) return null;

  await XFile.fromData(
    bytes,
    mimeType: mimeType,
    name: fileName,
  ).saveTo(location.path);
  return Uri.file(location.path);
}

/// Formats a save location for a user-facing message.
///
/// Local save dialogs return `file:` URIs while web save flows may return a
/// `blob:` or `data:` URI. Preserve the familiar filesystem path for local
/// files and show the URI for browser-managed downloads.
String filePickerLocationLabel(Uri location) {
  if (location.scheme == 'file') return location.toFilePath();
  return location.toString();
}

/// Rejects file/file and file/directory collisions before an export writes.
void validateUserVisibleExportPaths({
  required Iterable<String> files,
  Iterable<String> folders = const [],
}) {
  String safePath(String path) {
    final segments = path.replaceAll('\\', '/').split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw ArgumentError.value(path, 'path', 'Invalid export path');
    }
    return segments.join('/');
  }

  final filePaths = <String>{};
  final directoryPaths = <String>{};

  void addDirectoryAndAncestors(String path) {
    final segments = path.split('/');
    for (var i = 1; i <= segments.length; i++) {
      directoryPaths.add(segments.take(i).join('/'));
    }
  }

  for (final folder in folders) {
    if (folder.isNotEmpty) addDirectoryAndAncestors(safePath(folder));
  }
  for (final file in files) {
    final path = safePath(file);
    if (!filePaths.add(path)) {
      throw StateError('Duplicate export file path: $path');
    }
    final segments = path.split('/');
    if (segments.length > 1) {
      addDirectoryAndAncestors(segments.take(segments.length - 1).join('/'));
    }
  }

  for (final filePath in filePaths) {
    if (directoryPaths.contains(filePath) ||
        directoryPaths.any(
          (folderPath) => folderPath.startsWith('$filePath/'),
        )) {
      throw StateError('Export file conflicts with a folder path: $filePath');
    }
  }
}

/// Builds a portable archive using the logical paths shown in Stroom.
/// Storage paths are intentionally not accepted by this helper.
Uint8List encodeUserVisibleExportArchive({
  required Map<String, Uint8List> files,
  Iterable<String> folders = const [],
}) {
  validateUserVisibleExportPaths(files: files.keys, folders: folders);
  final archive = Archive();
  final addedFolders = <String>{};

  String safePath(String path) {
    final segments = path.replaceAll('\\', '/').split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw ArgumentError.value(path, 'path', 'Invalid export path');
    }
    return segments.join('/');
  }

  for (final folder in folders) {
    if (folder.isEmpty) continue;
    final path = safePath(folder);
    for (var i = 1; i <= path.split('/').length; i++) {
      final parent = path.split('/').take(i).join('/');
      if (addedFolders.add(parent)) {
        archive.addFile(ArchiveFile('$parent/', 0, Uint8List(0)));
      }
    }
  }

  for (final entry in files.entries) {
    final path = safePath(entry.key);
    final segments = path.split('/');
    for (var i = 1; i < segments.length; i++) {
      final parent = segments.take(i).join('/');
      if (addedFolders.add(parent)) {
        archive.addFile(ArchiveFile('$parent/', 0, Uint8List(0)));
      }
    }
    archive.addFile(ArchiveFile(path, entry.value.length, entry.value));
  }

  return Uint8List.fromList(ZipEncoder().encode(archive));
}
