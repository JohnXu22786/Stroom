/// Bidirectional audio and text sessions for supported upstream realtime APIs.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ai_gateway_contracts.dart';
import 'realtime_channel_unsupported.dart'
    if (dart.library.io) 'realtime_channel_io.dart'
    as realtime_channel;
import '../utils/audio_chunker.dart';

class AiGatewayRealtimeConnectionOptions {
  final String providerId;
  final Uri uri;
  final Map<String, String> headers;

  AiGatewayRealtimeConnectionOptions({
    required this.providerId,
    required this.uri,
    required Map<String, String> headers,
  }) : headers = Map.unmodifiable(headers);
}

enum AiGatewayRealtimeEventKind {
  textDelta,
  textComplete,
  inputTranscript,
  reasoningDelta,
  audioDelta,
  toolCall,
  lifecycle,
  error,
  providerEvent,
}

class AiGatewayRealtimeEvent {
  final AiGatewayRealtimeEventKind kind;
  final String type;
  final String? text;
  final String? audioBase64;
  final Map<String, dynamic> raw;

  AiGatewayRealtimeEvent({
    required this.kind,
    required this.type,
    required this.raw,
    this.text,
    this.audioBase64,
  });
}

/// Provider-specific WebSocket setup and event normalization.
abstract final class AiGatewayRealtimeProtocol {
  /// Realtime is selected by the provider's published model ID and the
  /// account's credential kind, never by the account's configured HTTP API
  /// protocol. Catalog membership remains the caller's responsibility.
  static String? providerForModel(String connectorType, String modelId) {
    final normalizedModelId = modelId.trim().toLowerCase();
    if (normalizedModelId.isEmpty) return null;
    if (connectorType == 'openai-api' &&
        normalizedModelId.startsWith('gpt-realtime')) {
      return 'openai';
    }
    if (connectorType == 'xai' &&
        (normalizedModelId == 'grok-voice' ||
            normalizedModelId.startsWith('grok-voice-'))) {
      return 'xai';
    }
    return null;
  }

  static Set<String>? supportedConnectorTypesForModel(String modelId) {
    final normalizedModelId = modelId.trim().toLowerCase();
    if (normalizedModelId.startsWith('gpt-realtime')) {
      return const {'openai-api'};
    }
    if (normalizedModelId == 'grok-voice' ||
        normalizedModelId.startsWith('grok-voice-')) {
      return const {'xai'};
    }
    return null;
  }

