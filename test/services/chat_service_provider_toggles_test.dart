// 供应商级 LLM 开关（温度 / maxTokens）请求注入测试：
// 供应商面板保存的 temperature / maxTokens 此前从未发送（死配置），
// 现在按「助手 > 模型 > 供应商」的层级兜底注入请求。
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

/// Mock provider that captures the request body for inspection.
class _CapturingProvider extends BaseChatProvider {
  @override
  Map<String, dynamic>? lastRequestBody;

  /// 原始参数（不经 defaultParams 兜底，验证「未启用 = 不传」）。
  double? lastTemperature;
  int? lastMaxTokens;

  @override
  String get name => 'Mock';

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
    lastTemperature = temperature;
    lastMaxTokens = maxTokens;
    lastRequestBody = {
      'model': model ?? defaultParams['model'],
      'messages': messages,
      'max_tokens': maxTokens ?? defaultParams['max_tokens'],
      'temperature': temperature ?? defaultParams['temperature'],
      'stream': true,
      if (extraParams != null) ...extraParams,
    };
    yield AIStreamEvent('');
  }
}

void main() {
  late _CapturingProvider provider;

  setUp(() {
    provider = _CapturingProvider();
  });

  ModelConfig plainModel() => ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
      );

  Future<Map<String, dynamic>?> sendWith({
    ModelConfig? model,
    ProviderConfigItem? providerConfig,
    AssistantSettings? assistantSettings,
  }) async {
    final service = ChatService(
      provider: provider,
      modelConfig: model ?? plainModel(),
      providerConfig: providerConfig,
    );
    if (assistantSettings != null) {
      service.setAssistantSettings(assistantSettings);
    }
    await for (final _ in service.sendStream('Hi', history: [])) {}
    return provider.lastRequestBody;
  }

  ProviderConfigItem providerWithToggles({
    bool enableTemperature = false,
    double? temperature,
    bool enableMaxTokens = false,
    int? maxTokens,
  }) {
    return ProviderConfigItem(
      providerName: 'Test Provider',
      host: 'https://api.example.com/v1',
      key: 'sk-test',
      typeConfig: {
        if (enableTemperature) 'temperature': temperature,
        'enableTemperature': enableTemperature,
        if (enableMaxTokens) 'maxTokens': maxTokens,
        'enableMaxTokens': enableMaxTokens,
      },
    );
  }

  group('provider-level temperature', () {
    test('enabled provider temperature is sent when model has none', () async {
      final body = await sendWith(
        providerConfig: providerWithToggles(
          enableTemperature: true,
          temperature: 0.3,
        ),
      );
      expect(body!['temperature'], 0.3);
    });

    test('disabled provider temperature is not sent', () async {
      await sendWith(providerConfig: providerWithToggles());
      expect(provider.lastTemperature, isNull,
          reason: '未启用时不得回退到 provider 默认值');
    });

    test('model temperature wins over provider temperature', () async {
      final model = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {
          'context': 4096,
          'enableTemperature': true,
          'temperature': 1.1,
        },
      );
      final body = await sendWith(
        model: model,
        providerConfig: providerWithToggles(
          enableTemperature: true,
          temperature: 0.3,
        ),
      );
      expect(body!['temperature'], 1.1);
    });

    test('assistant temperature wins over model and provider', () async {
      final model = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {
          'context': 4096,
          'enableTemperature': true,
          'temperature': 1.1,
        },
      );
      final body = await sendWith(
        model: model,
        providerConfig: providerWithToggles(
          enableTemperature: true,
          temperature: 0.3,
        ),
        assistantSettings: AssistantSettings(
          enableTemperature: true,
          temperature: 1.5,
        ),
      );
      expect(body!['temperature'], 1.5);
    });
  });

  group('provider-level maxTokens', () {
    test('enabled provider maxTokens is sent when model has none', () async {
      final body = await sendWith(
        providerConfig: providerWithToggles(
          enableMaxTokens: true,
          maxTokens: 2048,
        ),
      );
      expect(body!['max_tokens'], 2048);
    });

    test('disabled provider maxTokens is not sent', () async {
      await sendWith(providerConfig: providerWithToggles());
      expect(provider.lastMaxTokens, isNull,
          reason: '未启用时不得回退到 provider 默认值');
    });

    test('model maxTokens wins over provider maxTokens', () async {
      final model = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {
          'context': 4096,
          'enableMaxTokens': true,
          'maxTokens': 8192,
        },
      );
      final body = await sendWith(
        model: model,
        providerConfig: providerWithToggles(
          enableMaxTokens: true,
          maxTokens: 2048,
        ),
      );
      expect(body!['max_tokens'], 8192);
    });

    test('assistant maxTokens wins over model and provider', () async {
      final model = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {
          'context': 4096,
          'enableMaxTokens': true,
          'maxTokens': 8192,
        },
      );
      final body = await sendWith(
        model: model,
        providerConfig: providerWithToggles(
          enableMaxTokens: true,
          maxTokens: 2048,
        ),
        assistantSettings: AssistantSettings(
          enableMaxTokens: true,
          maxTokens: 16384,
        ),
      );
      expect(body!['max_tokens'], 16384);
    });
  });
}
