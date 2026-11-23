import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/asr_service.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('LLM reasoning controls reflow below their labels at 320 px', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showProviderSettingsPanel(
                  context: context,
                  config: ProviderConfigItem(
                    providerName: 'Provider QA',
                    host: 'https://api.example.com/v1',
                    key: 'test-key',
                    reasoningParams: [
                      ReasoningParam(
                        paramName: 'reasoning.enabled',
                        isReasoningToggle: true,
                        onValue: 'yes',
                        offValue: 'false',
                        options: [],
                      ),
                      ReasoningParam(
                        paramName: 'reasoning_effort',
                        isEffortParam: true,
                        options: ['low', 'high'],
                      ),
                      ReasoningParam(
                        paramName: 'thinking.budget',
                        options: ['1024', '4096'],
                      ),
                    ],
                  ),
                  providerType: 'llm',
                ),
                child: const Text('Open provider settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open provider settings'));
    await tester.pumpAndSettle();
    final localizations = AppLocalizations.of(
      tester.element(find.byType(Dialog)),
    )!;
    final tabController = DefaultTabController.of(
      tester.element(find.byType(TabBar)),
    );
    tabController.animateTo(1, duration: Duration.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final title in [
      localizations.providerReasoningToggle,
      localizations.chatReasoningEffort,
    ]) {
      final titleRect = tester.getRect(find.text(title));
      final card =
          find.ancestor(of: find.text(title), matching: find.byType(Card));
      final dropdownRect = tester.getRect(
        find.descendant(
            of: card, matching: find.byType(DropdownButton<String>)),
      );
      expect(
        dropdownRect.top,
        greaterThanOrEqualTo(titleRect.bottom),
        reason: '$title should have its own readable line before controls',
      );
    }
    final additionalName = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField && widget.initialValue == 'thinking.budget',
    );
    final additionalCard =
        find.ancestor(of: additionalName, matching: find.byType(Card));
    final additionalDropdown = find.descendant(
      of: additionalCard,
      matching: find.byType(DropdownButton<String>),
    );
    expect(
      tester.getTopLeft(additionalDropdown).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(additionalName).dy),
      reason: 'the additional-parameter name gets a full row before controls',
    );
    expect(find.byType(DropdownButton<String>), findsNWidgets(3));
    expect(
      find.byTooltip(localizations.providerDeleteReasoningToggle),
      findsOneWidget,
    );
    expect(
      find.byTooltip(localizations.providerDeleteReasoningEffort),
      findsOneWidget,
    );
    final deleteAdditionalParam = find.ancestor(
      of: find.byTooltip(localizations.providerDeleteCustomParam),
      matching: find.byType(IconButton),
    );
    expect(
        tester.widget<IconButton>(deleteAdditionalParam).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('ASR setting labels and dropdowns fit narrow and wide dialogs', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final locale in const [
      Locale('en'),
      Locale('de'),
      Locale('pt', 'BR'),
    ]) {
      for (final width in [360.0, 440.0, 800.0, 1100.0]) {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(
              dialogTheme: const DialogThemeData(
                constraints: BoxConstraints(maxWidth: 1200),
              ),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showProviderSettingsPanel(
                      context: context,
                      config: ProviderConfigItem(
                        providerName: 'ASR provider',
                        host: 'https://api.example.com',
                        key: 'test-key',
                        typeConfig: {
                          'fallbackMethod': 'none',
                          'preprocessing': 'resampleMono',
                          'chunking': 'silence',
                          'compression': 'flac',
                        },
                      ),
                      providerType: 'asr',
                    ),
                    child: const Text('Open provider settings'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open provider settings'));
        await tester.pumpAndSettle();
        final tabController = DefaultTabController.of(
          tester.element(find.byType(TabBar)),
        );
        tabController.animateTo(1, duration: Duration.zero);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tabController.index, 1);

        final localizations = AppLocalizations.of(
          tester.element(find.byType(Dialog)),
        )!;
        expect(find.text(localizations.providerFallbackMethod), findsOneWidget);
        expect(find.text(localizations.providerUploadMethod), findsOneWidget);
        expect(
          find.text(localizations.providerPreprocessingMethod),
          findsOneWidget,
        );
        expect(find.text(localizations.providerMaxUploadSize), findsOneWidget);
        expect(find.text(localizations.providerChunkingMode), findsOneWidget);
        expect(
          find.text(localizations.providerCompressionMode),
          findsOneWidget,
        );
        expect(find.byType(DropdownButton<String>), findsNWidgets(4));
        final dialogRect = tester.getRect(find.byType(Dialog));
        final cancelButton = find.ancestor(
          of: find.text(localizations.batchDlgCancel),
          matching: find.byType(TextButton),
        );
        final saveButton = find.ancestor(
          of: find.text(localizations.mermaidSaveButton),
          matching: find.byType(FilledButton),
        );
        for (final action in [cancelButton, saveButton]) {
          final actionRect = tester.getRect(action);
          expect(actionRect.left, greaterThanOrEqualTo(dialogRect.left));
          expect(actionRect.right, lessThanOrEqualTo(dialogRect.right));
          expect(actionRect.height, greaterThanOrEqualTo(48));
        }
        for (final label in [
          localizations.providerFallbackMethod,
          localizations.providerUploadMethod,
          localizations.providerPreprocessingMethod,
          localizations.providerMaxUploadSize,
          localizations.providerChunkingMode,
          localizations.providerCompressionMode,
        ]) {
          final labelRect = tester.getRect(find.text(label));
          expect(labelRect.left, greaterThanOrEqualTo(dialogRect.left));
          expect(labelRect.right, lessThanOrEqualTo(dialogRect.right));
        }
        final customParamsHeader = tester.getRect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedText &&
                widget.data == localizations.chatCustomParameters,
          ),
        );
        final addCustomParamButton = tester.getRect(
          find.ancestor(
            of: find.text(localizations.providerAddCustomParam),
            matching: find.byType(TextButton),
          ),
        );
        for (final controlRect in [customParamsHeader, addCustomParamButton]) {
          expect(controlRect.left, greaterThanOrEqualTo(dialogRect.left));
          expect(controlRect.right, lessThanOrEqualTo(dialogRect.right));
        }
        if (addCustomParamButton.top >= customParamsHeader.bottom) {
          expect(
            addCustomParamButton.top,
            greaterThanOrEqualTo(customParamsHeader.bottom),
          );
        } else {
          expect(
            addCustomParamButton.left,
            greaterThanOrEqualTo(customParamsHeader.right),
          );
        }
        var hasNarrowClippedTab = false;
        for (final tabLabel in [
          localizations.providerBasicInfoTab,
          localizations.providerParameterSettingsTab,
        ]) {
          final textRect = tester.getRect(find.text(tabLabel));
          final tabRect = tester.getRect(
            find.ancestor(of: find.text(tabLabel), matching: find.byType(Tab)),
          );
          final tabBarRect = tester.getRect(find.byType(TabBar));
          expect(tabRect.left, greaterThanOrEqualTo(tabBarRect.left));
          expect(tabRect.right, lessThanOrEqualTo(tabBarRect.right));
          if (textRect.width > tabRect.width + 0.5) {
            hasNarrowClippedTab = true;
            final textClip = tester.getRect(
              find
                  .ancestor(
                    of: find.text(tabLabel),
                    matching: find.byType(ClipRect),
                  )
                  .first,
            );
            expect(textClip.left, greaterThanOrEqualTo(tabRect.left));
            expect(textClip.right, lessThanOrEqualTo(tabRect.right));
          }
        }
        if (width < 800 && locale.languageCode != 'en') {
          expect(
            hasNarrowClippedTab,
            isTrue,
            reason: 'Long $locale tab text should scroll inside its Tab slot',
          );
        }
        final uploadLabel = tester.getRect(
          find.text(localizations.providerUploadMethod),
        );
        final uploadControl = tester.getRect(
          find.byType(DropdownButton<AudioUploadMethod>),
        );
        final maxSizeLabel = tester.getRect(
          find.text(localizations.providerMaxUploadSize),
        );
        final maxSizeControl = tester.getRect(find.byType(TextField).first);
        for (var i = 0; i < 4; i++) {
          final dropdownRect = tester.getRect(
            find.byType(DropdownButton<String>).at(i),
          );
          expect(
            dropdownRect.left,
            greaterThanOrEqualTo(dialogRect.left + 16),
            reason: 'ASR dropdown $i should stay inside dialog content',
          );
          expect(
            dropdownRect.right,
            lessThanOrEqualTo(dialogRect.right - 16),
            reason: 'ASR dropdown $i should stay inside dialog content',
          );
        }
        if (width < 800) {
          expect(uploadControl.top, greaterThanOrEqualTo(uploadLabel.bottom));
          expect(maxSizeControl.top, greaterThanOrEqualTo(maxSizeLabel.bottom));
        } else {
          expect(
            (uploadControl.center.dy - uploadLabel.center.dy).abs(),
            lessThan(20),
          );
          expect(
            (maxSizeControl.center.dy - maxSizeLabel.center.dy).abs(),
            lessThan(20),
          );
        }
        expect(
          tester.takeException(),
          isNull,
          reason: 'Dialog width: $width, locale: $locale',
        );
        await tester.tap(find.text(localizations.batchDlgCancel));
        await tester.pumpAndSettle();
      }
    }
  });
}
