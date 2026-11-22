import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/widgets/modal_bottom_sheet_constraints.dart';
import 'package:stroom/widgets/search_panel.dart';

void main() => runApp(const _CaptureApp());

class _CaptureApp extends StatefulWidget {
  const _CaptureApp();

  @override
  State<_CaptureApp> createState() => _CaptureAppState();
}

class _CaptureAppState extends State<_CaptureApp> {
  bool _sheetOpened = false;
  late final Conversation _conversation = Conversation(
    id: 'capture-search-result',
    title: 'Demo',
    updatedAt: DateTime(2026, 11, 22, 12, 34),
    messages: [
      ChatMessage(role: 'user', content: 'needle'),
      ChatMessage(role: 'assistant', content: 'reply'),
    ],
  );

  void _openSearchPanel(BuildContext context) {
    if (_sheetOpened) return;
    _sheetOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        constraints: modalBottomSheetWidthConstraints(context),
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => SearchPanel(
          conversations: [_conversation],
          onConversationSelected: (_) {},
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = Uri.base.queryParameters;
    final localeName = query['locale'] ?? 'en-US';
    final parts = localeName.replaceAll('_', '-').split('-');
    final locale = Locale(parts.first, parts.length > 1 ? parts[1] : null);
    final textScale = double.tryParse(query['scale'] ?? '1') ?? 1;
    final brightness = query['theme'] == 'dark'
        ? Brightness.dark
        : Brightness.light;

    return MaterialApp(
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          _openSearchPanel(context);
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    );
  }
}
