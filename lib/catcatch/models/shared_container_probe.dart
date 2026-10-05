import 'dart:io';

enum ProbedTrackKind { audio, video, unknown }

enum EbmlDocumentType { webm, matroska, unknown }

/// `.opus` is reserved for Ogg Opus. Other Ogg audio codecs use `.ogg`.
Future<bool> hasOggOpusHead(String path) async {
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final length = await reader.length();
    var offset = 0;
    while (length - offset >= 27) {
      await reader.setPosition(offset);
      final header = await reader.read(27);
      if (header.length != 27 ||
          String.fromCharCodes(header.take(4)) != 'OggS' ||
          header[4] != 0) {
        return false;
      }
      final lacing = await reader.read(header[26]);
      if (lacing.length != header[26]) return false;
      final payloadLength = lacing.fold<int>(0, (sum, value) => sum + value);
      final payloadStart = offset + 27 + lacing.length;
      if (payloadStart + payloadLength > length || (header[5] & 0x02) == 0) {
        return false;
      }
      final prefix = await reader.read(payloadLength.clamp(0, 8));
      if (String.fromCharCodes(prefix) == 'OpusHead') return true;
      offset = payloadStart + payloadLength;
    }
  } on FileSystemException {
    return false;
  } finally {
    await reader?.close();
  }
  return false;
}

/// WebM and Matroska use the same EBML structure and track IDs. Read the
/// EBML DocType before choosing a saved suffix for either container.
Future<EbmlDocumentType> probeEbmlDocumentType(String path) async {
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final length = await reader.length();
    await for (final header in _ebmlElements(reader, 0, length)) {
      if (header.id != 0x1a45dfa3) return EbmlDocumentType.unknown;
      await for (final field
          in _ebmlElements(reader, header.contentStart, header.end)) {
        if (field.id != 0x4282) continue; // DocType
        final size = field.end - field.contentStart;
        if (size < 1 || size > 32) return EbmlDocumentType.unknown;
        await reader.setPosition(field.contentStart);
        final bytes = await reader.read(size);
        if (bytes.length != size) return EbmlDocumentType.unknown;
        return switch (String.fromCharCodes(bytes)) {
          'webm' => EbmlDocumentType.webm,
          'matroska' => EbmlDocumentType.matroska,
          _ => EbmlDocumentType.unknown,
        };
      }
      return EbmlDocumentType.unknown;
    }
  } on FileSystemException {
    return EbmlDocumentType.unknown;
  } finally {
    await reader?.close();
  }
  return EbmlDocumentType.unknown;
}

/// Identify Ogg streams from beginning-of-stream packets, then require at
/// least one encoded media packet. Comment/setup pages alone are not media.
Future<ProbedTrackKind> probeOggTrackKind(String path) async {
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final length = await reader.length();
    var offset = 0;
    var hasAudio = false;
    final streams = <int, _OggStream>{};
    while (length - offset >= 27) {
      await reader.setPosition(offset);
      final header = await reader.read(27);
      if (header.length != 27 ||
          String.fromCharCodes(header.take(4)) != 'OggS' ||
          header[4] != 0) {
        return ProbedTrackKind.unknown;
      }
      final lacing = await reader.read(header[26]);
      if (lacing.length != header[26]) return ProbedTrackKind.unknown;
      final payloadLength = lacing.fold<int>(0, (sum, value) => sum + value);
      final payloadStart = offset + 27 + lacing.length;
      if (payloadStart + payloadLength > length) {
        return ProbedTrackKind.unknown;
      }
      final serial = header[14] |
          (header[15] << 8) |
          (header[16] << 16) |
          (header[17] << 24);
      if ((header[5] & 0x02) != 0) {
        streams[serial] = _OggStream();
      }
      final stream = streams[serial];
      if (stream == null ||
          ((header[5] & 0x01) != 0) != (stream.packetLength > 0)) {
        return ProbedTrackKind.unknown;
      }
      final payload = await reader.read(payloadLength);
      if (payload.length != payloadLength) return ProbedTrackKind.unknown;
      var position = 0;
      for (final segmentLength in lacing) {
        // Dirac keyframes can include sequence and auxiliary units before
        // their picture unit. Keep a bounded prefix for those parse headers.
        final prefixLimit = stream.codec == _OggCodec.dirac ? 64 : 32;
        final prefixSize =
            (prefixLimit - stream.packetPrefix.length).clamp(0, segmentLength);
        stream.packetPrefix
            .addAll(payload.sublist(position, position + prefixSize));
        stream.packetLength += segmentLength;
        position += segmentLength;
        if (segmentLength == 255) continue;

        if (stream.packetCount == 0) {
          stream.codec = _oggCodecFromHeader(stream.packetPrefix);
        } else if (_oggIsMediaPacket(
            stream.codec, stream.packetPrefix, stream.packetLength,
            packetCount: stream.packetCount)) {
          if (stream.codec == _OggCodec.theora ||
              stream.codec == _OggCodec.dirac) {
            return ProbedTrackKind.video;
          }
          hasAudio = true;
          // Later chained groups can still declare video or unknown codecs.
        }
        stream.packetCount++;
        stream.packetLength = 0;
        stream.packetPrefix.clear();
      }
      offset = payloadStart + payloadLength;
    }
    return offset == length && hasAudio && _oggOnlyAudioStreams(streams.values)
        ? ProbedTrackKind.audio
        : ProbedTrackKind.unknown;
  } on FileSystemException {
    return ProbedTrackKind.unknown;
  } finally {
    await reader?.close();
  }
}