  /// Converts the already protocol-neutral Stroom history, as represented by
  /// the routed chat bridge, into source-defined Realtime client events.
  /// Unsupported image, video, file, and tool shapes fail explicitly so Chat
  /// and Task Flow never drop those inputs silently.
  static List<Map<String, dynamic>> buildConversationEvents(
    List<Map<String, dynamic>> messages, {
    String providerId = 'openai',
    List<Map<String, dynamic>> tools = const [],
  }) {
    final events = <Map<String, dynamic>>[];
    if (providerId == 'openai') {
      events.add({
        'type': 'session.update',
        'session': {
          'audio': {
            'input': {
              'format': {'type': 'audio/pcm', 'rate': 24000},
            },
            'output': {
              'format': {'type': 'audio/pcm', 'rate': 24000},
              'voice': 'marin',
            },
          },
        },
      });
    }
    if (tools.isNotEmpty) {
      events.add({
        'type': 'session.update',
        'session': {
          'tools': [for (final tool in tools) _realtimeTool(tool)],
          'tool_choice': 'auto',
        },
      });
    }
    final systemInstructions = <String>[];
    for (final message in messages) {
      if (message['role'] != 'system') continue;
      final content = message['content'];
      if (content is! String) {
        throw UnsupportedError('Realtime system instructions must be text.');
      }
      if (content.isNotEmpty) systemInstructions.add(content);
    }
    if (systemInstructions.isNotEmpty) {
      events.add({
        'type': 'session.update',
        'session': {'instructions': systemInstructions.join('\n\n')},
      });
    }
    for (final message in messages) {
      if (message.containsKey('function_call') ||
          message.containsKey('tool_calls') && message['tool_calls'] is! List ||
          message.containsKey('tool_call_id') && message['role'] != 'tool') {
        throw UnsupportedError('Realtime function call history is invalid.');
      }
      final role = message['role'];
      if (role is! String ||
          !const {
            'system',
            'user',
            'assistant',
            'tool',
            'function',
          }.contains(role)) {
        throw UnsupportedError(
          'Realtime sessions require supported conversation history.',
        );
      }
      if (role == 'tool' || role == 'function') {
        final callId = message['tool_call_id'] ?? message['call_id'];
        final output = message['content'] ?? message['output'];
        if (callId is! String || output is! String) {
          throw UnsupportedError('Realtime tool results are not supported.');
        }
        events.add({
          'type': 'conversation.item.create',
          'item': {
            'type': 'function_call_output',
            'call_id': callId,
            'output': output,
          },
        });
        continue;
      }
      final content = message['content'];
      if (role == 'assistant' &&
          content == null &&
          message['tool_calls'] is List) {
        events.addAll(_toolCallHistory(message['tool_calls'] as List));
        continue;
      }
      if (role == 'system') {
        continue;
      }
      if (content is String) {
        if (content.isNotEmpty) events.add(_textItem(role, content));
        if (role == 'assistant' && message['tool_calls'] is List) {
          events.addAll(_toolCallHistory(message['tool_calls'] as List));
        }
        continue;
      }
      if (content is! List) {
        throw UnsupportedError('Realtime message content is not supported.');
      }
      final text = StringBuffer();
      for (final part in content) {
        if (part is! Map) {
          throw UnsupportedError('Realtime message content is not supported.');
        }
        final type = part['type'];
        if (type == 'text' || type == 'input_text') {
          final value = part['text'];
          if (value is! String) {
            throw UnsupportedError('Realtime text content is not supported.');
          }
          text.write(value);
          continue;
        }
        if (role == 'assistant' && type == 'input_audio') {
          // Generated assistant audio is already represented by its transcript
          // when available; replaying its WAV attachment as input audio would
          // incorrectly make the assistant speak as the next user's turn.
          continue;
        }
        if (role == 'user' && type == 'input_audio') {
          final audio = part['input_audio'];
          final data = audio is Map ? audio['data'] : part['data'];
          final format = audio is Map ? audio['format'] : part['format'];
          if (data is! String || data.isEmpty) {
            throw UnsupportedError('Realtime audio data is missing.');
          }
          final audioData = format == 'wav'
              ? _wavAudioToRealtimePcm(data)
              : format == 'pcm16' || format == 'audio/pcm'
              ? data
              : throw UnsupportedError(
                  'Realtime input audio supports 24 kHz PCM16 or PCM16 WAV; '
                  'convert compressed audio before sending.',
                );
          if (text.isNotEmpty) {
            events.add(_textItem(role, text.toString()));
            text.clear();
          }
          events.add({'type': 'input_audio_buffer.append', 'audio': audioData});
          events.add({'type': 'input_audio_buffer.commit'});
          continue;
        }
        throw UnsupportedError(
          'Realtime content type "$type" is not supported.',
        );
      }
      if (text.isNotEmpty) events.add(_textItem(role, text.toString()));
      if (role == 'assistant' && message['tool_calls'] is List) {
        events.addAll(_toolCallHistory(message['tool_calls'] as List));
      }
    }
    if (!messages.any((message) => message['role'] == 'user')) {
      throw ArgumentError('Realtime conversations require a user message.');
    }
    events.add({
      'type': 'response.create',
      if (providerId == 'openai')
        'response': {
          'output_modalities': ['audio'],
        },
    });
    return events;
  }

  static Map<String, dynamic> _textItem(String role, String text) => {
    'type': 'conversation.item.create',
    'item': {
      'type': 'message',
      'role': role,
      'content': [
        {'type': role == 'user' ? 'input_text' : 'text', 'text': text},
      ],
    },
  };

