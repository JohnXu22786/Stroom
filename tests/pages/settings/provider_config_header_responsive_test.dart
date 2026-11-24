import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

class _ProviderEntriesNotifier extends ProviderEntriesNotifier {
  _ProviderEntriesNotifier() {
    state = ProviderEntriesState(
      entries: [ProviderEntry(id: 'test_llm', type: 'llm', name: 'LLM')],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Functional suite mapping: provider-settings; the CI test owner is feature-ui.
  testWidgets(
    'provider config heading and add action stay within narrow and wide layouts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var locale = const Locale('fr');
      var textScale = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => _ProviderEntriesNotifier(),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: const ProviderConfigPage(entryId: 'test_llm'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      void expectHeaderFits() {
        final viewportWidth =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ProviderConfigPage)),
        )!;
        final heading = find.text(l10n.providerConfigurationHeading);
        final addAction = find.widgetWithText(
          TextButton,
          l10n.builtInPromptAdd,
        );
        final headingRect = tester.getRect(heading);
        final actionRect = tester.getRect(addAction);
        expect(headingRect.left, greaterThanOrEqualTo(16));
        expect(headingRect.right, lessThanOrEqualTo(viewportWidth - 16));
        expect(actionRect.left, greaterThanOrEqualTo(16));
        expect(actionRect.right, lessThanOrEqualTo(viewportWidth - 16));
        expect(tester.takeException(), isNull);
      }

      expectHeaderFits();

      // Simulate a keyboard resize while the production provider page remains open.
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pump();
      expectHeaderFits();

      // A longer German heading at expanded text scale also wraps naturally.
      locale = const Locale('de');
      textScale = 1.6;
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => _ProviderEntriesNotifier(),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: const ProviderConfigPage(entryId: 'test_llm'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectHeaderFits();

      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.physicalSize = const Size(600, 640);
      await tester.pump();
      expectHeaderFits();
    },
  );
}
