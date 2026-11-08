import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stroom/models/remote_assistant_catalog.dart';
import 'package:stroom/services/assistant_catalog_service.dart';

void main() {
  group('AssistantCatalogService', () {
    test('rejects an oversized streamed body before retaining it', () async {
      final client = _OversizedChunkedClient();
      final service = AssistantCatalogService(client: client);

      await expectLater(
        service.fetchCatalog('https://example.com/catalog.json'),
        throwsA(isA<FormatException>()),
      );
      expect(client.sentChunks, 2);
      service.close();
    });

    test('fetches a direct Stroom JSON assistant over HTTPS', () async {
      final body = _assistantJson(version: '1.0.0');
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/assistant.json');
        return http.Response.bytes(utf8.encode(body), 200, request: request);
      });
      final service = AssistantCatalogService(client: client);

      final result = await service.fetchDirectAssistant(
        'https://example.com/assistant.json',
      );
      service.close();

      expect(result.definition.id, 'stroom.test');
      expect(result.definition.version, '1.0.0');
      expect(result.format, 'stroom-json-v1');
      expect(result.sha256, sha256.convert(utf8.encode(body)).toString());
    });

    test(
      'rejects non-HTTPS and nonpublic IP URLs before making a request',
      () async {
        var requestCount = 0;
        final service = AssistantCatalogService(
          client: MockClient((_) async {
            requestCount++;
            return http.Response('{}', 200);
          }),
        );

        await expectLater(
          service.fetchCatalog('http://example.com/catalog.json'),
          throwsA(isA<FormatException>()),
        );
        for (final host in [
          '127.0.0.1',
          '192.0.2.10',
          '[::1]',
          '[0:0:0:0:0:0:0:1]',
          '[::ffff:127.0.0.1]',
          '[::ffff:172.16.0.1]',
          '[2001:db8::1]',
        ]) {
          await expectLater(
            service.fetchCatalog('https://$host/catalog.json'),
            throwsA(isA<FormatException>()),
          );
        }
        expect(requestCount, 0);
        service.close();
      },
    );

    test(
      'validates catalog file hash and metadata before returning it',
      () async {
        final file = _assistantJson(version: '2.0.0');
        final digest = sha256.convert(utf8.encode(file)).toString();
        final client = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.com/assistants/test.json',
          );
          return http.Response.bytes(utf8.encode(file), 200, request: request);
        });
        final service = AssistantCatalogService(client: client);
        final entry = RemoteAssistantCatalogEntry.fromMap({
          'id': 'stroom.test',
          'name': 'Test assistant',
          'description': 'A test prompt',
          'emoji': '🤖',
          'version': '2.0.0',
          'file': 'assistants/test.json',
          'format': 'stroom-json-v1',
          'sha256': digest,
        });

        final result = await service.fetchCatalogEntry(
          catalogUrl: 'https://example.com/catalog.json',
          entry: entry,
        );

        expect(result.definition.version, '2.0.0');
        expect(result.catalogEntry, same(entry));
        service.close();
      },
    );

    test(
      'rejects mismatched hashes and catalog paths outside the origin',
      () async {
        var requestCount = 0;
        final service = AssistantCatalogService(
          client: MockClient((request) async {
            requestCount++;
            return http.Response.bytes(
              utf8.encode(_assistantJson(version: '2.0.0')),
              200,
              request: request,
            );
          }),
        );
        final entry = RemoteAssistantCatalogEntry.fromMap({
          'id': 'stroom.test',
          'name': 'Test assistant',
          'version': '2.0.0',
          'file': 'https://other.example/test.json',
          'format': 'stroom-json-v1',
          'sha256': List.filled(64, 'a').join(),
        });

        await expectLater(
          service.fetchCatalogEntry(
            catalogUrl: 'https://example.com/catalog.json',
            entry: entry,
          ),
          throwsA(isA<FormatException>()),
        );
        expect(requestCount, 0);

        final sameOriginEntry = RemoteAssistantCatalogEntry.fromMap({
          'id': 'stroom.test',
          'name': 'Test assistant',
          'version': '2.0.0',
          'file': 'test.json',
          'format': 'stroom-json-v1',
          'sha256': List.filled(64, 'a').join(),
        });
        await expectLater(
          service.fetchCatalogEntry(
            catalogUrl: 'https://example.com/catalog.json',
            entry: sameOriginEntry,
          ),
          throwsA(isA<FormatException>()),
        );
        expect(requestCount, 1);
        service.close();
      },
    );
  });
}

String _assistantJson({required String version}) => '''
{
  "schemaVersion": 1,
  "id": "stroom.test",
  "name": "Test assistant",
  "description": "A test prompt",
  "emoji": "🤖",
  "version": "$version",
  "prompt": "Be helpful."
}
''';

class _OversizedChunkedClient extends http.BaseClient {
  int sentChunks = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    Stream<List<int>> body() async* {
      sentChunks++;
      yield List<int>.filled(600 * 1024, 1);
      sentChunks++;
      yield List<int>.filled(600 * 1024, 2);
      sentChunks++;
      yield List<int>.filled(600 * 1024, 3);
    }

    return http.StreamedResponse(body(), 200, request: request);
  }
}
