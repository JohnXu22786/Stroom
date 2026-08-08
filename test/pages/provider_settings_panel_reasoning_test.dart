// 供应商设置面板推理参数部分（从模型页完整移植）测试：
// - 推理开关 / 推理力度 / 附加推理参数三段结构
// - 无开关时推理力度添加按钮禁用
// - 供应商级推理力度允许仅填参数名（选项值可选）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/providers/provider_config.dart';

/// 打开供应商设置面板并返回保存结果（null 表示未保存成功）。
Future<ProviderConfigItem?> _openAndSave(
  WidgetTester tester, {
  required ProviderConfigItem config,
  bool tapSave = true,
}) async {
  ProviderConfigItem? saved;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              saved = await showProviderSettingsPanel(
                context: context,
                config: config,
                providerType: 'llm',
              );
            },
            child: const Text('打开供应商设置'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开供应商设置'));
  await tester.pumpAndSettle();

  // 切到「参数设置」Tab
  await tester.tap(find.text('参数设置'));
  await tester.pumpAndSettle();

  if (tapSave) {
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
  }
  return saved;
}

ProviderConfigItem _baseConfig() => ProviderConfigItem(
      providerName: 'Test Provider',
      host: 'https://api.example.com/v1',
      key: 'sk-test',
    );

void main() {
  group('ProviderSettingsPanel reasoning section (ported from model page)',
      () {
    testWidgets('shows toggle, effort and additional param sections',
        (tester) async {
      await _openAndSave(tester, config: _baseConfig(), tapSave: false);

      expect(find.text('推理参数'), findsOneWidget);
      expect(find.text('添加推理开关'), findsOneWidget);
      expect(find.text('添加推理力度'), findsOneWidget);
      expect(find.text('添加推理参数'), findsOneWidget);
    });

    testWidgets('effort add button disabled until a toggle exists',
        (tester) async {
      await _openAndSave(tester, config: _baseConfig(), tapSave: false);

      final addEffortButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('添加推理力度'),
          matching: find.byType(TextButton),
        ),
      );
      expect(addEffortButton.onPressed, isNull,
          reason: '无推理开关时不可添加推理力度');
    });

    testWidgets('provider-level effort param with name only is persisted',
        (tester) async {
      ProviderConfigItem? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  saved = await showProviderSettingsPanel(
                    context: context,
                    config: _baseConfig(),
                    providerType: 'llm',
                  );
                },
                child: const Text('打开供应商设置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开供应商设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('参数设置'));
      await tester.pumpAndSettle();

      // 添加开关 + 名称式力度参数并保存
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      var fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'thinking.type');
      await tester.enterText(fields.at(1), 'enabled');
      await tester.enterText(fields.at(2), 'disabled');
      await tester.pump();

      // 滚动到「添加推理力度」并点击
      await tester.scrollUntilVisible(
        find.text('添加推理力度'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加推理力度'));
      await tester.pump();
      fields = find.byType(TextFormField);
      await tester.enterText(fields.at(3), 'reasoning_effort');
      await tester.pump();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.reasoningParams.length, 2);
      expect(saved!.reasoningParams[0].isReasoningToggle, isTrue);
      expect(saved!.reasoningParams[1].paramName, 'reasoning_effort');
      expect(saved!.reasoningParams[1].isEffortParam, isTrue);
      // 名称式力度参数：无选项值，保存不被拦截
      expect(saved!.reasoningParams[1].options, isEmpty);
    });

    testWidgets('duplicate reasoning param name shows inline error',
        (tester) async {
      final config = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'high'],
          ),
        ],
      );
      await _openAndSave(tester, config: config, tapSave: false);

      // 修改开关参数名与力度参数重名 → 内联错误提示
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'reasoning_effort');
      await tester.pump();

      expect(find.text('已存在该参数'), findsOneWidget);
    });
  });
}
