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
}
