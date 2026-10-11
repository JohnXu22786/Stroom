import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/message_block.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('message links launch phone and messaging handlers safely', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final launchedUris = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(launcherChannel, (call) async {
      if (call.method == 'launch') {
        final args = call.arguments as Map<Object?, Object?>;
        launchedUris.add(args['url']! as String);
        return true;
      }
      return null;
    });

    final commands = <Map<String, dynamic>>[];
    late void Function(Map<String, dynamic>) sendEvent;
    Widget hostBuilder(
      String _,
      ValueNotifier<Map<String, dynamic>?> nextCommands,
      void Function(Map<String, dynamic>) nextSendEvent,
    ) {
      sendEvent = nextSendEvent;
      nextCommands.addListener(() {
        final command = nextCommands.value;
        if (command != null) commands.add(Map.of(command));
      });
      return const SizedBox.shrink();
    }

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith(
              (ref) => ConversationsNotifier(ref),
            ),
            activeConversationIdProvider.overrideWith((ref) => 'links'),
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifier(),
            ),
          ],
          child: MaterialApp(
            home: ChatPage(messageHostBuilder: hostBuilder),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPage)),
      );
      final now = DateTime(2026, 1, 1);
      container.read(conversationsProvider.notifier).state = [
        Conversation.fromMap({
          'id': 'links',
          'title': 'Links',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'messages': [
            ChatMessage(
              id: 'assistant',
              role: 'assistant',
              content: 'Try a phone link.',
              createdAt: now,
            ).toMap(),
          ],
          'isPinned': false,
          'sortOrder': 0,
        }),
      ];
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      sendEvent({'type': 'ready'});
      await tester.pump();
      final session = commands
          .lastWhere((command) => command['type'] == 'snapshot')['session'];

      for (final uri in ['tel:+1-555-0100', 'sms:+1-555-0100?body=Hello']) {
        sendEvent({'type': 'link', 'session': session, 'uri': uri});
        await tester.pump();
      }
      expect(launchedUris, ['tel:+1-555-0100', 'sms:+1-555-0100?body=Hello']);

      sendEvent({
        'type': 'link',
        'session': session,
        'uri': 'javascript:alert(1)',
      });
      sendEvent({
        'type': 'link',
        'session': session,
        'uri': 'file:///etc/passwd',
      });
      await tester.pump();
      expect(launchedUris, hasLength(2));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      messenger.setMockMethodCallHandler(launcherChannel, null);
    }
  });

  testWidgets('web message snapshots preserve creation timestamps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final createdAt = DateTime.utc(2026, 5, 6, 7, 8);
    final conversation = Conversation(
      id: 'timestamps',
      title: 'Timestamps',
      createdAt: createdAt,
      updatedAt: createdAt,
      messages: [
        ChatMessage(
          id: 'user-message',
          role: 'user',
          content: 'Question',
          createdAt: createdAt,
        ),
      ],
    );
    final commands = <Map<String, dynamic>>[];
    late void Function(Map<String, dynamic>) sendEvent;
    Widget hostBuilder(
      String _,
      ValueNotifier<Map<String, dynamic>?> nextCommands,
      void Function(Map<String, dynamic>) nextSendEvent,
    ) {
      sendEvent = nextSendEvent;
      nextCommands.addListener(() {
        final command = nextCommands.value;
        if (command != null) commands.add(Map.of(command));
      });
      return const SizedBox.shrink();
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationsProvider.overrideWith((ref) {
            final notifier = ConversationsNotifier(ref);
            notifier.state = [conversation];
            return notifier;
          }),
          activeConversationIdProvider.overrideWith((ref) => 'timestamps'),
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ChatPage(messageHostBuilder: hostBuilder),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    sendEvent({'type': 'ready'});
    await tester.pump();
    final snapshot = commands.lastWhere(
      (command) => command['type'] == 'snapshot',
    );
    final message =
        (snapshot['messages'] as List).single as Map<String, dynamic>;
    expect(message['createdAt'], createdAt.toIso8601String());

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('WebView numeric block indexes accept JavaScript numbers', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime(2026, 1, 1);
    final commands = <Map<String, dynamic>>[];
    late void Function(Map<String, dynamic>) sendEvent;
    Widget hostBuilder(
      String _,
      ValueNotifier<Map<String, dynamic>?> nextCommands,
      void Function(Map<String, dynamic>) nextSendEvent,
    ) {
      sendEvent = nextSendEvent;
      nextCommands.addListener(() {
        final command = nextCommands.value;
        if (command != null) commands.add(Map.of(command));
      });
      return const SizedBox.shrink();
    }

    final conversation = Conversation(
      id: 'reasoning-event',
      title: 'Reasoning event',
      createdAt: now,
      updatedAt: now,
      messages: [
        ChatMessage(
          id: 'assistant',
          role: 'assistant',
          content: 'Answer',
          createdAt: now,
          blocks: const [
            ReasoningBlock(text: 'private reasoning'),
            TextBlock(text: 'Answer'),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationsProvider.overrideWith((ref) {
            final notifier = ConversationsNotifier(ref);
            notifier.state = [conversation];
            return notifier;
          }),
          activeConversationIdProvider.overrideWith(
            (ref) => 'reasoning-event',
          ),
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ChatPage(messageHostBuilder: hostBuilder),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    sendEvent({'type': 'ready'});
    await tester.pump();
    final snapshot = commands.lastWhere(
      (command) => command['type'] == 'snapshot',
    );
    sendEvent({
      'type': 'action',
      'session': snapshot['session'],
      'messageId': 'assistant',
      'action': 'reasoning',
      'blockIndex': 0.0,
    });
    await tester.pump();

    expect(find.text('private reasoning'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
