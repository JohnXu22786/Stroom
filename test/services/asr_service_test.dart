import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/asr_service.dart';
import 'dart:typed_data';

void main() {
  group('AsrService', () {
    group('AsrConfig', () {
      test('can be created with all fields', () {
        const config = AsrConfig(
          model: 'whisper-1',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
          language: 'zh',
        );
        expect(config.model, equals('whisper-1'));
        expect(config.apiKey, equals('test-key'));
        expect(config.host, equals('https://api.openai.com/v1'));
        expect(config.language, equals('zh'));
      });

      test('default model is whisper-1', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.model, equals('whisper-1'));
      });

      test('language is null by default', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.language, isNull);
      });

      test('copies correctly', () {
        const config = AsrConfig(
          model: 'whisper-1',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
          language: 'en',
        );
        final copy = config.copyWith(model: 'whisper-2');
        expect(copy.model, equals('whisper-2'));
        expect(copy.apiKey, equals('test-key'));
        expect(copy.host, equals('https://api.openai.com/v1'));
        expect(copy.language, equals('en'));
      });

      test('copyWith can update language', () {
        const config = AsrConfig(
          apiKey: 'key',
          host: 'https://api.test.com',
        );
        final copy = config.copyWith(language: 'zh');
        expect(copy.language, equals('zh'));
      });

      test('normalizedHost strips trailing slash', () {
        const config = AsrConfig(
          apiKey: 'key',
          host: 'https://api.openai.com/v1/',
        );
        expect(config.normalizedHost.endsWith('/'), isFalse);
        expect(config.normalizedHost, equals('https://api.openai.com/v1'));
      });

      test('normalizedHost returns host as-is when no trailing slash', () {
        const config = AsrConfig(
          apiKey: 'key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.normalizedHost, equals('https://api.openai.com/v1'));
      });

      test('transcribeUrl returns normalizedHost directly (no auto-append)',
          () {
        const config = AsrConfig(
          apiKey: 'key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.transcribeUrl, equals('https://api.openai.com/v1'));
      });

      test('transcribeUrl handles trailing slash in host', () {
        const config = AsrConfig(
          apiKey: 'key',
          host: 'https://api.openai.com/v1/',
        );
        expect(config.transcribeUrl, equals('https://api.openai.com/v1'));
      });
    });

    group('AsrResult', () {
      test('can be created with all fields', () {
        final result = AsrResult(
          text: 'Hello world',
          processingTimeMs: 2000,
        );
        expect(result.text, equals('Hello world'));
        expect(result.processingTimeMs, equals(2000));
      });

      test('default values', () {
        final result = AsrResult(text: 'Hello');
        expect(result.processingTimeMs, isZero);
      });
    });

    group('AsrService', () {
      test('can be created with config', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = AsrService(config: config);
        expect(service, isNotNull);
        expect(service.config.model, equals('whisper-1'));
      });

      test('Dio has no sendTimeout (no timeout)', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = AsrService(config: config);
        expect(service.sendTimeout, isNull);
      });

      test('Dio has no connectTimeout (no timeout)', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = AsrService(config: config);
        expect(service.connectTimeout, isNull);
      });

      test('Dio has no receiveTimeout (no timeout)', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = AsrService(config: config);
        expect(service.receiveTimeout, isNull);
      });

      test('throws on empty host', () async {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: '',
        );
        final service = AsrService(config: config);
        expect(
          () => service.transcribe(
            audioBytes: Uint8List(0),
            audioFormat: 'wav',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('throws on empty audio bytes', () async {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.test.com',
        );
        final service = AsrService(config: config);
        expect(
          () => service.transcribe(
            audioBytes: Uint8List(0),
            audioFormat: 'wav',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('createAsrServiceFromConfig', () {
      test('creates service from config fields', () {
        final service = createAsrServiceFromConfig(
          host: 'https://api.test.com',
          apiKey: 'key',
          model: 'whisper-1',
        );
        expect(service, isNotNull);
        expect(service.config.model, equals('whisper-1'));
        expect(service.config.apiKey, equals('key'));
        expect(service.config.host, equals('https://api.test.com'));
      });

      test('creates service with language', () {
        final service = createAsrServiceFromConfig(
          host: 'https://api.test.com',
          apiKey: 'key',
          model: 'whisper-1',
          language: 'zh',
        );
        expect(service.config.language, equals('zh'));
      });
    });
  });
}
