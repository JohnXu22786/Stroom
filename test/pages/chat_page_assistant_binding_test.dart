// Widget-level regression test for the send-path assistant resolution:
// the request for a conversation bound to assistant A must carry A's
// system prompt — regardless of the session-level selection (and even when
// the session selection is null), instead of silently going out with no
// prompt or with another assistant's prompt.
//
// This locks the glue between `_startStreaming`'s resolution and the
// adapter cache → service → protocol request path (the pure-resolution
// priority itself is unit-tested in test/assistant_send_resolution_test.dart).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/chat_stream_manager.dart';

/// Records every chatStream call (messages, system, tools, extraParams).
class _RecordingProvider extends BaseChatProvider {
  final List<Map<String, dynamic>> captures = [];

  @override
  String get name => 'RecordingProvider';

  @override
  List<String> get supportedModelIds => ['test-model'];

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
    String? system,
  }) async* {
    captures.add({
      'messages': List<Map<String, dynamic>>.from(messages),
      'system': system,
      'tools': tools == null ? null : List<Map<String, dynamic>>.from(tools),
      'extraParams': Map<String, dynamic>.from(extraParams ?? {}),
    });
    yield AIStreamEvent('回答');
  }

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
    String? system,
  }) async {
    return 'Mock response';
  }

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'test-model',
        'max_tokens': 4096,
        'temperature': 0.7,
      };
}

/// Pumps [ChatPage] with a conversation bound to [boundAssistantId], a
/// recording provider wired into the manager's adapter, and a stable
/// provider container. Returns the container so the test can set the
/// session selection before sending.
Future<ProviderContainer> _pumpChat(
  WidgetTester tester, {
  required String boundAssistantId,
  required _RecordingProvider provider,
}) async {
  SharedPreferences.setMockInitialValues({});
  late final ChatStreamManager manager;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatStreamManagerProvider.overrideWith((ref) {
          manager = ChatStreamManager(ref);
          return manager;
        }),
        conversationsProvider.overrideWith((ref) {
          final notifier = ConversationsNotifier(ref);
          notifier.state = [
            Conversation(
              id: 'test-conv',
              title: '',
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
              messages: [],
              assistantId: boundAssistantId,
            ),
          ];
          return notifier;
        }),
        assistantProvider.overrideWith((ref) {
          final notifier = AssistantsNotifier();
          notifier.state = [
            Assistant(
              id: 'assistant-a',
              name: '助手A',
              prompt: 'A的系统提示词：翻译成英文',
              emoji: '🤖',
            ),
            Assistant(
              id: 'assistant-b',
              name: '助手B',
              prompt: 'B的系统提示词：写诗',
              emoji: '📝',
            ),
          ];
          return notifier;
        }),
        activeConversationIdProvider.overrideWith((ref) => 'test-conv'),
        // Empty entries: the adapter stays unconfigured during page init;
        // the recording provider is injected afterwards via forceService.
        providerEntriesProvider.overrideWith((ref) {
          return ProviderEntriesNotifier();
        }),
      ],
      child: const MaterialApp(home: ChatPage()),
    ),
  );
  // Let _initialize + _loadConversationMessages complete.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ChatPage)),
  );
  container.read(chatStreamManagerProvider).adapter.forceService(
        ChatService(
          provider: provider,
          modelConfig: ModelConfig(
            name: 'Test Model',
            modelId: 'test-model',
            typeConfig: {'context': 4096},
          ),
        ),
      );
  return container;
}

/// Enters text into the composer and taps the (enabled) send button.
Future<void> _sendMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  final sendButtons = tester
      .widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send_rounded),
      )
      .where((b) => b.onPressed != null)
      .toList();
  expect(sendButtons, isNotEmpty, reason: '发送按钮应在输入文本后可用');
  await tester.tap(find.byWidget(sendButtons.first));
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Pumps until [condition] holds (or [maxPumps] frames elapse).
///
/// Must pump (not real-time await): the test runs in the FakeAsync zone,
/// where a bare `Future.delayed` never fires and would hang the test until
/// the framework timeout.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 150,
}) async {
  for (var i = 0; i < maxPumps && !condition(); i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue, reason: '条件在 ${maxPumps * 20}ms 内未满足');
}

/// Flushes chat UI internal timers so teardown does not fail.
Future<void> _flushPendingTimers(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  group('ChatPage send uses the conversation-bound assistant', () {
    testWidgets('会话选择为其它助手时，请求仍用对话绑定的助手提示词', (tester) async {
      final provider = _RecordingProvider();
      final container = await _pumpChat(
        tester,
        boundAssistantId: 'assistant-a',
        provider: provider,
      );
      // 会话选择被设为另一个助手（如经由全局搜索打开本对话前选过 B）。
      container.read(selectedAssistantIdProvider.notifier).state =
          'assistant-b';

      await _sendMessage(tester, '你好');
      await _pumpUntil(tester, () => provider.captures.isNotEmpty);

      final system = _systemOf(provider.captures.first);
      expect(system, isNotNull, reason: '请求必须携带 system 提示词');
      expect(system, contains('A的系统提示词'),
          reason: '对话绑定助手 A 的提示词必须生效，而不是会话选择的 B');
      expect(system, isNot(contains('B的系统提示词')));
      await _flushPendingTimers(tester);
    });

    testWidgets('会话选择为空时，请求仍用对话绑定的助手提示词（不再无提示词）', (tester) async {
      final provider = _RecordingProvider();
      await _pumpChat(
        tester,
        boundAssistantId: 'assistant-a',
        provider: provider,
      );
      // 不设置会话选择（默认 null）——旧代码此路径会发出无 system 的请求。

      await _sendMessage(tester, '你好');
      await _pumpUntil(tester, () => provider.captures.isNotEmpty);

      final system = _systemOf(provider.captures.first);
      expect(system, contains('A的系统提示词'),
          reason: '绑定助手即使会话选择为空也必须生效，不得退化为无提示词请求');
      await _flushPendingTimers(tester);
    });

    testWidgets('绑定助手已删除且会话选择为空 → 兜底默认助手提示词', (tester) async {
      final provider = _RecordingProvider();
      final container = await _pumpChat(
        tester,
        boundAssistantId: 'deleted-assistant',
        provider: provider,
      );
      // 会话选择为空；对话绑定的助手已被删除。
      expect(container.read(selectedAssistantIdProvider), isNull);

      await _sendMessage(tester, '你好');
      await _pumpUntil(tester, () => provider.captures.isNotEmpty);

      final system = _systemOf(provider.captures.first);
      expect(system, contains('A的系统提示词'),
          reason: '绑定失效且无会话选择时兜底列表第一个助手（默认助手）的提示词');
      await _flushPendingTimers(tester);
    });
  });
}

/// Returns the merged system content of the request's first system message,
/// or null when the request has no system message.
String? _systemOf(Map<String, dynamic> capture) {
  final messages = (capture['messages'] as List).cast<Map>();
  final sys = messages
      .where((m) => m['role'] == 'system')
      .map((m) => m['content']?.toString() ?? '')
      .join('\n');
  final topLevel = capture['system']?.toString() ?? '';
  return '$sys\n$topLevel'.trim().isEmpty ? null : '$sys\n$topLevel';
}
