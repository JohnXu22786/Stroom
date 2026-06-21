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
    testWidgets('shows reasoning button with label when content exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        createReasoningTestApp(
          reasoningText: 'Test reasoning content',
          isStreaming: false,
        ),
      );

      // Should show the button with icon and "推理过程" label
      expect(find.text('推理过程'), findsOneWidget);
      // Should show the psychology icon
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      // The content should NOT be visible inline (it's a panel now)
      expect(find.text('Test reasoning content'), findsNothing);
    });

    testWidgets('shows reasoning in progress label when streaming', (tester) async {
      await tester.pumpWidget(
        createReasoningTestApp(
          reasoningText: 'Streaming reasoning...',
          isStreaming: true,
        ),
      );

      // Should show "推理中" label when streaming
      expect(find.text('推理中'), findsOneWidget);
    });
  });
}
