import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/text_manifest.dart';

// ============================================================================
// 文本记录列表
// ============================================================================

final textRecordsProvider =
    StateNotifierProvider<TextRecordsNotifier, List<TextRecord>>(
  (ref) => TextRecordsNotifier(),
);

// ============================================================================
// 文件夹列表
// ============================================================================

final textFolderListProvider =
    StateNotifierProvider<TextFolderListNotifier, Set<String>>(
  (ref) => TextFolderListNotifier(),
);

// ============================================================================
// 视图模式（false = 列表，true = 缩略图/网格）
// ============================================================================

final textViewModeProvider =
    StateNotifierProvider<TextViewModeNotifier, bool>((ref) {
  final notifier = TextViewModeNotifier();
  notifier.load();
  return notifier;
});

// ============================================================================
// 文件夹列表 Notifier
// ============================================================================

class TextFolderListNotifier extends StateNotifier<Set<String>> {
  TextFolderListNotifier() : super({});

  Future<void> loadFolders() async {
    final folders = await TextManifest.getAllFolders();
    state = folders;
  }

  Future<void> addFolder(String name) async {
    await TextManifest.addFolder(name);
    await loadFolders();
  }

  Future<void> removeFolder(String name) async {
    await TextManifest.removeFolder(name);
    await loadFolders();
  }
}

// ============================================================================
// 文本记录 Notifier
// ============================================================================

class TextRecordsNotifier extends StateNotifier<List<TextRecord>> {
  TextRecordsNotifier() : super([]);

  Future<void> loadRecords() async {
    final records = await TextManifest.loadRecords();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = List<TextRecord>.from(records);
  }

  Future<void> addRecord(TextRecord record) async {
    await TextManifest.addRecord(record);
    await loadRecords();
  }

  Future<void> deleteRecord(String id) async {
    await TextManifest.deleteRecord(id);
    await loadRecords();
  }

  Future<void> deleteRecords(List<String> ids) async {
    await TextManifest.deleteRecords(ids);
    await loadRecords();
  }

  Future<void> renameRecord(String id, String newName) async {
    TextManifest.invalidateCache();
    await TextManifest.renameRecord(id, newName);
    await loadRecords();
  }

  Future<void> moveRecord(String id, String targetFolder) async {
    await TextManifest.moveRecord(id, targetFolder);
    await loadRecords();
  }

  // ====================================================================
  // 文件夹管理
  // ====================================================================

  /// 获取所有有效文件夹（含空文件夹 + 记录中存在的文件夹）
  Future<Set<String>> getFolders() async {
    return TextManifest.getAllFolders();
  }

  /// 创建文件夹
  Future<void> createFolder(String folderName) async {
    await TextManifest.addFolder(folderName);
  }

  /// 删除文件夹（同时删除内部所有记录）
  Future<void> deleteFolder(String folderName) async {
    await TextManifest.removeFolder(folderName);
    await loadRecords();
  }

  /// 获取某个文件夹的所有后代文件夹路径
  Future<List<String>> _getDescendantFolders(String folderPath) async {
    final prefix = folderPath.isEmpty ? '' : '$folderPath/';
    final seen = <String>{};
    final result = <String>[];
    for (final r in state) {
      if (r.folder.startsWith(prefix) && r.folder != folderPath) {
        if (seen.add(r.folder)) {
          result.add(r.folder);
        }
      }
    }
    final allFolders = await TextManifest.getAllFolders();
    for (final f in allFolders) {
      if (f.startsWith(prefix) && f != folderPath) {
        if (seen.add(f)) result.add(f);
      }
    }
    return result;
  }

  /// 重命名文件夹（只更新末级名称，保留层级结构）
  Future<void> renameFolder(String oldName, String newName) async {
    TextManifest.invalidateCache();
    final parentPath = TextManifest.getParentFolderPath(oldName);
    final newPath = parentPath.isEmpty ? newName : '$parentPath/$newName';

    final records = await TextManifest.loadRecords();

    for (final r in records) {
      if (r.folder == oldName) {
        await TextManifest.moveRecord(r.id, newPath);
      }
    }

    final descendants = await _getDescendantFolders(oldName);
    for (final desc in descendants) {
      final suffix = desc.substring(oldName.length);
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await TextManifest.moveRecord(r.id, newDescPath);
        }
      }
    }

    await TextManifest.addFolder(newPath);
    await TextManifest.removeFolderFromCache(oldName);

    await loadRecords();
  }

  /// 移动文件夹（保持层级结构，整体搬入目标文件夹）
  Future<void> moveFolder(String sourceName, String targetParent) async {
    TextManifest.invalidateCache();
    final baseName = TextManifest.getFolderBaseName(sourceName);
    final newPath = targetParent.isEmpty ? baseName : '$targetParent/$baseName';

    final records = await TextManifest.loadRecords();

    for (final r in records) {
      if (r.folder == sourceName) {
        await TextManifest.moveRecord(r.id, newPath);
      }
    }

    final descendants = await _getDescendantFolders(sourceName);
    for (final desc in descendants) {
      final suffix = desc.substring(sourceName.length);
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await TextManifest.moveRecord(r.id, newDescPath);
        }
      }
    }

    await TextManifest.removeFolderFromCache(sourceName);
    for (final desc in descendants) {
      await TextManifest.removeFolderFromCache(desc);
    }

    await TextManifest.addFolder(newPath);
    if (targetParent.isNotEmpty) {
      await TextManifest.addFolder(targetParent);
    }

    await loadRecords();
  }

  /// 复制文件夹（保持层级结构，整体复制到目标文件夹）
  Future<void> copyFolder(String sourceName, String targetParent) async {
    final baseName = TextManifest.getFolderBaseName(sourceName);
    final newPath = targetParent.isEmpty ? baseName : '$targetParent/$baseName';

    final records = await TextManifest.loadRecords();

    for (final r in records) {
      if (r.folder == sourceName) {
        await TextManifest.addRecord(TextRecord(
          name: r.name,
          hash: r.hash,
          format: r.format,
          createdAt: DateTime.now(),
          size: r.size,
          folder: newPath,
          textLength: r.textLength,
        ));
      }
    }

    final descendants = await _getDescendantFolders(sourceName);
    for (final desc in descendants) {
      final suffix = desc.substring(sourceName.length);
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await TextManifest.addRecord(TextRecord(
            name: r.name,
            hash: r.hash,
            format: r.format,
            createdAt: DateTime.now(),
            size: r.size,
            folder: newDescPath,
            textLength: r.textLength,
          ));
        }
      }
    }

    await TextManifest.addFolder(newPath);
    if (targetParent.isNotEmpty) {
      await TextManifest.addFolder(targetParent);
    }

    await loadRecords();
  }
}

// ============================================================================
// 视图模式 Notifier（持久化到 SharedPreferences）
// ============================================================================

class TextViewModeNotifier extends StateNotifier<bool> {
  TextViewModeNotifier() : super(false);

  static const String _storageKey = 'text_view_mode';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_storageKey) ?? false;
    } catch (e) {
      debugPrint('TextViewModeNotifier.load error: $e');
    }
  }

  Future<void> toggle() async {
    final newValue = !state;
    state = newValue;
    await _persist(newValue);
  }

  Future<void> setViewMode(bool isGrid) async {
    state = isGrid;
    await _persist(isGrid);
  }

  Future<void> _persist(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, value);
    } catch (e) {
      debugPrint('TextViewModeNotifier._persist error: $e');
    }
  }
}
