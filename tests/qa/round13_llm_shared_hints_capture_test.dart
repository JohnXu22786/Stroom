import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/llm_model_config_shared.dart';
import 'package:stroom/widgets/constrained_text.dart';

const _captureKey = ValueKey('round13-llm-shared-hints-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final (family, fileName) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  testWidgets('captures fitting and clipped LLM basic field hints', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final nameController = TextEditingController();
    final tokensController = TextEditingController();
    final seedController = TextEditingController();
    addTearDown(nameController.dispose);
    addTearDown(tokensController.dispose);
    addTearDown(seedController.dispose);
    final seedPreviewController = TextEditingController();
    addTearDown(seedPreviewController.dispose);
    final semantics = tester.ensureSemantics();

    Future<void> pumpFields({
      required Size viewport,
      required Locale locale,
      required double scale,
      required String screenshot,
      required bool clipped,
    }) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Builder(
                  builder: (context) {
                    final strings = AppLocalizations.of(context)!;
                    return Column(
                      children: [
                        LabeledTextField(
                          label: strings.modelNameLabel,
                          controller: nameController,
                          hintText: strings.modelNameHint,
                        ),
                        const SizedBox(height: 16),
                        LlmToggleTextField(
                          label: strings.providerMaxOutputTokensLabel,
                          controller: tokensController,
                          enabled: true,
                          onToggle: (_) {},
                          hintText: strings.llmMaxTokensHint,
                          keyboardType: TextInputType.number,
                        ),
                        LlmToggleTextField(
                          label: strings.llmSeedLabel,
                          controller: seedController,
                          enabled: true,
                          onToggle: (_) {},
                          hintText: strings.llmSeedHint,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hints = tester.widgetList<ConstrainedInputHint>(
        find.byType(ConstrainedInputHint),
      );
      expect(hints, hasLength(3));
      for (final hint in hints) {
        final constrainedText = find.descendant(
          of: find.byWidget(hint),
          matching: find.byType(ConstrainedText),
        );
        final constrainedWidget = tester.widget<ConstrainedText>(
          constrainedText,
        );
        final textContext = tester.element(constrainedText);
        final slot = tester.getSize(constrainedText);
        final measurement = TextPainter(
          text: TextSpan(text: hint.data, style: constrainedWidget.style),
          textDirection: Directionality.of(textContext),
          textScaler: MediaQuery.textScalerOf(textContext),
          locale: Localizations.localeOf(textContext),
          maxLines: constrainedWidget.maxLines,
        )..layout();
        debugPrint(
          'Round 13 ${hint.data}: slot=$slot '
          'intrinsic=${measurement.width} clipped=${measurement.width > slot.width}',
        );
        expect(measurement.width > slot.width, clipped, reason: hint.data);
      }
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/round13-llm-shared-hints/$screenshot',
        ),
      );
    }

    await pumpFields(
      viewport: const Size(1200, 800),
      locale: const Locale('en', 'US'),
      scale: 1,
      screenshot: 'llm-hints-en-1200x800-scale1-light.png',
      clipped: false,
    );
    await pumpFields(
      viewport: const Size(320, 1200),
      locale: const Locale('de', 'DE'),
      scale: 2.5,
      screenshot: 'llm-hints-de-DE-320x1200-scale2_5-light.png',
      clipped: true,
    );
    final nameField = find.byType(TextField).first;
    final nameEditable = find.descendant(
      of: nameField,
      matching: find.byType(EditableText),
    );
    expect(
      tester.getSemantics(nameEditable).getSemanticsData().hint,
      'Anzeigenamen eingeben (optional)',
    );
    await tester.enterText(nameField, 'Edited model');
    await tester.pump();
    expect(nameController.text, 'Edited model');
    expect(
      tester.getSemantics(nameEditable).getSemanticsData().hint,
      'Anzeigenamen eingeben (optional)',
    );

    Future<void> pumpSeedPreview({
      required bool dark,
      required bool allowMotion,
    }) async {
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      final baseTheme = dark
          ? ThemeData.dark(useMaterial3: true)
          : ThemeData.light(useMaterial3: true);
      final scheme = baseTheme.colorScheme;
      final theme = baseTheme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: WidgetStateTextStyle.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return TextStyle(color: scheme.onSurface.withValues(alpha: 0.38));
            }
            return TextStyle(
              color: states.contains(WidgetState.focused)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            );
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de', 'DE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2.5),
              disableAnimations: !allowMotion,
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: _captureKey,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (context) {
                    final strings = AppLocalizations.of(context)!;
                    return LlmToggleTextField(
                      label: strings.llmSeedLabel,
                      controller: seedPreviewController,
                      enabled: true,
                      onToggle: (_) {},
                      hintText: strings.llmSeedHint,
                      keyboardType: TextInputType.number,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      if (allowMotion) {
        await tester.pump();
      } else {
        await tester.pumpAndSettle();
      }

      final hint = find.byType(ConstrainedInputHint);
      expect(hint, findsOneWidget);
      final text = find.descendant(
        of: hint,
        matching: find.byType(ConstrainedText),
      );
      final textWidget = tester.widget<ConstrainedText>(text);
      final textContext = tester.element(text);
      final slot = tester.getSize(text);
      final intrinsic = TextPainter(
        text: TextSpan(text: textWidget.data, style: textWidget.style),
        textDirection: Directionality.of(textContext),
        textScaler: MediaQuery.textScalerOf(textContext),
        locale: Localizations.localeOf(textContext),
      )..layout();
      expect(intrinsic.width, greaterThan(slot.width));

      final seedField = tester.widget<TextField>(find.byType(TextField));
      final states = seedField.statesController!;
      if (!allowMotion) {
        expect(
          tester.widget<ConstrainedText>(text).style!.color,
          scheme.onSurfaceVariant,
        );
        await expectLater(
          find.byKey(_captureKey),
          matchesGoldenFile(
            '../../docs/ui-constrained-text-qa/round13-llm-shared-hints/llm-seed-hint-de-DE-320x640-scale2_5-${dark ? 'dark' : 'light'}.png',
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(
          tester.widget<ConstrainedText>(text).style!.color,
          scheme.primary,
        );
        states.update(WidgetState.disabled, true);
        await tester.pump();
        expect(
          tester.widget<ConstrainedText>(text).style!.color,
          scheme.onSurface.withValues(alpha: 0.38),
        );
        states.update(WidgetState.disabled, false);
        await tester.pump();
      } else {
        await tester.tap(find.byType(TextField));
        await tester.pump();
      }

      if (allowMotion &&
          Platform.environment['CAPTURE_ROUND13_HINT_FRAMES'] == '1') {
        for (var index = 0; index < 60; index++) {
          await tester.pump(const Duration(milliseconds: 200));
          await expectLater(
            find.byKey(_captureKey),
            matchesGoldenFile(
              '../../docs/ui-constrained-text-qa/round13-llm-shared-hints/frames/frame-${index.toString().padLeft(2, '0')}.png',
            ),
          );
        }
      }
    }

    await pumpSeedPreview(dark: false, allowMotion: false);
    await pumpSeedPreview(dark: true, allowMotion: false);
    if (Platform.environment['CAPTURE_ROUND13_HINT_FRAMES'] == '1') {
      await pumpSeedPreview(dark: false, allowMotion: true);
    }
    semantics.dispose();
  });
}
