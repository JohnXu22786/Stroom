import 'dart:io';

import 'catcatch_task.dart';
import 'media_resource.dart';
import 'shared_container_probe.dart';

enum CatCatchMediaKind { audio, video, other }

enum IsoMediaFamily { mp4, quickTime, unknown }

/// The track kind and playable suffix established from saved bytes.
/// Discovery names and server MIME values are deliberately excluded.
typedef CatCatchVerifiedMedia = ({CatCatchMediaKind kind, String extension});

/// This hint is used before download, when no file is available to inspect.
/// Completed files must go through [catCatchMediaKindFromFile].
CatCatchMediaKind? catCatchSingleKindFromExtension(String extension) {
  final ext = extension.toLowerCase();
  if (const {'mp3', 'wav', 'aac', 'flac'}.contains(ext)) {
    return CatCatchMediaKind.audio;
  }
  return null;
}

/// Filenames for these containers do not prove which tracks they contain.
/// A missing hint can be selected for either declared output, then the saved
/// bytes are checked by [catCatchMediaKindFromFile].
bool catCatchIsSharedContainerExtension(String extension) => const {
      'mp4',
      'm4a',
      'mov',
      'ogg',
      'ogv',
      'opus',
      'webm',
      'weba',
      'mkv',
      'mka',
      'wma',
      'wmv',
      'flv',
      'ev1',
      'avi',
      'mpeg',
      'mpg',
    }.contains(extension.toLowerCase());

/// Use available discovery metadata for selection and split-track detection.
/// A probed video dimension is stronger evidence than a server-provided MIME;
/// neither is trusted after download. Resource type getters derive from the
/// filename, so they cannot disambiguate the shared containers above.
CatCatchMediaKind? catCatchResourceKindHint(MediaResource resource) {
  final singleKind = catCatchSingleKindFromExtension(resource.ext);
  if (singleKind != null) return singleKind;
  if ((resource.width ?? 0) > 0 || (resource.height ?? 0) > 0) {
    return CatCatchMediaKind.video;
  }
  final mime = resource.mimeType?.split(';').first.trim().toLowerCase() ?? '';
  if (mime.startsWith('audio/')) return CatCatchMediaKind.audio;
  if (mime.startsWith('video/')) return CatCatchMediaKind.video;
  if (resource.isPlaylist || catCatchIsSharedContainerExtension(resource.ext)) {
    return null;
  }
  if (resource.isAudio) return CatCatchMediaKind.audio;
  if (resource.isVideo) return CatCatchMediaKind.video;
  return null;
}

/// Classify the saved bytes, independent of the server's MIME or resource
/// flags. Shared containers need track probes; simpler formats need their
/// signatures checked before they can be forwarded or put in a gallery.
Future<CatCatchMediaKind> catCatchMediaKindFromFile(
        CatCatchTask task, String savedPath) =>
    catCatchMediaKindFromPath(savedPath);

/// Inspect a local media file without relying on task metadata or MIME.
Future<CatCatchMediaKind> catCatchMediaKindFromPath(String savedPath) async =>
    (await catCatchVerifiedMediaFromPath(savedPath))?.kind ??
    CatCatchMediaKind.other;

/// Choose a bounded track probe by the file's container signature, not by its
/// possibly incorrect download suffix. The returned suffix is safe to use for
/// completed copies, gallery records and flow attachments.
Future<CatCatchVerifiedMedia?> catCatchVerifiedMediaFromPath(
    String path) async {
  RandomAccessFile? reader;
  late final List<int> header;
  late final int length;
  try {
    reader = await File(path).open();
    length = await reader.length();
    header = await reader.read(length < 16 ? length : 16);
  } on FileSystemException {
    return null;
  } finally {
    await reader?.close();
  }

  if (_hasBytes(header, 'OggS'.codeUnits)) {
    final kind = _fromProbedTrackKind(await probeOggTrackKind(path));
    if (kind == CatCatchMediaKind.other) return null;
    final extension = kind == CatCatchMediaKind.video
        ? '.ogv'
        : await hasOggOpusHead(path)
            ? '.opus'
            : '.ogg';
    return (kind: kind, extension: extension);
  }
  if (_hasBytes(header, const [0x1a, 0x45, 0xdf, 0xa3])) {
    final documentType = await probeEbmlDocumentType(path);
    if (documentType == EbmlDocumentType.unknown) return null;
    final kind = _fromProbedTrackKind(await probeWebmTrackKind(path));
    return switch ((documentType, kind)) {
      (EbmlDocumentType.webm, CatCatchMediaKind.audio) => (
          kind: kind,
          extension: '.weba'
        ),
      (EbmlDocumentType.webm, CatCatchMediaKind.video) => (
          kind: kind,
          extension: '.webm'
        ),
      (EbmlDocumentType.matroska, CatCatchMediaKind.audio) => (
          kind: kind,
          extension: '.mka'
        ),
      (EbmlDocumentType.matroska, CatCatchMediaKind.video) => (
          kind: kind,
          extension: '.mkv'
        ),
      _ => null,
    };
  }
  if (_hasBytes(header, const [
    0x30,
    0x26,
    0xb2,
    0x75,
    0x8e,
    0x66,
    0xcf,
    0x11,
    0xa6,
    0xd9,
    0x00,
    0xaa,
    0x00,
    0x62,
    0xce,
    0x6c,
  ])) {
    final kind = await _probeAsfKind(path);
    return switch (kind) {
      CatCatchMediaKind.audio => (kind: kind, extension: '.wma'),
      CatCatchMediaKind.video => (kind: kind, extension: '.wmv'),
      CatCatchMediaKind.other => null,
    };
  }
  if (_hasBytes(header, 'RIFF'.codeUnits) &&
      _hasBytes(header, 'AVI '.codeUnits, at: 8)) {
    final kind = await _probeAviKind(path);
    return kind == CatCatchMediaKind.other
        ? null
        : (kind: kind, extension: '.avi');
  }
  if (_hasBytes(header, const [0, 0, 1, 0xba]) ||
      _hasBytes(header, const [0, 0, 1, 0xb3])) {
    final kind = await _probeMpegKind(path);
    return kind == CatCatchMediaKind.other
        ? null
        : (kind: kind, extension: '.mpeg');
  }
  if (_looksLikeIsoContainer(header, length)) {
    final family = await probeIsoMediaFamily(path);
    if (family == IsoMediaFamily.unknown) return null;
    final kind = await _probeMp4Kind(path);
    return switch ((family, kind)) {
      (IsoMediaFamily.mp4, CatCatchMediaKind.audio) => (
          kind: kind,
          extension: '.m4a'
        ),
      (IsoMediaFamily.mp4, CatCatchMediaKind.video) => (
          kind: kind,
          extension: '.mp4'
        ),
      (IsoMediaFamily.quickTime, CatCatchMediaKind.audio) ||
      (IsoMediaFamily.quickTime, CatCatchMediaKind.video) =>
        (kind: kind, extension: '.mov'),
      _ => null,
    };
  }
  if (_hasBytes(header, const [0xb9, 0xb3, 0xa9])) {
    // Obfuscated EV1 must be converted before it can be opened or saved.
    return null;
  }
  if (_hasBytes(header, 'FLV'.codeUnits)) {
    final kind = await _probeFlvKind(path, header, length);
    return kind == CatCatchMediaKind.other
        ? null
        : (kind: kind, extension: '.flv');
  }
  if ((_hasBytes(header, 'RIFF'.codeUnits) ||
          _hasBytes(header, 'RF64'.codeUnits) ||
          _hasBytes(header, 'RIFX'.codeUnits)) &&
      _hasBytes(header, 'WAVE'.codeUnits, at: 8)) {
    return await _probeWave(path, length)
        ? (kind: CatCatchMediaKind.audio, extension: '.wav')
        : null;
  }
  if (_hasBytes(header, 'fLaC'.codeUnits)) {
    return await _probeFlac(path, length)
        ? (kind: CatCatchMediaKind.audio, extension: '.flac')
        : null;
  }
  if (_hasBytes(header, 'ID3'.codeUnits) ||
      (header.length >= 2 && header[0] == 0xff)) {
    if (await _probeMp3(path)) {
      return (kind: CatCatchMediaKind.audio, extension: '.mp3');
    }
  }
  if (_hasAacHeader(header, length)) {
    return (kind: CatCatchMediaKind.audio, extension: '.aac');
  }
  return null;
}

