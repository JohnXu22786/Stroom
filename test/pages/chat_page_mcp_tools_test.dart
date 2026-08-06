import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/pages/chat_page.dart';
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
/// discovery and re-resolves the enabled tool set after discovery completes
/// (also in the provider-change listener), so newly discovered MCP tools are
/// auto-enabled immediately.
void main() {
  /// Provider entries with a single vendor SSE MCP config (Exa) whose server
  /// is unreachable — discovery fails fast in the test environment and the
  /// vendor placeholder tool ('exa_mcp') is created.
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

    // Let _initialize + MCP discovery (fails fast on unreachable URL in the
    // test environment) complete.
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
}
