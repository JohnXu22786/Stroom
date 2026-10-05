import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

/// Derive valid container headers from real samples while removing all media
/// data. These represent DASH initialization segments, not playable media.
Future<File> writeInitOnlyFixture(Directory directory, String fixtureName,
    {bool emptyMediaContainer = false}) async {
  final source = await File(
    p.join('tests', 'fixtures', 'catcatch', fixtureName),
  ).readAsBytes();
  final extension = p.extension(fixtureName);
  final bytes = switch (extension) {
    '.mp4' ||
    '.mov' =>
      _isoHeaderOnly(source, emptyMediaContainer: emptyMediaContainer),
    '.webm' ||
    '.mkv' =>
      _ebmlHeaderOnly(source, emptyMediaContainer: emptyMediaContainer),
    _ => throw ArgumentError.value(extension, 'extension'),
  };
  final file = File(p.join(directory.path,
      '${emptyMediaContainer ? 'empty_data' : 'init_only'}$extension'));
  await file.writeAsBytes(bytes);
  return file;
}

/// Change only the real audio fixture's declared TrackNumber; media blocks stay 1.
Future<List<int>> ebmlRenumberedTrackFixture() async {
  final source =
      await File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.webm'))
          .readAsBytes();
  final number = _find(source, [0xd7, 0x81, 1]);
  if (number < 0) throw StateError('Fixture needs TrackNumber 1');
  source[number + 2] = 2;
  return source;
}

/// Keep the real Tracks/codec headers and encoded sample while replacing only
/// Cluster framing. Valid laces repeat complete samples from that fixture.
Future<List<int>> ebmlBlockFixture(String framing,
    {bool video = false, bool blockGroup = false}) async {
  final source = await File(p.join('tests', 'fixtures', 'catcatch',
          video ? 'video_only.webm' : 'audio_only.webm'))
      .readAsBytes();
  final cluster = _find(source, [0x1f, 0x43, 0xb6, 0x75]);
  final clusterSize = _fixtureEbmlVint(source, cluster + 4);
  var offset = cluster + 4 + clusterSize.$2;
  List<int>? frame;
  while (offset < cluster + 4 + clusterSize.$2 + clusterSize.$1) {
    final size = _fixtureEbmlVint(source, offset + 1);
    final start = offset + 1 + size.$2;
    if (source[offset] == 0xa3) {
      frame = source.sublist(start + 4, start + size.$1);
      break;
    }
    offset = start + size.$1;
  }
  if (frame == null || frame.isEmpty) throw StateError('Fixture needs a frame');
  final content = switch (framing) {
    'none' => [0x81, 0, 0, 0x80, ...frame],
    'fixed' => [0x81, 0, 0, 0x84, 1, ...frame, ...frame],
    'xiph' => [0x81, 0, 0, 0x82, 1, frame.length, ...frame, ...frame],
    'ebml' => [
        0x81,
        0,
        0,
        0x86,
        2,
        0x80 | frame.length,
        0xbf,
        ...frame,
        ...frame,
        ...frame
      ],
    // Signed EBML difference -1: first sample size 7, second 6, third 7.
    'ebml_signed' => [
        0x81,
        0,
        0,
        0x86,
        2,
        0x87,
        0xbe,
        ...frame,
        8,
        7,
        0xc6,
        0xb3,
        0x0e,
        0xc6,
        ...frame
      ],
    'none_empty' => [0x81, 0, 0, 0x80],
    'xiph_empty' => [0x81, 0, 0, 2, 1, 0],
    'xiph_unterminated' => [0x81, 0, 0, 2, 1, 255],
    'xiph_overflow' => [0x81, 0, 0, 2, 1, 8, 1],
    'fixed_empty' => [0x81, 0, 0, 4, 1],
    'fixed_unequal' => [0x81, 0, 0, 4, 1, 1, 2, 3],
    'ebml_empty' => [0x81, 0, 0, 6, 1, 0x80],
    'ebml_missing_size' => [0x81, 0, 0, 6, 1],
    'ebml_negative' => [0x81, 0, 0, 6, 2, 0x81, 0xbd, 1],
    'ebml_overflow' => [0x81, 0, 0, 6, 1, 0x87, 1],
    'ebml_truncated_vint' => [0x81, 0, 0, 6, 1, 0x40],
    'unknown_track' => [0x82, 0, 0, 0x80, ...frame],
    _ => throw ArgumentError.value(framing),
  };
  final block = blockGroup
      ? _fixtureEbmlElement([0xa0], _fixtureEbmlElement([0xa1], content))
      : _fixtureEbmlElement([0xa3], content);
  final result = _ebmlHeaderOnly(source, emptyMediaContainer: false)
    ..addAll(_fixtureEbmlElement(
        [0x1f, 0x43, 0xb6, 0x75], [0xe7, 0x81, 0, ...block]));
  final segment = _find(result, [0x18, 0x53, 0x80, 0x67]);
  var size = result.length - segment - 12;
  for (var i = segment + 11; i >= segment + 5; i--) {
    result[i] = size & 0xff;
    size >>= 8;
  }
  return result;
}

