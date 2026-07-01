import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/models/tts_models.dart';

void main() {
  group('Cross-check duplicate names between reasoning params and custom params', () {
    /// Simulates the save validation logic from llm_model_config_page.dart.
    /// Returns null if valid, or an error message string if invalid.
    String? validateNoDuplicateAcrossParams({
      required List<ReasoningParam> reasoningParams,
      required List<CustomParam> customParams,
    }) {
      // Collect all custom param names
      final allNames = <String>{};

      // Check custom params internally (existing behavior)
      for (final param in customParams) {
        final name = param.paramName.trim();
        if (name.isEmpty) continue;
        if (!allNames.add(name)) {
          return '已存在该参数: $name';
        }
      }

      // Check reasoning params internally (existing behavior)
      final reasoningSeenNames = <String>{};
      for (final param in reasoningParams) {
        final name = param.paramName.trim();
        if (name.isEmpty) continue;
        if (!reasoningSeenNames.add(name)) {
          return '推理参数存在重名: $name';
        }
      }

      // NEW CROSS-CHECK: Check reasoning param names against custom param names
      for (final param in reasoningParams) {
        final name = param.paramName.trim();
        if (name.isEmpty) continue;
        if (!allNames.add(name)) {
          return '推理参数与自定义参数存在重名: $name';
        }
      }

      return null;
    }

    test('reasoning param and custom param with same name should be rejected', () {
      final reasoningParams = [
        ReasoningParam(paramName: 'thinking.type', options: ['enabled']),
      ];
      final customParams = [
        CustomParam(paramName: 'thinking.type', defaultValue: 'true'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNotNull);
      expect(result, contains('重名'));
    });

    test('reasoning param and custom param with different names should be valid', () {
      final reasoningParams = [
        ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'high']),
      ];
      final customParams = [
        CustomParam(paramName: 'temperature', defaultValue: '0.7'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNull);
    });

    test('multiple reasoning params and custom params with unique names should be valid', () {
      final reasoningParams = [
        ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'high']),
        ReasoningParam(paramName: 'thinking.type', options: ['a', 'b']),
      ];
      final customParams = [
        CustomParam(paramName: 'temperature', defaultValue: '0.7'),
        CustomParam(paramName: 'max_tokens', defaultValue: '4096'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNull);
    });

    test('duplicate within reasoning params still caught (existing behavior preserved)', () {
      final reasoningParams = [
        ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'high']),
        ReasoningParam(paramName: 'reasoning_effort', options: ['1', '2']),
      ];
      final customParams = [
        CustomParam(paramName: 'temperature', defaultValue: '0.7'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNotNull);
      expect(result, contains('推理参数存在重名'));
    });

    test('duplicate within custom params still caught (existing behavior preserved)', () {
      final reasoningParams = [
        ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'high']),
      ];
      final customParams = [
        CustomParam(paramName: 'temperature', defaultValue: '0.7'),
        CustomParam(paramName: 'temperature', defaultValue: '0.5'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNotNull);
      expect(result, contains('已存在该参数'));
    });

    test('empty param names are skipped in cross-check', () {
      final reasoningParams = [
        ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'high']),
      ];
      final customParams = [
        CustomParam(paramName: '', defaultValue: ''),
        CustomParam(paramName: 'temperature', defaultValue: '0.7'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNull);
    });

    test('toggle reasoning param flagged as duplicate with custom param', () {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'thinking.type',
          isReasoningToggle: true,
          onValue: 'enabled',
          offValue: 'disabled',
        ),
      ];
      final customParams = [
        CustomParam(paramName: 'thinking.type', defaultValue: 'enabled'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNotNull);
      expect(result, contains('重名'));
    });
  });
}
