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
}
