import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/chat/widgets/reasoning_section.dart';
import 'package:stroom/providers/chat_stream_provider.dart';

/// Helper to create a test app with the ReasoningSection widget.
Widget createReasoningTestApp({
  required String reasoningText,
  bool isStreaming = false,
}) {
  return ProviderScope(
    overrides: [
      if (isStreaming)
        streamingReasoningProvider.overrideWith((ref) => reasoningText)
      else
        streamingReasoningProvider.overrideWith((ref) => ''),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ReasoningSection(
          reasoningText: reasoningText,
          isStreaming: isStreaming,
          messageId: 'test-msg-id',
        ),
      ),
    ),
  );
}

void main() {
  group('ReasoningSection (Panel mode)', () {
    testWidgets('shows orange button with reasoning text when content exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        createReasoningTestApp(
          reasoningText: 'Test reasoning content',
          isStreaming: false,
        ),
      );

      // Should show the button with icon and "推理过程" text
      expect(find.text('推理过程'), findsOneWidget);
      // The content should NOT be visible inline (it's a panel now)
      expect(find.text('Test reasoning content'), findsNothing);
    });

    testWidgets('shows "推理中" when streaming', (tester) async {
      await tester.pumpWidget(
        createReasoningTestApp(
          reasoningText: 'Streaming reasoning...',
          isStreaming: true,
        ),
      );

      expect(find.text('推理中'), findsOneWidget);
    });

    testWidgets('opens dialog panel on tap', (tester) async {
      await tester.pumpWidget(createReasoningTestApp(
        reasoningText: 'Panel reasoning content',
        isStreaming: false,
      ));

      // Tap the reasoning button
      await tester.tap(find.text('推理过程'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should open a dialog
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('dialog has close button', (tester) async {
      await tester.pumpWidget(createReasoningTestApp(
        reasoningText: 'Test reasoning',
        isStreaming: false,
      ));

      // Open the panel
      await tester.tap(find.text('推理过程'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should have a close button
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('dialog closes on close button tap', (tester) async {
      await tester.pumpWidget(createReasoningTestApp(
        reasoningText: 'Test reasoning',
        isStreaming: false,
      ));

      // Open the panel
      await tester.tap(find.text('推理过程'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Dialog), findsOneWidget);

      // Close
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('dialog has close button', (tester) async {
      await tester.pumpWidget(
        createReasoningTestApp(
          reasoningText: 'Test reasoning',
          isStreaming: false,
        ),
      );

      // Open the panel
      await tester.tap(find.text('推理过程'));
      await tester.pumpAndSettle();

      // Dialog should have a close button
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('dialog closes on close button tap', (tester) async {
      await tester.pumpWidget(
        createReasoningTestApp(
          reasoningText: 'Test reasoning',
          isStreaming: false,
        ),
      );

      // Open the panel
      await tester.tap(find.text('推理过程'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      // Close
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  });
}
