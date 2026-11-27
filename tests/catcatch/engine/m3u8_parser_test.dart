import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/m3u8_parser.dart';

void main() {
  test('counts media fragments without counting the initialization map',
      () async {
    const playlist = '''
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-MAP:URI="init.mp4",BYTERANGE="2@3"
#EXT-X-MAP:URI="init.mp4",BYTERANGE="3"
#EXTINF:4.0,
segment-1.m4s
#EXT-X-ENDLIST
''';

    final parsed = await M3U8Parser.parsePlaylistWithDetails(
      playlist,
      'https://example.com/hls/playlist.m3u8',
    );

    expect(parsed.mediaSegmentCount, 1);
    expect(parsed.hasInitializationMap, isTrue);
    expect(
      M3U8Parser.mergedFileExtension(
        hasInitializationMap: parsed.hasInitializationMap,
      ),
      'mp4',
    );
    expect(parsed.resources, [
      'https://example.com/hls/init.mp4',
      'https://example.com/hls/init.mp4',
      'https://example.com/hls/segment-1.m4s',
    ]);
    expect(parsed.playlistResources.take(2), [
      (
        url: 'https://example.com/hls/init.mp4',
        rangeStart: 3,
        rangeLength: 2,
      ),
      (
        url: 'https://example.com/hls/init.mp4',
        rangeStart: 5,
        rangeLength: 3,
      ),
    ]);
  });

  test('keeps MPEG-TS extension when playlist has no initialization map',
      () async {
    const playlist = '''
#EXTM3U
#EXTINF:4.0,
segment-1.ts
#EXT-X-ENDLIST
''';

    final parsed = await M3U8Parser.parsePlaylistWithDetails(
      playlist,
      'https://example.com/hls/playlist.m3u8',
    );

    expect(parsed.hasInitializationMap, isFalse);
    expect(
      M3U8Parser.mergedFileExtension(
        hasInitializationMap: parsed.hasInitializationMap,
      ),
      'ts',
    );
  });

  test('rejects an initialization map without a URI', () async {
    expect(
      M3U8Parser.parsePlaylistWithDetails(
        '''
#EXTM3U
#EXT-X-MAP:
#EXTINF:4.0,
segment.m4s
''',
        'https://example.com/hls/playlist.m3u8',
      ),
      throwsFormatException,
    );
  });

  test('rejects an initialization map with an empty URI', () async {
    expect(
      M3U8Parser.parsePlaylistWithDetails(
        '''
#EXTM3U
#EXT-X-MAP:URI=""
#EXTINF:4.0,
segment.m4s
''',
        'https://example.com/hls/playlist.m3u8',
      ),
      throwsFormatException,
    );
  });

  test('preserves explicit and implicit ranges for repeated fragment URLs',
      () async {
    const playlist = '''
#EXTM3U
#EXTINF:4.0,
#EXT-X-BYTERANGE:4@2
shared.ts
#EXTINF:4.0,
#EXT-X-BYTERANGE:3
shared.ts
#EXT-X-ENDLIST
''';

    final parsed = await M3U8Parser.parsePlaylistWithDetails(
      playlist,
      'https://example.com/hls/playlist.m3u8',
    );

    expect(parsed.resources, [
      'https://example.com/hls/shared.ts',
      'https://example.com/hls/shared.ts',
    ]);
    expect(parsed.playlistResources, [
      (
        url: 'https://example.com/hls/shared.ts',
        rangeStart: 2,
        rangeLength: 4,
      ),
      (
        url: 'https://example.com/hls/shared.ts',
        rangeStart: 6,
        rangeLength: 3,
      ),
    ]);
  });

  test('resolves protocol-relative segments against the playlist scheme',
      () async {
    const playlist = '''
#EXTM3U
#EXTINF:4.0,
//cdn.example:8443/video/chapter%2Fone.ts
#EXT-X-ENDLIST
''';

    final parsed = await M3U8Parser.parsePlaylistWithDetails(
      playlist,
      'https://source.example/hls/playlist.m3u8',
    );

    expect(parsed.resources, [
      'https://cdn.example:8443/video/chapter%2Fone.ts',
    ]);
  });

  test('fetches a protocol-relative variant from its own host', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    final serverSubscription = server.listen((request) async {
      requests.add(request.uri.path);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.text
        ..write('''
#EXTM3U
#EXTINF:4.0,
segment%2Fone.ts
#EXT-X-ENDLIST
''');
      await request.response.close();
    });

    try {
      final parsed = await M3U8Parser.parsePlaylistWithDetails(
        '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
//127.0.0.1:${server.port}/child/playlist.m3u8
''',
        'http://source.example/master.m3u8',
      );

      expect(requests, ['/child/playlist.m3u8']);
      expect(parsed.resources, [
        'http://127.0.0.1:${server.port}/child/segment%2Fone.ts',
      ]);
    } finally {
      await serverSubscription.cancel();
      await server.close(force: true);
    }
  });

  test('forwards URL-specific authentication headers to child playlists',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <HttpRequest>[];
    final serverSubscription = server.listen((request) async {
      requests.add(request);
      request.response
        ..statusCode = request.headers.value(HttpHeaders.cookieHeader) ==
                    'session=child' &&
                request.headers.value(HttpHeaders.refererHeader) ==
                    'https://example.com/watch'
            ? HttpStatus.ok
            : HttpStatus.forbidden
        ..headers.contentType = ContentType.text
        ..write('''
#EXTM3U
#EXTINF:4.0,
segment.ts
#EXT-X-ENDLIST
''');
      await request.response.close();
    });

    try {
      final childUrl = 'http://127.0.0.1:${server.port}/child/playlist.m3u8';
      final parsed = await M3U8Parser.parsePlaylistWithDetails(
        '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
${Uri.parse(childUrl).path}
''',
        'http://127.0.0.1:${server.port}/master.m3u8',
        headersForUrl: (url) => url == childUrl
            ? {
                HttpHeaders.cookieHeader: 'session=child',
                HttpHeaders.refererHeader: 'https://example.com/watch',
              }
            : const {},
      );

      expect(requests, hasLength(1));
      expect(requests.single.headers.value(HttpHeaders.userAgentHeader),
          contains('Mozilla/5.0'));
      expect(parsed.resources, [
        'http://127.0.0.1:${server.port}/child/segment.ts',
      ]);
    } finally {
      await serverSubscription.cancel();
      await server.close(force: true);
    }
  });

  test('cancels a child playlist fetch while its response is held', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestReceived = Completer<void>();
    final releaseResponse = Completer<void>();
    final serverSubscription = server.listen((request) async {
      if (!requestReceived.isCompleted) requestReceived.complete();
      await releaseResponse.future;
      request.response
        ..statusCode = HttpStatus.ok
        ..write('#EXTM3U\n#EXTINF:4.0,\nsegment.ts\n');
      await request.response.close();
    });
    final cancellation = Completer<void>();

    try {
      final parsing = M3U8Parser.parsePlaylistWithDetails(
        '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
/child/playlist.m3u8
''',
        'http://127.0.0.1:${server.port}/master.m3u8',
        cancellationSignal: cancellation.future,
      );
      await requestReceived.future;
      cancellation.complete();

      await expectLater(
        parsing.timeout(const Duration(seconds: 2)),
        throwsA(isA<StateError>()),
      );
    } finally {
      if (!releaseResponse.isCompleted) releaseResponse.complete();
      await serverSubscription.cancel();
      await server.close(force: true);
    }
  });
}
