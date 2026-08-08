// 模型配置页「供应商推理参数继承」测试：
// - 供应商已配置的推理参数直接显示在模型页（标注「来自供应商」）
// - 未修改的继承参数不写入模型（供应商修改可继续同步）
// - 修改继承参数后变为模型独立配置并保存
// - 与供应商参数同名的模型参数视为覆盖，不重复显示
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

/// 打开模型配置页并返回保存结果（null 表示未成功保存）。
Future<ModelConfig?> _pumpAndSave(
  WidgetTester tester, {
  ModelConfig? model,
  ProviderConfigItem? provider,
  bool tapSave = true,
}) async {
  ModelConfig? saved;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              saved = await Navigator.push<ModelConfig>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LlmModelConfigPage(model: model, provider: provider),
                ),
              );
            },
            child: const Text('打开模型配置'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开模型配置'));
  await tester.pumpAndSettle();
  if (tapSave) {
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
  }
  return saved;
}

/// 滚动到推理参数区域（ListView 懒构建，需先滚动到目标附近）。
/// [delta] 为正向下滚动，为负向上滚动。
Future<void> _scrollToReasoning(WidgetTester tester, Finder target,
    {double delta = 200}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// 构造一个「开关完整 + 推理力度仅参数名」的供应商配置。
ProviderConfigItem _providerWithNameOnlyEffort() {
  return ProviderConfigItem(
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
        enabled: true,
        options: [],
      ),
    ],
  );
}

