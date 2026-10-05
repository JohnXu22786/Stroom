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
    String entryId = 'test_mcp',
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
          home: ProviderConfigPage(entryId: entryId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Scrolls to config [index], which may be lazily built in a later group.
  Future<void> scrollToCard(
    WidgetTester tester,
    int index, {
    required double delta,
  }) async {
    final card = find.byKey(ValueKey('config_test_mcp_$index'));
    await tester.scrollUntilVisible(
      card,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
  }

  Future<void> revealHttpSearchCard(WidgetTester tester) async {
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  }

  /// The card-level Container for config [index]. The page emits stable
  /// keys (`ValueKey('config_${entryId}_$i')`) on each _McpConfigCard; the
  /// card's outer Container (the one with the rounded BoxDecoration) is its
  /// first descendant Container.
  Future<BoxDecoration> cardDecoration(WidgetTester tester, int index) async {
    await scrollToCard(tester, index, delta: 200);
    final card = find.byKey(ValueKey('config_test_mcp_$index'));
    expect(card, findsOneWidget);
    final container = tester.widget<Container>(
      find.descendant(of: card, matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  /// The icon-box Containers (borderRadius 10) of all cards.
  Future<List<Color?>> iconBoxColors(WidgetTester tester) async {
    final colors = <Color?>[];
    // The preceding style checks leave the scroll view at the last card.
    for (var i = 2; i >= 0; i--) {
      await scrollToCard(tester, i, delta: -200);
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
      final d = await cardDecoration(tester, i);
      expect(d.color, expectedBg,
          reason: 'vendor and user-added cards must use the same background '
              '(matching the LLM provider page) — no primaryContainer tint');
      final border = d.border as Border;
      expect(border.top.color, expectedBorder,
          reason: 'all cards must use the same soft outline border color');
      expect(border.top.width, 0.5,
          reason: 'all cards must use the same border width');
    }

    // MCP icon boxes use the same theme-aware primary container color across
    // vendor and transport types.
    final expectedIconBox = cs.primaryContainer;
    for (final color in await iconBoxColors(tester)) {
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
      final d = await cardDecoration(tester, i);
      expect(d.color, expectedBg,
          reason: 'dark mode must use the same adaptive background for every '
              'card, no vendor tint');
      final border = d.border as Border;
      expect(border.top.color, expectedBorder,
          reason: 'all cards must use the same soft outline border color');
      expect(border.top.width, 0.5,
          reason: 'all cards must use the same border width');
    }

    final expectedIconBox = cs.primaryContainer;
    for (final color in await iconBoxColors(tester)) {
      expect(color, expectedIconBox,
          reason: 'icon boxes must use the same tint for every card');
    }
  });

  testWidgets(
      'Search group toggle leaves the MCP entry and other group enabled',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpPage(tester, Brightness.light);

    final searchGroupTitle = find.text('搜索').first;
    final searchGroupCard = find
        .ancestor(of: searchGroupTitle, matching: find.byType(Container))
        .first;
    final groupSwitch =
        find.descendant(of: searchGroupCard, matching: find.byType(Switch));
    expect(groupSwitch, findsOneWidget);

    await tester.tap(groupSwitch);
    await tester.pumpAndSettle();

    final state = ProviderScope.containerOf(
      tester.element(find.byType(ProviderConfigPage)),
    ).read(providerEntriesProvider);
    expect(
      state.mcpGroups
          .firstWhere((group) => group.id == builtinSearchMcpGroupId)
          .enabled,
      isFalse,
    );
    expect(
      state.mcpGroups
          .firstWhere((group) => group.id == builtinMcpServicesGroupId)
          .enabled,
      isTrue,
    );
    expect(state.entries.single.enabled, isTrue);
  });

  testWidgets('built-in MCP group accepts newly added content', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpPage(tester, Brightness.light);

    // The group header is in a later sliver and is not built until its first
    // config enters the viewport.
    await scrollToCard(tester, 2, delta: 200);
    final otherGroupTitle = find.text('其他 MCP 服务').first;
    final groupCard = find
        .ancestor(of: otherGroupTitle, matching: find.byType(Container))
        .first;
    final addButton = find.descendant(
      of: groupCard,
      matching: find.byTooltip('添加内容'),
    );
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Local Docs');
    await tester.enterText(fields.at(1), 'http://localhost:3000/sse');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final state = ProviderScope.containerOf(
      tester.element(find.byType(ProviderConfigPage)),
    ).read(providerEntriesProvider);
    final added = state.entries.single.configs.singleWhere(
      (config) => config.providerName == 'Local Docs',
    );
    expect(added.groupId, builtinMcpServicesGroupId);
  });

  testWidgets('editing an MCP config preserves its group and saved test',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = mixedState();
    final config = state.entries.single.configs[2];
    const savedTest = {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
      },
    };
    config.groupId = builtinMcpServicesGroupId;
    config.models[0].typeConfig['connectivityTest'] = savedTest;
    final configId = config.id;
    await pumpPage(tester, Brightness.light, state: state);

    final configCard = find.byKey(const ValueKey('config_test_mcp_2'));
    await tester.scrollUntilVisible(
      configCard,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(configCard);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final updated = ProviderScope.containerOf(
      tester.element(find.byType(ProviderConfigPage)),
    ).read(providerEntriesProvider).entries.single.configs.singleWhere(
          (item) => item.providerName == 'My Files',
        );
    expect(updated.id, configId);
    expect(updated.groupId, builtinMcpServicesGroupId);
    expect(updated.models[0].typeConfig['connectivityTest'], savedTest);
  });

  testWidgets('MCP master switch renders and toggles the entry enabled flag',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpPage(tester, Brightness.light);

    // 总开关卡片渲染在配置列表顶部，状态徽标和开关对应 entry.enabled。
    final masterCard = find
        .ancestor(
          of: find.text('MCP 服务器'),
          matching: find.byType(Container),
        )
        .first;
    final switchFinder = find.descendant(
      of: masterCard,
      matching: find.byType(Switch),
    );
    expect(switchFinder, findsOneWidget);
    expect(find.descendant(of: masterCard, matching: find.text('已启用')),
        findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    // 点击后写入 enabled=false，provider 状态同步更新。
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

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
    await revealHttpSearchCard(tester);
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

  testWidgets('built-in Web Search settings entry remains read-only',
      (tester) async {
    await pumpPage(
      tester,
      Brightness.light,
      entryId: kBuiltinWebSearchEntryId,
    );

    expect(find.text(kBuiltinWebSearchEntryName), findsOneWidget);
    expect(find.text('内置工具'), findsOneWidget);
    expect(
      find.text('内置网络搜索支持 Google、Bing 和百度，模型调用名为 web_search。'),
      findsOneWidget,
    );
    expect(find.text('添加'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('服务与工具'), findsNothing);
    expect(
      find.byKey(const ValueKey('builtin_tool_web_search')),
      findsNothing,
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

    await revealHttpSearchCard(tester);
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

    await revealHttpSearchCard(tester);
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

    await revealHttpSearchCard(tester);
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
