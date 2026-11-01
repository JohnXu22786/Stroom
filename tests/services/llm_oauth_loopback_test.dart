import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/llm_oauth_loopback.dart';

void main() {
  test('serves localhost OAuth callbacks on IPv4 and IPv6 loopback', () async {
    final listener = await LlmOAuthLoopback.bind(
      '/callback',
      host: 'localhost',
      port: 0,
    );
    final client = HttpClient();
    try {
      expect(listener.redirectUri.host, 'localhost');
      for (final host in ['127.0.0.1', '::1']) {
        final callbackFuture = listener.nextCallback();
        final callbackUri = Uri(
          scheme: 'http',
          host: host,
          port: listener.redirectUri.port,
          path: '/callback',
          queryParameters: {'code': 'loopback-code', 'state': 'loopback-state'},
        );
        final request = await client.getUrl(callbackUri);
        final responseFuture = request.close();

        final callback = await callbackFuture;
        expect(callback.host, 'localhost');
        expect(callback.path, '/callback');
        await listener.respond(accepted: true);
        expect((await responseFuture).statusCode, HttpStatus.ok);
      }
    } finally {
      client.close(force: true);
      await listener.close();
    }
  });

  test(
    'queues a callback that arrives before the waiter is installed',
    () async {
      final listener = await LlmOAuthLoopback.bind('/auth/callback');
      final client = HttpClient();
      try {
        final callbackUri = listener.redirectUri.replace(
          queryParameters: {'code': 'private-code', 'state': 'private-state'},
        );
        final request = await client.getUrl(callbackUri);
        final responseFuture = request.close();

        final callback = await listener.nextCallback();

        expect(callback.path, '/auth/callback');
        expect(callback.queryParameters['code'], 'private-code');
        await listener.respond(accepted: true);
        final response = await responseFuture;
        expect(response.statusCode, HttpStatus.ok);
        final body = await utf8.decoder.bind(response).join();
        expect(body, isNot(contains('private-code')));
        expect(body, isNot(contains('private-state')));
      } finally {
        client.close(force: true);
        await listener.close();
      }
    },
  );

  test(
    'accepts only loopback GET callback and does not echo its query',
    () async {
      final listener = await LlmOAuthLoopback.bind('/auth/callback');
      final client = HttpClient();
      try {
        final post = await client.postUrl(listener.redirectUri);
        final postResponse = await post.close();
        expect(postResponse.statusCode, HttpStatus.methodNotAllowed);
        await postResponse.drain<void>();

        final callbackFuture = listener.nextCallback();
        final unrelatedRequest = await client.getUrl(
          listener.redirectUri.replace(path: '/unrelated'),
        );
        final unrelatedResponse = await unrelatedRequest.close();
        expect(unrelatedResponse.statusCode, HttpStatus.notFound);
        await unrelatedResponse.drain<void>();

        final callbackUri = listener.redirectUri.replace(
          queryParameters: {'code': 'private-code', 'state': 'private-state'},
        );
        final request = await client.getUrl(callbackUri);
        final responseFuture = request.close();
        final callback = await callbackFuture;
        expect(callback.path, '/auth/callback');
        expect(callback.queryParameters['code'], 'private-code');
        await listener.respond(accepted: true);

        final response = await responseFuture;
        final body = await utf8.decoder.bind(response).join();
        expect(response.statusCode, HttpStatus.ok);
        expect(body, contains('return to Stroom'));
        expect(body, isNot(contains('private-code')));
        expect(body, isNot(contains('private-state')));
      } finally {
        client.close(force: true);
        await listener.close();
      }
    },
  );
}
