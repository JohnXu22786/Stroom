// 模型配置页「推理力度勾选块」与拖拽排序测试：
// - 力度参数值显示为勾选块（复用推理面板 OptionChip 样式），默认全选
// - 点击块高亮/取消（多选），选中的值按块顺序写入模型 → 影响推理面板
// - 供应商的值不可删除（只能取消勾选）；模型添加的值带删除按钮
// - 块可拖拽排序；附加参数卡片与选项值也可拖拽排序
// - 每次打开同步供应商最新值（新值默认未勾选，勾一下即可使用）
// - 推理开关/推理力度卡不可删除（删除按钮被启用开关替换）；
//   供应商传递下来的附加推理参数与自定义参数同样不可删除
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
      // 与供应商同名的参数（模型只选择了值/顺序，参数定义一致）
      // → 「当前：供应商」；模型独有的参数 → 「当前：模型自定义」。
      final provider = _providerWithEffortOptions(['low', 'medium']);
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          // 与供应商开关同名的模型副本（定义一致）→ 供应商
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          // 模型保存的力度参数：只改了选项选择 → 供应商
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'high'],
          ),
          // 模型独有的参数 → 模型自定义
          ReasoningParam(
            paramName: 'model_only_param',
            options: ['x'],
          ),
        ],
      );

      await _pumpAndSave(tester,
          model: model, provider: provider, tapSave: false);
      await _scrollToReasoning(tester, find.text('reasoning_effort'));
      expect(find.textContaining('当前：供应商'), findsWidgets);
      await _scrollToReasoning(tester, find.text('model_only_param'));
      expect(find.textContaining('当前：模型自定义'), findsOneWidget);
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

    testWidgets('custom params use pill-block options (no default value box)',
        (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'temperature_style',
            defaultValue: 'balanced',
            type: 'string',
          ),
        ],
      );

      final saved = await _pumpAndSave(
        tester,
        model: model,
        beforeSave: (tester) async {
          // 旧数据升级：defaultValue → 第一个选项块
          await _scrollToReasoning(tester, find.text('自定义参数'));
          await tester.scrollUntilVisible(
            find.text('balanced'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(find.text('balanced'), findsOneWidget);
          // 没有「默认参数值」输入框；有「添加选项」按钮
          expect(find.text('默认参数值'), findsNothing);
          expect(find.text('添加选项'), findsOneWidget);

          // 添加新选项 creative
          await tester.tap(find.text('添加选项'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, 'creative');
          await tester.pump();
          await tester.tap(find.text('确定'));
          await tester.pumpAndSettle();
          expect(find.text('creative'), findsOneWidget);
        },
      );

      expect(saved, isNotNull);
      expect(saved!.customParams.single.options, ['balanced', 'creative']);
    });

    testWidgets('json custom param keeps the default value input',
        (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'thinking',
            defaultValue: '{"type": "enabled"}',
            type: 'json',
          ),
        ],
      );

      await _pumpAndSave(
        tester,
        model: model,
        tapSave: false,
      );
      await _scrollToReasoning(tester, find.text('thinking'));
      // json 类型：保留默认参数值输入框（无选项块）
      expect(find.text('默认参数值'), findsOneWidget);
      expect(find.text('添加选项'), findsNothing);
    });

    testWidgets(
        'boolean custom param has no value area (like reasoning '
        'boolean params)', (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'verbose',
            defaultValue: '',
            type: 'boolean',
          ),
        ],
      );

      final saved = await _pumpAndSave(
        tester,
        model: model,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('自定义参数'));
          await tester.scrollUntilVisible(
            find.text('verbose'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          // boolean：无参数值区（与推理参数 boolean 一致）
          expect(find.text('布尔类型无需配置参数值。'), findsOneWidget);
          expect(find.text('默认参数值'), findsNothing);
          expect(find.text('添加选项'), findsNothing);
        },
      );

      expect(saved, isNotNull);
      // 无值区 → options 为空
      expect(saved!.customParams.single.options, isEmpty);
    });

    testWidgets('legacy custom param (defaultValue) open+back does not warn',
        (tester) async {
      // 旧数据：string 类型只有 defaultValue（无 options）——打开时升级
      // 为选项块，但不应算未保存修改
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'temperature_style',
            defaultValue: 'balanced',
            type: 'string',
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
                    builder: (_) => LlmModelConfigPage(model: model),
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
      expect(find.text('打开模型配置'), findsOneWidget);
    });

    testWidgets('unchecking all custom param options blocks save',
        (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'temperature_style',
            defaultValue: 'balanced',
            type: 'string',
          ),
        ],
      );

      final saved = await _pumpAndSave(
        tester,
        model: model,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('自定义参数'));
          await tester.scrollUntilVisible(
            find.text('balanced'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          // 取消勾选唯一选项
          await tester.tap(find.text('balanced'));
          await tester.pump();
        },
      );

      // 保存被拦（空值参数）
      expect(saved, isNull);
      expect(find.text('自定义参数的参数名和值不能为空'), findsOneWidget);
    });

    testWidgets('new additional param can add values and save', (tester) async {
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
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
          ],
        ),
        beforeSave: (tester) async {
          // 添加新的附加参数 + 填参数名 + 值
          await _scrollToReasoning(tester, find.text('添加推理参数'));
          await tester.tap(find.text('添加推理参数'));
          await tester.pump();
          await _scrollToReasoning(tester, find.text('添加值'));
          // 新卡片参数名输入框（最后一个 TextFormField）填名
          await tester.enterText(
            find.byType(TextFormField).last,
            'max_retries',
          );
          await tester.pump();
          final addValueBtn = find.text('添加值').last;
          await tester.ensureVisible(addValueBtn);
          await tester.pumpAndSettle();
          await tester.tap(addValueBtn);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, 'auto');
          await tester.pump();
          await tester.tap(find.text('确定'));
          await tester.pumpAndSettle();
        },
      );

      expect(saved, isNotNull);
      expect(
        saved!.reasoningParams
            .where((p) => !p.isReasoningToggle && !p.isEffortParam)
            .single
            .options,
        ['auto'],
      );
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

    testWidgets(
        'opening the model page never mutates the provider config '
        '(model edits stay model-only)', (tester) async {
      // 回归：_hasUnsavedChanges 的基线归一化曾直接修改合并结果中
      // 供应商的共享实例（清空力度选项），导致模型页的勾选/排序泄漏
      // 到供应商配置。打开页面（构建即评估基线）后供应商必须原样。
      final provider = _providerWithEffortOptions(['low', 'medium', 'high']);
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

      final providerEffort =
          provider.reasoningParams.firstWhere((p) => p.isEffortParam);
      expect(providerEffort.options, ['low', 'medium', 'high'],
          reason: '打开模型页不应修改供应商的力度选项');
      expect(
        provider.reasoningParams.firstWhere((p) => p.isReasoningToggle).onValue,
        'enabled',
        reason: '开关值也不应被模型页改动',
      );

      // 返回页面也不应触发任何写回
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        provider.reasoningParams.firstWhere((p) => p.isEffortParam).options,
        ['low', 'medium', 'high'],
      );
    });

    testWidgets(
        'saved selection reappears on reopen with provider values '
        'unchecked and no delete badges', (tester) async {
      // 回归：模型页勾选保存后重开，供应商的值必须重新出现（未勾选、
      // 无删除按钮），而不是全部变成「模型自定义 + 带叉号」。
      final provider = _providerWithEffortOptions(['low', 'medium', 'high']);
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: provider,
        beforeSave: (tester) async {
          await _tapBlock(tester, 'low');
          await _tapBlock(tester, 'high');
        },
      );
      expect(saved, isNotNull);
      expect(_savedEffortOptions(saved!), ['low', 'high']);

      // 重开：未勾选的 medium 重新出现且无删除按钮（供应商值）
      await _pumpAndSave(
        tester,
        model: saved,
        provider: provider,
        tapSave: false,
      );
      await _scrollToReasoning(tester, find.text('medium'));
      expect(find.text('medium'), findsOneWidget, reason: '未勾选的供应商值应重新出现');
      expect(find.text('low'), findsOneWidget);
      expect(find.text('high'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing, reason: '供应商来源的值不应带删除按钮');
      // 参数归属仍是供应商
      await _scrollToReasoning(tester, find.text('reasoning_effort'));
      expect(find.textContaining('当前：供应商'), findsWidgets);
    });

    testWidgets(
        'provider name-only effort param does not trigger the discard '
        'dialog on back', (tester) async {
      // 回归：供应商的名称式力度参数（仅参数名、无选项）被 initState
      // 从工作副本移除，基线比较必须镜像同一处理，否则打开未修改
      // 直接返回也会弹「放弃修改」。
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

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('放弃修改？'), findsNothing,
          reason: '名称式供应商力度参数（无选项）不应算未保存修改');
      expect(find.text('打开模型配置'), findsOneWidget);
    });

    testWidgets(
        'boolean reasoning toggle has no on/off inputs and saves '
        'by name only', (tester) async {
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        beforeSave: (tester) async {
          // 添加推理开关
          await _scrollToReasoning(tester, find.text('添加推理开关'));
          await tester.tap(find.text('添加推理开关'));
          await tester.pump();
          // 填参数名
          await tester.enterText(
            find.byType(TextFormField).first,
            'enable_reasoning',
          );
          await tester.pump();
          // 切换类型为布尔
          await tester.tap(find.text('字符串'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('布尔').last);
          await tester.pumpAndSettle();
          // 与推理力度一致：没有开/关值输入框
          expect(find.text('开启时值'), findsNothing);
          expect(find.text('关闭时值'), findsNothing);
          expect(find.textContaining('无需配置参数值'), findsOneWidget);
        },
      );

      expect(saved, isNotNull);
      final toggle =
          saved!.reasoningParams.firstWhere((p) => p.isReasoningToggle);
      expect(toggle.paramName, 'enable_reasoning');
      expect(toggle.type, 'boolean');
      expect(toggle.onValue, isEmpty);
      expect(toggle.offValue, isEmpty);
      expect(toggle.isFilledToggle, isTrue);
    });

    testWidgets('reset does not crash for a boolean effort param',
        (tester) async {
      // 回归：sync 会把 boolean 参数的 options 替换为 const []（前提是
      // 保存过选项值），reset 就地 clear() 曾抛 UnsupportedError。
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            type: 'boolean',
          ),
          ReasoningParam(
            paramName: 'effort_flag',
            isEffortParam: true,
            type: 'boolean',
            options: ['true'],
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
            type: 'boolean',
          ),
          ReasoningParam(
            paramName: 'effort_flag',
            isEffortParam: true,
            type: 'boolean',
            options: ['true'],
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

      await _scrollToReasoning(tester, find.text('推理力度'));
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
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'reset 不应在 const [] options 上抛 UnsupportedError');
    });

    testWidgets(
        'boolean effort param switched to json does not crash on typing',
        (tester) async {
      // 回归：sync 把 boolean 参数 options 替换为 const [] 后，切到
      // json 类型再输入，旧代码就地 clear() 抛 UnsupportedError。
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            type: 'boolean',
          ),
          ReasoningParam(
            paramName: 'effort_flag',
            isEffortParam: true,
            type: 'boolean',
            options: ['true'],
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
            type: 'boolean',
          ),
          ReasoningParam(
            paramName: 'effort_flag',
            isEffortParam: true,
            type: 'boolean',
            options: ['true'],
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

      await _scrollToReasoning(tester, find.text('推理力度'));
      // 力度卡的类型下拉（布尔）→ 切到 JSON
      await tester.tap(find.text('布尔').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('JSON').last);
      await tester.pumpAndSettle();

      // 输入 JSON 值：不应抛 UnsupportedError
      await tester.enterText(
        find.widgetWithText(TextFormField, 'JSON 值'),
        '{"thinking": {"budget": 1024}}',
      );
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'json 输入不应在 const [] options 上抛 UnsupportedError');
    });

    testWidgets(
        'additional param with empty saved options and same-name provider '
        'param does not warn on back', (tester) async {
      // 回归：模型保存的附加参数选项为空、供应商同名参数有选项时，
      // 打开即默认全选供应商值——基线必须镜像该语义，否则返回误弹
      // 「放弃修改」。
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
            paramName: 'legacy_param',
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
          // 旧数据：同名参数存在但未保存任何选项
          ReasoningParam(
            paramName: 'legacy_param',
            enabled: true,
            options: [],
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
      expect(find.text('放弃修改？'), findsNothing,
          reason: '空选项旧数据 + 供应商同名参数不应算未保存修改');
      expect(find.text('打开模型配置'), findsOneWidget);
    });
  });

  group('LlmModelConfigPage provider custom params inheritance', () {
    ProviderConfigItem providerWithCustomParams({
      List<String> options = const ['warm', 'cool'],
    }) {
      return ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        customParams: [
          CustomParam(
            paramName: 'voice_style',
            type: 'string',
            options: options,
          ),
        ],
      );
    }

    /// 滚动到自定义参数区并确保 [value] 可见。
    Future<void> scrollToCustomValue(WidgetTester tester, String value) async {
      await _scrollToReasoning(tester, find.text('自定义参数'));
      await tester.scrollUntilVisible(
        find.text(value),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        'provider custom params are inherited into the model page and saved',
        (tester) async {
      final provider = providerWithCustomParams();
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: provider,
        beforeSave: (tester) async {
          // 供应商自定义参数直接显示在本页（继承视图，与推理参数一致）
          await scrollToCustomValue(tester, 'voice_style');
          expect(find.text('voice_style'), findsOneWidget);
          expect(find.text('warm'), findsOneWidget);
          expect(find.text('cool'), findsOneWidget);
          // 供应商来源的选项不可删除（只能取消勾选）
          expect(find.byIcon(Icons.close), findsNothing);
        },
      );

      expect(saved, isNotNull);
      // 保存后模型携带供应商参数（默认全选 → options = 供应商全部选项）
      expect(saved!.customParams.single.paramName, 'voice_style');
      expect(saved.customParams.single.options, ['warm', 'cool']);
    });

    testWidgets(
        'provider custom param uncheck persists; the unselected '
        'value reappears unchecked on reopen', (tester) async {
      final provider = providerWithCustomParams();
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: provider,
        beforeSave: (tester) async {
          await scrollToCustomValue(tester, 'warm');
          // 默认全选 → 取消勾选 warm
          await tester.tap(find.text('warm'));
          await tester.pump();
        },
      );

      expect(saved, isNotNull);
      expect(saved!.customParams.single.options, ['cool']);

      // 重开：warm 重新出现但未勾选（供应商值重新同步）
      await _pumpAndSave(tester,
          model: saved, provider: provider, tapSave: false);
      await scrollToCustomValue(tester, 'warm');
      expect(find.text('warm'), findsOneWidget, reason: '未勾选的供应商值应重新出现');
      expect(find.text('cool'), findsOneWidget);
      final warmText = tester.widget<Text>(find.text('warm'));
      expect(warmText.style?.fontWeight, FontWeight.normal,
          reason: '重开后 warm 应保持未勾选');
    });

    testWidgets(
        'opening the page with provider custom params and going back '
        'does not warn', (tester) async {
      // 新模型 + 供应商自定义参数：打开即显示供应商参数不算改动，
      // 返回不应弹「放弃修改」。
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
                      provider: providerWithCustomParams(),
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
      expect(find.text('放弃修改？'), findsNothing, reason: '供应商自定义参数继承显示不应算未保存修改');
      expect(find.text('打开模型配置'), findsOneWidget);
    });

    testWidgets(
        'editing a model: unchecking a custom param chip triggers the '
        'discard dialog on back', (tester) async {
      // 回归：块操作只改内存中的块列表/勾选集合，不同步则未保存比较
      // 看不到任何变化 → 编辑模式下的勾选改动被静默丢弃。
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'voice_style',
            type: 'string',
            options: ['warm', 'cool'],
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
                    builder: (_) => LlmModelConfigPage(model: model),
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

      await scrollToCustomValue(tester, 'warm');
      await tester.tap(find.text('warm'));
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('放弃修改？'), findsOneWidget, reason: '取消勾选自定义参数块应算未保存修改');
    });
  });

  group('LlmModelConfigPage block order (no selection auto-fronting)', () {
    testWidgets('selected effort values keep the provider order on reopen',
        (tester) async {
      // 勾选 low + high（跳过 medium）保存 → 重开后块顺序保持供应商
      // 顺序 [low, medium, high]，而不是选中前置的 [low, high, medium]。
      final provider = _providerWithEffortOptions(['low', 'medium', 'high']);
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: provider,
        beforeSave: (tester) async {
          await _tapBlock(tester, 'low');
          await _tapBlock(tester, 'high');
        },
      );
      expect(saved, isNotNull);
      expect(_savedEffortOptions(saved!), ['low', 'high']);

      await _pumpAndSave(tester,
          model: saved, provider: provider, tapSave: false);
      await _scrollToReasoning(tester, find.text('reasoning_effort'));
      final lowX = tester.getTopLeft(find.text('low')).dx;
      final mediumX = tester.getTopLeft(find.text('medium')).dx;
      final highX = tester.getTopLeft(find.text('high')).dx;
      expect(lowX < mediumX, isTrue, reason: '选中的 low 不应被未选中的 medium 挤到后面');
      expect(mediumX < highX, isTrue, reason: '选中的 high 不应自动前置');
    });

    testWidgets('dragged block order persists across reopen', (tester) async {
      // 用户拖动过的块顺序保存到 optionOrder：重开后按拖动顺序恢复，
      // 而不是退回供应商顺序。
      final provider = _providerWithEffortOptions(['low', 'medium', 'high']);
      final saved = await _pumpAndSave(
        tester,
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        ),
        provider: provider,
        beforeSave: (tester) async {
          await _tapBlock(tester, 'low');
          await _tapBlock(tester, 'medium');
          await _tapBlock(tester, 'high');
          // 长按 low 拖到末尾
          await _scrollToReasoning(tester, find.text('medium'));
          await _longPressDrag(tester, find.text('low'), const Offset(250, 0));
        },
      );
      expect(saved, isNotNull);
      expect(_savedEffortOptions(saved!), ['medium', 'high', 'low']);

      await _pumpAndSave(tester,
          model: saved, provider: provider, tapSave: false);
      await _scrollToReasoning(tester, find.text('reasoning_effort'));
      final mediumX = tester.getTopLeft(find.text('medium')).dx;
      final highX = tester.getTopLeft(find.text('high')).dx;
      final lowX = tester.getTopLeft(find.text('low')).dx;
      expect(mediumX < highX && highX < lowX, isTrue,
          reason: '拖动顺序应跨重启保留（optionOrder）');
    });
  });

  group(
      'LlmModelConfigPage switch-locked effort/toggle and inherited delete lock',
      () {
    /// 卡片（按标题文本定位）内的开关。
    Finder switchInCard(String headerText) => find.descendant(
          of: find.ancestor(
            of: find.text(headerText),
            matching: find.byType(Card),
          ),
          matching: find.byType(Switch),
        );

    ReasoningParam toggleParam() => ReasoningParam(
          paramName: 'thinking.type',
          isReasoningToggle: true,
          onValue: 'enabled',
          offValue: 'disabled',
        );

    testWidgets(
        'effort card: switch replaces the delete button and saves '
        'enabled=false', (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          toggleParam(),
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
          await _scrollToReasoning(tester, find.text('推理力度'));
          // 删除按钮被开关替换：卡内无删除按钮、有开关且默认开启
          final effortCard = find.ancestor(
            of: find.text('推理力度'),
            matching: find.byType(Card),
          );
          expect(
            find.descendant(
                of: effortCard, matching: find.byIcon(Icons.delete)),
            findsNothing,
            reason: '推理力度不允许删除，不应有删除按钮',
          );
          final sw = switchInCard('推理力度');
          expect(sw, findsOneWidget);
          expect(tester.widget<Switch>(sw).value, isTrue);
          // 关掉开关 → 保存 enabled=false
          await tester.tap(sw);
          await tester.pump();
        },
      );
      expect(saved, isNotNull);
      expect(
        saved!.reasoningParams.firstWhere((p) => p.isEffortParam).enabled,
        isFalse,
      );
    });

    testWidgets(
        'toggle card: switch replaces the delete button and saves '
        'enabled=false', (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          toggleParam(),
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low'],
          ),
        ],
      );
      final saved = await _pumpAndSave(
        tester,
        model: model,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('推理开关'));
          // 删除按钮被开关替换：卡内无删除按钮、有开关且默认开启
          final toggleCard = find.ancestor(
            of: find.text('推理开关'),
            matching: find.byType(Card),
          );
          expect(
            find.descendant(
                of: toggleCard, matching: find.byIcon(Icons.delete)),
            findsNothing,
            reason: '推理开关不允许删除，不应有删除按钮',
          );
          final sw = switchInCard('推理开关');
          expect(sw, findsOneWidget);
          expect(tester.widget<Switch>(sw).value, isTrue);
          // 关掉开关 → 保存 enabled=false
          await tester.tap(sw);
          await tester.pump();
        },
      );
      expect(saved, isNotNull);
      expect(
        saved!.reasoningParams.firstWhere((p) => p.isReasoningToggle).enabled,
        isFalse,
      );
    });

    testWidgets('reset restores the effort switch to its open state',
        (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          toggleParam(),
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
          await _scrollToReasoning(tester, find.text('推理力度'));
          // 先关掉开关
          final sw = switchInCard('推理力度');
          await tester.tap(sw);
          await tester.pump();
          expect(tester.widget<Switch>(switchInCard('推理力度')).value, isFalse);
          // 点 reset（力度卡头部的刷新图标）→ 开关恢复为开
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
          await tester.pumpAndSettle();
          expect(tester.widget<Switch>(switchInCard('推理力度')).value, isTrue,
              reason: 'reset 应还原开关到打开时的状态');
        },
      );
      expect(saved, isNotNull);
      expect(
        saved!.reasoningParams.firstWhere((p) => p.isEffortParam).enabled,
        isTrue,
      );
    });

    testWidgets(
        'provider-inherited additional param cannot be deleted; '
        'model-added one can', (tester) async {
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          toggleParam(),
          ReasoningParam(
            paramName: 'provider_param',
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
          toggleParam(),
          ReasoningParam(
            paramName: 'model_param',
            enabled: true,
            options: ['x'],
          ),
        ],
      );
      final saved = await _pumpAndSave(
        tester,
        model: model,
        provider: provider,
        beforeSave: (tester) async {
          // 供应商传递下来的附加参数：无删除按钮
          await _scrollToReasoning(tester, find.text('provider_param'));
          final providerCard = find.ancestor(
            of: find.text('provider_param'),
            matching: find.byType(Card),
          );
          expect(
            find.descendant(
                of: providerCard, matching: find.byIcon(Icons.delete)),
            findsNothing,
            reason: '供应商传递下来的附加推理参数不可删除',
          );
          // 模型自己的参数：有删除按钮，可删除
          await _scrollToReasoning(tester, find.text('model_param'));
          final modelCard = find.ancestor(
            of: find.text('model_param'),
            matching: find.byType(Card),
          );
          final del = find.descendant(
            of: modelCard,
            matching: find.byIcon(Icons.delete),
          );
          expect(del, findsOneWidget, reason: '模型自己添加的附加参数应可删除');
          await tester.ensureVisible(del);
          await tester.pumpAndSettle();
          await tester.tap(del);
          await tester.pump();
        },
      );
      expect(saved, isNotNull);
      expect(saved!.reasoningParams.map((p) => p.paramName).toList(),
          isNot(contains('model_param')));
      expect(saved.reasoningParams.map((p) => p.paramName).toList(),
          contains('provider_param'));
    });

    testWidgets(
        'provider-inherited custom param cannot be deleted; '
        'model-added one can', (tester) async {
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        customParams: [
          CustomParam(
            paramName: 'voice_style',
            type: 'string',
            options: ['warm', 'cool'],
          ),
        ],
      );
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'my_param',
            type: 'string',
            options: ['x'],
          ),
        ],
      );
      final saved = await _pumpAndSave(
        tester,
        model: model,
        provider: provider,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('自定义参数'));
          // 供应商传递下来的自定义参数：无删除按钮
          await tester.scrollUntilVisible(
            find.text('voice_style'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final providerCard = find.ancestor(
            of: find.text('voice_style'),
            matching: find.byType(Card),
          );
          expect(
            find.descendant(
                of: providerCard, matching: find.byIcon(Icons.delete)),
            findsNothing,
            reason: '供应商传递下来的自定义参数不可删除',
          );
          // 模型自己的参数：有删除按钮，可删除
          await tester.scrollUntilVisible(
            find.text('my_param'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final modelCard = find.ancestor(
            of: find.text('my_param'),
            matching: find.byType(Card),
          );
          final del = find.descendant(
            of: modelCard,
            matching: find.byIcon(Icons.delete),
          );
          expect(del, findsOneWidget, reason: '模型自己添加的自定义参数应可删除');
          await tester.ensureVisible(del);
          await tester.pumpAndSettle();
          await tester.tap(del);
          await tester.pump();
        },
      );
      expect(saved, isNotNull);
      expect(saved!.customParams.map((p) => p.paramName).toList(),
          ['voice_style']);
    });

    testWidgets(
        'session-added additional param renamed to a provider name '
        'stays deletable', (tester) async {
      // 本会话「添加推理参数」创建的参数即使改名为供应商同名参数，
      // 仍是模型自己的参数（可删除），不应被误锁。
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          toggleParam(),
          ReasoningParam(
            paramName: 'provider_param',
            enabled: true,
            options: ['a', 'b'],
          ),
        ],
      );
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [toggleParam()],
      );
      await _pumpAndSave(
        tester,
        model: model,
        provider: provider,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('添加推理参数'));
          await tester.tap(find.text('添加推理参数'));
          await tester.pump();
          // 新卡片在最后：参数名输入框是最后一个 TextFormField
          await tester.enterText(
            find.byType(TextFormField).last,
            'provider_param',
          );
          await tester.pump();
          // 供应商卡片无删除按钮；本会话新建的卡片仍有删除按钮
          expect(find.byIcon(Icons.delete), findsOneWidget,
              reason: '本会话新建的附加参数改名后仍应可删除');
        },
      );
    });

    testWidgets(
        'provider-inherited additional param becomes deletable after '
        'its type is changed', (tester) async {
      // 修改供应商参数的参数定义（类型）后，参数归模型所有 → 可删除。
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          toggleParam(),
          ReasoningParam(
            paramName: 'provider_param',
            enabled: true,
            options: ['a', 'b'],
          ),
        ],
      );
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [toggleParam()],
      );
      await _pumpAndSave(
        tester,
        model: model,
        provider: provider,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('provider_param'));
          final providerCard = find.ancestor(
            of: find.text('provider_param'),
            matching: find.byType(Card),
          );
          expect(
            find.descendant(
                of: providerCard, matching: find.byIcon(Icons.delete)),
            findsNothing,
            reason: '供应商来源的附加参数初始不可删除',
          );
          // 类型：字符串 → 数字
          await tester.tap(
            find.descendant(of: providerCard, matching: find.text('字符串')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('数字').last);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
                of: providerCard, matching: find.byIcon(Icons.delete)),
            findsOneWidget,
            reason: '修改参数定义后参数归模型所有，应可删除',
          );
        },
      );
    });

    testWidgets(
        'session-added custom param renamed to a provider name stays '
        'deletable', (tester) async {
      // 与附加参数同款：本会话新建的自定义参数改名成供应商同名后
      // 仍应可删除（不被误锁）。
      final provider = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        customParams: [
          CustomParam(
            paramName: 'voice_style',
            type: 'string',
            options: ['warm', 'cool'],
          ),
        ],
      );
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
      );
      await _pumpAndSave(
        tester,
        model: model,
        provider: provider,
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('自定义参数'));
          await tester.tap(find.text('添加参数'));
          await tester.pump();
          // 新参数插入到列表头部：其参数名输入框是第一个 TextFormField
          await tester.enterText(
            find.byType(TextFormField).first,
            'voice_style',
          );
          await tester.pump();
          // 供应商卡片无删除按钮；本会话新建的卡片仍有删除按钮
          expect(find.byIcon(Icons.delete), findsOneWidget,
              reason: '本会话新建的自定义参数改名后仍应可删除');
        },
      );
    });

    testWidgets(
        'toggling the effort switch does not relabel the param as '
        'model-defined', (tester) async {
      // enabled 是模型偏好（默认启用标记），不是参数定义的一部分：
      // 关闭供应商参数的开关不应把来源标签从「当前：供应商」改成
      // 「当前：模型自定义」。
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          toggleParam(),
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'high'],
          ),
        ],
      );
      await _pumpAndSave(
        tester,
        model: model,
        provider: _providerWithEffortOptions(['low', 'high']),
        beforeSave: (tester) async {
          await _scrollToReasoning(tester, find.text('推理力度'));
          final effortCard = find.ancestor(
            of: find.text('推理力度'),
            matching: find.byType(Card),
          );
          expect(
            find.descendant(
                of: effortCard, matching: find.textContaining('当前：供应商')),
            findsOneWidget,
          );
          // 关掉开关
          await tester.tap(switchInCard('推理力度'));
          await tester.pump();
          expect(
            find.descendant(
                of: effortCard, matching: find.textContaining('当前：供应商')),
            findsOneWidget,
            reason: '关闭开关不应把供应商参数标签改成模型自定义',
          );
        },
      );
    });

    testWidgets('toggling the switch triggers the discard dialog on back',
        (tester) async {
      // 开关改变 enabled 是未保存修改：返回时应弹「放弃修改」。
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          toggleParam(),
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'high'],
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
                    builder: (_) => LlmModelConfigPage(model: model),
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

      await _scrollToReasoning(tester, find.text('推理力度'));
      await tester.tap(switchInCard('推理力度'));
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('放弃修改？'), findsOneWidget,
          reason: '开关切换（enabled 变化）应算未保存修改');
    });
  });
}
