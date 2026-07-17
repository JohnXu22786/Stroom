import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ====================================================================
// BackupLocationManager — 跨平台备份存储位置管理
// ====================================================================
//
// 根据平台策略统一管理备份文件的存放位置，并提供文件读写操作抽象。
//
// 各平台策略：
// - Android: 使用 SAF（Storage Access Framework）获取一个公开目录
//   （优先 Documents），调用 takePersistableUriPermission 固化权限，
//   所有文件操作通过 MethodChannel 转发到原生层。
//   备份文件存入 Documents/Stroom/AutoBackups。
// - iOS: 使用应用的 Documents 目录（通过 UIFileSharingEnabled 暴露
//   在文件 App 中）。
// - Desktop (Win/Mac/Linux): 统一使用 ~/Documents/StroomData/AutoBackup。
// - Web: 不支持本地自动备份，所有操作返回空/跳过。
// ====================================================================

/// 跨平台备份位置管理器。
class BackupLocationManager {
  BackupLocationManager._();

  static const String _androidSafUriKey = 'backup_saf_uri';

  /// Android SAF 专用 MethodChannel。
  static const MethodChannel _safChannel =
      MethodChannel('com.johntsui.stroom/saf');

  /// 备份目录路径（所有平台统一，相对于用户选择的 Documents 目录）。
  /// 使用 Stroom/AutoBackups 两级目录结构，便于用户识别和管理。
  static const String _backupDirName = 'Stroom/AutoBackups';

  // ================================================================
  // 路径解析
  // ================================================================

  /// 获取备份根目录路径（用于非 Android SAF 平台）。
  ///
  /// 返回格式化的路径字符串，供 dart:io 直接使用。
  /// Android 上如果已配置 SAF URI，返回的是虚拟路径用于 UI 显示。
  /// Web 上返回 null。
  static Future<String?> getBackupRootPath() async {
    if (kIsWeb) return null;

    // 测试环境
    try {
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        return '${Directory.systemTemp.path}/stroom_backup_test';
      }
    } catch (e) {
      debugPrint('[BackupLocationManager] 检查测试环境失败: $e');
    }

