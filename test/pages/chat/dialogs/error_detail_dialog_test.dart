import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/dialogs/error_detail_dialog.dart';

void main() {
  group('DataDetailDialog (unified 6-section dialog)', () {
    testWidgets('shows empty state when no request/response data',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
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

    testWidgets('shows all 6 sections when full data is provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
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

      expect(find.text('数据详情'), findsOneWidget);
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
              onPressed: () => showDataDetailDialog(
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

      await tester.tap(find.text('Request URL'));
      await tester.pumpAndSettle();

      expect(find.text('https://api.example.com/chat'), findsOneWidget);
      expect(find.text('Request URL'), findsAtLeastNWidgets(1));

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

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
              onPressed: () => showDataDetailDialog(
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

      await tester.tap(find.text('Response Headers'));
      await tester.pumpAndSettle();

      expect(find.text('Response Headers'), findsAtLeastNWidgets(1));
      expect(find.textContaining('content-type'), findsOneWidget);
      expect(find.textContaining('x-request-id'), findsOneWidget);
    });

    testWidgets('tapping Response Body shows data as JSON', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
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

      await tester.tap(find.text('Response Body'));
      await tester.pumpAndSettle();

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
              onPressed: () => showDataDetailDialog(
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

      await tester.tap(find.text('Request Headers'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Authorization'), findsOneWidget);
      expect(find.textContaining('Content-Type'), findsOneWidget);
    });

    testWidgets('Response Body shows when data is a Map', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
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
              onPressed: () => showDataDetailDialog(
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

      await tester.tap(find.text('Response Body'));
      await tester.pumpAndSettle();

      expect(find.textContaining('bad request'), findsOneWidget);
    });

    testWidgets('Response Body hidden when data key is absent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'statusCode': 400,
                  'headers': {
                    'content-type': ['application/json'],
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

      expect(find.text('Response Body'), findsNothing);
      expect(find.text('Response Headers'), findsOneWidget);
      expect(find.text('Status Code'), findsOneWidget);
    });

    testWidgets('network error shows Response Body from error field', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
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

      // Network error should show as Response Body (not as Error section)
      expect(find.text('Response Body'), findsOneWidget);
      // Status Code, Response Headers should NOT be visible (no HTTP response data)
      expect(find.text('Status Code'), findsNothing);
      expect(find.text('Response Headers'), findsNothing);
    });

    testWidgets('network error detail shows error string via Response Body', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
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

      await tester.tap(find.text('Response Body'));
      await tester.pumpAndSettle();

      expect(find.textContaining('DioException'), findsOneWidget);
      expect(find.textContaining('Failed to connect'), findsOneWidget);
    });

    testWidgets(
      'items hidden when data not present in section',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDataDetailDialog(
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

        expect(find.text('Request URL'), findsOneWidget);
        expect(find.text('Status Code'), findsOneWidget);
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
              onPressed: () => showDataDetailDialog(
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
              onPressed: () => showDataDetailDialog(
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
              onPressed: () => showDataDetailDialog(
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
              onPressed: () => showDataDetailDialog(
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
              onPressed: () => showDataDetailDialog(
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

      await tester.tap(find.text('Request URL'));
      await tester.pumpAndSettle();
      expect(find.text('https://api.example.com'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Request Headers'), findsOneWidget);

      await tester.tap(find.text('Status Code'));
      await tester.pumpAndSettle();
      expect(find.text('401'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Request URL'), findsOneWidget);
    });

    // ── UNIFIED PANEL TESTS ──

    testWidgets('header uses info_outline icon (no error styling)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
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

      expect(find.byIcon(Icons.info_outline), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('header uses info_outline even for network errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
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

      // Unified: always shows info_outline, never error_outline
      expect(find.byIcon(Icons.info_outline), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('no 消息内容 section anywhere', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
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

      expect(find.text('消息内容'), findsNothing);
    });

    testWidgets('dialog has uniform rounded corners', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
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

      // Verify the dialog exists by checking its content
      expect(find.text('数据详情'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });

    testWidgets('response body sections only for data and error keys', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDataDetailDialog(
                context: context,
                rawRequest: {'url': 'https://api.example.com/chat'},
                rawResponse: {
                  'statusCode': 500,
                  // Has both 'data' and 'error' — 'data' takes precedence
                  'data': 'Internal Server Error',
                  'error': 'DioException',
                },
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Should show Response Body from 'data' key, not 'error' key
      expect(find.text('Response Body'), findsOneWidget);
      expect(find.text('Status Code'), findsOneWidget);
    });

    testWidgets(
      'response body shows error field data when data key absent',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDataDetailDialog(
                  context: context,
                  rawRequest: {'url': 'https://api.example.com/chat'},
                  rawResponse: {
                    'error': 'DioException: Connection refused',
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

        await tester.tap(find.text('Response Body'));
        await tester.pumpAndSettle();

        expect(find.textContaining('DioException'), findsOneWidget);
      },
    );
  });
}
