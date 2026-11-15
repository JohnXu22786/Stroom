import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/temporary_conversation_dialog.dart';
import 'package:stroom/widgets/temporary_countdown_capsule.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets(
    'temporary mode explanation confirms or cancels without mutation',
    (tester) async {
      var enabled = false;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                if (await showTemporaryConversationEnableDialog(context)) {
                  enabled = true;
                }
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('one hour'), findsOneWidget);
      expect(find.textContaining('restarts the timer'), findsOneWidget);
      expect(
        find.textContaining('Turn off temporary mode to keep it'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(enabled, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enable temporary mode').last);
      await tester.pumpAndSettle();
      expect(enabled, isTrue);
    },
  );

  testWidgets(
    'countdown label is localized, warns near expiry, and fits narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 280,
            child: Row(
              children: [
                TemporaryCountdownCapsule(
                  expiresAt: DateTime.now().add(const Duration(minutes: 4)),
                ),
                const Expanded(child: Text('Conversation title')),
              ],
            ),
          ),
          locale: const Locale('zh', 'CN'),
        ),
      );
      await tester.pump();

      expect(find.text('临时'), findsNothing);
      expect(find.textContaining(':'), findsOneWidget);
      final semantics = tester.getSemantics(
        find.byType(TemporaryCountdownCapsule),
      );
      expect(semantics.label, contains('临时对话'));
      expect(semantics.label, contains('即将过期'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('header countdown briefly glows on activation and reset', (
    tester,
  ) async {
    var expiresAt = DateTime.now().add(const Duration(minutes: 60));
    var animationKey = 0;
    void Function(VoidCallback)? rebuild;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return TemporaryCountdownCapsule(
              expiresAt: expiresAt,
              animationKey: animationKey,
              animateOnMount: true,
              animateOnChange: true,
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    Container capsuleContainer() => tester.widget<Container>(
      find.descendant(
        of: find.byType(TemporaryCountdownCapsule),
        matching: find.byType(Container),
      ),
    );

    expect(capsuleContainer().decoration, isA<BoxDecoration>());
    expect(
      (capsuleContainer().decoration as BoxDecoration).boxShadow,
      isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect((capsuleContainer().decoration as BoxDecoration).boxShadow, isNull);

    expiresAt = expiresAt.add(const Duration(hours: 1));
    animationKey++;
    rebuild!(() {});
    await tester.pump();
    expect(
      (capsuleContainer().decoration as BoxDecoration).boxShadow,
      isNotNull,
    );
  });

  testWidgets('existing temporary conversation does not glow on header mount',
      (tester) async {
    await tester.pumpWidget(
      _app(
        TemporaryCountdownCapsule(
          expiresAt: DateTime.now().add(const Duration(minutes: 20)),
          animationKey: 0,
          animateOnChange: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    final capsule = tester.widget<Container>(
      find.descendant(
        of: find.byType(TemporaryCountdownCapsule),
        matching: find.byType(Container),
      ),
    );
    expect((capsule.decoration as BoxDecoration).boxShadow, isNull);
  });
}
