import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

class _ProviderBadgesNotifier extends ProviderEntriesNotifier {
  _ProviderBadgesNotifier() {
    state = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'builtin_mcp',
          type: 'mcp',
          name: 'MCP',
          configs: [
            ProviderConfigItem(
              id: 'vendor_service',
              providerName: 'A provider title that must remain fully available',
              models: [
                ModelConfig(
                  name: 'Vendor service',
                  modelId: 'vendor-service',
                  typeConfig: {
                    'isVendor': true,
                    'transport': 'sse',
                    'url': 'https://example.test',
                  },
                ),
              ],
            ),
            ProviderConfigItem(
              id: 'custom_service',
              providerName: 'Second MCP server',
              models: [
                ModelConfig(
                  name: 'Custom service',
                  modelId: 'custom-service',
                  typeConfig: {
                    'transport': 'sse',
                    'url': 'https://example.test'
                  },
                ),
              ],
            ),
          ],
        ),
        ProviderEntry(
          id: 'ordinary_llm',
          type: 'llm',
          name: 'Ordinary provider',
          configs: [
            ProviderConfigItem(
              id: 'ordinary_provider',
              providerName: 'Ordinary provider',
              host: 'https://example.test',
            ),
          ],
        ),
      ],
      mcpGroups: builtinMcpProviderGroups,
    );
  }

  @override
  Future<void> update(String id, ProviderEntry updated,
      {bool requirePersistence = true}) async {
    state = ProviderEntriesState(
      entries: [
        for (final entry in state.entries) entry.id == id ? updated : entry
      ],
      mcpGroups: state.mcpGroups,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'provider card badges reflow without clipping or starving the title',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => _ProviderBadgesNotifier(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('de', 'DE'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const ProviderConfigPage(entryId: 'builtin_mcp'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('config_builtin_mcp_0')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProviderConfigPage)),
      )!;
      const providerTitle = 'A provider title that must remain fully available';
      expect(find.text(providerTitle), findsOneWidget);
      expect(find.text(l10n.providerBuiltinBadge), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Reorder at the narrow viewport to cover the original interaction path.
      final card = find.byKey(const ValueKey('config_builtin_mcp_0'));
      final secondCard = find.byKey(const ValueKey('config_builtin_mcp_1'));
      final dragHandle = find.descendant(
        of: card,
        matching: find.byIcon(Icons.drag_handle),
      );
      final start = tester.getCenter(dragHandle);
      final end = tester.getCenter(secondCard);
      final drag = await tester.startGesture(start);
      final delta = (end - start) / 12;
      for (var step = 0; step < 12; step++) {
        await drag.moveBy(delta);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await drag.up();
      await tester.pumpAndSettle();

      final state = ProviderScope.containerOf(
        tester.element(find.byType(ProviderConfigPage)),
      ).read(providerEntriesProvider);
      expect(
        state.entries.first.configs.map((config) => config.id),
        ['custom_service', 'vendor_service'],
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(420, 640);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('config_builtin_mcp_0')))
            .height,
        lessThan(100),
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(400, 640);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('config_builtin_mcp_0')))
            .height,
        lessThan(100),
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();
      final customCard = find.byKey(const ValueKey('config_builtin_mcp_0'));
      final title = find.descendant(
        of: customCard,
        matching: find.text('Second MCP server'),
      );
      final toggle = find.descendant(
        of: customCard,
        matching: find.byWidgetPredicate((widget) => widget is Switch),
      );
      expect(
        tester.getCenter(toggle.first).dy,
        greaterThan(tester.getCenter(title).dy + 30),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
      'ordinary provider cards retain the inline layout at standard width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider
              .overrideWith((ref) => _ProviderBadgesNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('de', 'DE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const ProviderConfigPage(entryId: 'ordinary_llm'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const ordinaryTitle = 'Ordinary provider';
    expect(find.byKey(const ValueKey('config_ordinary_llm_0')), findsOneWidget);
    expect(find.text(ordinaryTitle), findsWidgets);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('config_ordinary_llm_0')))
          .height,
      lessThan(80),
    );
    expect(tester.takeException(), isNull);
  });
}
