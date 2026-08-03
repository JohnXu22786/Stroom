import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/image_manifest.dart';

// ============================================================================
// 图片记录列表
// ============================================================================

final imageRecordsProvider =
    StateNotifierProvider<ImageRecordsNotifier, List<ImageRecord>>(
  (ref) => ImageRecordsNotifier(),
);

// ============================================================================
// 文件夹列表
// ============================================================================

final imageFolderListProvider =
    StateNotifierProvider<ImageFolderListNotifier, Set<String>>(
  (ref) => ImageFolderListNotifier(),
);

// ============================================================================
// 视图模式（false = 列表，true = 缩略图/网格）
// ============================================================================

final imageViewModeProvider =
    StateNotifierProvider<ImageViewModeNotifier, bool>((ref) {
  final notifier = ImageViewModeNotifier();
  notifier.load();
  return notifier;
});

// ============================================================================
// 文件夹列表 Notifier
// ============================================================================

class ImageFolderListNotifier extends StateNotifier<Set<String>> {
  ImageFolderListNotifier() : super({});

  Future<void> loadFolders() async {
    final folders = await ImageManifest.getAllFolders();
    state = folders;
  }

  Future<void> addFolder(String name) async {
    await ImageManifest.addFolder(name);
    await loadFolders();
  }

  Future<void> removeFolder(String name) async {
    await ImageManifest.removeFolder(name);
    await loadFolders();
  }
}

// ============================================================================
// 图片记录 Notifier
// ============================================================================

class ImageRecordsNotifier extends StateNotifier<List<ImageRecord>> {
  ImageRecordsNotifier() : super([]);

  Future<void> loadRecords() async {
    final records = await ImageManifest.loadRecords();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = List<ImageRecord>.from(records);
  }

  Future<void> addRecord(ImageRecord record) async {
    await ImageManifest.addRecord(record);
    await loadRecords();
  }

  Future<void> deleteRecord(String id) async {
    await ImageManifest.deleteRecord(id);
    await loadRecords();
  }

  Future<void> deleteRecords(List<String> ids) async {
    await ImageManifest.deleteRecords(ids);
    await loadRecords();
  }

  Future<void> renameRecord(String id, String newName) async {
    ImageManifest.invalidateCache();
    await ImageManifest.renameRecord(id, newName);
    await loadRecords();
  }

  Future<void> moveRecord(String id, String targetFolder) async {
    await ImageManifest.moveRecord(id, targetFolder);
    await loadRecords();
  }

  // ====================================================================
  // 文件夹管理
  // ====================================================================

  /// 获取所有有效文件夹（含空文件夹 + 记录中存在的文件夹）
  Future<Set<String>> getFolders() async {
    return ImageManifest.getAllFolders();
  }

  /// 创建文件夹
  Future<void> createFolder(String folderName) async {
    await ImageManifest.addFolder(folderName);
  }

  /// 删除文件夹（同时删除内部所有记录）
  Future<void> deleteFolder(String folderName) async {
    await ImageManifest.removeFolder(folderName);
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
    // Also include empty folders from cache
    final allFolders = await ImageManifest.getAllFolders();
    for (final f in allFolders) {
      if (f.startsWith(prefix) && f != folderPath) {
        if (seen.add(f)) result.add(f);
      }
    }
    return result;
  }

