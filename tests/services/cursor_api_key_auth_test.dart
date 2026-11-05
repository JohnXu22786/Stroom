import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/cursor_api_key_auth.dart';

class _ExchangeAdapter implements HttpClientAdapter {
  final int statusCode;
  final String body;
  final Object? failure;
  final Duration delay;
  final Completer<void> firstRequest = Completer<void>();
  final Completer<void> secondRequest = Completer<void>();
  final Completer<void>? firstGate;
  RequestOptions? request;
  var calls = 0;

  _ExchangeAdapter({
    this.statusCode = 200,
    this.body = '{"accessToken":"session"}',
    this.failure,
    this.delay = Duration.zero,
    this.firstGate,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    request = options;
    if (!firstRequest.isCompleted) firstRequest.complete();
    if (calls == 2 && !secondRequest.isCompleted) secondRequest.complete();
    if (calls == 1 && firstGate != null) await firstGate!.future;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    if (requestStream != null) {
      await for (final _ in requestStream) {}
    }
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  tearDown(CursorApiKeyAuth.resetForTesting);

  test('accepts source key prefixes and rejects other values', () {
    expect(CursorApiKeyAuth.isApiKey('crsr_user'), isTrue);
    expect(CursorApiKeyAuth.isApiKey('grok_user'), isTrue);
    expect(CursorApiKeyAuth.isApiKey('cursor-token'), isFalse);
  });

  test('exchanges by POST to fixed endpoint with bearer and empty JSON body',
      () async {
    final adapter = _ExchangeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final token =
        await CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio);

    expect(token, 'session');
    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.uri.toString(), cursorApiKeyExchangeUrl);
    expect(adapter.request?.headers['Authorization'], 'Bearer crsr_secret');
    expect(adapter.request?.headers['Accept'], 'application/json');
    expect(adapter.request?.contentType, Headers.jsonContentType);
    expect(adapter.request!.data, <String, Object?>{});
  });

  test('caches an exchanged token without storing it as the user key',
      () async {
    final adapter = _ExchangeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final first =
        await CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio);
    final second =
        await CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio);

