import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/m3u8_parser.dart';

void main() {
  test('counts media fragments without counting the initialization map',
      () async {
    const playlist = '''
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-MAP:URI="init.mp4"
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
      'https://example.com/hls/segment-1.m4s',
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
}
