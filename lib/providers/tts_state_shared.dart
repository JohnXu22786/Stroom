import '../utils/file_manifest.dart';

/// 合成配置状态
class SynthesisConfig {
  final String voice;
  final double speed;
  final double volume;
  final String format;

  const SynthesisConfig({
    this.voice = 'female',
    this.speed = 1.0,
    this.volume = 1.0,
    this.format = 'wav',
  });

  SynthesisConfig copyWith({
    String? voice,
    double? speed,
    double? volume,
    String? format,
  }) {
    return SynthesisConfig(
      voice: voice ?? this.voice,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      format: format ?? this.format,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'voice': voice,
      'speed': speed,
      'volume': volume,
      'format': format,
    };
  }

  factory SynthesisConfig.fromMap(Map<String, dynamic> map) {
    return SynthesisConfig(
      voice: map['voice'] ?? 'female',
      speed: (map['speed'] ?? 1.0).toDouble(),
      volume: (map['volume'] ?? 1.0).toDouble(),
      format: map['format'] ?? 'wav',
    );
  }
}

/// TTS 合成状态
class TTSState {
  final bool isSynthesizing;
  final bool isStreaming;
  final double progress;
  final String? currentText;
  final String? error;
  final AudioRecord? lastGeneratedAudio;

  const TTSState({
    this.isSynthesizing = false,
    this.isStreaming = false,
    this.progress = 0,
    this.currentText,
    this.error,
    this.lastGeneratedAudio,
  });

  TTSState copyWith({
    bool? isSynthesizing,
    bool? isStreaming,
    double? progress,
    String? currentText,
    String? error,
    AudioRecord? lastGeneratedAudio,
  }) {
    return TTSState(
      isSynthesizing: isSynthesizing ?? this.isSynthesizing,
      isStreaming: isStreaming ?? this.isStreaming,
      progress: progress ?? this.progress,
      currentText: currentText ?? this.currentText,
      error: error ?? this.error,
      lastGeneratedAudio: lastGeneratedAudio ?? this.lastGeneratedAudio,
    );
  }
}
