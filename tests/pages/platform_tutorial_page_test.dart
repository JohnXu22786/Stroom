import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/platform_tutorial_page.dart';

Widget _chineseApp(Widget home) => MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  testWidgets('uses the selected locale for platform tutorial copy',
      (tester) async {
    Future<void> pump(Locale locale) => tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PlatformTutorialSelectionPage(),
          ),
        );

    await pump(const Locale('en', 'US'));
    await tester.pumpAndSettle();
    expect(find.text('Platform tutorials'), findsOneWidget);
    expect(
        find.text('Android background optimization tutorial'), findsOneWidget);

    await pump(const Locale('zh', 'CN'));
    await tester.pumpAndSettle();
    expect(find.text('平台教程'), findsOneWidget);
    expect(find.text('Android 后台运行优化教程'), findsOneWidget);
  });

  testWidgets('lists the supported platform tutorial choices', (tester) async {
    await tester.pumpWidget(
      _chineseApp(const PlatformTutorialSelectionPage()),
    );
    await tester.pumpAndSettle();

    for (final platform in [
      'Android',
      'iOS',
      'Windows',
      'macOS',
      'Linux',
      'Web'
    ]) {
      expect(find.text('$platform 后台运行优化教程'), findsOneWidget);
    }
  });

  testWidgets('opens the selected platform detail guide', (tester) async {
    await tester.pumpWidget(
      _chineseApp(const PlatformTutorialSelectionPage()),
    );
    await tester.pumpAndSettle();

    final webTutorial = find.text('Web 后台运行优化教程');
    await tester.ensureVisible(webTutorial);
    await tester.pumpAndSettle();
    await tester.tap(webTutorial);
    await tester.pumpAndSettle();

    expect(find.text('Web 后台运行教程'), findsOneWidget);
    expect(find.text('Web 后台运行优化指南'), findsOneWidget);
    expect(find.text('保持标签页打开'), findsOneWidget);
  });
}
