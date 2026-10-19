import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/ai_stream_event.dart';
import '../models/llm_account.dart';
import '../services/llm_chat_runtime.dart';
import '../services/llm_connector_http_client.dart';
import '../services/llm_connector_service.dart';
import '../services/llm_routing_service.dart';
import 'anthropic_chat_provider.dart';
import 'chat_api_provider.dart';

/// ChatAdapter provider that keeps the application's existing chat protocol
/// while selecting an eligible account from the model's stable M1 group.
class LlmRoutedChatProvider extends BaseChatProvider {
  final Future<LlmChatRoutingRuntime> _runtime;
  final String groupId;
  final String localModelId;
  final String endpointType;
  Map<String, dynamic>? _lastRequestBody;
  Map<String, dynamic>? _lastResponseData;
  Map<String, String>? _lastRequestHeaders;
  String? _lastRequestUrl;
  int? _lastResponseStatusCode;
  Map<String, List<String>>? _lastResponseHeaders;
  Map<String, dynamic>? _lastUsage;

  LlmRoutedChatProvider({
    required Future<LlmChatRoutingRuntime> runtime,
    required this.groupId,
    required this.localModelId,
    required this.endpointType,
  }) : _runtime = runtime;

  @override
  String get name => 'Stroom account routing';

  @override
  List<String> get supportedModelIds => const [];

  @override
  Map<String, dynamic>? get lastRequestBody => _lastRequestBody;

  @override
  Map<String, dynamic>? get lastResponseData => _lastResponseData;

  @override
  Map<String, String>? get lastRequestHeaders => _lastRequestHeaders;

  @override
  String? get lastRequestUrl => _lastRequestUrl;

  @override
  int? get lastResponseStatusCode => _lastResponseStatusCode;

  @override
  Map<String, List<String>>? get lastResponseHeaders => _lastResponseHeaders;

  @override
  Map<String, dynamic>? get lastUsage => _lastUsage;

  @override
  Map<String, dynamic> get defaultParams => endpointType == 'anthropic'
      ? const {'model': 'claude-sonnet-4', 'max_tokens': 4096}
      : const {'model': 'gpt-4o', 'max_tokens': 4096, 'temperature': 0.7};

