import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/dialogs/error_detail_dialog.dart';

void main() {
  group('ErrorDetailDialog', () {
    testWidgets('shows message when no request data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: null,
                rawResponse: null,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('错误详情'), findsOneWidget);
      expect(find.text('无详细数据'), findsOneWidget);
    });

    testWidgets('shows request and response data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com'},
                rawResponse: {'statusCode': 500},
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Title should be visible
      expect(find.text('错误详情'), findsOneWidget);
      // JSON data labels should be visible
      expect(find.textContaining('Request'), findsWidgets);
      expect(find.textContaining('Response'), findsWidgets);
    });

    testWidgets('has a close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: null,
                rawResponse: null,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Find the close button
      expect(find.widgetWithText(OutlinedButton, '关闭'), findsOneWidget);
    });
  });
}
