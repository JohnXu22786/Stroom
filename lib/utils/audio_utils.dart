import 'dart:typed_data';
import 'dart:math';

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
