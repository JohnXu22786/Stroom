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
  const conversationId = 'qa-chat-error-heading';
  final textScale =
      double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1.0;
  final conversation = Conversation.fromMap({
    'id': conversationId,
    'title': 'Error heading capture',
    'createdAt': DateTime(2025, 1, 1).toIso8601String(),
    'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
    'messages': [
      ChatMessage(
        id: 'qa-chat-error',
        role: 'assistant',
        content: 'Request failed in the local UI preview.',
        isError: true,
        rawResponse: const {'statusCode': 502},
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
        locale: const Locale('de', 'DE'),
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
            textScaler: TextScaler.linear(textScale),
            disableAnimations: false,
          ),
          child: child!,
        ),
        home: const Scaffold(body: ChatPage()),
      ),
    ),
  );
}
