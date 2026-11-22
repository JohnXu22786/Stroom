import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/audio_separation_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAudioSeparationPage(
    WidgetTester tester, {
    required Locale locale,
    required double textScale,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(textScale),
            ),
            child: const AudioSeparationPage(
              retryData: {
                'videos': [
                  {'bytes': 'AQID', 'name': 'sample.mp4', 'format': 'mp4'},
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('short count label stays aligned in the narrow footer', (
    tester,
  ) async {
    await pumpAudioSeparationPage(
      tester,
      locale: const Locale('en', 'US'),
      textScale: 1,
    );

    final label = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText && widget.data == 'Selected 1 video',
    );
    expect(label, findsOneWidget);
    expect(tester.getSize(label).width, lessThan(280));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long scaled localized count stays bounded beside its icon', (
    tester,
  ) async {
    await pumpAudioSeparationPage(
      tester,
      locale: const Locale('fr', 'FR'),
      textScale: 2.5,
    );

    final label = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText && widget.data == '1 vidéo sélectionnée',
    );
    expect(label, findsOneWidget);
    final labelRect = tester.getRect(label);
    final icon = find.byWidgetPredicate(
      (widget) =>
          widget is Icon && widget.icon == Icons.videocam && widget.size == 14,
    );
    final iconRect = tester.getRect(icon);
    final countRow = find.ancestor(of: icon, matching: find.byType(Row)).first;
    final rowRect = tester.getRect(countRow);
    final naturalText = TextPainter(
      text: const TextSpan(
        text: '1 vidéo sélectionnée',
        style: TextStyle(fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(2.5),
      locale: const Locale('fr', 'FR'),
    )..layout();
    final labelSlotWidth = rowRect.width - iconRect.width - 4;
    expect(naturalText.width, greaterThan(labelSlotWidth));
    expect(labelRect.left, iconRect.right + 4);
    expect(labelRect.width, lessThanOrEqualTo(labelSlotWidth));
    expect(labelRect.right, lessThanOrEqualTo(rowRect.right));
  });
}
