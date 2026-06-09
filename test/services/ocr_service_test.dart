import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/ocr_service.dart';
import 'dart:typed_data';

void main() {
  group('OcrService', () {
    group('OcrConfig', () {
      test('can be created', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.model, equals('gpt-4o'));
        expect(config.apiKey, equals('test-key'));
        expect(config.host, equals('https://api.openai.com/v1'));
      });

      test('copies correctly', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final copy = config.copyWith(model: 'gpt-4o-mini');
        expect(copy.model, equals('gpt-4o-mini'));
        expect(copy.apiKey, equals('test-key'));
        expect(copy.host, equals('https://api.openai.com/v1'));
      });

      test('normalizedHost strips trailing slash', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.openai.com/v1/',
        );
        expect(config.normalizedHost.endsWith('/'), isFalse);
        expect(config.normalizedHost, equals('https://api.openai.com/v1'));
      });

      test('normalizedHost returns host as-is when no trailing slash', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.normalizedHost, equals('https://api.openai.com/v1'));
      });

      test('effectiveSystemPrompt uses default when null', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
        );
        expect(config.effectiveSystemPrompt, contains('提取图片'));
      });

      test('effectiveSystemPrompt uses custom when provided', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          systemPrompt: 'Custom prompt',
        );
        expect(config.effectiveSystemPrompt, equals('Custom prompt'));
      });
    });

    group('OcrResult', () {
      test('can be created with all fields', () {
        final result = OcrResult(
          text: 'Extracted text',
          processingTimeMs: 1500,
          imageCount: 3,
        );
        expect(result.text, equals('Extracted text'));
        expect(result.processingTimeMs, equals(1500));
        expect(result.imageCount, equals(3));
      });

      test('default values', () {
        final result = OcrResult(text: 'Hello');
        expect(result.processingTimeMs, isZero);
        expect(result.imageCount, equals(1));
      });
    });

    group('OcrService', () {
      test('can be created with config', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service, isNotNull);
      });

      test('recognize throws on empty host', () async {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: '',
        );
        final service = OcrService(config: config);
        expect(
          () => service.recognize(imageBytes: Uint8List(0), imageFormat: 'jpeg'),
          throwsA(isA<Exception>()),
        );
      });

      test('recognizeBatch throws on empty list', () async {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.test.com',
        );
        final service = OcrService(config: config);
        expect(
          () => service.recognizeBatch(imageBytesList: []),
          throwsArgumentError,
        );
      });
    });

    group('createOcrServiceFromConfig', () {
      test('creates service from config fields', () {
        final service = createOcrServiceFromConfig(
          host: 'https://api.test.com',
          apiKey: 'key',
          model: 'gpt-4o',
        );
        expect(service, isNotNull);
        expect(service.config.model, equals('gpt-4o'));
        expect(service.config.apiKey, equals('key'));
        expect(service.config.host, equals('https://api.test.com'));
      });
    });
  });
}
