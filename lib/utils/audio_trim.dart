import 'dart:typed_data';

/// 默认采样率
const int defaultSampleRate = 24000;

/// 魔数字节
const _magicWav = [0x52, 0x49, 0x46, 0x46]; // "RIFF"
const _magicRifx = [0x52, 0x49, 0x46, 0x58]; // "RIFX"
const _magicMp3Id3 = [0x49, 0x44, 0x33]; // "ID3"
const _magicOgg = [0x4F, 0x67, 0x67, 0x53]; // "OggS"

/// 检测音频实际格式（基于文件头魔数）
///
/// 返回已知格式名，'pcm' 表示未识别的裸 PCM。
String _detectFormat(Uint8List data) {
  if (data.length < 4) return 'pcm';

  if ((data[0] == _magicWav[0] &&
          data[1] == _magicWav[1] &&
          data[2] == _magicWav[2] &&
          data[3] == _magicWav[3]) ||
      (data[0] == _magicRifx[0] &&
          data[1] == _magicRifx[1] &&
          data[2] == _magicRifx[2] &&
          data[3] == _magicRifx[3])) {
    return 'wav';
  }

  if (data[0] == _magicMp3Id3[0] &&
      data[1] == _magicMp3Id3[1] &&
      data[2] == _magicMp3Id3[2]) {
    return 'mp3';
  }

  if (data.length >= 2 && data[0] == 0xFF && (data[1] & 0xF0) == 0xF0) {
    return 'mp3';
  }

  if (data.length >= 4 &&
      data[0] == 0x66 &&
      data[1] == 0x4C &&
      data[2] == 0x61 &&
      data[3] == 0x43) {
    return 'flac';
  }

  if (data[0] == _magicOgg[0] &&
      data[1] == _magicOgg[1] &&
      data[2] == _magicOgg[2] &&
      data[3] == _magicOgg[3]) {
    return 'ogg';
  }

  // ISO Base Media File Format (M4A/MP4) has an "ftyp" box at offset 4.
  if (data.length >= 8 &&
      data[4] == 0x66 &&
      data[5] == 0x74 &&
      data[6] == 0x79 &&
      data[7] == 0x70) {
    return 'm4a';
  }

  return 'pcm';
}

class _PcmWav {
  const _PcmWav({
    required this.pcmData,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.blockAlign,
  });

  final Uint8List pcmData;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final int blockAlign;
}

