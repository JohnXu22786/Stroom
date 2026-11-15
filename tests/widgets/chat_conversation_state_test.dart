import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/chat_conversation_state.dart';

Widget _app(ChatConversationState state, {VoidCallback? onRetry}) =>
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: ChatConversationStateView(state: state, onRetry: onRetry),
      ),
    );

void main() {
  testWidgets(
    'loading, empty, no-conversation and failed states are distinct',
    (tester) async {
      await tester.pumpWidget(_app(ChatConversationState.loading));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading conversation…'), findsOneWidget);

      await tester.pumpWidget(_app(ChatConversationState.empty));
      expect(
        find.text('Start the conversation by sending a message.'),
        findsOneWidget,
      );

      await tester.pumpWidget(_app(ChatConversationState.noConversation));
      expect(
        find.text('Choose or create a conversation to start chatting.'),
        findsOneWidget,
      );

      var retries = 0;
      await tester.pumpWidget(
        _app(ChatConversationState.loadFailed, onRetry: () => retries++),
      );
      expect(find.text('Could not load this conversation.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    },
  );
}
