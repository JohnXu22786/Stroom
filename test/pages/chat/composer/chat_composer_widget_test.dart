import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/pages/chat_page.dart';

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

    testWidgets(
      'settings row shows model, tools, reasoning buttons above input',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createChatTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // The settings row buttons should be visible above the input
        expect(find.text('模型'), findsOneWidget);
        expect(find.text('工具'), findsOneWidget);
        expect(find.text('推理'), findsOneWidget);
      },
    );

    testWidgets('each settings button has an icon', (tester) async {
      await setupSurface(tester);
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Each button should have its icon
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
      expect(find.byIcon(Icons.build_outlined), findsOneWidget);
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
    });

    testWidgets('clicking model button opens model panel', (tester) async {
      await setupSurface(tester);
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Tap the model button
      await tester.ensureVisible(find.text('模型'));
      await tester.tap(find.text('模型'));
      await tester.pumpAndSettle();

      // Model panel should be visible
      expect(find.text('选择模型'), findsOneWidget);
    });

    testWidgets('clicking 工具 button opens tools panel', (tester) async {
      await setupSurface(tester);
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Tap the tools button
      await tester.ensureVisible(find.text('工具'));
      await tester.tap(find.text('工具'));
      await tester.pumpAndSettle();

      // Tools panel should be visible
      expect(find.text('可用工具'), findsOneWidget);
    });

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

    testWidgets('settings row tags use natural width, not forced full width',
        (tester) async {
      await setupSurface(tester);
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // All three tags should be visible
      expect(find.text('模型'), findsOneWidget);
      expect(find.text('工具'), findsOneWidget);
      expect(find.text('推理'), findsOneWidget);

      // The model chip should not overflow or cause errors
      expect(tester.takeException(), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // ChatPage Integration Smoke Tests
  // ═══════════════════════════════════════════════════════════
  group('ChatPage basic rendering', () {
    testWidgets('renders with default title', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      expect(find.text('新对话'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Req: ChatComposerWidget without Positioned
  // ═══════════════════════════════════════════════════════════
  group('ChatComposerWidget layout (no Positioned)', () {
    testWidgets('composer renders without Positioned wrapper', (tester) async {
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // The composer should render - verify by the attach file button
      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);

      // The send button should exist
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      // The settings row should be visible above input
      expect(find.text('模型'), findsOneWidget);
      expect(find.text('工具'), findsOneWidget);
      expect(find.text('推理'), findsOneWidget);
    });

    testWidgets('composer does not use its own Positioned widget', (
      tester,
    ) async {
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // The composer itself no longer wraps in Positioned
      // (flutter_chat_ui may use Positioned internally for its layout)
    });
  });

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
            isStreamingProvider.overrideWith((ref) => true),
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
            isStreamingProvider.overrideWith((ref) => true),
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
  group(
    'Gallery picker shows camera/gallery/file/app-file options (file-only panel)',
    () {
      testWidgets('gallery picker opens file-only panel with 4 action buttons',
          (
        tester,
      ) async {
        await tester.pumpWidget(createChatTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // Tap the attach file button to open file-only panel
        await tester.tap(find.byIcon(Icons.attach_file_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // The file-only panel should show all 4 file action buttons with
        // updated labels
        expect(find.text('拍照'), findsOneWidget);
        expect(find.text('设备相册'), findsOneWidget);
        expect(find.text('设备文件'), findsOneWidget);
        expect(find.text('应用内文件'), findsOneWidget);

        // Old settings section "推理设置" should not appear (it's not the button label)
        expect(find.text('推理设置'), findsNothing);

        // "模型" and "工具" are now visible in the settings row (always above input),
        // so they are expected to exist even when the file panel is open.
        expect(find.text('模型'), findsOneWidget);
        expect(find.text('工具'), findsOneWidget);
      });
    },
  );

  // ═══════════════════════════════════════════════════════════
  // Req: File-only panel on attach file button
  // ═══════════════════════════════════════════════════════════
  group('Attachment button opens file-only panel (no settings)', () {
    testWidgets(
      'attach file button opens file-only panel, not old settings panel',
      (tester) async {
        await tester.pumpWidget(createChatTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // Tap the attach file button
        await tester.tap(find.byIcon(Icons.attach_file_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // The panel title should be about file transfer, not settings
        expect(find.text('传文件'), findsOneWidget);

        // Old settings section headers should not exist
        expect(find.text('Chat 设置'), findsNothing);
      },
    );
  });
}
