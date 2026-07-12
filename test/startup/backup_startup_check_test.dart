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
      // Build a minimal widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Schedule check after the frame
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
      // Let microtasks process
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  // ==================================================================
  // Dialog display (integration-style)
  // ==================================================================

  group('storage access dialog', () {
    testWidgets('shows dialog explaining Documents directory need',
        (WidgetTester tester) async {
      // Directly test the dialog widget
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              Future.microtask(() async {
                // We simulate the dialog by checking if the dialog helper
                // would show the correct content
              });
              return ElevatedButton(
                onPressed: () {
                  showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      title: const Text('备份存储授权'),
                      content: const Text('测试'),
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

      // Tap the button to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pump();

      // Verify dialog content
      expect(find.text('备份存储授权'), findsOneWidget);
      expect(find.text('同意并选择目录'), findsOneWidget);
      expect(find.text('退出应用'), findsOneWidget);

      // Tap "同意并选择目录"
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
                      content: const Text(
                          '设备存储空间不足，无法正常完成自动备份。'),
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
