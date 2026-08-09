import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/startup/backup_startup_check.dart';
import 'package:stroom/services/auto_backup_service.dart';
import 'package:stroom/services/backup_location_manager.dart';
import 'package:stroom/services/manifest_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
  });

  // ==================================================================
  // runCheck — basic behavior
  // ==================================================================

  group('runCheck', () {
    testWidgets('returns result with storageReady and autoBackup status',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              Future.microtask(() async {
                final result = await BackupStartupCheck.runCheck(context);
                // In test environment (non-Android, temp dir),
                // storage should be ready and backup should succeed
                expect(result.storageReady, isTrue);
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  // ==================================================================
  // 真实对话框（visibleForTesting 暴露）— 失败原因分类驱动
  // ==================================================================

  group('backup failed dialog (classified reasons)', () {
    tearDown(() {
      AutoBackupService.lastFailure = null;
    });

    Future<void> pumpAndTrigger(
      WidgetTester tester,
      Future<dynamic> Function(BuildContext) action,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => action(context),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('noSpace reason shows required/free sizes and no re-auth',
        (WidgetTester tester) async {
      AutoBackupService.lastFailure = const BackupFailure(
        reason: BackupFailureReason.noSpace,
        message: '存储空间不足',
        requiredBytes: 200 * 1024 * 1024, // 200MB
        freeBytes: 50 * 1024 * 1024, // 50MB
      );
      bool? result;
      await pumpAndTrigger(
        tester,
        (context) =>
            BackupStartupCheck.showBackupFailedDialog(context, showSkip: false)
                .then((v) => result = v),
      );

      expect(find.text('自动备份失败'), findsOneWidget);
      expect(find.textContaining('存储空间不足'), findsOneWidget);
      expect(find.textContaining('约需 200.0 MB 空间'), findsOneWidget);
      expect(find.textContaining('当前可用 50.0 MB'), findsOneWidget);
      // 非 Android：无「重新授权」按钮
      expect(find.text('重新授权'), findsNothing);
      // 重试按钮存在且返回 true
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('showSkip instructs skip instead of absent retry button',
        (WidgetTester tester) async {
      AutoBackupService.lastFailure = const BackupFailure(
        reason: BackupFailureReason.fileLocked,
        message: '文件被占用',
      );
      bool? result;
      await pumpAndTrigger(
        tester,
        (context) =>
            BackupStartupCheck.showBackupFailedDialog(context, showSkip: true)
                .then((v) => result = v),
      );

      expect(find.textContaining('文件被其他程序占用'), findsOneWidget);
      expect(find.textContaining('跳过'), findsWidgets);
      expect(find.text('重试'), findsNothing, reason: '达到最大重试次数后不应再出现「重试」按钮');
      expect(find.text('重新授权'), findsNothing);
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();
      expect(result, isNull); // 跳过 → null
    });

    testWidgets('permission reason shows platform-appropriate guidance',
        (WidgetTester tester) async {
      AutoBackupService.lastFailure = const BackupFailure(
        reason: BackupFailureReason.permission,
        message: '权限异常',
      );
      await pumpAndTrigger(
        tester,
        (context) =>
            BackupStartupCheck.showBackupFailedDialog(context, showSkip: false),
      );

      expect(find.textContaining('备份目录权限异常'), findsOneWidget);
      // 非 Android 平台：不出现「重新授权」按钮与指引
      expect(find.text('重新授权'), findsNothing);
      expect(find.text('重试'), findsOneWidget);
    });
  });

  // ==================================================================
  // 存储空间不足对话框（真实实现）
  // ==================================================================

  group('storage space dialog (real implementation)', () {
    testWidgets('shows the estimated required size',
        (WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => BackupStartupCheck.showStorageSpaceDialog(
                      context,
                      requiredBytes: 5 * 1024 * 1024)
                  .then((v) => result = v),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump();

      expect(find.text('存储空间不足'), findsOneWidget);
      expect(find.textContaining('约需 5.0 MB 空间'), findsOneWidget);

      await tester.tap(find.text('我已清理，重试'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  // ==================================================================
  // 空间清理提醒（剩余空间 < 5× 备份大小）
  // ==================================================================

  group('space cleanup reminder', () {
    tearDown(() {
      AutoBackupService.lastBackupSizeBytes = null;
      BackupLocationManager.debugFreeSpaceOverride = null;
    });

    testWidgets('shows reminder dialog when free < 5x backup size',
        (WidgetTester tester) async {
      AutoBackupService.lastBackupSizeBytes = 100;
      BackupLocationManager.debugFreeSpaceOverride = () async => 400; // < 500

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  BackupStartupCheck.maybeShowSpaceReminder(context),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump();

      expect(find.text('存储空间提醒'), findsOneWidget);
      expect(find.textContaining('5 倍备份大小的空间'), findsOneWidget);

      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(find.text('存储空间提醒'), findsNothing);
    });

    testWidgets('does not show reminder when free >= 5x backup size',
        (WidgetTester tester) async {
      AutoBackupService.lastBackupSizeBytes = 100;
      BackupLocationManager.debugFreeSpaceOverride = () async => 600; // >= 500

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  BackupStartupCheck.maybeShowSpaceReminder(context),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump();

      expect(find.text('存储空间提醒'), findsNothing);
    });
  });
}
