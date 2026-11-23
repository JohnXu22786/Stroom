import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/locale_provider.dart';
import 'package:stroom/providers/update_provider.dart';
import 'package:stroom/startup/startup_data_safety_block_page.dart';
import 'package:stroom/startup/startup_sequence_controller.dart';
import 'package:stroom/widgets/update_dialog.dart';

class _PendingUpdateNotifier extends UpdateNotifier {
  _PendingUpdateNotifier(this.result) : super(dio: Dio());

  final UpdateState result;
  final Completer<void> check = Completer<void>();

  @override
  Future<void> checkForUpdate({bool silent = false}) async {
    state = state.copyWith(isChecking: true);
    await check.future;
    state = result;
  }
}

void main() {
  testWidgets(
    'narrow scaled update-check feedback stays readable through completion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final locale = const Locale('fr', 'FR');
      final l10n = appLocalizationsForLocale(locale);

      Future<_PendingUpdateNotifier> startCheck(UpdateState result) async {
        final notifier = _PendingUpdateNotifier(result);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateProvider.overrideWith((ref) => notifier),
            ],
            child: MaterialApp(
              locale: locale,
              theme: ThemeData.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                ),
                child: child!,
              ),
              home: const StartupDataSafetyBlockPage(
                block: StartupBlock(
                  reason: StartupBlockReason.dataVersionAhead,
                  message: 'Local safety fixture',
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(OutlinedButton).first);
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text(l10n.startupSafetyCheckingUpdates), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(tester.takeException(), isNull);
        return notifier;
      }

      final failureNotifier = await startCheck(
        const UpdateState(error: 'Local update service error'),
      );
      failureNotifier.check.complete();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Local update service error'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      final upToDateNotifier = await startCheck(const UpdateState());
      upToDateNotifier.check.complete();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.startupSafetyUpToDate), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      final updateNotifier = await startCheck(
        const UpdateState(updateAvailable: true, latestVersion: '0.5.6'),
      );
      updateNotifier.check.complete();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(UpdateDialog), findsOneWidget);
      expect(find.text(l10n.startupSafetyCheckingUpdates), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