(int, int) _fixtureEbmlVint(List<int> source, int offset, {bool isId = false}) {
  var marker = 0x80;
  var width = 1;
  while ((source[offset] & marker) == 0) {
    marker >>= 1;
    width++;
  }
  var value = isId ? source[offset] : source[offset] & (marker - 1);
  for (var i = 1; i < width; i++) {
    value = (value << 8) | source[offset + i];
  }
  return (value, width);
}

List<int> _fixtureEbmlElement(List<int> id, List<int> content) => [
      ...id,
      if (content.length < 127)
        0x80 | content.length
      else ...[0x40 | (content.length >> 8), content.length & 0xff],
      ...content,
    ];

/// Use real audio/video TrackEntries and encoded blocks in streaming Clusters.
Future<List<int>> ebmlStreamingFixture(
    {bool withVideo = true,
    bool tracksAfterCluster = false,
    bool emptyVideo = false,
    bool undeclaredVideo = false,
    bool lastClusterUnknown = true}) async {
  Future<List<int>> read(String name) =>
      File(p.join('tests', 'fixtures', 'catcatch', name)).readAsBytes();
  final audio = await read('audio_only.webm');
  final video = await read('video_only.webm');
  (int, int, int, int) child(List<int> bytes, int id,
          {int start = 0, int? end}) =>
      _fixtureEbmlChildren(bytes, start, end ?? bytes.length)
          .firstWhere((element) => element.$1 == id);
  List<int> element(List<int> bytes, (int, int, int, int) record) =>
      bytes.sublist(record.$2, record.$4);
  final audioSegment = child(audio, 0x18538067);
  final videoSegment = child(video, 0x18538067);
  final audioTracks =
      child(audio, 0x1654ae6b, start: audioSegment.$3, end: audioSegment.$4);
  final videoTracks =
      child(video, 0x1654ae6b, start: videoSegment.$3, end: videoSegment.$4);
  final audioEntry = element(
      audio, child(audio, 0xae, start: audioTracks.$3, end: audioTracks.$4));
  final videoEntry = element(
      video, child(video, 0xae, start: videoTracks.$3, end: videoTracks.$4));
  videoEntry[_find(videoEntry, [0xd7, 0x81, 1]) + 2] = 2;
  final tracks = _fixtureEbmlElement(
      [0x16, 0x54, 0xae, 0x6b], [...audioEntry, if (withVideo) ...videoEntry]);
  final audioCluster =
      child(audio, 0x1f43b675, start: audioSegment.$3, end: audioSegment.$4);
  final videoCluster =
      child(video, 0x1f43b675, start: videoSegment.$3, end: videoSegment.$4);
  final audioBlocks = audio.sublist(audioCluster.$3, audioCluster.$4);
  final videoBlocks = video.sublist(videoCluster.$3, videoCluster.$4);
  for (final block
      in _fixtureEbmlChildren(videoBlocks, 0, videoBlocks.length)) {
    if (block.$1 == 0xa3) videoBlocks[block.$3] = undeclaredVideo ? 0x83 : 0x82;
  }
  final second = !withVideo
      ? audioBlocks
      : emptyVideo
          ? [
              0xe7,
              0x81,
              0,
              ..._fixtureEbmlElement([0xa3], [0x82, 0, 0, 2, 1, 0])
            ]
          : videoBlocks;
  final info = element(audio,
      child(audio, 0x1549a966, start: audioSegment.$3, end: audioSegment.$4));
  const clusterId = [0x1f, 0x43, 0xb6, 0x75];
  return [
    ...audio.sublist(0, audioSegment.$2),
    0x18, 0x53, 0x80, 0x67, 1, ...List<int>.filled(7, 0xff), // Unknown Segment.
    ...info,
    if (!tracksAfterCluster) ...tracks,
    ...clusterId, 0xff, ...audioBlocks,
    // Global Void remains inside the Cluster; its payload contains sibling magic.
    ..._fixtureEbmlElement([0xec], [...clusterId, 0xff, 0xa3, 0x81, 0]),
    if (tracksAfterCluster) ...tracks,
    if (lastClusterUnknown) ...[...clusterId, 0xff, ...second] else
      ..._fixtureEbmlElement(clusterId, second),
  ];
}

