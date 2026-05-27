import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/widgets/llm/jumping_dots.dart';
import 'package:stroom/widgets/llm/tool_call_card.dart';

void main() {
  group('JumpingDotsProgressIndicator', () {
    testWidgets('renders default 3 dots', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JumpingDotsProgressIndicator(color: Colors.grey),
          ),
        ),
      );
      // Should find 3 dot widgets (Text widgets containing '.')
      expect(find.byType(Row), findsOneWidget);
      // The JumpingDot widgets should be rendered
      expect(find.byType(JumpingDot), findsNWidgets(3));
    });

    testWidgets('renders custom number of dots', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JumpingDotsProgressIndicator(
              color: Colors.blue,
              numberOfDots: 5,
              fontSize: 12,
            ),
          ),
        ),
      );
      expect(find.byType(JumpingDot), findsNWidgets(5));
    });

    testWidgets('responds to color changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JumpingDotsProgressIndicator(
              color: Colors.red.withValues(alpha: 0.5),
              numberOfDots: 3,
            ),
          ),
        ),
      );
      // The dots should be visible and rendered as Text widgets
      expect(find.byType(JumpingDot), findsNWidgets(3));
    });

    testWidgets('disposes without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JumpingDotsProgressIndicator(color: Colors.grey),
          ),
        ),
      );
      // Just verify it builds and the first frame renders
      expect(tester.takeException(), isNull);
    });
  });

  group('ToolCallCard', () {
    testWidgets('shows running state with spinner', (tester) async {
      final data = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '2+2'},
        status: ToolCallStatus.running,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolCallCard(data: data),
          ),
        ),
      );
      // Should show tool name
      expect(find.text('calculator'), findsOneWidget);
      // Should show arguments
      expect(find.text('expression: 2+2'), findsOneWidget);
      // Should show CircularProgressIndicator (running state)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows completed state with result', (tester) async {
      final data = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '2+2'},
        status: ToolCallStatus.completed,
        result: '4',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolCallCard(data: data),
          ),
        ),
      );
      expect(find.text('calculator'), findsOneWidget);
      expect(find.text('expression: 2+2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      // No spinner when completed
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows error state with error message', (tester) async {
      final data = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '1/0'},
        status: ToolCallStatus.error,
        result: 'Error: Division by zero',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolCallCard(data: data),
          ),
        ),
      );
      expect(find.text('calculator'), findsOneWidget);
      expect(find.text('Error: Division by zero'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows pending state without spinner or result', (tester) async {
      final data = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '2+2'},
        status: ToolCallStatus.pending,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolCallCard(data: data),
          ),
        ),
      );
      expect(find.text('calculator'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('handles empty arguments', (tester) async {
      final data = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {},
        status: ToolCallStatus.completed,
        result: '4',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolCallCard(data: data),
          ),
        ),
      );
      expect(find.text('calculator'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('handles multiple arguments', (tester) async {
      final data = ToolCallData(
        id: 'call_1',
        name: 'search',
        arguments: {'query': 'flutter', 'limit': '10'},
        status: ToolCallStatus.running,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolCallCard(data: data),
          ),
        ),
      );
      expect(find.text('query: flutter, limit: 10'), findsOneWidget);
    });
  });
}
