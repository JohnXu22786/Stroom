import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/mcp.dart';
import 'package:stroom/pages/provider_config_tool_dialogs.dart';
import 'package:stroom/pages/provider_config_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/http_tool_service.dart';
import 'package:stroom/services/todo_tool_service.dart';
import 'package:stroom/services/web_search_service.dart';

/// Regression test for the MCP config page card style:
///
/// BUG: `_McpConfigCard` split cards into two color schemes — built-in
/// (vendor) cards used a `primaryContainer` tint while user-added cards used
/// a neutral surface tone, mixing styles on the same page. The LLM provider
/// page (and all other provider pages) show uniform neutral cards.
///
/// FIX: every MCP card uses the same neutral theme-adaptive background and
/// simplified icon/text treatment, regardless of vendor or transport.
void main() {
  dynamic schemaContract(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          if (entry.key != 'description')
            entry.key as String: schemaContract(entry.value),
      };
    }
    if (value is List) return value.map(schemaContract).toList();
    return value;
  }

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
                  typeConfig: {'transport': 'stdio', 'command': 'npx'},
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
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
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

  testWidgets('all MCP config cards share one unified style (light)', (
    tester,
  ) async {
    await pumpPage(tester, Brightness.light);
    final cs =
        Theme.of(tester.element(find.byType(ProviderConfigPage))).colorScheme;

    final expectedBg = cs.surfaceContainerLow;
    for (var i = 0; i < 3; i++) {
      final d = await cardDecoration(tester, i);
      expect(
        d.color,
        expectedBg,
        reason: 'vendor and user-added cards must use the same background '
            '(matching the LLM provider page) — no primaryContainer tint',
      );
      expect(
        d.border,
        isNull,
        reason: 'MCP rows use a simple borderless settings style',
      );
    }
  });

  testWidgets('all MCP config cards share one unified style (dark)', (
    tester,
  ) async {
    await pumpPage(tester, Brightness.dark);
    final cs =
        Theme.of(tester.element(find.byType(ProviderConfigPage))).colorScheme;

    final expectedBg = cs.surfaceContainerHigh;
    for (var i = 0; i < 3; i++) {
      final d = await cardDecoration(tester, i);
      expect(
        d.color,
        expectedBg,
        reason: 'dark mode must use the same adaptive background for every '
            'card, no vendor tint',
      );
      expect(
        d.border,
        isNull,
        reason: 'dark MCP rows also use a simple borderless settings style',
      );
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
      final groupSwitch = find.descendant(
        of: searchGroupCard,
        matching: find.byType(Switch),
      );
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
    },
  );

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

  testWidgets('editing an MCP config preserves its group and saved test', (
    tester,
  ) async {
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
    )
        .read(providerEntriesProvider)
        .entries
        .single
        .configs
        .singleWhere((item) => item.providerName == 'My Files');
    expect(updated.id, configId);
    expect(updated.groupId, builtinMcpServicesGroupId);
    expect(updated.models[0].typeConfig['connectivityTest'], savedTest);
  });

  testWidgets('MCP master switch renders and toggles the entry enabled flag', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpPage(tester, Brightness.light);

    // 总开关卡片渲染在配置列表顶部，状态徽标和开关对应 entry.enabled。
    final masterCard = find
        .ancestor(of: find.text('MCP 服务器'), matching: find.byType(Container))
        .first;
    final switchFinder = find.descendant(
      of: masterCard,
      matching: find.byType(Switch),
    );
    expect(switchFinder, findsOneWidget);
    expect(
      find.descendant(of: masterCard, matching: find.text('已启用')),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    // 点击后写入 enabled=false，provider 状态同步更新。
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final container = tester.element(switchFinder);
    final entries =
        ProviderScope.containerOf(container).read(providerEntriesProvider);
    final mcpEntry = entries.entries.firstWhere((e) => e.type == 'mcp');
    expect(mcpEntry.enabled, isFalse);
  });

  testWidgets(
    'catalog separates integrations and opens the HTTP search editor',
    (tester) async {
      await pumpPage(tester, Brightness.light);

      final serverCard = find.byKey(const ValueKey('config_test_mcp_0'));
      final httpSearchCard = find.byKey(const ValueKey('config_test_mcp_1'));
      final builtinSearchCard = find.byKey(
        const ValueKey('builtin_tool_web_search'),
      );
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
    },
  );

  testWidgets('built-in Web Search settings entry remains read-only', (
    tester,
  ) async {
    await pumpPage(tester, Brightness.light, entryId: kBuiltinWebSearchEntryId);

    expect(find.text(kBuiltinWebSearchEntryName), findsOneWidget);
    expect(find.text('内置工具'), findsOneWidget);
    expect(
      find.text('内置网络搜索支持 Google、Bing 和百度，模型调用名为 web_search。'),
      findsOneWidget,
    );
    expect(find.text('添加'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('服务与工具'), findsNothing);
    expect(find.byKey(const ValueKey('builtin_tool_web_search')), findsNothing);
  });

  testWidgets('clearing HTTP search API key removes stale credential headers', (
    tester,
  ) async {
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
    expect(find.byType(HttpToolConfigDialog), findsOneWidget);
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
    expect(updatedTypeConfig['headers'], {'X-Subscription-Token': ''});
    expect(
      McpServerConfig.extractApiKeyFromTypeConfig(updatedTypeConfig),
      isEmpty,
    );
  });

  testWidgets('updating HTTP search API key preserves unrelated headers', (
    tester,
  ) async {
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
    expect(updatedTypeConfig['headers'], {
      'X-Subscription-Token': 'replacement-key',
      'X-Custom-Optional': '',
      'X-Custom-Metadata': 'old-explicit-key',
    });
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

    expect(find.text('请输入有效的 HTTP 或 HTTPS 地址。'), findsOneWidget);
    expect(find.text('接入类型：HTTP 搜索'), findsOneWidget);
    expect(
      state.entries.single.configs[1].host,
      'http://localhost:8080',
      reason: 'invalid URLs are not saved to the provider config',
    );
  });

  testWidgets('built-in tool details are localized without changing schemas', (
    tester,
  ) async {
    Future<void> showTool(Locale locale, ToolDefinition definition) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      BuiltinToolDetailsDialog(definition: definition),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    for (final locale in AppLocalizations.supportedLocales) {
      for (final definition in [
        TodoToolService.toolDefinitions.single,
        WebSearchService.toolDefinitions.single,
        ...HttpToolService.toolDefinitions,
      ]) {
        final schemaBefore = jsonEncode(definition.parameters);
        final definitionDescriptionBefore = definition.description;
        await showTool(locale, definition);

        final description = tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data ?? '')
            .join('\n');
        final renderedParameters =
            tester.widget<SelectableText>(find.byType(SelectableText)).data!;
        final parameters =
            jsonDecode(renderedParameters) as Map<String, dynamic>;

        expect(parameters['type'], 'object');
        final properties = parameters['properties'] as Map<String, dynamic>;
        expect(
          properties,
          contains(definition.name == 'todowrite' ? 'todos' : 'query'),
        );
        if (locale.languageCode == 'en') {
          expect(description, isNot(contains('通过网络搜索')));
          expect(description, isNot(contains('创建、读取并管理')));
          if (definition.name == 'todowrite') {
            expect(
              description,
              contains('Create, read, and manage a to-do list.'),
            );
          } else if (definition.name == 'web_search') {
            expect(
              description,
              contains('Search the web for current information.'),
            );
          }
          expect(
            renderedParameters,
            contains(
              definition.name == 'todowrite'
                  ? 'Complete replacement of the to-do list'
                  : 'Search terms',
            ),
          );
          if (HttpToolService.toolDefinitions.contains(definition)) {
            final expectedDescription = switch (definition.name) {
              'brave_web_search' =>
                'Search the web with the Brave Search API. Requires an API key.',
              'bocha_web_search' =>
                'Search the web with the Bocha AI Search API. Requires an API key.',
              'querit_search' =>
                'Search the web with Querit Search. Requires an API key.',
              'searxng_search' =>
                'A privacy-focused, self-hosted metasearch engine that aggregates search sources. Requires an instance URL.',
              _ => fail('Unexpected HTTP tool: ${definition.name}'),
            };
            expect(find.text(expectedDescription), findsOneWidget);
            expect(properties['query']['description'], 'Search terms.');
            expect(
              properties['count']['description'],
              definition.name == 'brave_web_search'
                  ? 'Number of results to return (maximum 20).'
                  : 'Number of results to return.',
            );
          }
        } else if (locale.languageCode == 'zh') {
          if (definition.name == 'todowrite') {
            expect(description, contains('创建、读取并管理待办事项列表。'));
          } else if (definition.name == 'web_search') {
            expect(description, contains('通过网络搜索获取实时信息。'));
          }
          expect(
            renderedParameters,
            contains(definition.name == 'todowrite' ? '待办事项列表（全量替换）' : '搜索关键词'),
          );
          if (HttpToolService.toolDefinitions.contains(definition)) {
            final expectedDescription = switch (definition.name) {
              'brave_web_search' => '使用 Brave Search API 搜索网络。需要配置 API Key。',
              'bocha_web_search' => '使用博查 AI Search API 搜索网络。需要配置 API Key。',
              'querit_search' => '使用 Querit Search 搜索网络。需要配置 API Key。',
              'searxng_search' => '注重隐私保护的自托管元搜索引擎，可聚合多种搜索源。需要配置实例 URL。',
              _ => fail('Unexpected HTTP tool: ${definition.name}'),
            };
            expect(find.text(expectedDescription), findsOneWidget);
            expect(properties['query']['description'], '搜索关键词。');
            expect(
              properties['count']['description'],
              definition.name == 'brave_web_search'
                  ? '返回结果数量（最大 20）。'
                  : '返回结果数量。',
            );
          }
        } else {
          // Spanish and Japanese use generated app strings for HTTP tools;
          // Todo and built-in web search descriptions still fall back to their
          // schema text until dedicated translations are added.
          final strings = await AppLocalizations.delegate.load(locale);
          if (definition.name == 'todowrite' ||
              definition.name == 'web_search') {
            expect(description, contains(definitionDescriptionBefore));
            expect(
              renderedParameters,
              contains(
                definition.name == 'todowrite'
                    ? 'Complete replacement of the to-do list'
                    : 'Search terms',
              ),
            );
          }
          if (HttpToolService.toolDefinitions.contains(definition)) {
            final expectedDescription = switch (definition.name) {
              'brave_web_search' => strings.httpToolBraveDescription,
              'bocha_web_search' => strings.httpToolBochaDescription,
              'querit_search' => strings.httpToolQueritDescription,
              'searxng_search' => strings.httpToolSearxngDescription,
              _ => fail('Unexpected HTTP tool: ${definition.name}'),
            };
            expect(find.text(expectedDescription), findsOneWidget);
            expect(
              properties['query']['description'],
              strings.httpToolSearchQueryDescription,
            );
            expect(
              properties['count']['description'],
              definition.name == 'brave_web_search'
                  ? strings.httpToolSearchCountMax20Description
                  : strings.httpToolSearchCountDescription,
            );
          }
        }

        expect(jsonEncode(definition.parameters), schemaBefore);
        expect(definition.description, definitionDescriptionBefore);
        expect(
          schemaContract(parameters),
          schemaContract(definition.parameters),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
