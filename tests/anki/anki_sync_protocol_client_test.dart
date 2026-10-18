import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stroom/anki/sync/anki_sync_protocol_client.dart';
import 'package:stroom/anki/sync/anki_sync_provider.dart';

void main() {
  group('Anki sync v10 protocol client', () {
    late _QueueHttpClient httpClient;
    late AnkiSyncProtocolClient client;

    setUp(() {
      httpClient = _QueueHttpClient();
      client = AnkiSyncProtocolClient.ankiWeb(client: httpClient);
    });

    tearDown(() {
      client.close();
      httpClient.close();
    });

    test('logs in using the v10 multipart hostKey request', () async {
      httpClient.responses.add(_jsonResponse({'key': 'host-key'}));

      final key = await client.login('test@example.invalid', 'test-only');

      expect(key, 'host-key');
      expect(httpClient.requests, hasLength(1));
      final request = httpClient.requests.single;
      expect(
        request.url,
        AnkiSyncProtocolClient.ankiWebSyncRoot.resolve('hostKey'),
      );
      expect(request.contentType, startsWith('multipart/form-data;'));

      final fields = _multipartFields(request);
      expect(utf8.decode(fields['c']!), '1');
      expect(utf8.decode(fields['k']!), '');
      final loginData = jsonDecode(utf8.decode(gzip.decode(fields['data']!)))
          as Map<String, dynamic>;
      expect(loginData, {'u': 'test@example.invalid', 'p': 'test-only'});
    });

    test('checks read-only metadata with the authenticated host key', () async {
      httpClient.responses
        ..add(_jsonResponse({'key': 'host-key'}))
        ..add(
          _jsonResponse({
            'mod': 1700000000000,
            'scm': 1600000000000,
            'usn': 7,
            'ts': 1700000000,
            'msg': '',
            'cont': true,
            'hostNum': 1,
            'empty': false,
            'media_usn': 3,
          }),
        );

      await client.login('test@example.invalid', 'test-only');
      final meta = await client.checkStatus();

      expect(meta.modified, 1700000000000);
      expect(meta.schema, 1600000000000);
      expect(meta.usn, 7);
      expect(meta.isEmpty, isFalse);
      final request = httpClient.requests.last;
      final fields = _multipartFields(request);
      expect(utf8.decode(fields['k']!), 'host-key');
      final payload = jsonDecode(utf8.decode(gzip.decode(fields['data']!)))
          as Map<String, dynamic>;
      expect(payload['v'], 10);
      expect(payload['cv'], startsWith('stroom:'));
    });

    test('does not include a server error body in login errors', () async {
      httpClient.responses.add(
        http.Response('echoed test-only password', HttpStatus.badRequest),
      );

      Object? thrown;
      try {
        await client.login('test@example.invalid', 'test-only');
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isA<AnkiSyncException>());
      expect(thrown.toString(), isNot(contains('test-only')));
      expect(thrown.toString(), contains('HTTP 400'));
    });

    test(
      'uploads a gzip-compressed collection only after authentication',
      () async {
        httpClient.responses
          ..add(_jsonResponse({'key': 'host-key'}))
          ..add(http.Response('OK', HttpStatus.ok));

        await client.login('test@example.invalid', 'test-only');
        await client.uploadCollection([0, 1, 2, 255]);

        final request = httpClient.requests.last;
        expect(request.url.path, '/sync/upload');
        final fields = _multipartFields(request);
        expect(utf8.decode(fields['k']!), 'host-key');
        expect(gzip.decode(fields['data']!), [0, 1, 2, 255]);
      },
    );

    test(
      'downloads raw collection bytes through the authenticated endpoint',
      () async {
        final collectionBytes = [0, 1, 2, 255];
        httpClient.responses
          ..add(_jsonResponse({'key': 'host-key'}))
          ..add(http.Response.bytes(collectionBytes, HttpStatus.ok));

        await client.login('test@example.invalid', 'test-only');
        final downloaded = await client.downloadCollection();

        expect(downloaded, collectionBytes);
        final request = httpClient.requests.last;
        expect(request.url.path, '/sync/download');
        final fields = _multipartFields(request);
        expect(utf8.decode(fields['k']!), 'host-key');
        expect(gzip.decode(fields['data']!), utf8.encode('{}'));
      },
    );

    test(
      'sends collection protocol requests through sync v10 multipart',
      () async {
        httpClient.responses
          ..add(_jsonResponse({'key': 'host-key'}))
          ..add(_jsonResponse({'cards': [], 'notes': [], 'decks': []}));

        await client.login('test@example.invalid', 'test-only');
        final response = await client.requestJson('start', {
          'minUsn': 4,
          'lnewer': true,
        });

        expect(response, {'cards': [], 'notes': [], 'decks': []});
        final request = httpClient.requests.last;
        expect(request.url.path, '/sync/start');
        final fields = _multipartFields(request);
        expect(utf8.decode(fields['c']!), '1');
        expect(utf8.decode(fields['k']!), 'host-key');
        expect(jsonDecode(utf8.decode(gzip.decode(fields['data']!))), {
          'minUsn': 4,
          'lnewer': true,
        });
      },
    );

    test('rejects endpoint methods that escape the sync server origin',
        () async {
      httpClient.responses.add(_jsonResponse({'key': 'host-key'}));
      await client.login('test@example.invalid', 'test-only');

      for (final method in [
        'https://attacker.example/collect',
        '//attacker.example/collect',
        '../../outside-sync',
      ]) {
        await expectLater(
          client.requestJson(method, const {}),
          throwsA(isA<AnkiSyncException>()),
        );
      }

      expect(httpClient.requests, hasLength(1));
    });

    test('uses media endpoint and leaves ZIP uploads uncompressed', () async {
      final zipBytes = [80, 75, 3, 4, 1, 2, 3];
      httpClient.responses
        ..add(_jsonResponse({'key': 'host-key'}))
        ..add(
          _jsonResponse({
            'data': {'usn': 3, 'sk': 'host-key'},
            'err': '',
          }),
        )
        ..add(
          _jsonResponse({
            'data': [1, 4],
            'err': '',
          }),
        );

      await client.login('test@example.invalid', 'test-only');
      final begin = await client.requestMediaJson('begin', {
        'v': 'stroom:test',
      });
      final uploaded = await client.uploadMediaZip(zipBytes);

      expect(begin, {'usn': 3, 'sk': 'host-key'});
      expect(uploaded, {'processed': 1, 'currentUsn': 4});
      expect(httpClient.requests[1].url.path, '/msync/begin');
      expect(httpClient.requests[2].url.path, '/msync/uploadChanges');
      final fields = _multipartFields(httpClient.requests[2]);
      expect(utf8.decode(fields['c']!), '0');
      expect(fields['data'], zipBytes);
    });

    test(
      'downloads media ZIP bytes without interpreting them as JSON',
      () async {
        final zipBytes = [80, 75, 3, 4, 8, 9];
        httpClient.responses
          ..add(_jsonResponse({'key': 'host-key'}))
          ..add(http.Response.bytes(zipBytes, HttpStatus.ok));

        await client.login('test@example.invalid', 'test-only');
        final response = await client.downloadMediaZip(['image.jpg']);

        expect(response, zipBytes);
        expect(httpClient.requests.last.url.path, '/msync/downloadFiles');
      },
    );

    test('rejects an oversized media ZIP response while receiving it',
        () async {
      httpClient.responses
        ..add(_jsonResponse({'key': 'host-key'}))
        ..add(http.Response.bytes([80, 75, 3, 4], HttpStatus.ok));

      await client.login('test@example.invalid', 'test-only');
      httpClient.nextContentLength = 128 * 1024 * 1024 + 1;

      await expectLater(
        client.downloadMediaZip(['image.jpg']),
        throwsA(isA<AnkiSyncException>()),
      );
    });

    test('caps media bytes when the response omits its content length',
        () async {
      httpClient.responses
        ..add(_jsonResponse({'key': 'host-key'}))
        ..add(http.Response.bytes([1, 2, 3, 4], HttpStatus.ok));

      await client.login('test@example.invalid', 'test-only');
      httpClient.omitNextContentLength = true;

      await expectLater(
        client.requestMediaData(
          'downloadFiles',
          {
            'files': ['image.jpg']
          },
          maxResponseBytes: 3,
        ),
        throwsA(isA<AnkiSyncException>()),
      );
    });
  });

  test('self-hosted endpoint gets its own sync root', () async {
    final fake = _QueueHttpClient()
      ..responses.add(_jsonResponse({'key': 'host-key'}));
    final selfHosted = AnkiSyncProtocolClient.selfHosted(
      endpoint: 'https://sync.example.invalid',
      client: fake,
    );
    try {
      await selfHosted.login('test-user', 'test-only');
      expect(fake.requests.single.url.path, '/sync/hostKey');
    } finally {
      selfHosted.close();
      fake.close();
    }
  });

  test('self-hosted plain HTTP is limited to loopback hosts', () {
    final fake = _QueueHttpClient();

    expect(
      () => AnkiSyncProtocolClient.selfHosted(
        endpoint: 'http://sync.example.invalid',
        client: fake,
      ),
      throwsA(isA<AnkiSyncException>()),
    );
    expect(fake.requests, isEmpty);

    final localServer = AnkiSyncProtocolClient.selfHosted(
      endpoint: 'http://127.0.0.1:8765',
      client: fake,
    );
    localServer.close();
    fake.close();
  });

  test('self-hosted plain HTTP accepts localhost subdomains', () async {
    final fake = _QueueHttpClient()
      ..responses.add(_jsonResponse({'key': 'host-key'}));
    final localServer = AnkiSyncProtocolClient.selfHosted(
      endpoint: 'http://anki.localhost:8765',
      client: fake,
    );
    try {
      await localServer.login('test-user', 'test-only');

      expect(
        fake.requests.single.url,
        Uri.parse('http://anki.localhost:8765/sync/hostKey'),
      );
    } finally {
      localServer.close();
      fake.close();
    }
  });

  test('secure storage identities are separated by mode and server', () {
    const official = AnkiSyncState(mode: AnkiSyncMode.ankiWeb, isLoaded: true);
    const serverA = AnkiSyncState(
      mode: AnkiSyncMode.selfHosted,
      selfHostedUrl: 'https://sync-a.example.invalid/sync/',
      isLoaded: true,
    );
    const serverB = AnkiSyncState(
      mode: AnkiSyncMode.selfHosted,
      selfHostedUrl: 'https://sync-b.example.invalid/sync/',
      isLoaded: true,
    );

    expect(official.secureStorageKey, isNot(serverA.secureStorageKey));
    expect(serverA.secureStorageKey, isNot(serverB.secureStorageKey));
  });
}

