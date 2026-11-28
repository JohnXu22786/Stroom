import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/constrained_text.dart';

const _captureKey = ValueKey('round12-model-reasoning-hints-capture');

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
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  setUp(() async {
    // The repository uses `tests/` rather than Dart's conventional `test/` path.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  void verifyHintMeasurement(
    WidgetTester tester, {
    required bool clipped,
    required String expectedHint,
  }) {
    final hintFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedInputHint && widget.data == expectedHint,
    );
    final hint = tester.widget<ConstrainedInputHint>(hintFinder);
    final textFinder = find.descendant(
      of: hintFinder,
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
      'Round 12 hint slot=$slot maxLines=${hint.maxLines} '
      'didExceedMaxLines=${painter.didExceedMaxLines}',
    );
    expect(painter.didExceedMaxLines, clipped);
  }

  testWidgets('captures clipped model reasoning parameter example hints', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    final captureMotion =
        Platform.environment['CAPTURE_ROUND12_HINT_FRAMES'] == '1';
    final toggle = ReasoningParam(
      paramName: 'thinking.type',
      isReasoningToggle: true,
      onValue: '',
      offValue: 'disabled',
    );
    final effort = ReasoningParam(
      paramName: 'reasoning_effort',
      isEffortParam: true,
      type: 'string',
      options: ['low'],
    );
    final additional = ReasoningParam(
      paramName: 'budget_tokens',
      type: 'json',
      options: ['1024'],
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          locale: const Locale('de', 'DE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: !captureMotion,
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => LlmModelConfigPage(
                        provider: ProviderConfigItem(
                          providerName: 'Capture Provider',
                          host: 'https://example.test',
                          key: 'test-key',
                          reasoningParams: [toggle, effort, additional],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open model settings'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open model settings'));
    await tester.pumpAndSettle();
    final strings =
        AppLocalizations.of(tester.element(find.byType(LlmModelConfigPage)))!;
    await tester.scrollUntilVisible(
      find.text(strings.llmReasoningParams),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    final hint = strings.reasoningOnExample;
    final hintFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedInputHint && widget.data == hint,
    );
    await tester.ensureVisible(hintFinder);
    verifyHintMeasurement(tester, clipped: true, expectedHint: hint);
    final field = find.ancestor(
      of: hintFinder,
      matching: find.byType(TextFormField),
    );
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    final semantics = tester.ensureSemantics();
    tester.widget<EditableText>(editable).focusNode.requestFocus();
    await tester.pump(const Duration(milliseconds: 100));
    if (captureMotion) {
      for (var index = 0; index < 40; index++) {
        await tester.pump(const Duration(milliseconds: 200));
        await expectLater(
          find.byKey(_captureKey),
          matchesGoldenFile(
            '../../docs/ui-constrained-text-qa/round12-llm-config-reasoning-hints/frames/frame-${index.toString().padLeft(2, '0')}.png',
          ),
        );
      }
    } else {
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.getSemantics(editable).getSemanticsData().hint, hint);
    if (!captureMotion) {
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/round12-llm-config-reasoning-hints/reasoning-toggle-value-de-320x640-scale2-light.png',
        ),
      );
    }
    await tester.enterText(field, 'active');
    await tester.pump();
    expect(tester.getSemantics(editable).getSemanticsData().hint, hint);
    expect(tester.widget<EditableText>(editable).controller.text, 'active');

    final addValue = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText && widget.data == strings.reasoningAddValue,
    );
    await tester.ensureVisible(addValue.first);
    if (captureMotion) {
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pumpAndSettle();
    }
    await tester.tap(addValue.first);
    if (captureMotion) {
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pumpAndSettle();
    }
    expect(find.byType(AlertDialog), findsOneWidget);
    final effortHint = strings.reasoningEffortExample;
    final effortHintFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedInputHint && widget.data == effortHint,
    );
    expect(effortHintFinder, findsOneWidget);
    expect(tester.widget<ConstrainedInputHint>(effortHintFinder).maxLines, 1);
    final effortField = find.ancestor(
      of: effortHintFinder,
      matching: find.byType(TextField),
    );
    final effortEditable = find.descendant(
      of: effortField,
      matching: find.byType(EditableText),
    );
    if (!captureMotion) {
      expect(
        tester.getSemantics(effortEditable).getSemanticsData().hint,
        effortHint,
      );
    }
    if (!captureMotion) {
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/round12-llm-config-reasoning-hints/effort-add-value-dialog-de-320x640-scale2-light.png',
        ),
      );
    }
    await tester.enterText(effortField, 'ultra');
    await tester.pump();
    expect(
        tester.widget<EditableText>(effortEditable).controller.text, 'ultra');
    await tester.tap(find.text(strings.batchDlgConfirm));
    if (captureMotion) {
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('captures clipped reasoning field hint in dark theme', (
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
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: LlmModelConfigPage(
            provider: ProviderConfigItem(
              providerName: 'Capture Provider',
              host: 'https://example.test',
              key: 'test-key',
              reasoningParams: [
                ReasoningParam(
                  paramName: 'thinking.type',
                  isReasoningToggle: true,
                  onValue: '',
                  offValue: 'disabled',
                ),
                ReasoningParam(
                  paramName: 'reasoning_effort',
                  isEffortParam: true,
                  type: 'string',
                  options: ['low'],
                ),
                ReasoningParam(
                  paramName: 'budget_tokens',
                  type: 'json',
                  options: ['1024'],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final strings =
        AppLocalizations.of(tester.element(find.byType(LlmModelConfigPage)))!;
    await tester.scrollUntilVisible(
      find.text(strings.llmReasoningParams),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    final hint = strings.reasoningOnExample;
    final hintFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedInputHint && widget.data == hint,
    );
    await tester.ensureVisible(hintFinder);
    verifyHintMeasurement(tester, clipped: true, expectedHint: hint);
    final field = find.ancestor(
      of: hintFinder,
      matching: find.byType(TextFormField),
    );
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    final semantics = tester.ensureSemantics();
    tester.widget<EditableText>(editable).focusNode.requestFocus();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getSemantics(editable).getSemanticsData().hint, hint);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile(
        '../../docs/ui-constrained-text-qa/round12-llm-config-reasoning-hints/reasoning-toggle-value-de-320x640-scale2-dark.png',
      ),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
