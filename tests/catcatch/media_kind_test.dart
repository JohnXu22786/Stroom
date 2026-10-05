import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_kind.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

import 'init_only_fixture.dart';

void main() {
  late Directory directory;
  late CatCatchTask task;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('catcatch_kind_');
    task = CatCatchTask(
      id: 'download',
      url: 'https://example.com/media',
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      selectedMedia: const MediaResource(
        url: 'https://example.com/media',
        name: 'media',
        ext: 'mp3',
        mimeType: 'audio/mpeg',
      ),
    );
  });

  tearDown(() async => directory.delete(recursive: true));

  test('HTML cannot pass as any single-kind media format', () async {
    for (final extension in [
      'mp3',
      'wav',
      'm4a',
      'aac',
      'wma',
      'opus',
      'weba',
      'flac',
      'ogv',
      'mkv',
      'avi',
      'flv',
      'wmv',
      'ev1',
      'mpeg',
      'mpg',
    ]) {
      final path = p.join(directory.path, 'media.$extension');
      await File(path).writeAsString('<!doctype html><html>Not found</html>');
      expect(
          await catCatchMediaKindFromFile(task, path), CatCatchMediaKind.other,
          reason: extension);
    }
  });

  test('missing file and wrong signature fail despite an audio MIME', () async {
    final missing = p.join(directory.path, 'missing.mp3');
    expect(await catCatchMediaKindFromFile(task, missing),
        CatCatchMediaKind.other);

    final wrong = p.join(directory.path, 'invalid.mp3');
    await File(wrong).writeAsBytes([0xff, 0xfb, 0, 0]);
    expect(
        await catCatchMediaKindFromFile(task, wrong), CatCatchMediaKind.other);

    final unknown = p.join(directory.path, 'unknown.bin');
    await File(unknown).writeAsString('not media');
    expect(await catCatchMediaKindFromFile(task, unknown),
        CatCatchMediaKind.other);

    final truncated = p.join(directory.path, 'truncated.wav');
    await File(truncated).writeAsBytes([
      ...'RIFF'.codeUnits,
      0,
      0,
      0,
      0,
      ...'WAVE'.codeUnits,
    ]);
    expect(await catCatchMediaKindFromFile(task, truncated),
        CatCatchMediaKind.other);
  });

  test('raw MP3 frames and audio in an M4A container remain audio', () async {
    final tagged =
        await File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.mp3'))
            .readAsBytes();
    final id3Size =
        (tagged[6] << 21) | (tagged[7] << 14) | (tagged[8] << 7) | tagged[9];
    final raw = p.join(directory.path, 'raw.mp3');
    await File(raw).writeAsBytes(tagged.sublist(10 + id3Size));
    expect(await catCatchMediaKindFromFile(task, raw), CatCatchMediaKind.audio);

    final m4a = p.join(directory.path, 'audio.m4a');
    await File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.mp4'))
        .copy(m4a);
    expect(await catCatchMediaKindFromFile(task, m4a), CatCatchMediaKind.audio);
  });

  test('simple audio headers without complete frames are not media', () async {
    final truncated = <String, List<int>>{
      'mp3': [0xff, 0xe3, 0x38, 0xc0, 0],
      'wav': [
        ...'RIFF'.codeUnits,
        40,
        0,
        0,
        0,
        ...'WAVEfmt '.codeUnits,
        16,
        0,
        0,
        0,
        1,
        0,
        1,
        0,
        0x40,
        0x1f,
        0,
        0,
        0x80,
        0x3e,
        0,
        0,
        2,
        0,
        16,
        0,
        ...'data'.codeUnits,
        4,
        0,
        0,
        0,
      ],
      'aac': [0xff, 0xf1, 0x6c, 0x40, 0x01, 0x1f, 0xfc, 0],
      'flac': [
        ...'fLaC'.codeUnits,
        0x80,
        0,
        0,
        34,
        ...List<int>.filled(34, 0),
      ],
    };
    for (final entry in truncated.entries) {
      final path = p.join(directory.path, 'truncated.${entry.key}');
      await File(path).writeAsBytes(entry.value);
      expect(
          await catCatchMediaKindFromFile(task, path), CatCatchMediaKind.other,
          reason: entry.key);
    }
  });

  test('actual WAV, AAC, MP3 and FLAC payloads remain audio', () async {
    for (final extension in ['wav', 'aac', 'mp3', 'flac']) {
      final path = p.join(directory.path, 'actual.$extension');
      await File(
              p.join('tests', 'fixtures', 'catcatch', 'audio_only.$extension'))
          .copy(path);
      expect(
          await catCatchMediaKindFromFile(task, path), CatCatchMediaKind.audio,
          reason: extension);
    }
  });

  test('FLAC metadata and frame header alone are not completed audio',
      () async {
    final bytes = await File(
      p.join('tests', 'fixtures', 'catcatch', 'audio_only.flac'),
    ).readAsBytes();
    var frameStart = 4;
    while (true) {
      final metadataHeader = bytes[frameStart];
      final size = (bytes[frameStart + 1] << 16) |
          (bytes[frameStart + 2] << 8) |
          bytes[frameStart + 3];
      frameStart += 4 + size;
      if ((metadataHeader & 0x80) != 0) break;
    }
    expect(bytes.sublist(frameStart, frameStart + 2), [0xff, 0xf8]);
    final path = p.join(directory.path, 'header_only.flac');
    await File(path).writeAsBytes(bytes.sublist(0, frameStart + 8));
    expect(
        await catCatchMediaKindFromFile(task, path), CatCatchMediaKind.other);
  });

  test('FLAC sample-size code 7 proves valid 32-bit audio', () async {
    final file = File(p.join(directory.path, '32_bit.flac'));
    await file.writeAsBytes(flac32BitFixture());
    expect(await catCatchVerifiedMediaFromPath(file.path),
        (kind: CatCatchMediaKind.audio, extension: '.flac'));
  });

  test('FLAC sample-size code 3 remains reserved despite valid checksums',
      () async {
    final file = File(p.join(directory.path, 'reserved.flac'));
    await file.writeAsBytes(flac32BitFixture(sampleSizeCode: 3));
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
  });

  test('32-bit FLAC still requires a valid header checksum', () async {
    final bytes = flac32BitFixture();
    bytes[48] ^=
        1; // CRC-8 after the 42-byte metadata and six-byte frame header.
    final file = File(p.join(directory.path, 'bad_crc.flac'));
    await file.writeAsBytes(bytes);
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
  });

  test('FLV video command tag does not prove encoded video', () async {
    final file = File(p.join(directory.path, 'command.flv'));
    await file.writeAsBytes(flvVideoTagFixture([0x52, 0]));
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
  });

  test('ASF stream type wins over WMA and WMV filenames and source MIME',
      () async {
    final audio = p.join(directory.path, 'audio_as_video.wmv');
    await File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.wma'))
        .copy(audio);
    expect(
        await catCatchMediaKindFromFile(task, audio), CatCatchMediaKind.audio);

    final video = p.join(directory.path, 'video_as_audio.wma');
    await File(p.join('tests', 'fixtures', 'catcatch', 'video_only.wmv'))
        .copy(video);
    expect(
        await catCatchMediaKindFromFile(task, video), CatCatchMediaKind.video);

    final mixed = p.join(directory.path, 'mixed_as_audio.wma');
    await File(p.join('tests', 'fixtures', 'catcatch', 'video_with_audio.wmv'))
        .copy(mixed);
    expect(
        await catCatchMediaKindFromFile(task, mixed), CatCatchMediaKind.video);
  });

  test('ASF header without a provable stream is not media', () async {
    final source =
        await File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.wma'))
            .readAsBytes();
    final header = source.sublist(0, 30);
    header.setRange(16, 24, [30, 0, 0, 0, 0, 0, 0, 0]);
    header.setRange(24, 28, [0, 0, 0, 0]);
    final path = p.join(directory.path, 'empty.wma');
    await File(path).writeAsBytes(header);
    expect(
        await catCatchMediaKindFromFile(task, path), CatCatchMediaKind.other);
  });

  test('ASF stream headers without Data Object packets are not media',
      () async {
    for (final fixtureName in ['audio_only.wma', 'video_only.wmv']) {
      final source = await File(
        p.join('tests', 'fixtures', 'catcatch', fixtureName),
      ).readAsBytes();
      final headerSize = source.sublist(16, 24).reversed.fold<int>(
            0,
            (size, byte) => (size << 8) | byte,
          );
      final headerOnly = p.join(directory.path, 'header_$fixtureName');
      await File(headerOnly).writeAsBytes(source.sublist(0, headerSize));
      expect(await catCatchMediaKindFromFile(task, headerOnly),
          CatCatchMediaKind.other,
          reason: fixtureName);

      final emptyData = p.join(directory.path, 'empty_data_$fixtureName');
      final bytes = source.sublist(0, headerSize + 50);
      bytes.setRange(
          headerSize + 16, headerSize + 24, [50, 0, 0, 0, 0, 0, 0, 0]);
      await File(emptyData).writeAsBytes(bytes);
      expect(await catCatchMediaKindFromFile(task, emptyData),
          CatCatchMediaKind.other,
          reason: '$fixtureName with empty Data Object');

      final partialPacket =
          p.join(directory.path, 'partial_packet_$fixtureName');
      final oneByteData = source.sublist(0, headerSize + 51);
      oneByteData.setRange(
          headerSize + 16, headerSize + 24, [51, 0, 0, 0, 0, 0, 0, 0]);
      await File(partialPacket).writeAsBytes(oneByteData);
      expect(await catCatchMediaKindFromFile(task, partialPacket),
          CatCatchMediaKind.other,
          reason: '$fixtureName with an incomplete packet');
    }
  });

  test('AVI and MPEG container tracks decide the saved media kind', () async {
    for (final (name, kind) in [
      ('audio_only.avi', CatCatchMediaKind.audio),
      ('video_only.avi', CatCatchMediaKind.video),
      ('video_with_aux.avi', CatCatchMediaKind.video),
      ('video_type1_dv.avi', CatCatchMediaKind.video),
      ('audio_only.mpg', CatCatchMediaKind.audio),
      ('video_program.mpg', CatCatchMediaKind.video),
      ('video_mpeg2_program.mpg', CatCatchMediaKind.video),
      ('video_only.mpeg', CatCatchMediaKind.video),
    ]) {
      final saved = p.join(directory.path, name);
      await File(p.join('tests', 'fixtures', 'catcatch', name)).copy(saved);
      expect(await catCatchMediaKindFromFile(task, saved), kind, reason: name);
    }
  });

  for (final boundary in [
    'picture_start',
    'picture_header',
    'truncated_picture_with_slice',
    'slice_start',
    'slice_header',
    'slice_extra_header',
    'terminated_slice_header',
  ]) {
    test('elementary MPEG $boundary has no coded picture payload', () async {
      final saved = p.join(directory.path, 'headers.mpeg');
      await File(saved).writeAsBytes(await mpegElementaryHeaders(boundary));
      expect(await catCatchMediaKindFromFile(task, saved),
          CatCatchMediaKind.other);
    });
  }

  for (final mpeg2 in [false, true]) {
    test('real elementary MPEG-${mpeg2 ? 2 : 1} slices prove video', () async {
      final saved = p.join(directory.path, 'video.mpeg');
      await File(saved).writeAsBytes(await mpegElementaryFixture(mpeg2: mpeg2));
      expect(await catCatchMediaKindFromFile(task, saved),
          CatCatchMediaKind.video);
    });
  }

  test('AVI stream labels and MPEG pack signatures alone do not prove tracks',
      () async {
    final audioAvi = await File(
      p.join('tests', 'fixtures', 'catcatch', 'audio_only.avi'),
    ).readAsBytes();
    final emptyAvi = p.join(directory.path, 'empty.avi');
    await File(emptyAvi).writeAsBytes(audioAvi.sublist(0, 12));
    expect(await catCatchMediaKindFromFile(task, emptyAvi),
        CatCatchMediaKind.other);

    final audioMpeg = await File(
      p.join('tests', 'fixtures', 'catcatch', 'audio_only.mpg'),
    ).readAsBytes();
    final packOnly = p.join(directory.path, 'pack_only.mpg');
    await File(packOnly).writeAsBytes(audioMpeg.sublist(0, 12));
    expect(await catCatchMediaKindFromFile(task, packOnly),
        CatCatchMediaKind.other);
  });

  test('AVI with only an auxiliary stream is not classified as video',
      () async {
    final bytes = await File(
      p.join('tests', 'fixtures', 'catcatch', 'video_only.avi'),
    ).readAsBytes();
    final streamHeader = latin1.decode(bytes).indexOf('vids');
    expect(streamHeader, greaterThan(0));
    bytes.setRange(streamHeader, streamHeader + 4, 'txts'.codeUnits);
    final saved = p.join(directory.path, 'aux_only.avi');
    await File(saved).writeAsBytes(bytes);
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.other);
  });

  test('zero-length MPEG-2 Program Stream PES is not accepted as video',
      () async {
    final bytes = await File(
      p.join('tests', 'fixtures', 'catcatch', 'video_mpeg2_program.mpg'),
    ).readAsBytes();
    var videoPes = -1;
    for (var i = 0; i + 6 < bytes.length; i++) {
      if (bytes[i] == 0 &&
          bytes[i + 1] == 0 &&
          bytes[i + 2] == 1 &&
          bytes[i + 3] == 0xe0) {
        videoPes = i + 3;
        break;
      }
    }
    expect(videoPes, greaterThan(3));
    expect(bytes.sublist(videoPes - 3, videoPes), [0, 0, 1]);
    bytes[videoPes + 1] = 0;
    bytes[videoPes + 2] = 0;
    final saved = p.join(directory.path, 'unbounded_program.mpg');
    await File(saved).writeAsBytes(bytes);
    // H.222.0 2.4.3.7 permits unbounded video PES only in Transport Stream.
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.other);
  });

  for (final fixture in ['audio_only.avi', 'video_only.avi']) {
    final sampleType = fixture.startsWith('audio') ? '00wb' : '00dc';
    for (final caseName in [
      'junk',
      'empty_rec',
      'empty_sample',
      'wrong_index',
      'wrong_type',
      'truncated_sample',
      'missing_pad'
    ]) {
      test('$fixture $caseName movie chunks do not prove media', () async {
        final chunks = switch (caseName) {
          'junk' => riffFixtureChunk('JUNK', [1, 2]),
          'empty_rec' => riffFixtureChunk('LIST', 'rec '.codeUnits),
          'empty_sample' => riffFixtureChunk(sampleType, []),
          'wrong_index' =>
            riffFixtureChunk('99${sampleType.substring(2)}', [1]),
          'wrong_type' =>
            riffFixtureChunk(sampleType == '00wb' ? '00dc' : '00wb', [1]),
          'truncated_sample' => [...sampleType.codeUnits, 2, 0, 0, 0, 1],
          _ => [...sampleType.codeUnits, 1, 0, 0, 0, 1],
        };
        final file = File(p.join(directory.path, 'invalid.avi'));
        await file.writeAsBytes(await aviWithMovieChunks(fixture, chunks));
        expect(await catCatchMediaKindFromPath(file.path),
            CatCatchMediaKind.other);
      });
    }
    test('$fixture samples inside nested rec lists prove the declared track',
        () async {
      final sample = await aviFirstSampleChunk(fixture);
      final nested = riffFixtureChunk('LIST', [
        ...'rec '.codeUnits,
        ...riffFixtureChunk('LIST', [...'rec '.codeUnits, ...sample])
      ]);
      final file = File(p.join(directory.path, 'nested.avi'));
      await file.writeAsBytes(await aviWithMovieChunks(fixture, nested));
      expect(
          await catCatchMediaKindFromPath(file.path),
          fixture.startsWith('audio')
              ? CatCatchMediaKind.audio
              : CatCatchMediaKind.video);
    });
  }

  for (final header in [
    [0x0f], // MPEG-1 no-timestamp header, with no elementary payload.
    [0x21, 0, 1, 0, 1], // MPEG-1 PTS header only.
    [0x80, 0, 0], // MPEG-2 fixed PES header only.
    [0x80, 0, 4, 0], // Header data extends beyond the declared packet.
  ]) {
    test('MPEG PES header ${header.length} bytes alone is not media', () async {
      final file = File(p.join(directory.path, 'header_only.mpg'));
      await file.writeAsBytes(await mpegProgramWithPackets([
        mpegFixturePes(0xe0, header),
      ], mpeg2: header.first == 0x80));
      expect(
          await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
    });
  }

  for (final privateFirst in [false, true]) {
    test(
        'MPEG video with private AC3 packet keeps proven video ($privateFirst)',
        () async {
      final video = await mpegVideoSamplePacket(mpeg2: true);
      final ac3 =
          mpegFixturePes(0xbd, [0x80, 0, 0, 0x80, 1, 0, 0, 0x0b, 0x77, 1]);
      final file = File(p.join(directory.path, 'private_audio.mpg'));
      await file.writeAsBytes(await mpegProgramWithPackets(
          privateFirst ? [ac3, video] : [video, ac3],
          mpeg2: true));
      expect(
          await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.video);
    });
  }

  for (final boundary in [
    'picture_header',
    'slice_start',
    'slice_header',
    'slice_extra_header'
  ]) {
    test('video PES with only $boundary does not prove a coded picture',
        () async {
      final saved = p.join(directory.path, 'headers.mpg');
      await File(saved).writeAsBytes(await mpegProgramWithPackets([
        mpegFixturePes(0xe0, [0x0f, ...await mpegElementaryHeaders(boundary)]),
      ]));
      expect(await catCatchMediaKindFromFile(task, saved),
          CatCatchMediaKind.other);
    });
  }

  for (final mpeg2 in [false, true]) {
    for (final cut in [24, 30, 33]) {
      test('MPEG-${mpeg2 ? 2 : 1} picture framing spans video PES at $cut',
          () async {
        final sample = await mpegElementaryFixture(mpeg2: mpeg2);
        final pesHeader = mpeg2 ? [0x80, 0, 0] : [0x0f];
        final saved = p.join(directory.path, 'split.mpg');
        await File(saved).writeAsBytes(await mpegProgramWithPackets([
          mpegFixturePes(0xe0, [...pesHeader, ...sample.sublist(0, cut)]),
          mpegFixturePes(0xbf, [0, 0, 0, 0]),
          mpegFixturePes(0xe0, [...pesHeader, ...sample.sublist(cut)]),
        ], mpeg2: mpeg2));
        expect(await catCatchMediaKindFromFile(task, saved),
            CatCatchMediaKind.video);
      });
    }
  }

  test('MPEG picture headers from different PES stream IDs cannot be joined',
      () async {
    final sample = await mpegElementaryFixture();
    final saved = p.join(directory.path, 'separate.mpg');
    await File(saved).writeAsBytes(await mpegProgramWithPackets([
      mpegFixturePes(0xe0, [0x0f, ...sample.sublist(0, 33)]),
      mpegFixturePes(0xe1, [0x0f, ...sample.sublist(33, 1209)]),
    ]));
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.other);
  });

  test('MPEG private packets alone remain an ambiguous media kind', () async {
    final file = File(p.join(directory.path, 'private_only.mpg'));
    await file.writeAsBytes(await mpegProgramWithPackets([
      mpegFixturePes(0xbd, [0x80, 0, 0, 0x80, 1, 0, 0, 0x0b, 0x77, 1]),
    ], mpeg2: true));
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
  });

  test('malformed private PES cannot be skipped beside valid MPEG video',
      () async {
    final file = File(p.join(directory.path, 'truncated_private.mpg'));
    await file.writeAsBytes(await mpegProgramWithPackets([
      await mpegVideoSamplePacket(mpeg2: true),
      mpegFixturePes(0xbd, [0x80, 0, 4, 0]),
    ], mpeg2: true));
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
  });

  for (final navigationFirst in [false, true]) {
    test('MPEG DVD navigation packet preserves proven video ($navigationFirst)',
        () async {
      final video = await mpegVideoSamplePacket(mpeg2: true);
      final navigation = mpegFixturePes(0xbf, List<int>.filled(980, 0));
      final file = File(p.join(directory.path, 'dvd_navigation.mpg'));
      await file.writeAsBytes(await mpegProgramWithPackets(
          navigationFirst ? [navigation, video] : [video, navigation],
          mpeg2: true));
      expect(
          await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.video);
    });
  }

  test('MPEG DVD navigation packets alone do not prove media', () async {
    final file = File(p.join(directory.path, 'navigation_only.mpg'));
    await file.writeAsBytes(await mpegProgramWithPackets([
      mpegFixturePes(0xbf, List<int>.filled(980, 0)),
    ], mpeg2: true));
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
  });

  test('MPEG truncated DVD navigation is rejected beside proven video',
      () async {
    final file = File(p.join(directory.path, 'truncated_navigation.mpg'));
    await file.writeAsBytes(await mpegProgramWithPackets([
      await mpegVideoSamplePacket(mpeg2: true),
      [0, 0, 1, 0xbf, 0, 20, ...List<int>.filled(8, 0)],
    ], mpeg2: true));
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
  });

  for (final fourCc in [null, 'hvc1', 'hev1']) {
    final layout = fourCc ?? 'legacy';
    for (final sample in [
      (
        name: 'configuration-only',
        packetType: 0,
        withPayload: true,
        kind: CatCatchMediaKind.other
      ),
      (
        name: 'end-of-sequence',
        packetType: 2,
        withPayload: true,
        kind: CatCatchMediaKind.other
      ),
      (
        name: 'empty coded packet',
        packetType: 1,
        withPayload: false,
        kind: CatCatchMediaKind.other
      ),
      (
        name: 'coded frame',
        packetType: 1,
        withPayload: true,
        kind: CatCatchMediaKind.video
      ),
    ]) {
      test('HEVC $layout ${sample.name} has only its actual payload kind',
          () async {
        final file = File(p.join(directory.path, 'hevc.flv'));
        await file.writeAsBytes(flvHevcFixture(
            fourCc: fourCc,
            packetType: sample.packetType,
            withPayload: sample.withPayload));
        expect(await catCatchMediaKindFromPath(file.path), sample.kind);
      });
    }
  }

  test('Ogg Dirac picture with Vorbis audio keeps proven video priority',
      () async {
    final file = File(p.join(directory.path, 'dirac_audio.ogg'));
    await file.writeAsBytes(await oggDiracFixture());
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.video);
  });

  test('Ogg unidentified logical stream prevents a mixed audio classification',
      () async {
    final file = File(p.join(directory.path, 'unknown_audio.ogg'));
    await file.writeAsBytes(await oggDiracFixture(unknownVideo: true));
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
  });

  test('Ogg Dirac sequence header alone does not prove a video frame',
      () async {
    final file = File(p.join(directory.path, 'dirac_header.ogg'));
    await file.writeAsBytes(await oggDiracFixture(headerOnly: true));
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
  });

  test('Ogg Dirac headers mixed with audio do not imply an audio-only file',
      () async {
    final file = File(p.join(directory.path, 'dirac_no_frames.ogg'));
    await file.writeAsBytes(await oggDiracFixture(omitVideoSamples: true));
    expect(await catCatchMediaKindFromPath(file.path), CatCatchMediaKind.other);
  });

  for (final codec in ['ogg', 'opus']) {
    test('normal Ogg $codec audio remains verified audio', () async {
      expect(
          await catCatchMediaKindFromPath(
              'tests/fixtures/catcatch/audio_only.$codec'),
          CatCatchMediaKind.audio);
    });
  }

  for (final lateTracks in [false, true]) {
    for (final video in [false, true]) {
      test(
          'streaming EBML later ${video ? 'video' : 'audio'} Cluster with Tracks ${lateTracks ? 'after' : 'before'}',
          () async {
        final saved = p.join(directory.path, 'streaming.webm');
        await File(saved).writeAsBytes(await ebmlStreamingFixture(
            withVideo: video, tracksAfterCluster: lateTracks));
        expect(await catCatchMediaKindFromFile(task, saved),
            video ? CatCatchMediaKind.video : CatCatchMediaKind.audio);
      });
    }
  }

  test('streaming EBML also ends before a sized video Cluster', () async {
    final saved = p.join(directory.path, 'streaming.webm');
    await File(saved)
        .writeAsBytes(await ebmlStreamingFixture(lastClusterUnknown: false));
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.video);
  });

  for (final invalid in ['unmatched', 'empty_lace']) {
    test('streaming EBML later $invalid video block cannot override real audio',
        () async {
      final saved = p.join(directory.path, 'streaming.webm');
      await File(saved).writeAsBytes(await ebmlStreamingFixture(
          undeclaredVideo: invalid == 'unmatched',
          emptyVideo: invalid == 'empty_lace'));
      expect(await catCatchMediaKindFromFile(task, saved),
          CatCatchMediaKind.audio);
    });
  }

  for (final group in ['theora', 'dirac', 'audio', 'unknown', 'header_only']) {
    test('chained Ogg audio followed by $group uses all groups', () async {
      final saved = p.join(directory.path, 'chained.ogg');
      await File(saved).writeAsBytes(await oggChainedFixture(group));
      final kind = switch (group) {
        'theora' || 'dirac' => CatCatchMediaKind.video,
        'audio' => CatCatchMediaKind.audio,
        _ => CatCatchMediaKind.other,
      };
      expect(await catCatchMediaKindFromFile(task, saved), kind);
    });
  }

  test('EBML blocks must match the real declared track number', () async {
    final saved = p.join(directory.path, 'renumbered.webm');
    await File(saved).writeAsBytes(await ebmlRenumberedTrackFixture());
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.other);
  });

  for (final framing in [
    'none_empty',
    'xiph_empty',
    'xiph_unterminated',
    'xiph_overflow',
    'fixed_empty',
    'fixed_unequal',
    'ebml_empty',
    'ebml_missing_size',
    'ebml_negative',
    'ebml_overflow',
    'ebml_truncated_vint',
    'unknown_track',
  ]) {
    test('EBML $framing cannot prove an audio sample', () async {
      final saved = p.join(directory.path, 'invalid.webm');
      await File(saved).writeAsBytes(await ebmlBlockFixture(framing));
      expect(await catCatchMediaKindFromFile(task, saved),
          CatCatchMediaKind.other);
    });
  }

  for (final framing in ['none', 'fixed', 'xiph', 'ebml']) {
    for (final video in [false, true]) {
      test('EBML $framing retains a real ${video ? 'video' : 'audio'} sample',
          () async {
        final saved = p.join(directory.path, 'valid.webm');
        await File(saved)
            .writeAsBytes(await ebmlBlockFixture(framing, video: video));
        expect(await catCatchMediaKindFromFile(task, saved),
            video ? CatCatchMediaKind.video : CatCatchMediaKind.audio);
      });
    }
  }

  test('EBML signed lace sizes and BlockGroup preserve real audio', () async {
    final saved = p.join(directory.path, 'group.webm');
    await File(saved)
        .writeAsBytes(await ebmlBlockFixture('ebml_signed', blockGroup: true));
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.audio);
  });

  test('EBML tracks with an unknown document type are not WebM media',
      () async {
    final bytes =
        await File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.webm'))
            .readAsBytes();
    final offset = latin1.decode(bytes).indexOf('webm');
    expect(offset, greaterThan(0));
    bytes.setRange(offset, offset + 4, 'xxxx'.codeUnits);
    final path = p.join(directory.path, 'unknown.weba');
    await File(path).writeAsBytes(bytes);
    expect(
        await catCatchMediaKindFromFile(task, path), CatCatchMediaKind.other);
  });

  for (final audio in [true, false]) {
    for (final withMetadata in [false, true]) {
      test(
          '${audio ? 'audio' : 'video'} FLV ${withMetadata ? 'metadata-only' : 'header-only'} is not media',
          () async {
        final file = File(p.join(directory.path, 'header.flv'));
        await file.writeAsBytes(
            flvHeaderOnly(audio: audio, withMetadata: withMetadata));
        expect(await catCatchVerifiedMediaFromPath(file.path), isNull);
      });
    }
  }

  for (final fixtureName in ['audio_only.ogg', 'audio_only.opus']) {
    test('$fixtureName codec headers without packets are not media', () async {
      final file = await writeHeaderOnlyOggFixture(directory, fixtureName);
      expect(await catCatchVerifiedMediaFromPath(file.path), isNull);
    });
  }

  for (final fixtureName in [
    'audio_only.mp4',
    'video_only.mov',
    'audio_only.webm',
    'video_only.mkv',
  ]) {
    for (final emptyMediaContainer in [false, true]) {
      test(
          '$fixtureName ${emptyMediaContainer ? 'empty media box' : 'initialization segment'} is not completed media',
          () async {
        final file = await writeInitOnlyFixture(directory, fixtureName,
            emptyMediaContainer: emptyMediaContainer);
        expect(await catCatchMediaKindFromPath(file.path),
            CatCatchMediaKind.other);
      });
    }
  }
}