http.Response _jsonResponse(Map<String, Object?> value) =>
    http.Response(jsonEncode(value), HttpStatus.ok);

Map<String, List<int>> _multipartFields(_CapturedRequest request) {
  final contentType = request.contentType;
  final boundary = RegExp(r'boundary=(.+)$').firstMatch(contentType)!.group(1)!;
  final delimiter = ascii.encode('--$boundary\r\n');
  final nextPart = ascii.encode('\r\n--$boundary');
  final output = <String, List<int>>{};
  var offset = 0;
  while (true) {
    final partStart = _indexOf(request.body, delimiter, offset);
    if (partStart < 0) break;
    final headersStart = partStart + delimiter.length;
    final headersEnd = _indexOf(
      request.body,
      ascii.encode('\r\n\r\n'),
      headersStart,
    );
    if (headersEnd < 0) break;
    final headers = utf8.decode(request.body.sublist(headersStart, headersEnd));
    final name = RegExp(r'name="([^"]+)"').firstMatch(headers)?.group(1);
    final dataStart = headersEnd + 4;
    final dataEnd = _indexOf(request.body, nextPart, dataStart);
    if (name == null || dataEnd < 0) break;
    output[name] = request.body.sublist(dataStart, dataEnd);
    offset = dataEnd + 2;
  }
  return output;
}

int _indexOf(List<int> source, List<int> pattern, int start) {
  for (var i = start; i <= source.length - pattern.length; i++) {
    var matches = true;
    for (var j = 0; j < pattern.length; j++) {
      if (source[i + j] != pattern[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  return -1;
}

class _CapturedRequest {
  final Uri url;
  final String contentType;
  final List<int> body;
  const _CapturedRequest(this.url, this.contentType, this.body);
}

class _QueueHttpClient extends http.BaseClient {
  final responses = <http.Response>[];
  final requests = <_CapturedRequest>[];
  bool _closed = false;
  int? nextContentLength;
  bool omitNextContentLength = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw StateError('HTTP client is closed');
    final body = await request.finalize().fold<List<int>>(
      <int>[],
      (collected, chunk) => collected..addAll(chunk),
    );
    requests.add(
      _CapturedRequest(
        request.url,
        request.headers['content-type'] ?? '',
        body,
      ),
    );
    final response = responses.removeAt(0);
    final contentLength = omitNextContentLength
        ? null
        : nextContentLength ?? response.bodyBytes.length;
    nextContentLength = null;
    omitNextContentLength = false;
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      contentLength: contentLength,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() => _closed = true;
}
