import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/dialogs/chat_account_override_dialog.dart';

void main() {
  testWidgets(
    'localizes choices and exposes the selected account to semantics',
    (tester) async {
      String? result = 'account-a';
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showChatAccountOverrideDialog(
                    context: context,
                    accounts: const [
                      ChatAccountOverrideChoice(
                        id: 'account-a',
                        displayName: 'Compte principal avec un nom très long',
                        connectorType: 'OpenAI',
                      ),
                      ChatAccountOverrideChoice(
                        id: 'account-b',
                        displayName: 'Compte secondaire',
                        connectorType: 'Anthropic',
                      ),
                    ],
                    selectedAccountId: 'account-a',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Compte pour cette requête'), findsOneWidget);
      expect(
        find.text('Utiliser le routage du groupe de modèles'),
        findsOneWidget,
      );
      expect(
        find.text('Compte principal avec un nom très long'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.text('Compte principal avec un nom très long'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.text('Compte secondaire'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );

      await tester.tap(find.text('Utiliser le routage du groupe de modèles'));
      await tester.pumpAndSettle();
      expect(result, '');
    },
  );

  testWidgets('fits a narrow large-text dark dialog and selects an account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showChatAccountOverrideDialog(
                  context: context,
                  accounts: const [
                    ChatAccountOverrideChoice(
                      id: 'account-a',
                      displayName: 'Account A',
                      connectorType: 'OpenAI',
                    ),
                  ],
                  selectedAccountId: null,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSemantics(find.text('按模型组策略路由'))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    await tester.tap(find.text('Account A'));
    await tester.pumpAndSettle();
    expect(result, 'account-a');
    expect(tester.takeException(), isNull);
  });
}
