import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/home_page.dart';
import 'package:visual_math/visual_math.dart';

void main() {
  testWidgets('HomePage opens the public Visual Math drawing page',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    try {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mathModule = find.text('数学绘图');
      await tester.ensureVisible(mathModule);
      await tester.tap(mathModule);
      await tester.pumpAndSettle();

      expect(find.byType(MathDrawingPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