bool _looksLikeIsoContainer(List<int> header, int length) {
  if (header.length < 8) return false;
  final size = _readMp4Uint(header, 0, 4);
  if (size != 0 && size != 1 && (size < 8 || size > length)) return false;
  return const {'ftyp', 'moov', 'mdat', 'free', 'skip', 'wide', 'uuid'}
      .contains(String.fromCharCodes(header.skip(4).take(4)));
}

Future<bool> _probeMp3(String path) async {
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final length = await reader.length();
    final header = await reader.read(length < 16 ? length : 16);
    return await _hasMp3Frame(reader, header, length);
  } on FileSystemException {
    return false;
  } finally {
    await reader?.close();
  }
}

bool _hasBytes(List<int> bytes, List<int> signature, {int at = 0}) {
  if (bytes.length < at + signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[at + i] != signature[i]) return false;
  }
  return true;
}

/// An ID3 tag is metadata, so seek past it and require an MPEG Layer III
/// frame. Raw MP3 files start directly with that frame.
Future<bool> _hasMp3Frame(
    RandomAccessFile reader, List<int> header, int length) async {
  var offset = 0;
  if (_hasBytes(header, 'ID3'.codeUnits)) {
    if (header.length < 10 ||
        header[3] < 2 ||
        header[3] > 4 ||
        header.skip(6).take(4).any((byte) => byte > 0x7f)) {
      return false;
    }
    final tagSize =
        (header[6] << 21) | (header[7] << 14) | (header[8] << 7) | header[9];
    offset = 10 + tagSize;
    if (header[3] == 4 && (header[5] & 0x10) != 0) offset += 10;
  }
  if (length - offset < 24) return false;
  await reader.setPosition(offset);
  final frame = await reader.read(4);
  if (frame.length != 4 || frame[0] != 0xff || (frame[1] & 0xe0) != 0xe0) {
    return false;
  }
  final version = (frame[1] >> 3) & 0x03;
  final layer = (frame[1] >> 1) & 0x03;
  final bitrateIndex = (frame[2] >> 4) & 0x0f;
  final sampleRateIndex = (frame[2] >> 2) & 0x03;
  if (version == 1 ||
      layer != 1 ||
      bitrateIndex == 0 ||
      bitrateIndex == 15 ||
      sampleRateIndex == 3) {
    return false;
  }
  const mpeg1Bitrates = [
    0,
    32,
    40,
    48,
    56,
    64,
    80,
    96,
    112,
    128,
    160,
    192,
    224,
    256,
    320,
  ];
  const mpeg2Bitrates = [
    0,
    8,
    16,
    24,
    32,
    40,
    48,
    56,
    64,
    80,
    96,
    112,
    128,
    144,
    160,
  ];
  final sampleRate = switch (version) {
    3 => [44100, 48000, 32000][sampleRateIndex],
    2 => [22050, 24000, 16000][sampleRateIndex],
    _ => [11025, 12000, 8000][sampleRateIndex],
  };
  final bitrate = (version == 3 ? mpeg1Bitrates : mpeg2Bitrates)[bitrateIndex];
  final frameLength =
      ((version == 3 ? 144000 : 72000) * bitrate ~/ sampleRate) +
          ((frame[2] >> 1) & 1);
  return frameLength >= 24 && length - offset >= frameLength;
}

bool _hasAacHeader(List<int> header, int length) {
  // ADIF needs bitstream parsing to locate its audio payload; its marker alone
  // is not evidence of a completed download.
  if (header.length >= 7 &&
      header[0] == 0xff &&
      (header[1] & 0xf0) == 0xf0 &&
      (header[1] & 0x06) == 0 &&
      ((header[2] >> 2) & 0x0f) != 0x0f) {
    final frameLength =
        ((header[3] & 0x03) << 11) | (header[4] << 3) | (header[5] >> 5);
    final headerLength = (header[1] & 1) == 0 ? 9 : 7;
    // One byte can hold only an end marker; require encoded frame payload.
    return frameLength >= headerLength + 2 && frameLength <= length;
  }
  // LOAS/LATM carries an AAC AudioMuxElement after its 3-byte sync header.
  if (header.length >= 3 && header[0] == 0x56 && (header[1] & 0xe0) == 0xe0) {
    final frameLength = ((header[1] & 0x1f) << 8) | header[2];
    return frameLength >= 2 && frameLength + 3 <= length;
  }
  return false;
}

