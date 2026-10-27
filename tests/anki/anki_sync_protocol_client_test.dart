import 'dart:async';
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

    test('rejects metadata without a boolean continuation decision', () async {
      httpClient.responses
        ..add(_jsonResponse({'key': 'host-key'}))
        ..add(
          _jsonResponse({
            'mod': 1700000000000,
            'scm': 1600000000000,
            'usn': 7,
            'ts': 1700000000,
            'msg': '',
            'hostNum': 1,
            'empty': false,
            'media_usn': 3,
          }),
        );

      await client.login('test@example.invalid', 'test-only');

      await expectLater(
        client.checkStatus(),
        throwsA(isA<AnkiSyncException>()),
      );
    });

    test('rejects missing or malformed required sync status fields', () async {
      httpClient.responses.add(_jsonResponse({'key': 'host-key'}));
      await client.login('test@example.invalid', 'test-only');

      Map<String, dynamic> validMetadata() => {
            'mod': 1700000000000,
            'scm': 1600000000000,
            'usn': 7,
            'ts': 1700000000,
            'msg': '',
            'cont': true,
            'hostNum': 1,
            'empty': false,
            'media_usn': 3,
          };

      final invalidCases = <String>[];
      for (final field in [
        'mod',
        'scm',
        'usn',
        'ts',
        'msg',
        'hostNum',
        'empty',
        'media_usn',
      ]) {
        final missing = validMetadata()..remove(field);
        final malformed = validMetadata()
          ..[field] = switch (field) {
            'msg' => 42,
            'empty' => 'false',
            _ => 'invalid',
          };
        invalidCases
          ..add('missing $field')
          ..add('malformed $field');
        httpClient.responses
          ..add(_jsonResponse(missing))
          ..add(_jsonResponse(malformed));
      }

      for (final description in invalidCases) {
        await expectLater(
          client.checkStatus(),
          throwsA(isA<AnkiSyncException>()),
          reason: description,
        );
      }
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

    test('cancels a response body stream after its read times out', () async {
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      httpClient.responses.add(_jsonResponse({'key': 'host-key'}));
      await client.login('test@example.invalid', 'test-only');
      httpClient.streamedResponses.add(
        http.StreamedResponse(body.stream, HttpStatus.ok),
      );

      try {
        await runZoned(
          () => expectLater(
            client.checkStatus(),
            throwsA(isA<AnkiSyncException>()),
          ),
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) =>
                parent.createTimer(zone, Duration.zero, callback),
          ),
        );

        expect(cancelled, isTrue);
      } finally {
        await body.close();
      }
    });

    test(
      'allows a media response to continue making progress past 45 seconds',
      () async {
        httpClient.responses.add(_jsonResponse({'key': 'host-key'}));
        await client.login('test@example.invalid', 'test-only');
        final body = StreamController<List<int>>();
        httpClient.streamedResponses.add(
          http.StreamedResponse(body.stream, HttpStatus.ok),
        );

        final received = await runZoned(
          () {
            Timer(const Duration(seconds: 30), () => body.add([1]));
            Timer(const Duration(seconds: 60), () {
              body
                ..add([1])
                ..close();
            });
            return client.downloadMediaZip(['large.bin']);
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) =>
                parent.createTimer(
              zone,
              Duration(milliseconds: duration.inMilliseconds ~/ 1000),
              callback,
            ),
          ),
        );

        expect(received, [1, 1]);
      },
    );

    test(
      'uploads a gzip-compressed collection file only after authentication',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'stroom-anki-protocol-upload_',
        );
        final collectionFile = File('${directory.path}/collection.anki2');
        final collectionBytes = List<int>.generate(
          256 * 1024,
          (index) => (index * 37) % 256,
          growable: false,
        );
        await collectionFile.writeAsBytes(collectionBytes);
        httpClient.responses
          ..add(_jsonResponse({'key': 'host-key'}))
          ..add(http.Response('OK', HttpStatus.ok))
          ..add(http.Response('upload failed', HttpStatus.serviceUnavailable));

        try {
          await client.login('test@example.invalid', 'test-only');
          await client.uploadCollectionFile(collectionFile);

          final request = httpClient.requests.last;
          expect(request.url.path, '/sync/upload');
          final fields = _multipartFields(request);
          expect(utf8.decode(fields['k']!), 'host-key');
          expect(utf8.decode(fields['c']!), '1');
          expect(gzip.decode(fields['data']!), collectionBytes);
          expect(await directory.list().toList(), hasLength(1));
          await expectLater(
            client.uploadCollectionFile(collectionFile),
            throwsA(isA<AnkiSyncException>()),
          );
          expect(await directory.list().toList(), hasLength(1));
        } finally {
          await directory.delete(recursive: true);
        }
      },
    );

    test(
      'does not follow redirects for authenticated multipart requests',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'stroom-anki-protocol-redirect_',
        );
        final collectionFile = File('${directory.path}/collection.anki2');
        await collectionFile.writeAsBytes([1, 2, 3]);
        httpClient.responses
          ..add(_jsonResponse({'key': 'host-key'}))
          ..add(
            http.Response(
              'redirect',
              HttpStatus.temporaryRedirect,
              headers: {'location': 'https://attacker.example/collect'},
            ),
          );

        try {
          await client.login('test@example.invalid', 'test-only');
          await expectLater(
            client.uploadCollectionFile(collectionFile),
            throwsA(isA<AnkiSyncException>()),
          );

          expect(httpClient.requests, hasLength(2));
          expect(
            httpClient.requests.map((request) => request.followRedirects),
            everyElement(isFalse),
          );
        } finally {
          await directory.delete(recursive: true);
        }
      },
    );

    test('relocates AnkiWeb meta requests to an approved HTTPS host', () async {
      httpClient.responses
        ..add(_jsonResponse({'key': 'host-key'}))
        ..add(
          http.Response(
            '',
            HttpStatus.permanentRedirect,
            headers: {'location': 'https://sync16.ankiweb.net/'},
          ),
        )
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
      final originalDestination = client.destinationIdentity;
      final meta = await client.checkStatus();

      expect(meta.usn, 7);
      expect(client.syncRoot, Uri.parse('https://sync16.ankiweb.net/sync/'));
      expect(client.destinationIdentity, originalDestination);
      expect(httpClient.requests, hasLength(3));
      expect(
        httpClient.requests[1].url,
        AnkiSyncProtocolClient.ankiWebSyncRoot.resolve('meta'),
      );
      expect(
        httpClient.requests[2].url,
        Uri.parse('https://sync16.ankiweb.net/sync/meta'),
      );
      final retryFields = _multipartFields(httpClient.requests[2]);
      expect(utf8.decode(retryFields['k']!), 'host-key');
      expect(httpClient.requests.map((request) => request.followRedirects),
          everyElement(isFalse));
    });

    test('rejects unapproved AnkiWeb redirect targets before retrying',
        () async {
      httpClient.responses.add(_jsonResponse({'key': 'host-key'}));
      await client.login('test@example.invalid', 'test-only');
      final unapprovedTargets = [
        'https://attacker.example/collect',
        'https://sync16.ankiweb.net.attacker.example/',
        'http://sync16.ankiweb.net/',
        'https://user@sync16.ankiweb.net/',
        'https://sync16.ankiweb.net:444/',
        'https://sync16.ankiweb.net/other/',
      ];

      for (final target in unapprovedTargets) {
        httpClient.responses.add(
          http.Response(
            '',
            HttpStatus.permanentRedirect,
            headers: {'location': target},
          ),
        );
        await expectLater(
          client.checkStatus(),
          throwsA(isA<AnkiSyncException>()),
          reason: target,
        );
      }

      expect(httpClient.requests, hasLength(unapprovedTargets.length + 1));
      expect(
        httpClient.requests.skip(1).map((request) => request.url.host),
        everyElement('sync.ankiweb.net'),
      );
      expect(client.syncRoot, AnkiSyncProtocolClient.ankiWebSyncRoot);
    });

    test('does not follow AnkiWeb redirects on self-hosted servers', () async {
      httpClient.responses.add(
        http.Response(
          '',
          HttpStatus.permanentRedirect,
          headers: {'location': 'https://sync16.ankiweb.net/'},
        ),
      );
      client.close();
      client = AnkiSyncProtocolClient.selfHosted(
        endpoint: 'https://self-hosted.example.invalid',
        client: httpClient,
        hostKey: 'self-hosted-key',
      );

      await expectLater(
        client.checkStatus(),
        throwsA(isA<AnkiSyncException>()),
      );

      expect(httpClient.requests, hasLength(1));
      expect(
          httpClient.requests.single.url.host, 'self-hosted.example.invalid');
    });

    test('does not retry a second AnkiWeb meta redirect', () async {
      httpClient.responses
        ..add(_jsonResponse({'key': 'host-key'}))
        ..add(
          http.Response(
            '',
            HttpStatus.permanentRedirect,
            headers: {'location': 'https://sync16.ankiweb.net/'},
          ),
        )
        ..add(
          http.Response(
            '',
            HttpStatus.permanentRedirect,
            headers: {'location': 'https://sync17.ankiweb.net/'},
          ),
        );

      await client.login('test@example.invalid', 'test-only');
      await expectLater(
        client.checkStatus(),
        throwsA(isA<AnkiSyncException>()),
      );

      expect(httpClient.requests, hasLength(3));
      expect(
        httpClient.requests.last.url,
        Uri.parse('https://sync16.ankiweb.net/sync/meta'),
      );
      expect(
        httpClient.requests.any(
          (request) => request.url.host == 'sync17.ankiweb.net',
        ),
        isFalse,
      );
    });

    test(
      'streams raw collection bytes to a file through the authenticated endpoint',
      () async {
        final collectionBytes = [0, 1, 2, 255];
        final directory = await Directory.systemTemp.createTemp(
          'stroom-anki-protocol-download_',
        );
        final destination = File('${directory.path}/collection.anki2');
        httpClient.responses.add(_jsonResponse({'key': 'host-key'}));
        httpClient.streamedResponses.add(
          http.StreamedResponse(
            Stream<List<int>>.fromIterable([
              collectionBytes.sublist(0, 2),
              collectionBytes.sublist(2),
            ]),
            HttpStatus.ok,
          ),
        );

        try {
          await client.login('test@example.invalid', 'test-only');
          await client.downloadCollectionToFile(destination);

          expect(await destination.readAsBytes(), collectionBytes);
          final request = httpClient.requests.last;
          expect(request.url.path, '/sync/download');
          final fields = _multipartFields(request);
          expect(utf8.decode(fields['k']!), 'host-key');
          expect(gzip.decode(fields['data']!), utf8.encode('{}'));
        } finally {
          await directory.delete(recursive: true);
        }
      },
    );

    test(
      'rejects a collection response larger than the supported limit',
      () async {
        httpClient.responses
          ..add(_jsonResponse({'key': 'host-key'}))
          ..add(http.Response.bytes([1, 2, 3], HttpStatus.ok));

        await client.login('test@example.invalid', 'test-only');
        httpClient.nextContentLength =
            AnkiSyncProtocolClient.maxInMemoryCollectionBytes + 1;

        await expectLater(
          client.downloadCollection(),
          throwsA(isA<AnkiSyncException>()),
        );
      },
    );

    test(
      'rejects an oversized collection before creating the output file',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'stroom-anki-protocol-large-download_',
        );
        final destination = File('${directory.path}/collection.anki2');
        httpClient.responses.add(_jsonResponse({'key': 'host-key'}));
        httpClient.streamedResponses.add(
          http.StreamedResponse(
            Stream<List<int>>.value([1, 2, 3]),
            HttpStatus.ok,
            contentLength:
                AnkiSyncProtocolClient.maxCollectionDownloadBytes + 1,
          ),
        );

        try {
          await client.login('test@example.invalid', 'test-only');
          await expectLater(
            client.downloadCollectionToFile(destination),
            throwsA(isA<AnkiSyncException>()),
          );

          expect(await destination.exists(), isFalse);
        } finally {
          await directory.delete(recursive: true);
        }
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

    test(
      'rejects endpoint methods that escape the sync server origin',
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
      },
    );

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
      'allows a multipart upload to progress beyond its inactivity timeout',
      () async {
        final uploadClient = _ControlledUploadHttpClient(
          chunkDelay: const Duration(milliseconds: 10),
        );
        final uploadProtocolClient = AnkiSyncProtocolClient.ankiWeb(
          client: uploadClient,
          hostKey: 'host-key',
          requestTimeout: const Duration(milliseconds: 25),
        );
        final zipBytes = List<int>.generate(
          256 * 1024,
          (index) => index % 251,
          growable: false,
        );

        try {
          final uploaded = await uploadProtocolClient.uploadMediaZip(zipBytes);

          expect(uploaded, {'processed': 1, 'currentUsn': 4});
          expect(uploadClient.uploadedBytes, greaterThan(zipBytes.length));
          expect(uploadClient.aborted, isFalse);
        } finally {
          uploadProtocolClient.close();
          uploadClient.close();
        }
      },
    );

    test(
      'aborts a stalled multipart upload when the inactivity timeout expires',
      () async {
        final uploadClient = _ControlledUploadHttpClient(
          chunkDelay: const Duration(milliseconds: 100),
        );
        final uploadProtocolClient = AnkiSyncProtocolClient.ankiWeb(
          client: uploadClient,
          hostKey: 'host-key',
          requestTimeout: const Duration(milliseconds: 25),
        );

        try {
          await expectLater(
            uploadProtocolClient.uploadMediaZip([80, 75, 3, 4, 1, 2, 3]),
            throwsA(isA<AnkiSyncException>()),
          );

          expect(uploadClient.aborted, isTrue);
        } finally {
          uploadProtocolClient.close();
          uploadClient.close();
        }
      },
    );

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

    test(
      'rejects an oversized media ZIP response while receiving it',
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
      },
    );

    test(
      'caps media bytes when the response omits its content length',
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
                'files': ['image.jpg'],
              },
              maxResponseBytes: 3),
          throwsA(isA<AnkiSyncException>()),
        );
      },
    );
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
  final bool followRedirects;
  const _CapturedRequest(
    this.url,
    this.contentType,
    this.body,
    this.followRedirects,
  );
}