enum _OggCodec { vorbis, theora, dirac, opus, speex, flac }

class _OggStream {
  _OggCodec? codec;
  int packetCount = 0;
  int packetLength = 0;
  final packetPrefix = <int>[];
}

bool _oggOnlyAudioStreams(Iterable<_OggStream> streams) => streams.every(
    (stream) =>
        stream.codec != null &&
        stream.codec != _OggCodec.theora &&
        stream.codec != _OggCodec.dirac);

_OggCodec? _oggCodecFromHeader(List<int> bytes) {
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith([0x80, ...'theora'.codeUnits])) return _OggCodec.theora;
  if (bytes.length >= 13 && startsWith('BBCD'.codeUnits) && bytes[4] == 0) {
    return _OggCodec.dirac; // Dirac sequence header, not a picture.
  }
  if (startsWith([0x01, ...'vorbis'.codeUnits])) return _OggCodec.vorbis;
  if (startsWith('OpusHead'.codeUnits)) return _OggCodec.opus;
  if (startsWith('Speex   '.codeUnits)) return _OggCodec.speex;
  if (startsWith([0x7f, ...'FLAC'.codeUnits])) return _OggCodec.flac;
  return null;
}

bool _oggIsMediaPacket(_OggCodec? codec, List<int> prefix, int length,
    {required int packetCount}) {
  if (codec == null || length == 0 || prefix.isEmpty) return false;
  switch (codec) {
    case _OggCodec.vorbis:
      return (prefix[0] & 1) == 0; // Header packets have the low bit set.
    case _OggCodec.theora:
      return (prefix[0] & 0x80) == 0; // Headers have the high bit set.
    case _OggCodec.dirac:
      return _oggDiracHasPicture(prefix, length);
    case _OggCodec.opus:
      return packetCount >= 2 &&
          !_oggStartsWith(prefix, 'OpusHead'.codeUnits) &&
          !_oggStartsWith(prefix, 'OpusTags'.codeUnits);
    case _OggCodec.speex:
      return packetCount >= 2; // Skip identification and comment packets.
    case _OggCodec.flac:
      return prefix.length >= 2 &&
          prefix[0] == 0xff &&
          (prefix[1] & 0xfe) == 0xf8;
  }
}

/// Dirac parse-info units use BBCD, a parse code and a next-unit offset.
/// Sequence/auxiliary headers can precede a picture in the same Ogg packet.
bool _oggDiracHasPicture(List<int> prefix, int length) {
  var offset = 0;
  while (offset + 9 <= prefix.length && length - offset >= 13) {
    if (!_oggStartsWith(prefix.sublist(offset), 'BBCD'.codeUnits)) return false;
    final nextOffset = (prefix[offset + 5] << 24) |
        (prefix[offset + 6] << 16) |
        (prefix[offset + 7] << 8) |
        prefix[offset + 8];
    final unitLength = nextOffset == 0 ? length - offset : nextOffset;
    if (unitLength < 13 || unitLength > length - offset) return false;
    if ((prefix[offset + 4] & 8) != 0) return unitLength > 13;
    if (nextOffset == 0) return false;
    offset += nextOffset;
  }
  return false;
}

bool _oggStartsWith(List<int> bytes, List<int> signature) {
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}