Iterable<(int, int, int, int)> _fixtureEbmlChildren(
    List<int> bytes, int start, int end) sync* {
  var offset = start;
  while (offset < end) {
    final id = _fixtureEbmlVint(bytes, offset, isId: true);
    final size = _fixtureEbmlVint(bytes, offset + id.$2);
    final contentStart = offset + id.$2 + size.$2;
    final contentEnd = contentStart + size.$1;
    if (contentEnd > end) throw StateError('Invalid fixture element');
    yield (id.$1, offset, contentStart, contentEnd);
    offset = contentEnd;
  }
}

/// Concatenate complete real logical groups; Opus uses a distinct serial from
/// the Vorbis/Theora/Dirac fixtures, preserving Ogg chaining serial uniqueness.
Future<List<int>> oggChainedFixture(String next) async {
  final first =
      await File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.opus'))
          .readAsBytes();
  final second = switch (next) {
    'dirac' => await oggDiracFixture(),
    'unknown' => await oggDiracFixture(unknownVideo: true),
    'header_only' => await oggDiracFixture(omitVideoSamples: true),
    'theora' =>
      await File(p.join('tests', 'fixtures', 'catcatch', 'video_only.ogg'))
          .readAsBytes(),
    'audio' =>
      await File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.ogg'))
          .readAsBytes(),
    _ => throw ArgumentError.value(next),
  };
  return [...first, ...second];
}

/// FLV flags announce possible tracks; the header itself contains no tags.
List<int> flvHeaderOnly({required bool audio, bool withMetadata = false}) => [
      ...'FLV'.codeUnits,
      1,
      audio ? 4 : 1,
      0, 0, 0, 9, // DataOffset
      0, 0, 0, 0, // PreviousTagSize0
      if (withMetadata) ...[
        18, // Script data tag, not an audio/video sample.
        0, 0, 1, // DataSize
        0, 0, 0, 0, // Timestamp
        0, 0, 0, // StreamID
        0, // Script data payload
        0, 0, 0, 12, // PreviousTagSize
      ],
    ];

/// Preserve the original Ogg identification/comment/setup pages, omitting
/// the later page with actual encoded audio packets.
Future<File> writeHeaderOnlyOggFixture(
    Directory directory, String fixtureName) async {
  final bytes = await File(
    p.join('tests', 'fixtures', 'catcatch', fixtureName),
  ).readAsBytes();
  var offset = 0;
  for (var page = 0; page < 2; page++) {
    if (offset + 27 > bytes.length ||
        String.fromCharCodes(bytes.sublist(offset, offset + 4)) != 'OggS') {
      throw StateError('Invalid Ogg fixture');
    }
    final segmentCount = bytes[offset + 26];
    final laceEnd = offset + 27 + segmentCount;
    if (laceEnd > bytes.length) throw StateError('Invalid Ogg fixture');
    final payloadLength = bytes
        .sublist(offset + 27, laceEnd)
        .fold<int>(0, (sum, value) => sum + value);
    offset = laceEnd + payloadLength;
  }
  if (offset >= bytes.length) throw StateError('Ogg fixture has no media page');
  final file =
      File(p.join(directory.path, 'init_only${p.extension(fixtureName)}'));
  await file.writeAsBytes(bytes.sublist(0, offset));
  return file;
}

