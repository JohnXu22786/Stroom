import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/sse_client_web.dart' as web_sse;

void main() {
  group('web MCP SSE connection', () {
    test('non-2xx response is emitted as an HTTP stream error', () async {
      final missingPath = Uri.base.resolve('/missing-sse-endpoint').toString();
      final emittedLines = <String>[];

      try {
        await for (final line in web_sse.sseConnect(missingPath, const {})) {
          emittedLines.add(line);
        }
        fail('Expected the failed HTTP response to emit a stream error.');
      } on DioException catch (error) {
        expect(error.response?.statusCode, 404);
      }

      expect(emittedLines, isEmpty);
    });

    test('2xx response continues to stream SSE lines', () async {
      final testFile = Uri.base
          .resolve('/services/sse_client_web_connect_test.dart')
          .toString();

      final lines = await web_sse.sseConnect(testFile, const {}).toList();

      expect(lines, contains(contains('web MCP SSE connection')));
    });
  });
}