  static String _wavAudioToRealtimePcm(String base64Wav) {
    try {
      final input = Uint8List.fromList(base64Decode(base64Wav));
      final wav = const WavPreprocessor(
        config: AudioPreprocessConfig(targetSampleRate: 24000, forceMono: true),
      ).process(input);
      final info = parseWavHeader(wav);
      final pcm = Uint8List.sublistView(
        wav,
        info.dataOffset,
        info.dataOffset + info.dataSize,
      );
      return base64Encode(pcm);
    } on FormatException {
      throw UnsupportedError(
        'Realtime WAV input must contain uncompressed 16-bit PCM audio.',
      );
    }
  }

  static Map<String, dynamic> _realtimeTool(Map<String, dynamic> tool) {
    final function = tool['function'];
    if (tool['type'] != 'function' || function is! Map) {
      throw UnsupportedError('Realtime only supports function tools.');
    }
    final name = function['name'];
    final description = function['description'];
    final parameters = function['parameters'];
    if (name is! String || name.isEmpty || parameters is! Map) {
      throw UnsupportedError('Realtime function tool definition is invalid.');
    }
    return {
      'type': 'function',
      'name': name,
      if (description is String && description.isNotEmpty)
        'description': description,
      'parameters': Map<String, dynamic>.from(parameters),
    };
  }

  static List<Map<String, dynamic>> _toolCallHistory(List calls) {
    if (calls.any((call) => call is! Map)) {
      throw UnsupportedError('Realtime function call history is invalid.');
    }
    return [for (final call in calls) _realtimeToolCallHistory(call as Map)];
  }

  static Map<String, dynamic> _realtimeToolCallHistory(Map call) {
    final function = call['function'];
    if (function is! Map ||
        call['id'] is! String ||
        function['name'] is! String ||
        function['arguments'] is! String) {
      throw UnsupportedError('Realtime function call history is invalid.');
    }
    return {
      'type': 'conversation.item.create',
      'item': {
        'type': 'function_call',
        'call_id': call['id'],
        'name': function['name'],
        'arguments': function['arguments'],
      },
    };
  }

  static AiGatewayRealtimeConnectionOptions prepareConnection({
    required String providerId,
    required String authType,
    required String apiKey,
    required String modelId,
  }) {
    return switch (providerId) {
      'openai' ||
      'openai-api' => AiGatewayOpenAiRealtimeAdapter.prepareConnection(
        authType: authType,
        apiKey: apiKey,
        modelId: modelId,
      ),
      'xai' => AiGatewayXaiVoiceRealtimeAdapter.prepareConnection(
        authType: authType,
        apiKey: apiKey,
        modelId: modelId,
      ),
      _ => throw ArgumentError.value(providerId, 'providerId'),
    };
  }

