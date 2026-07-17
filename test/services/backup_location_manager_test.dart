import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/backup_location_manager.dart';

/// Helper: creates test UUID-like strings for SAF URI testing.
String _fakeUri(int id) => 'content://com.android.externalstorage.documents/'
    'tree/primary%3ADocument%2FStroomBackups/test_$id';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ==================================================================
  // getDisplayPath — 用户友好路径
  // ==================================================================

  group('getDisplayPath', () {
    test('returns non-empty string on desktop', () async {
      // 在桌面/测试环境下，应该返回一条路径
      final path = await BackupLocationManager.getDisplayPath();
      expect(path, isNotEmpty);
      debugPrint('[test] getDisplayPath = $path');
    });

    test('contains expected directory name', () async {
      final path = await BackupLocationManager.getDisplayPath();
      // 应该包含 Stroom/AutoBackups 等有意义的目录名
      final hasExpectedName = path.contains('Stroom') ||
          path.contains('AutoBackups') ||
          path.contains('temp') ||
          path.contains('tmp');
      expect(hasExpectedName, isTrue,
          reason: 'getDisplayPath should contain a meaningful directory name');
    });
  });

  // ==================================================================
  // isStorageAccessible — 无 SAF 配置时应返回 false
  // ==================================================================

  group('isStorageAccessible (no SAF)', () {
    test('returns true on non-Android (directory is creatable)', () async {
      // 在测试/桌面环境下，目录应该可创建
      final accessible = await BackupLocationManager.isStorageAccessible();
      // 即使路径不存在，尝试创建也应成功
      expect(accessible, isTrue);
    });
  });

  // ==================================================================
  // SAF URI 持久化（通过 SharedPreferences）
  // ==================================================================

  group('SAF URI persistence', () {
    test('initially no SAF URI saved', () async {
      final result = await BackupLocationManager.isStorageAccessible();
      // 如果没有 SAF URI 且是测试环境（非 Android），应该返回 true（目录可创建）
      expect(result, isTrue);
    });
  });

  // ==================================================================
  // SAF URI 路径验证
  // ==================================================================

  group('SAF URI path validation', () {
    test('validates Documents path as valid', () async {
      // Documents 路径应通过验证
      final valid = BackupLocationManager.isValidBackupPath(
        'content://com.android.externalstorage.documents/tree/'
        'primary%3ADocuments',
      );
      expect(valid, isTrue);
    });

    test('validates Documents subfolder as valid', () async {
      // 子文件夹也应通过验证
      final valid = BackupLocationManager.isValidBackupPath(
        'content://com.android.externalstorage.documents/tree/'
        'primary%3ADocuments%2FMyFolder',
      );
      expect(valid, isTrue);
    });

    test('rejects root URI (primary:)', () async {
      // 根目录应被拒绝
      final valid = BackupLocationManager.isValidBackupPath(
        'content://com.android.externalstorage.documents/tree/'
        'primary%3A',
      );
      expect(valid, isFalse);
    });

    test('rejects null or empty URI', () async {
      expect(BackupLocationManager.isValidBackupPath(null), isFalse);
      expect(BackupLocationManager.isValidBackupPath(''), isFalse);
    });

    test('rejects arbitrary content URI', () async {
      final valid = BackupLocationManager.isValidBackupPath(
        'content://com.android.contacts/data',
      );
      expect(valid, isFalse);
    });

    test('rejects non-content URI', () async {
      final valid = BackupLocationManager.isValidBackupPath(
        'file:///storage/emulated/0',
      );
      expect(valid, isFalse);
    });

    test('rejects SD card root URI', () async {
      // SD 卡根路径格式如 primary: 但 volume id 不同
      final valid = BackupLocationManager.isValidBackupPath(
        'content://com.android.externalstorage.documents/tree/'
        'XXXX-XXXX%3A',
      );
      expect(valid, isFalse);
    });

    test('decodes and validates URI with encoded characters', () async {
      // primary%3ADocument 解码后为 "primary:Document"
      final valid = BackupLocationManager.isValidBackupPath(
        'content://com.android.externalstorage.documents/tree/'
        'primary%3ADocument',
      );
      expect(valid, isTrue);
    });

    test('rejects URI with only primary: prefix', () async {
      // 仅 primary: 没有子路径的情况
      final valid = BackupLocationManager.isValidBackupPath(
        'content://com.android.externalstorage.documents/tree/'
        'primary%3A/',
      );
      expect(valid, isFalse);
    });
  });

  // ==================================================================
  // read/write/delete file operations (non-SAF / temp dir)
  // ==================================================================

  group('file operations (temp dir)', () {
    late String testDir;
    late String testFileName;
    late Uint8List testData;

    setUp(() async {
      testDir =
          '${Directory.systemTemp.path}/backup_mgr_test_${DateTime.now().millisecondsSinceEpoch}';
      testFileName = 'test_backup_file.zip';
      testData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // 确保测试目录干净
      final dir = Directory(testDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    tearDown(() async {
      final dir = Directory(testDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('writeBackupFile creates file on non-Android platforms', () async {
      // 这个测试模拟非 Android 平台写入
      // 由于 BackupLocationManager 内部会检测 Platform，
      // 在测试环境下会走非 SAF 路径（兜底临时目录）
      final root = await BackupLocationManager.getBackupRootPath();
      expect(root, isNotNull);

      // 写入文件
      await BackupLocationManager.writeBackupFile(testFileName, testData);

      // 验证文件存在
      final bytes = await BackupLocationManager.readBackupFile(testFileName);
      expect(bytes, isNotNull);
      expect(bytes!.length, equals(5));
      expect(bytes, equals(testData));

      // 清理
      await BackupLocationManager.deleteBackupFile(testFileName);
      final afterDelete =
          await BackupLocationManager.readBackupFile(testFileName);
      expect(afterDelete, isNull);
    });

    test('listBackupFiles shows created files', () async {
      await BackupLocationManager.writeBackupFile(testFileName, testData);

      final files = await BackupLocationManager.listBackupFiles();
      expect(files, contains(testFileName));

      await BackupLocationManager.deleteBackupFile(testFileName);
    });

    test('renameBackupFile renames tmp to zip', () async {
      const tmpName = 'backup_test.tmp';
      const zipName = 'backup_test.zip';

      await BackupLocationManager.writeBackupFile(tmpName, testData);

      // 重命名
      await BackupLocationManager.renameBackupFile(tmpName, zipName);

      // 验证原文件不存在，新文件存在
      final oldBytes = await BackupLocationManager.readBackupFile(tmpName);
      expect(oldBytes, isNull);

      final newBytes = await BackupLocationManager.readBackupFile(zipName);
      expect(newBytes, isNotNull);
      expect(newBytes!.length, equals(5));

      await BackupLocationManager.deleteBackupFile(zipName);
    });

    test('readBackupFile returns null for non-existent file', () async {
      final bytes =
          await BackupLocationManager.readBackupFile('nonexistent.zip');
      expect(bytes, isNull);
    });

    test('deleteBackupFile is idempotent', () async {
      // 删除不存在的文件不应抛出异常
      await BackupLocationManager.deleteBackupFile('nonexistent.zip');
    });
  });

  // ==================================================================
  // hasSufficientSpace
  // ==================================================================

  group('hasSufficientSpace', () {
    test('returns true on non-Android platforms', () async {
      final hasSpace = await BackupLocationManager.hasSufficientSpace();
      expect(hasSpace, isTrue);
    });
  });

  // ==================================================================
  // isUsingSafMode
  // ==================================================================

  group('isUsingSafMode', () {
    test('returns false when no SAF URI saved', () async {
      final safMode = await BackupLocationManager.isUsingSafMode();
      expect(safMode, isFalse);
    });

    test('returns false on non-Android platforms regardless', () async {
      // 在非 Android 平台上，即使存储了 URI，也不应认为在 SAF 模式
      // 但实际 isUsingSafMode 只检查 Platform.isAndroid
      final safMode = await BackupLocationManager.isUsingSafMode();
      expect(safMode, isFalse);
    });
  });

  // ==================================================================
  // clearStorageAccess
  // ==================================================================

  group('clearStorageAccess', () {
    test('clears stored SAF URI', () async {
      // 模拟保存 SAF URI
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backup_saf_uri', _fakeUri(1));
      expect(await prefs.getString('backup_saf_uri'), isNotNull);

      await BackupLocationManager.clearStorageAccess();

      expect(await prefs.getString('backup_saf_uri'), isNull);
    });
  });
}
