import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/services/ocr_service.dart';

class _RequestCaptureAdapter implements HttpClientAdapter {
  Map<String, dynamic>? requestBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestBody = options.data as Map<String, dynamic>;
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {'content': 'recognized text'},
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in [const Locale('en', 'US'), const Locale('zh', 'CN')]) {
    test('sends the localized default system prompt for $locale', () async {
      final localizations = lookupAppLocalizations(locale);
      final adapter = _RequestCaptureAdapter();
      final service = OcrService(
        config: OcrConfig(
          apiKey: 'test-key',
          host: 'https://example.test/v1/chat/completions',
          systemPrompt: localizations.ocrDefaultSystemPrompt,
        ),
        dio: Dio()..httpClientAdapter = adapter,
      );

      await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));

      final messages = adapter.requestBody!['messages'] as List;
      expect(messages.first, {
        'role': 'system',
        'content': localizations.ocrDefaultSystemPrompt,
      });
    });
  }

  test('preserves explicit system prompt and configured user instruction',
      () async {
    final adapter = _RequestCaptureAdapter();
    const explicitPrompt = 'Keep this system prompt byte for byte.';
    const userInstruction = 'Read the invoice number and total.';
    final service = OcrService(
      config: const OcrConfig(
        apiKey: 'test-key',
        host: 'https://example.test/v1/chat/completions',
        systemPrompt: explicitPrompt,
        typeConfig: {'userInstruction': userInstruction},
      ),
      dio: Dio()..httpClientAdapter = adapter,
    );

    await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));

    final messages = adapter.requestBody!['messages'] as List;
    expect(messages.first, {'role': 'system', 'content': explicitPrompt});
    final userContent = messages.last['content'] as List;
    expect(userContent.last, {'type': 'text', 'text': userInstruction});
  });
}
