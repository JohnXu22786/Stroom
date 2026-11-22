import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _ChatErrorFixtureConversations extends ConversationsNotifier {
  _ChatErrorFixtureConversations(super.ref, List<Conversation> conversations) {
    state = conversations;
  }
}

void main() {
  testWidgets('error heading stays within the icon row on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval = const Duration(
        milliseconds: 500,
      );
    });

    final conversation = Conversation.fromMap({
      'id': 'error-heading',
      'title': 'Error heading fixture',
      'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
      'messages': [
        ChatMessage(
          id: 'error',
          role: 'assistant',
          content: 'Example error details',
          isError: true,
          rawResponse: const {'statusCode': 500},
        ).toMap(),
      ],
      'isPinned': false,
      'sortOrder': 0,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationsProvider.overrideWith(
            (ref) => _ChatErrorFixtureConversations(ref, [conversation]),
          ),
          activeConversationIdProvider.overrideWith((ref) => 'error-heading'),
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1),
              disableAnimations: false,
            ),
            child: child!,
          ),
          home: const Scaffold(body: ChatPage()),
        ),
      ),
    );
    await tester.pump();

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('Nachricht konnte nicht gesendet werden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
