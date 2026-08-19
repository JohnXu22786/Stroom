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

    test('data:application/json URI matches the generic data URI pattern', () {
      // The sanitizer now matches ALL data:<mime>;base64, URIs, not just
      // images. Even a "data:application/json" URI gets the data portion
      // stripped (with the prefix preserved) so JSON containing such a
      // value won't blow up the saved payload.
      const mixed = 'data:application/json;base64,{some data here}';
      final result = DataSanitizer.sanitizeBase64String(mixed);
      expect(result, startsWith('data:application/json;base64,'));
      expect(result, contains('[base64 data:'));
      // The original content is no longer present
      expect(result, isNot(contains('{some data here}')));
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
        'video data URI base64 is hidden (not just images) - critical for save size',
        () {
      // Bug fix: previously the sanitizer only matched data:image/...
      // Sending a video produced a huge data:video/mp4;base64,... string
      // that was saved verbatim into SharedPreferences, causing multi-MB
      // JSON files, UI freezes, and process kills on save.
      final longB64 = 'AAAAGGZ0eXBpc29tAAACAGlzb21pc28y' * 30;
      final dataUri = 'data:video/mp4;base64,$longB64';
      final result = DataSanitizer.sanitizeBase64String(dataUri);

      // The prefix is preserved for context, but the actual base64 is replaced.
      expect(result, startsWith('data:video/mp4;base64,'));
      expect(result, contains('[base64 data:'));
      expect(result, contains('bytes hidden]'));
      // The original base64 portion should NOT appear in full.
      expect(result, isNot(contains('AAAAGGZ0eXBpc29t')));
    });

    test(
        'application data URI base64 (e.g. PDF) is hidden - critical for save size',
        () {
      // PDFs and other documents can be 5-50MB, base64 → 7-70MB.
      // Saving the full base64 to SharedPreferences causes flash crashes
      // and silent data loss. Strip on save.
      final longB64 = 'aGVsbG8gd29ybGQgaGVsbG8gd29ybGQ=' * 30;
      final dataUri = 'data:application/pdf;base64,$longB64';
      final result = DataSanitizer.sanitizeBase64String(dataUri);

      expect(result, startsWith('data:application/pdf;base64,'));
      expect(result, contains('[base64 data:'));
      expect(result, contains('bytes hidden]'));
      expect(result, isNot(contains('aGVsbG8gd29ybGQ')));
    });

    test('audio data URI base64 is hidden', () {
      const longB64 = 'SUQzAwAAAAACdFRJVDIAAAAdAAADc3ViLm1wMwAAAA==';
      final dataUri = 'data:audio/mpeg;base64,$longB64';
      final result = DataSanitizer.sanitizeBase64String(dataUri);

      expect(result, startsWith('data:audio/mpeg;base64,'));
      expect(result, contains('[base64 data:'));
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

    test('input_audio.data (base64 audio) is sanitized', () {
      // OpenAI input_audio format: { type: "input_audio",
      //   input_audio: { data: "<base64>", format: "wav" } }
      // Without sanitization, the audio data blows up saved JSON.
      // Real audio data is always >> 300 chars (the sanitizer's threshold
      // for plain base64 without a data: URI prefix). Use a 500-char string
      // to comfortably exceed the threshold.
      final longB64 = 'A' * 500; // 500 chars of valid base64
      final input = {
        'role': 'user',
        'content': [
          {
            'type': 'input_audio',
            'input_audio': {'data': longB64, 'format': 'wav'},
          },
        ],
      };
      final result = DataSanitizer.sanitizeForDisplay(input) as Map;
      final parts = result['content'] as List;
      final audio = parts[0]['input_audio'] as Map;
      expect(audio['data'], contains('[base64 data:'));
      expect(audio['data'], isNot(equals(longB64)));
      // format field is preserved (it's a small enum-like string)
      expect(audio['format'], 'wav');
    });

    test('file.file_data (base64 PDF) is sanitized', () {
      // OpenRouter file format: { type: "file",
      //   file: { filename: "x.pdf", file_data: "data:application/pdf;base64,..." } }
      final longB64 = 'JVBERi0xLjQKJeLjz9MKMyAwIG9iago8PC9MZW5ndGggMzU+Pn' * 5;
      final input = {
        'type': 'file',
        'file': {
          'filename': 'report.pdf',
          'file_data': 'data:application/pdf;base64,$longB64',
        },
      };
      final result = DataSanitizer.sanitizeForDisplay(input) as Map;
      final file = result['file'] as Map;
      expect(file['file_data'], contains('[base64 data:'));
      expect(file['file_data'], isNot(contains('JVBERi0xLjQK')));
      // filename is preserved
      expect(file['filename'], 'report.pdf');
    });

    test('video_url.url (base64 video) is sanitized', () {
      final longB64 = 'AAAAGGZ0eXBpc29tAAACAGlzb21pc28y' * 30;
      final input = {
        'type': 'video_url',
        'video_url': {
          'url': 'data:video/mp4;base64,$longB64',
        },
      };
      final result = DataSanitizer.sanitizeForDisplay(input) as Map;
      final video = result['video_url'] as Map;
      expect(video['url'], contains('[base64 data:'));
      expect(video['url'], isNot(contains('AAAAGGZ0eXBpc29t')));
    });

    test('deeply nested multimodal messages all get sanitized', () {
      final input = {
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/png;base64,iVBORw0KGgoAAAA' * 10,
                },
              },
              {
                'type': 'video_url',
                'video_url': {
                  'url': 'data:video/mp4;base64,AAAAGGZ0' * 10,
                },
              },
              {
                'type': 'input_audio',
                'input_audio': {
                  'data': 'SUQzAwAAAAA' * 30,
                  'format': 'mp3',
                },
              },
            ],
          },
        ],
      };
      final result = DataSanitizer.sanitizeForDisplay(input) as Map;
      final parts = (result['messages'] as List)[0]['content'] as List;

      // All three attachment types should be sanitized
      expect((parts[0]['image_url'] as Map)['url'], contains('[base64 data:'));
      expect((parts[1]['video_url'] as Map)['url'], contains('[base64 data:'));
      expect(
          (parts[2]['input_audio'] as Map)['data'], contains('[base64 data:'));
    });
  });
}
