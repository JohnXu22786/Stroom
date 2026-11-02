import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/m3u8_parser.dart';

void main() {
  test('includes the resolved initialization map before media segments',
      () async {
    const playlist = '''
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-MAP:URI="init.mp4"
#EXTINF:4.0,
segment-1.m4s
#EXT-X-ENDLIST
''';

    final resources = await M3U8Parser.parsePlaylist(
      playlist,
      'https://example.com/hls/playlist.m3u8',
    );

    expect(resources, [
      'https://example.com/hls/init.mp4',
      'https://example.com/hls/segment-1.m4s',
    ]);
  });
}