List<int> _isoHeaderOnly(List<int> source,
    {required bool emptyMediaContainer}) {
  final header = <int>[];
  var offset = 0;
  var sawMoov = false;
  var sawMdat = false;
  while (offset + 8 <= source.length) {
    final size = _uint32(source, offset);
    if (size < 8 || offset + size > source.length) {
      throw StateError('Invalid ISO fixture');
    }
    final type = String.fromCharCodes(source.sublist(offset + 4, offset + 8));
    if (type == 'ftyp' || type == 'moov') {
      header.addAll(source.sublist(offset, offset + size));
    }
    sawMoov |= type == 'moov';
    sawMdat |= type == 'mdat';
    offset += size;
  }
  if (!sawMoov || !sawMdat || offset != source.length) {
    throw StateError('ISO fixture needs moov and mdat');
  }
  if (emptyMediaContainer) header.addAll([0, 0, 0, 8, ...'mdat'.codeUnits]);
  return header;
}

List<int> _ebmlHeaderOnly(List<int> source,
    {required bool emptyMediaContainer}) {
  final segment = _find(source, const [0x18, 0x53, 0x80, 0x67]);
  final cluster = _find(source, const [0x1f, 0x43, 0xb6, 0x75]);
  // The bundled samples use an 8-byte Segment-size VINT. Keep all headers
  // and Tracks, then update that size after removing the Cluster.
  if (segment < 0 || cluster <= segment + 12 || source[segment + 4] != 1) {
    throw StateError('Unexpected EBML fixture layout');
  }
  final header = List<int>.of(source.sublist(0, cluster));
  const emptyCluster = [0x1f, 0x43, 0xb6, 0x75, 0x80];
  var contentLength =
      cluster - segment - 12 + (emptyMediaContainer ? emptyCluster.length : 0);
  for (var index = segment + 11; index >= segment + 5; index--) {
    header[index] = contentLength & 0xff;
    contentLength >>= 8;
  }
  if (contentLength != 0) throw StateError('EBML fixture is too large');
  if (emptyMediaContainer) header.addAll(emptyCluster);
  return header;
}

int _uint32(List<int> bytes, int start) =>
    (bytes[start] << 24) |
    (bytes[start + 1] << 16) |
    (bytes[start + 2] << 8) |
    bytes[start + 3];

int _find(List<int> bytes, List<int> signature) {
  for (var offset = 0; offset <= bytes.length - signature.length; offset++) {
    var match = true;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[offset + index] != signature[index]) {
        match = false;
        break;
      }
    }
    if (match) return offset;
  }
  return -1;
}

/// Keep real AVI stream headers while replacing only the movie chunks.
Future<List<int>> aviWithMovieChunks(
    String fixtureName, List<int> chunks) async {
  final source =
      await File(p.join('tests', 'fixtures', 'catcatch', fixtureName))
          .readAsBytes();
  final start = _aviMovieStart(source);
  final result = <int>[
    ...source.sublist(0, start),
    ...riffFixtureChunk('LIST', [...'movi'.codeUnits, ...chunks]),
  ];
  final size = result.length - 8;
  for (var i = 0; i < 4; i++) {
    result[4 + i] = (size >> (8 * i)) & 0xff;
  }
  return result;
}

Future<List<int>> aviFirstSampleChunk(String fixtureName) async {
  final source =
      await File(p.join('tests', 'fixtures', 'catcatch', fixtureName))
          .readAsBytes();
  final start = _aviMovieStart(source) + 12;
  final size = _littleUint32(source, start + 4);
  return source.sublist(start, start + 8 + size + (size & 1));
}

List<int> riffFixtureChunk(String type, List<int> payload) => [
      ...type.codeUnits,
      for (var i = 0; i < 4; i++) (payload.length >> (8 * i)) & 0xff,
      ...payload,
      if (payload.length.isOdd) 0,
    ];

int _aviMovieStart(List<int> source) {
  var offset = 12;
  while (offset + 12 <= source.length) {
    final size = _littleUint32(source, offset + 4);
    if (String.fromCharCodes(source.sublist(offset, offset + 4)) == 'LIST' &&
        String.fromCharCodes(source.sublist(offset + 8, offset + 12)) ==
            'movi') {
      return offset;
    }
    offset += 8 + size + (size & 1);
  }
  throw StateError('AVI fixture needs a movie list');
}

