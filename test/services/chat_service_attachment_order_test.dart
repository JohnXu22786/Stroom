// Tests: attachment order is preserved through the chat service API message
// preparation pipeline.
//
// The user expects files to be sent in the API request in the same order
// as they appear in the composer's bottom input box. This test suite
// verifies that order is preserved at every intermediate step.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

/// Mock provider that captures the API messages for inspection.
class _MessageCaptureProvider extends BaseChatProvider {
  List<Map<String, dynamic>>? capturedMessages;

  @override
  String get name => 'MessageCapture';

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
  }) async {
    capturedMessages = messages;
    return 'test response';
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
  }) async* {
    capturedMessages = messages;
    yield AIStreamEvent('test response');
  }
}

/// Helper that creates an Attachment with pre-populated base64Data so that
/// _prepareApiMessages does not need to read from disk during tests.
///
/// The [contentSalt] is embedded in the fake base64 payload to make each
/// attachment's content deterministic, enabling content-based ordering
/// assertions in tests.
Attachment _createTestAttachment({
  required String fileName,
  required String fileType,
  String mimeType = 'image/jpeg',
  int contentSalt = 0,
}) {
  // Pre-compute a deterministic base64 string (small valid data).
  final data = utf8.encode('file-content-$fileName-salt-$contentSalt');
  final b64 = base64Encode(data);

  return Attachment(
    fileName: fileName,
    mimeType: mimeType,
    fileType: fileType,
    hash: 'hash-$fileName',
    storagePath: 'test/$fileName',
    fileSize: data.length,
    base64Data: b64,
  );
}