/// Parse standard integer PCM WAV files; unsupported or malformed files are
/// left untouched by the caller.
_PcmWav? _parsePcmWav(Uint8List wavData) {
  if (wavData.length < 12 ||
      String.fromCharCodes(wavData.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(wavData.sublist(8, 12)) != 'WAVE') {
    return null;
  }

  int readU16(int offset) => wavData[offset] | (wavData[offset + 1] << 8);
  int readU32(int offset) =>
      wavData[offset] |
      (wavData[offset + 1] << 8) |
      (wavData[offset + 2] << 16) |
      (wavData[offset + 3] << 24);

  final riffEnd = 8 + readU32(4);
  if (riffEnd < 12 || riffEnd > wavData.length) return null;

  int? format;
  int? channels;
  int? sampleRate;
  int? byteRate;
  int? blockAlign;
  int? bitsPerSample;
  int? dataStart;
  int? dataSize;

  var offset = 12;
  while (offset + 8 <= riffEnd) {
    final chunkId = String.fromCharCodes(wavData.sublist(offset, offset + 4));
    final chunkSize = readU32(offset + 4);
    final chunkStart = offset + 8;
    final chunkEnd = chunkStart + chunkSize;
    if (chunkEnd > riffEnd) return null;

    if (chunkId == 'fmt ') {
      if (format != null || chunkSize < 16) return null;
      format = readU16(chunkStart);
      channels = readU16(chunkStart + 2);
      sampleRate = readU32(chunkStart + 4);
      byteRate = readU32(chunkStart + 8);
      blockAlign = readU16(chunkStart + 12);
      bitsPerSample = readU16(chunkStart + 14);
    } else if (chunkId == 'data') {
      if (dataStart != null) return null;
      dataStart = chunkStart;
      dataSize = chunkSize;
    }

    offset = chunkEnd + (chunkSize.isOdd ? 1 : 0);
    if (offset > riffEnd) return null;
  }

  if (offset != riffEnd ||
      format != 1 ||
      channels == null ||
      channels <= 0 ||
      sampleRate == null ||
      sampleRate <= 0 ||
      byteRate == null ||
      blockAlign == null ||
      bitsPerSample == null ||
      dataStart == null ||
      dataSize == null ||
      ![8, 16, 24, 32].contains(bitsPerSample)) {
    return null;
  }

  final expectedBlockAlign = channels * (bitsPerSample ~/ 8);
  if (blockAlign != expectedBlockAlign ||
      byteRate != sampleRate * blockAlign ||
      dataSize % blockAlign != 0) {
    return null;
  }

  return _PcmWav(
    pcmData: wavData.sublist(dataStart, dataStart + dataSize),
    sampleRate: sampleRate,
    channels: channels,
    bitsPerSample: bitsPerSample,
    blockAlign: blockAlign,
  );
}

/// 将 PCM 数据包装为 WAV 格式，并保留源文件的 PCM 格式元数据。
Uint8List _pcmToWav(Uint8List pcmData, _PcmWav format) {
  final dataSize = pcmData.length;
  final fileSize = 36 + dataSize + (dataSize.isOdd ? 1 : 0);
  final byteRate = format.sampleRate * format.blockAlign;

  final writer = BytesBuilder();

  void writeU16(int v) {
    writer.addByte(v & 0xff);
    writer.addByte((v >> 8) & 0xff);
  }

  void writeU32(int v) {
    writer.addByte(v & 0xff);
    writer.addByte((v >> 8) & 0xff);
    writer.addByte((v >> 16) & 0xff);
    writer.addByte((v >> 24) & 0xff);
  }

  // RIFF header
  writer.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
  writeU32(fileSize);
  writer.add([0x57, 0x41, 0x56, 0x45]); // "WAVE"

  // fmt 子块
  writer.add([0x66, 0x6D, 0x74, 0x20]); // "fmt "
  writeU32(16); // Subchunk1Size (PCM)
  writeU16(1); // AudioFormat (1 = PCM)
  writeU16(format.channels);
  writeU32(format.sampleRate);
  writeU32(byteRate);
  writeU16(format.blockAlign);
  writeU16(format.bitsPerSample);

  // data 子块
  writer.add([0x64, 0x61, 0x74, 0x61]); // "data"
  writeU32(dataSize);
  writer.add(pcmData);
  if (dataSize.isOdd) writer.addByte(0);

  return writer.toBytes();
}

/// 从音频中裁切指定长度的头部或尾部
///
/// [audioBytes] 原始音频数据
/// [preset] 裁切预设，包含: durationSeconds(裁切时长), direction('head'/'tail')
/// [sampleRate] 采样率，仅 WAV 重建时使用，默认 24000
Uint8List trimAudio(
  Uint8List audioBytes, {
  required Map<String, dynamic> preset,
  int sampleRate = defaultSampleRate,
}) {
  if (audioBytes.isEmpty) return audioBytes;

  final durationSeconds = (preset['durationSeconds'] as num).toDouble();
  final direction = preset['direction'] as String? ?? 'head';

  // 时长为 0 或负数，不裁切
  if (durationSeconds <= 0) {
    return audioBytes;
  }

  // 自动检测格式
  final fmt = _detectFormat(audioBytes);

  // Compressed formats cannot be trimmed as raw PCM; preserve their bytes.
  if (fmt != 'wav' && fmt != 'pcm') {
    return audioBytes;
  }

  // ----- 根据格式执行裁切 -----

  if (fmt == 'pcm') {
    // 裸 PCM：直接 sublist (默认每样本 16-bit)
    final samplesToDiscard = (durationSeconds * sampleRate).round();
    final trimBytes = samplesToDiscard * 2;
    if (trimBytes <= 0) return audioBytes;

    if (trimBytes >= audioBytes.length) return audioBytes;
    if (direction == 'head') {
      return audioBytes.sublist(trimBytes);
    } else {
      // tail: 保留开头到结尾减去 trimBytes
      return audioBytes.sublist(0, audioBytes.length - trimBytes);
    }
  }

  // fmt == 'wav'：按文件中的 PCM 格式裁切并重建匹配的 WAV 头。
  final wav = _parsePcmWav(audioBytes);
  if (wav == null) return audioBytes;

  final framesToDiscard = (durationSeconds * wav.sampleRate).round();
  final trimBytes = framesToDiscard * wav.blockAlign;
  if (trimBytes <= 0) return audioBytes;

  if (trimBytes >= wav.pcmData.length) {
    // PCM 太短，返回原始 WAV
    return audioBytes;
  }

  Uint8List trimmedPcm;
  if (direction == 'head') {
    trimmedPcm = wav.pcmData.sublist(trimBytes);
  } else {
    trimmedPcm = wav.pcmData.sublist(0, wav.pcmData.length - trimBytes);
  }

  return _pcmToWav(trimmedPcm, wav);
}

/// 创建包装流并裁切音频头部/尾部的生成器
///
/// [stream] 原始音频数据块流
/// [preset] 裁切预设
/// [sampleRate] 采样率
/// [bytesPerSample] 每个样本的字节数（16位PCM为2）
Stream<Uint8List> createStreamTrimmingWrapper(
  Stream<Uint8List> stream, {
  required Map<String, dynamic> preset,
  int sampleRate = defaultSampleRate,
  int bytesPerSample = 2,
}) async* {
  final durationSeconds = (preset['durationSeconds'] as num).toDouble();
  final direction = preset['direction'] as String? ?? 'head';

  // 时长为 0，直接透传
  if (durationSeconds <= 0) {
    yield* stream;
    return;
  }

  final trimBytes = (durationSeconds * sampleRate).round() * bytesPerSample;
  var buffer = <int>[];
  var totalBuffered = 0;
  var trimmingDone = false;

  if (direction == 'head') {
    await for (final chunk in stream) {
      if (!trimmingDone) {
        buffer.addAll(chunk);
        totalBuffered += chunk.length;

        if (totalBuffered > trimBytes) {
          final trimmed = Uint8List.fromList(buffer.sublist(trimBytes));
          trimmingDone = true;
          buffer.clear();
          if (trimmed.isNotEmpty) {
            yield trimmed;
          }
        }
      } else {
        yield chunk;
      }
    }

    // 如果流结束但修剪未完成，输出剩余缓冲区（未修剪）
    if (!trimmingDone && buffer.isNotEmpty) {
      yield Uint8List.fromList(buffer);
    }
  } else {
    // tail 模式：缓冲所有数据，最后裁掉尾部
    await for (final chunk in stream) {
      buffer.addAll(chunk);
    }

    if (buffer.length > trimBytes) {
      yield Uint8List.fromList(buffer.sublist(0, buffer.length - trimBytes));
    } else {
      yield Uint8List.fromList(buffer);
    }
  }
}
