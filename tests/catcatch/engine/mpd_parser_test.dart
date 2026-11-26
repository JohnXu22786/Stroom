import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/mpd_parser.dart';

void main() {
  test(
    'parses DASH representations as separate segment alternatives',
    () async {
      const manifest = r'''
<MPD mediaPresentationDuration="PT4S">
  <Period duration="PT2S"><BaseURL>period-1/</BaseURL>
    <AdaptationSet id="video" contentType="video" mimeType="video/mp4" codecs="avc1.4d401f">
      <SegmentTemplate media="$RepresentationID$/segment-$Number$.m4s" duration="1"/>
      <Representation id="low" bandwidth="400000" width="640" height="360"/>
      <Representation id="high" bandwidth="1200000" width="1280" height="720"/>
    </AdaptationSet>
    <AdaptationSet id="audio" contentType="audio" mimeType="audio/mp4" codecs="mp4a.40.2">
      <SegmentTemplate media="$RepresentationID$/segment-$Number$.m4s" duration="1"/>
      <Representation id="audio" bandwidth="128000"/>
    </AdaptationSet>
  </Period>
  <Period duration="PT2S"><BaseURL>period-2/</BaseURL>
    <AdaptationSet id="audio" contentType="audio" mimeType="audio/mp4" codecs="mp4a.40.2">
      <SegmentTemplate media="$RepresentationID$/segment-$Number$.m4s" duration="1"/>
      <Representation id="audio" bandwidth="128000"/>
    </AdaptationSet>
    <AdaptationSet id="video" contentType="video" mimeType="video/mp4" codecs="avc1.4d401f">
      <SegmentTemplate media="$RepresentationID$/segment-$Number$.m4s" duration="1"/>
      <Representation id="low" bandwidth="400000" width="640" height="360"/>
      <Representation id="high" bandwidth="1200000" width="1280" height="720"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

      final representations = await MPDParser.parseRepresentations(
        manifest,
        'https://example.com/manifest.mpd',
      );

      expect(representations, hasLength(3));
      expect(representations[0].id, 'low');
      expect(representations[0].bandwidth, 400000);
      expect(representations[0].width, 640);
      expect(representations[0].height, 360);
      expect(representations[0].mimeType, 'video/mp4');
      expect(representations[0].codecs, 'avc1.4d401f');
      expect(representations[0].segments.map((segment) => segment.url), [
        'https://example.com/period-1/low/segment-1.m4s',
        'https://example.com/period-1/low/segment-2.m4s',
        'https://example.com/period-2/low/segment-1.m4s',
        'https://example.com/period-2/low/segment-2.m4s',
      ]);
      expect(representations[1].id, 'high');
      expect(representations[1].bandwidth, 1200000);
      expect(representations[1].width, 1280);
      expect(representations[1].height, 720);
      expect(representations[1].segments.map((segment) => segment.url), [
        'https://example.com/period-1/high/segment-1.m4s',
        'https://example.com/period-1/high/segment-2.m4s',
        'https://example.com/period-2/high/segment-1.m4s',
        'https://example.com/period-2/high/segment-2.m4s',
      ]);
      expect(representations[2].id, 'audio');
      expect(representations[2].segments.map((segment) => segment.url), [
        'https://example.com/period-1/audio/segment-1.m4s',
        'https://example.com/period-1/audio/segment-2.m4s',
        'https://example.com/period-2/audio/segment-1.m4s',
        'https://example.com/period-2/audio/segment-2.m4s',
      ]);

      const singleRepresentation = '''
<MPD><Period><AdaptationSet>
  <SegmentList><SegmentURL media="only.m4s"/></SegmentList>
  <Representation id="only"/>
</AdaptationSet></Period></MPD>
''';
      final single = await MPDParser.parseRepresentations(
        singleRepresentation,
        'https://example.com/manifest.mpd',
      );
      expect(single, hasLength(1));
      expect(single.single.segments.map((segment) => segment.url), [
        'https://example.com/only.m4s',
      ]);

      const noIdAlternatives = r'''
<MPD><Period><AdaptationSet mimeType="video/mp4">
  <SegmentTemplate media="segment-$Number$.m4s" duration="1"/>
  <Representation><BaseURL>first/</BaseURL></Representation>
  <Representation><BaseURL>second/</BaseURL></Representation>
</AdaptationSet></Period></MPD>
''';
      final noId = await MPDParser.parseRepresentations(
        noIdAlternatives,
        'https://example.com/manifest.mpd',
      );
      expect(noId, hasLength(2));
      expect(
        noId[0].segments.single.url,
        'https://example.com/first/segment-1.m4s',
      );
      expect(
        noId[1].segments.single.url,
        'https://example.com/second/segment-1.m4s',
      );
    },
  );

  test('puts SegmentList Initialization before media segments', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <Representation id="v1">
        <SegmentList>
          <Initialization sourceURL="init.mp4"/>
          <SegmentURL media="segment-1.m4s"/>
          <SegmentURL media="segment-2.m4s"/>
        </SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/video/manifest.mpd',
    );

    expect(segments, [
      'https://example.com/video/init.mp4',
      'https://example.com/video/segment-1.m4s',
      'https://example.com/video/segment-2.m4s',
    ]);
  });

  test(
    'resolves SegmentList Initialization against the effective BaseURL',
    () async {
      const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <Representation id="v1">
        <BaseURL>video/</BaseURL>
        <SegmentList>
          <Initialization sourceURL="init/init.mp4"/>
          <SegmentURL media="segment.m4s"/>
        </SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

      final segments = await MPDParser.parseManifest(
        manifest,
        'https://example.com/manifest.mpd',
      );

      expect(segments, [
        'https://example.com/video/init/init.mp4',
        'https://example.com/video/segment.m4s',
      ]);
    },
  );

  test(
    'keeps SegmentList media sequence when Initialization is absent',
    () async {
      const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <Representation id="v1">
        <SegmentList>
          <SegmentURL media="segment-1.m4s"/>
          <SegmentURL media="segment-2.m4s"/>
        </SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

      final segments = await MPDParser.parseManifest(
        manifest,
        'https://example.com/video/manifest.mpd',
      );

      expect(segments, [
        'https://example.com/video/segment-1.m4s',
        'https://example.com/video/segment-2.m4s',
      ]);
    },
  );

  test('inherits an AdaptationSet SegmentList', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentList>
        <Initialization sourceURL="init.mp4"/>
        <SegmentURL media="segment-1.m4s"/>
      </SegmentList>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/video/manifest.mpd',
    );

    expect(segments, [
      'https://example.com/video/init.mp4',
      'https://example.com/video/segment-1.m4s',
    ]);
  });

  test('inherits a Period SegmentList', () async {
    const manifest = r'''
<MPD>
  <Period>
    <SegmentList>
      <SegmentURL media="segment-1.m4s"/>
      <SegmentURL media="segment-2.m4s"/>
    </SegmentList>
    <AdaptationSet>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/video/manifest.mpd',
    );

    expect(segments, [
      'https://example.com/video/segment-1.m4s',
      'https://example.com/video/segment-2.m4s',
    ]);
  });

  test('prefers a Representation SegmentList over inherited SegmentLists',
      () async {
    const manifest = r'''
<MPD>
  <Period>
    <SegmentList><SegmentURL media="period.m4s"/></SegmentList>
    <AdaptationSet>
      <SegmentList><SegmentURL media="adaptation.m4s"/></SegmentList>
      <Representation id="v1">
        <SegmentList><SegmentURL media="representation.m4s"/></SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/video/manifest.mpd',
    );

    expect(segments, ['https://example.com/video/representation.m4s']);
  });

  test('prefers a more-specific SegmentTemplate over a Period SegmentList',
      () async {
    const manifest = r'''
<MPD mediaPresentationDuration="PT2S">
  <Period>
    <SegmentList><SegmentURL media="period.m4s"/></SegmentList>
    <AdaptationSet>
      <SegmentTemplate media="adaptation-$Number$.m4s" duration="1"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/video/manifest.mpd',
    );

    expect(segments, [
      'https://example.com/video/adaptation-1.m4s',
      'https://example.com/video/adaptation-2.m4s',
    ]);
  });

  test('inherits an AdaptationSet SegmentTemplate and timeline', () async {
    const manifest = r'''
<MPD mediaPresentationDuration="PT4S">
  <Period>
    <AdaptationSet>
      <SegmentTemplate timescale="1" media="chunk-$Number$.m4s" initialization="init.mp4" startNumber="7">
        <SegmentTimeline><S t="0" d="2" r="1"/></SegmentTimeline>
      </SegmentTemplate>
      <Representation id="video-a"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, [
      'https://example.com/init.mp4',
      'https://example.com/chunk-7.m4s',
      'https://example.com/chunk-8.m4s',
    ]);
  });

  test('resolves BaseURL at each MPD hierarchy level', () async {
    const manifest = r'''
<MPD>
  <BaseURL>root/</BaseURL>
  <Period>
    <BaseURL>period/</BaseURL>
    <AdaptationSet>
      <BaseURL>video/</BaseURL>
      <SegmentTemplate media="segment-$Number$.m4s" duration="4"/>
      <Representation id="v1">
        <BaseURL>high/</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, [
      'https://example.com/root/period/video/high/segment-1.m4s',
    ]);
  });

  test(
    'replaces the complete formatted Number token with zero padding',
    () async {
      const manifest = r'''
<MPD mediaPresentationDuration="PT1S">
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number%05d$.m4s" duration="1"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

      final segments = await MPDParser.parseManifest(
        manifest,
        'https://example.com/manifest.mpd',
      );

      expect(segments, ['https://example.com/segment-00001.m4s']);
    },
  );

  test('uses the id of each Representation in template URLs', () async {
    const manifest = r'''
<MPD mediaPresentationDuration="PT1S">
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="$RepresentationID$/segment-$Number$.m4s" duration="1"/>
      <Representation id="video-low"/>
      <Representation id="video-high"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, [
      'https://example.com/video-low/segment-1.m4s',
      'https://example.com/video-high/segment-1.m4s',
    ]);
  });

  test('does not allocate unbounded padding from a Number token', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number%09223372036854775807d$.m4s" duration="1"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments.single.length, lessThan(100));
  });

  test('supports valid Number padding wider than twenty digits', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number%021d$.m4s" duration="1"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, ['https://example.com/segment-000000000000000000001.m4s']);
  });

  test('does not add a segment at an exact fixed-duration boundary', () async {
    const manifest = r'''
<MPD mediaPresentationDuration="PT1.12S">
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number$.m4s" timescale="100" duration="7"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, hasLength(16));
  });

  test('prefers an explicit SegmentList over an inherited template', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="inherited-$Number$.m4s" duration="4"/>
      <Representation id="v1">
        <SegmentList><SegmentURL media="explicit.m4s"/></SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, ['https://example.com/explicit.m4s']);
  });

  test('counts fixed-duration segments in timescale units', () async {
    const manifest = r'''
<MPD mediaPresentationDuration="PT4S">
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number$.m4s" timescale="1000" duration="2000"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, [
      'https://example.com/segment-1.m4s',
      'https://example.com/segment-2.m4s',
    ]);
  });

  test(
    'advances timeline time through repeats and entries without t',
    () async {
      const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Time$.m4s" timescale="1">
        <SegmentTimeline>
          <S t="3" d="2" r="1"/>
          <S d="4"/>
        </SegmentTimeline>
      </SegmentTemplate>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

      final segments = await MPDParser.parseManifest(
        manifest,
        'https://example.com/manifest.mpd',
      );

      expect(segments, [
        'https://example.com/segment-3.m4s',
        'https://example.com/segment-5.m4s',
        'https://example.com/segment-7.m4s',
      ]);
    },
  );

  test(
    'does not reprocess template tokens inside a Representation id',
    () async {
      const manifest = r'''
<MPD mediaPresentationDuration="PT1S">
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="$RepresentationID$/segment-$Number$.m4s" duration="1"/>
      <Representation id="video-$Number$"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

      final segments = await MPDParser.parseManifest(
        manifest,
        'https://example.com/manifest.mpd',
      );

      expect(segments, ['https://example.com/video-\$Number\$/segment-1.m4s']);
    },
  );

  test('keeps a later nonempty BaseURL when an earlier one is blank', () async {
    const manifest = r'''
<MPD>
  <BaseURL>   </BaseURL>
  <BaseURL>root/</BaseURL>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number$.m4s" duration="4"/>
      <Representation id="v1">
        <BaseURL>  </BaseURL>
        <BaseURL>high/</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, ['https://example.com/root/high/segment-1.m4s']);
  });

  test(
    'uses the current Period duration for fixed-duration templates',
    () async {
      const manifest = r'''
<MPD mediaPresentationDuration="PT4S">
  <SegmentTemplate media="segment-$Number$.m4s" duration="1"/>
  <Period duration="PT1S"><BaseURL>first/</BaseURL><Representation id="v1"/></Period>
  <Period><BaseURL>second/</BaseURL><Representation id="v1"/></Period>
</MPD>
''';

      final segments = await MPDParser.parseManifest(
        manifest,
        'https://example.com/manifest.mpd',
      );

      expect(segments, [
        'https://example.com/first/segment-1.m4s',
        'https://example.com/second/segment-1.m4s',
        'https://example.com/second/segment-2.m4s',
        'https://example.com/second/segment-3.m4s',
      ]);
    },
  );

  test(
    'fails explicitly when fixed-duration output exceeds the limit',
    () async {
      const manifest = r'''
<MPD mediaPresentationDuration="PT1S">
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number$.m4s" timescale="1000000000" duration="1"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

      await expectLater(
        MPDParser.parseManifest(manifest, 'https://example.com/manifest.mpd'),
        throwsFormatException,
      );
    },
  );

  test(
    'returns complete fixed-duration output for a twelve-hour VOD',
    () async {
      const manifest = r'''
<MPD mediaPresentationDuration="PT43200S">
  <Period>
    <AdaptationSet>
      <Representation id="v1"><SegmentTemplate media="v1-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v2"><SegmentTemplate media="v2-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v3"><SegmentTemplate media="v3-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v4"><SegmentTemplate media="v4-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v5"><SegmentTemplate media="v5-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v6"><SegmentTemplate media="v6-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v7"><SegmentTemplate media="v7-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v8"><SegmentTemplate media="v8-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v9"><SegmentTemplate media="v9-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v10"><SegmentTemplate media="v10-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v11"><SegmentTemplate media="v11-$Number$.m4s" duration="2"/></Representation>
      <Representation id="v12"><SegmentTemplate media="v12-$Number$.m4s" duration="2"/></Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

      final segments = await MPDParser.parseManifest(
        manifest,
        'https://example.com/manifest.mpd',
        maxSegments: MPDParser.defaultMaxSegments,
      );

      expect(segments, hasLength(259200));
    },
  );

  test('uses a caller-selected segment limit', () async {
    const manifest = r'''
<MPD mediaPresentationDuration="PT2S">
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number$.m4s" duration="1"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    await expectLater(
      MPDParser.parseManifest(
        manifest,
        'https://example.com/manifest.mpd',
        maxSegments: 1,
      ),
      throwsFormatException,
    );
  });

  test(
    'keeps fractional Period start when calculating segment count',
    () async {
      const manifest = r'''
<MPD mediaPresentationDuration="PT2S">
  <Period start="PT0.5S">
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number$.m4s" duration="1"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

      final segments = await MPDParser.parseManifest(
        manifest,
        'https://example.com/manifest.mpd',
      );

      expect(segments, [
        'https://example.com/segment-1.m4s',
        'https://example.com/segment-2.m4s',
      ]);
    },
  );

  test('keeps source precision in fixed-duration count calculation', () async {
    const manifest = r'''
<MPD mediaPresentationDuration="PT2.0000555S">
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number$.m4s" timescale="90000" duration="180005"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, hasLength(1));
  });

  test('expands templates when the base URL has a long query', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number$.m4s" duration="4"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';
    final query = List.filled(3000, 'x').join();

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/path/manifest.mpd?signature=$query',
    );

    expect(segments, ['https://example.com/path/segment-1.m4s']);
  });

  test('parses quoted greater-than characters in XML attributes', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <Representation id="v1">
        <Role schemeIdUri="urn:example:role" value="a>b"/>
        <SegmentList><SegmentURL media="segment.m4s"/></SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, ['https://example.com/segment.m4s']);
  });

  test('preserves encoded characters in relative SegmentURL paths', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <Representation id="v1">
        <SegmentList><SegmentURL media="signed/%7Epart.m4s"/></SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, ['https://example.com/signed/%7Epart.m4s']);
  });

  test(
    'normalizes percent-encoded hostnames without corrupting them',
    () async {
      const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <Representation id="v1">
        <SegmentList><SegmentURL media="segment.m4s"/></SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

      final segments = await MPDParser.parseManifest(
        manifest,
        'https://exa%6Dple.com/manifest.mpd',
      );

      expect(segments, ['https://example.com/segment.m4s']);
    },
  );

  test('preserves absolute template URLs without URI normalization', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="https://cdn.example/a%7E/segment-$Number$.m4s" duration="4"/>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, ['https://cdn.example/a%7E/segment-1.m4s']);
  });

  test('parses a prefixed MPD with DASH namespace declarations', () async {
    const manifest = r'''
<dash:MPD xmlns:dash="urn:mpeg:dash:schema:mpd:2011" xmlns="urn:mpeg:dash:schema:mpd:2011">
  <Period>
    <AdaptationSet>
      <Representation id="v1">
        <SegmentList><SegmentURL media="segment.m4s"/></SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</dash:MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, ['https://example.com/segment.m4s']);
  });

  test('preserves CDATA and decodes numeric XML references', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="$RepresentationID$/segment-$Number$.m4s" duration="4"/>
      <Representation id="video&#49;"><BaseURL><![CDATA[high/]]></BaseURL></Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, ['https://example.com/high/video1/segment-1.m4s']);
  });

  test('decodes each XML character reference only once', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="$RepresentationID$/segment-$Number$.m4s" duration="4"/>
      <Representation id="video&#38;amp;"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, ['https://example.com/video&amp;/segment-1.m4s']);
  });

  test('bounds expanded inherited SegmentTimeline repetitions', () async {
    const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Number$.m4s">
        <SegmentTimeline><S t="0" d="1" r="1000000000"/></SegmentTimeline>
      </SegmentTemplate>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    await expectLater(
      MPDParser.parseManifest(manifest, 'https://example.com/manifest.mpd'),
      throwsFormatException,
    );
  });

  test(
    'expands negative timeline repeats to the next explicit start',
    () async {
      const manifest = r'''
<MPD>
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Time$.m4s" timescale="1">
        <SegmentTimeline>
          <S t="0" d="2" r="-1"/>
          <S t="6" d="2"/>
        </SegmentTimeline>
      </SegmentTemplate>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

      final segments = await MPDParser.parseManifest(
        manifest,
        'https://example.com/manifest.mpd',
      );

      expect(segments, [
        'https://example.com/segment-0.m4s',
        'https://example.com/segment-2.m4s',
        'https://example.com/segment-4.m4s',
        'https://example.com/segment-6.m4s',
      ]);
    },
  );

  test('expands final negative timeline repeats to the Period end', () async {
    const manifest = r'''
<MPD mediaPresentationDuration="PT6S">
  <Period>
    <AdaptationSet>
      <SegmentTemplate media="segment-$Time$.m4s" timescale="1">
        <SegmentTimeline><S t="0" d="2" r="-1"/></SegmentTimeline>
      </SegmentTemplate>
      <Representation id="v1"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

    final segments = await MPDParser.parseManifest(
      manifest,
      'https://example.com/manifest.mpd',
    );

    expect(segments, [
      'https://example.com/segment-0.m4s',
      'https://example.com/segment-2.m4s',
      'https://example.com/segment-4.m4s',
    ]);
  });
}