  /// 重命名文件夹（只更新末级名称，保留层级结构）
  Future<void> renameFolder(String oldName, String newName) async {
    ImageManifest.invalidateCache();
    final parentPath = ImageManifest.getParentFolderPath(oldName);
    final newNameTrimmed = newName.trim();
    final newPath =
        parentPath.isEmpty ? newNameTrimmed : '$parentPath/$newNameTrimmed';

    // 空源 / 非法名 / 无操作重命名（新路径与原路径相同）或自嵌套重命名：
    // 直接返回，否则 removeFolderFromCache 会把记录误移到根目录
    if (oldName.isEmpty ||
        ImageManifest.validateFolderName(newNameTrimmed) != null ||
        newPath == oldName ||
        newPath.startsWith('$oldName/')) {
      return;
    }

    // 目标位置（或其下）已存在同名文件夹：拒绝（防御性，UI 层已阻止），
    // 避免两个文件夹被静默合并
    final existing = await ImageManifest.getAllFolders();
    if (existing.any((f) => f == newPath || f.startsWith('$newPath/'))) return;

    final records = await ImageManifest.loadRecords();

    // 更新 oldName 本身的记录
    for (final r in records) {
      if (r.folder == oldName) {
        await ImageManifest.moveRecord(r.id, newPath);
      }
    }

    // 更新所有后代文件夹的记录
    final descendants = await _getDescendantFolders(oldName);
    for (final desc in descendants) {
      final suffix = desc.substring(oldName.length);
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await ImageManifest.moveRecord(r.id, newDescPath);
        }
      }
      // Empty subfolders (no records) must stay in the folder cache; otherwise the old-path cleanup would drop their paths.
      await ImageManifest.addFolder(newDescPath);
    }

    // 将新路径加入文件夹缓存
    await ImageManifest.addFolder(newPath);

    // 移除旧路径的文件夹缓存
    await ImageManifest.removeFolderFromCache(oldName);

    await loadRecords();
  }

  /// 移动文件夹（保持层级结构，整体搬入目标文件夹）
  Future<void> moveFolder(String sourceName, String targetParent) async {
    ImageManifest.invalidateCache();
    final baseName = ImageManifest.getFolderBaseName(sourceName);
    // 规范化目标父路径（去首尾空白与尾部斜杠），'' 表示根目录
    final targetParentClean =
        targetParent.trim().replaceAll(RegExp(r'/+$'), '');
    final newPath =
        targetParentClean.isEmpty ? baseName : '$targetParentClean/$baseName';

    // 防止空源 / 纯空白目标 / 无操作移动（目标为当前位置）或移动到
    // 自身/子文件夹：否则 removeFolderFromCache 会把记录误移到根目录，
    // 造成数据损坏
    if (sourceName.isEmpty ||
        (targetParent.isNotEmpty && targetParentClean.isEmpty) ||
        newPath == sourceName ||
        newPath.startsWith('$sourceName/')) {
      return;
    }

    // 目标位置（或其下）已存在同名文件夹：拒绝，避免静默合并
    final existing = await ImageManifest.getAllFolders();
    if (existing.any((f) => f == newPath || f.startsWith('$newPath/'))) return;

    final records = await ImageManifest.loadRecords();

    // 移动 sourceName 本身的记录到 newPath
    for (final r in records) {
      if (r.folder == sourceName) {
        await ImageManifest.moveRecord(r.id, newPath);
      }
    }

    // 移动所有后代文件夹的记录
    final descendants = await _getDescendantFolders(sourceName);
    for (final desc in descendants) {
      final suffix = desc.substring(sourceName.length);
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await ImageManifest.moveRecord(r.id, newDescPath);
        }
      }
      // Empty subfolders (no records) must stay in the folder cache; otherwise the old-path cleanup would drop their paths.
      await ImageManifest.addFolder(newDescPath);
    }

    // 清理旧文件夹缓存（不删除记录）
    await ImageManifest.removeFolderFromCache(sourceName);
    for (final desc in descendants) {
      await ImageManifest.removeFolderFromCache(desc);
    }

    // 添加新文件夹缓存
    await ImageManifest.addFolder(newPath);
    if (targetParentClean.isNotEmpty) {
      await ImageManifest.addFolder(targetParentClean);
      // 空文件夹移动/复制不经过 moveRecord/addRecord，
      // 祖先目录不会被自动跟踪，需逐级补齐
      var ancestor = ImageManifest.getParentFolderPath(targetParentClean);
      while (ancestor.isNotEmpty) {
        await ImageManifest.addFolder(ancestor);
        ancestor = ImageManifest.getParentFolderPath(ancestor);
      }
    }

    await loadRecords();
  }

  /// 复制文件夹（保持层级结构，整体复制到目标文件夹）
  Future<void> copyFolder(String sourceName, String targetParent) async {
    final baseName = ImageManifest.getFolderBaseName(sourceName);
    // 规范化目标父路径（去首尾空白与尾部斜杠），'' 表示根目录
    final targetParentClean =
        targetParent.trim().replaceAll(RegExp(r'/+$'), '');
    final newPath =
        targetParentClean.isEmpty ? baseName : '$targetParentClean/$baseName';

    // 防止空源 / 纯空白目标 / 复制到自身/子文件夹（或原地复制），
    // 避免文件夹内出现重复记录与自我嵌套
    if (sourceName.isEmpty ||
        (targetParent.isNotEmpty && targetParentClean.isEmpty) ||
        newPath == sourceName ||
        newPath.startsWith('$sourceName/')) {
      return;
    }

    // 目标位置（或其下）已存在同名文件夹：拒绝，避免重复复制/合并
    final existing = await ImageManifest.getAllFolders();
    if (existing.any((f) => f == newPath || f.startsWith('$newPath/'))) return;

    final records = await ImageManifest.loadRecords();

    // 复制 sourceName 本身的记录
    for (final r in records) {
      if (r.folder == sourceName) {
        await ImageManifest.addRecord(ImageRecord(
          name: r.name,
          hash: r.hash,
          format: r.format,
          createdAt: DateTime.now(),
          size: r.size,
          folder: newPath,
        ));
      }
    }

    // 复制所有后代文件夹的记录
    final descendants = await _getDescendantFolders(sourceName);
    for (final desc in descendants) {
      final suffix = desc.substring(sourceName.length);
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await ImageManifest.addRecord(ImageRecord(
            name: r.name,
            hash: r.hash,
            format: r.format,
            createdAt: DateTime.now(),
            size: r.size,
            folder: newDescPath,
          ));
        }
      }
      // 空子文件夹（无记录）也需要保留在缓存中
      await ImageManifest.addFolder(newDescPath);
    }

    // 确保新路径在文件夹缓存中
    await ImageManifest.addFolder(newPath);
    if (targetParentClean.isNotEmpty) {
      await ImageManifest.addFolder(targetParentClean);
      // 空文件夹移动/复制不经过 moveRecord/addRecord，
      // 祖先目录不会被自动跟踪，需逐级补齐
      var ancestor = ImageManifest.getParentFolderPath(targetParentClean);
      while (ancestor.isNotEmpty) {
        await ImageManifest.addFolder(ancestor);
        ancestor = ImageManifest.getParentFolderPath(ancestor);
      }
    }

    await loadRecords();
  }
}

// ============================================================================
// 视图模式 Notifier（持久化到 SharedPreferences）
// ============================================================================

class ImageViewModeNotifier extends StateNotifier<bool> {
  ImageViewModeNotifier() : super(false);

  static const String _storageKey = 'image_view_mode';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_storageKey) ?? false;
    } catch (e) {
      debugPrint('ImageViewModeNotifier.load error: $e');
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
      debugPrint('ImageViewModeNotifier._persist error: $e');
    }
  }
}