/// RIFF signatures and a `fmt ` chunk can exist before any audio samples.
/// Walk only chunk headers, validating the declared file/data bounds instead
/// of loading a potentially large recording into memory.
Future<bool> _probeWave(String path, int length) async {
  if (length < 44) return false;
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final header = await reader.read(12);
    if (header.length != 12 || !_hasBytes(header, 'WAVE'.codeUnits, at: 8)) {
      return false;
    }
    final rf64 = _hasBytes(header, 'RF64'.codeUnits);
    final bigEndian = _hasBytes(header, 'RIFX'.codeUnits);
    final riffSize = _readWaveSize(header, 4, bigEndian);
    if (rf64 && riffSize != 0xffffffff) return false;
    if (!rf64 && (riffSize < 36 || riffSize + 8 > length)) return false;
    var containerEnd = rf64 ? length : riffSize + 8;
    int? largeDataSize;
    var offset = 12;
    var hasFormat = false;
    var dataSize = 0;
    var blockAlign = 0;
    for (var chunks = 0;
        chunks < 4096 && offset + 8 <= containerEnd;
        chunks++) {
      await reader.setPosition(offset);
      final chunk = await reader.read(8);
      if (chunk.length != 8) return false;
      final name = String.fromCharCodes(chunk.take(4));
      var size = _readWaveSize(chunk, 4, bigEndian);
      if (name == 'data' && rf64 && size == 0xffffffff) {
        if (largeDataSize == null) return false;
        size = largeDataSize;
      }
      final contentStart = offset + 8;
      final contentEnd = contentStart + size;
      if (contentEnd > containerEnd || contentEnd > length) return false;
      if (name == 'ds64' && rf64) {
        if (size < 28) return false;
        final values = await reader.read(16);
        if (values.length != 16) return false;
        final fullRiffSize = _readLittleEndian(values, 0, 8);
        largeDataSize = _readLittleEndian(values, 8, 8);
        if (fullRiffSize < 36 ||
            fullRiffSize + 8 > length ||
            fullRiffSize + 8 < contentEnd) {
          return false;
        }
        containerEnd = fullRiffSize + 8;
      } else if (name == 'fmt ') {
        if (size < 16) return false;
        final format = await reader.read(16);
        if (format.length != 16) return false;
        final codec = _readWaveSize(format, 0, bigEndian, count: 2);
        final channels = _readWaveSize(format, 2, bigEndian, count: 2);
        final sampleRate = _readWaveSize(format, 4, bigEndian);
        blockAlign = _readWaveSize(format, 12, bigEndian, count: 2);
        hasFormat =
            codec != 0 && channels != 0 && sampleRate != 0 && blockAlign != 0;
      } else if (name == 'data') {
        dataSize = size;
      }
      offset = contentEnd + (size & 1);
      if (offset > containerEnd) return false;
      if (hasFormat && dataSize >= blockAlign) return true;
    }
  } on FileSystemException {
    return false;
  } finally {
    await reader?.close();
  }
  return false;
}

int _readWaveSize(List<int> bytes, int start, bool bigEndian, {int count = 4}) {
  var value = 0;
  for (var i = 0; i < count; i++) {
    value = (value << 8) | bytes[start + (bigEndian ? i : count - 1 - i)];
  }
  return value;
}

/// FLAC must have complete STREAMINFO metadata followed by an audio frame.
Future<bool> _probeFlac(String path, int length) async {
  if (length < 52) return false;
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    var offset = 4;
    var firstBlock = true;
    for (var blocks = 0; blocks < 256 && offset + 4 <= length; blocks++) {
      await reader.setPosition(offset);
      final header = await reader.read(4);
      if (header.length != 4) return false;
      final blockType = header[0] & 0x7f;
      final blockLength = (header[1] << 16) | (header[2] << 8) | header[3];
      if (blockType > 6 ||
          (firstBlock && (blockType != 0 || blockLength != 34)) ||
          offset + 4 + blockLength > length) {
        return false;
      }
      if (firstBlock) {
        final streamInfo = await reader.read(34);
        if (streamInfo.length != 34 ||
            (streamInfo[0] == 0 && streamInfo[1] == 0) ||
            (streamInfo[2] == 0 && streamInfo[3] == 0) ||
            (streamInfo[10] == 0 &&
                streamInfo[11] == 0 &&
                (streamInfo[12] & 0xf0) == 0)) {
          return false;
        }
      }
      offset += 4 + blockLength;
      firstBlock = false;
      if ((header[0] & 0x80) == 0) continue;
      return await _hasFlacFrame(reader, offset, length);
    }
  } on FileSystemException {
    return false;
  } finally {
    await reader?.close();
  }
  return false;
}

Future<bool> _hasFlacFrame(
    RandomAccessFile reader, int offset, int length) async {
  if (length - offset < 10) return false;
  await reader.setPosition(offset);
  final frame = await reader.read(length - offset < 32 ? length - offset : 32);
  if (frame.length < 10 ||
      frame[0] != 0xff ||
      (frame[1] & 0xfe) != 0xf8 ||
      (frame[2] >> 4) == 0 ||
      (frame[2] & 0x0f) == 15 ||
      (frame[3] >> 4) > 10 ||
      ((frame[3] >> 1) & 7) == 3 ||
      (frame[3] & 1) != 0) {
    return false;
  }
  final numberByte = frame[4];
  final numberLength = numberByte < 0x80
      ? 1
      : numberByte < 0xc0
          ? 0
          : numberByte < 0xe0
              ? 2
              : numberByte < 0xf0
                  ? 3
                  : numberByte < 0xf8
                      ? 4
                      : numberByte < 0xfc
                          ? 5
                          : numberByte < 0xfe
                              ? 6
                              : numberByte == 0xfe
                                  ? 7
                                  : 0;
  if (numberLength == 0) return false;
  var headerLength = 4 + numberLength;
  if (frame.length < headerLength) return false;
  for (var i = 5; i < headerLength; i++) {
    if ((frame[i] & 0xc0) != 0x80) return false;
  }
  final blockCode = frame[2] >> 4;
  if (blockCode == 6) {
    headerLength++;
  } else if (blockCode == 7) {
    headerLength += 2;
  }
  final rateCode = frame[2] & 0x0f;
  if (rateCode == 12) {
    headerLength++;
  } else if (rateCode == 13 || rateCode == 14) {
    headerLength += 2;
  }
  // CRC-8 closes the header. Leave at least a subframe and CRC-16 footer.
  if (length - offset < headerLength + 5 || frame.length < headerLength + 1) {
    return false;
  }
  var crc = 0;
  for (var i = 0; i < headerLength; i++) {
    crc ^= frame[i];
    for (var bit = 0; bit < 8; bit++) {
      crc = ((crc & 0x80) != 0 ? (crc << 1) ^ 0x07 : crc << 1) & 0xff;
    }
  }
  return crc == frame[headerLength];
}

