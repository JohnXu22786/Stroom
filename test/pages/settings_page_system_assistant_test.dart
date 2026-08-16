import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/built_in_assistants.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

/// 预设一个含两个供应商三个模型的 LLM 配置。
String _llmEntriesJson() => jsonEncode([
      {
        'id': 'builtin_llm',
        'type': 'llm',
        'name': 'LLM供应商',
        'configs': [
          {
            'providerName': 'OpenAI',
            'host': 'https://api.openai.com/v1',
            'key': 'sk-test',
            'endpointType': 'openai',
            'models': [
              {'name': 'GPT-4o', 'modelId': 'gpt-4o'},
              {'name': 'GPT-4o Mini', 'modelId': 'gpt-4o-mini'},
            ],
          },
          {
            'providerName': 'Anthropic',
            'host': 'https://api.anthropic.com/v1',
            'key': 'sk-ant-test',
            'endpointType': 'anthropic',
            'models': [
              {'name': 'Claude 3', 'modelId': 'claude-3-opus'},
            ],
          },
        ],
      },
    ]);

/// 在面板（BottomSheet）内部查找 [text]。
Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

Widget _buildSettingsTestApp() {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      providerEntriesProvider.overrideWith((ref) {
        final notifier = ProviderEntriesNotifier();
        notifier.load();
        return notifier;
      }),
      updateProvider.overrideWith((ref) => UpdateNotifier()),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

void _setLargeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _openTitlePanel(WidgetTester tester) async {
  final tile = find.text('标题生成助手').first;
  await tester.scrollUntilVisible(tile, 300,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<String?> _prefsValue(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

/// 轮询等待 prefs 满足 [cond]（异步 _persist 完成后断言）。
Future<void> _waitForPrefs(bool Function(SharedPreferences prefs) cond) async {
  final prefs = await SharedPreferences.getInstance();
  for (var i = 0; i < 100 && !cond(prefs); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('SettingsPage 系统助手配置面板', () {
    testWidgets('点击标题生成助手打开配置面板（模型 / 提示词 / 重置按钮）',
        (tester) async {
      _setLargeView(tester);
      SharedPreferences.setMockInitialValues({
        'provider_entries': _llmEntriesJson(),
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();
      await _openTitlePanel(tester);

      // 面板元素：使用的模型、提示词、重置为默认提示词、保存
      expect(_inSheet('使用的模型'), findsOneWidget);
      expect(_inSheet('提示词'), findsOneWidget);
      expect(_inSheet('重置为默认提示词'), findsOneWidget);
      expect(_inSheet('保存'), findsOneWidget);
      // 未配置模型 → 面板内显示跟随对话页当前模型
      expect(_inSheet('跟随对话页当前模型'), findsOneWidget);
      // 默认状态提示使用默认提示词（重置按钮禁用）
      expect(_inSheet('当前使用默认提示词'), findsOneWidget);
      final resetBtn = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '重置为默认提示词'),
      );
      expect(resetBtn.onPressed, isNull,
          reason: '默认提示词状态下重置按钮应禁用');
    });

    testWidgets('编辑提示词并保存 → 持久化为自定义提示词', (tester) async {
      _setLargeView(tester);
      SharedPreferences.setMockInitialValues({
        'provider_entries': _llmEntriesJson(),
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();
      await _openTitlePanel(tester);

      await tester.enterText(find.byType(TextField), '我的标题提示词');
      await tester.pump();
      // 编辑后进入自定义状态
      expect(_inSheet('当前使用自定义提示词'), findsOneWidget);
      final resetBtn = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '重置为默认提示词'),
      );
      expect(resetBtn.onPressed, isNotNull);

      // 清空输入 → 视为回到默认提示词（保存时 prompt=null）
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(_inSheet('当前使用默认提示词'), findsOneWidget);

      // 重新输入并保存
      await tester.enterText(find.byType(TextField), '我的标题提示词');
      await tester.pump();
      await tester.tap(_inSheet('保存'));
      await tester.pumpAndSettle();
      await _waitForPrefs(
          (prefs) => prefs.getString('system_title_prompt') == '我的标题提示词');
      expect(await _prefsValue('system_title_prompt'), '我的标题提示词');
    });

    testWidgets('重置默认带二次确认：取消保留自定义，确认后恢复默认并保存',
        (tester) async {
      _setLargeView(tester);
      SharedPreferences.setMockInitialValues({
        'provider_entries': _llmEntriesJson(),
        'system_title_prompt': '自定义提示词A',
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();
      await _openTitlePanel(tester);

      // 预置自定义提示词 → 面板显示它且重置按钮可用
      expect(_inSheet('自定义提示词A'), findsOneWidget);
      expect(_inSheet('当前使用自定义提示词'), findsOneWidget);

      // 第一次重置：取消 → 草稿不变
      await tester.tap(_inSheet('重置为默认提示词'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, '重置为默认提示词'),
          findsOneWidget);
      // 对话框内的「取消」（面板底部也有取消按钮，需按对话框内查找）
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('取消'),
      ));
      await tester.pumpAndSettle();
      expect(_inSheet('自定义提示词A'), findsOneWidget,
          reason: '取消后自定义提示词不应被重置');

      // 第二次重置：确认 → 恢复为内置默认提示词
      await tester.tap(_inSheet('重置为默认提示词'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('重置'),
      ));
      await tester.pumpAndSettle();
      final defaultPrompt =
          builtInSystemAssistantById(kBuiltInTitleAssistantId)!.prompt;
      expect(_inSheet('当前使用默认提示词'), findsOneWidget);
      expect(
        find.text(defaultPrompt),
        findsOneWidget,
        reason: '重置后文本框应显示内置默认提示词',
      );

      // 保存 → 自定义提示词清除（prompt key 移除）
      await tester.tap(_inSheet('保存'));
      await tester.pumpAndSettle();
      await _waitForPrefs((prefs) => prefs.getString('system_title_prompt') == null);
      expect(await _prefsValue('system_title_prompt'), isNull);
    });

    testWidgets(
        '选择模型（对话页显示格式）→ 保存持久化绝对身份，tile 副标题同格式显示',
        (tester) async {
      _setLargeView(tester);
      SharedPreferences.setMockInitialValues({
        'provider_entries': _llmEntriesJson(),
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();
      // 滚动到 tile 可见后：未配置时副标题为跟随提示
      final tile = find.text('标题生成助手').first;
      await tester.scrollUntilVisible(tile, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, '标题生成助手'),
          matching: find.text('跟随对话页当前模型'),
        ),
        findsOneWidget,
      );

      await tester.tap(tile);
      await tester.pumpAndSettle();
      // 打开模型选择（点击面板内的模型行）
      await tester.tap(_inSheet('跟随对话页当前模型'));
      await tester.pumpAndSettle();
      // 模型名显示格式与对话页一致："模型名 | 供应商名"
      expect(find.text('GPT-4o | OpenAI'), findsOneWidget);
      expect(find.text('GPT-4o Mini | OpenAI'), findsOneWidget);
      expect(find.text('Claude 3 | Anthropic'), findsOneWidget);

      await tester.tap(find.text('GPT-4o | OpenAI'));
      await tester.pumpAndSettle();
      // 面板返回并显示所选模型
      expect(_inSheet('GPT-4o | OpenAI'), findsOneWidget);

      await tester.tap(_inSheet('保存'));
      await tester.pumpAndSettle();
      await _waitForPrefs(
          (prefs) => prefs.getString('system_title_model_id') == 'gpt-4o');
      expect(await _prefsValue('system_title_model_id'), 'gpt-4o');
      expect(await _prefsValue('system_title_model_provider'), 'OpenAI');
      expect(
        await _prefsValue('system_title_model_name'),
        'GPT-4o | OpenAI',
      );
      // tile 副标题显示所选模型（对话页同款格式）
      await tester.pumpAndSettle();
      expect(find.text('GPT-4o | OpenAI'), findsOneWidget);
    });

    testWidgets('模型选择中可选择"跟随对话页当前模型"清除配置', (tester) async {
      _setLargeView(tester);
      SharedPreferences.setMockInitialValues({
        'provider_entries': _llmEntriesJson(),
        'system_title_model_id': 'gpt-4o',
        'system_title_model_provider': 'OpenAI',
        'system_title_model_name': 'GPT-4o | OpenAI',
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();
      await _openTitlePanel(tester);
      // 面板内模型行显示已配置模型
      expect(_inSheet('GPT-4o | OpenAI'), findsOneWidget);

      // 打开模型选择 → 列表顶部有"跟随对话页当前模型"选项
      await tester.tap(_inSheet('GPT-4o | OpenAI'));
      await tester.pumpAndSettle();
      final pickerRows = _inSheet('跟随对话页当前模型');
      expect(pickerRows, findsOneWidget,
          reason: '模型选择列表顶部的跟随选项');
      await tester.tap(pickerRows);
      await tester.pumpAndSettle();

      // 面板模型行回到跟随提示
      expect(_inSheet('跟随对话页当前模型'), findsOneWidget);
      await tester.tap(_inSheet('保存'));
      await tester.pumpAndSettle();
      await _waitForPrefs(
          (prefs) => prefs.getString('system_title_model_id') == null);
      expect(await _prefsValue('system_title_model_id'), isNull);
      expect(await _prefsValue('system_title_model_name'), isNull);
    });
  });
}