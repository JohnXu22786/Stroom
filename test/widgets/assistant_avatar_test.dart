import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/widgets/llm/assistant_avatar.dart';

void main() {
  group('AssistantAvatar widget', () {
    testWidgets('renders emoji avatar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantAvatar(
              assistant: Assistant(
                name: '助手',
                prompt: '你好',
                emoji: '🤖',
              ),
              size: 56,
            ),
          ),
        ),
      );

      // Should render the emoji text
      expect(find.text('🤖'), findsOneWidget);
    });

    testWidgets('renders emoji when only emoji field is set', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantAvatar(
              assistant: Assistant(
                name: '旧助手',
                prompt: '你好',
                emoji: '🧠',
              ),
              size: 56,
            ),
          ),
        ),
      );

      expect(find.text('🧠'), findsOneWidget);
    });

    testWidgets('accepts custom size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantAvatar(
              assistant: Assistant(
                name: '助手',
                prompt: '你好',
                emoji: '🎨',
              ),
              size: 80,
            ),
          ),
        ),
      );

      // Verify the emoji renders at the larger size
      expect(find.text('🎨'), findsOneWidget);
    });

    testWidgets('renders emoji at small size without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AssistantAvatar(
                  assistant: Assistant(
                    name: '助手',
                    prompt: '你好',
                    emoji: '🚀',
                  ),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      );

      // Should render without overflow at small size
      expect(find.text('🚀'), findsOneWidget);
    });

    testWidgets('renders emoji without Image widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantAvatar(
              assistant: Assistant(
                name: '助手',
                prompt: '你好',
                emoji: '🌟',
              ),
              size: 56,
            ),
          ),
        ),
      );

      // Should NOT have an Image widget (no image avatar support)
      expect(find.byType(Image), findsNothing);
    });
  });
}