    expect(first, 'session');
    expect(second, first);
    expect(adapter.calls, 1);
  });

  test('shares one in-flight exchange for concurrent requests', () async {
    final adapter = _ExchangeAdapter(delay: const Duration(milliseconds: 20));
    final dio = Dio()..httpClientAdapter = adapter;
    final tokens = await Future.wait([
      CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio),
      CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio),
      CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio),
    ]);

    expect(adapter.calls, 1);
    expect(tokens.toSet(), {'session'});
  });

  test('one canceled waiter does not cancel another shared exchange', () async {
    final adapter = _ExchangeAdapter(delay: const Duration(milliseconds: 20));
    final dio = Dio()..httpClientAdapter = adapter;
    final firstCancelToken = CancelToken();
    final first = CursorApiKeyAuth.resolveAccessToken(
      'crsr_secret',
      dio: dio,
      cancelToken: firstCancelToken,
    );
    final second = CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio);
    firstCancelToken.cancel('caller stopped');

    await expectLater(first, throwsA(isA<DioException>()));
    expect(await second, 'session');
    expect(adapter.calls, 1);
  });

  test('new caller starts a fresh exchange after the final waiter cancels',
      () async {
    final firstGate = Completer<void>();
    final adapter = _ExchangeAdapter(firstGate: firstGate);
    final dio = Dio()..httpClientAdapter = adapter;
    final cancelToken = CancelToken();
    final canceled = CursorApiKeyAuth.resolveAccessToken(
      'crsr_secret',
      dio: dio,
      cancelToken: cancelToken,
    );
    await adapter.firstRequest.future;
    cancelToken.cancel('caller stopped');
    await expectLater(canceled, throwsA(isA<DioException>()));

    final replacement =
        CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio);
    await adapter.secondRequest.future;
    expect(adapter.calls, 2);
    firstGate.complete();
    expect(await replacement, 'session');
    expect(
      await CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio),
      'session',
    );
    expect(adapter.calls, 2);
  });

  test('turns rejected and malformed exchange responses into safe errors',
      () async {
    final rejected = Dio()
      ..httpClientAdapter = _ExchangeAdapter(
        statusCode: 401,
        body: '{"message":"secret response"}',
      );
    await expectLater(
      CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: rejected),
      throwsA(isA<CursorApiKeyAuthException>()
          .having((error) => error.code, 'code', 'api_key_rejected')),
    );

    final malformed = Dio()
      ..httpClientAdapter =
          _ExchangeAdapter(body: '{"refreshToken":"temporary"}');
    await expectLater(
      CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: malformed),
      throwsA(isA<CursorApiKeyAuthException>().having(
          (error) => error.code, 'code', 'malformed_exchange_response')),
    );
  });

  test('re-exchanges JWT sessions inside the five minute expiry skew',
      () async {
    final now = DateTime.utc(2026, 11, 5, 12);
    final expiry =
        now.add(const Duration(minutes: 3)).millisecondsSinceEpoch ~/ 1000;
    final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': expiry})));
    final token = 'header.${base64Url.normalize(payload)}.signature';
    final adapter = _ExchangeAdapter(body: jsonEncode({'accessToken': token}));
    final dio = Dio()..httpClientAdapter = adapter;

    await CursorApiKeyAuth.resolveAccessToken(
      'crsr_secret',
      dio: dio,
      now: () => now,
    );
    await CursorApiKeyAuth.resolveAccessToken(
      'crsr_secret',
      dio: dio,
      now: () => now,
    );

    expect(adapter.calls, 2);
  });

  test('invalidation re-exchanges a rejected session with the stored key',
      () async {
    final adapter = _ExchangeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    await CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio);
    CursorApiKeyAuth.invalidate('crsr_secret');

    expect(
      await CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio),
      'session',
    );
    expect(adapter.calls, 2);
  });

  test('retries one Cursor chat 401 after invalidating the cached session',
      () async {
    final adapter = _ExchangeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    await CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio);

    expect(
      CursorApiKeyAuth.retryAfterUnauthorizedResponse(
        'crsr_secret',
        statusCode: 401,
        alreadyRetried: false,
      ),
      isTrue,
    );
    await CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio);
    expect(
      CursorApiKeyAuth.retryAfterUnauthorizedResponse(
        'crsr_secret',
        statusCode: 401,
        alreadyRetried: true,
      ),
      isFalse,
    );
    await CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: dio);
    expect(adapter.calls, 3);
  });

  test('redacts network and server failures and preserves cancellation',
      () async {
    final server = Dio()
      ..httpClientAdapter = _ExchangeAdapter(
        statusCode: 503,
        body: '{"message":"secret response"}',
      );
    await expectLater(
      CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: server),
      throwsA(isA<CursorApiKeyAuthException>()
          .having((error) => error.code, 'code', 'exchange_failed')),
    );

    final network = Dio()
      ..httpClientAdapter = _ExchangeAdapter(
        failure: DioException.connectionError(
          requestOptions: RequestOptions(path: cursorApiKeyExchangeUrl),
          reason: 'secret response',
        ),
      );
    await expectLater(
      CursorApiKeyAuth.resolveAccessToken('crsr_secret', dio: network),
      throwsA(isA<CursorApiKeyAuthException>()
          .having((error) => error.code, 'code', 'exchange_failed')),
    );

    final cancelToken = CancelToken()..cancel('cancelled');
    await expectLater(
      CursorApiKeyAuth.resolveAccessToken(
        'crsr_secret',
        dio: Dio(),
        cancelToken: cancelToken,
      ),
      throwsA(isA<DioException>()),
    );
  });

  test('bounds a stalled exchange', () async {
    final dio = Dio()
      ..httpClientAdapter = _ExchangeAdapter(
        delay: const Duration(milliseconds: 100),
      );
    await expectLater(
      CursorApiKeyAuth.resolveAccessToken(
        'crsr_secret',
        dio: dio,
        timeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<CursorApiKeyAuthException>()
          .having((error) => error.code, 'code', 'exchange_failed')),
    );
  });
}
