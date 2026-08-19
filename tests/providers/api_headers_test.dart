import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/tts_provider.dart';
import 'package:stroom/services/ocr_service.dart';
import 'package:stroom/services/asr_service.dart';

/// OpenRouter-format headers expected on all API requests.
const _expectedReferer = 'https://github.com/JohnXu22786/Stroom';
const _expectedTitle = 'Stroom';

void main() {
  group('OpenAICompatibleChatProvider - OpenRouter-format headers', () {
    test('includes HTTP-Referer and X-Title in default Dio headers', () {
      final provider = OpenAICompatibleChatProvider(
        baseUrl: 'https://api.example.com',
        apiKey: 'sk-test',
      );

      final headers = provider.defaultHeaders;
      expect(headers, containsPair('HTTP-Referer', _expectedReferer));
      expect(headers, containsPair('X-Title', _expectedTitle));
      expect(headers, containsPair('Authorization', 'Bearer sk-test'));
    });

    test('includes HTTP-Referer and X-Title even when API key is empty', () {
      final provider = OpenAICompatibleChatProvider(
        baseUrl: 'https://api.example.com',
        apiKey: '',
      );

      final headers = provider.defaultHeaders;
      expect(headers, containsPair('HTTP-Referer', _expectedReferer));
      expect(headers, containsPair('X-Title', _expectedTitle));
      expect(headers, isNot(contains('Authorization')));
    });
  });

  group('CustomTTSProvider - OpenRouter-format headers', () {
    test('includes HTTP-Referer and X-Title in default Dio headers', () {
      final provider = CustomTTSProvider(
        baseUrl: 'https://tts.example.com',
        apiKey: 'sk-tts-test',
      );

      final headers = provider.defaultHeaders;
      expect(headers, containsPair('HTTP-Referer', _expectedReferer));
      expect(headers, containsPair('X-Title', _expectedTitle));
    });

    test('includes HTTP-Referer and X-Title even when API key is empty', () {
      final provider = CustomTTSProvider(
        baseUrl: 'https://tts.example.com',
        apiKey: '',
      );

      final headers = provider.defaultHeaders;
      expect(headers, containsPair('HTTP-Referer', _expectedReferer));
      expect(headers, containsPair('X-Title', _expectedTitle));
      expect(headers, isNot(contains('Authorization')));
    });
  });

  group('OcrService - OpenRouter-format headers', () {
    test('includes HTTP-Referer and X-Title in default Dio headers', () {
      final service = OcrService(
        config: OcrConfig(
          host: 'https://ocr.example.com',
          apiKey: 'sk-ocr-test',
        ),
      );

      final headers = service.defaultHeaders;
      expect(headers, containsPair('HTTP-Referer', _expectedReferer));
      expect(headers, containsPair('X-Title', _expectedTitle));
    });

    test('includes HTTP-Referer and X-Title even when API key is empty', () {
      final service = OcrService(
        config: OcrConfig(
          host: 'https://ocr.example.com',
          apiKey: '',
        ),
      );

      final headers = service.defaultHeaders;
      expect(headers, containsPair('HTTP-Referer', _expectedReferer));
      expect(headers, containsPair('X-Title', _expectedTitle));
      expect(headers, isNot(contains('Authorization')));
    });
  });

  group('AsrService - OpenRouter-format headers', () {
    test('includes HTTP-Referer and X-Title in default Dio headers', () {
      final service = AsrService(
        config: AsrConfig(
          host: 'https://asr.example.com',
          apiKey: 'sk-asr-test',
        ),
      );

      final headers = service.defaultHeaders;
      expect(headers, containsPair('HTTP-Referer', _expectedReferer));
      expect(headers, containsPair('X-Title', _expectedTitle));
    });

    test('includes HTTP-Referer and X-Title even when API key is empty', () {
      final service = AsrService(
        config: AsrConfig(
          host: 'https://asr.example.com',
          apiKey: '',
        ),
      );

      final headers = service.defaultHeaders;
      expect(headers, containsPair('HTTP-Referer', _expectedReferer));
      expect(headers, containsPair('X-Title', _expectedTitle));
      expect(headers, isNot(contains('Authorization')));
    });
  });
}