/// ASF's outer signature identifies its container, not its media kind.
/// Stream Properties objects carry audio/video GUIDs; video wins for a file
/// containing both tracks. A completed file also needs a Data Object with
/// the declared packets. Object sizes let us skip metadata without reading
/// the complete ASF file into memory.
Future<CatCatchMediaKind> _probeAsfKind(String path) async {
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final fileLength = await reader.length();
    if (fileLength < 30) return CatCatchMediaKind.other;
    final header = await reader.read(30);
    if (!_hasBytes(header, const [
      0x30,
      0x26,
      0xb2,
      0x75,
      0x8e,
      0x66,
      0xcf,
      0x11,
      0xa6,
      0xd9,
      0x00,
      0xaa,
      0x00,
      0x62,
      0xce,
      0x6c,
    ])) {
      return CatCatchMediaKind.other;
    }
    final headerSize = _readLittleEndian(header, 16, 8);
    final objectCount = _readLittleEndian(header, 24, 4);
    if (headerSize < 30 ||
        headerSize > fileLength ||
        objectCount > (headerSize - 30) ~/ 24) {
      return CatCatchMediaKind.other;
    }

    var offset = 30;
    var hasAudio = false;
    var hasVideo = false;
    int? declaredPacketCount;
    int? minPacketSize;
    int? maxPacketSize;
    for (var i = 0; i < objectCount; i++) {
      if (headerSize - offset < 24) return CatCatchMediaKind.other;
      await reader.setPosition(offset);
      final objectHeader = await reader.read(24);
      if (objectHeader.length != 24) return CatCatchMediaKind.other;
      final objectSize = _readLittleEndian(objectHeader, 16, 8);
      if (objectSize < 24 || objectSize > headerSize - offset) {
        return CatCatchMediaKind.other;
      }
      if (_hasBytes(objectHeader, const [
        0xa1,
        0xdc,
        0xab,
        0x8c,
        0x47,
        0xa9,
        0xcf,
        0x11,
        0x8e,
        0xe4,
        0x00,
        0xc0,
        0x0c,
        0x20,
        0x53,
        0x65,
      ])) {
        // File Properties describes the expected number and size of packets.
        if (objectSize < 104) return CatCatchMediaKind.other;
        final properties = await reader.read(80);
        if (properties.length != 80) return CatCatchMediaKind.other;
        declaredPacketCount = _readLittleEndian(properties, 32, 8);
        minPacketSize = _readLittleEndian(properties, 68, 4);
        maxPacketSize = _readLittleEndian(properties, 72, 4);
      } else if (_hasBytes(objectHeader, const [
        0x91,
        0x07,
        0xdc,
        0xb7,
        0xb7,
        0xa9,
        0xcf,
        0x11,
        0x8e,
        0xe6,
        0x00,
        0xc0,
        0x0c,
        0x20,
        0x53,
        0x65,
      ])) {
        // Stream Properties has 54 fixed bytes after its 24-byte header.
        if (objectSize < 78) return CatCatchMediaKind.other;
        final properties = await reader.read(54);
        if (properties.length != 54) return CatCatchMediaKind.other;
        final typeDataLength = _readLittleEndian(properties, 40, 4);
        final correctionDataLength = _readLittleEndian(properties, 44, 4);
        final variableLength = objectSize - 78;
        if (typeDataLength > variableLength ||
            correctionDataLength > variableLength - typeDataLength) {
          return CatCatchMediaKind.other;
        }
        if (_hasBytes(properties, const [
          0x40,
          0x9e,
          0x69,
          0xf8,
          0x4d,
          0x5b,
          0xcf,
          0x11,
          0xa8,
          0xfd,
          0x00,
          0x80,
          0x5f,
          0x5c,
          0x44,
          0x2b,
        ])) {
          hasAudio = true;
        } else if (_hasBytes(properties, const [
              0xc0,
              0xef,
              0x19,
              0xbc,
              0x4d,
              0x5b,
              0xcf,
              0x11,
              0xa8,
              0xfd,
              0x00,
              0x80,
              0x5f,
              0x5c,
              0x44,
              0x2b,
            ]) ||
            // ASF JFIF media is also a video stream.
            _hasBytes(properties, const [
              0x00,
              0xe1,
              0x1b,
              0xb6,
              0x4e,
              0x5b,
              0xcf,
              0x11,
              0xa8,
              0xfd,
              0x00,
              0x80,
              0x5f,
              0x5c,
              0x44,
              0x2b,
            ])) {
          hasVideo = true;
        }
      }
      offset += objectSize;
    }
    if (offset != headerSize) return CatCatchMediaKind.other;
    if (!await _hasAsfDataPackets(reader, headerSize, fileLength,
        declaredPacketCount, minPacketSize, maxPacketSize)) {
      return CatCatchMediaKind.other;
    }
    if (hasVideo) return CatCatchMediaKind.video;
    if (hasAudio) return CatCatchMediaKind.audio;
  } on FileSystemException {
    return CatCatchMediaKind.other;
  } finally {
    await reader?.close();
  }
  return CatCatchMediaKind.other;
}

