import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/dialogs/error_detail_dialog.dart';

void main() {
  group('DataDetailDialog (renamed from ErrorDetailDialog)', () {
    testWidgets('shows message when no request/response data', (tester) async {
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

      expect(find.text('数据详情'), findsOneWidget);
      expect(find.text('No detail data available'), findsOneWidget);
    });

    testWidgets('shows item list when data is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {
                  'url': 'https://api.example.com/chat',
                  'headers': {'Authorization': 'Bearer sk-test'},
                  'body': {'model': 'gpt-4', 'messages': []},
                },
                rawResponse: {
                  'statusCode': 401,
                  'headers': {
                    'content-type': ['application/json'],
                    'x-request-id': ['req-001'],
                  },
                  'data': {
                    'error': {'message': 'Unauthorized'},
                  },
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Title should be visible
      expect(find.text('数据详情'), findsOneWidget);
      // All item labels should be visible
      expect(find.text('Request URL'), findsOneWidget);
      expect(find.text('Request Headers'), findsOneWidget);
      expect(find.text('Request Body'), findsOneWidget);
      expect(find.text('Status Code'), findsOneWidget);
      expect(find.text('Response Headers'), findsOneWidget);
      expect(find.text('Response Body'), findsOneWidget);
    });

    testWidgets('tapping Request URL shows detail and back button works', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'statusCode': 401,
                  'data': {'error': 'Unauthorized'},
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Tap Request URL
      await tester.tap(find.text('Request URL'));
      await tester.pumpAndSettle();

      // Should show the URL value and back button
      expect(find.text('https://api.example.com/chat'), findsOneWidget);
      // Section label appears in both header title and detail body label
      expect(find.text('Request URL'), findsAtLeastNWidgets(1));

      // Back button should be visible
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Tap back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should be back to list
      expect(find.text('Request URL'), findsOneWidget);
      expect(find.text('Status Code'), findsOneWidget);
    });

    testWidgets('tapping Response Headers shows headers as JSON', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'statusCode': 401,
                  'headers': {
                    'content-type': ['application/json'],
                    'x-request-id': ['req-001'],
                  },
                  'data': {'error': 'Unauthorized'},
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Tap Response Headers
      await tester.tap(find.text('Response Headers'));
      await tester.pumpAndSettle();

      // Should show the headers JSON
      // Label appears in both header title and detail body label
      expect(find.text('Response Headers'), findsAtLeastNWidgets(1));
      expect(find.textContaining('content-type'), findsOneWidget);
      expect(find.textContaining('x-request-id'), findsOneWidget);
    });

    testWidgets('tapping Response Body shows data as JSON', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'statusCode': 200,
                  'headers': {},
                  'data': {
                    'choices': [
                      {
                        'message': {'content': 'Hello'},
                      },
                    ],
                  },
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Tap Response Body
      await tester.tap(find.text('Response Body'));
      await tester.pumpAndSettle();

      // Should show the data JSON
      expect(find.text('Response Body'), findsAtLeastNWidgets(1));
      expect(find.textContaining('choices'), findsOneWidget);
      expect(find.textContaining('Hello'), findsOneWidget);
    });

    testWidgets('tapping Request Headers shows headers as JSON', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {
                  'url': 'https://api.example.com',
                  'headers': {
                    'Authorization': 'Bearer sk-test-key',
                    'Content-Type': 'application/json',
                  },
                },
                rawResponse: {'statusCode': 200},
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Tap Request Headers
      await tester.tap(find.text('Request Headers'));
      await tester.pumpAndSettle();

      // Should show the headers JSON
      expect(find.textContaining('Authorization'), findsOneWidget);
      expect(find.textContaining('Content-Type'), findsOneWidget);
    });

    testWidgets('Response Body shows when data is a Map', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'statusCode': 400,
                  'headers': {
                    'content-type': ['application/json'],
                  },
                  'data': {
                    'error': {'message': 'Bad Request'},
                  },
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Response Body'), findsOneWidget);

      // Tap Response Body to see detail
      await tester.tap(find.text('Response Body'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bad Request'), findsOneWidget);
    });

    testWidgets('Response Body shows when data has raw key (string body)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'statusCode': 400,
                  'headers': {
                    'content-type': ['application/json'],
                  },
                  'data': {'raw': '{"error":"bad request"}'},
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Response Body'), findsOneWidget);

      // Tap Response Body to see detail
      await tester.tap(find.text('Response Body'));
      await tester.pumpAndSettle();

      expect(find.textContaining('bad request'), findsOneWidget);
    });

    testWidgets('Response Body hidden when data key is absent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'statusCode': 400,
                  'headers': {
                    'content-type': ['application/json'],
                  },
                  // no 'data' key
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Response Body'), findsNothing);
      expect(find.text('Response Headers'), findsOneWidget);
      expect(find.text('Status Code'), findsOneWidget);
    });

    testWidgets('Response Headers shows all header keys as-is', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'statusCode': 200,
                  'headers': {
                    'content-type': ['application/json'],
                    'x-request-id': ['req-001'],
                    'x-ratelimit-remaining': ['99'],
                  },
                  'data': {'ok': true},
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Response Headers'));
      await tester.pumpAndSettle();

      // All header keys should be visible
      expect(find.textContaining('content-type'), findsOneWidget);
      expect(find.textContaining('x-request-id'), findsOneWidget);
      expect(find.textContaining('x-ratelimit-remaining'), findsOneWidget);
      // Header values should be visible
      expect(find.textContaining('application/json'), findsOneWidget);
      expect(find.textContaining('req-001'), findsOneWidget);
    });

    testWidgets('network error shows Error item instead of response sections', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'error': 'DioException [connectionError]: Failed to connect',
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Network error should show Error item
      expect(find.text('Error'), findsOneWidget);
      // Response sections should NOT be visible
      expect(find.text('Status Code'), findsNothing);
      expect(find.text('Response Headers'), findsNothing);
      expect(find.text('Response Body'), findsNothing);
    });

    testWidgets('network error detail view shows error string', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'error': 'DioException [connectionError]: Failed to connect',
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Tap the Error section
      await tester.tap(find.text('Error'));
      await tester.pumpAndSettle();

      // Should show the error message in detail
      expect(find.textContaining('DioException'), findsOneWidget);
      expect(find.textContaining('Failed to connect'), findsOneWidget);
    });

    testWidgets(
      'request/response items hidden when data not present in section',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showErrorDetailDialog(
                  context: context,
                  rawRequest: {'url': 'https://api.example.com'},
                  // no headers or body
                  rawResponse: {'statusCode': 200},
                  // no headers or data
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // URL and Status Code should be visible
        expect(find.text('Request URL'), findsOneWidget);
        expect(find.text('Status Code'), findsOneWidget);

        // Items without data should NOT be shown
        expect(find.text('Request Headers'), findsNothing);
        expect(find.text('Request Body'), findsNothing);
        expect(find.text('Response Headers'), findsNothing);
        expect(find.text('Response Body'), findsNothing);
      },
    );

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

      expect(find.widgetWithText(OutlinedButton, '关闭'), findsOneWidget);
    });

    testWidgets('close button dismisses dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com'},
                rawResponse: {'statusCode': 200},
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('数据详情'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, '关闭'));
      await tester.pumpAndSettle();

      expect(find.text('数据详情'), findsNothing);
    });

    testWidgets('Status Code detail shows the numeric code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com'},
                rawResponse: {'statusCode': 429},
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Status Code'));
      await tester.pumpAndSettle();

      expect(find.text('429'), findsOneWidget);
    });

    testWidgets('Request Body detail shows formatted JSON', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {
                  'url': 'https://api.example.com',
                  'body': {'model': 'gpt-4', 'temperature': 0.7},
                },
                rawResponse: {'statusCode': 200},
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Request Body'));
      await tester.pumpAndSettle();

      expect(find.textContaining('gpt-4'), findsOneWidget);
      expect(find.textContaining('0.7'), findsOneWidget);
    });

    testWidgets('multiple back/forth navigation works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {
                  'url': 'https://api.example.com',
                  'headers': {'Authorization': 'Bearer x'},
                },
                rawResponse: {
                  'statusCode': 401,
                  'data': {'error': 'Unauthorized'},
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Go to Request URL
      await tester.tap(find.text('Request URL'));
      await tester.pumpAndSettle();
      expect(find.text('https://api.example.com'), findsOneWidget);

      // Back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Request Headers'), findsOneWidget);

      // Go to Status Code
      await tester.tap(find.text('Status Code'));
      await tester.pumpAndSettle();
      expect(find.text('401'), findsOneWidget);

      // Back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Request URL'), findsOneWidget);
    });

    // ── NEW TESTS for the renamed/updated dialog ──

    testWidgets(
      'shows message content section when messageContent is provided',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showErrorDetailDialog(
                  context: context,
                  rawRequest: {'url': 'https://api.example.com/chat'},
                  rawResponse: {'statusCode': 200},
                  messageContent: '这是助手回复的内容',
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Message content section should be visible
        expect(find.text('消息内容'), findsOneWidget);
      },
    );

    testWidgets(
      'message content section shows the actual message text when tapped',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showErrorDetailDialog(
                  context: context,
                  rawRequest: {'url': 'https://api.example.com/chat'},
                  rawResponse: {'statusCode': 200},
                  messageContent: '这是助手回复的内容',
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Tap 消息内容 section
        await tester.tap(find.text('消息内容'));
        await tester.pumpAndSettle();

        // Should show the message text in detail
        expect(find.text('这是助手回复的内容'), findsOneWidget);
      },
    );

    testWidgets('message content section is hidden when not provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {'statusCode': 200},
                // no messageContent
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Message content section should NOT be visible
      expect(find.text('消息内容'), findsNothing);
    });
    testWidgets('dialog title defaults to 数据详情', (tester) async {
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

      expect(find.text('数据详情'), findsOneWidget);
      // Old title should NOT be present
      expect(find.text('Error Details'), findsNothing);
    });

    testWidgets('empty messageContent string hides the section like null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {'statusCode': 200},
                messageContent: '',
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Empty string should NOT show the message content section
      expect(find.text('消息内容'), findsNothing);
    });

    testWidgets('header shows info_outline and grey styling when no error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {'statusCode': 200},
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Should use info_outline for non-error data (header + Status Code section icon)
      expect(find.byIcon(Icons.info_outline), findsAtLeastNWidgets(1));
      // Should NOT use error_outline
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('header shows error_outline and red styling when network error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'error': 'DioException [connectionError]: Failed to connect',
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Should show error_outline (header + Error section list tile)
      expect(find.byIcon(Icons.error_outline), findsWidgets);
    });
  });
}
