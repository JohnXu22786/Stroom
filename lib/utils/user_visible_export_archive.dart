import 'dart:typed_data';

import 'package:archive/archive.dart';

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
        directoryPaths.any((folderPath) => folderPath.startsWith('$filePath/'))) {
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
    if (segments.any((segment) => segment.isEmpty || segment == '.' || segment == '..')) {
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
