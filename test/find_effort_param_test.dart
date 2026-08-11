import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';

/// Behavior tests for [findEffortParam] and [ReasoningParam.hasExplicitEffortFlag].
///
/// The effort param lookup must stay consistent between:
/// - modern data (saved with the isEffortParam flag, where false means
///   "deliberately not the effort param") — never fall back;
/// - legacy data (saved before the flag existed, where the first non-toggle
///   param WAS the effort param by position) — fall back to first non-toggle.
void main() {
  group('findEffortParam', () {
    ReasoningParam toggle() => ReasoningParam(
          paramName: 'thinking.type',
          isReasoningToggle: true,
          onValue: 'enabled',
          offValue: 'disabled',
        );

    test('returns the param explicitly marked isEffortParam', () {
      final params = [
        toggle(),
        ReasoningParam(paramName: 'budget_tokens', options: ['5000']),
        ReasoningParam(
          paramName: 'reasoning_effort',
          isEffortParam: true,
          options: ['low', 'medium', 'high'],
        ),
      ];
      expect(findEffortParam(params)?.paramName, 'reasoning_effort');
    });

    test('returns null for modern data with explicit flags but no effort param',
        () {
      final params = [
        toggle(),
        ReasoningParam(
          paramName: 'budget_tokens',
          isEffortParam: false,
          options: ['5000', '10000'],
        ),
      ];
      // Both params carry the explicit flag (code-constructed), none is
      // the effort param — no fallback must be applied.
      expect(findEffortParam(params), isNull);
    });

    test('legacy data (no explicit flags) falls back to first non-toggle param',
        () {
      // Real legacy lists are parsed entirely from pre-flag JSON:
      // NO param carries the isEffortParam key.
      ReasoningParam legacyToggle() => ReasoningParam.fromMap({
            'paramName': 'thinking.type',
            'options': <String>[],
            'enabled': true,
            'isReasoningToggle': true,
            'onValue': 'enabled',
            'offValue': 'disabled',
            'type': 'string',
          });
      final params = [
        legacyToggle(),
        ReasoningParam.fromMap({
          'paramName': 'reasoning_effort',
          'options': ['low', 'medium', 'high'],
          'enabled': true,
          'isReasoningToggle': false,
          'type': 'string',
        }),
        ReasoningParam.fromMap({
          'paramName': 'budget_tokens',
          'options': ['5000', '10000'],
          'enabled': true,
          'isReasoningToggle': false,
          'type': 'string',
        }),
      ];
      // Pre-flag semantics: the FIRST non-toggle param was the effort param.
      expect(findEffortParam(params)?.paramName, 'reasoning_effort');
    });

    test('legacy fallback skips empty-named non-toggle params', () {
      ReasoningParam legacyToggle() => ReasoningParam.fromMap({
            'paramName': 'thinking.type',
            'options': <String>[],
            'enabled': true,
            'isReasoningToggle': true,
            'onValue': 'enabled',
            'offValue': 'disabled',
            'type': 'string',
          });
      final params = [
        legacyToggle(),
        ReasoningParam.fromMap({
          'paramName': '',
          'options': ['a'],
          'isReasoningToggle': false,
          'type': 'string',
        }),
        ReasoningParam.fromMap({
          'paramName': 'reasoning_effort',
          'options': ['low', 'medium', 'high'],
          'isReasoningToggle': false,
          'type': 'string',
        }),
      ];
      expect(findEffortParam(params)?.paramName, 'reasoning_effort');
    });

    test('legacy fallback skips option-less non-toggle params', () {
      final params = [
        ReasoningParam.fromMap({
          'paramName': 'thinking.type',
          'options': <String>[],
          'enabled': true,
          'isReasoningToggle': true,
          'onValue': 'enabled',
          'offValue': 'disabled',
          'type': 'string',
        }),
        ReasoningParam.fromMap({
          'paramName': 'name_only_param',
          'options': <String>[],
          'isReasoningToggle': false,
          'type': 'string',
        }),
        ReasoningParam.fromMap({
          'paramName': 'reasoning_effort',
          'options': ['low', 'medium', 'high'],
          'isReasoningToggle': false,
          'type': 'string',
        }),
      ];
      expect(findEffortParam(params)?.paramName, 'reasoning_effort');
    });

    test('legacy data with only a toggle returns null', () {
      expect(findEffortParam([toggle()]), isNull);
    });

    test('legacy data with no non-toggle params returns null', () {
      expect(findEffortParam([]), isNull);
    });

    test(
        'code-constructed params without isEffortParam are treated as modern '
        '(no fallback)', () {
      // The UI constructs params without the flag in code; those must NOT
      // trigger the legacy fallback, otherwise a custom param would be
      // hijacked into the effort section.
      final params = [
        toggle(),
        ReasoningParam(paramName: 'budget_tokens', options: ['5000']),
      ];
      expect(findEffortParam(params), isNull);
    });

    test(
        'mixed list after migration: explicit flag wins over key-less siblings',
        () {
      // Post-migration state: the promoted param carries isEffortParam=true
      // while its legacy siblings still lack the key.
      final params = [
        ReasoningParam.fromMap({
          'paramName': 'thinking.type',
          'options': <String>[],
          'enabled': true,
          'isReasoningToggle': true,
          'onValue': 'enabled',
          'offValue': 'disabled',
          'type': 'string',
        }),
        ReasoningParam.fromMap({
          'paramName': 'reasoning_effort',
          'options': ['low', 'medium', 'high'],
          'enabled': true,
          'isReasoningToggle': false,
          'isEffortParam': true,
          'type': 'string',
        }),
        ReasoningParam.fromMap({
          'paramName': 'budget_tokens',
          'options': ['5000'],
          'enabled': true,
          'isReasoningToggle': false,
          'type': 'string',
        }),
      ];
      expect(findEffortParam(params)?.paramName, 'reasoning_effort');
    });
  });

  group('ReasoningParam.hasExplicitEffortFlag', () {
    test('fromMap without the isEffortParam key → false (legacy data)', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'reasoning_effort',
        'options': ['low', 'medium', 'high'],
        'enabled': true,
        'isReasoningToggle': false,
        'type': 'string',
      });
      expect(param.hasExplicitEffortFlag, isFalse);
    });

    test('fromMap with the isEffortParam key → true', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'reasoning_effort',
        'options': ['low', 'medium', 'high'],
        'enabled': true,
        'isReasoningToggle': false,
        'isEffortParam': false,
        'type': 'string',
      });
      expect(param.hasExplicitEffortFlag, isTrue);
    });

    test('defaultValue-era format derives the flag from the key too', () {
      final legacy = ReasoningParam.fromMap({
        'paramName': 'some_param',
        'defaultValue': 'x',
      });
      expect(legacy.hasExplicitEffortFlag, isFalse);

      final modern = ReasoningParam.fromMap({
        'paramName': 'some_param',
        'defaultValue': 'x',
        'isEffortParam': false,
      });
      expect(modern.hasExplicitEffortFlag, isTrue);
    });

    test('constructor defaults to true (modern code-constructed data)', () {
      expect(
        ReasoningParam(paramName: 'x', options: ['a']).hasExplicitEffortFlag,
        isTrue,
      );
    });

    test('copy preserves the flag', () {
      final legacy = ReasoningParam.fromMap({
        'paramName': 'reasoning_effort',
        'options': ['low'],
        'isReasoningToggle': false,
        'type': 'string',
      });
      expect(legacy.hasExplicitEffortFlag, isFalse);
      expect(legacy.copy().hasExplicitEffortFlag, isFalse);

      final modern = ReasoningParam(paramName: 'x', options: ['a']);
      expect(modern.copy().hasExplicitEffortFlag, isTrue);
    });

    test('toMap does not serialize the flag (derived from data era)', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'reasoning_effort',
        'options': ['low'],
        'isReasoningToggle': false,
        'type': 'string',
      });
      expect(param.toMap().containsKey('hasExplicitEffortFlag'), isFalse);
    });
  });

  group('ensureEffortValue', () {
    ReasoningParam effort() => ReasoningParam(
          paramName: 'reasoning_effort',
          isEffortParam: true,
          options: ['low', 'medium', 'high'],
        );

    test('writes options.first when effort is enabled but no value selected',
        () {
      final result = ensureEffortValue(
        [effort()],
        const {},
        effortEnabled: true,
      );
      expect(result, {'reasoning_effort': 'low'});
    });

    test('keeps an existing value untouched', () {
      final result = ensureEffortValue(
        [effort()],
        const {'reasoning_effort': 'high'},
        effortEnabled: true,
      );
      expect(result, {'reasoning_effort': 'high'});
    });

    test('no-op when toggle is off and the map holds no effort value', () {
      final clean = const <String, String>{};
      expect(ensureEffortValue([effort()], clean, effortEnabled: false),
          same(clean));
    });

    test('removes leftover effort value when toggle is off', () {
      final result = ensureEffortValue(
        [effort()],
        const {'reasoning_effort': 'high'},
        effortEnabled: false,
      );
      expect(result, isEmpty);
    });

    test('heals an empty-string effort value when toggle is on', () {
      final result = ensureEffortValue(
        [effort()],
        const {'reasoning_effort': ''},
        effortEnabled: true,
      );
      expect(result, {'reasoning_effort': 'low'});
    });

    test(
        'writes the default value for a config-disabled effort param '
        '(runtime state is the value map)', () {
      // 配置里的 enabled 只是新建参数的默认状态；运行时开关以已选值为准，
      // 开启即写入默认选项。
      final disabled = ReasoningParam(
        paramName: 'reasoning_effort',
        isEffortParam: true,
        enabled: false,
        options: ['low', 'medium', 'high'],
      );
      final values = const <String, String>{};
      expect(ensureEffortValue([disabled], values, effortEnabled: true),
          {'reasoning_effort': 'low'});
    });

    test('no-op when no effort param exists', () {
      final values = const <String, String>{};
      expect(ensureEffortValue([], values, effortEnabled: true), same(values));
    });

    test('no-op when effort param has no options', () {
      final values = const <String, String>{};
      expect(
        ensureEffortValue(
          [ReasoningParam(paramName: 'reasoning_effort', isEffortParam: true)],
          values,
          effortEnabled: true,
        ),
        same(values),
      );
    });

    test(
        'prunes a stale value when effort param lost its options '
        '(unusable — panel switch is disabled)', () {
      // 模型删除全部选项后，残留的已选值必须清除：否则请求仍会发送
      // 该值，而面板开关已显示灰色不可用。
      final result = ensureEffortValue(
        [ReasoningParam(paramName: 'reasoning_effort', isEffortParam: true)],
        const {'reasoning_effort': 'high'},
        effortEnabled: true,
      );
      expect(result, isEmpty);
    });

    test('keeps boolean effort value when options are empty (switch is the '
        'value)', () {
      // 布尔类型无选项值但开关即值：已选值（'true'/'false'）不得被清除。
      final boolEffort = ReasoningParam(
        paramName: 'thinking.enabled',
        isEffortParam: true,
        type: 'boolean',
      );
      final result = ensureEffortValue(
        [boolEffort],
        const {'thinking.enabled': 'true'},
        effortEnabled: true,
      );
      expect(result, {'thinking.enabled': 'true'});
    });
  });
}