/// The ASF Data Object starts after the Header Object. Verify that its
/// declared packet count can fit within the available bytes using File
/// Properties' packet-size bounds; an initialization/header-only download
/// must not be accepted as completed media.
Future<bool> _hasAsfDataPackets(
  RandomAccessFile reader,
  int headerSize,
  int fileLength,
  int? declaredPacketCount,
  int? minPacketSize,
  int? maxPacketSize,
) async {
  if (declaredPacketCount == null ||
      declaredPacketCount <= 0 ||
      minPacketSize == null ||
      minPacketSize <= 0 ||
      maxPacketSize == null ||
      maxPacketSize < minPacketSize ||
      fileLength - headerSize < 50) {
    return false;
  }
  await reader.setPosition(headerSize);
  final dataHeader = await reader.read(50);
  if (dataHeader.length != 50 ||
      !_hasBytes(dataHeader, const [
        0x36,
        0x26,
        0xb2,
        0x75,
        0x8e,
        0x66,
        0xcf,
        0x11,
        0xa6,
        0xd9,
        0x00,
        0xaa,
        0x00,
        0x62,
        0xce,
        0x6c,
      ])) {
    return false;
  }
  final dataObjectSize = _readLittleEndian(dataHeader, 16, 8);
  final dataPacketCount = _readLittleEndian(dataHeader, 40, 8);
  if (dataObjectSize < 50 ||
      dataObjectSize > fileLength - headerSize ||
      dataPacketCount != declaredPacketCount) {
    return false;
  }
  final packetBytes = dataObjectSize - 50;
  return packetBytes >= minPacketSize &&
      dataPacketCount <= packetBytes ~/ minPacketSize &&
      dataPacketCount >= ((packetBytes - 1) ~/ maxPacketSize) + 1;
}

int _readLittleEndian(List<int> bytes, int start, int count) {
  var value = 0;
  for (var i = count - 1; i >= 0; i--) {
    value = (value << 8) | bytes[start + i];
  }
  return value;
}

/// AVI is a RIFF container. A RIFF/AVI signature says nothing about its
/// streams; the `strh` headers inside `hdrl/strl` identify each track.
Future<CatCatchMediaKind> _probeAviKind(String path) async {
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final fileLength = await reader.length();
    if (fileLength < 12) return CatCatchMediaKind.other;
    final header = await reader.read(12);
    if (!_hasBytes(header, 'RIFF'.codeUnits) ||
        !_hasBytes(header, 'AVI '.codeUnits, at: 8)) {
      return CatCatchMediaKind.other;
    }
    final riffEnd = 8 + _readLittleEndian(header, 4, 4);
    if (riffEnd < 12 || riffEnd > fileLength) return CatCatchMediaKind.other;
    final topLevel = await _riffChunks(reader, 12, riffEnd);
    if (topLevel == null) return CatCatchMediaKind.other;

    var hasAudio = false;
    var hasVideo = false;
    var hasUnrecognizedTrack = false;
    final streamTypes = <String>[];
    final movies = <_RiffChunk>[];
    for (final chunk in topLevel) {
      if (chunk.type != 'LIST' || chunk.end - chunk.contentStart < 4) {
        continue;
      }
      await reader.setPosition(chunk.contentStart);
      final listType = String.fromCharCodes(await reader.read(4));
      if (listType == 'movi') {
        movies.add(chunk);
        continue;
      }
      if (listType != 'hdrl') continue;
      final headers =
          await _riffChunks(reader, chunk.contentStart + 4, chunk.end);
      if (headers == null) return CatCatchMediaKind.other;
      for (final streamList in headers) {
        if (streamList.type != 'LIST' ||
            streamList.end - streamList.contentStart < 4) {
          continue;
        }
        await reader.setPosition(streamList.contentStart);
        if (String.fromCharCodes(await reader.read(4)) != 'strl') continue;
        final streamHeaders = await _riffChunks(
            reader, streamList.contentStart + 4, streamList.end);
        if (streamHeaders == null) return CatCatchMediaKind.other;
        final streamHeader = streamHeaders.where((c) => c.type == 'strh');
        if (streamHeader.length != 1 ||
            streamHeader.single.end - streamHeader.single.contentStart < 56) {
          return CatCatchMediaKind.other;
        }
        await reader.setPosition(streamHeader.single.contentStart);
        final streamType = String.fromCharCodes(await reader.read(4));
        streamTypes.add(streamType);
        // Type-1 DV AVI stores interleaved audio/video in one `iavs` stream.
        if (streamType == 'vids' || streamType == 'iavs') {
          hasVideo = true;
        } else if (streamType == 'auds') {
          hasAudio = true;
        } else {
          // Auxiliary streams are allowed alongside proven video. If no
          // video exists, an unknown stream could still be visual, so the
          // container cannot safely be labeled audio.
          hasUnrecognizedTrack = true;
        }
      }
    }
    final sampledStreams = <int>{};
    for (final movie in movies) {
      final samples = await _aviSampleStreams(
          reader, movie.contentStart + 4, movie.end, streamTypes);
      if (samples == null) return CatCatchMediaKind.other;
      sampledStreams.addAll(samples);
    }
    if (hasVideo) {
      return sampledStreams.any((index) =>
              streamTypes[index] == 'vids' || streamTypes[index] == 'iavs')
          ? CatCatchMediaKind.video
          : CatCatchMediaKind.other;
    }
    if (hasUnrecognizedTrack) return CatCatchMediaKind.other;
    if (hasAudio &&
        sampledStreams.any((index) => streamTypes[index] == 'auds')) {
      return CatCatchMediaKind.audio;
    }
  } on FileSystemException {
    return CatCatchMediaKind.other;
  } finally {
    await reader?.close();
  }
  return CatCatchMediaKind.other;
}