void main() {
  group('ChatMessage serialization preserves attachment order', () {
    test('toMap and fromMap round-trip maintains order', () {
      final attachments = [
        _createTestAttachment(
          fileName: 'first.jpg',
          fileType: 'image',
          contentSalt: 1,
        ),
        _createTestAttachment(
          fileName: 'second.jpg',
          fileType: 'image',
          contentSalt: 2,
        ),
        _createTestAttachment(
          fileName: 'third.jpg',
          fileType: 'image',
          contentSalt: 3,
        ),
      ];

      final msg = ChatMessage(
        role: 'user',
        content: 'Check these files',
        attachments: attachments,
      );

      final map = msg.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.attachments.length, 3);
      expect(restored.attachments[0].fileName, 'first.jpg');
      expect(restored.attachments[1].fileName, 'second.jpg');
      expect(restored.attachments[2].fileName, 'third.jpg');
    });

    test('single attachment order is preserved through round-trip', () {
      final attachments = [
        _createTestAttachment(
          fileName: 'single.png',
          fileType: 'image',
          contentSalt: 1,
        ),
      ];

      final msg = ChatMessage(
        role: 'user',
        content: 'Single file',
        attachments: attachments,
      );

      final map = msg.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.attachments.length, 1);
      expect(restored.attachments[0].fileName, 'single.png');
    });
  });

  group(
      'ChatService sendStream preserves attachment order in captured messages',
      () {
    late _MessageCaptureProvider provider;
    late ModelConfig modelConfig;
    late ChatService service;

    setUp(() {
      provider = _MessageCaptureProvider();
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test Model',
        typeConfig: {},
        customParams: [],
        reasoningParams: [],
      );
      service = ChatService(provider: provider, modelConfig: modelConfig);
    });

    tearDown(() {
      // Cancel any in-flight streams to prevent leaks between tests.
      service.cancel();
    });

    test('image attachments keep original order in API content parts',
        () async {
      final attachments = [
        _createTestAttachment(
          fileName: 'sunset.png',
          fileType: 'image',
          contentSalt: 1,
        ),
        _createTestAttachment(
          fileName: 'beach.jpg',
          fileType: 'image',
          contentSalt: 2,
        ),
        _createTestAttachment(
          fileName: 'mountain.jpg',
          fileType: 'image',
          contentSalt: 3,
        ),
      ];

      final history = <ChatMessage>[
        ChatMessage(
          role: 'user',
          content: 'Look at these photos',
          attachments: attachments,
        ),
      ];

      final stream =
          service.sendStream('Look at these photos', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 1);

      final content = messages[0]['content'] as List<dynamic>;
      // First part should be the text
      expect(content[0]['type'], 'text');
      expect(content[0]['text'], 'Look at these photos');
      // Then images in original order
      expect(content[1]['type'], 'image_url');
      expect(content[2]['type'], 'image_url');
      expect(content[3]['type'], 'image_url');

      // Verify the ordering via the data URI content (each has distinct base64)
      // Extract the data URIs and ensure the order matches input order
      final url1 = content[1]['image_url']['url'] as String;
      final url2 = content[2]['image_url']['url'] as String;
      final url3 = content[3]['image_url']['url'] as String;

      // Decode base64 data and verify the text content contains the fileName
      // The data was created as 'file-content-$fileName-salt-$contentSalt'
      final decoded1 = utf8.decode(base64Decode(url1.split(',')[1]));
      final decoded2 = utf8.decode(base64Decode(url2.split(',')[1]));
      final decoded3 = utf8.decode(base64Decode(url3.split(',')[1]));
      expect(decoded1, contains('sunset.png'));
      expect(decoded2, contains('beach.jpg'));
      expect(decoded3, contains('mountain.jpg'));
    });

    test('mixed file types keep original order in API content parts', () async {
      final attachments = [
        _createTestAttachment(
          fileName: 'chart.png',
          fileType: 'image',
          contentSalt: 1,
        ),
        _createTestAttachment(
          fileName: 'audio.mp3',
          fileType: 'audio',
          mimeType: 'audio/mpeg',
          contentSalt: 2,
        ),
        _createTestAttachment(
          fileName: 'video.mp4',
          fileType: 'video',
          mimeType: 'video/mp4',
          contentSalt: 3,
        ),
      ];

      final history = <ChatMessage>[
        ChatMessage(
          role: 'user',
          content: 'Mixed files',
          attachments: attachments,
        ),
      ];

      final stream = service.sendStream('Mixed files', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 1);

      final content = messages[0]['content'] as List<dynamic>;
      // First part is the text
      expect(content[0]['type'], 'text');

      // Then attachments in original order
      expect(content[1]['type'], 'image_url'); // image
      expect(content[2]['type'], 'input_audio'); // audio
      expect(content[3]['type'], 'video_url'); // video

      // Verify the data URIs contain the file names in correct order
      // Decode base64 data from each URI and verify the text content
      final imgUrl = content[1]['image_url']['url'] as String;
      final decodedImg = utf8.decode(base64Decode(imgUrl.split(',')[1]));
      expect(decodedImg, contains('chart.png'));

      final audioData = content[2]['input_audio']['data'] as String;
      final decodedAudio = utf8.decode(base64Decode(audioData));
      expect(decodedAudio, contains('audio.mp3'));

      final videoUrl = content[3]['video_url']['url'] as String;
      final decodedVideo = utf8.decode(base64Decode(videoUrl.split(',')[1]));
      expect(decodedVideo, contains('video.mp4'));
    });

    test('sendStreamWithTools preserves attachment order', () async {
      final attachments = [
        _createTestAttachment(
          fileName: 'first.jpg',
          fileType: 'image',
          contentSalt: 1,
        ),
        _createTestAttachment(
          fileName: 'second.jpg',
          fileType: 'image',
          contentSalt: 2,
        ),
        _createTestAttachment(
          fileName: 'third.jpg',
          fileType: 'image',
          contentSalt: 3,
        ),
      ];

      final history = <ChatMessage>[
        ChatMessage(
          role: 'user',
          content: 'Process these',
          attachments: attachments,
        ),
      ];

      final stream = service.sendStreamWithTools(
        'Process these',
        history: history,
      );
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 1);

      final content = messages[0]['content'] as List<dynamic>;
      expect(content.length, 4); // text + 3 images

      // Verify order: text, first, second, third
      expect(content[0]['type'], 'text');
      expect(content[1]['type'], 'image_url');
      expect(content[2]['type'], 'image_url');
      expect(content[3]['type'], 'image_url');

      // Verify the file names via the data URIs (decoding base64)
      final url1 = content[1]['image_url']['url'] as String;
      final url2 = content[2]['image_url']['url'] as String;
      final url3 = content[3]['image_url']['url'] as String;
      final decoded1 = utf8.decode(base64Decode(url1.split(',')[1]));
      final decoded2 = utf8.decode(base64Decode(url2.split(',')[1]));
      final decoded3 = utf8.decode(base64Decode(url3.split(',')[1]));
      expect(decoded1, contains('first.jpg'));
      expect(decoded2, contains('second.jpg'));
      expect(decoded3, contains('third.jpg'));
    });

    test(
        'history with multiple user messages preserves each message attachment order',
        () async {
      final firstAttachments = [
        _createTestAttachment(
          fileName: 'alpha.png',
          fileType: 'image',
          contentSalt: 1,
        ),
        _createTestAttachment(
          fileName: 'beta.png',
          fileType: 'image',
          contentSalt: 2,
        ),
      ];

      final secondAttachments = [
        _createTestAttachment(
          fileName: 'gamma.jpg',
          fileType: 'image',
          contentSalt: 3,
        ),
        _createTestAttachment(
          fileName: 'delta.jpg',
          fileType: 'image',
          contentSalt: 4,
        ),
        _createTestAttachment(
          fileName: 'epsilon.jpg',
          fileType: 'image',
          contentSalt: 5,
        ),
      ];

      final history = <ChatMessage>[
        ChatMessage(
          role: 'user',
          content: 'First message',
          attachments: firstAttachments,
        ),
        ChatMessage(
          role: 'assistant',
          content: 'OK, got the first batch',
        ),
        ChatMessage(
          role: 'user',
          content: 'Second message with more files',
          attachments: secondAttachments,
        ),
      ];

      final stream = service.sendStream(
        'Second message with more files',
        history: history,
      );
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 3);

      // First user message: text + 2 images in order
      var content0 = messages[0]['content'] as List<dynamic>;
      expect(content0[0]['type'], 'text');
      expect(content0[0]['text'], 'First message');
      expect(content0[1]['type'], 'image_url');
      expect(content0[2]['type'], 'image_url');
      var decoded0_1 = utf8.decode(
        base64Decode((content0[1]['image_url']['url'] as String).split(',')[1]),
      );
      var decoded0_2 = utf8.decode(
        base64Decode((content0[2]['image_url']['url'] as String).split(',')[1]),
      );
      expect(decoded0_1, contains('alpha.png'));
      expect(decoded0_2, contains('beta.png'));

      // Assistant message (plain text, no attachments)
      expect(messages[1]['role'], 'assistant');
      expect(messages[1]['content'], 'OK, got the first batch');

      // Second user message: text + 3 images in order
      var content2 = messages[2]['content'] as List<dynamic>;
      expect(content2[0]['type'], 'text');
      expect(content2[0]['text'], 'Second message with more files');
      expect(content2[1]['type'], 'image_url');
      expect(content2[2]['type'], 'image_url');
      expect(content2[3]['type'], 'image_url');
      var decoded2_1 = utf8.decode(
        base64Decode((content2[1]['image_url']['url'] as String).split(',')[1]),
      );
      var decoded2_2 = utf8.decode(
        base64Decode((content2[2]['image_url']['url'] as String).split(',')[1]),
      );
      var decoded2_3 = utf8.decode(
        base64Decode((content2[3]['image_url']['url'] as String).split(',')[1]),
      );
      expect(decoded2_1, contains('gamma.jpg'));
      expect(decoded2_2, contains('delta.jpg'));
      expect(decoded2_3, contains('epsilon.jpg'));
    });

    test('empty text with attachments preserves order', () async {
      // Edge case: when msg.content is empty, _prepareApiMessages skips the
      // text part and only adds attachment parts. The order must still match.
      final attachments = [
        _createTestAttachment(
          fileName: 'first.png',
          fileType: 'image',
          contentSalt: 1,
        ),
        _createTestAttachment(
          fileName: 'second.jpg',
          fileType: 'image',
          contentSalt: 2,
        ),
      ];

      final history = <ChatMessage>[
        ChatMessage(
          role: 'user',
          content: '',
          attachments: attachments,
        ),
      ];

      final stream = service.sendStream('', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 1);

      final content = messages[0]['content'] as List<dynamic>;
      // No text part — attachments start at index 0
      expect(content.length, 2);
      expect(content[0]['type'], 'image_url');
      expect(content[1]['type'], 'image_url');

      final decoded0 = utf8.decode(
        base64Decode((content[0]['image_url']['url'] as String).split(',')[1]),
      );
      final decoded1 = utf8.decode(
        base64Decode((content[1]['image_url']['url'] as String).split(',')[1]),
      );
      expect(decoded0, contains('first.png'));
      expect(decoded1, contains('second.jpg'));
    });
  });
}
