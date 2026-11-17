import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

class _FailingGroupRemovalNotifier extends ProviderEntriesNotifier {
  _FailingGroupRemovalNotifier() {
    state = ProviderEntriesState(
      entries: [ProviderEntry(id: 'mcp', type: 'mcp', name: 'MCP')],
      mcpGroups: [
        ...builtinMcpProviderGroups,
        const McpProviderGroup(id: 'custom_group', name: 'Custom group'),
      ],
    );
  }

  @override
  Future<void> removeMcpGroup(String id) async {
    throw const ProviderEntriesRollbackException();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MCP group deletion shows a message when persistence fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => _FailingGroupRemovalNotifier(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ProviderConfigPage(entryId: 'mcp'),
        ),
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProviderConfigPage)),
    )!;

    await tester.tap(find.byTooltip(l10n.providerDeleteTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.providerDeleteGroup).last);
    await tester.pumpAndSettle();

    expect(find.text(l10n.taskFlowUiSaveFailed), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
