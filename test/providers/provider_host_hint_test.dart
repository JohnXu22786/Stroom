import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('ProviderTypeDefinition hostHint', () {
    setUp(() {
      registerBuiltinProviderTypes();
    });

    test('ProviderTypeDefinition has hostHint field', () {
      const def = ProviderTypeDefinition(type: 'test');
      expect(def.hostHint, isNull);
    });

    test('hostHint defaults to null when not provided', () {
      const def = ProviderTypeDefinition(type: 'custom');
      expect(def.hostHint, isNull);
    });

    test('hostHint can be set via constructor', () {
      const def = ProviderTypeDefinition(
        type: 'custom',
        hostHint: '例如: https://example.com/api',
      );
      expect(def.hostHint, equals('例如: https://example.com/api'));
    });

    group('builtin type host hints', () {
      test('llm type has hostHint with chat completions example', () {
        final def = ProviderTypeRegistry.get('llm');
        expect(def, isNotNull);
        expect(def!.hostHint, isNotNull);
        expect(def.hostHint, contains('chat/completions'));
      });

      test('tts type has hostHint with audio/speech example', () {
        final def = ProviderTypeRegistry.get('tts');
        expect(def, isNotNull);
        expect(def!.hostHint, isNotNull);
        expect(def.hostHint, contains('audio/speech'));
      });

      test('ocr type has hostHint with chat/completions example', () {
        final def = ProviderTypeRegistry.get('ocr');
        expect(def, isNotNull);
        expect(def!.hostHint, isNotNull);
        expect(def.hostHint, contains('chat/completions'));
      });

      test('asr type has hostHint with audio/transcriptions example', () {
        final def = ProviderTypeRegistry.get('asr');
        expect(def, isNotNull);
        expect(def!.hostHint, isNotNull);
        expect(def.hostHint, contains('audio/transcriptions'));
      });

      test('mcp type has hostHint with SSE example', () {
        final def = ProviderTypeRegistry.get('mcp');
        expect(def, isNotNull);
        expect(def!.hostHint, isNotNull);
        expect(def.hostHint, contains('localhost'));
      });

      test('all builtin types have a hostHint set', () {
        for (final type in ['llm', 'tts', 'ocr', 'asr', 'mcp']) {
          final def = ProviderTypeRegistry.get(type);
          expect(def, isNotNull, reason: 'Type $type should be registered');
          expect(def!.hostHint, isNotNull,
              reason: 'Type $type should have a hostHint');
          expect(def.hostHint!.isNotEmpty, isTrue,
              reason: 'Type $type hostHint should not be empty');
        }
      });
    });
  });
}
