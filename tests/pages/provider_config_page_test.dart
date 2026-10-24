import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/provider_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  testWidgets(
    'keeps legacy LLM configs reachable when secure migration is unavailable',
    (tester) async {
      final entry = ProviderEntry(
        id: 'legacy-llm',
        type: 'llm',
        name: 'LLM供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'Legacy OpenAI',
            host: 'https://legacy.example.test/v1',
            key: 'legacy-key',
            models: [
              ModelConfig(name: 'GPT-4o', modelId: 'gpt-4o'),
            ],
          ),
        ],
      );
      final state = ProviderEntriesState(
        entries: [entry],
        llmCredentialMigrationUnavailable: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith((ref) {
              final notifier = ProviderEntriesNotifier();
              notifier.state = state;
              return notifier;
            }),
          ],
          child: MaterialApp(home: ProviderConfigPage(entryId: entry.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('config_legacy-llm_0')), findsOneWidget);
      expect(find.text('Legacy OpenAI'), findsWidgets);
      expect(find.text('LLM 账号与模型组'), findsNothing);
    },
  );

  testWidgets(
    'keeps legacy LLM configs reachable when the account catalog is unavailable',
    (tester) async {
      final entry = ProviderEntry(
        id: 'legacy-llm-catalog-failure',
        type: 'llm',
        name: 'LLM供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'Legacy OpenAI',
            host: 'https://legacy.example.test/v1',
            key: 'legacy-key',
            models: [
              ModelConfig(name: 'GPT-4o', modelId: 'gpt-4o'),
            ],
          ),
        ],
      );
      final state = ProviderEntriesState(
        entries: [entry],
        llmModelGroupCatalogUnavailable: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith((ref) {
              final notifier = ProviderEntriesNotifier();
              notifier.state = state;
              return notifier;
            }),
          ],
          child: MaterialApp(home: ProviderConfigPage(entryId: entry.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('config_legacy-llm-catalog-failure_0')),
        findsOneWidget,
      );
      expect(find.text('Legacy OpenAI'), findsWidgets);
      expect(find.text('LLM 账号与模型组'), findsNothing);
    },
  );
}
