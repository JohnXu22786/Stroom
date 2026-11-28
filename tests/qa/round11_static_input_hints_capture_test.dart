import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/col_dao.dart';
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/models/model.dart' as anki_model;
import 'package:stroom/anki/providers/anki_actions.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/anki_page.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/pages/simple_model_config_page.dart';
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

  Finder nativeFieldForHint(String expectedHint) {
    final hintFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedInputHint && widget.data == expectedHint,
    );
    return find.ancestor(
      of: hintFinder,
      matching: find.byType(TextFormField),
    );
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

  testWidgets('captures fitting and clipped simple model ID hints', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await capture(
      tester,
      size: const Size(1200, 800),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SimpleModelConfigPage(),
      ),
      path:
          '../../docs/ui-constrained-text-qa/round13-form-hints-a/model-id-fitting-en-1200x800-scale1-light.png',
    );
    final strings = AppLocalizations.of(
      tester.element(find.byType(TextField).first),
    )!;
    final hint = strings.modelIdExample('gpt-4o');
    verifyHintMeasurement(tester, clipped: false, expectedHint: hint);

    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('de', 'DE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: SimpleModelConfigPage(
            model: ModelConfig(
              name: 'Example',
              modelId: 'gpt-4o',
              customParams: [CustomParam(paramName: 'response', type: 'json')],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final localizedStrings = AppLocalizations.of(
      tester.element(find.byType(TextField).first),
    )!;
    expect(tester.takeException(), isNull);
    final localizedHint =
        '${localizedStrings.paramTypeJsonHint}{"key": "value"}';
    verifyHintMeasurement(tester, clipped: true, expectedHint: localizedHint);
    final clippedField = nativeFieldForHint(localizedHint);
    await tester.enterText(clippedField, 'x');
    await tester.enterText(clippedField, '');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(localizedHint), findsOneWidget);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile(
        '../../docs/ui-constrained-text-qa/round13-form-hints-a/custom-json-clipped-de-320x640-scale1_8-widget-test-light.png',
      ),
    );
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byType(TextField), findsWidgets);

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('de', 'DE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData.dark(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: SimpleModelConfigPage(
            model: ModelConfig(
              name: 'Example',
              modelId: 'gpt-4o',
              customParams: [CustomParam(paramName: 'response', type: 'json')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    verifyHintMeasurement(tester, clipped: true, expectedHint: localizedHint);
    final darkClippedField = nativeFieldForHint(localizedHint);
    await tester.enterText(darkClippedField, 'x');
    await tester.enterText(darkClippedField, '');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(localizedHint), findsOneWidget);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile(
        '../../docs/ui-constrained-text-qa/round13-form-hints-a/custom-json-clipped-de-320x640-scale1_8-widget-test-dark.png',
      ),
    );
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

  testWidgets('captures clipped provider reasoning name and JSON hints', (
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
                        paramName: '',
                        isReasoningToggle: true,
                        onValue: '',
                        offValue: '',
                      ),
                      ReasoningParam(
                        paramName: '',
                        isEffortParam: true,
                        type: 'json',
                        options: [''],
                      ),
                      ReasoningParam(
                        paramName: '',
                        type: 'json',
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
    DefaultTabController.of(tester.element(find.byType(TabBar)))
        .animateTo(1, duration: Duration.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final strings = AppLocalizations.of(tester.element(find.byType(Dialog)))!;
    final nameHints = [
      strings.providerParamNameHint('thinking.type, reasoning'),
      strings.providerParamNameHint('reasoning_effort'),
      strings.providerParamNameHint('thinking.type, budget_tokens'),
    ];
    for (final hint in nameHints) {
      final finder = find.byWidgetPredicate(
        (widget) => widget is ConstrainedInputHint && widget.data == hint,
      );
      await tester.ensureVisible(finder);
      verifyHintMeasurement(tester, clipped: true, expectedHint: hint);
    }
    final nameFinder = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedInputHint && widget.data == nameHints.first,
    );
    await tester.ensureVisible(nameFinder);
    final nameField = find.ancestor(
      of: nameFinder,
      matching: find.byType(TextFormField),
    );
    tester
        .widget<EditableText>(
          find.descendant(of: nameField, matching: find.byType(EditableText)),
        )
        .focusNode
        .requestFocus();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    verifyHintMeasurement(tester, clipped: true, expectedHint: nameHints.first);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile(
        '../../docs/ui-constrained-text-qa/round11-static-input-hints/provider-reasoning-name-de-320x640-scale2-light.png',
      ),
    );

    final jsonHint = strings.providerOptionExampleHint(
      '{"thinking": {"budget": 1024}}',
    );
    final jsonFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedInputHint && widget.data == jsonHint,
    );
    expect(jsonFinder, findsNWidgets(2));
    for (var occurrence = 0; occurrence < 2; occurrence++) {
      await tester.ensureVisible(jsonFinder.at(occurrence));
      expect(
        tester.widget<ConstrainedInputHint>(jsonFinder.at(occurrence)).maxLines,
        5,
      );
    }
    final jsonField = find.ancestor(
      of: jsonFinder.first,
      matching: find.byType(TextFormField),
    );
    tester
        .widget<EditableText>(
          find.descendant(of: jsonField, matching: find.byType(EditableText)),
        )
        .focusNode
        .requestFocus();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile(
        '../../docs/ui-constrained-text-qa/round11-static-input-hints/provider-reasoning-json-de-320x640-scale2-light.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures Anki deck-name and tags hint slots', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;

    final container = ProviderContainer(
      overrides: [
        ankiDeckListProvider.overrideWith(
          (ref) async => [Deck(id: 1, name: 'Deck')],
        ),
        ankiDeckStatsProvider.overrideWith(
          (ref, deckId) async => DeckStats(deckName: 'Deck'),
        ),
        ankiModelListProvider.overrideWith(
          (ref) async => [anki_model.Notetype(id: 1, name: 'Basic')],
        ),
        ankiActionsProvider.overrideWith(AnkiActions.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(ankiDeckListProvider.future);
    await container.read(ankiModelListProvider.future);

    final strings = lookupAppLocalizations(const Locale('de', 'DE'));

    Future<void> pumpPage(ThemeData theme) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('de', 'DE'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2.5)),
                child: child!,
              ),
              home: const AnkiDroidPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> captureHints(String themeName, ThemeData theme) async {
      await pumpPage(theme);
      await tester.tap(find.byTooltip(strings.ankiNewDeckTooltip));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      verifyHintMeasurement(
        tester,
        clipped: true,
        expectedHint: strings.ankiDeckNameHint,
      );
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/round13-form-hints-a/anki-deck-name-de-320x640-scale2_5-$themeName.png',
        ),
      );
      await tester.tap(find.text(strings.actionCancel));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.ankiAddCardAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verifyHintMeasurement(
        tester,
        clipped: true,
        expectedHint: strings.ankiTagsHint,
      );
      final hintFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedInputHint &&
            widget.data == strings.ankiTagsHint,
      );
      await tester.ensureVisible(hintFinder);
      await tester.pump(const Duration(milliseconds: 100));
      final field = find.ancestor(
        of: hintFinder,
        matching: find.byType(TextField),
      );
      tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .focusNode
          .requestFocus();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/round13-form-hints-a/anki-tags-de-320x640-scale2_5-$themeName.png',
        ),
      );
      await tester.enterText(field, 'Mathe Physik');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mathe Physik'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(strings.actionCancel).last);
      await tester.pumpAndSettle();
    }

    await captureHints(
      'light',
      ThemeData.light(useMaterial3: true),
    );
    await captureHints(
      'dark',
      ThemeData.dark(useMaterial3: true),
    );
  });
}
