// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';
import 'package:stroom/widgets/constrained_text.dart';

class _PendingUpdateNotifier extends UpdateNotifier {
  final Completer<void> check = Completer<void>();

  @override
  Future<void> checkForUpdate({bool silent = false}) => check.future;
}

Widget _buildApp({
  required Locale locale,
  UpdateNotifier? updateNotifier,
  bool disableAnimations = true,
}) {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      providerEntriesProvider.overrideWith((ref) {
        final notifier = ProviderEntriesNotifier();
        notifier.load();
        return notifier;
      }),
      updateProvider.overrideWith((ref) => updateNotifier ?? UpdateNotifier()),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // These cases assert static layout and hit targets. Continuous clipped-
      // label motion is covered by ConstrainedText's own tests and QA preview.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: const SettingsPage(),
    ),
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _showAbout(WidgetTester tester, {required String label}) async {
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).first, const Offset(0, -10000));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
}

void _expectLabelOverflow(
  WidgetTester tester,
  String label, {
  required bool overflows,
}) {
  final textFinder = find.text(label).last;
  final text = tester.widget<Text>(textFinder);
  final context = tester.element(textFinder);
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: DefaultTextStyle.of(context).style.merge(text.style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.localeOf(context),
  )..layout();
  final slot = find.ancestor(
    of: textFinder,
    matching: find.byType(ConstrainedText),
  );
  expect(painter.width > tester.getSize(slot).width, overflows);
}

void main() {
  testWidgets(
    'privacy dialog keeps a long German title beside its icon at narrow width',
    (tester) async {
      _setViewport(tester, const Size(320, 640));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildApp(locale: const Locale('de')));
      await _showAbout(tester, label: 'Datenschutzerklärung');
      await tester.tap(find.text('Datenschutzerklärung'));
      await tester.pumpAndSettle();

      expect(find.text('Datenschutzerklärung'), findsNWidgets(2));
      expect(
        find.ancestor(
          of: find.text('Datenschutzerklärung').last,
          matching: find.byType(ConstrainedText),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.privacy_tip), findsNWidgets(2));
      expect(find.text('Schließen'), findsOneWidget);
      _expectLabelOverflow(tester, 'Datenschutzerklärung', overflows: true);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      expect(find.text('Datenschutzerklärung'), findsOneWidget);
    },
  );

  testWidgets('fitting English privacy title stays in the dialog with its icon',
      (tester) async {
    _setViewport(tester, const Size(800, 640));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_buildApp(locale: const Locale('en')));
    await _showAbout(tester, label: 'Privacy Policy');
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsNWidgets(2));
    expect(
      find.ancestor(
        of: find.text('Privacy Policy').last,
        matching: find.byType(ConstrainedText),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.privacy_tip), findsNWidgets(2));
    _expectLabelOverflow(tester, 'Privacy Policy', overflows: false);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long French update status stays beside progress at narrow width',
    (tester) async {
      _setViewport(tester, const Size(320, 640));
      SharedPreferences.setMockInitialValues({});
      final notifier = _PendingUpdateNotifier();
      await tester.pumpWidget(
        _buildApp(locale: const Locale('fr'), updateNotifier: notifier),
      );
      await _showAbout(tester, label: 'Rechercher des mises à jour');
      final updatesTile = find.ancestor(
        of: find.text('Rechercher des mises à jour'),
        matching: find.byType(ListTile),
      );
      await tester.tap(updatesTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Recherche de mises à jour…'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Recherche de mises à jour…'),
          matching: find.byType(ConstrainedText),
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      _expectLabelOverflow(
        tester,
        'Recherche de mises à jour…',
        overflows: true,
      );
      expect(tester.takeException(), isNull);

      notifier.check.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('fitting English update status retains its full label',
      (tester) async {
    _setViewport(tester, const Size(800, 640));
    SharedPreferences.setMockInitialValues({});
    final notifier = _PendingUpdateNotifier();
    await tester.pumpWidget(
      _buildApp(locale: const Locale('en'), updateNotifier: notifier),
    );
    await _showAbout(tester, label: 'Check for Updates');
    await tester.tap(find.text('Check for Updates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Checking for updates…'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Checking for updates…'),
        matching: find.byType(ConstrainedText),
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    _expectLabelOverflow(tester, 'Checking for updates…', overflows: false);
    expect(tester.takeException(), isNull);

    notifier.check.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('update check completes safely after leaving Settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = _PendingUpdateNotifier();
    await tester.pumpWidget(
      _buildApp(locale: const Locale('en'), updateNotifier: notifier),
    );
    await _showAbout(tester, label: 'Check for Updates');
    await tester.tap(find.text('Check for Updates'));
    await tester.pump();

    expect(find.text('Checking for updates…'), findsOneWidget);

    Navigator.of(tester.element(find.byType(SettingsPage))).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const Scaffold(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    await tester.pump();
    expect(find.byType(SettingsPage), findsNothing);

    notifier.check.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
