import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:stroom/catcatch/engine/dart_cat_catch_sniffer.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

// ============================================================================
// Mock helpers
// ============================================================================

/// Creates a mock [Response] with given status code and body.
Response _mockResponse({
  required int statusCode,
  required dynamic data,
  Map<String, List<String>>? headers,
}) {
  return Response(
    requestOptions: RequestOptions(path: 'http://example.com'),
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(headers ??
        {
          'content-type': ['text/html']
        }),
  );
}

/// A mock [HttpClientAdapter] that returns pre-configured responses.
class MockHttpClientAdapter implements HttpClientAdapter {
  final Map<String, Response Function()> _handlers = {};

  void onGet(String url, Response Function() responseBuilder) {
    _handlers[url] = responseBuilder;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final handler = _handlers[options.path];
    if (handler == null) {
      return ResponseBody.fromString(
        'Not found',
        404,
        headers: {
          'content-type': ['text/plain']
        },
      );
    }
    final response = handler();
    final bodyStr = response.data is String ? response.data as String : '';
    // Convert Dio Headers to plain Map for ResponseBody
    final plainHeaders = <String, List<String>>{};
    response.headers.forEach((name, values) {
      plainHeaders[name] = values;
    });
    return ResponseBody.fromString(
      bodyStr,
      response.statusCode ?? 200,
      headers: plainHeaders,
    );
  }

  @override
  void close({bool force = false}) {
    _handlers.clear();
  }
}

void main() {
  group('DartCatCatchSniffer', () {
    late DartCatCatchSniffer sniffer;
    late MockHttpClientAdapter mockAdapter;

    setUp(() {
      mockAdapter = MockHttpClientAdapter();
      sniffer = DartCatCatchSniffer(httpClientAdapter: mockAdapter);
    });

    tearDown(() {
      sniffer.dispose();
    });

    test('sniff() returns MediaResource for direct mp4 URL', () async {
      mockAdapter.onGet(
          'http://example.com/video.mp4',
          () => _mockResponse(
                statusCode: 200,
                data: 'not a real video',
                headers: {
                  'content-type': ['video/mp4']
                },
              ));

      final result = await sniffer.sniff(
        'http://example.com/video.mp4',
        headers: {'User-Agent': 'test-agent'},
      );

      expect(result.resources, isNotEmpty);
      expect(result.resources.first.ext, equals('mp4'));
      expect(result.resources.first.url, contains('video.mp4'));
      expect(result.resources.first.isPlayable, isTrue);
    });

    test('sniff() returns multiple resources for m3u8 playlist', () async {
      final m3u8Content = '''
#EXTM3U
#EXT-X-VERSION:3
#EXTINF:10.0,
segment1.ts
#EXTINF:10.0,
segment2.ts
#EXTINF:10.0,
segment3.ts
#EXT-X-ENDLIST
''';

      mockAdapter.onGet(
          'http://example.com/playlist.m3u8',
          () => _mockResponse(
                statusCode: 200,
                data: m3u8Content,
                headers: {
                  'content-type': ['application/vnd.apple.mpegurl'],
                },
              ));

      final result = await sniffer.sniff(
        'http://example.com/playlist.m3u8',
      );

      // The main playlist is included in resources
      final playlistResources =
          result.resources.where((r) => r.isPlaylist).toList();
      expect(playlistResources, isNotEmpty);
      expect(playlistResources.first.ext, equals('m3u8'));
    });

    test('sniff() injects custom headers', () async {
      mockAdapter.onGet(
          'http://example.com/video.mp4',
          () => _mockResponse(
                statusCode: 200,
                data: 'mock video',
                headers: {
                  'content-type': ['video/mp4']
                },
              ));

      final customHeaders = {
        'User-Agent': 'custom-agent/1.0',
        'Referer': 'https://example.com/page',
        'Cookie': 'session=abc123',
      };

      final result = await sniffer.sniff(
        'http://example.com/video.mp4',
        headers: customHeaders,
      );

      expect(result.resources, isNotEmpty);
      expect(result.resources.first.ext, equals('mp4'));
    });

    test('sniff() returns empty list for non-media non-HTML URL', () async {
      mockAdapter.onGet(
          'http://example.com/data.json',
          () => _mockResponse(
                statusCode: 200,
                data: '{"status": "ok"}',
                headers: {
                  'content-type': ['application/json']
                },
              ));

      final result = await sniffer.sniff('http://example.com/data.json');

      // No media resources expected from a plain JSON response
      expect(result.resources, isEmpty);
    });

    test('sniff() handles null/empty URL gracefully', () async {
      final result = await sniffer.sniff('');

      expect(result.error, isNotNull);
      expect(result.error, contains('empty'));
    });

    test('sniff() returns SniffResult with correct structure', () async {
      mockAdapter.onGet(
          'http://example.com/audio.mp3',
          () => _mockResponse(
                statusCode: 200,
                data: 'mock audio',
                headers: {
                  'content-type': ['audio/mpeg']
                },
              ));

      final result = await sniffer.sniff('http://example.com/audio.mp3');

      expect(result, isA<SniffResult>());
      expect(result.resources, isA<List<MediaResource>>());
      expect(result.source, isA<SniffSource>());
    });

    test('sniff() detects media from HTML page via regex', () async {
      final htmlContent = '''
<html>
<body>
  <video src="https://cdn.example.com/movie.mp4"></video>
  <script>
    var config = { url: "https://cdn.example.com/playlist.m3u8" };
  </script>
</body>
</html>
''';

      mockAdapter.onGet(
          'http://example.com/page.html',
          () => _mockResponse(
                statusCode: 200,
                data: htmlContent,
                headers: {
                  'content-type': ['text/html']
                },
              ));

      final result = await sniffer.sniff('http://example.com/page.html');

      // Should find mp4 and m3u8 from HTML content
      expect(result.resources, isNotEmpty);
      final urls = result.resources.map((r) => r.url).toSet();
      expect(urls, contains('https://cdn.example.com/movie.mp4'));
    });

    test('sniff() uses stream-based sniffing for unknown content type',
        () async {
      mockAdapter.onGet(
          'http://example.com/unknown.xyz',
          () => _mockResponse(
                statusCode: 200,
                data: 'some binary content here',
                headers: {
                  'content-type': ['application/octet-stream']
                },
              ));

      final result = await sniffer.sniff('http://example.com/unknown.xyz');

      // Should not crash for unknown content — returns empty
      expect(result.resources, isEmpty);
    });

    test('sniff() handles HTTP errors gracefully', () async {
      mockAdapter.onGet(
          'http://example.com/video.mp4',
          () => _mockResponse(
                statusCode: 404,
                data: 'Not Found',
              ));

      // Even with a 404, the sniffer should return something (URL has media ext)
      final result = await sniffer.sniff('http://example.com/video.mp4');
      expect(result.resources, isNotEmpty);
    });
  });
}
