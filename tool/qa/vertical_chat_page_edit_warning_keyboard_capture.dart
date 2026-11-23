import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final conversation = Conversation(
    id: 'local-fixture',
    title: 'Démo locale',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    messages: List.generate(
      3,
      (index) => ChatMessage(
        id: index.isEven ? 'user_$index' : 'assistant_$index',
        role: index.isEven ? 'user' : 'assistant',
        content: 'Message local $index pour l’aperçu.',
        createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
      ),
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        conversationsProvider.overrideWith((ref) {
          final notifier = ConversationsNotifier(ref);
          notifier.state = [conversation];
          return notifier;
        }),
        activeConversationIdProvider.overrideWith((ref) => 'local-fixture'),
        providerEntriesProvider.overrideWith((ref) {
          final notifier = ProviderEntriesNotifier();
          notifier.state = ProviderEntriesState(
            entries: [
              ProviderEntry(
                id: 'fixture_llm',
                type: 'llm',
                name: 'Fixture provider',
                configs: [
                  ProviderConfigItem(
                    providerName: 'Fixture',
                    host: 'https://example.invalid/v1',
                    key: 'fixture-key',
                    models: [
                      ModelConfig(
                        name: 'Fixture model',
                        modelId: 'fixture-model',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
          return notifier;
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr', 'FR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.5),
            viewInsets: const EdgeInsets.only(bottom: 260),
          ),
          child: child!,
        ),
        home: const Scaffold(body: ChatPage()),
      ),
    ),
  );
}