int _littleUint32(List<int> bytes, int start) =>
    bytes[start] |
    (bytes[start + 1] << 8) |
    (bytes[start + 2] << 16) |
    (bytes[start + 3] << 24);

/// Use a real pack header with explicit packets to exercise PES boundaries.
Future<List<int>> mpegProgramWithPackets(List<List<int>> packets,
    {bool mpeg2 = false}) async {
  final source = await File(p.join('tests', 'fixtures', 'catcatch',
          mpeg2 ? 'video_mpeg2_program.mpg' : 'video_program.mpg'))
      .readAsBytes();
  final size = mpeg2 ? 14 + (source[13] & 7) : 12;
  return [
    ...source.sublist(0, size),
    for (final packet in packets) ...packet,
    0,
    0,
    1,
    0xb9
  ];
}

List<int> mpegFixturePes(int streamId, List<int> data) => [
      0,
      0,
      1,
      streamId,
      data.length >> 8,
      data.length & 0xff,
      ...data,
    ];

Future<List<int>> mpegVideoSamplePacket({bool mpeg2 = false}) async {
  final source = await File(p.join('tests', 'fixtures', 'catcatch',
          mpeg2 ? 'video_mpeg2_program.mpg' : 'video_program.mpg'))
      .readAsBytes();
  for (var offset = 12; offset + 6 <= source.length; offset++) {
    if (_find(source.sublist(offset, offset + 4), [0, 0, 1, 0xe0]) == 0) {
      final size = (source[offset + 4] << 8) | source[offset + 5];
      return source.sublist(offset, offset + 6 + size);
    }
  }
  throw StateError('MPEG fixture needs a video packet');
}

/// Real elementary video, including MPEG-2 extracted from its first video PES.
Future<List<int>> mpegElementaryFixture({bool mpeg2 = false}) async {
  if (!mpeg2) {
    return File(p.join('tests', 'fixtures', 'catcatch', 'video_only.mpeg'))
        .readAsBytes();
  }
  final packet = await mpegVideoSamplePacket(mpeg2: true);
  return packet.sublist(9 + packet[8]);
}

/// Truncate the real MPEG-1 fixture at picture/slice header boundaries.
Future<List<int>> mpegElementaryHeaders(String boundary) async {
  final source = await mpegElementaryFixture();
  return switch (boundary) {
    'picture_start' => source.sublist(0, 24),
    'picture_header' => source.sublist(0, 28),
    'truncated_picture_with_slice' => [
        ...source.sublist(0, 24),
        ...source.sublist(28, 1209)
      ],
    'slice_start' => source.sublist(0, 32),
    'slice_header' => source.sublist(0, 33),
    // quantiser_scale_code=2, extra_bit_slice=1, one information byte,
    // extra_bit_slice=0, then byte padding; there is no macroblock data.
    'slice_extra_header' => [...source.sublist(0, 32), 0x14, 0],
    'terminated_slice_header' => [...source.sublist(0, 33), 0, 0, 1, 0xb7],
    _ => throw ArgumentError.value(boundary),
  };
}

/// Both HEVC layouts supported by DartFlvRemuxer, with bounded tag framing.
List<int> flvHevcFixture(
    {String? fourCc, required int packetType, bool withPayload = true}) {
  final payload = <int>[
    0x1c, // Keyframe, HEVC codecId 12.
    if (fourCc != null) ...fourCc.codeUnits,
    packetType,
    0, 0, 0, // Composition time.
    if (withPayload)
      ...packetType == 0
          ? [1, ...List<int>.filled(22, 0)] // hvcC configuration only.
          : [0, 0, 0, 3, 0x26, 1, 0x80], // Length-prefixed HEVC VCL NAL.
  ];
  return flvVideoTagFixture(payload);
}

/// Frame a video tag without assigning encoded-frame semantics to its payload.
List<int> flvVideoTagFixture(List<int> payload) {
  final previousSize = 11 + payload.length;
  return [
    ...flvHeaderOnly(audio: false),
    9, // Video tag.
    (payload.length >> 16) & 0xff, (payload.length >> 8) & 0xff,
    payload.length & 0xff,
    ...List<int>.filled(7, 0), // Timestamp and StreamID.
    ...payload,
    for (var i = 3; i >= 0; i--) (previousSize >> (8 * i)) & 0xff,
  ];
}

