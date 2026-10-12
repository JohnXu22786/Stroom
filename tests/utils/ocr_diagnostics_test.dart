import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/ocr_diagnostics.dart';

void main() {
  test(
    'sanitized diagnostics keep request metadata but drop bodies and keys',
    () {
      final imageBody =
          'data:image/png;base64,${List.filled(12000, 'x').join()}';
      const apiKey = 'sk-secret-provider-key';
      final request = OcrDiagnosticSnapshot.sanitizeRequest({
        'url': 'https://user:$apiKey@ocr.example.test/v1?api_key=$apiKey',
        'method': 'POST',
        'imageCount': 3,
        'imageBytes': 12000,
        'durationMs': 842,
        'headers': {
          'Authorization': 'Bearer $apiKey',
          'x-request-id': ['req-123'],
        },
        'body': {'image': imageBody, 'api_key': apiKey},
      })!;
      final response = OcrDiagnosticSnapshot.sanitizeResponse({
        'statusCode': 429,
        'durationMs': 842,
        'headers': {
          'Authorization': 'Bearer $apiKey',
          'x-request-id': ['req-123'],
        },
        'data': {
          'choices': [
            {
              'finish_reason': 'length',
              'message': {'content': imageBody},
            },
          ],
          'api_key': apiKey,
        },
      })!;

      final encoded = jsonEncode({'request': request, 'response': response});
      expect(request['host'], 'ocr.example.test');
      expect(request['imageCount'], 3);
      expect(request['imageBytes'], 12000);
      expect(request['requestId'], 'req-123');
      expect(response['statusCode'], 429);
      expect(response['finishReason'], 'length');
      expect(response['requestId'], 'req-123');
      expect(encoded, isNot(contains(apiKey)));
      expect(encoded, isNot(contains('data:image')));
      expect(encoded, isNot(contains('Authorization')));
      expect(utf8.encode(encoded).length, lessThanOrEqualTo(2048));
    },
  );

  test('legacy raw OCR diagnostic maps are reduced to allowlisted fields', () {
    final request = OcrDiagnosticSnapshot.sanitizeRequest({
      'url': 'https://ocr.example.test/v1?token=private',
      'headers': {'Authorization': 'Bearer private'},
      'body': {'messages': 'large base64 payload'},
    })!;
    final response = OcrDiagnosticSnapshot.sanitizeResponse({
      'statusCode': 503,
      'headers': {
        'x-request-id': ['req-old'],
      },
      'data': {
        'choices': [
          {
            'finish_reason': 'stop',
            'message': {'content': 'private text'},
          },
        ],
      },
    })!;

    expect(request, {'host': 'ocr.example.test'});
    expect(response, {
      'statusCode': 503,
      'finishReason': 'stop',
      'requestId': 'req-old',
    });
  });

  test('credential-shaped values are dropped from request ID fields', () {
    final googleApiKey = 'AIza${List.filled(35, 'a').join()}';
    const openAiProjectKey = 'sk-proj-abcdefghijklmnopqrstuvwxyz1234567890';
    const anthropicApiKey = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz1234567890';
    const groqApiKey = 'gsk_abcdefghijklmnopqrstuvwxyz1234567890';
    const openRouterApiKey = 'sk-or-v1-abcdefghijklmnopqrstuvwxyz1234567890';
    final request = OcrDiagnosticSnapshot.sanitizeRequest({
      'requestId': googleApiKey,
    })!;
    final response = OcrDiagnosticSnapshot.sanitizeResponse({
      'data': {'id': googleApiKey},
    })!;
    final prefixedGoogleKey = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': 'provider $googleApiKey',
    })!;
    final tokenAssignment = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': 'provider token=private-value',
    })!;
    final bearerAssignment = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': 'provider bearer=private-value',
    })!;
    final prefixedApiKey = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': 'provider xApiKey=private-value',
    })!;
    final spacedApiKey = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': 'provider API key=private-value',
    })!;
    final bareKeyAssignment = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': 'provider key=private-value',
    })!;
    final openAiProjectRequestId = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': openAiProjectKey,
    })!;
    final anthropicRequestId = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': anthropicApiKey,
    })!;
    final groqRequestId = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': groqApiKey,
    })!;
    final openRouterRequestId = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': openRouterApiKey,
    })!;

    expect(request, isEmpty);
    expect(response, isEmpty);
    expect(prefixedGoogleKey, isEmpty);
    expect(tokenAssignment, isEmpty);
    expect(bearerAssignment, isEmpty);
    expect(prefixedApiKey, isEmpty);
    expect(spacedApiKey, isEmpty);
    expect(bareKeyAssignment, isEmpty);
    expect(openAiProjectRequestId, isEmpty);
    expect(anthropicRequestId, isEmpty);
    expect(groqRequestId, isEmpty);
    expect(openRouterRequestId, isEmpty);
    expect(jsonEncode([request, response]), isNot(contains(googleApiKey)));
  });

  test(
    'request IDs redact configured credentials with inserted whitespace',
    () {
      const apiKey = 'opaque-user-secret-87';
      final spacedApiKey = apiKey.split('').join(' ');
      final response = OcrDiagnosticSnapshot.sanitizeResponse(
        {'requestId': 'req-$spacedApiKey'},
        excludedValues: [apiKey],
      )!;

      expect(response, isEmpty);
      expect(jsonEncode(response), isNot(contains(apiKey)));
    },
  );

  test('image data URIs are dropped from response request IDs', () {
    const imageDataUri = 'data:image/png;base64,AA==';
    final response = OcrDiagnosticSnapshot.sanitizeResponse({
      'data': {'id': imageDataUri},
    })!;

    expect(response, isEmpty);
    expect(jsonEncode(response), isNot(contains(imageDataUri)));
  });

  test('bare PNG base64 is dropped from request ID fields', () {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYGAAAAAEAAH2FzhVAAAAAElFTkSuQmCC';
    final request = OcrDiagnosticSnapshot.sanitizeRequest({
      'headers': {'x-request-id': png},
    })!;
    final response = OcrDiagnosticSnapshot.sanitizeResponse({
      'headers': {'x-request-id': png},
      'data': {'id': png},
    })!;

    expect(request, isEmpty);
    expect(response, isEmpty);
    expect(jsonEncode([request, response]), isNot(contains(png)));
  });

  test('short embedded image signatures are dropped from metadata fields', () {
    const pngSignature = 'iVBORw0KGgo';
    final response = OcrDiagnosticSnapshot.sanitizeResponse({
      'statusCode': 503,
      'requestId': 'req-$pngSignature',
      'finishReason': pngSignature,
      'errorType': pngSignature,
    })!;

    expect(response, {'statusCode': 503});
    expect(jsonEncode(response), isNot(contains(pngSignature)));
  });

  test('request IDs reject prose from generic provider id fields', () {
    final response = OcrDiagnosticSnapshot.sanitizeResponse({
      'data': {'id': 'Read the private receipt amount carefully'},
    })!;
    final opaqueId = OcrDiagnosticSnapshot.sanitizeResponse({
      'data': {'id': 'chatcmpl-123abc_xyz'},
    })!;

    expect(response, isEmpty);
    expect(opaqueId, {'requestId': 'chatcmpl-123abc_xyz'});
  });

  test('request ID fallback validates each provider field independently', () {
    final response = OcrDiagnosticSnapshot.sanitizeResponse({
      'data': {
        'request_id': 'Read the private receipt amount carefully',
        'requestId': 'req-safe-123',
        'id': 'chatcmpl-later-safe-id',
      },
    })!;

    expect(response, {'requestId': 'req-safe-123'});
  });

  test('short legacy OCR task errors redact token assignments', () {
    expect(
      OcrDiagnosticSnapshot.sanitizeStoredTaskError(
        'OCR 请求被模型拒绝: token=private-value',
      ),
      'OCR 错误详情已隐藏',
    );
  });

  test('short bare base64 image bodies are hidden from legacy task errors', () {
    const imageBodies = [
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/1s8AAAAASUVORK5CYII=',
      'UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEAAUAmJaQAA3AA/v89WAAAAA==',
    ];

    for (final imageBody in imageBodies) {
      expect(imageBody.length, lessThan(160));
      expect(
        OcrDiagnosticSnapshot.sanitizeStoredTaskError(imageBody),
        'OCR 错误详情已隐藏',
      );
    }
    expect(
      OcrDiagnosticSnapshot.sanitizeStoredTaskError(
        'OCR 任务因格式问题未完成',
      ),
      'OCR 任务因格式问题未完成',
    );
  });

  test('short bare image bodies are hidden inside legacy refusal text', () {
    const imageBodies = [
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/1s8AAAAASUVORK5CYII=',
      'UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEAAUAmJaQAA3AA/v89WAAAAA==',
    ];

    for (final imageBody in imageBodies) {
      final wrappedBody = imageBody.replaceAllMapped(
        RegExp(r'.{1,4}'),
        (match) => '${match.group(0)} ',
      );
      final refusal = 'Exception: OCR 请求被模型拒绝: $wrappedBody';
      expect(refusal.length, lessThan(160));
      expect(
        OcrDiagnosticSnapshot.sanitizeStoredTaskError(refusal),
        'OCR 错误详情已隐藏',
      );
    }
  });

  test('legacy task error details exclude recovered credentials', () {
    const apiKey = 'opaque-user-secret-87';
    final sanitized = OcrDiagnosticSnapshot.sanitizeStoredTaskError(
      'OCR 请求失败 HTTP 503 finish_reason=$apiKey',
      excludedValues: [apiKey],
    )!;

    expect(sanitized, contains('HTTP 503'));
    expect(sanitized, isNot(contains(apiKey)));
    expect(sanitized, isNot(contains('finish_reason=')));
  });

  test('legacy task error details exclude an unsafe HTTP status token', () {
    final sanitized = OcrDiagnosticSnapshot.sanitizeStoredTaskError(
      'OCR 请求失败 HTTP 503',
      excludedValues: ['503'],
    )!;

    expect(sanitized, 'OCR 错误详情已隐藏');
    expect(sanitized, isNot(contains('503')));
  });

  test('safe Dio error types still honor recovered credential exclusions', () {
    const credential = 'connectionTimeout';
    final sanitized = OcrDiagnosticSnapshot.sanitizeStoredTaskError(
      'OCR 请求失败（$credential）',
      excludedValues: [credential],
    )!;

    expect(sanitized, 'OCR 错误详情已隐藏');
    expect(sanitized, isNot(contains(credential)));
  });

  test('response error types honor configured credential exclusions', () {
    const credential = 'connectionTimeout';
    final excluded = OcrDiagnosticSnapshot.sanitizeResponse(
      {'errorType': credential},
      excludedValues: [credential],
    )!;
    final safe = OcrDiagnosticSnapshot.sanitizeResponse(
      {'errorType': credential},
      excludedValues: ['unrelated-secret'],
    )!;

    expect(excluded, isEmpty);
    expect(safe, {'errorType': credential});
  });

  test('request IDs redact credential fields with underscore prefixes', () {
    final response = OcrDiagnosticSnapshot.sanitizeResponse({
      'requestId': 'provider client_secret=private-value',
    })!;

    expect(response, isEmpty);
  });

  test('finish reasons exclude configured credentials', () {
    const apiKey = 'opaque-user-secret-87';
    final response = OcrDiagnosticSnapshot.sanitizeResponse(
      {
        'data': {
          'choices': [
            {'finish_reason': apiKey},
          ],
        },
      },
      excludedValues: [apiKey],
    )!;

    expect(response, isEmpty);
  });

  test('finish reasons redact credential-shaped values', () {
    const apiKey = 'sk-proj-abcdefghijklmnopqrstuvwxyz1234567890';
    final response = OcrDiagnosticSnapshot.sanitizeResponse({
      'finishReason': apiKey,
    })!;

    expect(response, isEmpty);
    expect(jsonEncode(response), isNot(contains(apiKey)));
  });
}
