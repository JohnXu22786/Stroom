import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/video_manifest.dart';

// ============================================================================
// 视频记录列表
// ============================================================================

final videoRecordsProvider =
    StateNotifierProvider<VideoRecordsNotifier, List<VideoRecord>>(
  (ref) => VideoRecordsNotifier(),
);

// ============================================================================
// 文件夹列表
// ============================================================================

final videoFolderListProvider =
    StateNotifierProvider<VideoFolderListNotifier, Set<String>>(
  (ref) => VideoFolderListNotifier(),
);

// ============================================================================
// 视图模式（false = 列表，true = 缩略图/网格）
// ============================================================================

final videoViewModeProvider =
    StateNotifierProvider<VideoViewModeNotifier, bool>((ref) {
  final notifier = VideoViewModeNotifier();
  notifier.load();
  return notifier;
});

// ============================================================================
// 文件夹列表 Notifier
// ============================================================================

class VideoFolderListNotifier extends StateNotifier<Set<String>> {
  VideoFolderListNotifier() : super({});

  Future<void> loadFolders() async {
    final folders = await VideoManifest.getAllFolders();
    state = folders;
  }

  Future<void> addFolder(String name) async {
    await VideoManifest.addFolder(name);
    await loadFolders();
  }

  Future<void> removeFolder(String name) async {
    await VideoManifest.removeFolder(name);
    await loadFolders();
  }
}

// ============================================================================
// 视频记录 Notifier
// ============================================================================

class VideoRecordsNotifier extends StateNotifier<List<VideoRecord>> {
  VideoRecordsNotifier() : super([]);

  Future<void> loadRecords() async {
    final records = await VideoManifest.loadRecords();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = List<VideoRecord>.from(records);
  }

  Future<void> addRecord(VideoRecord record) async {
    await VideoManifest.addRecord(record);
    await loadRecords();
  }

  Future<void> deleteRecord(String id) async {
    await VideoManifest.deleteRecord(id);
    await loadRecords();
  }

  Future<void> deleteRecords(List<String> ids) async {
    await VideoManifest.deleteRecords(ids);
    await loadRecords();
  }

  Future<void> renameRecord(String id, String newName) async {
    VideoManifest.invalidateCache();
    await VideoManifest.renameRecord(id, newName);
    await loadRecords();
  }

  Future<void> moveRecord(String id, String targetFolder) async {
    await VideoManifest.moveRecord(id, targetFolder);
    await loadRecords();
  }

  // ====================================================================
  // 文件夹管理
  // ====================================================================

  /// 获取所有有效文件夹（含空文件夹 + 记录中存在的文件夹）
  Future<Set<String>> getFolders() async {
    return VideoManifest.getAllFolders();
  }

  /// 创建文件夹
  Future<void> createFolder(String folderName) async {
    await VideoManifest.addFolder(folderName);
  }

  /// 删除文件夹（同时删除内部所有记录）
  Future<void> deleteFolder(String folderName) async {
    await VideoManifest.removeFolder(folderName);
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
    final allFolders = await VideoManifest.getAllFolders();
    for (final f in allFolders) {
      if (f.startsWith(prefix) && f != folderPath) {
        if (seen.add(f)) result.add(f);
      }
    }
    return result;
  }

  /// 重命名文件夹（只更新末级名称，保留层级结构）
  Future<void> renameFolder(String oldName, String newName) async {
    VideoManifest.invalidateCache();
    final parentPath = VideoManifest.getParentFolderPath(oldName);
    final newPath = parentPath.isEmpty ? newName : '$parentPath/$newName';

    final records = await VideoManifest.loadRecords();

    for (final r in records) {
      if (r.folder == oldName) {
        await VideoManifest.moveRecord(r.id, newPath);
      }
    }

    final descendants = await _getDescendantFolders(oldName);
    for (final desc in descendants) {
      final suffix = desc.substring(oldName.length);
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await VideoManifest.moveRecord(r.id, newDescPath);
        }
      }
    }

    await VideoManifest.addFolder(newPath);
    await VideoManifest.removeFolderFromCache(oldName);

    await loadRecords();
  }

  /// 移动文件夹（保持层级结构，整体搬入目标文件夹）
  Future<void> moveFolder(String sourceName, String targetParent) async {
    VideoManifest.invalidateCache();
    final baseName = VideoManifest.getFolderBaseName(sourceName);
    final newPath = targetParent.isEmpty ? baseName : '$targetParent/$baseName';

    final records = await VideoManifest.loadRecords();

    for (final r in records) {
      if (r.folder == sourceName) {
        await VideoManifest.moveRecord(r.id, newPath);
      }
    }

    final descendants = await _getDescendantFolders(sourceName);
    for (final desc in descendants) {
      final suffix = desc.substring(sourceName.length);
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await VideoManifest.moveRecord(r.id, newDescPath);
        }
      }
    }

    await VideoManifest.removeFolderFromCache(sourceName);
    for (final desc in descendants) {
      await VideoManifest.removeFolderFromCache(desc);
    }

    await VideoManifest.addFolder(newPath);
    if (targetParent.isNotEmpty) {
      await VideoManifest.addFolder(targetParent);
    }

    await loadRecords();
  }

  /// 复制文件夹（保持层级结构，整体复制到目标文件夹）
  Future<void> copyFolder(String sourceName, String targetParent) async {
    final baseName = VideoManifest.getFolderBaseName(sourceName);
    final newPath = targetParent.isEmpty ? baseName : '$targetParent/$baseName';

    final records = await VideoManifest.loadRecords();

    for (final r in records) {
      if (r.folder == sourceName) {
        await VideoManifest.addRecord(VideoRecord(
          name: r.name,
          hash: r.hash,
          format: r.format,
          createdAt: DateTime.now(),
          size: r.size,
          folder: newPath,
          duration: r.duration,
        ));
      }
    }

    final descendants = await _getDescendantFolders(sourceName);
    for (final desc in descendants) {
      final suffix = desc.substring(sourceName.length);
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await VideoManifest.addRecord(VideoRecord(
            name: r.name,
            hash: r.hash,
            format: r.format,
            createdAt: DateTime.now(),
            size: r.size,
            folder: newDescPath,
            duration: r.duration,
          ));
        }
      }
    }

    await VideoManifest.addFolder(newPath);
    if (targetParent.isNotEmpty) {
      await VideoManifest.addFolder(targetParent);
    }

    await loadRecords();
  }
}

// ============================================================================
// 视图模式 Notifier（持久化到 SharedPreferences）
// ============================================================================

class VideoViewModeNotifier extends StateNotifier<bool> {
  VideoViewModeNotifier() : super(false);

  static const String _storageKey = 'video_view_mode';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_storageKey) ?? false;
    } catch (e) {
      debugPrint('VideoViewModeNotifier.load error: $e');
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
      debugPrint('VideoViewModeNotifier._persist error: $e');
    }
  }
}
