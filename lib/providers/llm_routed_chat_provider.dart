import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/ai_stream_event.dart';
import '../ai_gateway/ai_gateway.dart';
import 'anthropic_chat_provider.dart';
import 'chat_api_provider.dart';

/// ChatAdapter provider that keeps the application's existing chat protocol
/// while selecting an eligible account from the model's stable M1 group.
class LlmRoutedChatProvider extends BaseChatProvider {
  final Future<AiGatewayFacade> _runtime;
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
    required Future<AiGatewayFacade> runtime,
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
      requiredCapabilities: _requiredCapabilities(
        messages,
        null,
        extraParams: extraParams,
      ),
      supportedConnectorTypes: _supportedConnectorTypes,
      request: (candidate, progress) async {
        if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
        final protocolId = _protocolFor(candidate.account);
        final body = _buildBody(
          messages,
          protocolId: protocolId,
          upstreamModelId: candidate.upstreamModelId,
          maxTokens: maxTokens,
          temperature: temperature,
          system: system,
          extraParams: extraParams,
        );
        _captureRequest(candidate.account, body, stream: false);
        try {
          final response = await runtime.executor.request(
            account: candidate.account,
            modelId: candidate.upstreamModelId,
            body: body,
            nativeFormat: _nativeFormatFor(protocolId),
            cancelToken: cancelToken,
            onRequestSent: progress.markRequestSent,
          );
          _lastResponseStatusCode = response.statusCode;
          _lastResponseHeaders = response.headers;
          final result = _readCompletion(response.body, protocolId);
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
        } on AiGatewayExecutionException catch (error) {
          if (error.kind != AiGatewayFailureKind.request) rethrow;
          _captureResponseFailure(error);
          rethrow;
        }
      },
    );
    return execution.value;
  }

  /// Counts Anthropic Messages input tokens through the connected account.
  /// This uses the provider's distinct count_tokens contract and path; it does
  /// not route through the generation endpoint.
  Future<int> countTokens(
    List<Map<String, dynamic>> messages, {
    String? system,
    List<Map<String, dynamic>>? tools,
    CancelToken? cancelToken,
  }) async {
    if (endpointType != 'anthropic') {
      throw UnsupportedError(
        'Token counting is only available for Anthropic Messages accounts.',
      );
    }
    final runtime = await _runtime;
    final execution = await runtime.executeForGroupId<int>(
      groupId: groupId,
      localModelId: localModelId,
      supportedConnectorTypes: const {'claude'},
      request: (candidate, progress) async {
        if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
        final body = _buildBody(
          messages,
          protocolId: 'anthropic.messages',
          operation: 'count_tokens',
          upstreamModelId: candidate.upstreamModelId,
          tools: tools,
          system: system,
        );
        final response = await runtime.executor.request(
          account: candidate.account,
          modelId: candidate.upstreamModelId,
          body: body,
          nativeFormat: 'count_tokens',
          cancelToken: cancelToken,
          onRequestSent: progress.markRequestSent,
        );
        final data = _jsonMap(response.body);
        final count = data?['input_tokens'];
        if (count is! num || count < 0) {
          throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
        }
        return count.toInt();
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
    final requestCancelToken = cancelToken ?? CancelToken();
    late final StreamController<AIStreamEvent> controller;
    controller = StreamController<AIStreamEvent>(
      onCancel: () {
        if (!requestCancelToken.isCancelled) {
          requestCancelToken.cancel('Chat stream cancelled');
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
            ..._requiredCapabilities(messages, tools, extraParams: extraParams),
            'streaming',
          },
          supportedConnectorTypes: _supportedConnectorTypes,
          request: (candidate, progress) async {
            if (requestCancelToken.isCancelled) {
              throw requestCancelToken.cancelError!;
            }
            final protocolId = _protocolFor(candidate.account);
            final body = _buildBody(
              messages,
              protocolId: protocolId,
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
              final response = await runtime.executor.request(
                account: candidate.account,
                modelId: candidate.upstreamModelId,
                body: body,
                stream: true,
                nativeFormat: _nativeFormatFor(protocolId),
                cancelToken: requestCancelToken,
                onRequestSent: progress.markRequestSent,
              );
              _lastResponseStatusCode = response.statusCode;
              _lastResponseHeaders = response.headers;
              final eventStream = await _parseStream(
                response,
                progress,
                runtime: runtime,
                accountId: candidate.account.id,
                protocolId: protocolId,
              );
              await for (final event in eventStream) {
                if (controller.isClosed) return;
                if (event.usage == null) {
                  await progress.markOutputVisible();
                }
                controller.add(event);
              }
            } on AiGatewayExecutionException catch (error) {
              if (error.kind != AiGatewayFailureKind.request) rethrow;
              _captureResponseFailure(error);
              rethrow;
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

  Set<String> get _supportedConnectorTypes => switch (endpointType) {
        'anthropic' => const {'claude'},
        'google.gemini.generate_content' => const {'gemini'},
        'google.gemini.interactions' => const {'gemini-interactions'},
        'ollama.chat' => const {'ollama'},
        _ => const {
            'openai-compatibility',
            'openai-api',
            'bedrock',
            'kimi',
            'kimi-ai',
            'kimi.ai',
            'moonshot',
            'glm',
            'deepseek',
            'minimax',
            'qwen',
          },
      };

  String _protocolFor(AiGatewayAccount account) {
    if (endpointType == 'anthropic' ||
        endpointType == 'google.gemini.generate_content' ||
        endpointType == 'google.gemini.interactions' ||
        endpointType == 'ollama.chat') {
      return endpointType == 'anthropic' ? 'anthropic.messages' : endpointType;
    }
    final configuredProtocol = account.endpointConfig['chatProtocol'];
    if (configuredProtocol == 'openai.responses') {
      if (const {
        'openai-api',
        'kimi',
        'kimi-ai',
        'kimi.ai',
      }.contains(account.connectorType)) {
        return 'openai.responses';
      }
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.request,
        code: 'unsupported_protocol',
      );
    }
    return 'openai.chat_completions';
  }

  String? _nativeFormatFor(String protocolId) =>
      protocolId == 'openai.responses' ? 'responses' : null;

  static Set<String> _requiredCapabilities(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools, {
    Map<String, dynamic>? extraParams,
  }) {
    final required = <String>{};
    if (_effectiveTools(tools, extraParams).isNotEmpty) required.add('tools');
    if (_containsContentType(messages, const {
      'image',
      'image_url',
      'input_image',
      'output_image',
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

  static List<Map<String, dynamic>> _effectiveTools(
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
  ) {
    final configured = extraParams?['tools'];
    if (configured is List) {
      return configured
          .whereType<Map>()
          .map((tool) => Map<String, dynamic>.from(tool))
          .toList(growable: false);
    }
    return tools ?? const <Map<String, dynamic>>[];
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
    required String protocolId,
    String operation = 'generate',
    required String upstreamModelId,
    int? maxTokens,
    double? temperature,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
    String? system,
    Map<String, dynamic>? extraParams,
  }) {
    final bridge = AiGatewayProtocolBridges.forProtocol(protocolId);
    if (bridge == null) {
      throw StateError('No internal protocol bridge for $protocolId.');
    }
    final requestTools = _effectiveTools(tools, extraParams);
    final previousInteractionValue = extraParams?['previous_interaction_id'];
    final previousInteractionId = protocolId == 'google.gemini.interactions' &&
            previousInteractionValue is String
        ? previousInteractionValue
        : null;
    final requestOptions = Map<String, dynamic>.from(extraParams ?? const {});
    if (previousInteractionId != null) {
      requestOptions.remove('previous_interaction_id');
    }
    final extraTokenLimit =
        extraParams?['max_tokens'] ?? extraParams?['max_output_tokens'];
    final requestedMaxTokens =
        maxTokens ?? (extraTokenLimit is num ? extraTokenLimit.toInt() : null);
    final requestedSystem = extraParams?['system'] is String
        ? extraParams!['system'] as String
        : system;
    final thinking = extraParams?['thinking'];
    final thinkingType = thinking is Map ? thinking['type'] : null;
    final extendedThinking = thinkingType is String &&
        const {
          'enabled',
          'adaptive',
          'on',
        }.contains(thinkingType.toLowerCase());
    if (protocolId == 'anthropic.messages' && extendedThinking) {
      requestOptions.remove('temperature');
    }
    final request = AiGatewayProtocolBridges.buildRequest(
      protocolId,
      AiGatewayProtocolRequest(
        modelId: upstreamModelId,
        operation: operation,
        messages: messages
            .map(AiGatewayProtocolBridges.openAiChatCompletions.toStroom)
            .toList(growable: false),
        system: requestedSystem,
        tools: requestTools,
        stream: stream,
        maxOutputTokens: requestedMaxTokens,
        previousInteractionId: previousInteractionId,
        temperature: protocolId == 'anthropic.messages' && extendedThinking
            ? null
            : temperature,
        options: requestOptions,
      ),
    );
    if (request == null) {
      throw StateError('No internal request builder for $protocolId.');
    }
    return request.body;
  }

  void _captureRequest(
    AiGatewayAccount account,
    Map<String, dynamic> body, {
    required bool stream,
  }) {
    _lastRequestBody = body;
    final baseUrl = account.endpointConfig['baseUrl'] ??
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

  void _captureResponseFailure(AiGatewayExecutionException error) {
    _lastResponseStatusCode = error.statusCode;
    _lastResponseHeaders = {
      for (final entry in error.headers.entries) entry.key: [entry.value],
    };
  }

  Future<Stream<AIStreamEvent>> _parseStream(
    AiGatewayResponse response,
    AiGatewayRouteProgress progress, {
    required AiGatewayFacade runtime,
    required String accountId,
    required String protocolId,
  }) async {
    final body = response.body;
    if (body is! Stream<List<int>>) {
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
    }
    final usage = <String, dynamic>{};
    final toolsByIndex = <int, Map<String, dynamic>>{};
    final anthropicAccumulator = AnthropicStreamAccumulator();
    final protocolStreamState = AiGatewayProtocolStreamState();
    final parsedEvents = StreamController<AIStreamEvent>();
    unawaited(() async {
      try {
        final payloads =
            protocolId == 'ollama.chat' ? _ndjsonData(body) : _sseData(body);
        await for (final payload in payloads) {
          final trimmedPayload = payload.trim();
          if (trimmedPayload.isEmpty) continue;
          if (trimmedPayload == '[DONE]') break;
          try {
            final decoded = jsonDecode(payload);
            if (decoded is! Map) continue;
            final data = Map<String, dynamic>.from(decoded);
            _lastResponseData = data;
            if (protocolId == 'anthropic.messages') {
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
            } else if (protocolId == 'openai.chat_completions') {
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
            } else {
              if (data['error'] is Map) {
                throw _streamRequestError(data['error']);
              }
              for (final event in AiGatewayProtocolStreamBridge.mapEvents(
                protocolId,
                data,
                state: protocolStreamState,
              )) {
                switch (event.kind) {
                  case AiGatewayProtocolStreamEventKind.textDelta:
                    parsedEvents.add(AIStreamEvent(event.delta ?? ''));
                  case AiGatewayProtocolStreamEventKind.reasoningDelta:
                    parsedEvents.add(
                      AIStreamEvent(event.delta ?? '', isReasoning: true),
                    );
                  case AiGatewayProtocolStreamEventKind.toolCallDelta:
                    _accumulateProtocolToolCall(event, toolsByIndex);
                  case AiGatewayProtocolStreamEventKind.usage:
                    final normalized = _normalizeProtocolUsage(
                      event.usage ?? const {},
                      protocolId,
                    );
                    usage.addAll(normalized);
                  case AiGatewayProtocolStreamEventKind.lifecycle:
                  case AiGatewayProtocolStreamEventKind.providerEvent:
                    break;
                  case AiGatewayProtocolStreamEventKind.error:
                    final failedResponse = _jsonMap(event.raw['response']);
                    throw _streamRequestError(
                      data['error'] ?? failedResponse?['error'],
                    );
                }
              }
            }
          } catch (error) {
            if (protocolId != 'anthropic.messages' &&
                (error is FormatException || error is TypeError)) {
              continue;
            }
            rethrow;
          }
        }
        final connectorObservation = await response.completedObservation;
        final usageObservation = connectorObservation == null
            ? response.observation
            : _mergeGatewayObservations(
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
        if (protocolId == 'anthropic.messages') {
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
            observation = _mergeGatewayObservations(
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

  _LlmCompletionResult _readCompletion(Object? raw, String protocolId) {
    final data = _jsonMap(raw);
    if (data == null) {
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
    }
    final apiError = data['error'];
    if (apiError is Map) throw _streamRequestError(apiError);
    if (protocolId == 'anthropic.messages') {
      final blocks = data['content'];
      if (blocks is! List || blocks.isEmpty) {
        throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
      }
      final text = blocks
          .whereType<Map>()
          .where((block) => block['type'] == 'text')
          .map((block) => block['text'])
          .whereType<String>()
          .join();
      final hasToolUse = blocks.whereType<Map>().any(
            (block) => block['type'] == 'tool_use',
          );
      if (text.trim().isEmpty && !hasToolUse) {
        throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
      }
      final usage = <String, dynamic>{};
      final rawUsage = data['usage'];
      if (rawUsage is Map) {
        AnthropicChatProvider.mergeAnthropicUsage(usage, rawUsage);
      }
      return _LlmCompletionResult(data: data, text: text, usage: usage);
    }
    final text = switch (protocolId) {
      'openai.responses' => _responsesText(data['output']),
      'google.gemini.generate_content' => _geminiText(data['candidates']),
      'google.gemini.interactions' => _interactionsText(data['outputs']),
      'ollama.chat' => (data['message'] as Map?)?['content'] as String?,
      _ => _openAiChatText(data['choices']),
    };
    if (text == null) {
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
    }
    return _LlmCompletionResult(
      data: data,
      text: text,
      usage: _normalizeProtocolUsage(
        _rawProtocolUsage(data, protocolId),
        protocolId,
      ),
    );
  }

  static String? _openAiChatText(Object? rawChoices) {
    if (rawChoices is! List || rawChoices.isEmpty) return null;
    final first = rawChoices.first;
    final message = first is Map ? first['message'] : null;
    return message is Map && message['content'] is String
        ? message['content'] as String
        : '';
  }

  static String? _responsesText(Object? rawOutput) {
    if (rawOutput is! List) return null;
    return rawOutput.whereType<Map>().expand((item) {
      final content = item['content'];
      if (content is List) {
        return content.whereType<Map>().expand((part) {
          if (part['type'] == 'output_text') {
            final text = part['text'];
            return text is String ? [text] : const <String>[];
          }
          if (part['type'] == 'refusal') {
            final refusal = part['refusal'] ?? part['text'];
            return refusal is String ? [refusal] : const <String>[];
          }
          return const <String>[];
        });
      }
      return const <String>[];
    }).join();
  }

  static String? _geminiText(Object? rawCandidates) {
    if (rawCandidates is! List) return null;
    return rawCandidates.whereType<Map>().expand((candidate) {
      final content = candidate['content'];
      final parts = content is Map ? content['parts'] : null;
      return parts is List
          ? parts
              .whereType<Map>()
              .where((part) => part['thought'] != true)
              .map((part) => part['text'])
              .whereType<String>()
          : const <String>[];
    }).join();
  }

  static String? _interactionsText(Object? rawOutputs) {
    if (rawOutputs is! List) return null;
    return rawOutputs.whereType<Map>().expand((output) {
      if (output['type'] == 'text') {
        final text = output['text'];
        return text is String ? [text] : const <String>[];
      }
      if (output['type'] != 'model_output') return const <String>[];
      final content = output['content'];
      if (content is! List) return const <String>[];
      return content
          .whereType<Map>()
          .where((part) => const {'text', 'output_text'}.contains(part['type']))
          .map((part) => part['text'])
          .whereType<String>();
    }).join();
  }

  static Map<String, dynamic> _rawProtocolUsage(
    Map<String, dynamic> data,
    String protocolId,
  ) =>
      switch (protocolId) {
        'google.gemini.generate_content' =>
          _jsonMap(data['usageMetadata']) ?? const {},
        'google.gemini.interactions' => _jsonMap(data['usage']) ?? const {},
        'ollama.chat' => {
            if (data['prompt_eval_count'] is num)
              'prompt_eval_count': data['prompt_eval_count'],
            if (data['eval_count'] is num) 'eval_count': data['eval_count'],
          },
        'openai.responses' => _jsonMap(data['usage']) ?? const {},
        _ => _jsonMap(data['usage']) ?? const {},
      };

  static Map<String, dynamic> _normalizeProtocolUsage(
    Map<String, dynamic> raw,
    String protocolId,
  ) {
    if (protocolId == 'anthropic.messages') {
      final normalized = <String, dynamic>{};
      AnthropicChatProvider.mergeAnthropicUsage(normalized, raw);
      return normalized;
    }
    if (protocolId == 'openai.chat_completions') {
      return OpenAICompatibleChatProvider.normalizeUsage(raw) ?? const {};
    }
    final input = raw['input_tokens'] ??
        raw['promptTokenCount'] ??
        raw['prompt_eval_count'];
    final output = raw['output_tokens'] ??
        raw['candidatesTokenCount'] ??
        raw['eval_count'];
    return {
      if (input is num) 'inputTokens': input,
      if (output is num) 'outputTokens': output,
    };
  }

  static void _accumulateProtocolToolCall(
    AiGatewayProtocolStreamEvent event,
    Map<int, Map<String, dynamic>> accumulators,
  ) {
    final index = event.toolCallIndex ??
        (event.toolCallId == null
            ? accumulators.length
            : accumulators.keys.firstWhere(
                (key) => accumulators[key]?['id'] == event.toolCallId,
                orElse: () => accumulators.length,
              ));
    final entry = accumulators.putIfAbsent(index, () => {});
    if (event.toolCallId != null) entry['id'] = event.toolCallId;
    final function = entry.putIfAbsent('function', () => <String, dynamic>{})
        as Map<String, dynamic>;
    if (event.toolName != null) function['name'] = event.toolName;
    if (event.thoughtSignature != null) {
      entry['thoughtSignature'] = event.thoughtSignature;
    }
    if (event.delta != null) {
      function['arguments'] = '${function['arguments'] ?? ''}${event.delta}';
    }
  }

  Future<void> _recordUsage(
    AiGatewayRouteProgress progress,
    Map<String, dynamic> usage,
    AiGatewayConnectorObservation observation, {
    required AiGatewayFacade runtime,
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
        await runtime.accountManagement.recordQuotaObservation(
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
    AiGatewayRouteProgress progress,
    AiGatewayMetricObservation metric,
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

  static Stream<String> _ndjsonData(Stream<List<int>> bytes) async* {
    await for (final line
        in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
      final payload = line.trim();
      if (payload.isNotEmpty) yield payload;
    }
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
      final target = entry.putIfAbsent('function', () => <String, dynamic>{})
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
            if (entry.value['thoughtSignature'] != null)
              'thoughtSignature': entry.value['thoughtSignature'],
            'function': entry.value['function'] ?? <String, dynamic>{},
          },
        )
        .toList(growable: false);
    return AIStreamEvent('', toolCalls: calls);
  }

  static Object _safeError(Object error) {
    if (error is AiGatewayRoutingException ||
        error is AiGatewayExecutionException) {
      return error;
    }
    return AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
  }

  static AiGatewayExecutionException _streamRequestError(Object? apiError) {
    final rawCode =
        apiError is Map ? apiError['code'] ?? apiError['type'] : null;
    return AiGatewayExecutionException(
      kind: AiGatewayFailureKind.request,
      code: rawCode is String ? rawCode : null,
    );
  }
}

AiGatewayConnectorObservation _mergeGatewayObservations(
  AiGatewayConnectorObservation first,
  AiGatewayConnectorObservation second,
) =>
    AiGatewayConnectorObservation(
      requestUsage: second.requestUsage.isKnown
          ? second.requestUsage
          : first.requestUsage,
      remainingQuota: second.remainingQuota.isKnown
          ? second.remainingQuota
          : first.remainingQuota,
      quotaSignals: {...first.quotaSignals, ...second.quotaSignals},
    );

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
