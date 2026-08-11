import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

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

    // The enabled set must include the discovered MCP tool, not just the
    // built-in tools. 内置工具数可能随内置工具增删变化（如 todowrite 与
    // todoread 合并），因此以当前注册的内置工具数 + 1（MCP 占位）为基准，
    // 而不是硬编码具体数字。
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatPage)));
    final enabled = container.read(enabledToolNamesProvider);
    expect(enabled, contains('exa_mcp'),
        reason: 'MCP tool discovered during page init must be auto-enabled '
            '(badge/list must show the full count, not built-in-only)');
    final builtinCount = ChatService.getRegisteredToolDefinitions().length;
    expect(enabled.length, greaterThan(builtinCount),
        reason: 'the tool badge count must include MCP tools '
            '(built-in-only: $builtinCount)');

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
      'master switch off keeps saved MCP tool prefs intact on send '
      '(no silent erasure of conversation preferences)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final conv = Conversation(
      id: 'test-conv-id',
      title: '话题',
      enabledMcpToolNames: {'exa_mcp', 'web_search'},
      hasExplicitEnabledMcpTools: true,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        conversationsProvider.overrideWith((ref) {
          final notifier = ConversationsNotifier(ref);
          notifier.state = [conv];
          return notifier;
        }),
        activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
        providerEntriesProvider.overrideWith((ref) {
          final notifier = ProviderEntriesNotifier();
          // MCP 总开关关闭：adapter 不发布 MCP 占位工具。
          notifier.state = ProviderEntriesState(
            entries: [
              ProviderEntry(
                id: 'test_mcp',
                type: 'mcp',
                name: 'MCP供应商',
                configs: const [],
                enabled: false,
              ),
            ],
          );
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

    // 显式保存过的 MCP 工具名保留在运行时启用集里：总开关关闭只影响
    // 展示/发送层过滤，不抹掉对话偏好。
    final enabled = container.read(enabledToolNamesProvider);
    expect(enabled, contains('exa_mcp'),
        reason: '总开关关闭时，显式保存的 MCP 工具名必须保留在启用集中');

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
        reason: '发送消息不得把被总开关隐藏的 MCP 工具从对话偏好中抹掉');
    expect(saved.hasExplicitEnabledMcpTools, isTrue);
  });
}
