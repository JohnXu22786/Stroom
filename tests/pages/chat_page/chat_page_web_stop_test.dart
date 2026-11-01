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
  final results = <Completer<StreamResult>>[];
  final messageIds = <String>[];
  final sentHistories = <List<ChatMessage>>[];
  bool _finalizationPending = false;

  @override
  bool isStreamingFor(String convId) => _finalizationPending;

  @override
  void cancel([String? convId]) {
    _finalizationPending = true;
  }

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
    messageIds.add(streamingMsgId!);
    sentHistories.add(List<ChatMessage>.from(history));
    final result = Completer<StreamResult>();
    results.add(result);
    return result.future;
  }

  void finish(StreamResult result) {
    _finalizationPending = false;
    results.first.complete(result);
  }
}

void main() {
  testWidgets(
      'stopping preserves the reply and delays follow-up until finalization',
      (tester) async {
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
    final stoppedMessageId = manager.messageIds.first;
    List<Map<String, dynamic>> messages() =>
        tester.widget<DshMessageView>(find.byType(DshMessageView)).messages;
    Map<String, dynamic> reply() =>
        messages().singleWhere((m) => m['id'] == stoppedMessageId);
    expect(reply()['streaming'], true);
    await tester.tap(find.byIcon(Icons.stop_circle_outlined));
    await tester.pump();
    expect(
      container.read(streamingConversationsProvider),
      isNot(contains('stop-conv')),
    );
    expect(reply()['streaming'], false);
    expect(reply()['content'], 'partial');
    expect((reply()['blocks'] as List).map((b) => b['type']), [
      'reasoning',
      'tool_call',
      'reasoning',
      'text',
    ]);
    expect((reply()['blocks'] as List).last['text'], 'partial');
    expect(reply()['actions'], isNot(contains('retry')),
        reason: '重试操作也必须等待取消结果持久化完成');
    expect(reply()['actions'], isNot(contains('delete')),
        reason: 'manager 保存取消结果期间，不能删除即将写入的部分回复');
    final userMessage = messages().singleWhere((m) => m['role'] == 'user');
    expect(userMessage['actions'], isNot(contains('edit')),
        reason: '停止收尾期间不能开始会截断历史的编辑');
    // Persistence has not finished. Rebuilds must keep the frozen reply.
    await tester.pump(const Duration(seconds: 1));
    expect(reply()['content'], 'partial');

    // Stopping clears the stream marker before the existing send Future has
    // finished. A send attempt during that interval must remain in the input
    // instead of being silently discarded by the pending-send guard.
    await tester.enterText(find.byType(TextField), 'follow-up');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(manager.sentHistories, hasLength(1));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'follow-up',
    );

    final finalMessage = ChatMessage(
      id: stoppedMessageId,
      role: 'assistant',
      content: 'final',
      reasoningContent: 'reason\n',
      reasoningSections: ['reason', ''],
      textSections: ['', 'partial'],
      toolCalls: [
        ToolCallData(
          id: 'tool',
          name: 'search',
          arguments: const {},
          status: ToolCallStatus.completed,
          result: 'found',
        ),
      ],
      toolCallRoundStarts: [0],
      rawResponse: const {'done': true},
    );
    manager.finish(
      StreamResult(
        history: [...manager.sentHistories.first, finalMessage],
        assistantMessage: finalMessage,
        fullReply: 'final',
      ),
    );
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(reply()['content'], 'final');
    expect(reply()['actions'], contains('raw'));
    expect(reply()['actions'], contains('retry'));
    expect(reply()['actions'], contains('delete'),
        reason: '取消结果保存完成后应重新提供删除操作');
    final finalizedUserMessage =
        messages().singleWhere((m) => m['role'] == 'user');
    expect(finalizedUserMessage['actions'], contains('edit'));
    await tester.tap(find.byIcon(Icons.send_rounded));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(manager.sentHistories, hasLength(2));
    final followUpHistory = manager.sentHistories.last.singleWhere(
      (message) => message.id == stoppedMessageId,
    );
    expect(followUpHistory.reasoningContent, 'reason\n');
    expect(
      tester
          .widget<DshMessageView>(find.byType(DshMessageView))
          .messages
          .where((m) => m['id'] == stoppedMessageId),
      hasLength(1),
    );
    manager.results.last.complete(
      StreamResult(
        history: [
          ...manager.sentHistories.last,
          ChatMessage(
            id: manager.messageIds.last,
            role: 'assistant',
            content: 'follow-up reply',
          ),
        ],
        assistantMessage: ChatMessage(
          id: manager.messageIds.last,
          role: 'assistant',
          content: 'follow-up reply',
        ),
        fullReply: 'follow-up reply',
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
