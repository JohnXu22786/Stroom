import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/background_task_card.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';

Future<void> _pumpRunningCard(
  WidgetTester tester, {
  required Locale locale,
  required TextScaler textScaler,
}) async {
  final task = BackgroundTask(
    id: 'elapsed-layout',
    type: BackgroundTaskType.ocr,
    title: 'OCR task',
    status: TaskStatus.running,
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Scaffold(body: BackgroundTaskCard(task: task)),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byType(InkWell).first);
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets(
    'running metadata wraps at narrow large-text German width and stays inline at ordinary width',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      tester.view.physicalSize = const Size(360, 800);
      await _pumpRunningCard(
        tester,
        locale: const Locale('de', 'DE'),
        textScaler: const TextScaler.linear(1.7),
      );
      expect(tester.takeException(), isNull);
      final elapsed = find.textContaining('Läuft seit');
      expect(elapsed, findsOneWidget);
      final narrowWrap = find.ancestor(
        of: elapsed,
        matching: find.byType(Wrap),
      );
      expect(narrowWrap, findsOneWidget);
      final narrowWrapHeight = tester.getSize(narrowWrap).height;
      expect(narrowWrapHeight, greaterThan(40));
      final statusIcon = find.byIcon(Icons.sync);
      expect(statusIcon, findsOneWidget);
      final narrowStatusCenterY = tester.getCenter(statusIcon).dy;

      tester.view.physicalSize = const Size(600, 800);
      await _pumpRunningCard(
        tester,
        locale: const Locale('de', 'DE'),
        textScaler: const TextScaler.linear(1.7),
      );
      expect(tester.takeException(), isNull);
      final widerWrap = find.ancestor(
        of: find.textContaining('Läuft seit'),
        matching: find.byType(Wrap),
      );
      expect(widerWrap, findsOneWidget);
      expect(tester.getSize(widerWrap).height, lessThan(narrowWrapHeight));
      expect(tester.getCenter(find.byIcon(Icons.sync)).dy, narrowStatusCenterY);

      tester.view.physicalSize = const Size(430, 932);
      await _pumpRunningCard(
        tester,
        locale: const Locale('en', 'US'),
        textScaler: TextScaler.noScaling,
      );
      expect(tester.takeException(), isNull);
      final ordinaryWrap = find.ancestor(
        of: find.textContaining('Running for'),
        matching: find.byType(Wrap),
      );
      expect(ordinaryWrap, findsOneWidget);
      expect(tester.getSize(ordinaryWrap).height, lessThan(45));
    },
  );
}