/// Walk WebM's EBML Segment/Tracks/TrackEntry/TrackType hierarchy. TrackType
/// 1 is video, 2 is audio; matching video frames take priority over audio.
/// A Tracks-only initialization segment is not a completed media file.
Future<ProbedTrackKind> probeWebmTrackKind(String path) async {
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final length = await reader.length();
    var sawEbmlHeader = false;
    await for (final top in _ebmlElements(reader, 0, length)) {
      if (!sawEbmlHeader) {
        if (top.id != 0x1a45dfa3) return ProbedTrackKind.unknown;
        sawEbmlHeader = true;
        continue;
      }
      if (top.id != 0x18538067) continue; // Segment
      final tracks = <int, int>{};
      await for (final child in _ebmlElements(reader, top.contentStart, top.end,
          segmentLevel: true)) {
        if (child.id != 0x1654ae6b) continue; // Tracks
        await for (final entry
            in _ebmlElements(reader, child.contentStart, child.end)) {
          if (entry.id != 0xae) continue; // TrackEntry
          int? number;
          int? type;
          await for (final field
              in _ebmlElements(reader, entry.contentStart, entry.end)) {
            if (field.id != 0xd7 && field.id != 0x83) continue;
            final size = field.end - field.contentStart;
            if (size < 1 || size > 8) return ProbedTrackKind.unknown;
            await reader.setPosition(field.contentStart);
            final value = await reader.read(size);
            if (value.length != size) return ProbedTrackKind.unknown;
            var integer = 0;
            for (final byte in value) {
              integer = (integer << 8) | byte;
            }
            if (field.id == 0xd7) number = integer; // TrackNumber
            if (field.id == 0x83) type = integer; // TrackType
          }
          if (number == null ||
              number <= 0 ||
              type == null ||
              tracks.containsKey(number)) {
            return ProbedTrackKind.unknown;
          }
          tracks[number] = type;
        }
      }
      // Resolve declarations first, including files placing Tracks after Clusters.
      var hasAudio = false;
      await for (final child in _ebmlElements(reader, top.contentStart, top.end,
          segmentLevel: true)) {
        if (child.id != 0x1f43b675) continue; // Cluster
        final kind = await _clusterTrackKind(reader, child, tracks);
        if (kind == ProbedTrackKind.video) return kind;
        hasAudio |= kind == ProbedTrackKind.audio;
      }
      return hasAudio ? ProbedTrackKind.audio : ProbedTrackKind.unknown;
    }
  } on FileSystemException {
    return ProbedTrackKind.unknown;
  } finally {
    await reader?.close();
  }
  return ProbedTrackKind.unknown;
}

Future<ProbedTrackKind> _clusterTrackKind(
    RandomAccessFile reader, _EbmlElement cluster, Map<int, int> tracks) async {
  var hasAudio = false;
  Future<ProbedTrackKind> blockKind(_EbmlElement block) async {
    final number = await _blockTrackWithPayload(reader, block);
    return switch (tracks[number]) {
      1 => ProbedTrackKind.video,
      2 => ProbedTrackKind.audio,
      _ => ProbedTrackKind.unknown,
    };
  }

  await for (final child
      in _ebmlElements(reader, cluster.contentStart, cluster.end)) {
    if (child.id == 0xa3) {
      // SimpleBlock
      final kind = await blockKind(child);
      if (kind == ProbedTrackKind.video) return kind;
      hasAudio |= kind == ProbedTrackKind.audio;
    }
    if (child.id != 0xa0) continue; // BlockGroup
    await for (final field
        in _ebmlElements(reader, child.contentStart, child.end)) {
      if (field.id != 0xa1) continue; // Block
      final kind = await blockKind(field);
      if (kind == ProbedTrackKind.video) return kind;
      hasAudio |= kind == ProbedTrackKind.audio;
    }
  }
  return hasAudio ? ProbedTrackKind.audio : ProbedTrackKind.unknown;
}

