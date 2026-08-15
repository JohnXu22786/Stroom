import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/provider_config.dart';

/// Helper that creates a MaterialApp wrapped in ProviderScope with
/// all providers needed to render ChatPage.
Widget createChatTestApp({String? activeConversationId}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith(
        (ref) => activeConversationId ?? 'test-conv-id',
      ),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(home: const ChatPage()),
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════
  // ChatComposer Settings Row Tests
  // ═══════════════════════════════════════════════════════════
  group('Settings row above composer input', () {
    // Use a wider surface to accommodate the full chat page layout
    Future<void> setupSurface(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
    }

    testWidgets('clicking 推理 button opens reasoning panel', (tester) async {
      await setupSurface(tester);
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // The reasoning button exists
      expect(find.text('推理'), findsOneWidget);

      // The reasoning button is always enabled now, and opens the panel
      // even when no reasoning params are configured.
      await tester.tap(find.text('推理'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // Reasoning panel should open even without params
      expect(find.text('推理设置'), findsOneWidget);

      // The disable hint should appear
      expect(
        find.textContaining('当前模型未配置推理参数'),
        findsOneWidget,
      );
    });

    testWidgets(
        'opening reasoning panel with unusable effort param heals stale '
        'state (prunes value + resets effort flag)', (tester) async {
      await setupSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          reasoningEnabledProvider.overrideWith((ref) => true),
          reasoningEffortEnabledProvider.overrideWith((ref) => true),
          reasoningParamValuesProvider.overrideWith(
            (ref) => {'reasoning_effort': 'high'},
          ),
          conversationsProvider.overrideWith((ref) {
            return ConversationsNotifier(ref);
          }),
          activeConversationIdProvider.overrideWith(
            (ref) => 'test-conv-id',
          ),
          providerEntriesProvider.overrideWith((ref) {
            return ProviderEntriesNotifier();
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ChatComposerWidget(
                onSend: (text, attachments) {},
                onStop: () {},
                modelNames: ['test-model'],
                selectedModelIndex: 0,
                onModelSelected: (idx) {},
                onEnabledToolsChanged: (tools) {},
                // 力度参数仅声明参数名（无选项值、非布尔）：不可用
                reasoningParams: [
                  ReasoningParam(
                    paramName: 'reasoning_effort',
                    isEffortParam: true,
                    options: [],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Open the reasoning panel
      await tester.tap(find.text('推理'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // The effort switch (second switch) is disabled AND off
      final effortSwitch = tester.widget<Switch>(find.byType(Switch).at(1));
      expect(effortSwitch.onChanged, isNull);
      expect(effortSwitch.value, isFalse);

      // Self-heal: stale value pruned + effort flag reset in the providers
      expect(container.read(reasoningParamValuesProvider), isEmpty);
      expect(container.read(reasoningEffortEnabledProvider), isFalse);
      // No usable params → reasoning flag also reset
      expect(container.read(reasoningEnabledProvider), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // ChatPage Integration Smoke Tests
  // ═══════════════════════════════════════════════════════════
  // (renders with default title — removed: pure existence check)

  // ═══════════════════════════════════════════════════════════
  // Req: File button works during streaming
  // ═══════════════════════════════════════════════════════════
  group('File button works during streaming', () {
    testWidgets('file button is tappable during streaming state', (
      tester,
    ) async {
      // Set streaming to true
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingConversationsProvider
                .overrideWith((ref) => {'test-conv-id'}),
            conversationsProvider.overrideWith(
              (ref) => ConversationsNotifier(ref),
            ),
            activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifier(),
            ),
          ],
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // The file button should be visible and enabled during streaming
      final fileButton = find.byIcon(Icons.attach_file_outlined);
      expect(fileButton, findsOneWidget);

      // Tap the file button - should open the attachment panel
      await tester.tap(fileButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The attachment panel should be open (showing file options)
      // even though streaming is in progress
      expect(find.text('传文件'), findsOneWidget);
    });

    testWidgets('stop button shows during streaming, not send button', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingConversationsProvider
                .overrideWith((ref) => {'test-conv-id'}),
            conversationsProvider.overrideWith(
              (ref) => ConversationsNotifier(ref),
            ),
            activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifier(),
            ),
          ],
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // During streaming, stop button should be visible
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);

      // Send button should NOT be visible during streaming
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Req: Gallery picker uses updated attachment panel
  // ═══════════════════════════════════════════════════════════
  // (gallery picker 4-action-button panel — removed: pure existence checks)

  // ═══════════════════════════════════════════════════════════
  // Req: File-only panel on attach file button
  // ═══════════════════════════════════════════════════════════
  // (attach file button opens file-only panel — removed: pure existence checks)

  // ═══════════════════════════════════════════════════════════
  // Per-conversation streaming button isolation
  // ═══════════════════════════════════════════════════════════
  group('Per-conversation streaming state', () {
    testWidgets(
      'shows send button when a different conversation is streaming',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Conversation "other-conv" is streaming, not "test-conv-id"
              streamingConversationsProvider
                  .overrideWith((ref) => {'other-conv'}),
              conversationsProvider.overrideWith(
                (ref) => ConversationsNotifier(ref),
              ),
              activeConversationIdProvider
                  .overrideWith((ref) => 'test-conv-id'),
              providerEntriesProvider.overrideWith(
                (ref) => ProviderEntriesNotifier(),
              ),
            ],
            child: const MaterialApp(home: ChatPage()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        // The page must render without exceptions; otherwise the
        // send/stop button assertions below would be meaningless.
        expect(tester.takeException(), isNull);

        // The current conversation is NOT streaming — should show send button
        expect(find.byIcon(Icons.send_rounded), findsOneWidget);
        // Should NOT show stop button
        expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
      },
    );
  });
}
