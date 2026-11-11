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
      expect(find.textContaining('keep this conversation'), findsOneWidget);
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

      expect(find.text('临时'), findsOneWidget);
      expect(find.textContaining(':'), findsOneWidget);
      final semantics = tester.getSemantics(
        find.byType(TemporaryCountdownCapsule),
      );
      expect(semantics.label, contains('临时对话'));
      expect(semantics.label, contains('即将过期'));
      expect(tester.takeException(), isNull);

      final label = tester.widget<Text>(find.text('临时'));
      expect(
        label.style?.color,
        Theme.of(tester.element(find.byType(MaterialApp))).colorScheme.error,
      );
    },
  );
}
