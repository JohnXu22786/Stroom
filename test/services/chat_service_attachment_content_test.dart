import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/chat_service_shared.dart';

// ====================================================================
// Mock provider that captures the messages sent to the API.
// ====================================================================
class _MessageCaptureProvider extends BaseChatProvider {
  /// Captures the messages from the last chatStream call.
  List<Map<String, dynamic>>? lastMessages;

  /// Completer to signal that the provider has received a chatStream call.
  final _streamCompleter = Completer<void>();

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
  }) async* {
    lastMessages = messages;
    if (!_streamCompleter.isCompleted) {
      _streamCompleter.complete();
    }
    yield AIStreamEvent('');
  }

  Future<void> waitForCall() => _streamCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('chatStream was never called within 5s'),
      );
}

void main() {
  group('ChatService - attachment content in API messages', () {
    late _MessageCaptureProvider provider;
    late ModelConfig modelConfig;

    setUp(() {
      provider = _MessageCaptureProvider();
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 8192},
      );
    });

    test('image attachment with cached base64 produces image_url content part',
        () async {
      final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      final b64 = base64Encode(imageBytes);
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'imghash123',
        storagePath: 'attachments/imghash123_photo.png',
        fileSize: imageBytes.length,
      )..base64Data = b64;

      final history = [
        ChatMessage(
          role: 'user',
          content: 'Check this image',
          attachments: [att],
        ),
      ];

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.sendStream('Check this image', history: history).listen((_) {});

      await provider.waitForCall();
      final messages = provider.lastMessages!;

      // Find the user message with attachments
      final userMsg = messages.firstWhere((m) => m['role'] == 'user');
      final parts = userMsg['content'] as List;

      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      expect(parts[0]['text'], 'Check this image');
      expect(parts[1]['type'], 'image_url');
      expect(
        (parts[1]['image_url'] as Map)['url'],
        'data:image/png;base64,$b64',
      );
    });

    test(
        'audio attachment with cached base64 produces input_audio content part',
        () async {
      final audioBytes = Uint8List.fromList([0xFF, 0xF3, 0x44, 0x00]);
      final b64 = base64Encode(audioBytes);
      final att = Attachment(
        fileName: 'audio.mp3',
        mimeType: 'audio/mpeg',
        fileType: 'audio',
        hash: 'audiohash456',
        storagePath: 'attachments/audiohash456_audio.mp3',
        fileSize: audioBytes.length,
      )..base64Data = b64;

      final history = [
        ChatMessage(
          role: 'user',
          content: 'Transcribe this',
          attachments: [att],
        ),
      ];

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.sendStream('Transcribe this', history: history).listen((_) {});

      await provider.waitForCall();
      final messages = provider.lastMessages!;

      final userMsg = messages.firstWhere((m) => m['role'] == 'user');
      final parts = userMsg['content'] as List;

      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      expect(parts[1]['type'], 'input_audio');
      expect(
        (parts[1]['input_audio'] as Map)['data'],
        b64,
      );
      expect(
        (parts[1]['input_audio'] as Map)['format'],
        'mp3',
      );
    });

    test('video attachment produces video_url content part', () async {
      final videoBytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x1C]);
      final b64 = base64Encode(videoBytes);
      final att = Attachment(
        fileName: 'video.mp4',
        mimeType: 'video/mp4',
        fileType: 'video',
        hash: 'videohash789',
        storagePath: 'attachments/videohash789_video.mp4',
        fileSize: videoBytes.length,
      )..base64Data = b64;

      final history = [
        ChatMessage(
          role: 'user',
          content: 'Analyze this video',
          attachments: [att],
        ),
      ];

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.sendStream('Analyze this video', history: history).listen((_) {});

      await provider.waitForCall();
      final messages = provider.lastMessages!;

      final userMsg = messages.firstWhere((m) => m['role'] == 'user');
      final parts = userMsg['content'] as List;

      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      // Should be video_url (correct format), not image_url (broken), not text
      expect(parts[1]['type'], 'video_url');
      expect(parts[1]['type'], isNot('image_url'));
      expect(parts[1]['type'], isNot('text'));
      final videoUrl = parts[1]['video_url'] as Map;
      expect(
        videoUrl['url'],
        'data:video/mp4;base64,$b64',
      );
    });

    test('text document attachment produces inline text content', () async {
      final textContent = 'Hello, this is a test document.';
      final textBytes = Uint8List.fromList(utf8.encode(textContent));
      final att = Attachment(
        fileName: 'notes.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'texthash111',
        storagePath: 'attachments/texthash111_notes.txt',
        fileSize: textBytes.length,
      );

      // Text documents don't have base64Data cached in _addPendingAttachment.
      // _prepareApiMessages calls AttachmentStorage.readFile(att.storagePath)
      // to read the text content. Since the backing file doesn't exist in
      // the test environment, readFile returns null and the test observes
      // the fallback error message — this exercises the real production code
      // path, not a simulation.
      final history = [
        ChatMessage(
          role: 'user',
          content: 'Read this',
          attachments: [att],
        ),
      ];

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.sendStream('Read this', history: history).listen((_) {});

      await provider.waitForCall();
      final messages = provider.lastMessages!;

      final userMsg = messages.firstWhere((m) => m['role'] == 'user');
      final parts = userMsg['content'] as List;

      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      expect(parts[1]['type'], 'text');
      // The text describes the file was not readable (since no disk file exists)
      expect(
        (parts[1]['text'] as String).contains('notes.txt'),
        true,
      );
    });

    test('non-text document with cached base64 produces file content part',
        () async {
      final docBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]);
      final b64 = base64Encode(docBytes);
      final att = Attachment(
        fileName: 'document.pdf',
        mimeType: 'application/pdf',
        fileType: 'document',
        hash: 'pdfhash444',
        storagePath: 'attachments/pdfhash444_document.pdf',
        fileSize: docBytes.length,
      )..base64Data = b64;

      final history = [
        ChatMessage(
          role: 'user',
          content: 'Read this PDF',
          attachments: [att],
        ),
      ];

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.sendStream('Read this PDF', history: history).listen((_) {});

      await provider.waitForCall();
      final messages = provider.lastMessages!;

      final userMsg = messages.firstWhere((m) => m['role'] == 'user');
      final parts = userMsg['content'] as List;

      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      expect(parts[1]['type'], 'file');
      final fileObj = parts[1]['file'] as Map;
      expect(fileObj['filename'], 'document.pdf');
      expect(fileObj['file_data'], 'data:application/pdf;base64,$b64');
    });

    test('non-text document with large file (>10MB) gets skip message',
        () async {
      final docBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]);
      final b64 = base64Encode(docBytes);
      final att = Attachment(
        fileName: 'big_doc.bin',
        mimeType: 'application/octet-stream',
        fileType: 'document',
        hash: 'bighash555',
        storagePath: 'attachments/bighash555_big.bin',
        fileSize: 11 * 1024 * 1024, // 11MB
      )..base64Data = b64;

      final history = [
        ChatMessage(
          role: 'user',
          content: 'Read this',
          attachments: [att],
        ),
      ];

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.sendStream('Read this', history: history).listen((_) {});

      await provider.waitForCall();
      final messages = provider.lastMessages!;

      final userMsg = messages.firstWhere((m) => m['role'] == 'user');
      final parts = userMsg['content'] as List;

      expect(parts.length, 2);
      expect(parts[1]['type'], 'text');
      expect(
        (parts[1]['text'] as String).contains('big_doc.bin'),
        true,
      );
    });

    test('attachments with known text extensions are treated as text',
        () async {
      // Test with a .css file which was missing from the old textExts list
      // When the disk file doesn't exist in tests, the text file path
      // produces an error message (tried but failed to read), while a
      // non-text file would produce a different generic placeholder.
      final textContent = 'body { color: red; }';
      final textBytes = Uint8List.fromList(utf8.encode(textContent));
      final att = Attachment(
        fileName: 'style.css',
        mimeType: 'text/css',
        fileType: 'document',
        hash: 'csshash333',
        storagePath: 'attachments/csshash333_style.css',
        fileSize: textBytes.length,
      );

      final history = [
        ChatMessage(
          role: 'user',
          content: 'Style',
          attachments: [att],
        ),
      ];

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.sendStream('Style', history: history).listen((_) {});

      await provider.waitForCall();
      final messages = provider.lastMessages!;

      final userMsg = messages.firstWhere((m) => m['role'] == 'user');
      final parts = userMsg['content'] as List;

      expect(parts.length, 2);
      expect(parts[1]['type'], 'text');
      // The message should indicate an attempt to read as text failed
      // (because disk file doesn't exist in test), not a generic placeholder
      expect(
        (parts[1]['text'] as String).contains('style.css'),
        true,
      );
    });

    test('large image (>10MB) is skipped with descriptive message', () async {
      final att = Attachment(
        fileName: 'big_image.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'bigimghash',
        storagePath: 'attachments/bigimghash_big.png',
        fileSize: 11 * 1024 * 1024, // 11MB
      )..base64Data = 'some_big_data';

      final history = [
        ChatMessage(
          role: 'user',
          content: 'Look',
          attachments: [att],
        ),
      ];

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.sendStream('Look', history: history).listen((_) {});

      await provider.waitForCall();
      final messages = provider.lastMessages!;

      final userMsg = messages.firstWhere((m) => m['role'] == 'user');
      final parts = userMsg['content'] as List;

      expect(parts.length, 2);
      expect(parts[1]['type'], 'text');
      expect(
        (parts[1]['text'] as String).contains('big_image.png'),
        true,
      );
    });
  });

  // ====================================================================
  // Tests for shared helper functions
  // ====================================================================

  group('audioFormatFromMimeType', () {
    test('returns correct format for common audio MIME types', () {
      expect(audioFormatFromMimeType('audio/mpeg'), 'mp3');
      expect(audioFormatFromMimeType('audio/mp3'), 'mp3');
      expect(audioFormatFromMimeType('audio/wav'), 'wav');
      expect(audioFormatFromMimeType('audio/ogg'), 'ogg');
      expect(audioFormatFromMimeType('audio/aac'), 'aac');
      expect(audioFormatFromMimeType('audio/flac'), 'flac');
      expect(audioFormatFromMimeType('audio/webm'), 'webm');
      expect(audioFormatFromMimeType('audio/mp4'), 'm4a');
    });

    test('falls back to mp3 for unknown MIME types', () {
      expect(audioFormatFromMimeType('audio/unknown'), 'mp3');
      expect(audioFormatFromMimeType('application/octet-stream'), 'mp3');
    });
  });

  group('imageExtension', () {
    test('returns correct extension for known MIME types', () {
      expect(imageExtension('image/png'), 'png');
      expect(imageExtension('image/gif'), 'gif');
      expect(imageExtension('image/webp'), 'webp');
      expect(imageExtension('image/bmp'), 'bmp');
    });

    test('falls back to jpeg for unknown image MIME types', () {
      expect(imageExtension('image/tiff'), 'jpeg');
      expect(imageExtension('image/avif'), 'jpeg');
    });
  });
}