Future<int?> _blockTrackWithPayload(
    RandomAccessFile reader, _EbmlElement block) async {
  final track =
      await _readEbmlVint(reader, block.contentStart, block.end, isId: false);
  // Track number, signed 16-bit timecode and flags precede the frame bytes.
  if (track == null ||
      track.unknownSize ||
      track.value <= 0 ||
      block.end - block.contentStart <= track.width + 3) {
    return null;
  }
  await reader.setPosition(block.contentStart + track.width);
  final header = await reader.read(3);
  if (header.length != 3) return null;
  final lacing = header[2] & 6;
  var offset = block.contentStart + track.width + 3;
  if (lacing == 0) return track.value;
  final frameCount = await reader.readByte() + 1;
  offset++;
  if (frameCount < 2) return null;
  if (lacing == 4) {
    // Fixed-size lacing.
    final remaining = block.end - offset;
    return remaining > 0 && remaining % frameCount == 0 ? track.value : null;
  }

  var used = 0;
  if (lacing == 2) {
    // Xiph lengths for all frames except the last.
    final remaining = block.end - offset;
    final prefix = await reader.read(remaining < 65536 ? remaining : 65536);
    var index = 0;
    for (var frame = 0; frame < frameCount - 1; frame++) {
      var size = 0;
      int byte;
      do {
        if (index >= prefix.length) return null;
        byte = prefix[index++];
        size += byte;
      } while (byte == 255);
      used += size;
    }
    offset += index;
  } else {
    // EBML unsigned first length followed by signed size differences.
    var size = 0;
    for (var frame = 0; frame < frameCount - 1; frame++) {
      final value = await _readEbmlVint(reader, offset, block.end, isId: false);
      if (value == null) return null;
      offset += value.width;
      size = frame == 0
          ? value.value
          : size + value.value - ((1 << (7 * value.width - 1)) - 1);
      if (size < 0) return null;
      used += size;
    }
  }
  // The last frame consumes the remainder; descriptors/padding prove no data.
  final remaining = block.end - offset;
  return remaining > 0 && used <= remaining ? track.value : null;
}

class _EbmlElement {
  final int id;
  final int contentStart;
  final int end;

  const _EbmlElement(this.id, this.contentStart, this.end);
}

class _EbmlVint {
  final int value;
  final int width;
  final bool unknownSize;

  const _EbmlVint(this.value, this.width, this.unknownSize);
}

Stream<_EbmlElement> _ebmlElements(RandomAccessFile reader, int start, int end,
    {bool segmentLevel = false}) async* {
  var offset = start;
  while (offset < end) {
    final id = await _readEbmlVint(reader, offset, end, isId: true);
    if (id == null) return;
    final size =
        await _readEbmlVint(reader, offset + id.width, end, isId: false);
    if (size == null) return;
    final contentStart = offset + id.width + size.width;
    var contentEnd = size.unknownSize ? end : contentStart + size.value;
    if (segmentLevel && id.value == 0x1f43b675 && size.unknownSize) {
      final clusterEnd = await _unknownClusterEnd(reader, contentStart, end);
      if (clusterEnd == null) return;
      contentEnd = clusterEnd;
    }
    if (contentEnd > end || contentEnd < contentStart) return;
    yield _EbmlElement(id.value, contentStart, contentEnd);
    offset = contentEnd;
  }
}

/// RFC 8794 section 6.2: a Segment sibling ends an unknown-size Cluster.
/// Walk complete framed children; sibling-looking bytes in block/Void payloads
/// are skipped with their enclosing element and cannot create a boundary.
Future<int?> _unknownClusterEnd(
    RandomAccessFile reader, int start, int end) async {
  var offset = start;
  while (offset < end) {
    final id = await _readEbmlVint(reader, offset, end, isId: true);
    if (id == null) return null;
    final size =
        await _readEbmlVint(reader, offset + id.width, end, isId: false);
    if (size == null) return null;
    final contentStart = offset + id.width + size.width;
    final contentEnd = size.unknownSize ? end : contentStart + size.value;
    if (contentEnd > end || contentEnd < contentStart) return null;
    if (const {
      0x114d9b74, // SeekHead
      0x1549a966, // Info
      0x1654ae6b, // Tracks
      0x1f43b675, // Cluster
      0x1c53bb6b, // Cues
      0x1941a469, // Attachments
      0x1043a770, // Chapters
      0x1254c367, // Tags
    }.contains(id.value)) {
      return offset;
    }
    // Only Segment/Cluster unknown sizes are supported by this bounded walker.
    if (size.unknownSize) return null;
    offset = contentEnd;
  }
  return offset;
}

Future<_EbmlVint?> _readEbmlVint(RandomAccessFile reader, int offset, int end,
    {required bool isId}) async {
  if (offset >= end) return null;
  await reader.setPosition(offset);
  final first = await reader.readByte();
  if (first <= 0) return null;
  var marker = 0x80;
  var width = 1;
  while ((first & marker) == 0) {
    marker >>= 1;
    width++;
    if (marker == 0 || (isId && width > 4)) return null;
  }
  if (offset + width > end) return null;
  var value = isId ? first : first & (marker - 1);
  for (var i = 1; i < width; i++) {
    final byte = await reader.readByte();
    if (byte < 0) return null;
    value = (value << 8) | byte;
  }
  final unknownSize = !isId && value == (1 << (7 * width)) - 1;
  return _EbmlVint(value, width, unknownSize);
}
