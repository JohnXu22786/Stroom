import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';
import '../utils/web_file_store.dart';

void addStringToArchive(Archive archive, String name, String content) {
  final bytes = utf8.encode(content);
  archive.addFile(ArchiveFile(name, bytes.length, bytes));
}

Future<void> addTaskFileToArchive(
    Archive archive, String archiveName, String sourcePath) async {
  if (WebFileStore.isTestMode) {
    addStringToArchive(archive, archiveName, '[]');
    return;
  }
  try {
    final file = File(sourcePath);
    if (await file.exists()) {
      final data = await file.readAsBytes();
      archive.addFile(ArchiveFile(archiveName, data.length, data));
    } else {
      addStringToArchive(archive, archiveName, '[]');
    }
  } catch (e) {
    debugPrint('添加任务文件 $archiveName 失败: $e');
    addStringToArchive(archive, archiveName, '[]');
  }
}

Future<void> addFileToArchive(
    Archive archive, String archiveName, String subDir, String fileName) async {
  try {
    final data = await readBackupFile(subDir, fileName);
    if (data != null) {
      archive.addFile(ArchiveFile(archiveName, data.length, data));
    }
  } catch (e) {
    debugPrint('添加文件 $archiveName 失败: $e');
  }
}

Future<Uint8List?> readBackupFile(String subDir, String fileName) async {
  if (kIsWeb || WebFileStore.isTestMode) {
    return WebFileStore.read('$subDir/$fileName');
  } else {
    final appDir = await AppStorage.directory;
    final file = File(p.join(appDir, subDir, fileName));
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }
}

Future<void> writeBackupFile(
    String subDir, String fileName, Uint8List data) async {
  if (kIsWeb || WebFileStore.isTestMode) {
    await WebFileStore.write('$subDir/$fileName', data);
  } else {
    final appDir = await AppStorage.directory;
    final dir = Directory(p.join(appDir, subDir));
    await dir.create(recursive: true);
    await File(p.join(dir.path, fileName)).writeAsBytes(data);
  }
}

Future<Set<String>> collectAttachmentPaths() async {
  final paths = <String>{};
  try {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('conversations');
    if (json == null) return paths;

    final conversations = jsonDecode(json) as List<dynamic>;
    for (final conv in conversations) {
      final messages =
          (conv as Map<String, dynamic>)['messages'] as List<dynamic>? ?? [];
      for (final msg in messages) {
        final attachments =
            (msg as Map<String, dynamic>)['attachments'] as List<dynamic>? ??
                [];
        for (final att in attachments) {
          final attMap = att as Map<String, dynamic>;
          final storagePath = attMap['storagePath'] as String?;
          if (storagePath != null && storagePath.isNotEmpty) {
            paths.add(storagePath);
          }
          final thumbnailPath = attMap['thumbnailPath'] as String?;
          if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
            paths.add(thumbnailPath);
          }
        }
      }
    }
  } catch (e) {
    debugPrint('收集附件路径失败: $e');
  }
  return paths;
}
