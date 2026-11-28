import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/pages/text_storage_shared.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/constrained_text.dart';

import '../widgets/message_search_test.dart' show createMessageSearchTestApp;

const _captureKey = ValueKey('round11-static-input-hints-capture');

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  Future<void> capture(
    WidgetTester tester, {
    required Size size,
    required Widget child,
    required String path,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(RepaintBoundary(key: _captureKey, child: child));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(_captureKey), matchesGoldenFile(path));
  }

  void verifyHintMeasurement(
    WidgetTester tester, {
    required bool clipped,
    String? expectedHint,
    int occurrence = 0,
  }) {
    final hintFinder = expectedHint == null
        ? find.byType(ConstrainedInputHint).first
        : find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedInputHint && widget.data == expectedHint,
          );
    final hint = tester.widget<ConstrainedInputHint>(hintFinder.at(occurrence));
    final textFinder = find.descendant(
      of: hintFinder.at(occurrence),
      matching: find.byType(ConstrainedText),
    );
    final text = tester.widget<ConstrainedText>(textFinder);
    final slot = tester.getSize(textFinder);
    final painter = TextPainter(
      text: TextSpan(text: hint.data, style: text.style),
      textDirection: Directionality.of(tester.element(textFinder)),
      textScaler: MediaQuery.textScalerOf(tester.element(textFinder)),
      locale: Localizations.localeOf(tester.element(textFinder)),
      maxLines: hint.maxLines,
    )..layout(maxWidth: slot.width);
    debugPrint(
      'Round 11 hint=${hint.data} slot=$slot maxLines=${hint.maxLines} '
      'didExceedMaxLines=${painter.didExceedMaxLines}',
    );
    expect(painter.didExceedMaxLines, clipped);
  }

  testWidgets('captures fitting and clipped message search hint slots', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await capture(
      tester,
      size: const Size(1200, 800),
      child: createMessageSearchTestApp(locale: const Locale('en', 'US')),
      path:
          '../../docs/ui-constrained-text-qa/round11-static-input-hints/message-search-fitting-en-1200x800-scale1-light.png',
    );
    verifyHintMeasurement(tester, clipped: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await capture(
      tester,
      size: const Size(320, 640),
      child: createMessageSearchTestApp(
        locale: const Locale('fr', 'FR'),
        textScale: 1.5,
      ),
      path:
          '../../docs/ui-constrained-text-qa/round11-static-input-hints/message-search-clipped-fr-320x640-scale1_5-light.png',
    );
    verifyHintMeasurement(tester, clipped: true);
    expect(find.byType(ConstrainedInputHint), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('captures text creation field and compact provider option row', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await capture(
      tester,
      size: const Size(320, 640),
      child: MaterialApp(
        locale: const Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const TextCreatePage(),
      ),
      path:
          '../../docs/ui-constrained-text-qa/round11-static-input-hints/text-create-de-320x640-scale2-light.png',
    );
    verifyHintMeasurement(tester, clipped: true);
    expect(find.byType(ConstrainedInputHint), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          locale: const Locale('fr', 'FR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData.light(useMaterial3: true).copyWith(
            dialogTheme: const DialogThemeData(
              constraints: BoxConstraints(maxWidth: 340),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showProviderSettingsPanel(
                  context: context,
                  providerType: 'llm',
                  config: ProviderConfigItem(
                    providerName: 'Provider',
                    host: 'https://example.test',
                    customParams: [
                      CustomParam(
                        paramName: 'response_mode',
                        type: 'string',
                        options: [''],
                      ),
                    ],
                  ),
                ),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    await tester.tap(find.byWidget(tabs.tabs[1]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final strings = AppLocalizations.of(tester.element(find.byType(Dialog)))!;
    final optionHint = strings.providerOptionExampleHint(
      'low, enabled, true, max',
    );
    final optionHintFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedInputHint && widget.data == optionHint,
    );
    await tester.ensureVisible(optionHintFinder.first);
    final optionField = find.ancestor(
      of: optionHintFinder.first,
      matching: find.byType(TextFormField),
    );
    final optionEditable = find.descendant(
      of: optionField,
      matching: find.byType(EditableText),
    );
    tester.widget<EditableText>(optionEditable).focusNode.requestFocus();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile(
        '../../docs/ui-constrained-text-qa/round11-static-input-hints/provider-custom-option-fr-320x640-scale1_8-light.png',
      ),
    );
    verifyHintMeasurement(tester, clipped: true, expectedHint: optionHint);
    expect(find.byType(ConstrainedInputHint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures clipped provider reasoning option hint slots', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          locale: const Locale('de', 'DE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData.light(useMaterial3: true).copyWith(
            dialogTheme: const DialogThemeData(
              constraints: BoxConstraints(maxWidth: 340),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showProviderSettingsPanel(
                  context: context,
                  providerType: 'llm',
                  config: ProviderConfigItem(
                    providerName: 'Provider',
                    host: 'https://example.test',
                    reasoningParams: [
                      ReasoningParam(
                        paramName: 'reasoning_effort',
                        isEffortParam: true,
                        options: [''],
                      ),
                      ReasoningParam(
                        paramName: 'thinking.style',
                        options: [''],
                      ),
                    ],
                  ),
                ),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    await tester.tap(find.byWidget(tabs.tabs[1]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final strings = AppLocalizations.of(tester.element(find.byType(Dialog)))!;
    final hint = strings.providerOptionExampleHint('low, medium, high');
    final hints = find.byWidgetPredicate(
      (widget) => widget is ConstrainedInputHint && widget.data == hint,
    );
    expect(hints, findsNWidgets(2));
    await tester.ensureVisible(hints.first);
    final field = find.ancestor(
      of: hints.first,
      matching: find.byType(TextFormField),
    );
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    tester.widget<EditableText>(editable).focusNode.requestFocus();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));

    verifyHintMeasurement(
      tester,
      clipped: true,
      expectedHint: hint,
      occurrence: 0,
    );
    verifyHintMeasurement(
      tester,
      clipped: true,
      expectedHint: hint,
      occurrence: 1,
    );
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile(
        '../../docs/ui-constrained-text-qa/round11-static-input-hints/provider-reasoning-option-de-320x640-scale2-light.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
