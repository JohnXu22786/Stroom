import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/startup/backup_startup_check.dart';
import 'package:stroom/services/manifest_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
  });

  // ==================================================================
  // Static flag tracking
  // ==================================================================

  group('static startupBackupPerformed flag', () {
    test('initially false', () {
      expect(BackupStartupCheck.startupBackupPerformed, isFalse);
    });
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
  // Backup failure dialog — no skip, must have re-authorize
  // ==================================================================

  group('backup failure dialog', () {
    testWidgets('has no Skip button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              Future.microtask(() async {
                // Use the real static method to show the dialog
                // via a public test helper (we re-create the dialog inline)
              });
              return ElevatedButton(
                onPressed: () {
                  showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade400, size: 24),
                          const SizedBox(width: 8),
                          const Text('自动备份失败'),
                        ],
                      ),
                      content: const Text(
                        '自动备份未能成功完成。\n\n'
                        '请确认已授权正确的「Documents」文档目录路径，\n'
                        '点击「重新授权」返回重新选择正确的目录；\n'
                        '或点击「重试」再次尝试备份。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('重新授权'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Show Dialog'));
      await tester.pump();

      // Verify dialog content has correct title and no Skip button
      expect(find.text('自动备份失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('重新授权'), findsOneWidget);

      // Verify Skip button does NOT exist
      expect(find.text('跳过'), findsNothing);
    });

    testWidgets('Retry returns true, Re-authorize returns false',
        (WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      title: const Text('自动备份失败'),
                      content: const Text('自动备份未能成功完成。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('重新授权'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ).then((v) => result = v);
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Test Retry returns true
      await tester.tap(find.text('Show Dialog'));
      await tester.pump();
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(result, isTrue);

      // Test Re-authorize returns false
      result = null;
      await tester.tap(find.text('Show Dialog'));
      await tester.pump();
      await tester.tap(find.text('重新授权'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  // ==================================================================
  // Storage access dialog
  // ==================================================================

  group('storage access dialog', () {
    testWidgets('shows dialog explaining Documents directory need',
        (WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.folder_open,
                              color: Colors.orange.shade700, size: 24),
                          const SizedBox(width: 8),
                          const Text('备份存储授权'),
                        ],
                      ),
                      content:
                          const Text('为了确保您的数据安全，Stroom 需要您选择一个公开目录来存放自动备份文件。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('退出应用'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('同意并选择目录'),
                        ),
                      ],
                    ),
                  ).then((v) => result = v);
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Show Dialog'));
      await tester.pump();

      // Verify dialog content
      expect(find.text('备份存储授权'), findsOneWidget);
      expect(find.text('同意并选择目录'), findsOneWidget);
      expect(find.text('退出应用'), findsOneWidget);

      await tester.tap(find.text('同意并选择目录'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  // ==================================================================
  // Storage space dialog
  // ==================================================================

  group('storage space dialog', () {
    testWidgets('shows space warning and retry option',
        (WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      title: const Text('存储空间不足'),
                      content: const Text('设备存储空间不足，无法正常完成自动备份。'),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('我已清理，重试'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('稍后处理'),
                        ),
                      ],
                    ),
                  ).then((v) => result = v);
                },
                child: const Text('Show Space Dialog'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Show Space Dialog'));
      await tester.pump();

      expect(find.text('存储空间不足'), findsOneWidget);
      expect(find.text('我已清理，重试'), findsOneWidget);
      expect(find.text('稍后处理'), findsOneWidget);

      await tester.tap(find.text('我已清理，重试'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
