import 'dart:typed_data';

/// WAV字节写入器（小端序）
class _WavWriter {
  final BytesBuilder _builder = BytesBuilder();

  void writeString(String s) {
    _builder.add(s.codeUnits.map((c) => c.toInt()).toList());
  }

  void writeInt32(int value) {
    _builder.addByte(value & 0xff);
    _builder.addByte((value >> 8) & 0xff);
    _builder.addByte((value >> 16) & 0xff);
    _builder.addByte((value >> 24) & 0xff);
  }

  void writeInt16(int value) {
    _builder.addByte(value & 0xff);
    _builder.addByte((value >> 8) & 0xff);
  }

  void writeBytes(Uint8List bytes) {
    _builder.add(bytes);
  }

  Uint8List toBytes() => _builder.toBytes();
}

/// 将PCM音频数据转换为WAV格式
///
/// [pcmData] 原始PCM字节数据（16位有符号，单声道）
/// [sampleRate] 采样率，默认24000Hz
/// [bitsPerSample] 位深，默认16位
/// [numChannels] 声道数，默认1（单声道）
Uint8List pcmToWav(
  Uint8List pcmData, {
  int sampleRate = 24000,
  int bitsPerSample = 16,
  int numChannels = 1,
}) {
  final dataSize = pcmData.length;
  final fileSize = 36 + dataSize;

  final writer = _WavWriter();

  // RIFF header
  writer.writeString('RIFF');
  writer.writeInt32(fileSize);
  writer.writeString('WAVE');

  // fmt chunk
  writer.writeString('fmt ');
  writer.writeInt32(16); // Subchunk1Size (16 for PCM)
  writer.writeInt16(1); // AudioFormat (1 = PCM)
  writer.writeInt16(numChannels);
  writer.writeInt32(sampleRate);
  writer.writeInt32(sampleRate * numChannels * bitsPerSample ~/ 8); // byte rate
  writer.writeInt16(numChannels * bitsPerSample ~/ 8); // block align
  writer.writeInt16(bitsPerSample);

  // data chunk
  writer.writeString('data');
  writer.writeInt32(dataSize);
  writer.writeBytes(pcmData);

  return writer.toBytes();
}

/// 获取MIME类型
String getMimeType(String format) {
  switch (format.toLowerCase()) {
    case 'wav':
      return 'audio/wav';
    case 'mp3':
      return 'audio/mpeg';
    case 'flac':
      return 'audio/flac';
    case 'pcm':
      return 'audio/L16;rate=24000;channels=1';
    default:
      return 'audio/wav';
  }
}

// ===========================================================================
// 通用音频格式检测与修复
// ===========================================================================

/// 已知音频格式的魔数字节。
/// WAV:  "RIFF"
/// MP3:  "ID3" 或 0xFFFx (MPEG sync)
/// FLAC: "fLaC"
const _MAGIC_WAV = [0x52, 0x49, 0x46, 0x46];
const _MAGIC_MP3_ID3 = [0x49, 0x44, 0x33];
const _MAGIC_FLAC = [0x66, 0x4C, 0x61, 0x43];

/// 检测音频数据的实际格式（基于文件头魔数）。
///
/// 返回小写格式名，'pcm' 表示未识别到任何已知魔数（即裸 PCM）。
String detectAudioFormat(Uint8List data) {
  if (data.length < 4) return 'pcm';

  // WAV: "RIFF"
  if (data[0] == _MAGIC_WAV[0] &&
      data[1] == _MAGIC_WAV[1] &&
      data[2] == _MAGIC_WAV[2] &&
      data[3] == _MAGIC_WAV[3]) {
    return 'wav';
  }

  // MP3: "ID3" tag
  if (data[0] == _MAGIC_MP3_ID3[0] &&
      data[1] == _MAGIC_MP3_ID3[1] &&
      data[2] == _MAGIC_MP3_ID3[2]) {
    return 'mp3';
  }

  // MP3: MPEG sync (0xFFFx)
  if (data.length >= 2 && data[0] == 0xFF && (data[1] & 0xF0) == 0xF0) {
    return 'mp3';
  }

  // FLAC: "fLaC"
  if (data[0] == _MAGIC_FLAC[0] &&
      data[1] == _MAGIC_FLAC[1] &&
      data[2] == _MAGIC_FLAC[2] &&
      data[3] == _MAGIC_FLAC[3]) {
    return 'flac';
  }

  // 无匹配 → 裸数据
  return 'pcm';
}

/// 确保音频数据具有有效的文件头，使之可被播放器识别。
///
/// 自动处理以下场景：
/// - 请求 PCM → 转为 WAV（浏览器无法播放裸 PCM）
/// - 请求 WAV 但数据无 RIFF 头（裸 PCM）→ 自动补 WAV 头
/// - 请求 MP3/FLAC 但数据实际是裸 PCM → 无法无损转换，原样返回并打警告
///
/// [data]            原始音频字节
/// [requestedFormat] 期望的格式（wav / pcm / mp3 / flac）
/// [sampleRate]      采样率，仅 PCM→WAV 转换时使用
///
/// 返回 `(转换后的数据, 实际输出格式)`。
(Uint8List, String) ensureValidAudioFormat(
  Uint8List data, {
  String requestedFormat = 'wav',
  int sampleRate = 24000,
}) {
  final fmt = requestedFormat.toLowerCase();
  final detected = detectAudioFormat(data);

  // 情况 0: 数据为空，直接返回
  if (data.isEmpty) return (data, fmt);

  // 情况 1: 魔数匹配请求格式 → 数据已经是合法格式
  if (detected == fmt) {
    // 但 PCM 是裸数据无法播放，强制转为 WAV
    if (fmt == 'pcm') {
      print('ensureValidAudioFormat: PCM→WAV 转换');
      return (pcmToWav(data, sampleRate: sampleRate), 'wav');
    }
    return (data, fmt);
  }

  // 情况 2: 数据是裸 PCM（无任何已知魔数）
  if (detected == 'pcm') {
    // 请求格式是 WAV 或 PCM → 可以直接补头
    if (fmt == 'wav' || fmt == 'pcm') {
      print('ensureValidAudioFormat: 裸PCM→WAV 转换（请求格式=$fmt）');
      return (pcmToWav(data, sampleRate: sampleRate), 'wav');
    }
    // 请求 MP3/FLAC 等压缩格式 → 无法无损转换
    print('ensureValidAudioFormat: 警告 - 无法将裸PCM转为$fmt，返回原始数据');
    return (data, fmt);
  }

  // 情况 3: 魔数是别的有效格式（如请求 pcm 但数据实际是 wav）
  // 使用实际检测到的格式，确保 MIME 类型与数据内容一致
  print('ensureValidAudioFormat: 数据为$detected格式，请求为$fmt，使用实际格式');
  return (data, detected);
}
