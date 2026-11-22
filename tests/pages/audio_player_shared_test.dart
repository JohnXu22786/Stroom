import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/audio_player_shared.dart';

void main() {
  testWidgets(
    'long audio failure diagnostics scroll to the retry action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retried = false;
      final diagnostics = List<String>.generate(
        40,
        (index) =>
            'diagnostic line $index: decoder reported a detailed failure',
      ).join('\n');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioPlayerErrorView(
              errorMessage: 'The audio file could not be played.',
              diagnosticInfo: diagnostics,
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text(diagnostics), findsOneWidget);
      final failureScrollView = find.byType(SingleChildScrollView);
      expect(failureScrollView, findsOneWidget);
      await tester.drag(failureScrollView, const Offset(0, -4000));
      await tester.pumpAndSettle();

      final retry = find.text('Retry');
      expect(retry, findsOneWidget);
      expect(tester.getBottomRight(retry).dy, lessThanOrEqualTo(640));
      await tester.tap(retry);
      expect(retried, isTrue);
    },
  );
}
