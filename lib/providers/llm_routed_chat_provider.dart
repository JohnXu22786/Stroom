import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/ai_stream_event.dart';
import '../ai_gateway/ai_gateway.dart';
import '../services/attachment_storage.dart';
import 'anthropic_chat_provider.dart';
import 'chat_api_provider.dart';
import '../services/conversation_media_storage.dart';

Set<String> llmRoutedChatSupportedConnectorTypes(String endpointType) =>
    switch (endpointType) {
      'anthropic' => const {'claude'},
      'google.gemini.generate_content' => const {'gemini', 'aistudio'},
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

/// ChatAdapter provider that keeps the application's existing chat protocol
/// while selecting an eligible account from the model's stable M1 group.
class LlmRoutedChatProvider extends BaseChatProvider {
  final Future<AiGatewayFacade> _runtime;
  final String groupId;
  final String localModelId;
  final String endpointType;
  final String? conversationId;
  String? selectedAccountId;
  final ConversationMediaWriter? _saveMediaFile;
  List<Attachment> _lastMediaAttachments = const [];
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
    this.conversationId,
    this.selectedAccountId,
    ConversationMediaWriter? saveMediaFile,
  })  : _runtime = runtime,
        _saveMediaFile = saveMediaFile;

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

  /// Media returned by the most recent non-streaming [chat] call.
  @override
  List<Attachment> get lastMediaAttachments =>
      List.unmodifiable(_lastMediaAttachments);

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
    _lastMediaAttachments = const [];
    final selectedAccountId = this.selectedAccountId;
    this.selectedAccountId = null;
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
      conversationId: conversationId,
      selectedAccountId: selectedAccountId,
      request: (candidate, progress) async {
        if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
        final protocolId = _protocolFor(candidate.account);
        final body = await _buildBody(
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
          _lastMediaAttachments = await _storeStreamMedia(
            result.data,
            protocolId,
          );
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
      conversationId: conversationId,
      selectedAccountId: selectedAccountId,
      request: (candidate, progress) async {
        if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
        final body = await _buildBody(
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
      final selectedAccountId = this.selectedAccountId;
      this.selectedAccountId = null;
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
          conversationId: conversationId,
          selectedAccountId: selectedAccountId,
          request: (candidate, progress) async {
            if (requestCancelToken.isCancelled) {
              throw requestCancelToken.cancelError!;
            }
            final protocolId = _protocolFor(candidate.account);
            final body = await _buildBody(
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

  Set<String> get _supportedConnectorTypes =>
      llmRoutedChatSupportedConnectorTypes(endpointType);

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
    final outputModalities = _requestedOutputModalities(extraParams);
    if (_effectiveTools(tools, extraParams).isNotEmpty) required.add('tools');
    if (_containsContentType(messages, const {
          'image',
          'image_url',
          'input_image',
          'output_image',
          'video_url',
          'video_frame',
          'input_video',
          'file',
          'input_file',
          'document',
        }) ||
        outputModalities.any(const {'image', 'video'}.contains)) {
      required.add('vision');
    }
    if (_containsContentType(messages, const {
          'input_audio',
          'output_audio',
          'audio',
          'audio_url',
          'audio_transcription',
          'text_audio',
        }) ||
        outputModalities.contains('audio')) {
      required.add('audio');
    }
    return required;
  }

  static Set<String> _requestedOutputModalities(
    Map<String, dynamic>? extraParams,
  ) {
    final modalities = <String>{};
    void addFrom(Map? options) {
      if (options == null) return;
      for (final key in const {
        'modalities',
        'output_modalities',
        'outputModalities',
        'response_modalities',
        'responseModalities',
      }) {
        final value = options[key];
        final values = value is Iterable ? value : [value];
        for (final item in values) {
          if (item is String) modalities.add(item.toLowerCase());
        }
      }
      if (options['audio'] is Map) modalities.add('audio');
    }

    addFrom(extraParams);
    final generationConfig = extraParams?['generationConfig'];
    if (generationConfig is Map) addFrom(generationConfig);
    return modalities;
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

  Future<Map<String, dynamic>> _buildBody(
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
  }) async {
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
    final resolvedMessages = await resolveConversationMediaReferences(messages);
    final request = AiGatewayProtocolBridges.buildRequest(
      protocolId,
      AiGatewayProtocolRequest(
        modelId: upstreamModelId,
        operation: operation,
        messages: resolvedMessages
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
    final mediaOutputs = <Object>[];
    final seenResponseMediaIds = <String>{};
    final responseAudioByItem = <String, _BufferedStreamAudio>{};
    final chatCompletionAudio = <int, _BufferedStreamAudio>{};
    final anthropicAccumulator = AnthropicStreamAccumulator();
    final protocolStreamState = AiGatewayProtocolStreamState();
    final parsedEvents = StreamController<AIStreamEvent>();
    final emittedMediaAttachments = Set<Attachment>.identity();
    var nextContentOrder = 0;

    AIStreamEvent orderedEvent(AIStreamEvent event) {
      if (event.text.isEmpty ||
          event.isReasoning ||
          event.contentOrder != null) {
        return event;
      }
      return AIStreamEvent(
        event.text,
        isReasoning: event.isReasoning,
        toolCalls: event.toolCalls,
        thinkingSignature: event.thinkingSignature,
        usage: event.usage,
        mediaAttachments: event.mediaAttachments,
        contentOrder: nextContentOrder++,
      );
    }

    Attachment atContentOrder(Attachment attachment, int contentOrder) =>
        attachment.copyWith(
          extraFields: {
            ...attachment.extraFields,
            'stroom.contentOrder': contentOrder,
          },
        );

    Future<void> flushAudio() async {
      for (final output in mediaOutputs.whereType<_BufferedStreamAudio>()) {
        if (output.attachment != null || output.bytes.length == 0) continue;
        final attachment = await _saveMediaAttachment(
          'audio',
          output.mimeType,
          output.bytes.toBytes(),
          protocolId,
          output.metadata,
        );
        output.attachment = atContentOrder(attachment, output.contentOrder);
      }
    }

    void emitMedia() {
      final attachments = <Attachment>[];
      for (final output in mediaOutputs) {
        if (output is Attachment) {
          attachments.add(output);
        } else if (output is _BufferedStreamAudio &&
            output.attachment != null) {
          attachments.add(output.attachment!);
        }
      }
      final pending = attachments.where(emittedMediaAttachments.add).toList()
        ..sort((left, right) =>
            (left.extraFields['stroom.contentOrder'] as int? ?? 1 << 30)
                .compareTo(
              right.extraFields['stroom.contentOrder'] as int? ?? 1 << 30,
            ));
      if (pending.isNotEmpty) {
        parsedEvents.add(
          AIStreamEvent(
            '',
            mediaAttachments: pending,
            contentOrder: pending
                .map((attachment) =>
                    attachment.extraFields['stroom.contentOrder'] as int?)
                .whereType<int>()
                .firstOrNull,
          ),
        );
      }
    }

    void queueMedia(List<Attachment> media) {
      for (final attachment in media) {
        final source = _jsonMap(
          attachment.extraFields['stroom.mediaSource'],
        );
        final metadata = _jsonMap(source?['metadata']);
        final mediaId = _stringValue(metadata?['id']);
        if (mediaId != null) seenResponseMediaIds.add(mediaId);
      }
      mediaOutputs.addAll([
        for (final attachment in media)
          atContentOrder(attachment, nextContentOrder++),
      ]);
      emitMedia();
    }

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
            var geminiContentPartsHandled = false;
            if (protocolId == 'google.gemini.generate_content' &&
                data['candidates'] is List) {
              for (final candidate
                  in (data['candidates'] as List).whereType<Map>().take(1)) {
                final content = _jsonMap(candidate['content']);
                final parts = content?['parts'];
                if (parts is! List) continue;
                geminiContentPartsHandled = true;
                for (final rawPart in parts.whereType<Map>()) {
                  final part = Map<String, dynamic>.from(rawPart);
                  if (part['text'] is String) {
                    parsedEvents.add(
                      AIStreamEvent(
                        part['text'] as String,
                        isReasoning: part['thought'] == true,
                        contentOrder:
                            part['thought'] == true ? null : nextContentOrder++,
                      ),
                    );
                  } else if (part['inlineData'] is Map) {
                    final media = await _storeStreamMedia(
                      part,
                      protocolId,
                      excludedImageGenerationIds: seenResponseMediaIds,
                    );
                    queueMedia(media);
                  } else if (part['fileData'] is Map) {
                    final fileData = _jsonMap(part['fileData'])!;
                    final reference = _stringValue(fileData['fileUri']);
                    if (reference != null && reference.isNotEmpty) {
                      final mimeType = _stringValue(fileData['mimeType']) ??
                          'application/octet-stream';
                      final mediaType = _mediaTypeFromMime(mimeType);
                      final uri = Uri.tryParse(reference);
                      final pathSegments = uri?.pathSegments
                              .where((segment) => segment.isNotEmpty)
                              .toList(growable: false) ??
                          const <String>[];
                      queueMedia([
                        Attachment(
                          fileName: pathSegments.isNotEmpty
                              ? pathSegments.last
                              : _mediaFileName(mediaType, mimeType),
                          mimeType: mimeType,
                          fileType: mediaType,
                          hash: '',
                          storagePath: reference,
                          fileSize: 0,
                          extraFields: {
                            'stroom.mediaReference': reference,
                            'stroom.mediaSource': {
                              'protocol': protocolId,
                              'metadata': sanitizeConversationMediaJson(
                                _mediaMetadata(part, const {'fileData'}),
                              ),
                            },
                          },
                        ),
                      ]);
                    }
                  }
                }
              }
            }
            final eventType = _stringValue(data['type']);
            final audioDelta = protocolId == 'openai.responses' &&
                    const {
                      'response.output_audio.delta',
                      'response.audio.delta',
                    }.contains(eventType)
                ? _stringValue(data['delta'])
                : null;
            if (audioDelta != null) {
              final itemId = _stringValue(data['item_id']);
              final outputIndex = _stringValue(data['output_index']);
              final contentIndex = _stringValue(data['content_index']) ?? '0';
              final audioKey =
                  '${itemId ?? outputIndex ?? 'default'}:$contentIndex';
              final responseAudio = responseAudioByItem[audioKey];
              final bytes = _decodeBase64Payload(audioDelta);
              if (bytes != null) {
                final output = responseAudioByItem.putIfAbsent(audioKey, () {
                  final created = _BufferedStreamAudio(nextContentOrder++);
                  mediaOutputs.add(created);
                  return created;
                });
                output.bytes.add(bytes);
              }
              final format = _stringValue(data['format']);
              final output = responseAudioByItem[audioKey] ?? responseAudio;
              if (format != null && output != null) {
                output.mimeType = _audioMimeFromFormat(format);
              }
              output?.metadata.addAll(
                _mediaMetadata(data, const {'delta'}),
              );
            }
            if (protocolId == 'openai.chat_completions') {
              for (final audio in _chatCompletionAudioDeltas(data)) {
                final bytes = _decodeBase64Payload(audio.data);
                if (bytes == null) continue;
                final output = chatCompletionAudio.putIfAbsent(
                  audio.choiceIndex,
                  () {
                    final output = _BufferedStreamAudio(nextContentOrder++);
                    output.metadata['choiceIndex'] = audio.choiceIndex;
                    mediaOutputs.add(output);
                    return output;
                  },
                );
                output.bytes.add(bytes);
                if (audio.format != null) {
                  output.mimeType = _audioMimeFromFormat(audio.format);
                }
                output.metadata.addAll(audio.metadata);
              }
            }
            final media = audioDelta == null && !geminiContentPartsHandled
                ? await _storeStreamMedia(
                    data,
                    protocolId,
                    accumulateAudio: protocolId == 'openai.chat_completions',
                    excludedImageGenerationIds: seenResponseMediaIds,
                  )
                : const <Attachment>[];
            if (media.isNotEmpty) queueMedia(media);
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
                parsedEvents.add(orderedEvent(event));
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
                parsedEvents.add(orderedEvent(event));
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
                    if (geminiContentPartsHandled) break;
                    parsedEvents.add(
                      AIStreamEvent(
                        event.delta ?? '',
                        contentOrder: (event.delta ?? '').isEmpty
                            ? null
                            : nextContentOrder++,
                      ),
                    );
                  case AiGatewayProtocolStreamEventKind.reasoningDelta:
                    if (geminiContentPartsHandled) break;
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
        await flushAudio();
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
        emitMedia();
        await parsedEvents.close();
      } catch (error, stack) {
        try {
          await flushAudio();
        } catch (_) {
          try {
            await flushAudio();
          } catch (_) {
            // Keep the original stream error if persisting partial media fails.
          }
        }
        emitMedia();
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

  Future<List<Attachment>> _storeStreamMedia(
    Map<String, dynamic> frame,
    String protocolId, {
    bool accumulateAudio = false,
    Set<String> excludedImageGenerationIds = const {},
  }) async {
    final payloads = <_StreamMediaPayload>[];
    final imageGenerationIds = <String>{};
    final seen = Set<Object>.identity();
    void visit(Object? value, {String? hint}) {
      if (value is Map) {
        if (!seen.add(value)) return;
        final map = Map<String, dynamic>.from(value);
        final type = _stringValue(map['type']) ?? hint;
        final inline = map['inlineData'] ?? map['inline_data'];
        if (inline is Map && inline['data'] is String) {
          payloads.add(
            _StreamMediaPayload(
              _mediaTypeFromMime(_stringValue(inline['mimeType']) ?? ''),
              _stringValue(inline['mimeType']) ?? 'application/octet-stream',
              inline['data'] as String,
              _mediaMetadata(map, const {'inlineData', 'inline_data'}),
            ),
          );
          return;
        }
        if (map['type'] == 'image_generation_call' && map['result'] is String) {
          final id = _stringValue(map['id']);
          if (id != null &&
              (excludedImageGenerationIds.contains(id) ||
                  !imageGenerationIds.add(id))) {
            return;
          }
          payloads.add(
            _StreamMediaPayload(
              'image',
              _stringValue(map['mime_type']) ?? 'image/png',
              map['result'] as String,
              _mediaMetadata(map, const {'result'}),
            ),
          );
          return;
        }
        if (map['type'] == 'response.image_generation_call.partial_image' &&
            map['partial_image_b64'] is String) {
          payloads.add(
            _StreamMediaPayload(
              'image',
              _stringValue(map['mime_type']) ?? 'image/png',
              map['partial_image_b64'] as String,
              _mediaMetadata(map, const {'partial_image_b64'}),
            ),
          );
          return;
        }
        if (const {'audio', 'input_audio', 'output_audio'}.contains(type) &&
            map['data'] is String) {
          if (accumulateAudio) return;
          final mimeType = _stringValue(map['mime_type'] ?? map['mimeType']) ??
              _audioMimeFromFormat(_stringValue(map['format']));
          payloads.add(
            _StreamMediaPayload(
              'audio',
              mimeType,
              map['data'] as String,
              _mediaMetadata(map, const {'data'}),
            ),
          );
          return;
        }
        final imageUrl = map['image_url'];
        final imageReference = imageUrl is Map ? imageUrl['url'] : imageUrl;
        if (imageReference is String && imageReference.startsWith('data:')) {
          final parsed = _decodeMediaDataUri(imageReference);
          if (parsed != null) {
            payloads.add(
              _StreamMediaPayload(
                'image',
                parsed.$1,
                base64Encode(parsed.$2),
                _mediaMetadata(map, const {'image_url'}),
              ),
            );
            return;
          }
        }
        final images = map['images'];
        if (images is List) {
          for (final image in images.whereType<String>()) {
            payloads.add(
              _StreamMediaPayload('image', 'image/png', image, const {}),
            );
          }
        }
        for (final entry in map.entries) {
          if (const {
            'data',
            'result',
            'images',
            'inlineData',
            'inline_data',
            'image_url',
          }.contains(entry.key)) {
            continue;
          }
          visit(entry.value, hint: entry.key);
        }
      } else if (value is List) {
        for (final item in value) {
          visit(item, hint: hint);
        }
      }
    }

    visit(frame);
    final attachments = <Attachment>[];
    for (final payload in payloads) {
      final decodedUri = _decodeMediaDataUri(payload.data);
      final bytes = decodedUri == null
          ? _decodeBase64Payload(payload.data)
          : decodedUri.$2;
      if (bytes == null || bytes.isEmpty) continue;
      final mimeType = decodedUri?.$1 ?? payload.mimeType;
      attachments.add(
        await _saveMediaAttachment(
          payload.type,
          mimeType,
          bytes,
          protocolId,
          payload.metadata,
        ),
      );
    }
    return attachments;
  }

  List<_StreamAudioDelta> _chatCompletionAudioDeltas(
    Map<String, dynamic> frame,
  ) {
    final deltas = <_StreamAudioDelta>[];
    final choices = frame['choices'];
    if (choices is! List) return deltas;
    for (final (choiceIndex, choice) in choices.indexed) {
      if (choice is! Map) continue;
      final delta = choice['delta'];
      final audio = delta is Map ? delta['audio'] : null;
      if (audio is! Map || audio['data'] is! String) continue;
      deltas.add(
        _StreamAudioDelta(
          choiceIndex:
              choice['index'] is int ? choice['index'] as int : choiceIndex,
          data: audio['data'] as String,
          format: _stringValue(audio['format']),
          metadata: _mediaMetadata(
            Map<String, dynamic>.from(audio),
            const {'data'},
          ),
        ),
      );
    }
    return deltas;
  }

  Future<Attachment> _saveMediaAttachment(
    String type,
    String mimeType,
    Uint8List bytes,
    String protocolId,
    Map<String, dynamic> metadata,
  ) async {
    final fileName = _mediaFileName(type, mimeType);
    final path = await (_saveMediaFile ?? AttachmentStorage.saveFile)(
      fileName,
      bytes,
      stableId: const Uuid().v4(),
    );
    return Attachment(
      fileName: fileName,
      mimeType: mimeType,
      fileType: type,
      hash: AttachmentStorage.computeHash(bytes),
      storagePath: path,
      fileSize: bytes.length,
      extraFields: {
        'stroom.mediaSource': {
          'protocol': protocolId,
          'metadata': sanitizeConversationMediaJson(metadata),
        },
      },
    );
  }

  static Map<String, dynamic> _mediaMetadata(
    Map<String, dynamic> source,
    Set<String> removed,
  ) =>
      {
        for (final entry in source.entries)
          if (!removed.contains(entry.key) &&
              !const {'data', 'result', 'inlineData', 'inline_data'}
                  .contains(entry.key))
            entry.key: entry.value,
      };

  static String _mediaTypeFromMime(String mimeType) =>
      mimeType.startsWith('audio/')
          ? 'audio'
          : mimeType.startsWith('video/')
              ? 'video'
              : mimeType.startsWith('image/')
                  ? 'image'
                  : 'file';

  static String _audioMimeFromFormat(String? format) => switch (format) {
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'ogg' => 'audio/ogg',
        'pcm16' || 'pcm' => 'audio/pcm',
        _ => 'audio/octet-stream',
      };

  static String _mediaFileName(String type, String mimeType) {
    final extension = switch (mimeType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'audio/mpeg' => 'mp3',
      'audio/wav' => 'wav',
      'audio/ogg' => 'ogg',
      'audio/pcm' => 'pcm',
      'video/mp4' => 'mp4',
      'application/pdf' => 'pdf',
      _ => 'bin',
    };
    return '$type.$extension';
  }

  static Uint8List? _decodeBase64Payload(String value) {
    try {
      return Uint8List.fromList(base64Decode(value));
    } on FormatException {
      return null;
    }
  }

  static (String, Uint8List)? _decodeMediaDataUri(String value) {
    final match = RegExp(
      r'^data:([^;,]+)(?:;[^,]+)*;base64,(.*)$',
      dotAll: true,
    ).firstMatch(value);
    if (match == null) return null;
    final bytes = _decodeBase64Payload(match.group(2)!);
    return bytes == null ? null : (match.group(1)!, bytes);
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

String? _stringValue(Object? value) => value is String ? value : null;

class _StreamMediaPayload {
  final String type;
  final String mimeType;
  final String data;
  final Map<String, dynamic> metadata;

  const _StreamMediaPayload(
    this.type,
    this.mimeType,
    this.data,
    this.metadata,
  );
}

class _StreamAudioDelta {
  final int choiceIndex;
  final String data;
  final String? format;
  final Map<String, dynamic> metadata;

  const _StreamAudioDelta({
    required this.choiceIndex,
    required this.data,
    required this.format,
    required this.metadata,
  });
}

class _BufferedStreamAudio {
  final int contentOrder;
  final BytesBuilder bytes = BytesBuilder(copy: false);
  final Map<String, dynamic> metadata = {};
  String mimeType = 'audio/pcm';
  Attachment? attachment;

  _BufferedStreamAudio(this.contentOrder);
}
