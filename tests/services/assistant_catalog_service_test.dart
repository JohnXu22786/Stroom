import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stroom/models/remote_assistant_catalog.dart';
import 'package:stroom/services/assistant_catalog_service.dart';

void main() {
  group('AssistantCatalogService', () {
    if (kIsWeb) {
      test('fails closed when guarded DNS resolution is unavailable', () async {
        final service = AssistantCatalogService();

        await expectLater(
          service.fetchCatalog('https://catalog.example/catalog.json'),
          throwsA(isA<FormatException>()),
        );
        service.close();
      });
    }

    test('fetches a direct Stroom JSON assistant over HTTPS', () async {
      final body = _assistantJson(version: '1.0.0');
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/assistant.json');
        return http.Response.bytes(utf8.encode(body), 200, request: request);
      });
      final service = AssistantCatalogService.testing(
        client: client,
        addressLookup: _publicAddressLookup,
      );

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
      'rejects non-HTTPS and private host URLs before making a request',
      () async {
        var requestCount = 0;
        final service = AssistantCatalogService.testing(
          client: MockClient((_) async {
            requestCount++;
            return http.Response('{}', 200);
          }),
          addressLookup: _publicAddressLookup,
        );

        await expectLater(
          service.fetchCatalog('http://example.com/catalog.json'),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          service.fetchCatalog('https://127.0.0.1/catalog.json'),
          throwsA(isA<FormatException>()),
        );
        for (final host in [
          'service.local.',
          '[::]',
          '[0:0:0:0:0:0:0:0]',
          '[::1]',
          '[0:0:0:0:0:0:0:1]',
          '[fc00::1]',
          '[fd12:3456:789a::1]',
          '[fe80::1]',
          '[fe80:0:0:0:0:0:0:1]',
          '[::ffff:127.0.0.1]',
          '[::ffff:172.16.0.1]',
          '[0:0:0:0:0:ffff:7f00:1]',
          '[0:0:0:0:0:ffff:ac10:1]',
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

    test('allows a public IPv6 HTTPS host', () async {
      final body = _assistantJson(version: '1.0.0');
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://[2001:4860:4860::8888]/assistant.json',
        );
        return http.Response.bytes(utf8.encode(body), 200, request: request);
      });
      final service = AssistantCatalogService.testing(
        client: client,
        addressLookup: _publicAddressLookup,
      );

      final result = await service.fetchDirectAssistant(
        'https://[2001:4860:4860::8888]/assistant.json',
      );
      service.close();

      expect(result.definition.id, 'stroom.test');
      expect(result.definition.version, '1.0.0');
    });

    test(
      'rejects a public hostname resolving to a private IPv4 address',
      () async {
        var requestCount = 0;
        final service = AssistantCatalogService.testing(
          client: MockClient((_) async {
            requestCount++;
            return http.Response('{}', 200);
          }),
          addressLookup: (_) async => ['93.184.216.34', '10.0.0.8'],
        );

        await expectLater(
          service.fetchCatalog('https://catalog.example/catalog.json'),
          throwsA(isA<FormatException>()),
        );
        expect(requestCount, 0);
        service.close();
      },
    );

    test(
      'rejects a public hostname resolving to a private IPv6 address',
      () async {
        var requestCount = 0;
        final service = AssistantCatalogService.testing(
          client: MockClient((_) async {
            requestCount++;
            return http.Response('{}', 200);
          }),
          addressLookup: (_) async => ['2001:4860:4860::8888', 'fd12::1'],
        );

        await expectLater(
          service.fetchCatalog('https://catalog.example/catalog.json'),
          throwsA(isA<FormatException>()),
        );
        expect(requestCount, 0);
        service.close();
      },
    );

    test('rejects IPv6 transition addresses that encode private IPv4',
        () async {
      for (final address in [
        '64:ff9b::a00:1',
        '64:ff9b:1::a00:1',
        '::a00:1',
        '2002:0a00:0001::1',
        '2001:0000:4136:e378:8000:63bf:3fff:fdd2',
        '2002:5db8:d822::1',
        '2001:4860:4860::5efe:a00:1',
      ]) {
        var requestCount = 0;
        final service = AssistantCatalogService.testing(
          client: MockClient((_) async {
            requestCount++;
            return http.Response('{}', 200);
          }),
          addressLookup: (_) async => [address],
        );

        await expectLater(
          service.fetchCatalog('https://catalog.example/catalog.json'),
          throwsA(isA<FormatException>()),
          reason: 'DNS answer $address encodes a private IPv4 endpoint',
        );
        expect(requestCount, 0, reason: 'DNS answer $address was requested');
        service.close();
      }
    });

    test('rejects IPv6 special-purpose addresses from DNS', () async {
      for (final address in [
        '100::1',
        '2001:2::1',
        '3fff::1',
        '5f00::1',
        '4000::1',
      ]) {
        var requestCount = 0;
        final service = AssistantCatalogService.testing(
          client: MockClient((_) async {
            requestCount++;
            return http.Response('{}', 200);
          }),
          addressLookup: (_) async => [address],
        );

        await expectLater(
          service.fetchCatalog('https://catalog.example/catalog.json'),
          throwsA(isA<FormatException>()),
          reason: 'DNS answer $address is a special-purpose destination',
        );
        expect(requestCount, 0, reason: 'DNS answer $address was requested');
        service.close();
      }
    });

    test('does not follow a redirect to a private address', () async {
      final requests = <Uri>[];
      var lookupCount = 0;
      final service = AssistantCatalogService.testing(
        client: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://catalog.example/private'},
            request: request,
          );
        }),
        addressLookup: (_) async =>
            lookupCount++ == 0 ? ['93.184.216.34'] : ['10.0.0.8'],
      );

      await expectLater(
        service.fetchCatalog('https://catalog.example/catalog.json'),
        throwsA(isA<FormatException>()),
      );
      expect(requests, [Uri.parse('https://catalog.example/catalog.json')]);
      expect(lookupCount, 2);
      service.close();
    });

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
        final service = AssistantCatalogService.testing(
          client: client,
          addressLookup: _publicAddressLookup,
        );
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
        final service = AssistantCatalogService.testing(
          client: MockClient((request) async {
            requestCount++;
            return http.Response.bytes(
              utf8.encode(_assistantJson(version: '2.0.0')),
              200,
              request: request,
            );
          }),
          addressLookup: _publicAddressLookup,
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

Future<List<String>> _publicAddressLookup(String _) async =>
    const ['93.184.216.34'];
