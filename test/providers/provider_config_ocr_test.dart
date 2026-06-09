import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('ProviderConfig OCR type', () {
    test('OCR provider type is registered', () {
      // During normal app start, registerBuiltinProviderTypes is called
      // which registers 'llm' and 'tts'. We need 'ocr' too.
      registerBuiltinProviderTypes();
      expect(ProviderTypeRegistry.isRegistered('ocr'), isTrue);
    });

    test('OCR provider type has correct definition', () {
      registerBuiltinProviderTypes();
      final def = ProviderTypeRegistry.get('ocr');
      expect(def, isNotNull);
      expect(def!.type, equals('ocr'));
    });

    test('OCR provider entry can be created', () {
      final entry = ProviderEntry(
        id: 'test_ocr',
        type: 'ocr',
        name: 'OCR供应商',
      );
      expect(entry.id, equals('test_ocr'));
      expect(entry.type, equals('ocr'));
      expect(entry.name, equals('OCR供应商'));
    });

    test('OCR provider entry with config', () {
      final config = ProviderConfigItem(
        providerName: 'Test OCR',
        host: 'https://api.test.com/v1',
        key: 'test-key',
        models: [
          ModelConfig(
            name: 'GPT-4o',
            modelId: 'gpt-4o',
          ),
        ],
      );
      final entry = ProviderEntry(
        id: 'ocr_1',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [config],
      );
      expect(entry.configs.length, equals(1));
      expect(entry.configs[0].providerName, equals('Test OCR'));
      expect(entry.configs[0].models.length, equals(1));
      expect(entry.configs[0].models[0].modelId, equals('gpt-4o'));
    });

    test('OCR provider entry serialization round-trip', () {
      final config = ProviderConfigItem(
        providerName: 'My OCR',
        host: 'https://ocr.example.com',
        key: 'sk-1234',
        models: [
          ModelConfig(name: 'Qwen-VL', modelId: 'qwen-vl-max'),
        ],
      );
      final entry = ProviderEntry(
        id: 'ocr_roundtrip',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [config],
      );

      // Serialize to map
      final map = entry.toMap();
      expect(map['type'], equals('ocr'));
      expect(map['name'], equals('OCR供应商'));

      // Deserialize back
      final restored = ProviderEntry.fromMap(map);
      expect(restored.id, equals(entry.id));
      expect(restored.type, equals('ocr'));
      expect(restored.configs.length, equals(1));
      expect(restored.configs[0].host, equals('https://ocr.example.com'));
    });
  });
}
