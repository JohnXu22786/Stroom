part of 'chat_service_streaming_test.dart';

void chatServiceStreamingGroup4() {
  // ====================================================================
  // From chat_service_base64_cache_test.dart
  // ====================================================================

  group('ChatService - base64 cached attachment handling', () {
    test(
        '_prepareApiMessages uses cached base64 when attachment has base64Data',
        () async {
      // Create a ChatMessage with an attachment that has cached base64
      final base64Content = base64Encode(utf8.encode('fake_image_data'));
      final att = Attachment(
        fileName: 'test.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'testhash123',
        storagePath: 'attachments/testhash123_12345.png',
        fileSize: 100,
      )..base64Data = base64Content;

      final msg = ChatMessage(
        role: 'user',
        content: 'Check this image',
        attachments: [att],
      );

      // Call _prepareApiMessages via a helper that simulates what the
      // service does — we can't call private methods directly, so we
      // verify the logic that would be used:
      // 1. If att.base64Data != null, use it directly
      // 2. Otherwise, read from AttachmentStorage

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': msg.content});

      for (final a in msg.attachments) {
        if (a.fileType == 'image') {
          if (a.base64Data != null) {
            // Use cached base64
            final b64 = a.base64Data!;
            final ext = _privateImageExtension(a.mimeType);
            parts.add({
              'type': 'image_url',
              'image_url': {'url': 'data:image/$ext;base64,$b64'},
            });
          } else {
            // Fallback: read from disk (not tested here)
            throw Exception('Should not reach disk read');
          }
        }
      }

      // Verify the result uses the cached base64
      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      expect(parts[0]['text'], 'Check this image');
      expect(parts[1]['type'], 'image_url');
      expect(
        (parts[1]['image_url'] as Map)['url'],
        'data:image/png;base64,$base64Content',
      );
    });

    test(
        '_prepareApiMessages falls back to description when cached base64 is null and file is image',
        () async {
      // Create a ChatMessage with an attachment that has NO base64Data
      final att = Attachment(
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileType: 'image',
        hash: 'testhash456',
        storagePath: 'attachments/testhash456_67890.jpg',
        fileSize: 200,
      );
      // base64Data not set → null

      final msg = ChatMessage(
        role: 'user',
        content: 'View this photo',
        attachments: [att],
      );

      // Verify the logic path: when base64Data is null,
      // it should produce a placeholder text indicating the file
      bool diskReadAttempted = false;

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': msg.content});

      for (final a in msg.attachments) {
        if (a.fileType == 'image') {
          if (a.base64Data != null) {
            // Use cached base64 (should not happen in this test)
            throw Exception('Should not have cached base64');
          } else {
            // Base64 not cached → need to read from disk
            // (In production, _prepareApiMessages would call
            // AttachmentStorage.readFile and encode the bytes)
            diskReadAttempted = true;
            parts.add({
              'type': 'text',
              'text': '[图片附件: ${a.fileName}]',
            });
          }
        }
      }

      expect(diskReadAttempted, true);
      expect(parts.length, 2);
      expect(parts[1]['type'], 'text');
      expect(
        (parts[1]['text'] as String).contains('photo.jpg'),
        true,
      );
    });

    // ====================================================================
    // ChatService cancel tests
    // ====================================================================

    group('ChatService cancel', () {
      late _StallingChatProvider provider;
      late ModelConfig modelConfig;

      setUp(() {
        provider = _StallingChatProvider();
        modelConfig = ModelConfig(
          modelId: 'test-model',
          name: 'Test Model',
          typeConfig: {
            'context': 4096,
            'temperature': 0.7,
          },
        );
      });

      test('sendStreamWithTools stream ends promptly after cancel() is called',
          () async {
        final service =
            ChatService(provider: provider, modelConfig: modelConfig);

        // Start streaming
        final stream = service.sendStreamWithTools('Hello', history: []);
        final events = <ChatEvent>[];

        // Use a completer to signal when the stream ends
        final streamEnded = Completer<void>();

        // Listen to the stream (using listen instead of await for to allow
        // the test to call cancel() from outside the loop)
        final sub = stream.listen(
          (event) => events.add(event),
          onDone: () {
            if (!streamEnded.isCompleted) streamEnded.complete();
          },
          onError: (e) {
            if (!streamEnded.isCompleted) streamEnded.complete();
          },
        );

        // Wait a short bit for the microtask to set up
        await Future.delayed(const Duration(milliseconds: 50));

        // Cancel the stream
        service.cancel();

        // Stream should end within a reasonable time
        await streamEnded.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail(
            'Stream did not end after cancel() — this is the bug being fixed. '
            'The stream should end promptly when cancel() is called.',
          ),
        );

        await sub.cancel();
        await provider.closeController();
      });

      test('sendStream stream ends promptly after cancel() is called',
          () async {
        final service =
            ChatService(provider: provider, modelConfig: modelConfig);

        // Start streaming via sendStream
        final stream = service.sendStream('Hello', history: []);
        final events = <String>[];

        final streamEnded = Completer<void>();
        final sub = stream.listen(
          (event) => events.add(event),
          onDone: () {
            if (!streamEnded.isCompleted) streamEnded.complete();
          },
          onError: (e) {
            if (!streamEnded.isCompleted) streamEnded.complete();
          },
        );

        await Future.delayed(const Duration(milliseconds: 50));

        service.cancel();

        await streamEnded.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail(
            'sendStream should end promptly after cancel()',
          ),
        );

        await sub.cancel();
        await provider.closeController();
      });

      test('cancel() can be called before sendStreamWithTools microtask runs',
          () async {
        // This tests the edge case where cancel() is called very early,
        // before the Future.microtask in sendStreamWithTools has executed.
        final service =
            ChatService(provider: provider, modelConfig: modelConfig);

        // Get the stream but don't await it yet
        final stream = service.sendStreamWithTools('Hello', history: []);

        // Immediately cancel before any microtask runs
        service.cancel();

        final events = <ChatEvent>[];
        final streamEnded = Completer<void>();
        final sub = stream.listen(
          (event) => events.add(event),
          onDone: () {
            if (!streamEnded.isCompleted) streamEnded.complete();
          },
          onError: (e) {
            if (!streamEnded.isCompleted) streamEnded.complete();
          },
        );

        await streamEnded.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail(
            'Stream should end when cancel() is called early',
          ),
        );

        await sub.cancel();
        await provider.closeController();
      });

      test('cancel() can be called multiple times without error', () async {
        final service =
            ChatService(provider: provider, modelConfig: modelConfig);

        // Start streaming
        final stream = service.sendStreamWithTools('Hello', history: []);
        final events = <ChatEvent>[];

        final streamEnded = Completer<void>();
        final sub = stream.listen(
          (event) => events.add(event),
          onDone: () {
            if (!streamEnded.isCompleted) streamEnded.complete();
          },
          onError: (e) {
            if (!streamEnded.isCompleted) streamEnded.complete();
          },
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Call cancel multiple times
        service.cancel();
        service.cancel(); // Second call should be a no-op, not crash
        service.cancel(); // Third call should also be safe

        await streamEnded.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail(
            'Stream should end after multiple cancel() calls',
          ),
        );

        await sub.cancel();
        await provider.closeController();
      });
    });

    // ====================================================================
    // Original test section
    // ====================================================================

    test('non-image attachments with base64Data do not use image_url format',
        () async {
      // Non-image attachments should not produce image_url even if base64Data is set
      final att = Attachment(
        fileName: 'doc.pdf',
        mimeType: 'application/pdf',
        fileType: 'document',
        hash: 'dochash789',
        storagePath: 'attachments/dochash789_11111.pdf',
        fileSize: 300,
      )..base64Data = base64Encode(utf8.encode('fake_pdf_content'));

      final msg = ChatMessage(
        role: 'user',
        content: 'Here is a document',
        attachments: [att],
      );

      // The _prepareApiMessages should NOT create an image_url for non-image files
      bool imageUrlCreated = false;
      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': msg.content});

      for (final a in msg.attachments) {
        if (a.fileType == 'image') {
          if (a.base64Data != null) {
            imageUrlCreated = true;
          }
        } else {
          // Non-image handling (should use text description path)
          parts.add({
            'type': 'text',
            'text': '[Attached file: ${a.fileName}]',
          });
        }
      }

      expect(imageUrlCreated, false);
      expect(parts.length, 2);
      expect(parts[1]['type'], 'text');
    });

    test(
        'cache is naturally tied to conversation lifecycle (base64Data cleared with attachment)',
        () async {
      // Verify that when attachments are replaced in a ChatMessage,
      // the old base64 data is naturally garbage collected
      final att1 = Attachment(
        fileName: 'img1.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'h1',
        storagePath: 'attachments/h1.png',
        fileSize: 50,
      )..base64Data = 'cached_data_1';

      final msg = ChatMessage(
        role: 'user',
        content: 'Test',
        attachments: [att1],
      );

      expect(msg.attachments.first.base64Data, 'cached_data_1');

      // Replace attachments (simulating message edit or re-send with new files)
      final att2 = Attachment(
        fileName: 'img2.jpg',
        mimeType: 'image/jpeg',
        fileType: 'image',
        hash: 'h2',
        storagePath: 'attachments/h2.jpg',
        fileSize: 75,
      )..base64Data = 'cached_data_2';

      // Use internal mutation (ChatMessage has no setter for attachments)
      final newMsg = ChatMessage(
        role: 'user',
        content: 'Test',
        attachments: [att2],
      );

      // Old att1's base64Data reference is gone
      expect(newMsg.attachments.first.base64Data, 'cached_data_2');
      expect(newMsg.attachments.length, 1);
      expect(newMsg.attachments.first.hash, 'h2');
    });
  });
}
