import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/chat/widgets/reasoning_section.dart';
import 'package:stroom/providers/chat_stream_provider.dart';

void main() {
  group('ReasoningSection (Single section)', () {
    testWidgets('shows reasoning button with label when content exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['Test reasoning content'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['Test reasoning content'],
                  streaming: false,
                ),
                messageId: 'test-msg-id',
              ),
            ),
          ),
        ),
      );

      // Should show the button with icon and "推理过程" label
      expect(find.text('推理过程'), findsOneWidget);
      // Should show the psychology icon
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      // The content should NOT be visible inline (it's a panel now)
      expect(find.text('Test reasoning content'), findsNothing);
    });

    testWidgets('shows reasoning in progress label when streaming',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['Streaming reasoning...'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['Streaming reasoning...'],
                  streaming: true,
                ),
                messageId: 'test-msg-id',
              ),
            ),
          ),
        ),
      );

      // Should show "推理中" label when streaming
      expect(find.text('推理中'), findsOneWidget);
    });
  });

  group('ReasoningSection (Multiple sections)', () {
    testWidgets('shows multiple reasoning buttons for multi-step reasoning', (
      tester,
    ) async {
      // Two reasoning sections: first complete, second streaming
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['第一步推理内容...', '第二步推理内容...'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['第一步推理内容...', '第二步推理内容...'],
                  streaming: true,
                ),
                messageId: 'multi-msg-id',
              ),
            ),
          ),
        ),
      );

      // Should show one "推理过程" for the first section and one "推理中" for the last
      expect(find.text('推理过程'), findsOneWidget, reason: '第一个已完成的推理应显示"推理过程"');
      expect(find.text('推理中'), findsOneWidget, reason: '第二个正在进行的推理应显示"推理中"');
    });

    testWidgets('multiple reasoning buttons with index labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['第一轮推理', '第二轮推理'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['第一轮推理', '第二轮推理'],
                  streaming: false,
                ),
                messageId: 'multi-msg-id',
              ),
            ),
          ),
        ),
      );

      // Should show "推理 1 推理过程" and "推理 2 推理过程"
      expect(find.text('推理 1'), findsOneWidget, reason: '多推理时应显示序号');
      expect(find.text('推理 2'), findsOneWidget, reason: '多推理时应显示序号');
    });

    testWidgets('tapping reasoning button opens a dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['推理内容'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['推理内容'],
                  streaming: false,
                ),
                messageId: 'test-msg-id',
              ),
            ),
          ),
        ),
      );

      // Tap the reasoning button
      await tester.tap(find.text('推理过程'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be shown
      expect(find.byType(Dialog), findsOneWidget, reason: '点击推理按钮应弹出对话框');

      // Dismiss the dialog to avoid pending timer issues
      // Use Navigator.pop via the tester's route mechanism
      await tester.binding.setSurfaceSize(const Size(400, 800));
      // Tap outside the dialog (barrier dismiss)
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Pump additional frames to clear pending timers
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });
}
