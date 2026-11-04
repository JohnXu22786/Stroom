import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/trae_solo_connector.dart';

void main() {
  group('Trae SOLO token import', () {
    test('accepts Cloud-IDE-JWT header value and applies source defaults', () {
      final credential = TraeSoloCredential.fromPastedValue(
        'Cloud-IDE-JWT ${_jwt({'web_id': 'web-1', 'biz_user_id': 'biz-2'})}',
        now: DateTime.utc(2026, 1, 1),
      );

      expect(credential.accessToken, startsWith('ey'));
      expect(credential.expiresAt, DateTime.utc(2026, 1, 15));
      expect(credential.identity['webId'], 'web-1');
      expect(credential.identity['bizUserId'], 'biz-2');
      expect(credential.identity['tenant'], 'marscode');
    });

    test('uses a token expiry claim and rejects empty or malformed values', () {
      final expiresAt = DateTime.utc(2026, 2, 3);
      final credential = TraeSoloCredential.fromPastedValue(
        _jwt({'exp': expiresAt.millisecondsSinceEpoch ~/ 1000}),
        now: DateTime.utc(2026, 1, 1),
      );

      expect(credential.expiresAt, expiresAt);
      expect(
        () => TraeSoloCredential.fromPastedValue(' '),
        throwsFormatException,
      );
      expect(
        () => TraeSoloCredential.fromPastedValue('Bearer abc'),
        throwsFormatException,
      );
    });

    test('keeps the 14-day fallback expiry across app restarts', () {
      final importedAt = DateTime.utc(2026, 1, 1);
      final imported = TraeSoloCredential.fromPastedValue(
        _jwt(const {}),
        now: importedAt,
      );
      final stored = TraeSoloCredential.fromPastedValue(
        imported.toStoredValue(),
        now: importedAt.add(const Duration(days: 20)),
      );

      expect(stored.expiresAt, importedAt.add(const Duration(days: 14)));
      expect(
        stored.expiresAt.isAfter(importedAt.add(const Duration(days: 20))),
        isFalse,
      );
    });
  });

  test('builds source model and session routes with text-only messages', () {
    expect(
      TraeSoloConnector.modelsUri.toString(),
      'https://core-normal.trae.ai/api/remote/v1/models?functions=solo_agent_remote,solo_work_remote',
    );
    final request = TraeSoloConnector.createSessionRequest(
      modelId: 'gemini-3.1-pro',
      messages: const [
        {'role': 'system', 'content': 'Be concise'},
        {'role': 'user', 'content': 'Hello'},
      ],
      identity: const {},
    );
    expect(request['mode'], 'code');
    final initial = request['initial_message'] as Map;
    expect(initial['model_name'], 'gemini-3.1-pro');
    expect(initial['agent_type'], 'solo_agent_remote');
    expect(jsonDecode(initial['query'] as String), [
      {
        'type': 'text',
        'data': {'content': '[System]\nBe concise\n\nHello'},
      },
    ]);
  });

  test(
    'deduplicates cumulative plan item text and stops on terminal events',
    () {
      final mapper = TraeSoloEventMapper();
      expect(mapper.accept('plan_item', {'id': 'p1', 'thought': 'Hel'}), 'Hel');
      expect(
        mapper.accept('plan_item', {'id': 'p1', 'thought': 'Hello'}),
        'lo',
      );
      expect(mapper.accept('token_usage', {'total_tokens': 2}), isEmpty);
      expect(mapper.accept('done', const {}), isEmpty);
      expect(mapper.isDone, isTrue);
      expect(mapper.text, 'Hello');
    },
  );

  test('rejects non-text message parts rather than claiming media support', () {
    expect(
      () => TraeSoloConnector.createSessionRequest(
        modelId: 'auto',
        messages: const [
          {
            'role': 'user',
            'content': [
              {'type': 'image_url'},
            ],
          },
        ],
        identity: const {},
      ),
      throwsFormatException,
    );
  });

  test('rejects legacy function messages and function-call payloads', () {
    expect(
      () => TraeSoloConnector.createSessionRequest(
        modelId: 'auto',
        messages: const [
          {'role': 'function', 'name': 'lookup', 'content': 'result'},
        ],
        identity: const {},
      ),
      throwsFormatException,
    );
    expect(
      () => TraeSoloConnector.createSessionRequest(
        modelId: 'auto',
        messages: const [
          {'role': 'assistant', 'content': 'hello', 'function_call': {}},
        ],
        identity: const {},
      ),
      throwsFormatException,
    );
  });

  test(
    'HTTP adapter creates a SOLO session and maps SSE to chat completion',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final requests = <String>[];
      final subscription = server.listen((request) async {
        requests.add(
          '${request.method} ${request.uri.path}${request.uri.query.isEmpty ? '' : '?${request.uri.query}'}',
        );
        expect(
          request.headers.value('authorization'),
          startsWith('Cloud-IDE-JWT '),
        );
        if (request.uri.path.endsWith('/chat_sessions')) {
          await request.drain<void>();
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'code': 0,
              'data': {
                'chat_session_id': 'session-1',
                'message_id': 'message-1',
              },
            }),
          );
        } else {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'event: plan_item\ndata: {"id":"p1","thought":"hello"}\n\n'
            'event: done\ndata: {}\n\n',
          );
        }
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      final adapter = TraeSoloHttpAdapter(Dio());
      final result = await adapter.request(
        baseUrl: 'http://127.0.0.1:${server.port}/api/remote/v1',
        credential: _jwt(const {}),
        modelId: 'auto',
        messages: const [
          {'role': 'user', 'content': 'hi'},
        ],
        stream: false,
        cancelToken: null,
      );

      expect(requests, [
        'POST /api/remote/v1/chat_sessions',
        'GET /api/remote/v1/chat_sessions/session-1/events?reply_to_message_id=message-1',
      ]);
      final decoded = result.body as Map;
      expect((decoded['choices'] as List).first['message']['content'], 'hello');
    },
  );

  test(
    'HTTP adapter exposes upstream event errors and honors cancellation',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final subscription = server.listen((request) async {
        if (request.uri.path.endsWith('/chat_sessions')) {
          await request.drain<void>();
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            '{"code":0,"data":{"chat_session_id":"s","message_id":"m"}}',
          );
        } else {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'event: error\ndata: {"code":"busy","message":"try again"}\n\n',
          );
        }
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      final adapter = TraeSoloHttpAdapter(Dio());
      final result = await adapter.request(
        baseUrl: 'http://127.0.0.1:${server.port}/api',
        credential: _jwt(const {}),
        modelId: 'auto',
        messages: const [
          {'role': 'user', 'content': 'hi'},
        ],
        stream: true,
        cancelToken: null,
      );
      await expectLater(
        (result.body as Stream<List<int>>).drain<void>(),
        throwsA(isA<TraeSoloUpstreamException>()),
      );

      final cancelled = CancelToken()..cancel('test cancellation');
      await expectLater(
        adapter.request(
          baseUrl: 'http://127.0.0.1:${server.port}/api',
          credential: _jwt(const {}),
          modelId: 'auto',
          messages: const [
            {'role': 'user', 'content': 'hi'},
          ],
          stream: false,
          cancelToken: cancelled,
        ),
        throwsA(isA<DioException>()),
      );
    },
  );

  test('HTTP adapter rejects event streams that end before done', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final subscription = server.listen((request) async {
      if (request.uri.path.endsWith('/chat_sessions')) {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          '{"code":0,"data":{"chat_session_id":"s","message_id":"m"}}',
        );
      } else {
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'event: plan_item\ndata: {"id":"p1","thought":"partial"}\n\n',
        );
      }
      await request.response.close();
    });
    addTearDown(subscription.cancel);
    final adapter = TraeSoloHttpAdapter(Dio());

    final streamed = await adapter.request(
      baseUrl: 'http://127.0.0.1:${server.port}/api',
      credential: _jwt(const {}),
      modelId: 'auto',
      messages: const [
        {'role': 'user', 'content': 'hi'},
      ],
      stream: true,
      cancelToken: null,
    );
    await expectLater(
      (streamed.body as Stream<List<int>>).drain<void>(),
      throwsA(isA<TraeSoloUpstreamException>()),
    );

    await expectLater(
      adapter.request(
        baseUrl: 'http://127.0.0.1:${server.port}/api',
        credential: _jwt(const {}),
        modelId: 'auto',
        messages: const [
          {'role': 'user', 'content': 'hi'},
        ],
        stream: false,
        cancelToken: null,
      ),
      throwsA(isA<TraeSoloUpstreamException>()),
    );
  });

  test(
    'HTTP adapter marks a request sent before opening the event stream',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      var requestMarkedSent = false;
      var wasMarkedAtEventsRequest = false;
      final subscription = server.listen((request) async {
        if (request.uri.path.endsWith('/chat_sessions')) {
          await request.drain<void>();
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            '{"code":0,"data":{"chat_session_id":"s","message_id":"m"}}',
          );
        } else {
          wasMarkedAtEventsRequest = requestMarkedSent;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write('event: done\ndata: {}\n\n');
        }
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      final result = await TraeSoloHttpAdapter(Dio()).request(
        baseUrl: 'http://127.0.0.1:${server.port}/api',
        credential: _jwt(const {}),
        modelId: 'auto',
        messages: const [
          {'role': 'user', 'content': 'hi'},
        ],
        stream: false,
        cancelToken: null,
        onRequestSent: () async => requestMarkedSent = true,
      );

      expect(wasMarkedAtEventsRequest, isTrue);
      expect((result.body as Map)['choices'], isNotEmpty);
    },
  );
}

String _jwt(Map<String, Object?> claims) =>
    'eyJhbGciOiJSUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.signature';