class _QueueHttpClient extends http.BaseClient {
  final responses = <http.Response>[];
  final streamedResponses = <http.StreamedResponse>[];
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
        request.followRedirects,
      ),
    );
    if (responses.isNotEmpty) {
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
    return streamedResponses.removeAt(0);
  }

  @override
  void close() => _closed = true;
}

class _ControlledUploadHttpClient extends http.BaseClient {
  final Duration chunkDelay;
  bool aborted = false;
  int uploadedBytes = 0;

  _ControlledUploadHttpClient({required this.chunkDelay});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortTrigger =
        request is http.Abortable ? request.abortTrigger : null;
    final abortedRequest = abortTrigger?.then<void>((_) {
          aborted = true;
          throw http.RequestAbortedException(request.url);
        }) ??
        Completer<void>().future;
    final body = StreamIterator(request.finalize());

    try {
      while (await Future.any<bool>([
        body.moveNext(),
        abortedRequest.then<bool>((_) => false),
      ])) {
        uploadedBytes += body.current.length;
        await Future.any<void>([
          Future<void>.delayed(chunkDelay),
          abortedRequest,
        ]);
      }
    } finally {
      await body.cancel();
    }

    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('{"err":"","data":[1,4]}')),
      HttpStatus.ok,
      request: request,
    );
  }

  @override
  void close() {}
}
