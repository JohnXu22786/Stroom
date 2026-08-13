// Merged from:
//   test/pages/settings_page_asr_test.dart
//   test/pages/settings_page_background_optimization_test.dart
//   test/pages/settings_page_camera_test.dart
//   test/pages/settings_page_license_test.dart
//   test/pages/settings_page_ocr_test.dart
//   test/pages/settings_page_update_test.dart
//   test/pages/notification_settings_page_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/notification_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

/// Builds the SettingsPage test app without notification override.
/// Used by ASR / OCR / license groups.
Widget _buildSettingsTestApp() {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      providerEntriesProvider.overrideWith((ref) {
        final notifier = ProviderEntriesNotifier();
        // load() is normally called in the provider factory, so we call it here too.
        notifier.load();
        return notifier;
      }),
      updateProvider.overrideWith((ref) => UpdateNotifier()),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

/// Builds the SettingsPage test app with notification override.
/// Used by 任务 section and camera section groups.
Widget _buildSettingsTestAppWithNotification() {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      providerEntriesProvider.overrideWith(
        (ref) {
          final notifier = ProviderEntriesNotifier();
          notifier.load();
          return notifier;
        },
      ),
      updateProvider.overrideWith((ref) => UpdateNotifier()),
      notificationSettingsProvider
          .overrideWith((ref) => NotificationSettingsNotifier()),
    ],
    child: const MaterialApp(
      home: SettingsPage(),
    ),
  );
}

/// 构建只包含 TTS、LLM 和 OCR 的已保存数据（模拟旧版本用户升级，无 ASR）
String _savedDataWithoutAsr() {
  final entries = [
    {
      'id': 'builtin_tts',
      'type': 'tts',
      'name': 'TTS供应商',
      'configs': <Map<String, dynamic>>[],
    },
    {
      'id': 'builtin_llm',
      'type': 'llm',
      'name': 'LLM供应商',
      'configs': <Map<String, dynamic>>[],
    },
    {
      'id': 'builtin_ocr',
      'type': 'ocr',
      'name': 'OCR供应商',
      'configs': <Map<String, dynamic>>[],
    },
  ];
  return jsonEncode(entries);
}

/// 构建只包含 TTS 和 LLM 的已保存数据（模拟旧版本用户升级）
String _savedDataWithoutOcr() {
  final entries = [
    {
      'id': 'builtin_tts',
      'type': 'tts',
      'name': 'TTS供应商',
      'configs': <Map<String, dynamic>>[],
    },
    {
      'id': 'builtin_llm',
      'type': 'llm',
      'name': 'LLM供应商',
      'configs': <Map<String, dynamic>>[],
    },
  ];
  return jsonEncode(entries);
}

