import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/widgets/action_button.dart';

void main() {
  group('ActionButton', () {
    testWidgets('renders with icon and tooltip', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButton(
              icon: Icons.copy,
              tooltip: '复制',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('triggers onPressed when tapped', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButton(
              icon: Icons.copy,
              tooltip: '复制',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.copy));
      expect(pressed, isTrue);
    });
  });
}
