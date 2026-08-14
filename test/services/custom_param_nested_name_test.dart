import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/assistant.dart' show CustomParameter;
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/services/chat_service.dart';

/// Mock provider that captures extraParams for inspection.
class _NestedCaptureProvider extends BaseChatProvider {
  Map<String, dynamic>? capturedExtraParams;

  @override
  String get name => 'NestedCapture';

  @override
  List<String> get supportedModelIds => [];

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'test',
        'max_tokens': 4096,
        'temperature': 0.7,
      };

  @override
  Future<String> chat(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
    String? system,
  }) async {
    throw UnimplementedError();
  }

  @override
  Stream<AIStreamEvent> chatStream(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
    String? system,
  }) async* {
    capturedExtraParams = extraParams;
    yield AIStreamEvent('');
  }
}

void main() {
  group('Custom params with dotted names are sent as nested JSON', () {
    test('model-level dotted custom param expands to nested object', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'provider.only',
            defaultValue: 'true',
            type: 'boolean',
          ),
          CustomParam(
            paramName: 'style',
            defaultValue: 'cheerful',
            type: 'string',
          ),
        ],
      );

      final provider = _NestedCaptureProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extra = provider.capturedExtraParams;
      expect(extra, isNotNull);
      // `provider.only` must NOT be a flat key `provider.only`.
      expect(extra!.containsKey('provider.only'), isFalse);
      expect(extra['provider'], isA<Map>());
      expect((extra['provider'] as Map)['only'], isTrue);
      // Flat names keep their flat shape.
      expect(extra['style'], equals('cheerful'));
    });

    test('provider-level dotted custom param expands to nested object',
        () async {
      final providerConfig = ProviderConfigItem(
        providerName: 'p',
        host: 'http://localhost',
        key: 'k',
        customParams: [
          CustomParam(
            paramName: 'thinking.budget',
            defaultValue: 'high',
            type: 'string',
          ),
        ],
      );
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
      );

      final provider = _NestedCaptureProvider();
      final service = ChatService(
        provider: provider,
        modelConfig: modelConfig,
        providerConfig: providerConfig,
      );

      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extra = provider.capturedExtraParams;
      expect(extra, isNotNull);
      expect(extra!.containsKey('thinking.budget'), isFalse);
      expect(extra['thinking'], isA<Map>());
      expect((extra['thinking'] as Map)['budget'], equals('high'));
    });

    test('assistant-level dotted custom param expands to nested object',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
      );

      final provider = _NestedCaptureProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantCustomParams([
        CustomParameter(name: 'response.preset', type: 'string', value: 'x'),
      ]);

      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extra = provider.capturedExtraParams;
      expect(extra, isNotNull);
      expect(extra!.containsKey('response.preset'), isFalse);
      expect(extra['response'], isA<Map>());
      expect((extra['response'] as Map)['preset'], equals('x'));
    });

    test('nested and flat params sharing a prefix do not crash', () async {
      // `provider` (flat) + `provider.only` (nested): the nested path must
      // win (the scalar is replaced by a map) instead of throwing a cast
      // error inside setNestedParam.
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'provider',
            defaultValue: 'flat-value',
            type: 'string',
          ),
          CustomParam(
            paramName: 'provider.only',
            defaultValue: 'true',
            type: 'boolean',
          ),
        ],
      );

      final provider = _NestedCaptureProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extra = provider.capturedExtraParams;
      expect(extra, isNotNull);
      expect(extra!['provider'], isA<Map>());
      expect((extra['provider'] as Map)['only'], isTrue);
    });

    test('flat param after a nested one does not clobber the nested map',
        () async {
      // Nested path is listed FIRST, flat param second: the nested structure
      // must survive (nested wins in BOTH insertion orders).
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'provider.only',
            defaultValue: 'true',
            type: 'boolean',
          ),
          CustomParam(
            paramName: 'provider',
            defaultValue: 'flat-value',
            type: 'string',
          ),
        ],
      );

      final provider = _NestedCaptureProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extra = provider.capturedExtraParams;
      expect(extra, isNotNull);
      expect(extra!['provider'], isA<Map>());
      expect((extra['provider'] as Map)['only'], isTrue);
      expect((extra['provider'] as Map).length, equals(1));
    });

    test(
        'invalid JSON in a dotted param is omitted without breaking the '
        'request', () async {
      // The sentinel produced by failed JSON coercion must be stripped at
      // ANY depth (previously only top-level sentinels were removed, so the
      // nested map survived and crashed jsonEncode with
      // JsonUnsupportedObjectError).
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'provider.only',
            defaultValue: '{invalid json}',
            type: 'json',
          ),
          CustomParam(
            paramName: 'style',
            defaultValue: 'cheerful',
            type: 'string',
          ),
        ],
      );

      final provider = _NestedCaptureProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extra = provider.capturedExtraParams;
      expect(extra, isNotNull);
      // The whole nested branch is dropped; the healthy flat param stays.
      expect(extra!.containsKey('provider'), isFalse);
      expect(extra['style'], equals('cheerful'));
    });
  });

  group('_stripOmitted recursive sentinel stripping', () {
    test('keeps legit empty maps and deep structures, drops sentinel branches',
        () {
      final params = <String, dynamic>{
        'empty': <String, dynamic>{}, // 合法 JSON 值 {} 必须保留
        'deep': {
          'a': {'b': 1}
        }, // 合法嵌套值不受影响
        'provider': {
          'only': ChatService.omittedSentinelInstanceForTest,
        },
        'mixed': {
          'a': 1,
          'only': ChatService.omittedSentinelInstanceForTest,
        },
      };
      final stripped = ChatService.stripOmittedForTest(params);
      expect(stripped.containsKey('empty'), isTrue);
      expect(stripped['empty'], isEmpty);
      expect(
          stripped['deep'],
          equals({
            'a': {'b': 1}
          }));
      expect(stripped.containsKey('provider'), isFalse,
          reason: 'nested branch whose only value was omitted must drop');
      expect(stripped['mixed'], equals({'a': 1}),
          reason: 'nested branch with surviving values keeps them');
    });
  });
}
