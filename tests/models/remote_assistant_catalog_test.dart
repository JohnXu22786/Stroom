import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/remote_assistant_catalog.dart';

void main() {
  group('RemoteAssistantDefinition', () {
    test('decodes JSON, YAML, and Markdown into the same schema', () {
      const json = '''
{
  "schemaVersion": 1,
  "id": "stroom.test",
  "name": "Test assistant",
  "version": "1.0.0",
  "settings": {"temperature": 0.5, "enableTemperature": true},
  "prompt": "Be helpful."
}
''';
      const yaml = '''
schemaVersion: 1
id: stroom.test
name: Test assistant
version: 1.0.0
settings:
  temperature: 0.5
  enableTemperature: true
prompt: Be helpful.
''';
      const markdown = '''---
schemaVersion: 1
id: stroom.test
name: Test assistant
version: 1.0.0
settings:
  temperature: 0.5
  enableTemperature: true
---
Be helpful.
''';

      final definitions = [
        RemoteAssistantDefinition.parse(json, format: 'stroom-json-v1'),
        RemoteAssistantDefinition.parse(yaml, format: 'stroom-yaml-v1'),
        RemoteAssistantDefinition.parse(
          markdown,
          format: kRemoteAssistantMarkdownFormat,
        ),
      ];

      for (final definition in definitions) {
        expect(definition.id, 'stroom.test');
        expect(definition.name, 'Test assistant');
        expect(definition.prompt, 'Be helpful.');
        expect(definition.settings.temperature, 0.5);
        expect(definition.settings.enableTemperature, isTrue);
      }
    });

    test('rejects unknown aliases and out-of-range settings', () {
      expect(
        () => RemoteAssistantDefinition.parse(
          _assistantJson(extra: '"model": "x"'),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => RemoteAssistantDefinition.parse(
          _assistantJson(settings: '"temperature": 3'),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => RemoteAssistantDefinition.parse(
          _assistantJson(settings: '"maxTokens": 255'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates custom parameter names and types', () {
      final definition = RemoteAssistantDefinition.parse(
        _assistantJson(
          settings:
              '"customParameters": [{"name":"vendor.option","type":"json","value":{"enabled":true}}]',
        ),
      );
      expect(definition.settings.customParameters.single.name, 'vendor.option');

      expect(
        () => RemoteAssistantDefinition.parse(
          _assistantJson(
            settings:
                '"customParameters": [{"name":"vendor..option","type":"string","value":"x"}]',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('RemoteAssistantCatalog', () {
    test('accepts supported capability names and preserves extensions', () {
      final catalog = RemoteAssistantCatalog.parse('''
schemaVersion: 1
catalogId: example
extensions:
  publisher: test
assistants:
  - id: stroom.test
    name: Test
    version: 1.0.0
    file: test.json
    format: stroom-json-v1
    sha256: ${_testHash}
    requiresCapabilities: [stroom.assistant.v1, stroom.settings.v1]
''');

      expect(catalog.extensions['publisher'], 'test');
      expect(catalog.assistants.single.requiresCapabilities, {
        'stroom.assistant.v1',
        'stroom.settings.v1',
      });
    });

    test('rejects unknown capabilities, invalid hashes, and duplicate ids', () {
      expect(
        () => RemoteAssistantCatalog.parse(
          _catalogYaml(capability: 'future.capability'),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => RemoteAssistantCatalog.parse(_catalogYaml(hash: 'bad')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => RemoteAssistantCatalog.parse(_catalogYaml(duplicate: true)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

String _assistantJson({String settings = '', String extra = ''}) => '''
{
  "schemaVersion": 1,
  "id": "stroom.test",
  "name": "Test assistant",
  "version": "1.0.0",
  ${settings.isEmpty ? '' : '"settings": {$settings},'}
  "prompt": "Be helpful."
  ${extra.isEmpty ? '' : ',$extra'}
}
''';

String _catalogYaml({
  String capability = 'stroom.assistant.v1',
  String hash = _testHash,
  bool duplicate = false,
}) =>
    '''
schemaVersion: 1
catalogId: example
assistants:
  - id: stroom.test
    name: Test
    version: 1.0.0
    file: test.json
    format: stroom-json-v1
    sha256: $hash
    requiresCapabilities: [$capability]
  ${duplicate ? '''- id: stroom.test
    name: Test
    version: 1.0.0
    file: test2.json
    format: stroom-json-v1
    sha256: $hash''' : ''}
''';

const String _testHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
