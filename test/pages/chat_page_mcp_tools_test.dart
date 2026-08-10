import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

/// Regression test for the "sometimes 7 tools, sometimes 12 tools" bug:
///
/// BUG: `_initialize` snapshotted the provider entries state BEFORE MCP
/// discovery and resolved the enabled tool set in `_loadConversationMessages`
/// BEFORE `initializeMcpServers` ran. As a result, MCP tools discovered
/// asynchronously were missing from the enabled set on the first entry
/// (badge/list showed 7 built-in tools) and only appeared after a later
/// reload, making the count nondeterministic per page entry.
///
/// FIX: `_initialize` re-reads the fresh entries state right before MCP
/// initialization and re-resolves the enabled tool set afterwards (also in
/// the provider-change listener), so MCP placeholder tools are auto-enabled
/// immediately. MCP servers are lazy: placeholders are published without
/// any network connection (connections happen only when a tool is called).
void main() {
  /// Provider entries with a single vendor SSE MCP config (Exa) whose server
  /// is unreachable — MCP servers are lazy (no connection at page entry),
  /// so the vendor placeholder tool ('exa_mcp') is published synchronously.
  ProviderEntriesState vendorMcpState() {
    return ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'test_mcp',
          type: 'mcp',
          name: 'MCP供应商',
          configs: [
            ProviderConfigItem(
              providerName: 'Exa',
              host: 'https://mcp.example.com/mcp',
              key: '',
              models: [
                ModelConfig(
                  name: 'Exa',
                  modelId: 'sse',
                  typeConfig: {
                    'transport': 'sse',
                    'url': 'https://mcp.example.com/mcp',
                    'isVendor': true,
                    'description': 'Exa MCP search tool',
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  testWidgets(
      'MCP tools discovered on page entry are auto-enabled and visible '
      '(not stuck at built-in-only count)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        conversationsProvider.overrideWith((ref) => ConversationsNotifier(ref)),
        activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
        providerEntriesProvider.overrideWith((ref) {
          final notifier = ProviderEntriesNotifier();
          // Preset the loaded state (bypasses the async load()).
          notifier.state = vendorMcpState();
          return notifier;
        }),
      ],
      child: const MaterialApp(home: ChatPage()),
    ));

    // Let _initialize + MCP initialization (synchronous placeholder
    // publication, no network) complete.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The enabled set must include the discovered MCP tool, not just the 7
    // built-in tools.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatPage)));
    final enabled = container.read(enabledToolNamesProvider);
    expect(enabled, contains('exa_mcp'),
        reason: 'MCP tool discovered during page init must be auto-enabled '
            '(badge/list must show the full count, not built-in-only)');
    expect(enabled.length, greaterThan(7),
        reason: 'the tool badge count must include MCP tools');

    // The tools panel must list the MCP tool alongside the built-ins.
    // The panel is a lazy ListView — scroll it to reveal the MCP tool
    // (it sorts after the built-in tools).
    await tester.tap(find.text('工具'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('exa_mcp'), findsOneWidget,
        reason: 'the tools panel must list the discovered MCP tool');
  });

  testWidgets(
      'display switch off keeps saved MCP tool prefs intact on send '
      '(no silent erasure of conversation preferences)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final assistant = Assistant(
      id: 'assistant-1',
      name: '助手',
      prompt: '你好',
      mcpToolsVisible: false,
    );
    final conv = Conversation(
      id: 'test-conv-id',
      title: '话题',
      assistantId: assistant.id,
      enabledMcpToolNames: {'exa_mcp', 'web_search'},
      hasExplicitEnabledMcpTools: true,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        assistantProvider.overrideWith((ref) {
          final notifier = AssistantsNotifier();
          notifier.state = [assistant];
          return notifier;
        }),
        conversationsProvider.overrideWith((ref) {
          final notifier = ConversationsNotifier(ref);
          notifier.state = [conv];
          return notifier;
        }),
        activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
        providerEntriesProvider.overrideWith((ref) {
          final notifier = ProviderEntriesNotifier();
          // Preset the loaded state (bypasses the async load()).
          notifier.state = vendorMcpState();
          return notifier;
        }),
      ],
      child: const MaterialApp(home: ChatPage()),
    ));

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatPage)));

    // 显式保存过的 MCP 工具名保留在运行时启用集里：运行时集不是持久化
    // 来源，隐藏的工具由显示/发送层过滤（徽标、请求），不抹掉偏好。
    final enabled = container.read(enabledToolNamesProvider);
    expect(enabled, contains('exa_mcp'),
        reason: '显示开关关闭时，显式保存的 MCP 工具名必须保留在启用集中');

    // 发送一条消息：_saveEnabledToolsToConversation 在请求之前执行，
    // 等值比较应跳过写入（请求本身会因未配置 LLM 供应商而失败，不影响
    // 本断言）。
    await tester.enterText(find.byType(TextField).first, '你好');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final convs = container.read(conversationsProvider);
    final saved = convs.firstWhere((c) => c.id == 'test-conv-id');
    expect(saved.enabledMcpToolNames, contains('exa_mcp'),
        reason: '发送消息不得把被显示开关隐藏的 MCP 工具从对话偏好中抹掉');
    expect(saved.hasExplicitEnabledMcpTools, isTrue);
  });
}