/// Sample IDs identify their declared stream; JUNK, empty chunks and record
/// lists alone do not establish media. Walk records without reading payloads.
Future<Set<int>?> _aviSampleStreams(
    RandomAccessFile reader, int start, int end, List<String> streams,
    {int depth = 0}) async {
  if (depth > 32) return null;
  final samples = <int>{};
  var offset = start;
  while (end - offset >= 8) {
    await reader.setPosition(offset);
    final header = await reader.read(8);
    if (header.length != 8) return null;
    final size = _readLittleEndian(header, 4, 4);
    final paddedSize = size + (size & 1);
    if (paddedSize > end - offset - 8) return null;
    final type = String.fromCharCodes(header.take(4));
    if (type == 'LIST') {
      if (size < 4) return null;
      final listType = String.fromCharCodes(await reader.read(4));
      if (listType == 'rec ') {
        final nested = await _aviSampleStreams(
            reader, offset + 12, offset + 8 + size, streams,
            depth: depth + 1);
        if (nested == null) return null;
        samples.addAll(nested);
      }
    } else if (size > 0 &&
        header[0] >= 0x30 &&
        header[0] <= 0x39 &&
        header[1] >= 0x30 &&
        header[1] <= 0x39) {
      final index = (header[0] - 0x30) * 10 + header[1] - 0x30;
      if (index < streams.length) {
        final suffix = type.substring(2);
        final stream = streams[index];
        if ((stream == 'auds' && suffix == 'wb') ||
            ((stream == 'vids' || stream == 'iavs') &&
                (suffix == 'dc' || suffix == 'db'))) {
          samples.add(index);
        }
      }
    }
    offset += 8 + paddedSize;
  }
  return offset == end ? samples : null;
}

class _RiffChunk {
  final String type;
  final int contentStart;
  final int end;

  const _RiffChunk(this.type, this.contentStart, this.end);
}

/// Walk only chunk headers and skip `movi` without loading media into memory.
/// Invalid boundaries are rejected, including the RIFF word-alignment pad.
Future<List<_RiffChunk>?> _riffChunks(
    RandomAccessFile reader, int start, int end) async {
  final chunks = <_RiffChunk>[];
  var offset = start;
  while (end - offset >= 8) {
    if (chunks.length >= 4096) return null;
    await reader.setPosition(offset);
    final header = await reader.read(8);
    if (header.length != 8) return null;
    final size = _readLittleEndian(header, 4, 4);
    final paddedSize = size + (size & 1);
    if (paddedSize > end - offset - 8) return null;
    chunks.add(_RiffChunk(
        String.fromCharCodes(header.take(4)), offset + 8, offset + 8 + size));
    offset += 8 + paddedSize;
  }
  return offset == end ? chunks : null;
}

/// MPEG files can contain elementary video or a program stream with audio,
/// video, or both. Program-stream packet IDs identify their payload tracks;
/// ambiguous private streams and packet layouts are left unclassified.
Future<CatCatchMediaKind> _probeMpegKind(String path) async {
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final length = await reader.length();
    if (length < 12) return CatCatchMediaKind.other;
    final first = await reader.read(12);
    if (_hasBytes(first, const [0, 0, 1, 0xb3])) {
      final width = (first[4] << 4) | (first[5] >> 4);
      final height = ((first[5] & 0x0f) << 8) | first[6];
      if (width == 0 || height == 0) return CatCatchMediaKind.other;
      await reader.setPosition(0);
      final sample = await reader.read(length < 65536 ? length : 65536);
      return _mpegElementaryHasVideo(sample)
          ? CatCatchMediaKind.video
          : CatCatchMediaKind.other;
    }
    if (!_hasBytes(first, const [0, 0, 1, 0xba])) {
      return CatCatchMediaKind.other;
    }

    var offset = 0;
    var hasAudio = false;
    final videoPayloads = <int, List<int>>{};
    var hasPrivateStream = false;
    while (offset + 4 <= length) {
      await reader.setPosition(offset);
      final header =
          await reader.read(length - offset < 14 ? length - offset : 14);
      if (!_hasBytes(header, const [0, 0, 1])) {
        return CatCatchMediaKind.other;
      }
      final streamId = header[3];
      if (streamId == 0xb9) {
        offset += 4;
        break;
      }
      if (streamId == 0xba) {
        if (header.length < 12) return CatCatchMediaKind.other;
        final packLength = (header[4] & 0xf0) == 0x20
            ? 12 // MPEG-1 pack header.
            : (header[4] & 0xc0) == 0x40 && header.length >= 14
                ? 14 + (header[13] & 7) // MPEG-2 stuffing bytes.
                : 0;
        if (packLength == 0 || packLength > length - offset) {
          return CatCatchMediaKind.other;
        }
        offset += packLength;
        continue;
      }
      if (header.length < 6) return CatCatchMediaKind.other;
      final packetLength = (header[4] << 8) | header[5];
      // H.222.0 2.4.3.7 allows zero-length video PES only in Transport
      // Stream packets. This parser handles Program Streams.
      if (packetLength == 0 || packetLength > length - offset - 6) {
        return CatCatchMediaKind.other;
      }
      final audioPacket = streamId >= 0xc0 && streamId <= 0xdf;
      final videoPacket = streamId >= 0xe0 && streamId <= 0xef;
      if (audioPacket || videoPacket || streamId == 0xbd) {
        await reader.setPosition(offset + 6);
        final prefix =
            await reader.read(packetLength < 258 ? packetLength : 258);
        final payloadStart = _mpegPesPayloadStart(prefix, packetLength);
        if (payloadStart == null) return CatCatchMediaKind.other;
        if (payloadStart < packetLength) {
          hasAudio |= audioPacket;
          hasPrivateStream |= streamId == 0xbd;
          if (videoPacket) {
            // Keep packet continuity within each video stream, with a bounded
            // prefix just like the elementary probe. Other IDs never join it.
            final sample = videoPayloads.putIfAbsent(streamId, () => <int>[]);
            final remaining = 65536 - sample.length;
            if (remaining > 0) {
              await reader.setPosition(offset + 6 + payloadStart);
              final size = packetLength - payloadStart;
              sample.addAll(
                  await reader.read(size < remaining ? size : remaining));
            }
          }
        }
      } else if (streamId != 0xbb &&
          streamId != 0xbc &&
          streamId != 0xbe &&
          streamId != 0xbf) {
        return CatCatchMediaKind.other;
      }
      // Private stream 2 (DVD navigation) is opaque, not an audio/video PES.
      // Its packet bounds were checked above; skip it without inferring tracks.
      offset += 6 + packetLength;
    }
    if (offset != length) return CatCatchMediaKind.other;
    if (videoPayloads.values.any(_mpegElementaryHasVideo)) {
      return CatCatchMediaKind.video;
    }
    if (hasPrivateStream) return CatCatchMediaKind.other;
    if (hasAudio) return CatCatchMediaKind.audio;
  } on FileSystemException {
    return CatCatchMediaKind.other;
  } finally {
    await reader?.close();
  }
  return CatCatchMediaKind.other;
}