  @override
  Map<String, dynamic> get defaultHeaders => const {
    'Content-Type': 'application/json',
    'Accept': 'text/event-stream',
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
    final runtime = await _runtime;
    final execution = await runtime.executeForGroupId<String>(
      groupId: groupId,
      localModelId: localModelId,
      requiredCapabilities: _requiredCapabilities(messages, null),
      supportedConnectorTypes: _supportedConnectorTypes,
      request: (candidate, progress) async {
        if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
        final body = _buildBody(
          messages,
          upstreamModelId: candidate.upstreamModelId,
          maxTokens: maxTokens,
          temperature: temperature,
          system: system,
          extraParams: extraParams,
        );
        _captureRequest(candidate.account, body, stream: false);
        try {
          final response = await runtime.connectorClient.request(
            account: candidate.account,
            modelId: candidate.upstreamModelId,
            body: body,
            cancelToken: cancelToken,
            onRequestSent: progress.markRequestSent,
          );
          _lastResponseStatusCode = response.statusCode;
          final result = _readCompletion(response.body);
          _lastResponseData = result.data;
          _lastUsage = result.usage;
          await _recordUsage(
            progress,
            result.usage,
            response.observation,
            runtime: runtime,
            accountId: candidate.account.id,
          );
          return result.text;
        } on LlmConnectorHttpException catch (error) {
          throw LlmRouteRequestException(
            statusCode: error.statusCode,
            code: error.code,
            headers: error.headers,
          );
        }
      },
    );
    return execution.value;
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
  }) {
    late final StreamController<AIStreamEvent> controller;
    controller = StreamController<AIStreamEvent>(
      onCancel: () {
        if (cancelToken != null && !cancelToken.isCancelled) {
          cancelToken.cancel('Chat stream cancelled');
        }
      },
    );
    unawaited(() async {
      try {
        final runtime = await _runtime;
        await runtime.executeForGroupId<void>(
          groupId: groupId,
          localModelId: localModelId,
          requiredCapabilities: {
            ..._requiredCapabilities(messages, tools),
            'streaming',
          },
          supportedConnectorTypes: _supportedConnectorTypes,
          request: (candidate, progress) async {
            if (cancelToken?.isCancelled == true) {
              throw cancelToken!.cancelError!;
            }
            final body = _buildBody(
              messages,
              upstreamModelId: candidate.upstreamModelId,
              maxTokens: maxTokens,
              temperature: temperature,
              stream: true,
              tools: tools,
              system: system,
              extraParams: extraParams,
            );
            _captureRequest(candidate.account, body, stream: true);
            try {
              final response = await runtime.connectorClient.request(
                account: candidate.account,
                modelId: candidate.upstreamModelId,
                body: body,
                stream: true,
                cancelToken: cancelToken,
                onRequestSent: progress.markRequestSent,
              );
              _lastResponseStatusCode = response.statusCode;
              final eventStream = await _parseStream(
                response,
                progress,
                runtime: runtime,
                accountId: candidate.account.id,
              );
              await for (final event in eventStream) {
                if (controller.isClosed) return;
                if (event.usage == null) {
                  await progress.markOutputVisible();
                }
                controller.add(event);
              }
            } on LlmConnectorHttpException catch (error) {
              throw LlmRouteRequestException(
                statusCode: error.statusCode,
                code: error.code,
                headers: error.headers,
              );
            }
          },
        );
        if (!controller.isClosed) await controller.close();
      } catch (error, stack) {
        if (!controller.isClosed) {
          controller.addError(_safeError(error), stack);
          await controller.close();
        }
      }
    }());
    return controller.stream;
  }

  Set<String> get _supportedConnectorTypes => endpointType == 'anthropic'
      ? const {'claude'}
      : const {'openai-compatibility', 'kimi', 'kimi-ai', 'kimi.ai'};

  static Set<String> _requiredCapabilities(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
  ) {
    final required = <String>{};
    if (tools != null && tools.isNotEmpty) required.add('tools');
    if (_containsContentType(messages, const {
      'image',
      'image_url',
      'video_url',
      'file',
      'document',
    })) {
      required.add('vision');
    }
    if (_containsContentType(messages, const {
      'input_audio',
      'audio',
      'audio_url',
    })) {
      required.add('audio');
    }
    return required;
  }

  static bool _containsContentType(Object? value, Set<String> types) {
    if (value is Map) {
      if (types.contains(value['type'])) return true;
      return value.values.any((child) => _containsContentType(child, types));
    }
    if (value is Iterable) {
      return value.any((child) => _containsContentType(child, types));
    }
    return false;
  }

  Map<String, dynamic> _buildBody(
    List<Map<String, dynamic>> messages, {
    required String upstreamModelId,
    int? maxTokens,
    double? temperature,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
    String? system,
    Map<String, dynamic>? extraParams,
  }) {
    if (endpointType == 'anthropic') {
      final thinking = extraParams?['thinking'];
      final thinkingType = thinking is Map ? thinking['type'] : null;
      final extendedThinking =
          thinkingType is String &&
          const {
            'enabled',
            'adaptive',
            'on',
          }.contains(thinkingType.toLowerCase());
      return {
        'max_tokens': maxTokens ?? 4096,
        'messages': messages,
        if (system != null && system.isNotEmpty) 'system': system,
        if (temperature != null && !extendedThinking)
          'temperature': temperature,
        'stream': stream,
        if (tools != null && tools.isNotEmpty) 'tools': tools,
        ...?extraParams,
        // Custom parameters may contain `model`; routing remains authoritative.
        'model': upstreamModelId,
      };
    }
    return {
      'messages': messages,
      'max_tokens': ?maxTokens,
      'temperature': ?temperature,
      'stream': stream,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      ...?extraParams,
      'model': upstreamModelId,
    };
  }

  void _captureRequest(
    LlmAccount account,
    Map<String, dynamic> body, {
    required bool stream,
  }) {
    _lastRequestBody = body;
    final baseUrl =
        account.endpointConfig['baseUrl'] ??
        account.endpointConfig['host'] ??
        account.endpointConfig['apiBase'];
    _lastRequestUrl = baseUrl is String ? baseUrl : null;
    _lastRequestHeaders = {
      'Content-Type': 'application/json',
      if (stream) 'Accept': 'text/event-stream',
      if (endpointType == 'anthropic')
        'anthropic-version': kAnthropicApiVersion,
    };
    _lastResponseData = null;
    _lastResponseStatusCode = null;
    _lastResponseHeaders = null;
    _lastUsage = null;
  }

  Future<Stream<AIStreamEvent>> _parseStream(
    LlmConnectorResponse response,
    LlmRouteProgress progress, {
    required LlmChatRoutingRuntime runtime,
    required String accountId,
  }) async {
    final body = response.body;
    if (body is! Stream<List<int>>) {
      throw const LlmConnectorHttpException();
    }
    final usage = <String, dynamic>{};
    final toolsByIndex = <int, Map<String, dynamic>>{};
    final anthropicAccumulator = AnthropicStreamAccumulator();
    final parsedEvents = StreamController<AIStreamEvent>();
    unawaited(() async {
      try {
        await for (final payload in _sseData(body)) {
          final trimmedPayload = payload.trim();
          if (trimmedPayload.isEmpty) continue;
          if (trimmedPayload == '[DONE]') break;
          final decoded = jsonDecode(payload);
          if (decoded is! Map) continue;
          final data = Map<String, dynamic>.from(decoded);
          _lastResponseData = data;
          if (endpointType == 'anthropic') {
            if (data['type'] == 'error') {
              throw _streamRequestError(data['error']);
            }
            if (data['type'] == 'message_start') {
              final rawUsage = (data['message'] as Map?)?['usage'];
              if (rawUsage is Map) {
                AnthropicChatProvider.mergeAnthropicUsage(usage, rawUsage);
              }
            } else if (data['type'] == 'message_delta' &&
                data['usage'] is Map) {
              AnthropicChatProvider.mergeAnthropicUsage(
                usage,
                data['usage'] as Map,
              );
            }
            for (final event in processAnthropicStreamData(
              data,
              anthropicAccumulator,
            )) {
              parsedEvents.add(event);
            }
          } else {
            final apiError = data['error'];
            if (apiError is Map) throw _streamRequestError(apiError);
            OpenAICompatibleChatProvider.throwIfApiError(data);
            final chunkUsage = OpenAICompatibleChatProvider.normalizeUsage(
              data['usage'],
            );
            if (chunkUsage != null) usage.addAll(chunkUsage);
            for (final event in OpenAICompatibleChatProvider.parseStreamEvent(
              data,
            )) {
              parsedEvents.add(event);
            }
            _accumulateOpenAIToolCalls(data, toolsByIndex);
          }
        }
        final connectorObservation = await response.completedObservation;
        final usageObservation = connectorObservation == null
            ? response.observation
            : mergeLlmConnectorObservations(
                response.observation,
                connectorObservation,
              );
        await _recordUsage(
          progress,
          usage,
          usageObservation,
          runtime: runtime,
          accountId: accountId,
        );
        if (usage.isNotEmpty) {
          _lastUsage = Map<String, dynamic>.from(usage);
          parsedEvents.add(AIStreamEvent('', usage: _lastUsage));
        }
        if (endpointType == 'anthropic') {
          final signature = anthropicAccumulator.thinkingSignatures.length == 1
              ? anthropicAccumulator.thinkingSignatures.single
              : '';
          if (signature.isNotEmpty) {
            parsedEvents.add(AIStreamEvent('', thinkingSignature: signature));
          }
          final toolEvent = buildToolCallEvent(anthropicAccumulator);
          if (toolEvent != null) parsedEvents.add(toolEvent);
        } else {
          final toolEvent = _buildOpenAIToolCallEvent(toolsByIndex);
          if (toolEvent != null) parsedEvents.add(toolEvent);
        }
        await parsedEvents.close();
      } catch (error, stack) {
        var observation = response.observation;
        try {
          final connectorObservation = await response.completedObservation;
          if (connectorObservation != null) {
            observation = mergeLlmConnectorObservations(
              observation,
              connectorObservation,
            );
          }
        } catch (_) {
          // Keep the response-header observation if stream telemetry failed.
        }
        try {
          await _recordUsage(
            progress,
            usage,
            observation,
            runtime: runtime,
            accountId: accountId,
          );
          if (usage.isNotEmpty) {
            parsedEvents.add(AIStreamEvent('', usage: usage));
          }
        } catch (_) {
          // Telemetry failures must not replace the original stream failure.
        }
        if (!parsedEvents.isClosed) {
          parsedEvents.addError(_safeError(error), stack);
        }
        await parsedEvents.close();
      }
    }());
    return parsedEvents.stream;
  }

  _LlmCompletionResult _readCompletion(Object? raw) {
    final data = _jsonMap(raw);
    if (data == null) throw const LlmConnectorHttpException();
    final apiError = data['error'];
    if (apiError is Map) throw _streamRequestError(apiError);
    if (endpointType == 'anthropic') {
      final blocks = data['content'];
      final text = blocks is List
          ? blocks
                .whereType<Map>()
                .where((block) => block['type'] == 'text')
                .map((block) => block['text'])
                .whereType<String>()
                .join()
          : '';
      if (text.trim().isEmpty) throw const LlmConnectorHttpException();
      final usage = <String, dynamic>{};
      final rawUsage = data['usage'];
      if (rawUsage is Map) {
        AnthropicChatProvider.mergeAnthropicUsage(usage, rawUsage);
      }
      return _LlmCompletionResult(data: data, text: text, usage: usage);
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const LlmConnectorHttpException();
    }
    final first = choices.first;
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String) throw const LlmConnectorHttpException();
    return _LlmCompletionResult(
      data: data,
      text: content,
      usage: OpenAICompatibleChatProvider.normalizeUsage(data['usage']) ?? {},
    );
  }

  Future<void> _recordUsage(
    LlmRouteProgress progress,
    Map<String, dynamic> usage,
    LlmConnectorObservation observation, {
    required LlmChatRoutingRuntime runtime,
    required String accountId,
  }) async {
    final requestUsage = observation.requestUsage;
    await _recordMetric(progress, requestUsage);
    final observedUnit = requestUsage.isKnown && requestUsage.value != null
        ? requestUsage.unit
        : null;
    final input = _number(usage['inputTokens']);
    final output = _number(usage['outputTokens']);
    final tokens = (input ?? 0) + (output ?? 0);
    if ((input != null || output != null) && observedUnit != 'tokens') {
      await progress.recordUsage(
        unit: 'tokens',
        value: tokens,
        source: 'provider',
      );
    }
    final cost = _number(usage['cost']);
    if (cost != null && observedUnit != 'usd') {
      await progress.recordUsage(unit: 'usd', value: cost, source: 'provider');
    }
    if (observation.remainingQuota.isKnown ||
        observation.quotaSignals.values.any((metric) => metric.isKnown)) {
      try {
        await runtime.accountService.recordQuotaObservation(
          accountId: accountId,
          remainingQuota: observation.remainingQuota,
          quotaSignals: observation.quotaSignals,
        );
      } catch (_) {
        // Connector quota is observational and cannot fail a completed chat.
      }
    }
  }

  Future<void> _recordMetric(
    LlmRouteProgress progress,
    LlmMetricObservation metric,
  ) async {
    final unit = metric.unit;
    final value = metric.value;
    if (unit == null || value == null || unit == 'requests') return;
    await progress.recordUsage(unit: unit, value: value, source: 'provider');
  }

  static double? _number(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value.toDouble() : null;

  static Map<String, dynamic>? _jsonMap(Object? value) {
    Object? decoded = value;
    if (value is List<int>) {
      try {
        decoded = jsonDecode(utf8.decode(value));
      } catch (_) {
        return null;
      }
    } else if (value is String) {
      try {
        decoded = jsonDecode(value);
      } catch (_) {
        return null;
      }
    }
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  static Stream<String> _sseData(Stream<List<int>> bytes) async* {
    final dataLines = <String>[];
    await for (final line
        in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          yield dataLines.join('\n');
          dataLines.clear();
        }
      } else if (line.startsWith('data:')) {
        var data = line.substring(5);
        if (data.startsWith(' ')) data = data.substring(1);
        dataLines.add(data);
      }
    }
    if (dataLines.isNotEmpty) yield dataLines.join('\n');
  }

  static void _accumulateOpenAIToolCalls(
    Map<String, dynamic> data,
    Map<int, Map<String, dynamic>> accumulators,
  ) {
    final choices = data['choices'];
    final choice = choices is List && choices.isNotEmpty ? choices.first : null;
    final delta = choice is Map ? choice['delta'] : null;
    final calls = delta is Map ? delta['tool_calls'] : null;
    if (calls is! List) return;
    for (final call in calls.whereType<Map>()) {
      final index = call['index'] is int ? call['index'] as int : 0;
      final entry = accumulators.putIfAbsent(index, () => {});
      if (call['id'] is String) entry['id'] = call['id'];
      if (call['type'] is String) entry['type'] = call['type'];
      final function = call['function'];
      if (function is! Map) continue;
      final target =
          entry.putIfAbsent('function', () => <String, dynamic>{})
              as Map<String, dynamic>;
      if (function['name'] is String) target['name'] = function['name'];
      if (function['arguments'] is String) {
        target['arguments'] =
            '${target['arguments'] ?? ''}${function['arguments']}';
      }
    }
  }

  static AIStreamEvent? _buildOpenAIToolCallEvent(
    Map<int, Map<String, dynamic>> accumulators,
  ) {
    if (accumulators.isEmpty) return null;
    final calls = accumulators.entries
        .map(
          (entry) => {
            'id': entry.value['id'] ?? 'call_${entry.key}',
            'type': entry.value['type'] ?? 'function',
            'function': entry.value['function'] ?? <String, dynamic>{},
          },
        )
        .toList(growable: false);
    return AIStreamEvent('', toolCalls: calls);
  }

  static Object _safeError(Object error) {
    if (error is LlmRoutingUnavailableException ||
        error is LlmRouteRequestException ||
        error is LlmConnectorRequestCancelled) {
      return error;
    }
    if (error is LlmConnectorHttpException) {
      return LlmRouteRequestException(
        statusCode: error.statusCode,
        code: error.code,
        headers: error.headers,
      );
    }
    return const LlmRouteRequestException();
  }

  static LlmRouteRequestException _streamRequestError(Object? apiError) {
    final rawCode = apiError is Map
        ? apiError['code'] ?? apiError['type']
        : null;
    return LlmRouteRequestException(code: rawCode is String ? rawCode : null);
  }
}

class _LlmCompletionResult {
  final Map<String, dynamic> data;
  final String text;
  final Map<String, dynamic> usage;

  const _LlmCompletionResult({
    required this.data,
    required this.text,
    required this.usage,
  });
}
