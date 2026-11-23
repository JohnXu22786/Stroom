import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/temporary_conversation_dialog.dart';
import 'package:stroom/widgets/temporary_countdown_capsule.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  TextScaler? textScaler,
}) {
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
      builder: (context, appChild) {
        Widget content = appChild!;
        if (textScaler != null) {
          content = MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: content,
          );
        }
        return content;
      },
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
      final fittingEnableLabel = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText && widget.data == 'Enable temporary mode',
      );
      expect(fittingEnableLabel, findsOneWidget);
      expect(
        find.descendant(
          of: fittingEnableLabel,
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
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
    'large localized confirmation keeps its explanation scrollable and actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      bool? result;

      Future<void> openDialog(BuildContext context) async {
        result = await showTemporaryConversationEnableDialog(context);
      }

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => openDialog(context),
              child: const Text('open'),
            ),
          ),
          locale: const Locale('de', 'DE'),
          textScaler: const TextScaler.linear(2.5),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      final l10n = AppLocalizations.of(tester.element(dialog))!;
      final explanation = l10n.conversationTemporaryExplanation;
      final explanationFinder = find.text(explanation);
      expect(explanationFinder, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.byType(Scrollable)),
        findsOneWidget,
      );
      expect(tester.getSemantics(explanationFinder).label, explanation);
      final enableLabel = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data == l10n.conversationEnableTemporary,
      );
      expect(enableLabel, findsOneWidget);
      final enableConstrainedText = tester.widget<ConstrainedText>(enableLabel);
      expect(enableConstrainedText.maxLines, 1);
      expect(enableConstrainedText.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSemantics(enableLabel).label,
        l10n.conversationEnableTemporary,
      );
      expect(
        find.descendant(
          of: enableLabel,
          matching: find.byType(AnimatedBuilder),
        ),
        findsOneWidget,
      );
      final enableText = find.text(l10n.conversationEnableTemporary).last;
      final initialEnableTextX = tester.getTopLeft(enableText).dx;
      await tester.pump(const Duration(milliseconds: 999));
      expect(
          tester.getTopLeft(enableText).dx, closeTo(initialEnableTextX, 0.01));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getTopLeft(enableText).dx, lessThan(initialEnableTextX));
      final cancelLabel = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText && widget.data == l10n.actionCancel,
      );
      expect(cancelLabel, findsOneWidget);
      expect(tester.getSemantics(cancelLabel).label, l10n.actionCancel);

      tester.view.physicalSize = const Size(320, 420);
      await tester.pumpAndSettle();
      final explanationTop = tester.getTopLeft(explanationFinder).dy;
      await tester.drag(
        find.descendant(of: dialog, matching: find.byType(Scrollable)),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(explanationFinder).dy, lessThan(explanationTop));
      final cancelAction = find.ancestor(
        of: find.text(l10n.actionCancel),
        matching: find.byType(TextButton),
      );
      final enableActionButton = find.ancestor(
        of: find.text(l10n.conversationEnableTemporary).last,
        matching: find.byType(FilledButton),
      );
      expect(
        tester.getRect(cancelAction).bottom,
        lessThanOrEqualTo(tester.getRect(enableActionButton).top),
      );
      expect(tester.getBottomRight(cancelAction).dy, lessThanOrEqualTo(420));
      expect(tester.getBottomRight(cancelAction).dx, lessThanOrEqualTo(320));
      expect(
        tester.getBottomRight(enableActionButton).dx,
        lessThanOrEqualTo(320),
      );
      await tester.tap(find.text(l10n.actionCancel));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(enableActionButton).dy,
        lessThanOrEqualTo(420),
      );
      await tester.tap(enableActionButton);
      await tester.pumpAndSettle();
      expect(result, isTrue);
      semantics.dispose();
      expect(tester.takeException(), isNull);
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