void main() {
  // ─────────────────────────────────────────────────────────────────────
  // From settings_page_asr_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - ASR (音频转写) supplier display', () {
    testWidgets(
      'shows ASR supplier after migration from saved data without it',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'provider_entries': _savedDataWithoutAsr(),
        });

        await tester.pumpWidget(_buildSettingsTestApp());
        await tester.pumpAndSettle();

        // ASR should be migrated in and displayed
        expect(find.text('TTS供应商'), findsOneWidget);
        expect(find.text('LLM供应商'), findsOneWidget);
        expect(find.text('OCR供应商'), findsOneWidget);
        expect(find.text('音频转写供应商'), findsOneWidget);
      },
    );

    testWidgets('ASR supplier entry is tappable and navigates to config page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      // Verify ASR supplier is visible
      expect(find.text('音频转写供应商'), findsOneWidget);

      // Tap the ASR supplier entry
      await tester.tap(find.text('音频转写供应商'));
      await tester.pumpAndSettle();

      // Should navigate to ProviderConfigPage which has title "供应商配置"
      expect(find.text('供应商配置'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From settings_page_background_optimization_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - 任务 section & 后台运行优化 card', () {
    testWidgets('shows 任务 section header instead of 通知', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
      await tester.pumpAndSettle();

      // Should show the new 任务 header
      expect(find.text('任务'), findsOneWidget);
      // Should NOT show the old 通知 header
      expect(find.text('通知'), findsNothing);
    });

    testWidgets('shows 任务完成通知 as navigation card', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
      await tester.pumpAndSettle();

      // The text should still exist
      expect(find.text('任务完成通知'), findsOneWidget);
      // Subtitle describing the purpose
      expect(find.text('检测通知权限与系统设置，查看通知指南'), findsOneWidget);
      // Should have a chevron_right icon (navigation indicator)
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
      // Should NOT have a Switch directly on the settings page for notifications
      // (there may be other Switches like the pre-release toggle)
      // Just verify the notification card is not a Switch-based toggle
      expect(find.text('任务完成或失败时发送通知'), findsNothing);
    });

    testWidgets('tapping 后台运行优化 navigates to BackgroundOptimizationPage', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.johntsui.stroom/keepalive'),
        (MethodCall methodCall) async => true,
      );

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
      await tester.pumpAndSettle();

      // Tap the 后台运行优化 card
      await tester.tap(find.text('后台运行优化'));
      await tester.pumpAndSettle();

      // Should navigate to BackgroundOptimizationPage (verify unique content)
      expect(find.text('系统环境检测'), findsOneWidget);
      expect(find.text('平台教程'), findsOneWidget);
    });

    testWidgets('tapping 任务完成通知 navigates to NotificationSettingsPage', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
      await tester.pumpAndSettle();

      // Tap the 任务完成通知 card
      await tester.tap(find.text('任务完成通知'));
      // Push the new page - use pump without settle because
      // CircularProgressIndicator animation prevents settling
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Should navigate to NotificationSettingsPage (verify unique content)
      expect(find.text('通知权限设置'), findsOneWidget);
      expect(find.text('通知权限检测'), findsOneWidget);
      expect(find.text('平台指南'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From settings_page_ocr_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - OCR supplier display', () {
    testWidgets('shows OCR supplier after migration from saved data without it',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithoutOcr(),
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      // OCR should be migrated in and displayed
      expect(find.text('TTS供应商'), findsOneWidget);
      expect(find.text('LLM供应商'), findsOneWidget);
      expect(find.text('OCR供应商'), findsOneWidget);
    });

    testWidgets('OCR supplier entry is tappable and navigates to config page',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      // Verify OCR supplier is visible
      expect(find.text('OCR供应商'), findsOneWidget);

      // Tap the OCR supplier entry
      await tester.tap(find.text('OCR供应商'));
      await tester.pumpAndSettle();

      // Should navigate to ProviderConfigPage which has title "供应商配置"
      expect(find.text('供应商配置'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 上下文管理设置（压缩触发值字段交互）
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - context management compaction threshold', () {
    testWidgets('invalid input reverts on blur, valid input persists',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      // 滚动到"自定义压缩触发值"开关并开启
      final toggleFinder = find.text('自定义压缩触发值').first;
      await tester.scrollUntilVisible(toggleFinder, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // 输入框出现：输入非法文本
      final fieldFinder = find.byType(TextFormField);
      expect(fieldFinder, findsOneWidget);
      await tester.enterText(fieldFinder, 'abc');
      await tester.pump();

      // 失焦（提交）→ 非法输入回退为空（provider 保持 null）
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        tester.widget<TextFormField>(fieldFinder).controller?.text ?? '',
        isEmpty,
      );

      // 输入有效值 48000 → 提交 → provider 持久化
      await tester.enterText(fieldFinder, '48000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('context_compaction_threshold'), 48000);
      expect(prefs.getBool('context_compaction_threshold_enabled'), isTrue);
    });

    testWidgets(
        'tapping outside the field blurs it (invalid input still '
        'reverts)', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      // 滚动到"自定义压缩触发值"开关并开启
      final toggleFinder = find.text('自定义压缩触发值').first;
      await tester.scrollUntilVisible(toggleFinder, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // 输入框出现：输入非法文本并聚焦
      final fieldFinder = find.byType(TextFormField);
      expect(fieldFinder, findsOneWidget);
      await tester.enterText(fieldFinder, 'abc');
      await tester.pump();
      final editableFinder = find.descendant(
        of: fieldFinder,
        matching: find.byType(EditableText),
      );
      bool fieldFocused() => tester
          .state<EditableTextState>(editableFinder)
          .widget
          .focusNode
          .hasFocus;
      await tester.tap(fieldFinder);
      await tester.pump();
      expect(fieldFocused(), isTrue,
          reason: 'precondition: the field is focused');

      // 点击字段外的区域 → 字段必须失焦（自定义 onTapOutside 同时
      // 回退非法输入；此前该字段在任何平台上都不会失焦）
      await tester.tap(find.text('上下文管理').first);
      await tester.pump();
      expect(fieldFocused(), isFalse,
          reason: 'tapping outside the compaction threshold field must '
              'blur it (the cursor must not stay stuck)');
      expect(
        tester.widget<TextFormField>(fieldFinder).controller?.text,
        isEmpty,
        reason: 'the invalid input is reverted on blur',
      );
    });

    testWidgets(
        'clearing the field falls back to model context and closes '
        'the custom toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'context_compaction_threshold_enabled': true,
        'context_compaction_threshold': 48000,
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      final toggleFinder = find.text('自定义压缩触发值').first;
      await tester.scrollUntilVisible(toggleFinder, 300,
          scrollable: find.byType(Scrollable).first);
      final tile = find.widgetWithText(SwitchListTile, '自定义压缩触发值');
      final switchWidget = tester.widget<Switch>(
        find.descendant(of: tile, matching: find.byType(Switch)),
      );
      expect(switchWidget.value, isTrue);

      final fieldFinder = find.byType(TextFormField);
      // 清空输入 → 提交 → 阈值清除且开关关闭
      await tester.enterText(fieldFinder, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('context_compaction_threshold'), isNull);
      expect(
        prefs.getBool('context_compaction_threshold_enabled'),
        isFalse,
      );
      // 字段随开关关闭而消失
      expect(find.byType(TextFormField), findsNothing);
    });
  });
  // ─────────────────────────────────────────────────────────────────────
  // From settings_page_about.dart — 版本信息面板
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - 版本信息面板', () {
    testWidgets(
        'only the version icon opens the dialog; the app name text does not',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      // The about header shows the app name; only the icon (the near-square
      // logo area) is tappable — the text itself must NOT open the dialog.
      // Scroll the last section of the long ListView into view first.
      await tester.ensureVisible(find.text('Stroom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stroom'));
      await tester.pumpAndSettle();
      expect(find.text('版本信息'), findsNothing);

      await tester.ensureVisible(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();

      expect(find.text('版本信息'), findsOneWidget);
      expect(find.text('版本号'), findsOneWidget);
      expect(find.text('发布时间'), findsOneWidget);
      // Tests run without CD dart-defines → fallback text.
      expect(find.text('本地构建'), findsOneWidget);
      // No release notes baked into the test build → section hidden.
      expect(find.text('更新内容'), findsNothing);
    });

    testWidgets('version info dialog closes via 关闭 button', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();
      expect(find.text('版本信息'), findsOneWidget);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      expect(find.text('版本信息'), findsNothing);
    });
  });
}
