import 'dart:typed_data';

/// 默认采样率
const int defaultSampleRate = 24000;

/// WAV 标准 PCM 头长度
const int _wavHeaderSize = 44;

/// 魔数字节
const _magicWav = [0x52, 0x49, 0x46, 0x46]; // "RIFF"
const _magicMp3Id3 = [0x49, 0x44, 0x33]; // "ID3"

/// 检测音频实际格式（基于文件头魔数）
///
/// 返回 'wav' | 'mp3' | 'flac' | 'pcm'
String _detectFormat(Uint8List data) {
  if (data.length < 4) return 'pcm';

  if (data[0] == _magicWav[0] &&
      data[1] == _magicWav[1] &&
      data[2] == _magicWav[2] &&
      data[3] == _magicWav[3]) {
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

  return 'pcm';
}

/// 从 WAV 数据中提取裸 PCM 数据
///
/// 解析 RIFF/WAVE 结构找到 "data" chunk，返回 chunk 内的 PCM 字节。
/// 如果解析失败（非标准结构），则默认跳过前 44 字节。
Uint8List _extractPcmFromWav(Uint8List wavData) {
  if (wavData.length < _wavHeaderSize) return wavData;

  // 从 byte 12 开始扫描子块
  int offset = 12;
  while (offset + 8 <= wavData.length) {
    final chunkId = String.fromCharCodes(wavData.sublist(offset, offset + 4));
    final chunkSize = (wavData[offset + 4] & 0xff) |
        ((wavData[offset + 5] & 0xff) << 8) |
        ((wavData[offset + 6] & 0xff) << 16) |
        ((wavData[offset + 7] & 0xff) << 24);

    if (chunkId == 'data') {
      final dataStart = offset + 8;
      final dataEnd = dataStart + chunkSize;
      if (dataEnd > wavData.length) {
        // 声明的 size 超出实际长度，取剩余全部
        return wavData.sublist(dataStart);
      }
      return wavData.sublist(dataStart, dataEnd);
    }

    offset += 8 + chunkSize;
    // 对齐到偶数边界
    if (offset % 2 != 0) offset++;
  }

  // 没找到 data chunk，回退：跳过前 44 字节
  return wavData.length > _wavHeaderSize
      ? wavData.sublist(_wavHeaderSize)
      : Uint8List(0);
}

/// 将 PCM 数据包装为 WAV 格式（小端序 16-bit 单声道）
Uint8List _pcmToWav(Uint8List pcmData, int sampleRate) {
  final dataSize = pcmData.length;
  final fileSize = 36 + dataSize;

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
  writeU16(1); // NumChannels (单声道)
  writeU32(sampleRate);
  writeU32(sampleRate * 2); // ByteRate
  writeU16(2); // BlockAlign
  writeU16(16); // BitsPerSample

  // data 子块
  writer.add([0x64, 0x61, 0x74, 0x61]); // "data"
  writeU32(dataSize);
  writer.add(pcmData);

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

  // 压缩格式（mp3/flac）跳过裁切
  if (fmt != 'wav' && fmt != 'pcm') {
    return audioBytes;
  }

  // 计算需要裁切的字节数 (16位PCM = 2字节/样本)
  final samplesToDiscard = (durationSeconds * sampleRate).round();
  final trimBytes = samplesToDiscard * 2;

  if (trimBytes <= 0) return audioBytes;

  // ----- 根据格式执行裁切 -----

  if (fmt == 'pcm') {
    // 裸 PCM：直接 sublist
    if (trimBytes >= audioBytes.length) return audioBytes;
    if (direction == 'head') {
      return audioBytes.sublist(trimBytes);
    } else {
      // tail: 保留开头到结尾减去 trimBytes
      return audioBytes.sublist(0, audioBytes.length - trimBytes);
    }
  }

  // fmt == 'wav'：剥离头 → 裁切 PCM → 重建 WAV 头
  final pcmData = _extractPcmFromWav(audioBytes);

  if (trimBytes >= pcmData.length) {
    // PCM 太短，返回原始 WAV
    return audioBytes;
  }

  Uint8List trimmedPcm;
  if (direction == 'head') {
    trimmedPcm = pcmData.sublist(trimBytes);
  } else {
    trimmedPcm = pcmData.sublist(0, pcmData.length - trimBytes);
  }

  return _pcmToWav(trimmedPcm, sampleRate);
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
