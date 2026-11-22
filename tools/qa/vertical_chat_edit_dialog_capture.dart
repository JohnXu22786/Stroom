import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  final query = Uri.base.queryParameters;
  final locale = switch (query['locale']) {
    'en' => const Locale('en', 'US'),
    _ => const Locale('fr', 'FR'),
  };
  final scale = double.tryParse(query['scale'] ?? '') ?? 2;
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;

  SharedPreferences.setMockInitialValues({});
  runApp(
    ProviderScope(
      overrides: [
        streamingConversationsProvider.overrideWith((ref) => const {}),
        conversationsProvider.overrideWith((ref) {
          return ConversationsNotifier(ref);
        }),
        activeConversationIdProvider.overrideWith((ref) => 'local-fixture'),
        providerEntriesProvider.overrideWith((ref) {
          return ProviderEntriesNotifier();
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          brightness: brightness,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: ChatComposerWidget(
              onSend: (text, attachments) {},
              onStop: () {},
              onEnabledToolsChanged: (_) {},
              modelNames: const ['local-fixture'],
              selectedModelIndex: 0,
              onModelSelected: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}
