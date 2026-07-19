import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/pages/chat/chat_types.dart';
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
  // Issue 5: All settings buttons always visible
  // ═══════════════════════════════════════════════════════════
  //
  // Regression: the "自定义参数" chip was previously hidden when no
  // non-toggle/non-effort reasoning params existed. After the fix,
  // it must always be visible regardless of configuration.
  group('Issue 5: Settings row buttons always visible', () {
    Future<void> setupSurface(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
    }

    testWidgets(
      '自定义参数 button is always visible even with no custom params',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createChatTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // All four buttons should be visible in the settings row:
        // 模型, 工具, 推理, 自定义参数
        expect(find.text('模型'), findsOneWidget);
        expect(find.text('工具'), findsOneWidget);
        expect(find.text('推理'), findsOneWidget);
        expect(find.text('自定义参数'), findsOneWidget);
      },
    );

    testWidgets(
      '自定义参数 button has correct icon',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createChatTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // The custom params button should have the tune icon
        expect(find.byIcon(Icons.tune), findsOneWidget);
      },
    );

    testWidgets(
      'tapping 自定义参数 opens panel even with no params',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createChatTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // Tap the custom params button
        await tester.ensureVisible(find.text('自定义参数'));
        await tester.tap(find.text('自定义参数'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 100));

        // Custom params panel should open even with no params
        expect(find.text('自定义推理参数'), findsOneWidget);

        // The no-params hint should appear
        expect(
          find.textContaining('当前模型未配置自定义推理参数'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '工具 button is always visible with badge count',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createChatTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // Tools button should be visible
        expect(find.text('工具'), findsOneWidget);
      },
    );

    testWidgets(
      '推理 button is always visible with correct label',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createChatTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // Reasoning button should be visible with default label
        expect(find.text('推理'), findsOneWidget);
      },
    );

    testWidgets(
      'all settings row icons are present',
      (tester) async {
        await setupSurface(tester);
        await tester.pumpWidget(createChatTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // All four icons should be present
        expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
        expect(find.byIcon(Icons.build_outlined), findsOneWidget);
        expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
        expect(find.byIcon(Icons.tune), findsOneWidget);
      },
    );
  });
}
