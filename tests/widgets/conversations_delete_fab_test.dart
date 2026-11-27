import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/widgets/constrained_text.dart';

// Functional suite mapping and CI execution group: chat-ai-ui.
Widget _app({
  required Locale locale,
  required List<Conversation> conversations,
  TextScaler textScaler = TextScaler.noScaling,
  ThemeMode themeMode = ThemeMode.light,
  Size? mediaSize,
}) {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        notifier.state = conversations;
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => null),
    ],
    child: MaterialApp(
      locale: locale,
      themeMode: themeMode,
      darkTheme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: mediaSize,
          textScaler: textScaler,
        ),
        child: child!,
      ),
      home: const ConversationsPage(),
    ),
  );
}

List<Conversation> _conversations(int count) => [
      for (var index = 0; index < count; index++)
        Conversation(
          id: 'conversation-$index',
          title: 'Conversation $index',
          messages: [],
        ),
    ];

Future<void> _selectEveryConversation(WidgetTester tester, int count) async {
  await tester.tap(find.byIcon(Icons.checklist));
  await tester.pump();
  for (var index = 0; index < count; index++) {
    final title = find.text('Conversation $index');
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'French 3x batch-delete label stays in the viewport and keeps action visible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      late StateSetter setTextScale;
      var textScale = 1.0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setTextScale = setState;
            return _app(
              locale: const Locale('fr'),
              conversations: _conversations(123),
              textScaler: TextScaler.linear(textScale),
            );
          },
        ),
      );
      await _selectEveryConversation(tester, 123);
      setTextScale(() => textScale = 3);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(ConversationsPage)))
            .scale(14),
        42,
      );
      final fab = find.byType(FloatingActionButton);
      final fabRect = tester.getRect(fab);
      final labelRect = tester.getRect(
        find.ancestor(
          of: find.text('Supprimer 123'),
          matching: find.byType(ConstrainedText),
        ),
      );
      expect(fabRect.left, greaterThanOrEqualTo(0));
      expect(fabRect.right, lessThanOrEqualTo(320));
      expect(fabRect.bottom, lessThanOrEqualTo(640));
      expect(labelRect.left, greaterThanOrEqualTo(fabRect.left));
      expect(labelRect.right, lessThanOrEqualTo(fabRect.right));
      expect(find.bySemanticsLabel('Supprimer 123'), findsOneWidget);
      expect(
        find.descendant(of: fab, matching: find.byIcon(Icons.delete)),
        findsOneWidget,
      );
      expect(find.text('Supprimer 123'), findsOneWidget);
    },
  );

  testWidgets('fitting batch-delete label retains the extended FAB layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _app(locale: const Locale('en'), conversations: _conversations(1)),
    );
    await _selectEveryConversation(tester, 1);

    final fab = find.byType(FloatingActionButton);
    expect(tester.getRect(fab).right, lessThanOrEqualTo(800));
    final label = find.ancestor(
      of: find.text('Delete 1'),
      matching: find.byType(ConstrainedText),
    );
    expect(tester.getRect(label).width, lessThan(220));
    await tester.pump(const Duration(milliseconds: 500));
    final initialLabelX = tester.getTopLeft(label).dx;
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(label).dx, closeTo(initialLabelX, 0.01));
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(of: fab, matching: find.byIcon(Icons.delete)),
      findsOneWidget,
    );
    expect(find.text('Delete 1'), findsOneWidget);
  });

  testWidgets('dark theme retains destructive FAB colors', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        conversations: _conversations(1),
        themeMode: ThemeMode.dark,
      ),
    );
    await _selectEveryConversation(tester, 1);

    final fabFinder = find.byType(FloatingActionButton);
    final fab = tester.widget<FloatingActionButton>(fabFinder);
    final colorScheme = Theme.of(tester.element(fabFinder)).colorScheme;
    expect(fab.backgroundColor, colorScheme.error);
    expect(fab.foregroundColor, colorScheme.onError);
  });

  testWidgets('label width budget is nonnegative below 100dp', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        conversations: _conversations(1),
        // Keep the real scaffold 320dp wide while isolating the slot budget.
        mediaSize: const Size(80, 640),
      ),
    );
    await _selectEveryConversation(tester, 1);

    final labelBoxes = tester.widgetList<ConstrainedBox>(
      find.ancestor(
        of: find.text('Delete 1'),
        matching: find.byType(ConstrainedBox),
      ),
    );
    final zeroWidthConstraint = labelBoxes.firstWhere(
      (box) => box.constraints.maxWidth == 0,
    );
    expect(zeroWidthConstraint.constraints.isNormalized, isTrue);
    expect(tester.takeException(), isNull);
  });
}
