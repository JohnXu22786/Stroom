import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/pages/chat/composer/composer_shared.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/models/tts_models.dart';

/// Helper that creates a widget with all providers needed to test
/// the composer widget in isolation with custom params.
///
/// [customParams] controls the badge count on the '自定义参数' chip:
///   - Params with non-empty [paramName] are counted as enabled.
///   - Params with empty [paramName] are excluded from the count.
///   - When count > 0, a badge (ChipBadge) with the count is shown
///     and the chip uses the accent color (indigo).
///   - When count == 0, no badge is shown and the chip is grey.
///
/// The custom params badge display is independent of the tool enabled
/// state: tools off + custom params > 0 -> badge still shows.
Widget createComposerTestApp({
  Set<String> enabledTools = const {},
  List<CustomParam> customParams = const [],
  List<ReasoningParam> extraReasoningParams = const [],
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      reasoningEnabledProvider.overrideWith((ref) => false),
      reasoningEffortEnabledProvider.overrideWith((ref) => false),
      reasoningParamValuesProvider.overrideWith((ref) => const {}),
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ChatComposerWidget(
          onSend: (text, attachments) {},
          onStop: () {},
          modelNames: ['test-model'],
          selectedModelIndex: 0,
          onModelSelected: (idx) {},
          onEnabledToolsChanged: (tools) {},
          enabledTools: enabledTools,
          customParams: customParams,
          reasoningParams: [
            ReasoningParam(paramName: 'reasoning_effort', isEffortParam: true),
            ...extraReasoningParams,
          ],
        ),
      ),
    ),
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════════
  // Behavior: Custom params badge counts model-level CustomParams
  // (not reasoning params), independently of tool enabled state.
  // ═══════════════════════════════════════════════════════════════

  group('Custom params bubble displays independently of tools', () {
    Future<void> setupSurface(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
    }

    testWidgets(
      'shows badge count when custom params are configured (non-empty name)',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createComposerTestApp(
          customParams: [
            CustomParam(paramName: 'voice', defaultValue: 'cheerful'),
            CustomParam(paramName: 'speed', defaultValue: '1.2'),
          ],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // The "自定义参数" chip should have a badge showing count=2
        expect(find.text('自定义参数'), findsOneWidget);
        // A ChipBadge with "2" should exist
        expect(find.text('2'), findsOneWidget);
      },
    );

    testWidgets(
      'hides badge when no custom params exist',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createComposerTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        expect(find.text('自定义参数'), findsOneWidget);
        // No badge number should be shown
        expect(find.text('1'), findsNothing);
        expect(find.text('2'), findsNothing);
      },
    );

    testWidgets(
      'badge shows even when tools are disabled — independent of tool state',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createComposerTestApp(
          enabledTools: {}, // no tools enabled
          customParams: [
            CustomParam(paramName: 'voice', defaultValue: 'cheerful'),
            CustomParam(paramName: 'speed', defaultValue: '1.2'),
          ],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // Badge should still show even with no tools enabled
        expect(find.text('2'), findsOneWidget);
      },
    );

    testWidgets(
      'no badge on custom params chip when tools enabled but no custom params',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createComposerTestApp(
          enabledTools: {'web_search'}, // tools enabled
          customParams: [], // no custom params
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // "自定义参数" chip exists but has no badge.
        // The "1" from the tool badge should be visible on the tools chip,
        // not on the custom params chip.
        expect(find.text('自定义参数'), findsOneWidget);
        // Custom params badge should NOT show "2" (no params configured)
        expect(find.text('2'), findsNothing);
        // "1" is the tool badge, which is correct — no conflict with custom params
      },
    );

    testWidgets(
      'custom params with empty name are excluded from badge count',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createComposerTestApp(
          customParams: [
            CustomParam(paramName: '', defaultValue: 'empty_name'),
            CustomParam(paramName: 'valid', defaultValue: 'ok'),
          ],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // Only 1 valid param, so badge should show "1"
        expect(find.text('1'), findsOneWidget);
        // Should NOT show "2"
        expect(find.text('2'), findsNothing);
      },
    );
  });
}
