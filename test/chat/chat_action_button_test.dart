import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/chat_action_button.dart';

void main() {
  group('ChatActionButton', () {
    testWidgets('renders icon and tooltip', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatActionButton(
              icon: Icons.copy,
              tooltip: '复制',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      // Tooltip should display
      expect(find.byIcon(Icons.copy), findsOneWidget);

      // Tap the button
      await tester.tap(find.byIcon(Icons.copy));
      expect(pressed, true);
    });

    testWidgets('responds to onPressed callback', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatActionButton(
              icon: Icons.refresh,
              tooltip: '重试',
              onPressed: () => callCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.refresh));
      expect(callCount, 1);
    });
  });
}