void main() {
  group('LlmModelConfigPage provider reasoning inheritance', () {
    testWidgets('provider effort name displays directly on the model page',
        (tester) async {
      await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: _providerWithNameOnlyEffort(),
        tapSave: false,
      );

      // Provider 的推理力度参数（仅参数名）直接显示，无需模型重复填写
      await _scrollToReasoning(tester, find.text('reasoning_effort'));
      expect(find.text('reasoning_effort'), findsOneWidget);
      // 继承参数带「来自供应商」标记
      expect(find.text('来自供应商'), findsWidgets);
      // 力度参数未配置选项 → 模型页显示「添加选项」按钮（模型可只设参数值）
      expect(find.text('添加选项'), findsOneWidget);
    });

    testWidgets('unchanged inherited params are not written to the model',
        (tester) async {
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
          reasoningParams: [],
        ),
        provider: _providerWithNameOnlyEffort(),
      );

      expect(saved, isNotNull);
      // 未修改的继承参数不写入模型 → 模型保持跟随供应商同步
      expect(saved!.reasoningParams, isEmpty);
    });

    testWidgets(
        'claiming an inherited effort param by adding options saves it to the model',
        (tester) async {
      ModelConfig? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  saved = await Navigator.push<ModelConfig>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LlmModelConfigPage(
                        model: ModelConfig(
                          name: 'test-model',
                          modelId: 'test-model',
                          typeConfig: {'context': 4096},
                        ),
                        provider: _providerWithNameOnlyEffort(),
                      ),
                    ),
                  );
                },
                child: const Text('打开模型配置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开模型配置'));
      await tester.pumpAndSettle();

      // 编辑前：力度参数带「来自供应商」标记
      await _scrollToReasoning(tester, find.text('推理力度'));
      expect(find.text('来自供应商'), findsWidgets);

      // 给继承的力度参数添加选项值（参数名沿用供应商提供的名称）
      await tester.tap(find.text('添加选项'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, '选项 1'),
        'high',
      );
      await tester.pump();

      // 编辑后：回到开关区域，开关仍继承自供应商（徽章保留 1 个），
      // 被认领的力度参数徽章已消失
      await _scrollToReasoning(tester, find.text('thinking.type'),
          delta: -200);
      expect(find.text('来自供应商'), findsOneWidget,
          reason: '开关仍继承自供应商，力度参数已变为模型独立');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.reasoningParams.length, 1);
      final savedParam = saved!.reasoningParams.first;
      // 参数名沿用供应商提供的名称，选项值为模型设置
      expect(savedParam.paramName, 'reasoning_effort');
      expect(savedParam.options, ['high']);
      // 开关未修改 → 仍跟随供应商，不写入模型
    });

    testWidgets('model param with the same name overrides the provider one',
        (tester) async {
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'high'],
          ),
        ],
      );
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'medium', 'high'],
          ),
        ],
      );

      await _pumpAndSave(tester, model: model, provider: provider, tapSave: false);

      // 同名模型参数覆盖供应商参数：只显示一张力度卡片，且不是继承态
      await _scrollToReasoning(tester, find.text('reasoning_effort'));
      expect(find.text('reasoning_effort'), findsOneWidget);
      expect(find.text('来自供应商'), findsNothing);
      // 模型自身的选项值显示
      expect(find.text('low'), findsOneWidget);
    });

    testWidgets('back navigation without changes does not warn when only '
        'inherited params exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LlmModelConfigPage(
                      model: ModelConfig(
                        name: 'test-model',
                        modelId: 'test-model',
                        typeConfig: {'context': 4096},
                      ),
                      provider: _providerWithNameOnlyEffort(),
                    ),
                  ),
                ),
                child: const Text('打开模型配置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开模型配置'));
      await tester.pumpAndSettle();

      // 返回不弹「放弃修改」确认框（继承参数不算未保存修改）
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('放弃修改？'), findsNothing);
      expect(find.text('打开模型配置'), findsOneWidget,
          reason: '页面应已正常返回');
    });

    testWidgets('delete button hidden for provider-originated params '
        '(including claimed ones)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LlmModelConfigPage(
                      model: ModelConfig(
                        name: 'test-model',
                        modelId: 'test-model',
                        typeConfig: {'context': 4096},
                      ),
                      provider: _providerWithNameOnlyEffort(),
                    ),
                  ),
                ),
                child: const Text('打开模型配置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开模型配置'));
      await tester.pumpAndSettle();

      // 继承的开关 + 力度：均无删除按钮（删除会造成「无效删除」的错觉）
      await _scrollToReasoning(tester, find.text('推理力度'));
      expect(find.byIcon(Icons.delete), findsNothing);

      // 认领（添加选项）后删除按钮仍然隐藏：供应商参数只能覆盖不能删除
      await tester.tap(find.text('添加选项'));
      await tester.pump();
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('delete button visible for model-owned params even when the '
        'name collides with a provider param', (tester) async {
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'high'],
          ),
        ],
      );
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'medium', 'high'],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LlmModelConfigPage(
                      model: model,
                      provider: provider,
                    ),
                  ),
                ),
                child: const Text('打开模型配置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开模型配置'));
      await tester.pumpAndSettle();

      // 同名模型参数覆盖供应商参数 → 模型自有，删除按钮可见
      await _scrollToReasoning(tester, find.text('推理力度'));
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets(
        'claim is reversible: reverting an edit keeps the param inherited',
        (tester) async {
      // 编辑又被还原成与供应商原值一致 → 参数保持继承，保存不被
      // 「力度参数必须有选项值」拦截（避免改回去却无法保存的死局）。
      ModelConfig? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  saved = await Navigator.push<ModelConfig>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LlmModelConfigPage(
                        model: ModelConfig(
                          name: 'test-model',
                          modelId: 'test-model',
                          typeConfig: {'context': 4096},
                        ),
                        provider: _providerWithNameOnlyEffort(),
                      ),
                    ),
                  );
                },
                child: const Text('打开模型配置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开模型配置'));
      await tester.pumpAndSettle();

      // 编辑力度参数名（认领）→ 再还原为供应商原值（回退）
      await _scrollToReasoning(tester, find.text('reasoning_effort'));
      await tester.enterText(
        find.widgetWithText(TextFormField, '参数名').last,
        'effort_x',
      );
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, '参数名').last,
        'reasoning_effort',
      );
      await tester.pump();

      // 还原后仍为继承状态：徽章仍在
      expect(find.text('来自供应商'), findsWidgets);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.reasoningParams, isEmpty,
          reason: '还原后的参数不写入模型，保持跟随供应商');
    });

    testWidgets(
        'model custom param colliding with an inherited provider reasoning '
        'param is blocked at save', (tester) async {
      // 自定义参数与继承的供应商推理参数重名时，请求构建中自定义参数
      // 会覆盖推理参数、聊天开关形同虚设 → 保存必须拦截。
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'medium', 'high'],
          ),
        ],
      );
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'reasoning_effort',
            defaultValue: 'high',
            type: 'string',
          ),
        ],
      );

      await _pumpAndSave(tester, model: model, provider: provider);

      expect(find.text('推理参数与自定义参数存在重名: reasoning_effort'),
          findsOneWidget);
    });

    testWidgets(
        'new param identical to a provider param is not mistaken for '
        'inherited', (tester) async {
      // 新建的参数即使内容与供应商参数完全一致，也不得被标为继承
      // （否则会被静默丢弃）。按实例身份判定继承来源。
      final provider = ProviderConfigItem(
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
            paramName: 'budget_tokens',
            enabled: false,
            options: ['a', 'b'],
          ),
        ],
      );

      ModelConfig? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  saved = await Navigator.push<ModelConfig>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LlmModelConfigPage(
                        model: ModelConfig(
                          name: 'test-model',
                          modelId: 'test-model',
                          typeConfig: {'context': 4096},
                        ),
                        provider: provider,
                      ),
                    ),
                  );
                },
                child: const Text('打开模型配置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开模型配置'));
      await tester.pumpAndSettle();

      // 新建一个与供应商参数内容完全一致的附加参数
      await _scrollToReasoning(tester, find.text('添加推理参数'));
      await tester.tap(find.text('添加推理参数'));
      await tester.pump();
      // 新卡片位于列表末尾：其参数名输入框是最后一个 TextFormField
      await tester.enterText(
        find.byType(TextFormField).last,
        'budget_tokens',
      );
      await tester.pump();
      // 「添加选项」按钮：使用最后一个（新卡片自身的）
      await _scrollToReasoning(tester, find.text('添加选项').last);
      await tester.tap(find.text('添加选项').last);
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).last, 'a');
      await tester.pump();
      await _scrollToReasoning(tester, find.text('添加选项').last);
      await tester.tap(find.text('添加选项').last);
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).last, 'b');
      await tester.pump();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 新建参数是模型自有：保存进模型（而非被当作继承丢弃）
      expect(saved, isNotNull);
      expect(saved!.reasoningParams.map((p) => p.paramName),
          ['budget_tokens']);
    });

    testWidgets(
        'toggle with legacy null values: edit then clear reverts to inherited',
        (tester) async {
      // 旧数据中开关的开/关值可能为 null（UI 清空时写入 ''）。
      // 回退比较需将 '' 与 null 等价处理，否则「改了又清空」会被认领，
      // 且因开关值缺失而无法保存。
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            // onValue/offValue 为 null（旧数据形态）
          ),
        ],
      );

      ModelConfig? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  saved = await Navigator.push<ModelConfig>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LlmModelConfigPage(
                        model: ModelConfig(
                          name: 'test-model',
                          modelId: 'test-model',
                          typeConfig: {'context': 4096},
                        ),
                        provider: provider,
                      ),
                    ),
                  );
                },
                child: const Text('打开模型配置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开模型配置'));
      await tester.pumpAndSettle();

      // 编辑「开启时值」（认领）→ 再清空（还原）
      await _scrollToReasoning(tester, find.text('thinking.type'));
      await tester.enterText(
        find.widgetWithText(TextFormField, '开启时值'),
        'enabled',
      );
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, '开启时值'),
        '',
      );
      await tester.pump();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 还原成功 → 开关仍继承，不写入模型（若未还原，会因开关值缺失
      // 被校验拦截，saved 为 null）
      expect(saved, isNotNull);
      expect(saved!.reasoningParams, isEmpty);
    });

    testWidgets('new model with provider params still saves', (tester) async {
      ModelConfig? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  saved = await Navigator.push<ModelConfig>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LlmModelConfigPage(
                        provider: _providerWithNameOnlyEffort(),
                      ),
                    ),
                  );
                },
                child: const Text('打开模型配置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开模型配置'));
      await tester.pumpAndSettle();

      // 填写必填项（模型 ID、上下文长度）
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'test-model');
      await tester.enterText(textFields.at(2), '4096');
      await tester.pump();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.modelId, 'test-model');
      // 新建模型默认不写推理参数（继承参数未修改）
      expect(saved!.reasoningParams, isEmpty);
    });
  });
}
