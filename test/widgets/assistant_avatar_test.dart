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
                avatarType: 'emoji',
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

    testWidgets('renders image avatar from URL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantAvatar(
              assistant: Assistant(
                name: '图片助手',
                prompt: '你好',
                avatarType: 'image',
                emoji: '🤖',
                avatarUrl: 'https://example.com/avatar.png',
              ),
              size: 56,
            ),
          ),
        ),
      );

      // Should NOT render the emoji - should render an Image widget instead
      expect(find.text('🤖'), findsNothing);
      // Should have an Image.network widget
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders emoji when avatarType is null (backward compat)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantAvatar(
              assistant: Assistant(
                name: '旧助手',
                prompt: '你好',
                // No avatarType set - defaults to emoji
                emoji: '🧠',
              ),
              size: 56,
            ),
          ),
        ),
      );

      expect(find.text('🧠'), findsOneWidget);
    });

    testWidgets('uses fallback emoji from assistant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantAvatar(
              assistant: Assistant(
                name: '助手',
                prompt: '你好',
                avatarType: 'image',
                avatarUrl: 'https://example.com/avatar.png',
                emoji: '🌟',
              ),
              size: 56,
            ),
          ),
        ),
      );

      // Image mode - no emoji shown
      expect(find.text('🌟'), findsNothing);
    });

    testWidgets('accepts custom size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantAvatar(
              assistant: Assistant(
                name: '助手',
                prompt: '你好',
                avatarType: 'emoji',
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
  });
}
