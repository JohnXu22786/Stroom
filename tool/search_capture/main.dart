// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/message_search_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  const query = 'needle';
  final longContent =
      '${List.filled(18, '這是一段真實的中文搜索結果上下文，應自然換行並可垂直閱讀。').join()} '
      '$query '
      '${List.filled(18, '更多搜索結果內容應保留高亮、完整語義與原始文字排列。').join()}';
  final conversations = [
    Conversation(
      id: 'search-clipped',
      title: '01 · 完整上下文',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      messages: [
        ChatMessage(
          id: 'search-clipped-message',
          role: 'user',
          content: longContent,
          createdAt: DateTime(2025, 1, 1),
        ),
      ],
    ),
    Conversation(
      id: 'search-fitting',
      title: '02 · 簡短內容',
      createdAt: DateTime(2025, 1, 2),
      updatedAt: DateTime(2025, 1, 2),
      messages: [
        ChatMessage(
          id: 'search-fitting-message',
          role: 'user',
          content: '簡短的 $query 結果',
          createdAt: DateTime(2025, 1, 2),
        ),
      ],
    ),
  ];

  runApp(
    ProviderScope(
      overrides: [
        conversationsProvider.overrideWith((ref) {
          final notifier = ConversationsNotifier(ref);
          notifier.state = conversations;
          return notifier;
        }),
        providerEntriesProvider
            .overrideWith((ref) => ProviderEntriesNotifier()),
      ],
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData.light(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: false),
          child: TickerMode(enabled: true, child: child!),
        ),
        home: const MessageSearchPage(),
      ),
    ),
  );
}
