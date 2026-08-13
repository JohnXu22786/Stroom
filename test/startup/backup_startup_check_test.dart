import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';
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

    testWidgets(
        'reminder requires tapping 知道了 to dismiss — tapping the '
        'blank area outside must not close it', (WidgetTester tester) async {
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

      // 点击对话框外空白处：提醒必须保持打开，直到用户点击「知道了」
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('存储空间提醒'), findsOneWidget, reason: '点击空白处不应关闭存储空间提醒');

      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(find.text('存储空间提醒'), findsNothing, reason: '只有点击「知道了」才能关闭提醒');
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

  // ==================================================================
  // 自动备份失败 → 先静默自动重试，重试全部失败才弹窗报错
  // ==================================================================
  //
  // 注意：这些用例包含真实文件 IO（备份目录、ZIP 写入），而
  // testWidgets 的 FakeAsync 区域中真实异步 IO 不会完成，因此必须在
  // tester.runAsync 中执行整个 runCheck 流程；对话框通过 Navigator
  // 顶层路由 pop（结果 null → 等价于点击「跳过」）来驱动结束。

  group('runCheck auto-retries before showing failure dialog', () {
    setUp(() async {
      // 清理测试备份目录，确保 1 小时规则不会跳过本次备份
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      BackupStartupCheck.retryDelay = const Duration(milliseconds: 20);
    });

    tearDown(() {
      BackupStartupCheck.retryDelay = const Duration(seconds: 2);
      AutoBackupService.debugFreeSpaceOverride = null;
      AutoBackupService.lastError = null;
      BackupLocationManager.debugFreeSpaceOverride = null;
      AutoBackupService.lastFailure = null;
      // 注意：不要在这里调用 AutoBackupService.cancel() —— 该调用会把
      // _cancelRequested 置为 true 并泄漏到下一个用例（下一次备份会在
      // 预检前直接以「已取消」返回）。取消标志由备份流程自身的
      // finally 复位。
    });

    /// 在 runAsync 中运行 runCheck；当失败对话框出现在导航栈顶时
    /// 记录 [preCheckCalls] 并 pop（等效「跳过」），返回 runCheck 结果。
    Future<BackupStartupResult?> runCheckUntilDialog(
      WidgetTester tester, {
      required GlobalKey<NavigatorState> navKey,
      required int Function() preCheckCalls,
    }) {
      return tester.runAsync(() async {
        final context = navKey.currentContext!; // Builder context（对话框挂在此导航栈）
        BackupStartupResult? finalResult;
        final checkFuture = BackupStartupCheck.runCheck(context).then((r) {
          finalResult = r;
        });

        var popped = false;
        var callsAtDialog = -1;
        for (var i = 0; i < 300; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (navKey.currentState?.canPop() ?? false) {
            callsAtDialog = preCheckCalls();
            navKey.currentState!.pop(); // pop(null) → 跳过
            popped = true;
            break;
          }
        }
        if (!popped) {
          throw TestFailure('失败对话框未在超时时间内出现');
        }
        expect(callsAtDialog, preCheckCalls(),
            reason: '对话框出现后到 pop 之间不应再发起新的备份尝试');

        await checkFuture;
        return finalResult!;
      });
    }

    testWidgets('silently retries twice before showing the failure dialog',
        (WidgetTester tester) async {
      var preCheckCalls = 0;
      // 步骤 2 空间检查通过；步骤 3 每次备份预检都失败（空间不足）
      BackupLocationManager.debugFreeSpaceOverride =
          () async => 1024 * 1024 * 1024;
      AutoBackupService.debugFreeSpaceOverride = () async {
        preCheckCalls++;
        return 0;
      };

      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const SizedBox.shrink(),
        ),
      );

      final result = await runCheckUntilDialog(
        tester,
        navKey: navKey,
        preCheckCalls: () => preCheckCalls,
      );

      expect(preCheckCalls, 3,
          reason: '弹窗前应静默重试 2 次（共 3 次尝试），'
              '而不是第一次失败就报错');
      expect(result?.autoBackupPerformed, isFalse);
      expect(result?.storageReady, isTrue);
      // 最后一次尝试的失败原因保留，供对话框展示针对性提示
      expect(
          AutoBackupService.lastFailure?.reason, BackupFailureReason.noSpace);

      await tester.pumpAndSettle();
    });

    testWidgets(
        'recovers on a silent retry — no failure dialog, backup '
        'succeeds', (WidgetTester tester) async {
      var preCheckCalls = 0;
      // 步骤 2 空间检查通过；步骤 3 第一次预检失败（瞬时错误），
      // 静默重试时恢复（空间充足）
      BackupLocationManager.debugFreeSpaceOverride =
          () async => 1024 * 1024 * 1024;
      AutoBackupService.debugFreeSpaceOverride = () async {
        preCheckCalls++;
        return preCheckCalls == 1 ? 0 : 1024 * 1024 * 1024;
      };

      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const SizedBox.shrink(),
        ),
      );

      final result = await tester.runAsync(() async {
        final context = navKey.currentContext!;
        BackupStartupResult? finalResult;
        var dialogAppeared = false;
        final checkFuture = BackupStartupCheck.runCheck(context).then((r) {
          finalResult = r;
        });

        // 全程监听：失败对话框绝不应出现
        for (var i = 0; i < 600; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (navKey.currentState?.canPop() ?? false) {
            dialogAppeared = true;
            break;
          }
          if (finalResult != null) break;
        }
        await checkFuture;
        expect(dialogAppeared, isFalse, reason: '静默重试成功后不应弹出失败对话框');
        return finalResult;
      });

      expect(preCheckCalls, greaterThanOrEqualTo(2),
          reason: '首次失败后应自动重试（第 2 次成功）—— 失败仅发生 1 次，'
              '第 3 次调用来自成功后的空间提醒检查');
      expect(result?.autoBackupPerformed, isTrue, reason: '瞬时错误经静默重试恢复后备份应成功');

      await tester.pumpAndSettle();
    });

    testWidgets(
        'user retry after the first dialog leads to exactly one '
        'more failure dialog before the flow ends',
        (WidgetTester tester) async {
      var preCheckCalls = 0;
      // 所有尝试都失败（空间不足）
      BackupLocationManager.debugFreeSpaceOverride =
          () async => 1024 * 1024 * 1024;
      AutoBackupService.debugFreeSpaceOverride = () async {
        preCheckCalls++;
        return 0;
      };

      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const SizedBox.shrink(),
        ),
      );

      final callsAtDialogs = <int>[];
      final result = await tester.runAsync(() async {
        final context = navKey.currentContext!;
        BackupStartupResult? finalResult;
        final checkFuture = BackupStartupCheck.runCheck(context).then((r) {
          finalResult = r;
        });

        // 注意：runAsync 内不渲染帧，对话框被 pop 后其退场动画永不推进，
        // canPop() 在旧对话框上会持续为 true。因此 pop 后必须等待
        // preCheckCalls 变化（新一次备份尝试发生）才允许再次 pop，
        // 防止对退场中的旧对话框重复 pop。
        var dialogs = 0;
        var callsAtLastPop = -1;
        for (var i = 0; i < 600; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final canPopNow = navKey.currentState?.canPop() ?? false;
          if (canPopNow && preCheckCalls != callsAtLastPop) {
            callsAtLastPop = preCheckCalls;
            dialogs++;
            callsAtDialogs.add(preCheckCalls);
            // 第 1 个对话框点「重试」(pop(true))；第 2 个点「跳过」
            // (pop(null))。按钮级可见性（showSkip 后只剩「跳过」）由
            // 上面的单测 'showSkip instructs skip…' 覆盖。
            navKey.currentState!.pop(dialogs == 1 ? true : null);
            if (dialogs == 2) break;
          }
        }
        expect(dialogs, 2, reason: '静默重试 + 用户重试都失败后，应恰好出现 2 个失败对话框');
        await checkFuture;
        return finalResult;
      });

      expect(callsAtDialogs, [3, 4],
          reason: '第 1 个对话框在 3 次尝试后出现；用户点「重试」后再失败'
              '才出现第 2 个（此时只剩「跳过」）');
      expect(result?.autoBackupPerformed, isFalse);

      await tester.pumpAndSettle();
    });

    testWidgets('cancelled backup is not auto-retried and shows dialog once',
        (WidgetTester tester) async {
      var preCheckCalls = 0;
      BackupLocationManager.debugFreeSpaceOverride =
          () async => 1024 * 1024 * 1024;

      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const SizedBox.shrink(),
        ),
      );

      final result = await tester.runAsync(() async {
        // 注意：gate 必须在 runAsync 的真实 zone 中创建 —— FakeAsync
        // zone 中创建的 Future 完成时，传播微任务进入假时钟队列，
        // runAsync 期间假时钟不会推进，被 await 的一方将永远不恢复。
        final gate = Completer<int>();
        AutoBackupService.debugFreeSpaceOverride = () {
          preCheckCalls++;
          return gate.future;
        };

        final context = navKey.currentContext!;
        BackupStartupResult? finalResult;
        final checkFuture = BackupStartupCheck.runCheck(context).then((r) {
          finalResult = r;
        });

        // 等待第一次备份进入空间预检（卡在 gate 上）
        for (var i = 0; i < 300 && preCheckCalls == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(preCheckCalls, 1, reason: '备份应已进入空间预检');

        // 应用进入后台 → 系统取消备份；预检随后放行（空间充足）
        AutoBackupService.cancel();
        gate.complete(1024 * 1024 * 1024);

        // 被取消的备份不自动重试，直接弹窗报错
        var popped = false;
        for (var i = 0; i < 300; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (navKey.currentState?.canPop() ?? false) {
            navKey.currentState!.pop();
            popped = true;
            break;
          }
        }
        expect(popped, isTrue, reason: '取消后应立即弹出失败对话框');
        await checkFuture;
        return finalResult;
      });

      expect(preCheckCalls, 1,
          reason: '被取消的备份不应自动重试'
              '（重试会违背用户离开应用的意图）');
      expect(AutoBackupService.lastFailure, isNull,
          reason: '取消不产生失败分类（与真实失败区分）');
      expect(result?.autoBackupPerformed, isFalse);

      await tester.pumpAndSettle();
    });
  });
}