/// Picture and slice start codes also occur in initialization-only files.
/// Require a framed picture header followed by slice data, not header bytes.
bool _mpegElementaryHasVideo(List<int> sample) {
  var hasPicture = false;
  var offset = 0;
  while (offset + 4 <= sample.length) {
    if (!_hasBytes(sample, const [0, 0, 1], at: offset)) {
      offset++;
      continue;
    }
    var end = offset + 4;
    while (end + 4 <= sample.length &&
        !_hasBytes(sample, const [0, 0, 1], at: end)) {
      end++;
    }
    if (end + 4 > sample.length) end = sample.length;
    final code = sample[offset + 3];
    if (code == 0) {
      // temporal_reference, picture_coding_type and vbv_delay take 29 bits.
      final pictureType = end - offset >= 8 ? (sample[offset + 5] >> 3) & 7 : 0;
      hasPicture = pictureType >= 1 && pictureType <= 4;
    } else if (code == 0xb3 || code == 0xb7 || code == 0xb8) {
      hasPicture = false;
    } else if (code >= 1 && code <= 0xaf && hasPicture) {
      if (_mpegSliceHasPayload(sample, offset + 4, end)) return true;
    }
    offset = end;
  }
  return false;
}

bool _mpegSliceHasPayload(List<int> sample, int start, int end) {
  var bit = start * 8;
  int? readBits(int count) {
    if (count > end * 8 - bit) return null;
    var value = 0;
    for (var i = 0; i < count; i++, bit++) {
      value = (value << 1) | ((sample[bit >> 3] >> (7 - (bit & 7))) & 1);
    }
    return value;
  }

  final quantiserScale = readBits(5);
  if (quantiserScale == null || quantiserScale == 0) return false;
  // Consume extra_information_slice bytes so they cannot count as sample data.
  while (true) {
    final extraBit = readBits(1);
    if (extraBit == null) return false;
    if (extraBit == 0) break;
    if (readBits(8) == null) return false;
  }
  // Padding or a truncated first macroblock in the header byte proves no slice.
  return end * 8 - bit >= 8;
}

/// Locate elementary bytes after MPEG-1 or MPEG-2 PES headers. Packet length
/// alone includes timestamps and optional header data, so it proves no sample.
int? _mpegPesPayloadStart(List<int> prefix, int packetLength) {
  if (prefix.isEmpty) return null;
  bool timestampAt(int offset, int tag) =>
      offset + 5 <= prefix.length &&
      prefix[offset] >> 4 == tag &&
      (prefix[offset] & 1) == 1 &&
      (prefix[offset + 2] & 1) == 1 &&
      (prefix[offset + 4] & 1) == 1;
  if ((prefix[0] & 0xc0) == 0x80) {
    if (prefix.length < 3) return null;
    final end = 3 + prefix[2];
    if (end > packetLength) return null;
    final timestampFlags = prefix[1] >> 6;
    if (timestampFlags == 1 ||
        (timestampFlags == 2 && (prefix[2] < 5 || !timestampAt(3, 2))) ||
        (timestampFlags == 3 &&
            (prefix[2] < 10 || !timestampAt(3, 3) || !timestampAt(8, 1)))) {
      return null;
    }
    return end;
  }
  var offset = 0;
  while (offset < prefix.length && prefix[offset] == 0xff) {
    if (++offset > 16) return null;
  }
  if (offset >= prefix.length) return null;
  if ((prefix[offset] & 0xc0) == 0x40) offset += 2; // MPEG-1 STD buffer.
  if (offset >= prefix.length) return null;
  final tag = prefix[offset] >> 4;
  if (tag == 2 && timestampAt(offset, 2)) return offset + 5;
  if (tag == 3 && timestampAt(offset, 3) && timestampAt(offset + 5, 1)) {
    return offset + 10;
  }
  return prefix[offset] == 0x0f ? offset + 1 : null;
}

Future<CatCatchMediaKind> _probeFlvKind(
    String path, List<int> header, int length) async {
  if (length < 13 || header.length < 9) return CatCatchMediaKind.other;
  if (!_hasBytes(header, 'FLV'.codeUnits)) return CatCatchMediaKind.other;
  final version = header[3];
  final flags = header[4];
  if (version != 1 || (flags & ~0x05) != 0) {
    return CatCatchMediaKind.other;
  }
  final dataOffset = _readMp4Uint(header, 5, 4);
  if (dataOffset < 9 || dataOffset + 4 > length) {
    return CatCatchMediaKind.other;
  }
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    await reader.setPosition(dataOffset);
    final previousTagSize = await reader.read(4);
    if (previousTagSize.length != 4 ||
        _readMp4Uint(previousTagSize, 0, 4) != 0) {
      return CatCatchMediaKind.other;
    }
    var offset = dataOffset + 4;
    var hasAudio = false;
    var hasVideo = false;
    while (offset < length) {
      if (length - offset < 15) return CatCatchMediaKind.other;
      await reader.setPosition(offset);
      final tag = await reader.read(11);
      if (tag.length != 11) return CatCatchMediaKind.other;
      final payloadLength = _readMp4Uint(tag, 1, 3);
      if (payloadLength > length - offset - 15) {
        return CatCatchMediaKind.other;
      }
      final payloadStart = offset + 11;
      if (payloadLength > 1 &&
          ((tag[0] == 8 && (flags & 4) != 0) ||
              (tag[0] == 9 && (flags & 1) != 0))) {
        await reader.setPosition(payloadStart);
        final prefix = await reader.read(payloadLength < 9 ? payloadLength : 9);
        if (_flvTagHasMediaPayload(tag[0], prefix, payloadLength)) {
          if (tag[0] == 9) hasVideo = true;
          if (tag[0] == 8) hasAudio = true;
        }
      }
      final previousSizeOffset = payloadStart + payloadLength;
      await reader.setPosition(previousSizeOffset);
      final previousSize = await reader.read(4);
      if (previousSize.length != 4 ||
          _readMp4Uint(previousSize, 0, 4) != 11 + payloadLength) {
        return CatCatchMediaKind.other;
      }
      offset = previousSizeOffset + 4;
    }
    if (hasVideo) return CatCatchMediaKind.video;
    if (hasAudio) return CatCatchMediaKind.audio;
  } on FileSystemException {
    return CatCatchMediaKind.other;
  } finally {
    await reader?.close();
  }
  return CatCatchMediaKind.other;
}

