// 模型配置页「推理力度勾选块」与拖拽排序测试：
// - 力度参数值显示为勾选块（复用推理面板 OptionChip 样式），默认全选
// - 点击块高亮/取消（多选），选中的值按块顺序写入模型 → 影响推理面板
// - 供应商的值不可删除（只能取消勾选）；模型添加的值带删除按钮
// - 块可拖拽排序；附加参数卡片与选项值也可拖拽排序
// - 每次打开同步供应商最新值（新值默认未勾选，勾一下即可使用）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

/// 打开模型配置页；[beforeSave] 在点保存前执行；返回保存结果。
Future<ModelConfig?> _pumpAndSave(
  WidgetTester tester, {
  ModelConfig? model,
  ProviderConfigItem? provider,
  bool tapSave = true,
  Future<void> Function(WidgetTester tester)? beforeSave,
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
    if (beforeSave != null) await beforeSave(tester);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
  }
  return saved;
}

/// 滚动到推理参数区域（ListView 懒构建，需先滚动到目标附近）。
Future<void> _scrollToReasoning(WidgetTester tester, Finder target,
    {double delta = 200}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// 构造一个「开关完整 + 推理力度带选项」的供应商配置。
ProviderConfigItem _providerWithEffortOptions(List<String> options) {
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
        options: options,
      ),
    ],
  );
}

/// 取保存结果中力度参数的选项（全量保存后 model 含开关+力度等参数）。
List<String> _savedEffortOptions(ModelConfig m) =>
    m.reasoningParams.firstWhere((p) => p.isEffortParam).options;

/// 长按拖拽（LongPressDraggable 需要长按后移动）。
Future<void> _longPressDrag(
  WidgetTester tester,
  Finder from,
  Offset offset,
) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveBy(offset);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 点击力度块勾选/取消（滚动到目标后点击）。
Future<void> _tapBlock(WidgetTester tester, String value) async {
  await _scrollToReasoning(tester, find.text(value));
  await tester.tap(find.text(value));
  await tester.pump();
}

