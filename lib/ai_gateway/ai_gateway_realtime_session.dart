/// Bidirectional audio and text sessions for supported upstream realtime APIs.
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_channel_unsupported.dart'
    if (dart.library.io) 'realtime_channel_io.dart'
    as realtime_channel;

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
  audioDelta,
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
      'conversation.item.input_audio_transcription.delta',
    }.contains(type)) {
      return AiGatewayRealtimeEvent(
        kind: AiGatewayRealtimeEventKind.textDelta,
        type: type,
        text: event['delta'] is String ? event['delta'] as String : '',
        raw: Map.unmodifiable(event),
      );
    }
    if (type == 'conversation.item.input_audio_transcription.completed') {
      return AiGatewayRealtimeEvent(
        kind: AiGatewayRealtimeEventKind.textComplete,
        type: type,
        text: event['transcript'] is String
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
    AiGatewayRealtimeConnectionOptions options,
  ) async {
    final channel = await realtime_channel.connectRealtimeChannel(
      options.uri,
      options.headers,
    );
    await channel.ready;
    return AiGatewayRealtimeSession._(
      providerId: options.providerId,
      channel: channel,
    );
  }
}

/// OpenAI's public Realtime API-key contract.
abstract final class AiGatewayOpenAiRealtimeAdapter {
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
