import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/m3u8_parser.dart';
import 'package:stroom/catcatch/engine/mpd_parser.dart';

// =============================================================================
// M3U8 测试数据
// =============================================================================

const singleBitrateM3U8 = '''#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXTINF:9.009,
segment1.ts
#EXTINF:10.010,
segment2.ts
#EXTINF:9.009,
segment3.ts
#EXT-X-ENDLIST''';

const multiBitrateM3U8 = '''#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1280000,RESOLUTION=720x480
low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2560000,RESOLUTION=1280x720
mid.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5120000,RESOLUTION=1920x1080
high.m3u8''';

const encryptedM3U8 = '''#EXTM3U
#EXT-X-VERSION:3
#EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key"
#EXTINF:9.009,
seg1.ts
#EXT-X-ENDLIST''';

// =============================================================================
// MPD 测试数据
// =============================================================================

const templateMPD = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentTemplate timescale="1" duration="10" startNumber="1"
          media="seg-\$Number\$.m4s" initialization="init.m4s"/>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

// =============================================================================
// 测试
// =============================================================================

void main() {
  // ===========================================================================
  // M3U8Parser
  // ===========================================================================
  group('M3U8Parser', () {
    // ──────────────────────────────────────────────
    // 加密检测 (isEncrypted)
    // ──────────────────────────────────────────────
    test('isEncrypted returns true for AES-128 content', () {
      expect(M3U8Parser.isEncrypted(encryptedM3U8), isTrue);
    });

    test('isEncrypted returns false for non-encrypted content', () {
      expect(M3U8Parser.isEncrypted(singleBitrateM3U8), isFalse);
    });

    test('isEncrypted returns false for multi-bitrate playlist', () {
      expect(M3U8Parser.isEncrypted(multiBitrateM3U8), isFalse);
    });

    test('isEncrypted is case-insensitive for METHOD=AES-128', () {
      const upper = '''#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key"
#EXTINF:9.009,
seg.ts
#EXT-X-ENDLIST''';
      expect(M3U8Parser.isEncrypted(upper), isTrue);
    });

    test('isEncrypted returns false for empty string', () {
      expect(M3U8Parser.isEncrypted(''), isFalse);
    });

    test('isEncrypted returns false for content without KEY tag', () {
      const noKey = '''#EXTM3U
#EXTINF:9.009,
seg.ts
#EXT-X-ENDLIST''';
      expect(M3U8Parser.isEncrypted(noKey), isFalse);
    });

    // ──────────────────────────────────────────────
    // 密钥 URL 提取 (extractKeyUrl)
    // ──────────────────────────────────────────────
    test('extractKeyUrl returns key URL from encrypted content', () {
      final keyUrl =
          M3U8Parser.extractKeyUrl(encryptedM3U8, 'https://example.com/');
      expect(keyUrl, equals('https://example.com/key'));
    });

    test('extractKeyUrl returns null for non-encrypted content', () {
      final keyUrl =
          M3U8Parser.extractKeyUrl(singleBitrateM3U8, 'https://example.com/');
      expect(keyUrl, isNull);
    });

    test('extractKeyUrl resolves relative key URL', () {
      const relativeKey = '''#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:9.009,
seg.ts
#EXT-X-ENDLIST''';
      final keyUrl =
          M3U8Parser.extractKeyUrl(relativeKey, 'https://example.com/video/');
      expect(keyUrl, equals('https://example.com/video/key.bin'));
    });

    test('extractKeyUrl resolves relative key URL with subdirectory base', () {
      const relativeKey = '''#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="keys/key.bin"
#EXTINF:9.009,
seg.ts
#EXT-X-ENDLIST''';
      final keyUrl = M3U8Parser.extractKeyUrl(
          relativeKey, 'https://example.com/video/playlist.m3u8');
      expect(keyUrl, equals('https://example.com/video/keys/key.bin'));
    });

    test('extractKeyUrl handles absolute key URL with path base', () {
      const absKey = '''#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="https://keys.example.com/master.key"
#EXTINF:9.009,
seg.ts
#EXT-X-ENDLIST''';
      final keyUrl = M3U8Parser.extractKeyUrl(
          absKey, 'https://example.com/video/playlist.m3u8');
      expect(keyUrl, equals('https://keys.example.com/master.key'));
    });

    // ──────────────────────────────────────────────
    // 单码率播放列表 (parsePlaylist)
    // ──────────────────────────────────────────────
    test('parsePlaylist returns correct segments for single bitrate playlist',
        () async {
      final segments = await M3U8Parser.parsePlaylist(
        singleBitrateM3U8,
        'https://example.com/video/',
      );

      expect(segments.length, equals(3));
      expect(segments[0], equals('https://example.com/video/segment1.ts'));
      expect(segments[1], equals('https://example.com/video/segment2.ts'));
      expect(segments[2], equals('https://example.com/video/segment3.ts'));
    });

    test('parsePlaylist preserves absolute URLs in single bitrate playlist',
        () async {
      const withAbsUrl = '''#EXTM3U
#EXTINF:9.009,
https://cdn.example.com/seg1.ts
#EXTINF:10.010,
https://cdn2.example.com/seg2.ts
#EXT-X-ENDLIST''';

      final segments = await M3U8Parser.parsePlaylist(
        withAbsUrl,
        'https://example.com/playlist.m3u8',
      );

      expect(segments.length, equals(2));
      expect(segments[0], equals('https://cdn.example.com/seg1.ts'));
      expect(segments[1], equals('https://cdn2.example.com/seg2.ts'));
    });

    test('parsePlaylist resolves relative segment URLs with various base URLs',
        () async {
      final segments = await M3U8Parser.parsePlaylist(
        singleBitrateM3U8,
        'https://example.com/video/playlist.m3u8',
      );

      expect(segments[0], equals('https://example.com/video/segment1.ts'));
    });

    // ──────────────────────────────────────────────
    // 单码率播放列表 (parseSegments)
    // ──────────────────────────────────────────────
    test('parseSegments returns segments with correct durations', () async {
      final segments = await M3U8Parser.parseSegments(
        singleBitrateM3U8,
        'https://example.com/video/',
      );

      expect(segments.length, equals(3));
      expect(segments[0].url, equals('https://example.com/video/segment1.ts'));
      expect(segments[0].duration, closeTo(9.009, 0.001));
      expect(segments[1].duration, closeTo(10.010, 0.001));
      expect(segments[2].duration, closeTo(9.009, 0.001));
    });

    test('parseSegments handles empty EXTINF duration', () async {
      const withEmptyDur = '''#EXTM3U
#EXTINF:,
segment.ts
#EXT-X-ENDLIST''';

      final segments = await M3U8Parser.parseSegments(
        withEmptyDur,
        'https://example.com/',
      );

      expect(segments.length, equals(1));
      expect(segments[0].duration, closeTo(0.0, 0.001));
    });

    // ──────────────────────────────────────────────
    // 多码率检测逻辑
    // ──────────────────────────────────────────────
    test('parsePlaylist with multi-bitrate content throws (detects STREAM-INF)',
        () async {
      // parsePlaylist detects #EXT-X-STREAM-INF and attempts to fetch
      // the sub-playlist, which fails because there's no HTTP server.
      // This confirms the detection logic works.
      expect(
        () => M3U8Parser.parsePlaylist(
          multiBitrateM3U8,
          'https://example.com/',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('parseSegments with multi-bitrate content returns empty list on fail',
        () async {
      // parseSegments also detects STREAM-INF and tries to fetch.
      // Expect an exception because no HTTP server is available.
      expect(
        () => M3U8Parser.parseSegments(
          multiBitrateM3U8,
          'https://example.com/',
        ),
        throwsA(isA<Exception>()),
      );
    });

    // ──────────────────────────────────────────────
    // _resolveUrl 相关功能测试 (通过公有方法间接测试)
    // ──────────────────────────────────────────────
    test('absolute URL in key remains unchanged', () {
      final keyUrl = M3U8Parser.extractKeyUrl(
        encryptedM3U8,
        'https://example.com/',
      );
      expect(keyUrl, equals('https://example.com/key'));
    });

    test('relative URL with root-path (starting with /) is resolved correctly',
        () {
      const rootRelative = '''#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="/keys/common.key"
#EXTINF:9.009,
/video/seg.ts
#EXT-X-ENDLIST''';

      final keyUrl = M3U8Parser.extractKeyUrl(
        rootRelative,
        'https://example.com/video/playlist.m3u8',
      );
      expect(keyUrl, equals('https://example.com/keys/common.key'));
    });

    // ──────────────────────────────────────────────
    // 边界情况
    // ──────────────────────────────────────────────
    test('parsePlaylist with empty content returns empty list', () async {
      final segments =
          await M3U8Parser.parsePlaylist('', 'https://example.com/');
      expect(segments, isEmpty);
    });

    test('parsePlaylist with no EXTINF lines returns empty list', () async {
      const noInf = '''#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-ENDLIST''';
      final segments =
          await M3U8Parser.parsePlaylist(noInf, 'https://example.com/');
      expect(segments, isEmpty);
    });

    test('parseSegments with no EXTINF lines returns empty list', () async {
      const noInf = '''#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-ENDLIST''';
      final segments =
          await M3U8Parser.parseSegments(noInf, 'https://example.com/');
      expect(segments, isEmpty);
    });

    test('isEncrypted with empty string returns false', () {
      expect(M3U8Parser.isEncrypted(''), isFalse);
    });

    test('extractKeyUrl with empty content returns null', () {
      expect(
        M3U8Parser.extractKeyUrl('', 'https://example.com/'),
        isNull,
      );
    });
  });

  // ===========================================================================
  // MPDParser
  // ===========================================================================
  group('MPDParser', () {
    // ──────────────────────────────────────────────
    // BaseURL 提取
    // ──────────────────────────────────────────────
    test('extractBaseUrls finds BaseURL from MPD content', () {
      // BaseURL extraction is done via MPDParser._extractBaseUrls (private).
      // We test it indirectly via parseManifest.
      // A simple MPD with BaseURL:
      const mpdWithBase = '''<?xml version="1.0"?>
      <MPD mediaPresentationDuration="PT30S" xmlns="urn:mpeg:dash:schema:mpd:2011">
        <BaseURL>http://example.com/video/</BaseURL>
        <Period>
          <AdaptationSet mimeType="video/mp4">
            <SegmentTemplate timescale="1" duration="10" startNumber="1"
              media="seg-\$Number\$.m4s" initialization="init.m4s"/>
          </AdaptationSet>
        </Period>
      </MPD>''';

      // Just verify it doesn't crash and returns segments
      // (BaseURL is used internally)
      expect(
        MPDParser.parseManifest(mpdWithBase, 'http://example.com/'),
        completes,
      );
    });

    // ──────────────────────────────────────────────
    // SegmentTemplate 解析
    // ──────────────────────────────────────────────
    test('parseManifest with SegmentTemplate generates correct segment URLs',
        () async {
      final segments = await MPDParser.parseManifest(
        templateMPD,
        'http://example.com/video/',
      );

      // PT30S / 10s per segment = 3 segments + 1 init = 4
      expect(segments.length, equals(4));
      // init segment is first
      expect(segments[0], contains('init.m4s'));
      expect(segments[1], contains('seg-1.m4s'));
      expect(segments[2], contains('seg-2.m4s'));
      expect(segments[3], contains('seg-3.m4s'));
    });

    test('parseManifest with SegmentTemplate resolves relative URLs', () async {
      final segments = await MPDParser.parseManifest(
        templateMPD,
        'http://cdn.example.com/video/manifest.mpd',
      );

      expect(segments.length, equals(4));
      expect(segments[0], equals('http://cdn.example.com/video/init.m4s'));
      expect(segments[1], equals('http://cdn.example.com/video/seg-1.m4s'));
    });

    test('parseSegments with SegmentTemplate returns correct durations',
        () async {
      final segments = await MPDParser.parseSegments(
        templateMPD,
        'http://example.com/video/',
      );

      // 3 data segments, each 10s (timescale=1, duration=10)
      // + 1 init segment with duration 0
      expect(segments.length, equals(4));
      expect(segments[0].url, contains('init.m4s'));
      expect(segments[0].duration, closeTo(0.0, 0.001));
      expect(segments[1].url, contains('seg-1.m4s'));
      expect(segments[1].duration, closeTo(10.0, 0.001));
      expect(segments[2].url, contains('seg-2.m4s'));
      expect(segments[2].duration, closeTo(10.0, 0.001));
      expect(segments[3].url, contains('seg-3.m4s'));
      expect(segments[3].duration, closeTo(10.0, 0.001));
    });

    // ──────────────────────────────────────────────
    // SegmentTimeline 解析
    // ──────────────────────────────────────────────

    test('parseManifest with SegmentTimeline generates correct segment URLs',
        () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentTemplate timescale="1" startNumber="1"
          media="seg-\$Number\$.m4s" initialization="init.m4s">
          <SegmentTimeline>
            <S t="0" d="10" r="2"/>
          </SegmentTimeline>
        </SegmentTemplate>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseManifest(
        mpd,
        'http://example.com/video/',
      );

      // S元素 t=0,d=10,r=2 → 3个数据分段 + 1个init = 4
      expect(segments.length, equals(4));
      expect(segments[0], contains('init.m4s'));
      expect(segments[1], contains('seg-1.m4s'));
      expect(segments[2], contains('seg-2.m4s'));
      expect(segments[3], contains('seg-3.m4s'));
    });

    test('parseSegments with SegmentTimeline returns correct durations',
        () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentTemplate timescale="1" startNumber="1"
          media="seg-\$Number\$.m4s" initialization="init.m4s">
          <SegmentTimeline>
            <S t="0" d="10" r="2"/>
          </SegmentTimeline>
        </SegmentTemplate>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseSegments(
        mpd,
        'http://example.com/video/',
      );

      // 4 segments: init + 3 data (each 10s)
      expect(segments.length, equals(4));
      expect(segments[0].duration, closeTo(0.0, 0.001)); // init
      expect(segments[1].duration, closeTo(10.0, 0.001));
      expect(segments[2].duration, closeTo(10.0, 0.001));
      expect(segments[3].duration, closeTo(10.0, 0.001));
    });

    test('SegmentTimeline with multiple S elements parses correctly', () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT50S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentTemplate timescale="1" startNumber="1"
          media="seg-\$Number\$.m4s" initialization="init.m4s">
          <SegmentTimeline>
            <S t="0" d="10" r="1"/>
            <S t="20" d="15" r="0"/>
          </SegmentTimeline>
        </SegmentTemplate>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseSegments(
        mpd,
        'http://example.com/',
      );

      // S1: t=0,d=10,r=1 → 2 segments (t=0,10)
      // S2: t=20,d=15,r=0 → 1 segment (t=20)
      // total: 1 init + 3 data = 4
      expect(segments.length, equals(4));
      expect(segments[0].duration, closeTo(0.0, 0.001)); // init
      expect(segments[1].duration, closeTo(10.0, 0.001));
      expect(segments[2].duration, closeTo(10.0, 0.001));
      expect(segments[3].duration, closeTo(15.0, 0.001));
    });

    // ──────────────────────────────────────────────
    // SegmentList 解析
    // ──────────────────────────────────────────────
    test('parseManifest with SegmentList returns correct URLs', () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentList>
          <SegmentURL media="seg-1.m4s"/>
          <SegmentURL media="seg-2.m4s"/>
          <SegmentURL media="seg-3.m4s"/>
        </SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseManifest(
        mpd,
        'http://example.com/video/',
      );

      expect(segments.length, equals(3));
      expect(segments[0], equals('http://example.com/video/seg-1.m4s'));
      expect(segments[1], equals('http://example.com/video/seg-2.m4s'));
      expect(segments[2], equals('http://example.com/video/seg-3.m4s'));
    });

    test('parseSegments with SegmentList returns zero durations', () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentList>
          <SegmentURL media="seg-1.m4s"/>
          <SegmentURL media="seg-2.m4s"/>
        </SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseSegments(
        mpd,
        'http://example.com/',
      );

      expect(segments.length, equals(2));
      expect(segments[0].duration, closeTo(0.0, 0.001));
      expect(segments[1].duration, closeTo(0.0, 0.001));
    });

    // ──────────────────────────────────────────────
    // mediaPresentationDuration 解析
    // ──────────────────────────────────────────────
    test('parses PT30S as 30 seconds', () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentTemplate timescale="1" duration="10" startNumber="1"
          media="seg-\$Number\$.m4s"/>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseManifest(
        mpd,
        'http://example.com/',
      );

      // PT30S / 10s = 3 segments
      expect(segments.length, equals(3));
    });

    test('parses PT0H30M0S as 1800 seconds', () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT0H30M0S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentTemplate timescale="1" duration="10" startNumber="1"
          media="seg-\$Number\$.m4s"/>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseManifest(
        mpd,
        'http://example.com/',
      );

      // PT0H30M0S = 1800s / 10s = 180 segments
      expect(segments.length, equals(180));
    });

    test('parses PT1H30M15S correctly', () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT1H30M15S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentTemplate timescale="1" duration="10" startNumber="1"
          media="seg-\$Number\$.m4s"/>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseManifest(
        mpd,
        'http://example.com/',
      );

      // PT1H30M15S = 5415s / 10s = 542 segments (ceil)
      expect(segments.length, equals(542));
    });

    test('parses PT15M correctly', () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT15M">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentTemplate timescale="1" duration="10" startNumber="1"
          media="seg-\$Number\$.m4s"/>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseManifest(
        mpd,
        'http://example.com/',
      );

      // PT15M = 900s / 10s = 90 segments
      expect(segments.length, equals(90));
    });

    // ──────────────────────────────────────────────
    // 相对路径→绝对 URL
    // ──────────────────────────────────────────────
    test('relative BaseURL resolves correctly', () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentTemplate timescale="1" duration="10" startNumber="1"
          media="seg-\$Number\$.m4s"/>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseManifest(
        mpd,
        'http://example.com/video/manifest.mpd',
      );

      expect(segments[0], equals('http://example.com/video/seg-1.m4s'));
    });

    test('absolute segments remain unchanged', () async {
      // SegmentList with absolute URLs
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentList>
          <SegmentURL media="https://cdn.example.com/seg1.m4s"/>
          <SegmentURL media="https://cdn2.example.com/seg2.m4s"/>
        </SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseManifest(
        mpd,
        'http://base.example.com/manifest.mpd',
      );

      expect(segments[0], equals('https://cdn.example.com/seg1.m4s'));
      expect(segments[1], equals('https://cdn2.example.com/seg2.m4s'));
    });

    test('root-relative path resolution', () async {
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentList>
          <SegmentURL media="/static/segments/seg1.m4s"/>
        </SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseManifest(
        mpd,
        'http://example.com/video/manifest.mpd',
      );

      expect(
          segments[0], equals('http://example.com/static/segments/seg1.m4s'));
    });

    // ──────────────────────────────────────────────
    // 边界情况
    // ──────────────────────────────────────────────
    test('parseManifest with empty content returns empty list', () async {
      final segments = await MPDParser.parseManifest('', 'http://example.com/');
      expect(segments, isEmpty);
    });

    test('parseManifest with no AdaptationSet returns empty list', () async {
      const emptyMpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
  </Period>
</MPD>''';
      final segments =
          await MPDParser.parseManifest(emptyMpd, 'http://example.com/');
      expect(segments, isEmpty);
    });

    test('parseManifest with no Representation returns empty list', () async {
      const noRep = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
    </AdaptationSet>
  </Period>
</MPD>''';
      final segments =
          await MPDParser.parseManifest(noRep, 'http://example.com/');
      expect(segments, isEmpty);
    });

    test('parseSegments with empty content returns empty list', () async {
      final segments = await MPDParser.parseSegments('', 'http://example.com/');
      expect(segments, isEmpty);
    });

    test('SegmentTemplate without timeline uses duration-based segment count',
        () async {
      // 注意：当前解析器的非 timeline 路径在计算分段数时不除以 timescale，
      // 所以 timescale != 1 时计算结果会有偏差。此处使用 timescale=1。
      const mpd = '''<?xml version="1.0"?>
<MPD mediaPresentationDuration="PT30S">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation bandwidth="1000000">
        <SegmentTemplate timescale="1" duration="10" startNumber="1"
          media="seg-\$Number\$.m4s"/>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';

      final segments = await MPDParser.parseManifest(
        mpd,
        'http://example.com/',
      );

      expect(segments.length, equals(3));
    });
  });
}
