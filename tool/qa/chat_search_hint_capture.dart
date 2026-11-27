import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

class _CaptureConversationsNotifier extends ConversationsNotifier {
  _CaptureConversationsNotifier(super.ref, Conversation conversation) {
    state = [conversation];
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final query = Uri.base.queryParameters;
  final localeTag = (query['locale'] ?? 'fr-FR').split('-');
  final locale = Locale.fromSubtags(
    languageCode: localeTag[0],
    countryCode: localeTag.length > 1 ? localeTag[1] : null,
  );
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;
  final dark = query['theme'] == 'dark';
  const conversationId = 'qa-chat-search-hint';
  final conversation = Conversation.fromMap({
    'id': conversationId,
    'title': 'Search hint preview',
    'createdAt': DateTime(2025, 1, 1).toIso8601String(),
    'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
    'messages': [
      ChatMessage(
        id: 'qa-chat-search-hint-message',
        role: 'assistant',
        content: 'A local conversation used to preview the search placeholder.',
        createdAt: DateTime(2025, 1, 1),
      ).toMap(),
    ],
    'isPinned': false,
    'sortOrder': 0,
  });
  runApp(
    ProviderScope(
      overrides: [
        conversationsProvider.overrideWith((ref) {
          return _CaptureConversationsNotifier(ref, conversation);
        }),
        activeConversationIdProvider.overrideWith((_) => conversationId),
        providerEntriesProvider.overrideWith((_) => ProviderEntriesNotifier()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
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
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: query['motion'] == 'off',
          ),
          child: child!,
        ),
        home: const Scaffold(body: ChatPage()),
      ),
    ),
  );
}
