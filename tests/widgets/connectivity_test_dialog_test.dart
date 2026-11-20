import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/connectivity_test_dialog.dart';
import 'package:stroom/services/connectivity_test_service.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
    'saved status label is bounded when long and stationary when it fits',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<void> showSavedDialog({
        required Locale locale,
        required Size size,
        required double textScale,
        ThemeData? theme,
      }) async {
        if (find.byType(ConnectivityTestDialog).evaluate().isNotEmpty) {
          Navigator.of(tester.element(find.byType(ConnectivityTestDialog)))
              .pop();
          await tester.pumpAndSettle();
        }
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        await tester.binding.setSurfaceSize(const Size(800, 800));
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: theme ?? ThemeData.light(),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ConnectivityTestDialog(
                      title: 'Proxy',
                      initialContent: '{}',
                      note: 'Read-only check.',
                      onSave: (_) async {},
                      onRun: (_) async => const ConnectivityTestResult(
                        succeeded: true,
                        summary: 'HTTP 200',
                        details: '',
                        elapsed: Duration.zero,
                      ),
                    ),
                  ),
                  child: const Text('Open dialog'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            locale.languageCode == 'de' ? 'Inhalt speichern' : 'Save Content',
          ),
        );
        await tester.pumpAndSettle();
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
      }

      await showSavedDialog(
        locale: const Locale('de', 'DE'),
        size: const Size(320, 640),
        textScale: 1.8,
      );

      expect(tester.takeException(), isNull);
      final germanLabel = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data == 'Testinhalt gespeichert',
      );
      expect(germanLabel, findsOneWidget);
      final germanText = tester.widget<ConstrainedText>(germanLabel);
      final germanContext = tester.element(germanLabel);
      final germanNatural = TextPainter(
        text: TextSpan(
          text: germanText.data,
          style:
              DefaultTextStyle.of(germanContext).style.merge(germanText.style),
        ),
        textDirection: Directionality.of(germanContext),
        textScaler: MediaQuery.textScalerOf(germanContext),
        locale: Localizations.localeOf(germanContext),
        maxLines: germanText.maxLines,
      )..layout();
      expect(
        germanNatural.width,
        greaterThan(tester.getSize(germanLabel).width),
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      await showSavedDialog(
        locale: const Locale('en', 'US'),
        size: const Size(800, 800),
        textScale: 1,
        theme: ThemeData.dark(),
      );
      final englishLabel = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText && widget.data == 'Test content saved',
      );
      expect(englishLabel, findsOneWidget);
      final englishText = tester.widget<ConstrainedText>(englishLabel);
      final englishContext = tester.element(englishLabel);
      final englishNatural = TextPainter(
        text: TextSpan(
          text: englishText.data,
          style: DefaultTextStyle.of(englishContext)
              .style
              .merge(englishText.style),
        ),
        textDirection: Directionality.of(englishContext),
        textScaler: MediaQuery.textScalerOf(englishContext),
        locale: Localizations.localeOf(englishContext),
        maxLines: englishText.maxLines,
      )..layout();
      expect(
        englishNatural.width,
        lessThanOrEqualTo(tester.getSize(englishLabel).width),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disables test content editing while saving or running', (
    tester,
  ) async {
    final saveCompleter = Completer<void>();
    final runCompleter = Completer<ConnectivityTestResult>();
    var saveAttempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => ConnectivityTestDialog(
                    title: 'Test',
                    initialContent: '{}',
                    note: 'Test connectivity content.',
                    onSave: (_) {
                      saveAttempts++;
                      if (saveAttempts == 1) return saveCompleter.future;
                      return Future<void>.error(StateError('storage error'));
                    },
                    onRun: (_) => runCompleter.future,
                  ),
                );
              },
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    final contentField = find.byType(TextField);
    expect(tester.widget<TextField>(contentField).enabled, isTrue);

    await tester.tap(find.text('保存内容'));
    await tester.pump();
    expect(tester.widget<TextField>(contentField).enabled, isFalse);

    saveCompleter.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(contentField).enabled, isTrue);
    expect(find.text('测试内容已保存'), findsOneWidget);

    await tester.tap(find.text('保存内容'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(find.text('测试内容已保存'), findsNothing);

    await tester.tap(find.text('运行测试'));
    await tester.pump();
    expect(tester.widget<TextField>(contentField).enabled, isFalse);

    runCompleter.complete(
      const ConnectivityTestResult(
        succeeded: true,
        summary: 'Test succeeded',
        details: 'Test details',
        elapsed: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(contentField).enabled, isTrue);
  });

  testWidgets(
    'shows English chrome while preserving entered and returned data',
    (tester) async {
      const input = '{"endpoint":"https://example.test"}';
      String? runContent;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => ConnectivityTestDialog(
                      title: 'Proxy',
                      initialContent: input,
                      note: 'Read-only check.',
                      onSave: (_) async {},
                      onRun: (content) async {
                        runContent = content;
                        return const ConnectivityTestResult(
                          succeeded: true,
                          summary: 'HTTP 200',
                          details: 'Provider returned HTTP 200',
                          elapsed: Duration(milliseconds: 120),
                        );
                      },
                    ),
                  );
                },
                child: const Text('Open dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Proxy · Connectivity Test'), findsOneWidget);
      expect(find.text('Test content (JSON)'), findsOneWidget);
      expect(find.text('Save Content'), findsOneWidget);
      expect(find.text(input), findsOneWidget);

      await tester.tap(find.text('Run Test'));
      await tester.pumpAndSettle();
      expect(runContent, input);
      expect(find.text('HTTP 200'), findsOneWidget);
      expect(find.text('Provider returned HTTP 200'), findsOneWidget);
    },
  );
}
