// 供应商/模型自定义参数合并与勾选块顺序测试：
// - mergeCustomParams：模型同名覆盖、供应商追加、空名跳过（与
//   mergeReasoningParams 同语义）
// - mergeOptionBlocks：勾选状态不改变显示顺序（修复「选中值自动前置」）；
//   已保存的完整顺序（optionOrder）优先（拖动/添加跨重启保留）
// - selectedInBlockOrder：勾选值按块顺序归一化（保存与未保存比较共用）
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';

void main() {
  group('mergeCustomParams', () {
    CustomParam p(String name, {List<String> options = const []}) =>
        CustomParam(paramName: name, type: 'string', options: options);

    test('model params come first, then non-overridden provider params', () {
      final merged = mergeCustomParams(
        [p('provider_a'), p('provider_b')],
        [p('model_only')],
      );
      expect(merged.map((e) => e.paramName).toList(), [
        'model_only',
        'provider_a',
        'provider_b',
      ]);
    });

    test('model param with the same name replaces the provider param', () {
      final provider = p('temperature_style', options: ['warm', 'cool']);
      final model = p('temperature_style', options: ['balanced']);
      final merged = mergeCustomParams([provider], [model]);
      expect(merged.length, 1);
      expect(identical(merged.first, model), isTrue);
      expect(merged.first.options, ['balanced']);
    });

    test('empty-name params are skipped', () {
      final merged = mergeCustomParams(
        [CustomParam(paramName: ''), p('valid')],
        [],
      );
      expect(merged.map((e) => e.paramName).toList(), ['valid']);
    });

    test('empty-name model params do not shadow provider params', () {
      final merged = mergeCustomParams(
        [p('valid')],
        [CustomParam(paramName: '')],
      );
      expect(merged.map((e) => e.paramName).toList(), ['', 'valid']);
    });
  });

  group('mergeOptionBlocks', () {
    test('selection does not change display order (provider order first)', () {
      // 旧逻辑：已保存（=已勾选）的值排最前 → 重开后选中块跳到队首。
      // 新逻辑：供应商顺序在前，勾选状态不影响显示顺序。
      final blocks = mergeOptionBlocks(
        providerOptions: ['low', 'medium', 'high'],
        savedOptions: ['high', 'medium'],
      );
      expect(blocks, ['low', 'medium', 'high']);
    });

    test('model-only values are appended after provider values', () {
      final blocks = mergeOptionBlocks(
        providerOptions: ['low', 'high'],
        savedOptions: ['high', 'max'],
      );
      expect(blocks, ['low', 'high', 'max']);
    });

    test('saved full order (optionOrder) takes priority (drag persistence)',
        () {
      // 用户拖动过：完整块顺序已保存 → 重开时按该顺序恢复，
      // 供应商新增的值追加在后。
      final blocks = mergeOptionBlocks(
        providerOptions: ['low', 'medium', 'high'],
        savedOptions: ['high', 'low'],
        savedOrder: ['high', 'low', 'medium'],
      );
      expect(blocks, ['high', 'low', 'medium']);
    });

    test('provider additions are appended after the saved order', () {
      final blocks = mergeOptionBlocks(
        providerOptions: ['low', 'medium', 'ultra'],
        savedOptions: ['low'],
        savedOrder: ['low'],
      );
      expect(blocks, ['low', 'medium', 'ultra']);
    });

    test('empty saved order falls back to provider order', () {
      final blocks = mergeOptionBlocks(
        providerOptions: const [],
        savedOptions: ['a', 'b'],
      );
      expect(blocks, ['a', 'b']);
    });

    test('saved value missing from the saved order is kept (defensive)', () {
      final blocks = mergeOptionBlocks(
        providerOptions: ['low'],
        savedOptions: ['low', 'max'],
        savedOrder: ['low'],
      );
      expect(blocks, ['low', 'max']);
    });
  });

  group('selectedInBlockOrder', () {
    test('filters saved options by block order', () {
      final selected = selectedInBlockOrder(
        blocks: ['low', 'medium', 'high'],
        savedOptions: ['high', 'low'],
      );
      expect(selected, ['low', 'high']);
    });

    test('empty saved options produce an empty list', () {
      final selected = selectedInBlockOrder(
        blocks: ['low', 'medium'],
        savedOptions: const [],
      );
      expect(selected, isEmpty);
    });
  });
}
