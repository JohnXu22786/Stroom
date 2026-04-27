import 'dart:typed_data';
import 'dart:math' show sqrt;
import '../providers/tts_config.dart';

/// GLM-TTS固定修剪点（单位：秒）
const double glmCutPoint = 0.629333;

/// GLM-TTS蜂鸣声结束后的额外修剪点（单位：秒）
const double glmBuzzerCutPoint = 1.829333;

/// 默认采样率
const int defaultSampleRate = 24000;

/// WAV 标准 PCM 头长度
const int _wavHeaderSize = 44;

/// 魔数字节
const _magicWav = [0x52, 0x49, 0x46, 0x46]; // "RIFF"
const _magicMp3Id3 = [0x49, 0x44, 0x33];    // "ID3"

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
      data[0] == 0x66 && data[1] == 0x4C &&
      data[2] == 0x61 && data[3] == 0x43) {
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
  writeU32(16);          // Subchunk1Size (PCM)
  writeU16(1);           // AudioFormat (1 = PCM)
  writeU16(1);           // NumChannels (单声道)
  writeU32(sampleRate);
  writeU32(sampleRate * 2); // ByteRate
  writeU16(2);           // BlockAlign
  writeU16(16);          // BitsPerSample

  // data 子块
  writer.add([0x64, 0x61, 0x74, 0x61]); // "data"
  writeU32(dataSize);
  writer.add(pcmData);

  return writer.toBytes();
}

/// 需要丢弃的字节数（基于默认采样率和16位PCM）
int get bytesToDiscard =>
    (glmCutPoint * defaultSampleRate).round() * 2; // 16位PCM = 2字节/样本

/// 检测音频是否来自GLM-TTS（通过分析开头是否有蜂鸣声）
///
/// [audioBytes] 音频数据字节
/// [sampleRate] 采样率，默认24000Hz
bool isGlmAudio(Uint8List audioBytes, {int sampleRate = defaultSampleRate}) {
  // 需要至少0.5秒的数据进行分析
  final minSamples = (sampleRate * 0.5).round();
  final bytesPerSample = 2; // 16位PCM

  if (audioBytes.length < minSamples * bytesPerSample) {
    return false;
  }

  // 如果数据有 WAV 头，先剥离
  final pcm = _detectFormat(audioBytes) == 'wav'
      ? _extractPcmFromWav(audioBytes)
      : audioBytes;
  if (pcm.length < minSamples * bytesPerSample) {
    return false;
  }

  // 分析前0.5秒的能量变化
  // GLM-TTS蜂鸣声具有脉冲特性，能量方差较大
  final sampleCount = minSamples;
  final samples = Int16List.view(pcm.buffer, 0, sampleCount);

  // 计算均方根（RMS）能量
  double sumSquares = 0;
  for (int i = 0; i < sampleCount; i++) {
    sumSquares += samples[i] * samples[i];
  }
  final rms = sqrt(sumSquares / sampleCount);

  // 计算零交叉率（蜂鸣声具有规律性）
  int zeroCrossings = 0;
  for (int i = 1; i < sampleCount; i++) {
    if ((samples[i - 1] >= 0 && samples[i] < 0) ||
        (samples[i - 1] < 0 && samples[i] >= 0)) {
      zeroCrossings++;
    }
  }
  final zcr = zeroCrossings / sampleCount;

  // GLM-TTS蜂鸣声特征：较高的RMS和规律性的零交叉率
  // 阈值基于经验值
  return rms > 500 && zcr > 0.05 && zcr < 0.3;
}

/// 从GLM-TTS音频中修剪开头固定时长。
///
/// 自动检测音频格式（WAV / PCM / MP3 / FLAC）：
/// - PCM：直接按字节裁切
/// - WAV：剥离 RIFF 头 → 裁切 PCM → 重写 WAV 头
/// - MP3 / FLAC：跳过裁切（压缩格式无法安全裁切）
///
/// [audioBytes] 原始音频数据
/// [sampleRate] 采样率，仅 WAV 重建时使用，默认 24000
/// [trimMode] 裁切模式
/// [force] 是否跳过 isGlmAudio 检测（已确认为 GLM 音频时设为 true）
Uint8List trimGlmAudio(
  Uint8List audioBytes, {
  int sampleRate = defaultSampleRate,
  GlmTrimMode trimMode = GlmTrimMode.beep,
  bool force = false,
}) {
  if (audioBytes.isEmpty) return audioBytes;

  // none模式跳过修剪
  if (trimMode == GlmTrimMode.none) {
    return audioBytes;
  }

  // 自动检测格式
  final fmt = _detectFormat(audioBytes);

  // 压缩格式（mp3/flac）跳过裁切
  if (fmt != 'wav' && fmt != 'pcm') {
    return audioBytes;
  }

  // 选择修剪点
  final cutPoint =
      trimMode == GlmTrimMode.buzzer ? glmBuzzerCutPoint : glmCutPoint;

  // 安全检查：跳过非GLM音频（除非强制裁切）
  if (!force && cutPoint > 0 && !isGlmAudio(audioBytes, sampleRate: sampleRate)) {
    return audioBytes;
  }

  // 计算需要修剪的样本数和字节数
  final samplesToDiscard = (cutPoint * sampleRate).round();
  final trimBytes = samplesToDiscard * 2; // 16位PCM = 2字节/样本

  // ----- 根据格式执行裁切 -----

  if (fmt == 'pcm') {
    // 裸 PCM：直接 sublist
    if (trimBytes >= audioBytes.length) {
      return audioBytes;
    }
    return audioBytes.sublist(trimBytes);
  }

  // fmt == 'wav'：剥离头 → 裁切 PCM → 重建 WAV 头
  final pcmData = _extractPcmFromWav(audioBytes);

  if (trimBytes >= pcmData.length) {
    // PCM 太短，返回原始 WAV
    return audioBytes;
  }

  final trimmedPcm = pcmData.sublist(trimBytes);
  return _pcmToWav(trimmedPcm, sampleRate);
}

/// 创建包装流并修剪初始GLM-TTS蜂鸣声的生成器
///
/// [stream] 原始音频数据块流
/// [sampleRate] 采样率
/// [bytesPerSample] 每个样本的字节数（16位PCM为2）
/// [trimMode] 修剪模式
Stream<Uint8List> createStreamTrimmingWrapper(
  Stream<Uint8List> stream, {
  int sampleRate = defaultSampleRate,
  int bytesPerSample = 2,
  GlmTrimMode trimMode = GlmTrimMode.beep,
}) async* {
  // none模式直接透传
  if (trimMode == GlmTrimMode.none) {
    yield* stream;
    return;
  }

  final cutPoint =
      trimMode == GlmTrimMode.buzzer ? glmBuzzerCutPoint : glmCutPoint;
  final trimBytes = (cutPoint * sampleRate).round() * bytesPerSample;
  var buffer = <int>[];
  var totalBuffered = 0;
  var trimmingDone = false;

  await for (final chunk in stream) {
    if (!trimmingDone) {
      buffer.addAll(chunk);
      totalBuffered += chunk.length;

      if (totalBuffered > trimBytes) {
        // 丢弃初始字节，输出剩余部分
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
}
