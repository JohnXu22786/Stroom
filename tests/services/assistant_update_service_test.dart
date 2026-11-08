import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/services/assistant_catalog_service.dart';
import 'package:stroom/services/assistant_update_service.dart';

void main() {
  group('AssistantUpdateService', () {
    test('returns null for local assistants without a remote source', () async {
      final assistant = Assistant(
        id: 'local',
        name: 'Local',
        prompt: 'Prompt',
      );

      expect(await AssistantUpdateService.checkForUpdate(assistant), isNull);
    });

    test('returns a changed direct-file version for a remote assistant',
        () async {
      final body = _assistantJson(id: 'stroom.test', version: '2.0.0');
      final service = AssistantCatalogService(
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://example.com/test.json');
          return http.Response(body, 200, request: request);
        }),
      );
      final assistant = Assistant(
        id: 'local-id',
        name: 'Test assistant',
        prompt: 'Old prompt',
        remoteFileUrl: 'https://example.com/test.json',
        remoteAssistantId: 'stroom.test',
        remoteVersion: '1.0.0',
        remoteSha256: List.filled(64, '0').join(),
      );

      final update = await AssistantUpdateService.checkForUpdate(
        assistant,
        catalogService: service,
      );
      service.close();

      expect(update, isNotNull);
      expect(update!.definition.version, '2.0.0');
      expect(update.sha256, sha256.convert(utf8.encode(body)).toString());
    });

    test('rejects a direct file whose stable assistant ID changed', () async {
      final service = AssistantCatalogService(
        client: MockClient((request) async => http.Response(
              _assistantJson(id: 'stroom.changed', version: '2.0.0'),
              200,
              request: request,
            )),
      );
      final assistant = Assistant(
        id: 'local-id',
        name: 'Test assistant',
        prompt: 'Old prompt',
        remoteFileUrl: 'https://example.com/test.json',
        remoteAssistantId: 'stroom.test',
        remoteVersion: '1.0.0',
      );

      await expectLater(
        AssistantUpdateService.checkForUpdate(
          assistant,
          catalogService: service,
        ),
        throwsA(isA<FormatException>()),
      );
      service.close();
    });
  });
}

String _assistantJson({required String id, required String version}) => '''
{
  "schemaVersion": 1,
  "id": "$id",
  "name": "Test assistant",
  "version": "$version",
  "prompt": "Be helpful."
}
''';