    // Android: 使用 SAF URI（如果已配置）
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          final uri = await _getSavedSafUri();
          if (uri != null) {
            // 返回虚拟路径，用于 Dart 侧区分 SAF 模式
            return 'saf://$uri/$_backupDirName';
          }
          // SAF URI 未配置，返回 null 表示需要用户授权
          return null;
        }
      } catch (e) {
        debugPrint('[BackupLocationManager] 检查 Android SAF 平台失败: $e');
      }
    }

    // Desktop: ~/Documents/StroomData/AutoBackup
    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          return p.join(userProfile, 'Documents', 'StroomData', 'AutoBackup');
        }
      }
    } catch (e) {
      debugPrint('[BackupLocationManager] 获取 Windows 备份路径失败: $e');
    }

    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          return p.join(home, 'Documents', 'StroomData', 'AutoBackup');
        }
      }
    } catch (e) {
      debugPrint('[BackupLocationManager] 获取 macOS/Linux 备份路径失败: $e');
    }

    // iOS: 应用 Documents 目录（通过文件 App 可访问）
    try {
      if (Platform.isIOS) {
        final docsDir = await getApplicationDocumentsDirectory();
        return p.join(docsDir.path, _backupDirName);
      }
    } catch (e) {
      debugPrint('[BackupLocationManager] 获取 iOS 备份路径失败: $e');
    }

    // 兜底：系统临时目录
    try {
      return '${Directory.systemTemp.path}/$_backupDirName';
    } catch (e) {
      debugPrint('[BackupLocationManager] 获取系统临时目录失败: $e');
      return '/tmp/$_backupDirName';
    }
  }

  /// 获取用于 UI 显示的用户友好路径。
  static Future<String> getDisplayPath() async {
    if (kIsWeb) return 'Web 平台不支持本地备份';

    // Android
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          final uri = await _getSavedSafUri();
          if (uri != null) {
            return 'Documents/Stroom/AutoBackups (点击重新选择目录)';
          }
          return '尚未选择备份目录，请在启动流程中授权';
        }
      } catch (e) {
        debugPrint('[BackupLocationManager] getDisplayPath 检查 Android 失败: $e');
      }
    }

    // Desktop
    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          return p.join(userProfile, 'Documents', 'StroomData', 'AutoBackup');
        }
      }
    } catch (e) {
      debugPrint('[BackupLocationManager] getDisplayPath 检查 Windows 失败: $e');
    }

    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          return p.join(home, 'Documents', 'StroomData', 'AutoBackup');
        }
      }
    } catch (e) {
      debugPrint(
          '[BackupLocationManager] getDisplayPath 检查 macOS/Linux 失败: $e');
    }

    // iOS
    try {
      if (Platform.isIOS) {
        final docsDir = await getApplicationDocumentsDirectory();
        return p.join(docsDir.path, _backupDirName);
      }
    } catch (e) {
      debugPrint('[BackupLocationManager] getDisplayPath 检查 iOS 失败: $e');
    }

    final fallback = await getBackupRootPath();
    return fallback ?? '/tmp/Stroom/AutoBackups';
  }

  // ================================================================
  // 存储访问检查与授权
  // ================================================================

  /// 检查备份存储是否可访问。
  ///
  /// 对于 Android SAF：检查存储的 URI 是否仍然有效。
  /// 对于其他平台：检查目录是否存在或可创建。
  static Future<bool> isStorageAccessible() async {
    if (kIsWeb) return false;

    // Android SAF
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          final uri = await _getSavedSafUri();
          if (uri == null) return false;

          // 验证已保存的路径是否为有效文档路径（非根目录）
          // 防止之前错误授权了根目录后，启动时跳过授权弹窗
          if (!isValidBackupPath(uri)) {
            debugPrint('[BackupLocationManager] 已保存的 SAF URI 无效（根目录）'
                '，需要重新授权: $uri');
            await _clearSafUri();
            return false;
          }

          return _checkSafAccess(uri);
        }
      } catch (e) {
        debugPrint('[BackupLocationManager] 检查 SAF 访问失败: $e');
        return false;
      }
    }

    // 其他平台：尝试获取路径并检查目录
    try {
      final path = await getBackupRootPath();
      if (path == null) return false;
      final dir = Directory(path);
      if (await dir.exists()) return true;
      // 尝试创建目录，如果成功则认为可访问
      await dir.create(recursive: true);
      return true;
    } catch (e) {
      debugPrint('[BackupLocationManager] 存储不可访问: $e');
      return false;
    }
  }

  /// 检查 SAF URI 是否指向有效的文档路径（非根目录）。
  ///
  /// 确保用户选择的不是存储根目录（如 primary:），
  /// 而是至少包含一个子目录（如 primary:Documents 或更深的路径）。
  ///
  /// [uri] 为 SAF tree URI 字符串，如
  /// `content://com.android.externalstorage.documents/tree/primary%3ADocuments`。
  /// 传入 null 或空字符串返回 false。
  static bool isValidBackupPath(String? uri) {
    if (uri == null || uri.isEmpty) return false;

    try {
      // 提取 URI 中 "tree/" 后的路径段
      const treePrefix = 'tree/';
      final treeIndex = uri.indexOf(treePrefix);
      if (treeIndex == -1) return false;

      final encodedPath = uri.substring(treeIndex + treePrefix.length);
      if (encodedPath.isEmpty) return false;

      // URI 解码（处理 %3A → :, %2F → / 等）
      final decodedPath = Uri.decodeComponent(encodedPath);

      // 拒绝根路径：路径格式通常为 "primary:Documents" 或 "XXXX-XXXX:folder"
      // 根路径则为 "primary:" 或 "XXXX-XXXX:" — 冒号后无有效内容
      // 取冒号后的部分，如果为空或仅包含 / 和空格则判定为根路径
      final colonIndex = decodedPath.indexOf(':');
      if (colonIndex == -1) return false;

      final afterColon = decodedPath.substring(colonIndex + 1);
      final trimmedAfterColon = afterColon.replaceAll('/', '').trim();

      if (trimmedAfterColon.isEmpty) return false;

      return true;
    } catch (e) {
      debugPrint('[BackupLocationManager] URI 路径验证失败: $e');
      return false;
    }
  }

  /// 请求存储访问权限。
  ///
  /// Android: 打开 SAF 目录选择器，引导用户选择 Documents 目录。
  /// 其他平台: 返回 true（路径直接可用）。
  ///
  /// 返回 true 表示授权成功，false 表示失败。
  static Future<bool> requestStorageAccess() async {
    if (kIsWeb) return false;

    // Android SAF: 打开目录选择器
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          try {
            final uri = await _safChannel.invokeMethod<String>('pickDirectory');
            if (uri == null || uri.isEmpty) {
              debugPrint('[BackupLocationManager] 用户取消了 SAF 目录选择');
              return false;
            }

            // 验证选择的路径是否为有效的文档路径（非根目录）
            if (!isValidBackupPath(uri)) {
              debugPrint('[BackupLocationManager] 用户选择了无效路径(根目录)'
                  '，需要重新授权: $uri');
              return false;
            }

            // 保存 URI
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_androidSafUriKey, uri);

            // 验证访问
            final accessible = await _checkSafAccess(uri);
            if (accessible) {
              debugPrint('[BackupLocationManager] SAF 授权成功: $uri');
            } else {
              debugPrint('[BackupLocationManager] SAF URI 无法访问，'
                  '需要重新授权');
              await _clearSafUri();
              return false;
            }
            return accessible;
          } catch (e) {
            debugPrint('[BackupLocationManager] SAF 授权失败: $e');
            return false;
          }
        }
      } catch (e) {
        debugPrint(
            '[BackupLocationManager] requestStorageAccess 检查 Android 失败: $e');
      }
    }

    // 非 Android 平台：路径已固定，直接返回 true
    return true;
  }

  /// 清除已保存的 SAF URI（用于重新授权场景）。
  static Future<void> clearStorageAccess() async {
    await _clearSafUri();
  }

  // ================================================================
  // 文件操作（跨平台抽象）
  // ================================================================

  /// 写入备份文件。
  ///
  /// [relativePath] 是相对于备份根目录的路径（如 backup_xxx.zip）。
  static Future<void> writeBackupFile(
      String relativePath, Uint8List data) async {
    debugPrint('[BackupLocationManager] 写入备份文件: $relativePath');
    if (kIsWeb) {
      throw UnsupportedError('Web 平台不支持本地文件写入');
    }

    // Android SAF
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          final uri = await _getSavedSafUri();
          if (uri == null) {
            throw Exception('SAF URI 未配置，无法写入备份文件');
          }
          await _safChannel.invokeMethod<void>('writeFile', {
            'uri': uri,
            'fileName': relativePath,
            'bytes': data,
          });
          return;
        }
      } catch (e) {
        debugPrint('[BackupLocationManager] SAF 写入失败: $e');
        rethrow;
      }
    }

    // 非 Android 平台
    try {
      final rootPath = await getBackupRootPath();
      if (rootPath == null) {
        throw Exception('无法获取备份根目录');
      }
      final file = File(p.join(rootPath, relativePath));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data);
    } catch (e) {
      debugPrint('[BackupLocationManager] 写入备份文件失败: $relativePath: $e');
      rethrow;
    }
  }

  /// 读取备份文件。
  static Future<Uint8List?> readBackupFile(String relativePath) async {
    debugPrint('[BackupLocationManager] 读取备份文件: $relativePath');
    if (kIsWeb) return null;

    // Android SAF
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          final uri = await _getSavedSafUri();
          if (uri == null) return null;
          final result = await _safChannel.invokeMethod<Uint8List>('readFile', {
            'uri': uri,
            'fileName': relativePath,
          });
          if (result != null) {
            return result;
          }
          return null;
        }
      } catch (e) {
        debugPrint('[BackupLocationManager] SAF 读取失败: $e');
        return null;
      }
    }

    // 非 Android 平台
    try {
      final rootPath = await getBackupRootPath();
      if (rootPath == null) return null;
      final file = File(p.join(rootPath, relativePath));
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('[BackupLocationManager] 读取备份文件失败: $relativePath: $e');
      return null;
    }
  }

  /// 删除备份文件。
  static Future<void> deleteBackupFile(String relativePath) async {
    debugPrint('[BackupLocationManager] 删除备份文件: $relativePath');
    if (kIsWeb) return;

    // Android SAF
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          final uri = await _getSavedSafUri();
          if (uri == null) return;
          await _safChannel.invokeMethod<void>('deleteFile', {
            'uri': uri,
            'fileName': relativePath,
          });
          return;
        }
      } catch (e) {
        debugPrint('[BackupLocationManager] SAF 删除失败: $e');
        return;
      }
    }

    // 非 Android 平台
    try {
      final rootPath = await getBackupRootPath();
      if (rootPath == null) return;
      final file = File(p.join(rootPath, relativePath));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[BackupLocationManager] 删除备份文件失败: $relativePath: $e');
    }
  }

  /// 重命名备份文件（如 .tmp → .zip）。
  static Future<void> renameBackupFile(
      String oldRelativePath, String newRelativePath) async {
    debugPrint(
        '[BackupLocationManager] 重命名备份文件: $oldRelativePath -> $newRelativePath');
    if (kIsWeb) return;

    // Android SAF
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          final uri = await _getSavedSafUri();
          if (uri == null) {
            throw Exception('SAF URI 未配置，无法重命名备份文件');
          }
          await _safChannel.invokeMethod<void>('renameFile', {
            'uri': uri,
            'oldName': oldRelativePath,
            'newName': newRelativePath,
          });
          return;
        }
      } catch (e) {
        debugPrint('[BackupLocationManager] SAF 重命名失败: $e');
        rethrow;
      }
    }

    // 非 Android 平台
    try {
      final rootPath = await getBackupRootPath();
      if (rootPath == null) {
        throw Exception('无法获取备份根目录');
      }
      final oldFile = File(p.join(rootPath, oldRelativePath));
      final newFile = File(p.join(rootPath, newRelativePath));
      if (await oldFile.exists()) {
        await oldFile.rename(newFile.path);
      }
    } catch (e) {
      debugPrint(
          '[BackupLocationManager] 重命名备份文件失败: $oldRelativePath -> $newRelativePath: $e');
      rethrow;
    }
  }

  /// 列出备份目录中的所有文件。
  static Future<List<String>> listBackupFiles() async {
    debugPrint('[BackupLocationManager] 列出备份文件');
    if (kIsWeb) return [];

    // Android SAF
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          final uri = await _getSavedSafUri();
          if (uri == null) return [];
          final result = await _safChannel
              .invokeMethod<List<dynamic>>('listFiles', {'uri': uri});
          if (result != null) {
            return result.cast<String>();
          }
          return [];
        }
      } catch (e) {
        debugPrint('[BackupLocationManager] SAF 列出文件失败: $e');
        return [];
      }
    }

    // 非 Android 平台
    try {
      final rootPath = await getBackupRootPath();
      if (rootPath == null) return [];
      final dir = Directory(rootPath);
      if (!await dir.exists()) return [];
      final entries = await dir.list().toList();
      return entries.whereType<File>().map((f) => p.basename(f.path)).toList();
    } catch (e) {
      debugPrint('[BackupLocationManager] 列出备份文件失败: $e');
      return [];
    }
  }

  /// 检查是否有足够的可用空间。
  ///
  /// 阈值：100MB。
  /// Android SAF 模式下通过 MethodChannel 获取可用空间；
  /// 其他平台因无法从 Dart 层获取精确值，默认返回 true。
  static Future<bool> hasSufficientSpace() async {
    try {
      if (kIsWeb) return false;

      // Android SAF: 通过 MethodChannel 检查
      if (!kIsWeb) {
        try {
          if (Platform.isAndroid) {
            final uri = await _getSavedSafUri();
            if (uri == null) return false;
            final freeBytes =
                await _safChannel.invokeMethod<int>('getFreeSpace', {
              'uri': uri,
            });
            if (freeBytes != null && freeBytes > 0) {
              return freeBytes > 100 * 1024 * 1024; // 100MB
            }
            return true; // 无法检查时默认通过
          }
        } catch (e) {
          debugPrint(
              '[BackupLocationManager] hasSufficientSpace 检查 Android 空间失败: $e');
        }
      }

      // 其他平台无法精确获取可用空间，默认通过
      return true;
    } catch (e) {
      debugPrint('[BackupLocationManager] 检查空间失败: $e');
      return true; // 无法检查时默认通过
    }
  }

  // ================================================================
  // 内部方法
  // ================================================================

  /// 获取已保存的 SAF URI。
  static Future<String?> _getSavedSafUri() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_androidSafUriKey);
    } catch (e) {
      debugPrint('[BackupLocationManager] 获取已保存的 SAF URI 失败: $e');
      return null;
    }
  }

  /// 清除已保存的 SAF URI。
  static Future<void> _clearSafUri() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_androidSafUriKey);
    } catch (e) {
      debugPrint('[BackupLocationManager] 清除已保存的 SAF URI 失败: $e');
    }
  }

  /// 检查 SAF URI 是否仍可访问。
  static Future<bool> _checkSafAccess(String uri) async {
    try {
      final result =
          await _safChannel.invokeMethod<bool>('checkAccess', {'uri': uri});
      return result ?? false;
    } catch (e) {
      debugPrint('[BackupLocationManager] SAF 访问检查失败: $e');
      return false;
    }
  }

  /// 检查是否使用了 SAF 模式（Android）。
  static Future<bool> isUsingSafMode() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final uri = await _getSavedSafUri();
        return uri != null;
      }
    } catch (e) {
      debugPrint('[BackupLocationManager] isUsingSafMode 检查失败: $e');
    }
    return false;
  }
}
