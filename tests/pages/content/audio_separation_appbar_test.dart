import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/audio_separation_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(
    WidgetTester tester, {
    required double devicePixelRatio,
    required Locale locale,
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = devicePixelRatio;
    tester.view.physicalSize = Size(
      320 * devicePixelRatio,
      640 * devicePixelRatio,
    );
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
                  {
                    'bytes': 'AQID',
                    'name': 'sample-long-video.mp4',
                    'format': 'mp4',
                  },
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'localized AppBar stays within 320x640 at 1x and 3x with a selected video',
    (tester) async {
      for (final ratio in [1.0, 3.0]) {
        await pumpPage(
          tester,
          devicePixelRatio: ratio,
          locale: const Locale('zh', 'CN'),
        );

        final title = find.byWidgetPredicate(
          (widget) => widget is ConstrainedText && widget.data == '视频音频分离',
        );
        final clearLabel = find.byWidgetPredicate(
          (widget) => widget is ConstrainedText && widget.data == '清空',
        );
        expect(title, findsOneWidget);
        expect(clearLabel, findsOneWidget);
        final clearButton = find.widgetWithText(TextButton, '清空');
        expect(clearButton, findsOneWidget);
        expect(tester.getRect(clearButton).right, lessThanOrEqualTo(320));
        expect(tester.getSize(title).width, lessThan(320));
        expect(tester.getSize(clearLabel).width, greaterThan(0));
        expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);

        // A fitting AppBar title remains still after the marquee's start delay.
        await tester.pump(const Duration(seconds: 3));
        expect(
          find.descendant(of: title, matching: find.byType(Transform)),
          findsNothing,
        );
        expect(
          find.descendant(of: clearLabel, matching: find.byType(Transform)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('clear action works with long scaled localized AppBar text', (
    tester,
  ) async {
    await pumpPage(
      tester,
      devicePixelRatio: 3,
      locale: const Locale('de', 'DE'),
      textScale: 1.5,
    );

    expect(find.text('sample-long-video.mp4'), findsOneWidget);
    final clearButton = find.widgetWithText(TextButton, 'Leeren');
    expect(clearButton, findsOneWidget);
    expect(tester.getRect(clearButton).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);

    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('sample-long-video.mp4'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Leeren'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cleared page keeps the original 1x bottom action in view', (
    tester,
  ) async {
    await pumpPage(
      tester,
      devicePixelRatio: 1,
      locale: const Locale('de', 'DE'),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Leeren'));
    await tester.pumpAndSettle();

    final action = find.widgetWithText(FilledButton, 'Audio extrahieren');
    expect(action, findsOneWidget);
    expect(tester.getRect(action).bottom, lessThanOrEqualTo(640));
    expect(tester.getRect(action).top, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('3x text scale keeps AppBar action and cleared page scrollable', (
    tester,
  ) async {
    await pumpPage(
      tester,
      devicePixelRatio: 1,
      locale: const Locale('de', 'DE'),
      textScale: 3,
    );

    final clearButton = find.widgetWithText(TextButton, 'Leeren');
    expect(clearButton, findsOneWidget);
    expect(tester.getRect(clearButton).width, lessThanOrEqualTo(120));
    expect(tester.getRect(clearButton).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);

    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('sample-long-video.mp4'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Leeren'), findsNothing);
    expect(tester.takeException(), isNull);

    final action = find.widgetWithText(FilledButton, 'Audio extrahieren');
    await tester.scrollUntilVisible(
      action,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(action, findsOneWidget);
    expect(tester.getRect(action).bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });
}