  static AiGatewayRealtimeEvent mapEvent(
    String providerId,
    Map<String, dynamic> event,
  ) {
    final type = event['type'] is String ? event['type'] as String : 'unknown';
    if (providerId != 'openai' && providerId != 'xai') {
      throw ArgumentError.value(providerId, 'providerId');
    }
    if (const {
      'response.output_text.delta',
      'response.text.delta',
      'response.audio_transcript.delta',
      'response.output_audio_transcript.delta',
    }.contains(type)) {
      return AiGatewayRealtimeEvent(
        kind: AiGatewayRealtimeEventKind.textDelta,
        type: type,
        text: event['delta'] is String ? event['delta'] as String : '',
        raw: Map.unmodifiable(event),
      );
    }
    if (type == 'response.reasoning_summary_text.delta' ||
        type == 'response.reasoning_text.delta') {
      return AiGatewayRealtimeEvent(
        kind: AiGatewayRealtimeEventKind.reasoningDelta,
        type: type,
        text: event['delta'] is String ? event['delta'] as String : '',
        raw: Map.unmodifiable(event),
      );
    }
    if (type == 'conversation.item.input_audio_transcription.delta' ||
        type == 'conversation.item.input_audio_transcription.completed') {
      return AiGatewayRealtimeEvent(
        kind: AiGatewayRealtimeEventKind.inputTranscript,
        type: type,
        text: event['delta'] is String
            ? event['delta'] as String
            : event['transcript'] is String
            ? event['transcript'] as String
            : '',
        raw: Map.unmodifiable(event),
      );
    }
    if (const {
      'response.output_text.done',
      'response.text.done',
      'response.audio_transcript.done',
      'response.output_audio_transcript.done',
    }.contains(type)) {
      final completedText = event['text'] ?? event['transcript'];
      return AiGatewayRealtimeEvent(
        kind: AiGatewayRealtimeEventKind.textComplete,
        type: type,
        text: completedText is String ? completedText : '',
        raw: Map.unmodifiable(event),
      );
    }
    if (const {
      'response.audio.delta',
      'response.output_audio.delta',
      'audio.delta',
    }.contains(type)) {
      return AiGatewayRealtimeEvent(
        kind: AiGatewayRealtimeEventKind.audioDelta,
        type: type,
        audioBase64: event['delta'] is String ? event['delta'] as String : '',
        raw: Map.unmodifiable(event),
      );
    }
    if (type == 'response.function_call_arguments.done') {
      return AiGatewayRealtimeEvent(
        kind: AiGatewayRealtimeEventKind.toolCall,
        type: type,
        raw: Map.unmodifiable(event),
      );
    }
    if (type == 'error' || type == 'response.failed') {
      return AiGatewayRealtimeEvent(
        kind: AiGatewayRealtimeEventKind.error,
        type: type,
        raw: Map.unmodifiable(event),
      );
    }
    if (type.startsWith('session.') ||
        type.startsWith('response.') ||
        type.startsWith('input_audio_buffer.') ||
        type.startsWith('conversation.item.')) {
      return AiGatewayRealtimeEvent(
        kind: AiGatewayRealtimeEventKind.lifecycle,
        type: type,
        raw: Map.unmodifiable(event),
      );
    }
    return AiGatewayRealtimeEvent(
      kind: AiGatewayRealtimeEventKind.providerEvent,
      type: type,
      raw: Map.unmodifiable(event),
    );
  }

  static Future<AiGatewayRealtimeSession> connect(
    AiGatewayRealtimeConnectionOptions options, {
    CancelToken? cancelToken,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw const AiGatewayRealtimeConnectionCancelled();
    }
    final connection = await realtime_channel.connectRealtimeChannel(
      options.uri,
      options.headers,
      timeout,
    );
    final channel = connection.channel;
    try {
      await Future.any<void>([
        channel.ready.timeout(timeout),
        if (cancelToken != null)
          cancelToken.whenCancel.then<void>(
            (_) => throw const AiGatewayRealtimeConnectionCancelled(),
          ),
      ]);
      if (cancelToken?.isCancelled == true) {
        throw const AiGatewayRealtimeConnectionCancelled();
      }
      return AiGatewayRealtimeSession._(
        providerId: options.providerId,
        channel: channel,
      );
    } catch (error) {
      try {
        await connection.abort();
      } catch (_) {
        // The handshake may already have closed the channel.
      }
      final statusCode = connection.handshakeStatusCode(error);
      if (statusCode != null) {
        throw AiGatewayRealtimeHandshakeFailure(statusCode: statusCode);
      }
      rethrow;
    }
  }
}

class AiGatewayRealtimeHandshakeFailure implements Exception {
  final int statusCode;

  const AiGatewayRealtimeHandshakeFailure({required this.statusCode});
}

class AiGatewayRealtimeConnectionCancelled implements Exception {
  const AiGatewayRealtimeConnectionCancelled();
}

/// OpenAI's public Realtime API-key contract.
abstract final class AiGatewayOpenAiRealtimeAdapter {
  static Map<String, dynamic> buildClientSecretRequest(String modelId) => {
    'expires_after': {'anchor': 'created_at', 'seconds': 600},
    'session': {
      'type': 'realtime',
      'model': modelId,
      'output_modalities': ['audio'],
      'audio': {
        'input': {
          'format': {'type': 'audio/pcm', 'rate': 24000},
          'turn_detection': null,
        },
        'output': {
          'format': {'type': 'audio/pcm', 'rate': 24000},
          'voice': 'marin',
        },
      },
    },
  };

  static AiGatewayRealtimeConnectionOptions prepareConnection({
    required String authType,
    required String apiKey,
    required String modelId,
  }) => _prepareRealtimeConnection(
    providerId: 'openai',
    host: 'api.openai.com',
    authType: authType,
    apiKey: apiKey,
    modelId: modelId,
  );

