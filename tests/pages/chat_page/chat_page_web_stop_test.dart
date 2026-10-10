import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/pages/chat/message_view/dsh_message_view.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_stream_manager.dart';

class _DelayedManager extends ChatStreamManager {
  _DelayedManager() : super(null);
  final result = Completer<StreamResult>();
  late String messageId;
  late List<ChatMessage> sentHistory;

  @override
  Future<StreamResult> startStreaming({
    required String text,
    required String convId,
    required List<ChatMessage> history,
    List<ToolDefinition> tools = const [],
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    String? streamingMsgId,
    Assistant? assistant,
    ProviderEntriesState? entriesStateOverride,
  }) {
    messageId = streamingMsgId!;
    sentHistory = history;
    return result.future;
  }
}

void main() {
  testWidgets('stopping preserves canonical reply until finalization by ID', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final manager = _DelayedManager();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatStreamManagerProvider.overrideWith((ref) => manager),
          conversationsProvider.overrideWith(
            (ref) => ConversationsNotifier(ref),
          ),
          activeConversationIdProvider.overrideWith((ref) => 'stop-conv'),
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ChatPage(messageHostBuilder: (_, __, ___) => const SizedBox()),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.enterText(find.byType(TextField), 'question');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatPage)),
    );
    container.read(streamingConversationsProvider.notifier).state = {
      'stop-conv',
    };
    container
        .read(streamingReasoningSectionsProvider('stop-conv').notifier)
        .state = [
      'reason',
      '',
    ];
    container
        .read(streamingToolCallRoundStartsProvider('stop-conv').notifier)
        .state = [
      0,
    ];
    container.read(streamingToolCallsProvider('stop-conv').notifier).state = [
      ToolCallData(
        id: 'tool',
        name: 'search',
        arguments: const {},
        status: ToolCallStatus.completed,
        result: 'found',
      ),
    ];
    container.read(streamingTextSectionsProvider('stop-conv').notifier).state =
        ['', 'partial'];
    container.read(streamingFullReplyProvider('stop-conv').notifier).state =
        'partial';
    await tester.pump();
    Map<String, dynamic> reply() => tester
        .widget<DshMessageView>(find.byType(DshMessageView))
        .messages
        .singleWhere((m) => m['id'] == manager.messageId);
    expect(reply()['streaming'], true);
    await tester.tap(find.byIcon(Icons.stop_circle_outlined));
    await tester.pump();
    expect(reply()['streaming'], false);
    expect(reply()['content'], 'partial');
    expect((reply()['blocks'] as List).map((b) => b['type']), [
      'reasoning',
      'tool_call',
      'reasoning',
      'text',
    ]);
    expect((reply()['blocks'] as List).last['text'], 'partial');
    // Persistence has not finished. Rebuilds must keep the frozen reply.
    await tester.pump(const Duration(seconds: 1));
    expect(reply()['content'], 'partial');
    final finalMessage = ChatMessage(
      id: manager.messageId,
      role: 'assistant',
      content: 'final',
      rawResponse: const {'done': true},
    );
    manager.result.complete(
      StreamResult(
        history: [...manager.sentHistory, finalMessage],
        assistantMessage: finalMessage,
        fullReply: 'final',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(reply()['content'], 'final');
    expect(reply()['actions'], contains('raw'));
    expect(
      tester
          .widget<DshMessageView>(find.byType(DshMessageView))
          .messages
          .where((m) => m['id'] == manager.messageId),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