bool _flvTagHasMediaPayload(int type, List<int> prefix, int length) {
  if (prefix.length < 2) return false;
  if (type == 8) {
    // AAC packet type 0 is the codec sequence header, not a sample.
    return (prefix[0] >> 4) != 10 || (prefix[1] == 1 && length > 2);
  }
  if (type == 9) {
    if ((prefix[0] >> 4) == 5) return false; // Video info/command, no frame.
    final codecId = prefix[0] & 0x0f;
    // AVC/legacy HEVC packet type 0 carries configuration, not a video frame.
    if (codecId == 7) return prefix[1] == 1 && length > 5;
    if (codecId == 12) {
      // Match DartFlvRemuxer's HEVC layouts: FourCC + type + CTS, or the
      // legacy type + CTS. Require coded-frame data after either header.
      final fourCcLayout = _hasBytes(prefix, 'hvc1'.codeUnits, at: 1) ||
          _hasBytes(prefix, 'hev1'.codeUnits, at: 1);
      if (fourCcLayout) {
        return prefix.length >= 6 && prefix[5] == 1 && length > 9;
      }
      return prefix[1] == 1 && length > 5;
    }
    return true;
  }
  return false;
}

CatCatchMediaKind _fromProbedTrackKind(ProbedTrackKind kind) => switch (kind) {
      ProbedTrackKind.audio => CatCatchMediaKind.audio,
      ProbedTrackKind.video => CatCatchMediaKind.video,
      ProbedTrackKind.unknown => CatCatchMediaKind.other,
    };

/// The MP4 and QuickTime file layouts share track handlers but have different
/// `ftyp` brands. Keep actual QuickTime bytes under `.mov` when saving.
Future<IsoMediaFamily> probeIsoMediaFamily(String path) async {
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final length = await reader.length();
    await for (final box in _mp4Boxes(reader, 0, length)) {
      // Older QuickTime files may have no ftyp box at all.
      if (box.type == 'moov') return IsoMediaFamily.quickTime;
      if (box.type != 'ftyp') continue;
      if (box.end - box.contentStart < 8) return IsoMediaFamily.unknown;
      await reader.setPosition(box.contentStart);
      final brand = String.fromCharCodes(await reader.read(4));
      return brand == 'qt  ' ? IsoMediaFamily.quickTime : IsoMediaFamily.mp4;
    }
  } on FileSystemException {
    return IsoMediaFamily.unknown;
  } finally {
    await reader?.close();
  }
  return IsoMediaFamily.unknown;
}

Future<CatCatchMediaKind> _probeMp4Kind(String path) async {
  RandomAccessFile? reader;
  try {
    reader = await File(path).open();
    final length = await reader.length();
    var hasMediaData = false;
    var hasAudio = false;
    var hasVideo = false;
    await for (final box in _mp4Boxes(reader, 0, length)) {
      if (box.type == 'mdat') {
        hasMediaData |= box.end > box.contentStart;
        continue;
      }
      if (box.type != 'moov') continue;
      await for (final track in _mp4Boxes(reader, box.contentStart, box.end)) {
        if (track.type != 'trak') continue;
        final mdia =
            await _firstMp4Box(reader, track.contentStart, track.end, 'mdia');
        if (mdia == null) continue;
        final handler =
            await _firstMp4Box(reader, mdia.contentStart, mdia.end, 'hdlr');
        // A handler has 4 version/flags bytes, 4 predefined bytes, then its
        // 4-byte handler type. No sample data needs to be loaded into memory.
        if (handler == null || handler.end - handler.contentStart < 12) {
          continue;
        }
        await reader.setPosition(handler.contentStart + 8);
        final type = String.fromCharCodes(await reader.read(4));
        if (type == 'vide') hasVideo = true;
        if (type == 'soun') hasAudio = true;
      }
    }
    // A DASH initialization segment contains track handlers but no samples.
    // Both a track and a nonempty media-data box are needed for a saved file.
    if (hasMediaData && hasVideo) return CatCatchMediaKind.video;
    if (hasMediaData && hasAudio) return CatCatchMediaKind.audio;
  } on FileSystemException {
    return CatCatchMediaKind.other;
  } finally {
    await reader?.close();
  }
  return CatCatchMediaKind.other;
}

class _Mp4Box {
  final String type;
  final int contentStart;
  final int end;

  const _Mp4Box(this.type, this.contentStart, this.end);
}

Future<_Mp4Box?> _firstMp4Box(
    RandomAccessFile reader, int start, int end, String type) async {
  await for (final box in _mp4Boxes(reader, start, end)) {
    if (box.type == type) return box;
  }
  return null;
}

/// Walk box headers by offset, including extended-size boxes, so a large
/// `mdat` can be skipped even when `moov` is stored after the media payload.
Stream<_Mp4Box> _mp4Boxes(RandomAccessFile reader, int start, int end) async* {
  var offset = start;
  while (end - offset >= 8) {
    await reader.setPosition(offset);
    final header = await reader.read(8);
    if (header.length != 8) return;
    var size = _readMp4Uint(header, 0, 4);
    var headerSize = 8;
    if (size == 1) {
      final extendedSize = await reader.read(8);
      if (extendedSize.length != 8) return;
      size = _readMp4Uint(extendedSize, 0, 8);
      headerSize = 16;
    } else if (size == 0) {
      size = end - offset;
    }
    if (size < headerSize || size > end - offset) return;
    yield _Mp4Box(String.fromCharCodes(header.skip(4)), offset + headerSize,
        offset + size);
    offset += size;
  }
}

int _readMp4Uint(List<int> bytes, int start, int count) {
  var value = 0;
  for (var i = 0; i < count; i++) {
    value = (value << 8) | bytes[start + i];
  }
  return value;
}
