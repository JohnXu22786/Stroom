// Merged from:
//   tests/pages/settings_page_asr_test.dart
//   tests/pages/settings_page_background_optimization_test.dart
//   tests/pages/settings_page_camera_test.dart
//   tests/pages/settings_page_license_test.dart
//   tests/pages/settings_page_ocr_test.dart
//   tests/pages/settings_page_update_test.dart
//   tests/pages/notification_settings_page_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/context_management_provider.dart';
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

/// 带两个模型的 LLM 供应商数据（用于压缩触发设置面板的模型列表）。
String _llmEntryWithModels() {
  return jsonEncode([
    {
      'id': 'builtin_llm',
      'type': 'llm',
      'name': 'LLM供应商',
      'configs': [
        {
          'providerName': 'ProviderA',
          'host': 'https://api.a.com/v1',
          'key': 'key-a',
          'models': [
            {
              'name': 'Model A',
              'modelId': 'model-a',
              'typeConfig': {'context': 128000},
            },
            {
              'name': 'Model B',
              'modelId': 'model-b',
              'typeConfig': {'context': 64000},
            },
          ],
        },
      ],
    },
  ]);
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
  });

  // ─────────────────────────────────────────────────────────────────────
  // 上下文管理设置（压缩触发设置面板）
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - 压缩触发设置面板', () {
    Future<void> openCompactionPanel(WidgetTester tester) async {
      final tileFinder = find.text('压缩触发设置').first;
      await tester.scrollUntilVisible(tileFinder, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();
    }

    testWidgets('点击"压缩触发设置"进入面板，展示总开关/百分比/模型', (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'provider_entries': _llmEntryWithModels(),
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      await openCompactionPanel(tester);

      // 面板内容
      expect(find.text('压缩触发设置'), findsOneWidget);
      expect(find.text('上下文自动压缩'), findsOneWidget);
      expect(find.text('全局触发百分比'), findsOneWidget);
      expect(find.text('按模型设置'), findsOneWidget);
      // 模型显示格式同对话页："模型名 | 供应商名"
      expect(find.text('Model A | ProviderA'), findsOneWidget);
      expect(find.text('Model B | ProviderA'), findsOneWidget);
      // 默认全局百分比 95
      expect(
        tester
            .widget<TextFormField>(
                find.byKey(const Key('global-percent-field')))
            .controller
            ?.text,
        '95',
      );
    });

    testWidgets('总开关关闭后下方设置全部置灰且不可操作', (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'provider_entries': _llmEntryWithModels(),
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();
      await openCompactionPanel(tester);

      // 预置一个开启的模型独立设置（带可见的 token 输入框）
      final modelATile =
          find.widgetWithText(SwitchListTile, 'Model A | ProviderA');
      await tester.tap(modelATile);
      await tester.pumpAndSettle();
      final key =
          compactionModelKey(modelId: 'model-a', providerName: 'ProviderA');
      final tokenField = find.byKey(ValueKey('model-token-$key'));
      expect(tokenField, findsOneWidget,
          reason: 'precondition: token field visible');

      // 关闭总开关
      await tester.tap(find.text('上下文自动压缩'));
      await tester.pumpAndSettle();

      // 下方设置区整体置灰
      final body = tester.widget<Opacity>(
        find.byKey(const Key('compaction-settings-body')),
      );
      expect(body.opacity, lessThan(1));

      // 模型开关被禁用
      final modelSwitch = tester.widget<Switch>(
        find.descendant(of: modelATile, matching: find.byType(Switch)),
      );
      expect(modelSwitch.onChanged, isNull);

      // 全局百分比输入框与重置按钮被禁用
      final percentField = tester.widget<TextFormField>(
        find.byKey(const Key('global-percent-field')),
      );
      expect(percentField.enabled, isFalse);
      final resetIcon = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.refresh),
      );
      expect(resetIcon.onPressed, isNull);

      // 可见的模型 token 输入框同样被禁用
      final tokenTextFormField = tester.widget<TextFormField>(
        find.descendant(of: tokenField, matching: find.byType(TextFormField)),
      );
      expect(
        tokenTextFormField.enabled,
        isFalse,
        reason: '总开关关闭时可见的独立触发值输入框也必须置灰',
      );

      // 恢复总开关后模型开关可操作（值未被改动）
      await tester.tap(find.text('上下文自动压缩'));
      await tester.pumpAndSettle();
      final again = tester.widget<Switch>(
        find.descendant(of: modelATile, matching: find.byType(Switch)),
      );
      expect(again.onChanged, isNotNull);
      expect(
        tester
            .widget<TextFormField>(find.descendant(
                of: tokenField, matching: find.byType(TextFormField)))
            .enabled,
        isTrue,
        reason: '恢复总开关后输入框重新可用',
      );
    });

    testWidgets('修改全局百分比并一键重置回 95', (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'provider_entries': _llmEntryWithModels(),
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();
      await openCompactionPanel(tester);

      final percentField = find.byKey(const Key('global-percent-field'));
      await tester.enterText(percentField, '80');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('context_compaction_global_percent'), 80);

      // 一键重置回 95（仅图标按钮）
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(prefs.getInt('context_compaction_global_percent'), 95);
      expect(
        tester.widget<TextFormField>(percentField).controller?.text,
        '95',
      );
    });

    testWidgets('非法/越界的全局百分比失焦回退上次有效值', (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();
      await openCompactionPanel(tester);

      final percentField = find.byKey(const Key('global-percent-field'));
      await tester.enterText(percentField, 'abc');
      await tester.pump();
      // 越界值 150 也不保存
      await tester.enterText(percentField, '150');
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('context_compaction_global_percent'), isNull,
          reason: '非法/越界输入不推给 provider（保持默认）');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        tester.widget<TextFormField>(percentField).controller?.text,
        '95',
        reason: '失焦时回退显示上次有效值',
      );
    });

    testWidgets('模型开关开启后填写独立触发值并持久化', (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'provider_entries': _llmEntryWithModels(),
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();
      await openCompactionPanel(tester);

      // 开启 Model A 的独立设置
      final modelATile =
          find.widgetWithText(SwitchListTile, 'Model A | ProviderA');
      await tester.tap(modelATile);
      await tester.pumpAndSettle();

      // 独立触发值输入框出现（具体 token 数，非百分比）
      final key =
          compactionModelKey(modelId: 'model-a', providerName: 'ProviderA');
      final tokenField = find.byKey(ValueKey('model-token-$key'));
      expect(tokenField, findsOneWidget);
      await tester.enterText(tokenField, '30000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final perModel =
          jsonDecode(prefs.getString('context_compaction_per_model')!) as Map;
      expect((perModel[key] as Map)['enabled'], isTrue);
      expect((perModel[key] as Map)['threshold'], 30000);

      // Model B 未被配置（跟随全局）
      expect(
        perModel.containsKey(
            compactionModelKey(modelId: 'model-b', providerName: 'ProviderA')),
        isFalse,
      );

      // 清空输入 → 独立值置空（回退全局百分比），但开关保持开启
      await tester.enterText(tokenField, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final afterClear =
          jsonDecode(prefs.getString('context_compaction_per_model')!) as Map;
      expect((afterClear[key] as Map)['enabled'], isTrue,
          reason: '误清输入不应关闭模型的独立设置开关');
      expect((afterClear[key] as Map)['threshold'], isNull);
      // 输入框仍在、开关仍为开启态
      expect(find.byKey(ValueKey('model-token-$key')), findsOneWidget);
      expect(
        tester
            .widget<Switch>(
                find.descendant(of: modelATile, matching: find.byType(Switch)))
            .value,
        isTrue,
      );
    });
  });
  // ─────────────────────────────────────────────────────────────────────
  // From settings_page_about.dart — 版本信息面板
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - 版本信息面板', () {
    testWidgets('tapping the version card opens the version info dialog', (
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

      // The whole about header card is tappable — tapping the app name
      // text (not just the logo icon) must open the dialog.
      // Scroll the last section of the long ListView into view first.
      await tester.ensureVisible(find.text('Stroom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stroom'));
      await tester.pumpAndSettle();

      expect(find.text('版本信息'), findsOneWidget);
      expect(find.text('版本号'), findsOneWidget);
      expect(find.text('发布时间'), findsOneWidget);
      // Tests run without CD dart-defines → fallback text.
      expect(find.text('本地构建'), findsOneWidget);
      // No release notes baked into the test build → section hidden.
      expect(find.text('更新内容'), findsNothing);

      // The card keeps its compact #635 shape: the "点击查看版本信息"
      // hint row from #582 must NOT be re-added (no size regression).
      expect(find.text('点击查看版本信息'), findsNothing);
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