void main() {
  group('LlmModelConfigPage reasoning option blocks', () {
    testWidgets(
        'provider effort values show as blocks, none selected by '
        'default', (tester) async {
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: _providerWithEffortOptions(['low', 'medium', 'high']),
        beforeSave: (tester) async {
          // 供应商的值以块形式显示
          await _scrollToReasoning(tester, find.text('reasoning_effort'));
          expect(find.text('low'), findsOneWidget);
          expect(find.text('medium'), findsOneWidget);
          expect(find.text('high'), findsOneWidget);
          // 供应商来源的块没有删除按钮
          expect(find.byIcon(Icons.close), findsNothing);
          // 无拖拽把手（胶囊长按拖拽）
          expect(find.byIcon(Icons.drag_handle), findsNothing);
        },
      );

      // 默认全不选 → 保存的 options 为空
      expect(saved, isNotNull);
      expect(_savedEffortOptions(saved!), isEmpty);
    });

    testWidgets('selecting blocks saves only the selected values',
        (tester) async {
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: _providerWithEffortOptions(['low', 'medium', 'high']),
        beforeSave: (tester) async {
          // 勾选 low 和 high（medium 保持不选）
          await _tapBlock(tester, 'low');
          await _tapBlock(tester, 'high');
        },
      );

      expect(saved, isNotNull);
      expect(_savedEffortOptions(saved!), ['low', 'high']);
    });

    testWidgets('adding a value via dialog creates a selected removable block',
        (tester) async {
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: _providerWithEffortOptions(['low', 'high']),
        beforeSave: (tester) async {
          // 添加新值 max
          await _scrollToReasoning(tester, find.text('添加值'));
          await tester.tap(find.text('添加值'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, 'max');
          await tester.pump();
          await tester.tap(find.text('确定'));
          await tester.pumpAndSettle();

          // 新块出现（默认勾选），且带删除按钮（非供应商来源）
          expect(find.text('max'), findsOneWidget);
          expect(find.byIcon(Icons.close), findsOneWidget);
        },
      );

      expect(saved, isNotNull);
      // 默认全不选：只保存勾选的新值 max
      expect(_savedEffortOptions(saved!), ['max']);
    });

    testWidgets('removing a custom block deletes it from the saved model',
        (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
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
            options: ['low', 'max'],
          ),
        ],
      );
      final provider = _providerWithEffortOptions(['low', 'medium']);

      final saved = await _pumpAndSave(
        tester,
        model: model,
        provider: provider,
        beforeSave: (tester) async {
          // 块列表 = 供应商 [low, medium] + 模型独有 [max]；max 带删除按钮
          await _scrollToReasoning(tester, find.text('max'));
          expect(find.byIcon(Icons.close), findsOneWidget);
          await tester.ensureVisible(find.byIcon(Icons.close));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.close));
          await tester.pump();
        },
      );

      expect(saved, isNotNull);
      // 删除 max 后，勾选只剩 low（medium 是模型此前保存中未勾选的）
      expect(_savedEffortOptions(saved!), ['low']);
    });

    testWidgets('long-press dragging blocks reorders the saved options',
        (tester) async {
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: _providerWithEffortOptions(['low', 'medium', 'high']),
        beforeSave: (tester) async {
          // 先勾选全部（默认全不选）
          await _tapBlock(tester, 'low');
          await _tapBlock(tester, 'medium');
          await _tapBlock(tester, 'high');
          // 长按 low 胶囊拖到 medium 上（横向排列，向右拖动）
          await _scrollToReasoning(tester, find.text('medium'));
          await _longPressDrag(tester, find.text('low'), const Offset(60, 0));
        },
      );

      expect(saved, isNotNull);
      expect(_savedEffortOptions(saved!), ['medium', 'low', 'high']);
    });

    testWidgets('provider changes appear on reopen (unchecked by default)',
        (tester) async {
      // 第一次：provider [low, medium] → 默认全不选，保存 options 为空
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: _providerWithEffortOptions(['low', 'medium']),
      );
      expect(_savedEffortOptions(saved!), isEmpty);

      // 第二次：provider 新增 high；模型打开时 high 出现（未勾选）
      await _pumpAndSave(
        tester,
        model: saved,
        provider: _providerWithEffortOptions(['low', 'medium', 'high']),
        tapSave: false,
      );
      await _scrollToReasoning(tester, find.text('high'));
      expect(find.text('high'), findsOneWidget);
    });

    testWidgets('additional params use pill blocks and are draggable and saved',
        (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'first_param',
            enabled: true,
            options: ['1', '2'],
          ),
          ReasoningParam(
            paramName: 'second_param',
            enabled: true,
            options: ['3'],
          ),
        ],
      );

      final saved = await _pumpAndSave(
        tester,
        model: model,
        beforeSave: (tester) async {
          // 附加参数值显示为胶囊块（默认全选；无 provider 时模型
          // 保存的值可删除 → 有删除按钮）
          await _scrollToReasoning(tester, find.text('first_param'));
          expect(find.text('1'), findsOneWidget);
          expect(find.text('2'), findsOneWidget);

          // 取消勾选 2 → 只保存 1
          await _tapBlock(tester, '2');
        },
      );

      expect(saved, isNotNull);
      expect(
        saved!.reasoningParams
            .firstWhere((p) => p.paramName == 'first_param')
            .options,
        ['1'],
      );
    });

    testWidgets(
        'adding a value to an additional param creates a deletable block',
        (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'first_param',
            enabled: true,
            options: ['1'],
          ),
        ],
      );

      final saved = await _pumpAndSave(
        tester,
        model: model,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('first_param'));
          // 添加新值 max（对话框）→ 新块出现（默认勾选）
          await tester.tap(find.text('添加值').first);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, 'max');
          await tester.pump();
          await tester.tap(find.text('确定'));
          await tester.pumpAndSettle();
          expect(find.text('max'), findsOneWidget);
        },
      );

      expect(saved, isNotNull);
      expect(
        saved!.reasoningParams
            .firstWhere((p) => p.paramName == 'first_param')
            .options,
        ['1', 'max'],
      );
    });

    testWidgets(
        'model custom param colliding with a provider reasoning param '
        'is blocked at save', (tester) async {
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

      expect(find.text('推理参数与自定义参数存在重名: reasoning_effort'), findsOneWidget);
    });

    testWidgets('back navigation without changes does not warn',
        (tester) async {
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
                      provider: _providerWithEffortOptions(['low', 'medium']),
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

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('放弃修改？'), findsNothing);
      expect(find.text('打开模型配置'), findsOneWidget, reason: '页面应已正常返回');
    });

    testWidgets(
        'model saved order differing from provider order is not unsaved',
        (tester) async {
      // 模型保存的力度选项顺序与供应商顺序不同（旧数据可能如此）：
      // 打开页面未做任何修改，返回不应弹「放弃修改」。
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
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
            options: ['high', 'low'], // 与供应商顺序相反
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
                      provider: _providerWithEffortOptions(['low', 'high']),
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

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('放弃修改？'), findsNothing, reason: '模型已保存顺序与供应商不同不应算未保存修改');
      expect(find.text('打开模型配置'), findsOneWidget);
    });

    testWidgets(
        'shadowed provider effort param does not trigger the discard dialog',
        (tester) async {
      // 模型有自己命名的力度参数、供应商有异名力度参数（被遮蔽）：
      // 打开页面未修改，返回不应弹「放弃修改」。
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
            paramName: 'provider.effort',
            isEffortParam: true,
            enabled: true,
            options: ['a', 'b'],
          ),
        ],
      );
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'model.effort',
            isEffortParam: true,
            options: ['x', 'y'],
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
                    builder: (_) =>
                        LlmModelConfigPage(model: model, provider: provider),
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

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('放弃修改？'), findsNothing, reason: '被遮蔽的供应商力度参数不应算未保存修改');
      expect(find.text('打开模型配置'), findsOneWidget);
    });

    testWidgets(
        'model effort param shadows a differently-named provider effort param',
        (tester) async {
      // 模型有自己命名的力度参数时，供应商的力度参数被遮蔽：
      // 模型页不显示它，保存也不应携带它（避免不可见的陈旧副本）。
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
            paramName: 'provider.effort',
            isEffortParam: true,
            enabled: true,
            options: ['a', 'b'],
          ),
        ],
      );
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'model.effort',
            isEffortParam: true,
            options: ['x', 'y'],
          ),
        ],
      );

      final saved =
          await _pumpAndSave(tester, model: model, provider: provider);

      expect(saved, isNotNull);
      // 供应商的 provider.effort 未进入模型（被 model.effort 遮蔽）
      expect(saved!.reasoningParams.map((p) => p.paramName).toList(),
          contains('model.effort'));
      expect(saved.reasoningParams.map((p) => p.paramName).toList(),
          isNot(contains('provider.effort')));
    });

    testWidgets('added effort values persist across reopen', (tester) async {
      // 添加值并保存 → 重开模型页 → 值仍在且勾选
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: _providerWithEffortOptions(['low', 'high']),
        beforeSave: (tester) async {
          // 勾选 low + 添加 max（自动勾选）
          await _tapBlock(tester, 'low');
          await _scrollToReasoning(tester, find.text('添加值'));
          await tester.tap(find.text('添加值'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, 'max');
          await tester.pump();
          await tester.tap(find.text('确定'));
          await tester.pumpAndSettle();
        },
      );
      expect(saved, isNotNull);
      expect(_savedEffortOptions(saved!), ['low', 'max']);

      // 重开：块列表 = 模型保存顺序 ['low','max'] + provider 独有 ['high']
      // 勾选 = 模型保存的 {'low','max'}
      await _pumpAndSave(
        tester,
        model: saved,
        provider: _providerWithEffortOptions(['low', 'high']),
        tapSave: false,
      );
      await _scrollToReasoning(tester, find.text('reasoning_effort'));
      expect(find.text('low'), findsOneWidget);
      expect(find.text('max'), findsOneWidget);
      expect(find.text('high'), findsOneWidget);
      // max 是自定义值 → 有删除按钮
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets(
        'provider name-only effort param (no values) is not shown on the '
        'model page', (tester) async {
      // 供应商只填了力度参数名、未设置选项值 → 模型页不显示它
      // （「没有就不显示」），用户可在模型页自建。
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
            paramName: 'reasoning_effort',
            isEffortParam: true,
            enabled: true,
            options: [],
          ),
        ],
      );

      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: provider,
        beforeSave: (tester) async {
          // 力度区不显示 provider 的名称式参数（无块、无参数名）
          await _scrollToReasoning(tester, find.text('推理参数'));
          expect(find.text('reasoning_effort'), findsNothing);
          expect(find.text('添加推理力度'), findsOneWidget, reason: '用户仍可在模型页自建力度参数');
        },
      );

      expect(saved, isNotNull);
      // provider 的名称式力度参数不写入模型
      expect(saved!.reasoningParams.where((p) => p.isEffortParam), isEmpty);
    });

    testWidgets('reset button restores the effort param to its open state',
        (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
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

      final saved = await _pumpAndSave(
        tester,
        model: model,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('reasoning_effort'));
          // 勾选 low 再取消 → 改为勾选 high
          await _tapBlock(tester, 'low');
          await _tapBlock(tester, 'high');
          // 点 reset（力度卡头部的刷新图标）
          final resetIcon = find
              .descendant(
                of: find.ancestor(
                  of: find.text('推理力度'),
                  matching: find.byType(Card),
                ),
                matching: find.byIcon(Icons.refresh),
              )
              .first;
          await tester.ensureVisible(resetIcon);
          await tester.pumpAndSettle();
          await tester.tap(resetIcon);
          await tester.pump();
        },
      );

      expect(saved, isNotNull);
      // reset 后还原为打开时勾选（模型保存的 ['low','high']）
      expect(_savedEffortOptions(saved!), ['low', 'high']);
    });

    testWidgets('param name label shows the source state', (tester) async {
      // provider 提供的参数 → 「当前：供应商」；模型保存的参数 → 模型自定义
      final provider = _providerWithEffortOptions(['low', 'medium']);
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          // 模型只保存了力度参数（无开关）→ 开关来自 provider
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'high'],
          ),
        ],
      );

      await _pumpAndSave(tester,
          model: model, provider: provider, tapSave: false);
      // 模型保存的力度参数 → 模型自定义
      await _scrollToReasoning(tester, find.text('reasoning_effort'));
      expect(find.textContaining('当前：模型自定义'), findsOneWidget);
      // provider 的推理开关（模型未保存）→ 供应商（滚动到开关区）
      await _scrollToReasoning(tester, find.text('thinking.type'), delta: -200);
      expect(find.textContaining('当前：供应商'), findsWidgets);
    });

    testWidgets('json type shows a large input instead of option blocks',
        (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'thinking_config',
            isEffortParam: true,
            type: 'json',
            options: ['{"thinking": {"budget": 1024}}'],
          ),
        ],
      );

      final saved = await _pumpAndSave(
        tester,
        model: model,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('thinking_config'));
          // json 类型：大输入框 + 无勾选块/添加值按钮
          expect(find.byType(TextField).last, findsOneWidget);
          // 大输入框内容即保存值
          await tester.enterText(
            find.widgetWithText(TextFormField, 'JSON 值'),
            '{"thinking": {"budget": 2048}}',
          );
          await tester.pump();
        },
      );

      expect(saved, isNotNull);
      final effort = saved!.reasoningParams.firstWhere((p) => p.isEffortParam);
      expect(effort.options, ['{"thinking": {"budget": 2048}}']);
    });

    testWidgets('boolean type has no value area', (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'use_cache',
            isEffortParam: true,
            type: 'boolean',
            options: [],
          ),
        ],
      );

      final saved = await _pumpAndSave(
        tester,
        model: model,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('use_cache'));
          // 布尔类型：无添加值按钮、无选项块
          expect(find.text('添加值'), findsNothing);
          expect(find.textContaining('无需配置参数值'), findsOneWidget);
        },
      );

      expect(saved, isNotNull);
      expect(_savedEffortOptions(saved!), isEmpty);
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
                        provider: _providerWithEffortOptions(['low', 'high']),
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
      // 新建模型：默认全不选 → 力度参数 options 为空（用户显式勾选）
      expect(_savedEffortOptions(saved!), isEmpty);
    });
  });
}