  static AiGatewayRealtimeEvent mapEvent(Map<String, dynamic> event) =>
      AiGatewayRealtimeProtocol.mapEvent('openai', event);

  static Future<AiGatewayRealtimeSession> connect({
    required String authType,
    required String apiKey,
    required String modelId,
  }) => AiGatewayRealtimeProtocol.connect(
    prepareConnection(authType: authType, apiKey: apiKey, modelId: modelId),
  );
}

/// xAI Voice Realtime's independent API-key contract. OAuth credentials used
/// by xAI chat connectors are intentionally not accepted here.
abstract final class AiGatewayXaiVoiceRealtimeAdapter {
  static AiGatewayRealtimeConnectionOptions prepareConnection({
    required String authType,
    required String apiKey,
    required String modelId,
  }) => _prepareRealtimeConnection(
    providerId: 'xai',
    host: 'api.x.ai',
    authType: authType,
    apiKey: apiKey,
    modelId: modelId,
  );

  static AiGatewayRealtimeEvent mapEvent(Map<String, dynamic> event) =>
      AiGatewayRealtimeProtocol.mapEvent('xai', event);

  static Future<AiGatewayRealtimeSession> connect({
    required String authType,
    required String apiKey,
    required String modelId,
  }) => AiGatewayRealtimeProtocol.connect(
    prepareConnection(authType: authType, apiKey: apiKey, modelId: modelId),
  );
}

AiGatewayRealtimeConnectionOptions _prepareRealtimeConnection({
  required String providerId,
  required String host,
  required String authType,
  required String apiKey,
  required String modelId,
}) {
  if (authType != 'api_key' || apiKey.trim().isEmpty) {
    throw ArgumentError('Realtime sessions require an API key.');
  }
  if (modelId.trim().isEmpty) throw ArgumentError.value(modelId, 'modelId');
  return AiGatewayRealtimeConnectionOptions(
    providerId: providerId,
    uri: Uri(
      scheme: 'wss',
      host: host,
      path: '/v1/realtime',
      queryParameters: {'model': modelId},
    ),
    headers: {'Authorization': 'Bearer $apiKey'},
  );
}

/// Owns one realtime connection and exposes normalized provider events.
class AiGatewayRealtimeSession {
  final String providerId;
  final WebSocketChannel _channel;
  bool _closed = false;

  AiGatewayRealtimeSession._({
    required this.providerId,
    required WebSocketChannel channel,
  }) : _channel = channel;

  Stream<AiGatewayRealtimeEvent> get events => _channel.stream.map((frame) {
    final decoded = jsonDecode(frame as String);
    if (decoded is! Map) {
      throw const FormatException('Realtime event must be a JSON object.');
    }
    return AiGatewayRealtimeProtocol.mapEvent(
      providerId,
      Map<String, dynamic>.from(decoded),
    );
  });

  void sendEvent(Map<String, dynamic> event) {
    if (_closed) throw StateError('Realtime session is closed.');
    _channel.sink.add(jsonEncode(event));
  }

  void sendText(String text) {
    sendEvent({
      'type': 'conversation.item.create',
      'item': {
        'type': 'message',
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': text},
        ],
      },
    });
    sendEvent({'type': 'response.create'});
  }

  void appendAudio(String base64Chunk) =>
      sendEvent({'type': 'input_audio_buffer.append', 'audio': base64Chunk});

  void commitAudio() => sendEvent({'type': 'input_audio_buffer.commit'});

  void cancelResponse() => sendEvent({'type': 'response.cancel'});

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _channel.sink.close(1000);
  }
}

/// Optional internal transport capability implemented by the account
/// executor. Keeping secret lookup behind this boundary prevents Realtime
/// routes in Chat and Task Flow from reading credential storage directly.
abstract interface class AiGatewayRealtimeExecutor {
  Future<AiGatewayRealtimeSession> connectRealtime({
    required AiGatewayAccount account,
    required String modelId,
    CancelToken? cancelToken,
  });
}
