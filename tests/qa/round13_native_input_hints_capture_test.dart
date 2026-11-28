import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/constrained_text.dart';

const _captureKey = ValueKey('round13-native-input-hints-capture');

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

  Future<void> openProviderPanel(
    WidgetTester tester, {
    required Size size,
    required Locale locale,
    required double textScale,
    required String screenshot,
    String providerType = 'llm',
    bool checkOcrRequestSize = false,
    bool captureMotion = false,
    bool darkTheme = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          debugShowCheckedModeBanner: false,
          theme: (darkTheme
                  ? ThemeData.dark(useMaterial3: true)
                  : ThemeData.light(useMaterial3: true))
              .copyWith(
            dialogTheme: const DialogThemeData(
              constraints: BoxConstraints(maxWidth: 340),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: !captureMotion,
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showProviderSettingsPanel(
                  context: context,
                  providerType: providerType,
                  config: ProviderConfigItem(
                    providerName: '',
                    host: '',
                    key: '',
                  ),
                ),
                child: const Text('Open provider settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open provider settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (!captureMotion) await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final strings = AppLocalizations.of(tester.element(find.byType(Dialog)))!;
    for (final hint in [
      strings.providerNameHint,
      strings.providerApiUrlHint,
      strings.providerApiKeyInputHint,
    ]) {
      final finder = find.byWidgetPredicate(
        (widget) => widget is ConstrainedInputHint && widget.data == hint,
      );
      expect(finder, findsOneWidget);
      final field = find.ancestor(of: finder, matching: find.byType(TextField));
      expect(field, findsOneWidget);
      final input = tester.widget<TextField>(field);
      expect(
        input.statesController,
        tester.widget<ConstrainedInputHint>(finder).statesController,
      );
      expect(
        find.descendant(of: field, matching: find.byType(EditableText)),
        findsOneWidget,
      );
    }
    if (checkOcrRequestSize) {
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      await tester.tap(find.byWidget(tabs.tabs[1]));
      await tester.pumpAndSettle();

      final hintText = strings.providerUseAppDefault;
      final hintFinder = find.byWidgetPredicate(
        (widget) => widget is ConstrainedInputHint && widget.data == hintText,
      );
      expect(hintFinder, findsOneWidget);
      await tester.ensureVisible(hintFinder);
      await tester.pump();
      final field = find.byKey(
        const Key('ocr_provider_request_size_budget_mib'),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(field);
      final hint = tester.widget<ConstrainedInputHint>(hintFinder);
      expect(input.statesController, hint.statesController);
      expect(input.decoration!.suffixText, 'MiB');
      final suffixFinder = find.text('MiB');
      expect(suffixFinder, findsOneWidget);
      final fieldRect = tester.getRect(field);
      final suffixRect = tester.getRect(suffixFinder);
      final hintRect = tester.getRect(hintFinder);
      expect(suffixRect.left, greaterThan(fieldRect.left));
      expect(suffixRect.right, lessThanOrEqualTo(fieldRect.right));
      final suffixOpacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: suffixFinder, matching: find.byType(AnimatedOpacity))
            .first,
      );
      expect(suffixOpacity.opacity, 1);
      expect(
        hintRect.right,
        lessThanOrEqualTo(suffixRect.left),
        reason: 'The measured hint must leave room for the MiB suffix.',
      );
      expect(
        input.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      expect(
        find.descendant(of: field, matching: find.byType(EditableText)),
        findsOneWidget,
      );
    }
    if (!captureMotion) {
      await expectLater(find.byKey(_captureKey), matchesGoldenFile(screenshot));
    }
  }

  testWidgets('provider hints fit at normal scale and reveal when clipped', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openProviderPanel(
      tester,
      size: const Size(1200, 800),
      locale: const Locale('en', 'US'),
      textScale: 1,
      screenshot:
          '../../docs/ui-constrained-text-qa/round13-form-hints-b/provider-hints-fitting-en-1200x800-scale1-light.png',
    );
    for (final hint in tester.widgetList<ConstrainedInputHint>(
      find.byType(ConstrainedInputHint),
    )) {
      final finder = find.byWidget(hint);
      final textFinder = find.descendant(
        of: finder,
        matching: find.byType(ConstrainedText),
      );
      final text = tester.widget<ConstrainedText>(textFinder);
      final size = tester.getSize(textFinder);
      final painter = TextPainter(
        text: TextSpan(text: hint.data, style: text.style),
        textDirection: Directionality.of(tester.element(textFinder)),
        textScaler: MediaQuery.textScalerOf(tester.element(textFinder)),
        locale: Localizations.localeOf(tester.element(textFinder)),
        maxLines: hint.maxLines,
      )..layout(maxWidth: size.width);
      expect(painter.didExceedMaxLines, isFalse, reason: hint.data);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await openProviderPanel(
      tester,
      size: const Size(320, 640),
      locale: const Locale('fr', 'FR'),
      textScale: 2,
      screenshot:
          '../../docs/ui-constrained-text-qa/round13-form-hints-b/provider-hints-clipped-fr-320x640-scale2-light.png',
    );
    final urlHint = AppLocalizations.of(tester.element(find.byType(Dialog)))!
        .providerApiUrlHint;
    final hintFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedInputHint && widget.data == urlHint,
    );
    final hint = tester.widget<ConstrainedInputHint>(hintFinder);
    final text = tester.widget<ConstrainedText>(
      find.descendant(of: hintFinder, matching: find.byType(ConstrainedText)),
    );
    final slot = tester.getSize(
      find.descendant(of: hintFinder, matching: find.byType(ConstrainedText)),
    );
    final painter = TextPainter(
      text: TextSpan(text: hint.data, style: text.style),
      textDirection: Directionality.of(tester.element(hintFinder)),
      textScaler: MediaQuery.textScalerOf(tester.element(hintFinder)),
      locale: Localizations.localeOf(tester.element(hintFinder)),
      maxLines: hint.maxLines,
    )..layout(maxWidth: slot.width);
    expect(painter.didExceedMaxLines, isTrue);

    final captureMotion =
        Platform.environment['CAPTURE_ROUND13_HINT_FRAMES'] == '1';
    if (captureMotion) {
      await tester.pumpWidget(const SizedBox.shrink());
      await openProviderPanel(
        tester,
        size: const Size(320, 640),
        locale: const Locale('fr', 'FR'),
        textScale: 2,
        captureMotion: true,
        screenshot:
            '../../docs/ui-constrained-text-qa/round13-form-hints-b/provider-hints-clipped-fr-320x640-scale2-light.png',
      );
      final motionHint = AppLocalizations.of(
        tester.element(find.byType(Dialog)),
      )!
          .providerApiUrlHint;
      final motionHintFinder = find.byWidgetPredicate(
        (widget) => widget is ConstrainedInputHint && widget.data == motionHint,
      );
      final motionField = find.ancestor(
        of: motionHintFinder,
        matching: find.byType(TextField),
      );
      tester
          .widget<EditableText>(
            find.descendant(
              of: motionField,
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .requestFocus();
      await tester.pump(const Duration(milliseconds: 100));
      for (var index = 0; index < 100; index++) {
        await tester.pump(const Duration(milliseconds: 200));
        await expectLater(
          find.byKey(_captureKey),
          matchesGoldenFile(
            '../../docs/ui-constrained-text-qa/round13-form-hints-b/frames/frame-${index.toString().padLeft(2, '0')}.png',
          ),
        );
      }
    }

    final nameHint = AppLocalizations.of(tester.element(find.byType(Dialog)))!
        .providerNameHint;
    final nameHintFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedInputHint && widget.data == nameHint,
    );
    final nameField = find.ancestor(
      of: nameHintFinder,
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Nom de test');
    final editable = tester.widget<EditableText>(
      find.descendant(of: nameField, matching: find.byType(EditableText)),
    );
    expect(tester.widget<TextField>(nameField).controller!.text, 'Nom de test');
    expect(
      editable.controller.value.selection.baseOffset,
      'Nom de test'.length,
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('OCR provider request-size hint keeps its native MiB field', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openProviderPanel(
      tester,
      size: const Size(320, 640),
      locale: const Locale('de', 'DE'),
      textScale: 2,
      providerType: 'ocr',
      checkOcrRequestSize: true,
      screenshot:
          '../../docs/ui-constrained-text-qa/round13-form-hints-b/provider-ocr-budget-de-320x640-scale2-light.png',
    );
  });

  testWidgets('OCR provider request-size hint keeps its dark theme styling', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openProviderPanel(
      tester,
      size: const Size(320, 640),
      locale: const Locale('de', 'DE'),
      textScale: 2,
      providerType: 'ocr',
      checkOcrRequestSize: true,
      darkTheme: true,
      screenshot:
          '../../docs/ui-constrained-text-qa/round13-form-hints-b/provider-ocr-budget-de-320x640-scale2-dark.png',
    );
  });
}
