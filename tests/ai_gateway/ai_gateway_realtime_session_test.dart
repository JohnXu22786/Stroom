import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/ai_gateway/ai_gateway_realtime_session.dart';

void main() {
  group('AI Gateway realtime session protocol', () {
    test('requires API-key auth and keeps provider endpoints separate', () {
      expect(
        () => AiGatewayRealtimeProtocol.prepareConnection(
          providerId: 'xai',
          authType: 'oauth',
          apiKey: 'oauth-token',
          modelId: 'grok-voice',
        ),
        throwsArgumentError,
      );

      final openAi = AiGatewayRealtimeProtocol.prepareConnection(
        providerId: 'openai-api',
        authType: 'api_key',
        apiKey: 'openai-key',
        modelId: 'gpt-realtime',
      );
      final xai = AiGatewayRealtimeProtocol.prepareConnection(
        providerId: 'xai',
        authType: 'api_key',
        apiKey: 'xai-key',
        modelId: 'grok-voice',
      );

      expect(
        openAi.uri.toString(),
        'wss://api.openai.com/v1/realtime?model=gpt-realtime',
      );
      expect(xai.uri.toString(), 'wss://api.x.ai/v1/realtime?model=grok-voice');
      expect(
        AiGatewayXaiVoiceRealtimeAdapter.prepareConnection(
          authType: 'api_key',
          apiKey: 'xai-key',
          modelId: 'grok-voice',
        ).headers['Authorization'],
        'Bearer xai-key',
      );
      expect(
        () => AiGatewayXaiVoiceRealtimeAdapter.prepareConnection(
          authType: 'oauth',
          apiKey: 'oauth-access-token',
          modelId: 'grok-voice',
        ),
        throwsArgumentError,
      );
      expect(openAi.headers['Authorization'], 'Bearer openai-key');
      expect(xai.headers['Authorization'], 'Bearer xai-key');
    });

    test('maps realtime text, audio, lifecycle, cancellation, and errors', () {
      final text = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'response.output_text.delta',
        'delta': 'hello',
      });
      final audio = AiGatewayRealtimeProtocol.mapEvent('xai', {
        'type': 'response.audio.delta',
        'delta': 'AQID',
      });
      final lifecycle = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'session.created',
        'session': {'id': 'sess-1'},
      });
      final error = AiGatewayRealtimeProtocol.mapEvent('xai', {
        'type': 'error',
        'error': {'code': 'bad_request'},
      });
      final failedResponse = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'response.failed',
        'response': {
          'error': {'code': 'server_error'},
        },
      });
      final transcript = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'conversation.item.input_audio_transcription.completed',
        'transcript': 'recognized speech',
      });
      final transcriptionDelta = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'conversation.item.input_audio_transcription.delta',
        'delta': 'recognized ',
      });
      final generatedText = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'response.output_text.done',
        'text': 'final answer',
      });
      final generatedTranscript = AiGatewayRealtimeProtocol.mapEvent('xai', {
        'type': 'response.output_audio_transcript.done',
        'transcript': 'spoken answer',
      });

      expect(text.kind, AiGatewayRealtimeEventKind.textDelta);
      expect(text.text, 'hello');
      expect(audio.kind, AiGatewayRealtimeEventKind.audioDelta);
      expect(audio.audioBase64, 'AQID');
      expect(lifecycle.kind, AiGatewayRealtimeEventKind.lifecycle);
      expect(error.kind, AiGatewayRealtimeEventKind.error);
      expect(failedResponse.kind, AiGatewayRealtimeEventKind.error);
      expect((failedResponse.raw['response'] as Map)['error'], {
        'code': 'server_error',
      });
      expect(transcript.kind, AiGatewayRealtimeEventKind.textComplete);
      expect(transcript.text, 'recognized speech');
      expect(transcriptionDelta.kind, AiGatewayRealtimeEventKind.textDelta);
      expect(generatedText.kind, AiGatewayRealtimeEventKind.textComplete);
      expect(generatedText.text, 'final answer');
      expect(generatedTranscript.kind, AiGatewayRealtimeEventKind.textComplete);
      expect(generatedTranscript.text, 'spoken answer');
      expect(error.raw['error'], {'code': 'bad_request'});
    });
  });
}
