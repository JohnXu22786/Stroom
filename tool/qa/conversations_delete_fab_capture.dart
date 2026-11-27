import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';

void main() {
  final query = Uri.base.queryParameters;
  final locale = query['locale'] == 'fr'
      ? const Locale('fr')
      : const Locale('en', 'US');
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;

  runApp(
    ProviderScope(
      overrides: [
        conversationsProvider.overrideWith((ref) {
          final notifier = ConversationsNotifier(ref);
          notifier.state = [
            for (var index = 0; index < 123; index++)
              Conversation(
                id: 'delete-fab-capture-$index',
                title: 'Conversation $index',
                messages: [],
              ),
          ];
          return notifier;
        }),
        activeConversationIdProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const ConversationsPage(),
      ),
    ),
  );
}