/// A complete mono 32-bit constant FLAC frame, including both frame checksums.
/// STREAMINFO describes sixteen samples of signed value 1 at 8000 Hz.
List<int> flac32BitFixture({int sampleSizeCode = 7}) {
  final header = <int>[
    0xff,
    0xf8,
    0x64,
    sampleSizeCode << 1,
    0,
    15,
  ];
  header.add(_fixtureCrc(header, 8, 0x07));
  final frame = <int>[
    ...header,
    0, // Constant subframe, no wasted bits.
    0, 0, 0, 1, // The signed 32-bit sample value, big endian.
  ];
  final frameCrc = _fixtureCrc(frame, 16, 0x8005);
  frame.addAll([frameCrc >> 8, frameCrc & 0xff]);
  final streamInfo = List<int>.filled(34, 0);
  streamInfo.setRange(0, 4, [0, 16, 0, 16]);
  streamInfo.setRange(4, 10, [0, 0, frame.length, 0, 0, frame.length]);
  final properties = (8000 << 44) | (31 << 36) | 16;
  for (var i = 0; i < 8; i++) {
    streamInfo[10 + i] = (properties >> ((7 - i) * 8)) & 0xff;
  }
  final pcm = [
    for (var sample = 0; sample < 16; sample++) ...[1, 0, 0, 0]
  ];
  streamInfo.setRange(18, 34, md5.convert(pcm).bytes);
  return [...'fLaC'.codeUnits, 0x80, 0, 0, 34, ...streamInfo, ...frame];
}

int _fixtureCrc(List<int> bytes, int bits, int polynomial) {
  var crc = 0;
  final highBit = 1 << (bits - 1);
  final mask = (1 << bits) - 1;
  for (final byte in bytes) {
    crc ^= byte << (bits - 8);
    for (var bit = 0; bit < 8; bit++) {
      crc = ((crc & highBit) != 0 ? (crc << 1) ^ polynomial : crc << 1) & mask;
    }
  }
  return crc;
}

/// Derive unknown/header-only streams from a checksum-valid, decoder-verified
/// Ogg fixture containing a 64x64 VC-2 frame and the existing Vorbis sample.
Future<List<int>> oggDiracFixture(
    {bool unknownVideo = false,
    bool headerOnly = false,
    bool omitVideoSamples = false}) async {
  final source = await File(
          p.join('tests', 'fixtures', 'catcatch', 'video_dirac_with_audio.ogg'))
      .readAsBytes();
  final result = <int>[];
  int? diracSerial;
  var offset = 0;
  while (offset + 27 <= source.length) {
    final segmentCount = source[offset + 26];
    final payloadStart = offset + 27 + segmentCount;
    final payloadLength = source
        .sublist(offset + 27, payloadStart)
        .fold<int>(0, (sum, value) => sum + value);
    final end = payloadStart + payloadLength;
    if (end > source.length) throw StateError('Invalid Ogg fixture');
    final serial = _littleUint32(source, offset + 14);
    final bos = (source[offset + 5] & 2) != 0;
    final diracHeader = bos &&
        payloadLength >= 4 &&
        String.fromCharCodes(source.sublist(payloadStart, payloadStart + 4)) ==
            'BBCD';
    if (diracHeader) diracSerial = serial;
    final page = List<int>.of(source.sublist(offset, end));
    if (diracHeader && unknownVideo) {
      final prefixStart = payloadStart - offset;
      page.setRange(prefixStart, prefixStart + 4, 'XXXX'.codeUnits);
      page.setRange(22, 26, [0, 0, 0, 0]);
      final crc = _fixtureCrc(page, 32, 0x04c11db7);
      for (var byte = 0; byte < 4; byte++) {
        page[22 + byte] = (crc >> (8 * byte)) & 0xff;
      }
    }
    if (diracHeader && headerOnly) return page;
    if (!omitVideoSamples || serial != diracSerial || bos) result.addAll(page);
    offset = end;
  }
  if (offset != source.length || diracSerial == null) {
    throw StateError('Invalid Ogg fixture');
  }
  return result;
}
