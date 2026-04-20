import 'dart:async';
import 'dart:typed_data';

/// 音频格式枚举
enum AudioFormat {
  pcm('pcm'),
  wav('wav'),
  mp3('mp3'),
  flac('flac');

  const AudioFormat(this.value);
  final String value;

  /// 从字符串值获取AudioFormat枚举
  static AudioFormat? fromValue(String value) {
    for (final format in AudioFormat.values) {
      if (format.value == value.toLowerCase()) {
        return format;
      }
    }
    return null;
  }
}

/// 音频处理工具类
///
/// 提供音频格式转换、修剪、数据对齐等实用功能。
/// 参考Python版本实现，适配Dart/Flutter环境。
class AudioUtils {
  // 防止实例化
  AudioUtils._();

  /// GLM-TTS音频修剪常量
  ///
  /// GLM-TTS生成的音频开头包含约0.629秒的蜂鸣声需要移除
  static const double glmCutPoint = 0.629333; // 629.333毫秒
  static const int defaultSampleRate = 24000; // 默认采样率
  static const int defaultBitsPerSample = 16; // 默认位深度
  static const int defaultNumChannels = 1; // 默认声道数（单声道）

  /// 将PCM音频数据转换为WAV格式
  ///
  /// [pcmData] PCM音频数据
  /// [sampleRate] 采样率，默认24000Hz
  /// [bitsPerSample] 位深度，默认16位
  /// [numChannels] 声道数，默认1（单声道）
  ///
  /// 返回WAV格式的音频数据
  ///
  /// 注意：此实现创建标准的WAV文件头，支持16位单声道PCM数据
  static Uint8List pcmToWav(
    Uint8List pcmData, {
    int sampleRate = defaultSampleRate,
    int bitsPerSample = defaultBitsPerSample,
    int numChannels = defaultNumChannels,
  }) {
    // 计算WAV文件大小
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;

    // 创建WAV文件头
    final header = ByteData(44);

    // RIFF头
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt子块
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6d); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // fmt块大小
    header.setUint16(20, 1, Endian.little); // 音频格式（PCM）
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);

    // 字节率 = 采样率 * 声道数 * 位深度/8
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    header.setUint32(28, byteRate, Endian.little);

    // 块对齐 = 声道数 * 位深度/8
    final int blockAlign = numChannels * bitsPerSample ~/ 8;
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data子块
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    // 合并头数据和PCM数据
    final result = Uint8List(44 + dataSize);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, pcmData);

    return result;
  }

  /// 修剪GLM-TTS音频（移除初始蜂鸣声）
  ///
  /// [audioBytes] 原始音频数据
  /// [sampleRate] 采样率，默认24000Hz
  /// [force] 是否强制修剪（即使检测不到蜂鸣声）
  ///
  /// 返回修剪后的音频数据
  ///
  /// 注意：GLM-TTS生成的音频开头包含约0.629秒的蜂鸣声
  /// 此函数会尝试检测并移除这部分数据
  static Uint8List trimGlmAudio(
    Uint8List audioBytes, {
    int sampleRate = defaultSampleRate,
    bool force = false,
  }) {
    if (audioBytes.isEmpty) {
      return Uint8List(0);
    }

    // 计算需要修剪的字节数
    // 16位PCM：2字节/样本，单声道：1声道
    final bytesPerSecond = sampleRate * 2; // 2字节/样本
    final bytesToCut = (glmCutPoint * bytesPerSecond).round();

    // 确保不会修剪超过音频长度
    if (bytesToCut >= audioBytes.length) {
      return Uint8List(0);
    }

    // 检查是否需要强制修剪或检测到蜂鸣声
    if (force || _detectGlmBeep(audioBytes, bytesToCut)) {
      // 修剪开头的字节
      return audioBytes.sublist(bytesToCut);
    }

    // 未检测到蜂鸣声且未强制修剪，返回原始数据
    return audioBytes;
  }

  /// 检测GLM-TTS蜂鸣声
  ///
  /// [audioBytes] 音频数据
  /// [checkLength] 检查的字节数（通常是要修剪的长度）
  ///
  /// 返回是否检测到典型的GLM蜂鸣声模式
  ///
  /// 注意：这是一个简化的检测方法，实际实现可能需要更复杂的音频分析
  static bool _detectGlmBeep(Uint8List audioBytes, int checkLength) {
    if (audioBytes.length < checkLength) {
      return false;
    }

    // 简化的检测逻辑：检查前checkLength字节的平均振幅
    // 在实际实现中，可能需要更复杂的音频特征分析
    final checkData = audioBytes.sublist(0, checkLength);

    // 对于16位PCM，计算平均振幅
    if (checkData.length >= 2) {
      double sumAmplitude = 0;
      int sampleCount = 0;

      // 每2个字节作为一个16位样本
      for (int i = 0; i < checkData.length - 1; i += 2) {
        final int sample = (checkData[i + 1] << 8) | checkData[i];
        // 将16位有符号转换为绝对值
        final int amplitude = sample.abs();
        sumAmplitude += amplitude.toDouble();
        sampleCount++;
      }

      if (sampleCount > 0) {
        final double avgAmplitude = sumAmplitude / sampleCount;
        // 如果平均振幅较高，可能包含蜂鸣声
        // 32768是16位有符号的最大振幅
        return avgAmplitude > 10000; // 经验阈值
      }
    }

    return false;
  }

  /// 创建流式修剪包装器
  ///
  /// [stream] 原始音频数据流
  /// [sampleRate] 采样率，默认24000Hz
  /// [bytesPerSample] 每个样本的字节数，默认2（16位PCM）
  ///
  /// 返回包装后的流，会自动移除初始蜂鸣声
  ///
  /// 注意：用于实时流式处理中修剪GLM-TTS蜂鸣声
  static Stream<Uint8List> createStreamTrimmingWrapper(
    Stream<Uint8List> stream, {
    int sampleRate = defaultSampleRate,
    int bytesPerSample = 2,
  }) async* {
    // 计算需要丢弃的字节数
    final bytesPerSecond = sampleRate * bytesPerSample;
    final bytesToDiscard = (glmCutPoint * bytesPerSecond).round();

    var buffer = <int>[];
    var bytesDiscarded = 0;
    var trimmingDone = false;

    await for (final chunk in stream) {
      if (!trimmingDone) {
        // 积累数据直到达到要丢弃的字节数
        buffer.addAll(chunk);
        bytesDiscarded += chunk.length;

        if (bytesDiscarded >= bytesToDiscard) {
          // 计算缓冲区中需要保留的部分
          final bytesToKeep = bytesDiscarded - bytesToDiscard;
          final startIndex = buffer.length - bytesToKeep;

          if (startIndex < buffer.length && startIndex >= 0) {
            // 输出保留的数据
            yield Uint8List.fromList(buffer.sublist(startIndex));
          }

          // 重置状态
          buffer.clear();
          trimmingDone = true;
        }
      } else {
        // 修剪已完成，直接传递数据
        yield chunk;
      }
    }

    // 如果修剪未完成但流已结束，输出剩余数据
    if (!trimmingDone && buffer.isNotEmpty) {
      yield Uint8List.fromList(buffer);
    }
  }

  /// 检查并修复PCM数据块对齐
  ///
  /// [chunk] 音频数据块
  /// [bytesPerSample] 每个样本的字节数，默认2（16位PCM）
  ///
  /// 返回对齐后的数据块
  ///
  /// 注意：16位PCM需要2字节对齐，此函数会检查并添加填充字节
  static Uint8List alignPcmChunk(
    Uint8List chunk, {
    int bytesPerSample = 2,
  }) {
    if (chunk.isEmpty) {
      return chunk;
    }

    final int remainder = chunk.length % bytesPerSample;
    if (remainder == 0) {
      return chunk;
    }

    // 数据块不对齐，添加填充字节
    final int padding = bytesPerSample - remainder;
    final alignedChunk = Uint8List(chunk.length + padding);
    alignedChunk.setAll(0, chunk);

    // 填充0字节
    for (int i = chunk.length; i < alignedChunk.length; i++) {
      alignedChunk[i] = 0;
    }

    return alignedChunk;
  }

  /// 检查数据块是否对齐
  ///
  /// [chunk] 音频数据块
  /// [bytesPerSample] 每个样本的字节数，默认2（16位PCM）
  ///
  /// 返回数据块是否对齐
  static bool isChunkAligned(
    Uint8List chunk, {
    int bytesPerSample = 2,
  }) {
    return chunk.isEmpty || chunk.length % bytesPerSample == 0;
  }

  /// 将音频数据转换为目标格式
  ///
  /// [pcmData] PCM音频数据
  /// [targetFormat] 目标格式（支持：'wav'）
  /// [sampleRate] 采样率，默认24000Hz
  /// [bitsPerSample] 位深度，默认16位
  /// [numChannels] 声道数，默认1
  ///
  /// 返回转换后的音频数据
  ///
  /// 注意：目前仅支持WAV格式转换，其他格式需要集成第三方库
  static Uint8List convertAudioFormat({
    required Uint8List pcmData,
    required String targetFormat,
    int sampleRate = defaultSampleRate,
    int bitsPerSample = defaultBitsPerSample,
    int numChannels = defaultNumChannels,
  }) {
    final format = targetFormat.toLowerCase();

    switch (format) {
      case 'wav':
        return pcmToWav(
          pcmData,
          sampleRate: sampleRate,
          bitsPerSample: bitsPerSample,
          numChannels: numChannels,
        );
      case 'pcm':
        // PCM格式不需要转换
        return pcmData;
      case 'mp3':
      case 'flac':
      default:
        // 其他格式需要外部库支持
        // 这里抛出异常，实际使用时可以集成audio package
        throw UnsupportedError(
          '音频格式转换不支持: $targetFormat。'
          '需要集成音频处理库（如just_audio、audioplayers等）。',
        );
    }
  }

  /// 计算音频时长（秒）
  ///
  /// [audioBytes] 音频数据
  /// [sampleRate] 采样率，默认24000Hz
  /// [bytesPerSample] 每个样本的字节数，默认2（16位PCM）
  /// [numChannels] 声道数，默认1
  ///
  /// 返回音频时长（秒）
  static double calculateAudioDuration(
    Uint8List audioBytes, {
    int sampleRate = defaultSampleRate,
    int bytesPerSample = 2,
    int numChannels = 1,
  }) {
    if (audioBytes.isEmpty) {
      return 0.0;
    }

    // 总样本数 = 总字节数 / (字节数/样本 * 声道数)
    final totalSamples = audioBytes.length / (bytesPerSample * numChannels);

    // 时长 = 总样本数 / 采样率
    return totalSamples / sampleRate;
  }

  /// 合并多个音频数据块
  ///
  /// [chunks] 音频数据块列表
  ///
  /// 返回合并后的音频数据
  static Uint8List mergeAudioChunks(List<Uint8List> chunks) {
    if (chunks.isEmpty) {
      return Uint8List(0);
    }

    if (chunks.length == 1) {
      return chunks[0];
    }

    // 计算总长度
    int totalLength = 0;
    for (final chunk in chunks) {
      totalLength += chunk.length;
    }

    // 合并数据
    final result = Uint8List(totalLength);
    int offset = 0;
    for (final chunk in chunks) {
      result.setAll(offset, chunk);
      offset += chunk.length;
    }

    return result;
  }

  /// 分割音频数据为固定大小的块
  ///
  /// [audioData] 音频数据
  /// [chunkSize] 块大小（字节）
  ///
  /// 返回分割后的数据块列表
  static List<Uint8List> splitAudioIntoChunks(
    Uint8List audioData,
    int chunkSize,
  ) {
    if (chunkSize <= 0 || audioData.isEmpty) {
      return [];
    }

    final chunks = <Uint8List>[];
    for (int i = 0; i < audioData.length; i += chunkSize) {
      final end = i + chunkSize < audioData.length ? i + chunkSize : audioData.length;
      chunks.add(audioData.sublist(i, end));
    }

    return chunks;
  }



  /// 音频格式信息
  static const Map<String, Map<String, dynamic>> audioFormatInfo = {
    'pcm': {
      'extension': 'pcm',
      'mimeType': 'audio/pcm',
      'description': '原始PCM音频数据',
    },
    'wav': {
      'extension': 'wav',
      'mimeType': 'audio/wav',
      'description': 'WAV音频格式',
    },
    'mp3': {
      'extension': 'mp3',
      'mimeType': 'audio/mpeg',
      'description': 'MP3音频格式',
    },
    'flac': {
      'extension': 'flac',
      'mimeType': 'audio/flac',
      'description': 'FLAC音频格式',
    },
  };

  /// 获取音频格式信息
  ///
  /// [format] 音频格式字符串
  ///
  /// 返回格式信息，如果格式不支持则返回null
  static Map<String, dynamic>? getAudioFormatInfo(String format) {
    final info = audioFormatInfo[format.toLowerCase()];
    return info != null ? Map<String, dynamic>.from(info) : null;
  }
}
