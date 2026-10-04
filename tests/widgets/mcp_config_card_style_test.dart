import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/mcp.dart';
import 'package:stroom/pages/provider_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

/// Regression test for the MCP config page card style:
///
/// BUG: `_McpConfigCard` split cards into two color schemes — built-in
/// (vendor) cards used a `primaryContainer` tint while user-added cards used
/// a neutral surface tone, mixing styles on the same page. The LLM provider
/// page (and all other provider pages) show uniform neutral cards.
///
/// FIX: every MCP card uses the same theme-adaptive background and a soft
/// outline border, regardless of vendor/transport, so light and dark mode
/// look consistent with the rest of the settings UI.
void main() {
  ProviderEntriesState mixedState() {
    return ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'test_mcp',
          type: 'mcp',
          name: 'MCP供应商',
          configs: [
            // Built-in vendor SSE
            ProviderConfigItem(
              providerName: 'Exa',
              host: 'https://mcp.exa.ai/mcp',
              key: '',
              models: [
                ModelConfig(
                  name: 'Exa',
                  modelId: 'sse',
                  typeConfig: {
                    'transport': 'sse',
                    'url': 'https://mcp.exa.ai/mcp',
                    'isVendor': true,
                    'description': 'Exa 网络搜索',
                  },
                ),
              ],
            ),
            // Built-in HTTP tool
            ProviderConfigItem(
              providerName: 'Brave Search',
              host: 'https://api.search.brave.com',
              key: '',
              models: [
                ModelConfig(
                  name: 'Brave Search',
                  modelId: 'http',
                  typeConfig: {
                    'transport': 'http',
                    'isHttpTool': true,
                    'isVendor': true,
                  },
                ),
              ],
            ),
            // User-added stdio (no vendor flag)
            ProviderConfigItem(
              providerName: 'My Files',
              host: '',
              key: '',
              models: [
                ModelConfig(
                  name: 'My Files',
                  modelId: 'stdio',
                  typeConfig: {
                    'transport': 'stdio',
                    'command': 'npx',
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpPage(
    WidgetTester tester,
    Brightness brightness, {
    ProviderEntriesState? state,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith((ref) {
            final notifier = ProviderEntriesNotifier();
            notifier.state = state ?? mixedState();
            return notifier;
          }),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: const ProviderConfigPage(entryId: 'test_mcp'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// The card-level Container for config [index]. The page emits stable
  /// keys (`ValueKey('config_${entryId}_$i')`) on each _McpConfigCard; the
  /// card's outer Container (the one with the rounded BoxDecoration) is its
  /// first descendant Container.
  BoxDecoration cardDecoration(WidgetTester tester, int index) {
    final card = find.byKey(ValueKey('config_test_mcp_$index'));
    expect(card, findsOneWidget);
    final container = tester.widget<Container>(
      find.descendant(of: card, matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  /// The icon-box Containers (borderRadius 10) of all cards.
  List<Color?> iconBoxColors(WidgetTester tester) {
    final colors = <Color?>[];
    for (var i = 0; i < 3; i++) {
      final card = find.byKey(ValueKey('config_test_mcp_$i'));
      final boxes = find
          .descendant(of: card, matching: find.byType(Container))
          .evaluate()
          .map((e) => e.widget as Container)
          .where((c) {
        final d = c.decoration;
        return d is BoxDecoration &&
            d.borderRadius == BorderRadius.circular(10);
      }).toList();
      expect(boxes, hasLength(1), reason: 'each card has exactly one icon box');
      colors.add((boxes.first.decoration as BoxDecoration).color);
    }
    return colors;
  }

  testWidgets('all MCP config cards share one unified style (light)',
      (tester) async {
    await pumpPage(tester, Brightness.light);
    final cs = Theme.of(
      tester.element(find.byType(ProviderConfigPage)),
    ).colorScheme;

    final expectedBg = cs.surfaceContainerLow;
    final expectedBorder = cs.outlineVariant.withValues(alpha: 0.5);
    for (var i = 0; i < 3; i++) {
      final d = cardDecoration(tester, i);
      expect(d.color, expectedBg,
          reason: 'vendor and user-added cards must use the same background '
              '(matching the LLM provider page) — no primaryContainer tint');
      final border = d.border as Border;
      expect(border.top.color, expectedBorder,
          reason: 'all cards must use the same soft outline border color');
      expect(border.top.width, 0.5,
          reason: 'all cards must use the same border width');
    }

    // Icon boxes: all use the same primaryContainer tint regardless of
    // vendor/transport.
    final expectedIconBox = cs.primaryContainer.withValues(alpha: 0.3);
    for (final color in iconBoxColors(tester)) {
      expect(color, expectedIconBox,
          reason: 'icon boxes must use the same tint for every card');
    }
  });

  testWidgets('all MCP config cards share one unified style (dark)',
      (tester) async {
    await pumpPage(tester, Brightness.dark);
    final cs = Theme.of(
      tester.element(find.byType(ProviderConfigPage)),
    ).colorScheme;

    final expectedBg = cs.surfaceContainerHigh;
    final expectedBorder = cs.outlineVariant.withValues(alpha: 0.5);
    for (var i = 0; i < 3; i++) {
      final d = cardDecoration(tester, i);
      expect(d.color, expectedBg,
          reason: 'dark mode must use the same adaptive background for every '
              'card, no vendor tint');
      final border = d.border as Border;
      expect(border.top.color, expectedBorder,
          reason: 'all cards must use the same soft outline border color');
      expect(border.top.width, 0.5,
          reason: 'all cards must use the same border width');
    }

    final expectedIconBox = cs.primaryContainer.withValues(alpha: 0.3);
    for (final color in iconBoxColors(tester)) {
      expect(color, expectedIconBox,
          reason: 'icon boxes must use the same tint for every card');
    }
  });

  testWidgets('MCP master switch renders and toggles the entry enabled flag',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpPage(tester, Brightness.light);

    // 总开关卡片渲染在配置列表顶部，值为 entry.enabled（默认 true）
    final switchFinder = find.widgetWithText(SwitchListTile, 'MCP 总开关');
    expect(switchFinder, findsOneWidget);
    final switchTile = tester.widget<SwitchListTile>(switchFinder);
    expect(switchTile.value, isTrue);

    // 点击后写入 enabled=false，provider 状态同步更新
    await tester.tap(find.descendant(
      of: switchFinder,
      matching: find.byType(Switch),
    ));
    await tester.pump();

    final container = tester.element(switchFinder);
    final entries = ProviderScope.containerOf(container).read(
      providerEntriesProvider,
    );
    final mcpEntry = entries.entries.firstWhere((e) => e.type == 'mcp');
    expect(mcpEntry.enabled, isFalse);
  });

  testWidgets('catalog separates integrations and opens the HTTP search editor',
      (tester) async {
    await pumpPage(tester, Brightness.light);

    final serverCard = find.byKey(const ValueKey('config_test_mcp_0'));
    final httpSearchCard = find.byKey(const ValueKey('config_test_mcp_1'));
    final builtinSearchCard =
        find.byKey(const ValueKey('builtin_tool_web_search'));
    expect(serverCard, findsOneWidget);
    expect(httpSearchCard, findsOneWidget);
    expect(
      find.descendant(of: serverCard, matching: find.text('MCP · SSE')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: httpSearchCard, matching: find.text('HTTP 搜索')),
      findsOneWidget,
    );
    await tester.tap(httpSearchCard);
    await tester.pumpAndSettle();

    expect(find.text('接入类型：HTTP 搜索'), findsOneWidget);
    expect(find.text('工具接口：brave_web_search'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      fields.first.readOnly,
      isTrue,
      reason: 'the Brave endpoint remains fixed to its provider URL',
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      builtinSearchCard,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(builtinSearchCard, findsOneWidget);
    expect(
      find.descendant(of: builtinSearchCard, matching: find.text('内置工具')),
      findsOneWidget,
    );
  });

  testWidgets('clearing HTTP search API key removes stale credential headers',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = mixedState();
    final braveConfig = state.entries.single.configs[1];
    braveConfig.models[0].typeConfig = {
      'transport': 'http',
      'isHttpTool': true,
      'isVendor': true,
      'apiKey': 'new-explicit-key',
      'headers': {'X-Subscription-Token': 'stale-header-key'},
    };
    await pumpPage(tester, Brightness.light, state: state);

    await tester.tap(find.byKey(const ValueKey('config_test_mcp_1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProviderConfigPage)),
    );
    final updatedTypeConfig = container
        .read(providerEntriesProvider)
        .entries
        .single
        .configs[1]
        .models[0]
        .typeConfig;
    expect(updatedTypeConfig, isNot(contains('apiKey')));
    expect(
      updatedTypeConfig['headers'],
      {'X-Subscription-Token': ''},
    );
    expect(
      McpServerConfig.extractApiKeyFromTypeConfig(updatedTypeConfig),
      isEmpty,
    );
  });

  testWidgets('updating HTTP search API key preserves unrelated headers',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = mixedState();
    final braveConfig = state.entries.single.configs[1];
    braveConfig.models[0].typeConfig = {
      'transport': 'http',
      'isHttpTool': true,
      'isVendor': true,
      'apiKey': 'old-explicit-key',
      'headers': {
        'X-Subscription-Token': 'stale-header-key',
        'X-Custom-Optional': '',
        'X-Custom-Metadata': 'old-explicit-key',
      },
    };
    await pumpPage(tester, Brightness.light, state: state);

    await tester.tap(find.byKey(const ValueKey('config_test_mcp_1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'replacement-key');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final updatedTypeConfig = ProviderScope.containerOf(
      tester.element(find.byType(ProviderConfigPage)),
    )
        .read(providerEntriesProvider)
        .entries
        .single
        .configs[1]
        .models[0]
        .typeConfig;
    expect(
      updatedTypeConfig['headers'],
      {
        'X-Subscription-Token': 'replacement-key',
        'X-Custom-Optional': '',
        'X-Custom-Metadata': 'old-explicit-key',
      },
    );
  });

  testWidgets('Searxng editor rejects URLs without a host', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = mixedState();
    final searxngConfig = state.entries.single.configs[1];
    searxngConfig.providerName = 'Searxng';
    searxngConfig.host = 'http://localhost:8080';
    searxngConfig.models[0].typeConfig = {
      'transport': 'http',
      'isHttpTool': true,
      'isVendor': true,
      'url': 'http://localhost:8080',
      'headers': <String, String>{},
    };
    await pumpPage(tester, Brightness.light, state: state);

    await tester.tap(find.byKey(const ValueKey('config_test_mcp_1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'http:///search');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('请输入有效的 HTTP 或 HTTPS 地址'), findsOneWidget);
    expect(find.text('接入类型：HTTP 搜索'), findsOneWidget);
    expect(
      state.entries.single.configs[1].host,
      'http://localhost:8080',
      reason: 'invalid URLs are not saved to the provider config',
    );
  });
}
