import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        streamingConversationsProvider.overrideWith((ref) => const {}),
        conversationsProvider.overrideWith((ref) => ConversationsNotifier(ref)),
        activeConversationIdProvider.overrideWith((ref) => 'local-fixture'),
        providerEntriesProvider
            .overrideWith((ref) => ProviderEntriesNotifier()),
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
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(
                child: Center(
                  child: Text('Conversation locale de démonstration'),
                ),
              ),
              ChatComposerWidget(
                onSend: _ignoreSend,
                onStop: _ignoreStop,
                onEnabledToolsChanged: _ignoreTools,
                modelNames: const ['local-fixture-model'],
                selectedModelIndex: 0,
                onModelSelected: _ignoreModel,
                conversationId: 'local-fixture',
                editingMessageId: 'fixture-message',
                editingMessageText: 'Exemple de message local',
                showEditWarningOnEntry: true,
                editWarningArmCount: 1,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _ignoreSend(String text, List<Attachment> attachments) {}
void _ignoreStop() {}
void _ignoreTools(Set<String> tools) {}
void _ignoreModel(int index) {}
