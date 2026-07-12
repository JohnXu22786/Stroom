import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/data_sanitizer.dart';

void main() {
  group('DataSanitizer.sanitizeBase64String', () {
    test('data URI image with base64 is hidden with placeholder', () {
      const longBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
          'uP1fPQAIaAMONeFfTAAAAABJRU5ErkJggg==';
      final dataUri = 'data:image/png;base64,$longBase64';
      final result = DataSanitizer.sanitizeBase64String(dataUri);

      expect(result, startsWith('data:image/png;base64,'));
      expect(result, contains('[base64 data:'));
      expect(result, contains('bytes hidden]'));
      // The original base64 portion should NOT appear in full
      expect(result, isNot(contains('iVBORw0KGgo')));
    });

    test('long base64-only string (>=300 chars) is hidden', () {
      // Create a string of 300+ base64 characters
      final longB64 = 'A' * 300 + '==';
      final result = DataSanitizer.sanitizeBase64String(longB64);
      expect(result, '[base64 data: 302 bytes hidden]');
    });

    test('short normal string (<300 chars) passes through unchanged', () {
      const short = 'Hello, World!';
      expect(DataSanitizer.sanitizeBase64String(short), short);
    });

    test('mixed content string with non-base64 chars passes through', () {
      const mixed = 'data:application/json;base64,{some data here}';
      // This doesn't match image data URI pattern and is long enough
      // but contains non-base64 chars ({, }, space)
      expect(DataSanitizer.sanitizeBase64String(mixed), mixed);
    });

    test('empty string passes through', () {
      expect(DataSanitizer.sanitizeBase64String(''), '');
    });

    test('string exactly at boundary (299 chars) passes through', () {
      final b64 = 'A' * 299;
      expect(DataSanitizer.sanitizeBase64String(b64), b64);
    });

    test('string just over boundary (300 chars) is hidden if base64', () {
      final b64 = 'A' * 300;
      expect(DataSanitizer.sanitizeBase64String(b64),
          '[base64 data: 300 bytes hidden]');
    });

    test('data URI with jpeg type is also hidden', () {
      const longB64 = 'VBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUl'
          'EQVR42mNk+P1fPQAIaAMONeFfTAAAAABJRU5ErkJggg==';
      final dataUri = 'data:image/jpeg;base64,$longB64';
      final result = DataSanitizer.sanitizeBase64String(dataUri);
      expect(result, startsWith('data:image/jpeg;base64,'));
      expect(result, contains('[base64 data:'));
    });

    test('data URI with webp type is also hidden', () {
      const longB64 = 'VBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUl'
          'EQVR42mNk+P1fPQAIaAMONeFfTAAAAABJRU5ErkJggg==';
      final dataUri = 'data:image/webp;base64,$longB64';
      final result = DataSanitizer.sanitizeBase64String(dataUri);
      expect(result, contains('[base64 data:'));
    });

    test('data URI with gif type is also hidden', () {
      const longB64 = 'VBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUl'
          'EQVR42mNk+P1fPQAIaAMONeFfTAAAAABJRU5ErkJggg==';
      final dataUri = 'data:image/gif;base64,$longB64';
      final result = DataSanitizer.sanitizeBase64String(dataUri);
      expect(result, contains('[base64 data:'));
    });
    test('data URI with svg+xml type is also hidden', () {
      // svg+xml contains '+' which was not matched by the old regex
      const longB64 = 'VBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUl'
          'EQVR42mNk+P1fPQAIaAMONeFfTAAAAABJRU5ErkJggg==';
      final dataUri = 'data:image/svg+xml;base64,$longB64';
      final result = DataSanitizer.sanitizeBase64String(dataUri);
      expect(result, contains('[base64 data:'));
    });

    test(
        'non-image data URI (application/pdf) is not hidden by image regex but returns without freeze',
        () {
      // Non-image data URIs don't match the ^data:image/... regex.
      // The pure base64 check also won't match because the prefix
      // 'data:application/pdf;base64,' contains non-base64 characters.
      // Important: the function returns the string as-is (no freeze/crash).
      final longB64 =
          'aGVsbG8gd29ybGQgaGVsbG8gd29ybGQ=' * 20; // >300 chars base64
      final dataUri = 'data:application/pdf;base64,$longB64';
      final result = DataSanitizer.sanitizeBase64String(dataUri);
      // The prefix is preserved; the full string is returned (not hidden)
      expect(result, startsWith('data:application/pdf;base64,'));
      expect(result, contains(longB64));
    });

    test('multi-line base64 with embedded newlines is detected', () {
      // Some base64 encoders insert newlines every 76 characters.
      // Need total >= 300 chars of base64 content (excluding newlines).
      // 76*4 = 304 + 3 newlines = 307 total
      final b64WithNewlines =
          '${'A' * 76}\n${'B' * 76}\n${'C' * 76}\n${'D' * 76}';
      final result = DataSanitizer.sanitizeBase64String(b64WithNewlines);
      expect(result, '[base64 data: 307 bytes hidden]');
    });

    test('multi-line base64 with embedded carriage returns is detected', () {
      // 76*4 = 304 + 3*\r\n = 310 total chars, >= 300 threshold
      final b64WithCR =
          '${'X' * 76}\r\n${'Y' * 76}\r\n${'Z' * 76}\r\n${'W' * 76}';
      final result = DataSanitizer.sanitizeBase64String(b64WithCR);
      expect(result, '[base64 data: 310 bytes hidden]');
    });

    test('large pure-base64 string does not cause full-string regex freeze',
        () {
      // Create a 1MB base64 string - the regex should only check first 100 chars
      final largeB64 = 'A' * 1000000;
      final result = DataSanitizer.sanitizeBase64String(largeB64);
      expect(result, '[base64 data: 1000000 bytes hidden]');
    });
  });

  group('DataSanitizer.sanitizeForDisplay', () {
    test('Map with base64 values is recursively sanitized', () {
      final input = {
        'url': 'https://example.com',
        'body': {
          'image': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAY'
              'AAAAfFcSJAAAADUlEQVR42mNk+P1fPQAIaAMONeFfTAAAAABJRU5ErkJggg==',
          'text': 'hello',
        },
      };
      final result = DataSanitizer.sanitizeForDisplay(input);
      final body = result['body'] as Map<String, dynamic>;
      expect(body['image'], contains('[base64 data:'));
      expect(body['text'], 'hello');
    });

    test('List with base64 items is recursively sanitized', () {
      final input = [
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
            'AAAADUlEQVR42mNk+P1fPQAIaAMONeFfTAAAAABJRU5ErkJggg==',
        'normal text',
      ];
      final result = DataSanitizer.sanitizeForDisplay(input) as List;
      expect(result[0], contains('[base64 data:'));
      expect(result[1], 'normal text');
    });

    test('null, numbers, bool pass through unchanged', () {
      final input = {
        'nullValue': null,
        'intValue': 42,
        'doubleValue': 3.14,
        'boolValue': true,
        'string': 'hello',
      };
      final result = DataSanitizer.sanitizeForDisplay(input);
      expect(result['nullValue'], null);
      expect(result['intValue'], 42);
      expect(result['doubleValue'], 3.14);
      expect(result['boolValue'], true);
      expect(result['string'], 'hello');
    });

    test('nested empty containers pass through', () {
      final input = {'empty': <String, dynamic>{}, 'items': <dynamic>[]};
      final result = DataSanitizer.sanitizeForDisplay(input);
      expect(result['empty'], <String, dynamic>{});
      expect(result['items'], <dynamic>[]);
    });
  });
}
