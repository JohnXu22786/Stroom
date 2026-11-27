import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/chat_conversation_state.dart';

Widget _app(
  ChatConversationState state, {
  VoidCallback? onRetry,
  double height = 600,
  double textScale = 1,
}) =>
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          height: height,
          child: ChatConversationStateView(state: state, onRetry: onRetry),
        ),
      ),
    );

void main() {
  testWidgets(
    'loading indicator remains square when the chat viewport is narrow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              height: 96,
              child: ChatConversationStateView(
                state: ChatConversationState.loading,
              ),
            ),
          ),
        ),
      );

      final indicatorSize = tester.getSize(
        find.byType(CircularProgressIndicator),
      );
      expect(indicatorSize.width, indicatorSize.height);
      expect(indicatorSize.width, lessThanOrEqualTo(40));
      final stateRect = tester.getRect(find.byType(ChatConversationStateView));
      final indicatorRect = tester.getRect(
        find.byType(CircularProgressIndicator),
      );
      final labelRect = tester.getRect(find.text('Loading conversation…'));
      expect(
        (indicatorRect.top + labelRect.bottom) / 2,
        closeTo(stateRect.center.dy, 1),
      );
    },
  );

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

  testWidgets(
    'all chat states remain reachable in a short 4x text viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pumpState(ChatConversationState state,
          {VoidCallback? onRetry}) async {
        await tester.pumpWidget(
          _app(
            state,
            onRetry: onRetry,
            height: 96,
            textScale: 4,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      }

      await pumpState(ChatConversationState.loading);
      final loadingLabel = find.text('Loading conversation…');
      await tester.ensureVisible(loadingLabel);
      expect(loadingLabel, findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpState(ChatConversationState.empty);
      final emptyLabel =
          find.text('Start the conversation by sending a message.');
      await tester.ensureVisible(emptyLabel);
      expect(emptyLabel, findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpState(ChatConversationState.noConversation);
      final noConversationLabel =
          find.text('Choose or create a conversation to start chatting.');
      await tester.ensureVisible(noConversationLabel);
      expect(noConversationLabel, findsOneWidget);
      expect(tester.takeException(), isNull);

      var retries = 0;
      await pumpState(
        ChatConversationState.loadFailed,
        onRetry: () => retries++,
      );
      final retryButton = find.text('Retry');
      await tester.ensureVisible(retryButton);
      expect(find.text('Could not load this conversation.'), findsOneWidget);
      await tester.tap(retryButton);
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
