import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/dialogs/chat_account_override_dialog.dart';

void main() {
  testWidgets(
    'account override is localized and exposes the selected choice in a narrow large-text dialog',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ChatAccountOverrideDialog(
                    selectedAccountId: 'account-2',
                    accounts: [
                      ChatAccountOverrideChoice(
                        id: 'account-1',
                        name: 'First account',
                        connectorType: 'first-provider',
                      ),
                      ChatAccountOverrideChoice(
                        id: 'account-2',
                        name: 'Second account with a long display name',
                        connectorType: 'second-provider',
                      ),
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Account for this request'), findsOneWidget);
      expect(find.text('Use model group routing'), findsOneWidget);
      expect(
        find.text('Second account with a long display name'),
        findsOneWidget,
      );
      final selected = tester.widget<ListTile>(
        find.byWidgetPredicate(
          (widget) => widget is ListTile && widget.selected,
        ),
      );
      expect(selected.trailing, isA<Icon>());
      expect(tester.takeException(), isNull);
    },
  );
}
