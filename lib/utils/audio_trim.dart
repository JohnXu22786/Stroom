import 'dart:typed_data';
import 'dart:math' show sqrt;

/// GLM-TTS固定修剪点（单位：秒）
const double glmCutPoint = 0.629333;

/// 默认采样率
const int defaultSampleRate = 24000;

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

  // 分析前0.5秒的能量变化
  // GLM-TTS蜂鸣声具有脉冲特性，能量方差较大
  final sampleCount = minSamples;
  final samples = Int16List.view(audioBytes.buffer, 0, sampleCount);

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

/// 从GLM-TTS音频中修剪前[glmCutPoint]秒
///
/// [audioBytes] 原始音频字节数据
/// [sampleRate] 采样率
/// [force] 是否强制修剪（跳过检测）
Uint8List trimGlmAudio(
  Uint8List audioBytes, {
  int sampleRate = defaultSampleRate,
  bool force = false,
}) {
  if (audioBytes.isEmpty) return audioBytes;

  // 检测是否为GLM音频（除非force=true）
  if (!force && !isGlmAudio(audioBytes, sampleRate: sampleRate)) {
    return audioBytes;
  }

  // 计算需要修剪的样本数和字节数
  final samplesToDiscard = (glmCutPoint * sampleRate).round();
  final trimBytes = samplesToDiscard * 2; // 16位PCM = 2字节/样本

  if (trimBytes >= audioBytes.length) {
    // 音频太短，跳过修剪
    return audioBytes;
  }

  // 返回修剪后的音频
  return audioBytes.sublist(trimBytes);
}

/// 创建包装流并修剪初始GLM-TTS蜂鸣声的生成器
///
/// [stream] 原始音频数据块流
/// [sampleRate] 采样率
/// [bytesPerSample] 每个样本的字节数（16位PCM为2）
Stream<Uint8List> createStreamTrimmingWrapper(
  Stream<Uint8List> stream, {
  int sampleRate = defaultSampleRate,
  int bytesPerSample = 2,
}) async* {
  final trimBytes = (glmCutPoint * sampleRate).round() * bytesPerSample;
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
