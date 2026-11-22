import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/connectivity_test_dialog.dart';
import 'package:stroom/services/connectivity_test_service.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
    'wraps the complete JSON helper in every locale at a narrow viewport',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 640));

      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: locale.languageCode == 'en'
                ? ThemeData.dark()
                : ThemeData.light(),
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

        final helper = AppLocalizations.delegate
            .load(locale)
            .then((localizations) => localizations.connectivityTestJsonHelp);
        final helperText = await helper;
        final helperFinder = find.text(helperText);
        expect(helperFinder, findsOneWidget, reason: locale.toString());
        final helperParagraph = tester.renderObject<RenderParagraph>(
          helperFinder,
        );
        expect(
          helperParagraph.didExceedMaxLines,
          isFalse,
          reason: '${locale.toString()} helper should not be truncated',
        );
        expect(
          helperParagraph.size.height,
          greaterThan(24),
          reason: '${locale.toString()} helper should wrap naturally',
        );
        expect(tester.takeException(), isNull, reason: locale.toString());
      }
    },
  );

  testWidgets(
    'keeps native JSON editing active with the multiline keyboard open',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 640));
      const locale = Locale('de', 'DE');

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
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

      final fieldFinder = find.byType(TextField);
      await tester.showKeyboard(fieldFinder);
      const editedJson = '{\n  "edited": true\n}';
      await tester.enterText(fieldFinder, editedJson);
      await tester.pump();

      final field = tester.widget<TextField>(fieldFinder);
      expect(field.keyboardType, TextInputType.multiline);
      expect(field.enabled, isTrue);
      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.focusNode.hasFocus, isTrue);
      expect(editableText.controller.text, editedJson);
      expect(
        editableText.controller.selection,
        const TextSelection.collapsed(offset: editedJson.length),
      );
      expect(tester.view.viewInsets.bottom, 280);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(find.byType(ConnectivityTestDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'connectivity JSON field label uses a measured constrained label',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 640));
      tester.platformDispatcher.textScaleFactorTestValue = 2;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de', 'DE'),
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

      final localizedLabel = AppLocalizations.delegate
          .load(const Locale('de', 'DE'))
          .then((localizations) => localizations.connectivityTestJsonLabel);
      final labelText = await localizedLabel;
      final labelFinder = find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == labelText,
      );
      expect(labelFinder, findsOneWidget);
      final label = tester.widget<ConstrainedText>(labelFinder);
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      final labelContext = tester.element(labelFinder);
      final naturalLabel = TextPainter(
        text: TextSpan(
          text: label.data,
          style: DefaultTextStyle.of(labelContext).style.merge(label.style),
        ),
        textDirection: Directionality.of(labelContext),
        textScaler: MediaQuery.textScalerOf(labelContext),
        locale: Localizations.localeOf(labelContext),
        maxLines: label.maxLines,
      )..layout();
      expect(
        naturalLabel.width,
        greaterThan(tester.getSize(labelFinder).width),
        reason: 'the localized field label should be clipped at this scale',
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(labelText), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets(
    'long diagnostic details remain reachable in a narrow result dialog',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 640));

      const lastLine = 'END OF COMPLETE CONNECTIVITY DIAGNOSTIC';
      final details =
          '${List.generate(800, (i) => 'diagnostic line $i').join('\n')}\n$lastLine';
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
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
                    onRun: (_) async => ConnectivityTestResult(
                      succeeded: false,
                      summary: 'Request failed',
                      details: details,
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
      await tester.tap(find.text('Run Test'));
      await tester.pumpAndSettle();

      final fullDetails = find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == details,
      );
      expect(fullDetails, findsOneWidget);
      final scrollable =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(fullDetails).dy, lessThan(640));
      expect(tester.takeException(), isNull);
    },
  );
}
