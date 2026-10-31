// The legacy APIs remain exported for compatibility; these tests verify that
// they delegate login to sync v10 and refuse unsafe placeholder operations.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stroom/anki/sync/anki_full_sync_client.dart';
import 'package:stroom/anki/sync/anki_sync_client.dart';
import 'package:stroom/anki/sync/anki_sync_engine.dart';
import 'package:stroom/anki/sync/anki_sync_protocol_client.dart';

void main() {
  test(
    'legacy login entry points delegate to the v10 hostKey exchange',
    () async {
      final fakeHttp = _QueueHttpClient()
        ..responses.addAll([
          _json({'key': 'full-client-key'}),
          _json({'key': 'login-client-key'}),
        ]);
      AnkiSyncProtocolClient clientFactory() =>
          AnkiSyncProtocolClient.ankiWeb(client: fakeHttp);

      final auth = await AnkiFullSyncClient(clientFactory: clientFactory)
          .login('test@example.invalid', 'test-only');
      final loginKey = await AnkiSyncClient.login(
        'test@example.invalid',
        'test-only',
        clientFactory: clientFactory,
      );

      expect(auth.hkey, 'full-client-key');
      expect(loginKey, 'login-client-key');
      expect(fakeHttp.requests, hasLength(2));
      expect(fakeHttp.requests.map((request) => request.url.path), [
        '/sync/hostKey',
        '/sync/hostKey',
      ]);
      expect(
        fakeHttp.requests.every(
          (request) => request.contentType.startsWith('multipart/form-data;'),
        ),
        isTrue,
      );
      fakeHttp.close();
    },
  );

  test(
    'retired protobuf and sync-v1 operations fail before sending requests',
    () async {
      final fakeHttp = _QueueHttpClient();
      final protocolClient = AnkiSyncProtocolClient.ankiWeb(client: fakeHttp);
      final legacyClient = AnkiFullSyncClient(
        clientFactory: () => protocolClient,
      );

      await expectLater(
        legacyClient.checkStatus('host-key'),
        throwsA(isA<AnkiSyncException>()),
      );
      await expectLater(
        legacyClient.startSync('host-key'),
        throwsA(isA<AnkiSyncException>()),
      );
      await expectLater(
        legacyClient.fullUpload('host-key', [1, 2, 3]),
        throwsA(isA<AnkiSyncException>()),
      );

      final engine = AnkiSyncEngine(
        endpoint: 'https://sync.example.invalid/sync/',
      );
      await expectLater(engine.start(0, 1), throwsA(isA<AnkiSyncException>()));
      await expectLater(
        engine.fullUpload([1, 2, 3]),
        throwsA(isA<AnkiSyncException>()),
      );
      await expectLater(engine.mediaBegin(), throwsA(isA<AnkiSyncException>()));
      expect(fakeHttp.requests, isEmpty);

      engine.dispose();
      protocolClient.close();
      fakeHttp.close();
    },
  );
}

http.Response _json(Map<String, Object?> value) =>
    http.Response(jsonEncode(value), HttpStatus.ok);

class _QueueHttpClient extends http.BaseClient {
  final List<http.Response> responses = [];
  final List<_CapturedRequest> requests = [];
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw StateError('client is closed');
    final body = <int>[];
    await for (final chunk in request.finalize()) {
      body.addAll(chunk);
    }
    requests.add(
      _CapturedRequest(
        url: request.url,
        contentType: request.headers['content-type'] ?? '',
        body: body,
      ),
    );
    if (responses.isEmpty) throw StateError('no fake response queued');
    final response = responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() => _closed = true;
}

class _CapturedRequest {
  final Uri url;
  final String contentType;
  final List<int> body;

  const _CapturedRequest({
    required this.url,
    required this.contentType,
    required this.body,
  });
}
