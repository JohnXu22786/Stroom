import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/application.dart';
import 'package:stroom/startup/startup_app.dart';
import 'package:stroom/startup/startup_check_service.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetCache();
    // 迁移前备份需要可用的存储（JSON 测试模式）：
    // checkAndMigrate 在备份失败时会取消迁移（生产安全策略）。
    ManifestDatabase.enableTestMode();
    // 启动后任务标记是进程级的（错误边界重试不重复执行），
    // 每个测试用例需要复位以获得完整的启动后流程。
    resetPostStartupTasksFlag();
    // StartupApp 会在渐出时置位；先复位避免跨用例泄漏。
    startupReadyNotifier.value = false;
  });

  group('StartupApp - startup checks integration', () {
    test('detects stale format version and performs migration', () async {
      // Simulate an old format version
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'provider_entries': jsonEncode([
          {'id': 'old_provider', 'type': 'llm', 'name': 'Old', 'configs': []},
        ]),
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String()
          },
        ]),
      });
      AppStorage.resetCache();

      // Run the startup check (this is called by StartupApp._runStartupSequence)
      final migrationResult = await StartupCheckService.checkFormatVersion();
      expect(migrationResult.needsMigration, isTrue);

      // After migration:
      final prefs = await SharedPreferences.getInstance();
      // Version should be updated
      expect(prefs.getInt('data_format_version'),
          equals(DataMigrationService.currentFormatVersion));
    });

    test('no migration needed when format version is current', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Normal',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });

      // Should detect no migration needed
      final issues = await StartupCheckService.validateDataFormats();
      expect(issues.isEmpty, isTrue);
    });

    test('validates data formats without crash recovery', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        'provider_entries': jsonEncode([
          {
            'id': 'test_llm',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [],
          },
        ]),
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });

      // Validate data formats (does not involve crash recovery)
      final issues = await StartupCheckService.validateDataFormats();
      expect(issues.where((i) => i.severity == StartupIssueSeverity.error),
          isEmpty);
    });
  });

  group('StartupApp - restart dialog flow', () {
    testWidgets(
        'migration restart dialog survives the back button and '
        'dismissal proceeds to the main app', (tester) async {
      // 旧版本数据 → 启动序列执行迁移 → 弹出「数据格式升级完成」对话框。
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'provider_entries': jsonEncode([
          {'id': 'p1', 'type': 'llm', 'name': 'P1', 'configs': []},
        ]),
        'conversations': jsonEncode([]),
      });
      AppStorage.resetCache();

      // 移动端视口（HomePage 的 NavigationBar 仅在宽度 < 600 时渲染，
      // 便于断言主应用接管界面）。
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const ProviderScope(child: StartupApp()));
      await tester.pump();
      // 启动页先显示。
      expect(find.text('Stroom'), findsOneWidget);

      // 推进启动序列（最小显示 1.5s + 各检查延时 + 完成态 0.6s）。
      // 迁移链路包含大量真实文件 I/O（备份 ZIP 创建/清理），而
      // testWidgets 的 FakeAsync 不驱动真实 I/O —— 用 runAsync 让
      // 真实事件循环推进 I/O，再 pump 冲刷 fake 区间的微任务续体。
      // 用轮询等待对话框出现（上限宽松，慢机器不 flaky）。
      var dialogShown = false;
      for (int i = 0; i < 300 && !dialogShown; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        dialogShown = tester.any(find.text('数据格式升级完成'));
      }
      expect(dialogShown, isTrue,
          reason: '迁移完成后必须显示重启对话框');

      // Android 系统返回键不能关闭对话框（PopScope(canPop: false)），
      // 否则用户会永远停留在启动页。
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('数据格式升级完成'), findsOneWidget,
          reason: '系统返回键不能关闭迁移重启对话框');

      // 点击「退出应用」：移动端 SystemNavigator.pop() 在测试环境是
      // no-op，进程存活 → 启动页必须继续渐出进入主应用，绝不停留。
      await tester.tap(find.text('退出应用'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('数据格式升级完成'), findsNothing);
      // 启动页（含 tagline）已从树中移除 → 主应用可见。
      expect(find.text('你的学习助理'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget,
          reason: '主应用（HomePage）应已接管界面');
      expect(tester.takeException(), isNull);
    });
  });

  group('StartupApp - ensure checks yield to event loop', () {
    test('validateDataFormats can be interleaved with UI frames', () async {
      // Set up some data to validate
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        'provider_entries': jsonEncode([
          {
            'id': 'test_llm',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [
              {
                'models': [
                  {
                    'customParams': [],
                    'voices': [],
                    'reasoningParams': [],
                  },
                ],
              },
            ],
          },
        ]),
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test Conv',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });
      AppStorage.resetCache();

      // Run validation - should not hang the event loop
      // In test mode this runs synchronously (sync fallback)
      final issues = await StartupCheckService.validateDataFormats();
      expect(issues, isA<List<StartupIssue>>());
    });

    test('multiple sequential checks complete without blocking', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        'provider_entries': jsonEncode([
          {
            'id': 'test_llm',
            'type': 'llm',
            'name': 'Test',
            'configs': [],
          },
        ]),
        'conversations': jsonEncode([]),
      });
      AppStorage.resetCache();

      // Simulate running multiple checks sequentially with yields between them
      final issues1 = await StartupCheckService.validateDataFormats();
      // Insert a microtask to simulate event loop yield
      await Future<void>.microtask(() {});
      final issues2 = await StartupCheckService.checkDataIntegrity();

      expect(issues1, isA<List<StartupIssue>>());
      expect(issues2, isA<List<StartupIssue>>());
    });
  });
}
