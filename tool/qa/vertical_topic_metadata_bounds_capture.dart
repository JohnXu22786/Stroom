import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/widgets/topic_item.dart';

void main() {
  final dark = Uri.base.queryParameters['theme'] == 'dark';
  final textScale =
      double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  final topic = Conversation(
    id: 'synthetic-topic',
    title: 'Topic',
    updatedAt: DateTime(2026, 11, 22, 14, 35),
    messages: [
      ChatMessage(id: 'synthetic-message', role: 'user', content: 'Sample'),
    ],
  );

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              TopicItem(
                topic: topic,
                selectionMode: false,
                isSelected: false,
                isActive: false,
                onTap: () {},
                onDelete: () {},
                onPinToggle: () {},
                onRename: () {},
                onAutoRename: () {},
                onReadStateToggle: () {},
                onSelectionToggle: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
