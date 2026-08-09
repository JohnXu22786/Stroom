import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/auto_backup_service.dart';
import 'package:stroom/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ==================================================================
  // classifyBackupFailure — 失败原因分类
  // ==================================================================

  group('classifyBackupFailure', () {
    test('maps ENOSPC / no space messages to noSpace', () {
      final cases = [
        'FileSystemException: No space left on device, path = /x',
        '写入失败: ENOSPC',
        'insufficient storage space',
        '存储空间不足: 需要约 100 字节, 当前可用 50 字节',
      ];
      for (final c in cases) {
        final f = classifyBackupFailure(c);
        expect(f.reason, BackupFailureReason.noSpace, reason: c);
        expect(f.message, contains('存储空间不足'));
      }
    });

    test('noSpace carries required/free bytes for UI display', () {
      final f = classifyBackupFailure('No space left on device',
          requiredBytes: 1000, freeBytes: 500);
      expect(f.reason, BackupFailureReason.noSpace);
      expect(f.requiredBytes, 1000);
      expect(f.freeBytes, 500);
    });

    test('maps OOM messages to outOfMemory', () {
      final cases = [
        'Out of Memory',
        'OutOfMemoryError',
        'Cannot allocate memory',
        'malloc failed',
      ];
      for (final c in cases) {
        final f = classifyBackupFailure(c);
        expect(f.reason, BackupFailureReason.outOfMemory, reason: c);
      }
    });

    test('maps permission / SAF errors to permission', () {
      final cases = [
        'Permission denied',
        'SAF URI 未配置，无法写入备份文件',
        '未获得正确的备份目录访问权限',
      ];
      for (final c in cases) {
        final f = classifyBackupFailure(c);
        expect(f.reason, BackupFailureReason.permission, reason: c);
      }
    });

    test('maps file-in-use errors to fileLocked', () {
      final cases = [
        '文件被占用，无法删除',
        'The process cannot access the file because it is being used by another process',
        'sharing violation',
      ];
      for (final c in cases) {
        final f = classifyBackupFailure(c);
        expect(f.reason, BackupFailureReason.fileLocked, reason: c);
      }
    });

    test('maps BackupCancelledException to cancelled', () {
      final f = classifyBackupFailure(const BackupCancelledException());
      expect(f.reason, BackupFailureReason.cancelled);
    });

    test('maps unknown errors to other', () {
      final f = classifyBackupFailure('some weird platform error: #42');
      expect(f.reason, BackupFailureReason.other);
      expect(f.detail, contains('#42'));
    });
  });

  // ==================================================================
  // shouldRemindSpaceCleanup — 剩余空间 < 5× 备份大小 → 提醒
  // ==================================================================

  group('shouldRemindSpaceCleanup', () {
    const size = 100; // 备份 100 字节
    test('reminds when free space is below 5x backup size', () {
      expect(shouldRemindSpaceCleanup(backupSizeBytes: size, freeBytes: 499),
          isTrue);
      expect(shouldRemindSpaceCleanup(backupSizeBytes: size, freeBytes: 0),
          isTrue);
    });

    test('does not remind when free space is exactly 5x backup size', () {
      expect(shouldRemindSpaceCleanup(backupSizeBytes: size, freeBytes: 500),
          isFalse);
    });

    test('does not remind when free space exceeds 5x backup size', () {
      expect(shouldRemindSpaceCleanup(backupSizeBytes: size, freeBytes: 501),
          isFalse);
      expect(shouldRemindSpaceCleanup(backupSizeBytes: size, freeBytes: 100000),
          isFalse);
    });

    test('guards invalid inputs', () {
      expect(
          shouldRemindSpaceCleanup(backupSizeBytes: 0, freeBytes: 0), isFalse);
      expect(shouldRemindSpaceCleanup(backupSizeBytes: size, freeBytes: -1),
          isFalse);
    });
  });

  // ==================================================================
  // AutoBackupService.checkSpaceReminder — 端到端提醒判定
  // ==================================================================

  group('AutoBackupService.checkSpaceReminder', () {
    tearDown(() {
      AutoBackupService.debugFreeSpaceOverride = null;
      AutoBackupService.lastBackupSizeBytes = null;
    });

    test('returns reminder info when free < 5x backup size', () async {
      AutoBackupService.lastBackupSizeBytes = 100;
      AutoBackupService.debugFreeSpaceOverride = () async => 400;
      final reminder = await AutoBackupService.checkSpaceReminder();
      expect(reminder, isNotNull);
      expect(reminder!.backupSizeBytes, 100);
      expect(reminder.freeBytes, 400);
    });

    test('returns null when free >= 5x backup size', () async {
      AutoBackupService.lastBackupSizeBytes = 100;
      AutoBackupService.debugFreeSpaceOverride = () async => 500;
      final reminder = await AutoBackupService.checkSpaceReminder();
      expect(reminder, isNull);
    });

    test('returns null when no backup size recorded', () async {
      AutoBackupService.lastBackupSizeBytes = null;
      AutoBackupService.debugFreeSpaceOverride = () async => 0;
      final reminder = await AutoBackupService.checkSpaceReminder();
      expect(reminder, isNull);
    });
  });
}
