part of 'chat_service_streaming_test.dart';

void chatServiceStreamingGroup4() {
  // ====================================================================
  // From chat_service_base64_cache_test.dart
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
      final service = ChatService(provider: provider, modelConfig: modelConfig);

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

    test('sendStream stream ends promptly after cancel() is called', () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

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
      final service = ChatService(provider: provider, modelConfig: modelConfig);

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
      final service = ChatService(provider: provider, modelConfig: modelConfig);

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
}
