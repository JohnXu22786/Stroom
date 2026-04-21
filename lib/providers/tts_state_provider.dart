import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'tts_config.dart' as tts_config;
import 'tts_provider.dart' as tts_provider_base;

/// TTS供应商配置状态
class TTSConfigState {
  final tts_config.TTSProvider? selectedProvider;
  final String? apiKey;
  final String? model;
  final String? voice;
  final String? baseUrl;

  const TTSConfigState({
    this.selectedProvider,
    this.apiKey,
    this.model,
    this.voice,
    this.baseUrl,
  });

  TTSConfigState copyWith({
    tts_config.TTSProvider? selectedProvider,
    String? apiKey,
    String? model,
    String? voice,
    String? baseUrl,
  }) {
    return TTSConfigState(
      selectedProvider: selectedProvider ?? this.selectedProvider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      voice: voice ?? this.voice,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }

  bool get isConfigured => selectedProvider != null && apiKey?.isNotEmpty == true;

  Map<String, dynamic> toMap() {
    return {
      'selectedProvider': selectedProvider?.value,
      'apiKey': apiKey,
      'model': model,
      'voice': voice,
      'baseUrl': baseUrl,
    };
  }

  factory TTSConfigState.fromMap(Map<String, dynamic> map) {
    return TTSConfigState(
      selectedProvider: map['selectedProvider'] != null
          ? tts_config.TTSProvider.fromValue(map['selectedProvider'] as String)
          : null,
      apiKey: map['apiKey'],
      model: map['model'],
      voice: map['voice'],
      baseUrl: map['baseUrl'],
    );
  }
}

/// TTS供应商配置提供器
final ttsConfigProvider = StateNotifierProvider<TTSConfigNotifier, TTSConfigState>(
  (ref) => TTSConfigNotifier(),
);

class TTSConfigNotifier extends StateNotifier<TTSConfigState> {
  TTSConfigNotifier() : super(const TTSConfigState());

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('tts_config');
      if (configJson != null) {
        final configMap = Map<String, dynamic>.from(
          (jsonDecode(configJson) as Map).cast<String, dynamic>(),
        );
        state = TTSConfigState.fromMap(configMap);
      }
    } catch (e) {
      print('Failed to load TTS config: $e');
    }
  }

  Future<void> saveConfig(TTSConfigState config) async {
    try {
      state = config;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tts_config', jsonEncode(config.toMap()));
    } catch (e) {
      print('Failed to save TTS config: $e');
    }
  }

  Future<void> updateProvider(tts_config.TTSProvider provider) async {
    await saveConfig(state.copyWith(selectedProvider: provider));
  }

  Future<void> updateApiKey(String apiKey) async {
    await saveConfig(state.copyWith(apiKey: apiKey));
  }

  Future<void> updateModel(String model) async {
    await saveConfig(state.copyWith(model: model));
  }

  Future<void> updateVoice(String voice) async {
    await saveConfig(state.copyWith(voice: voice));
  }

  Future<void> updateBaseUrl(String baseUrl) async {
    await saveConfig(state.copyWith(baseUrl: baseUrl));
  }
}

/// TTS提供者实例提供器
final ttsProviderProvider = Provider<tts_provider_base.TTSProvider?>((ref) {
  final config = ref.watch(ttsConfigProvider);

  if (!config.isConfigured) {
    return null;
  }

  try {
    final provider = config.selectedProvider!;

    switch (provider) {
      case tts_config.TTSProvider.glmTts:
        return tts_provider_base.GLMTTSProvider(apiKey: config.apiKey);
      case tts_config.TTSProvider.aihubmixTts:
        return tts_provider_base.AIHUBMIXTTSProvider(
          apiKey: config.apiKey,
          baseUrl: config.baseUrl,
          model: config.model,
        );
    }
  } catch (e) {
    print('Failed to create TTS provider: $e');
    return null;
  }
});

/// 音频文件实体
class AudioFile {
  final String id;
  final String name;
  final String path;
  final DateTime createdAt;
  final int size;
  final String format;
  final Duration? duration;

  AudioFile({
    required this.id,
    required this.name,
    required this.path,
    required this.createdAt,
    required this.size,
    required this.format,
    this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'createdAt': createdAt.toIso8601String(),
      'size': size,
      'format': format,
      'duration': duration?.inSeconds,
    };
  }

  factory AudioFile.fromMap(Map<String, dynamic> map) {
    return AudioFile(
      id: map['id'],
      name: map['name'],
      path: map['path'],
      createdAt: DateTime.parse(map['createdAt']),
      size: map['size'],
      format: map['format'],
      duration: map['duration'] != null
          ? Duration(seconds: map['duration'])
          : null,
    );
  }
}

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
    this.format = 'mp3',
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
      format: map['format'] ?? 'mp3',
    );
  }
}

/// 合成配置提供器（支持持久化）
final synthesisConfigProvider = StateNotifierProvider<SynthesisConfigNotifier, SynthesisConfig>(
  (ref) => SynthesisConfigNotifier(),
);

class SynthesisConfigNotifier extends StateNotifier<SynthesisConfig> {
  SynthesisConfigNotifier() : super(const SynthesisConfig());

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('synthesis_config');
      if (configJson != null) {
        final configMap = Map<String, dynamic>.from(
          (jsonDecode(configJson) as Map).cast<String, dynamic>(),
        );
        state = SynthesisConfig.fromMap(configMap);
      }
    } catch (e) {
      print('Failed to load synthesis config: $e');
    }
  }

  Future<void> saveConfig(SynthesisConfig config) async {
    try {
      state = config;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('synthesis_config', jsonEncode(config.toMap()));
    } catch (e) {
      print('Failed to save synthesis config: $e');
    }
  }

  Future<void> updateVoice(String voice) async {
    await saveConfig(state.copyWith(voice: voice));
  }

  Future<void> updateSpeed(double speed) async {
    await saveConfig(state.copyWith(speed: speed));
  }

  Future<void> updateVolume(double volume) async {
    await saveConfig(state.copyWith(volume: volume));
  }

  Future<void> updateFormat(String format) async {
    await saveConfig(state.copyWith(format: format));
  }

  Future<void> resetToDefaults() async {
    await saveConfig(const SynthesisConfig());
  }
}

/// TTS合成状态
class TTSState {
  final bool isSynthesizing;
  final bool isStreaming;
  final double progress;
  final String? currentText;
  final String? error;
  final AudioFile? lastGeneratedAudio;

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
    AudioFile? lastGeneratedAudio,
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

/// TTS合成状态提供器
final ttsStateProvider = StateNotifierProvider<TTSStateNotifier, TTSState>(
  (ref) => TTSStateNotifier(ref),
);

class TTSStateNotifier extends StateNotifier<TTSState> {
  final Ref ref;

  TTSStateNotifier(this.ref) : super(const TTSState());

  Future<AudioFile?> synthesize(String text) async {
    if (state.isSynthesizing) {
      return null;
    }

    final provider = ref.read(ttsProviderProvider);
    if (provider == null) {
      state = state.copyWith(error: '请先配置TTS供应商');
      return null;
    }

    final config = ref.read(synthesisConfigProvider);

    try {
      state = state.copyWith(
        isSynthesizing: true,
        currentText: text,
        progress: 0,
        error: null,
      );

      // 更新进度
      state = state.copyWith(progress: 0.3);

      // 执行合成
      final audioData = await provider.synthesize(
        text,
        params: {
          'voice': config.voice,
          'speed': config.speed,
          'volume': config.volume,
          'format': config.format,
        },
      );

      state = state.copyWith(progress: 0.7);

      // 保存音频文件
      final audioFile = await _saveAudioFile(audioData, config.format, text);

      state = state.copyWith(
        isSynthesizing: false,
        progress: 1.0,
        lastGeneratedAudio: audioFile,
      );

      // 触发音频文件列表更新
      ref.read(audioFilesProvider.notifier).loadAudioFiles();

      return audioFile;
    } catch (e) {
      state = state.copyWith(
        isSynthesizing: false,
        error: '合成失败: $e',
      );
      return null;
    }
  }

  Future<void> startStreaming(String text) async {
    if (state.isStreaming) {
      return;
    }

    final provider = ref.read(ttsProviderProvider);
    if (provider == null) {
      state = state.copyWith(error: '请先配置TTS供应商');
      return;
    }

    final config = ref.read(synthesisConfigProvider);

    try {
      state = state.copyWith(
        isStreaming: true,
        currentText: text,
        error: null,
      );

      // 流式合成
      final stream = provider.streamSynthesize(
        text,
        params: {
          'voice': config.voice,
          'speed': config.speed,
          'volume': config.volume,
          'format': config.format,
        },
      );

      // 处理流式数据
      // 注意：这里只是启动流，实际播放需要音频播放器
      await for (final chunk in stream) {
        // 处理音频数据块
        // 可以在这里实现实时播放或保存
      }

      state = state.copyWith(isStreaming: false);
    } catch (e) {
      state = state.copyWith(
        isStreaming: false,
        error: '流式合成失败: $e',
      );
    }
  }

  void stopStreaming() {
    state = state.copyWith(isStreaming: false);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<AudioFile> _saveAudioFile(
    Uint8List audioData,
    String format,
    String text,
  ) async {
    final uuid = Uuid();
    final id = uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'tts_${timestamp}_${id.substring(0, 8)}.$format';
    final name = '录音_${DateTime.now().toString().substring(0, 10)}';

    // 获取应用文档目录
    final appDocDir = await getApplicationDocumentsDirectory();
    final ttsDir = Directory(path.join(appDocDir.path, 'tts_audio'));

    if (!await ttsDir.exists()) {
      await ttsDir.create(recursive: true);
    }

    final filePath = path.join(ttsDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(audioData);

    return AudioFile(
      id: id,
      name: name,
      path: filePath,
      createdAt: DateTime.now(),
      size: audioData.length,
      format: format,
    );
  }
}

/// 音频文件列表提供器
final audioFilesProvider = StateNotifierProvider<AudioFilesNotifier, List<AudioFile>>(
  (ref) => AudioFilesNotifier(),
);

class AudioFilesNotifier extends StateNotifier<List<AudioFile>> {
  AudioFilesNotifier() : super([]);

  Future<void> loadAudioFiles() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final ttsDir = Directory(path.join(appDocDir.path, 'tts_audio'));

      if (!await ttsDir.exists()) {
        state = [];
        return;
      }

      final files = await ttsDir.list().where((entity) => entity is File).toList();
      final audioFiles = <AudioFile>[];

      for (final fileEntity in files.cast<File>()) {
        try {
          final stat = await fileEntity.stat();
          final fileName = path.basename(fileEntity.path);
          final format = path.extension(fileName).replaceAll('.', '');

          // 从文件名提取ID和时间戳
          final parts = fileName.replaceFirst('tts_', '').split('_');
          if (parts.length >= 2) {
            final timestamp = int.tryParse(parts[0]);
            final idPart = parts[1].split('.').first;

            audioFiles.add(AudioFile(
              id: '${timestamp}_$idPart',
              name: _generateNameFromTimestamp(timestamp),
              path: fileEntity.path,
              createdAt: timestamp != null
                  ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                  : stat.changed,
              size: stat.size,
              format: format,
            ));
          }
        } catch (e) {
          print('Failed to load audio file: $e');
        }
      }

      // 按创建时间排序（最新的在前）
      audioFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = audioFiles;
    } catch (e) {
      print('Failed to load audio files: $e');
      state = [];
    }
  }

  String _generateNameFromTimestamp(int? timestamp) {
    if (timestamp == null) {
      return '录音_${DateTime.now().toString().substring(0, 10)}';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '录音_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> deleteAudioFile(String id) async {
    try {
      final file = state.firstWhere((f) => f.id == id);
      final fileObj = File(file.path);

      if (await fileObj.exists()) {
        await fileObj.delete();
      }

      state = List.from(state)..removeWhere((f) => f.id == id);
    } catch (e) {
      print('Failed to delete audio file: $e');
    }
  }

  Future<void> renameAudioFile(String id, String newName) async {
    try {
      final index = state.indexWhere((f) => f.id == id);
      if (index != -1) {
        final oldFile = state[index];
        final newFile = AudioFile(
          id: oldFile.id,
          name: newName,
          path: oldFile.path,
          createdAt: oldFile.createdAt,
          size: oldFile.size,
          format: oldFile.format,
          duration: oldFile.duration,
        );

        state = List.from(state)..[index] = newFile;
      }
    } catch (e) {
      print('Failed to rename audio file: $e');
    }
  }

  Future<void> createFolder(String folderName) async {
    // 对于文件夹管理，可以创建子目录
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final folderPath = path.join(appDocDir.path, 'tts_audio', folderName);
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
    } catch (e) {
      print('Failed to create folder: $e');
    }
  }

  Future<void> moveAudioFile(String id, String targetFolder) async {
    try {
      final file = state.firstWhere((f) => f.id == id);
      final appDocDir = await getApplicationDocumentsDirectory();
      final targetPath = path.join(appDocDir.path, 'tts_audio', targetFolder, path.basename(file.path));

      final sourceFile = File(file.path);
      final targetFile = File(targetPath);

      if (await sourceFile.exists()) {
        // 确保目标文件夹存在
        final targetDir = Directory(path.dirname(targetPath));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        await sourceFile.copy(targetPath);
        await sourceFile.delete();

        // 更新状态
        final index = state.indexWhere((f) => f.id == id);
        if (index != -1) {
          final newFile = AudioFile(
            id: file.id,
            name: file.name,
            path: targetPath,
            createdAt: file.createdAt,
            size: file.size,
            format: file.format,
            duration: file.duration,
          );

          state = List.from(state)..[index] = newFile;
        }
      }
    } catch (e) {
      print('Failed to move audio file: $e');
    }
  }

  Future<void> copyAudioFile(String id) async {
    try {
      final file = state.firstWhere((f) => f.id == id);
      final uuid = Uuid();
      final newId = uuid.v4();
      final newFileName = 'tts_${DateTime.now().millisecondsSinceEpoch}_${newId.substring(0, 8)}.${file.format}';

      final appDocDir = await getApplicationDocumentsDirectory();
      final newFilePath = path.join(appDocDir.path, 'tts_audio', newFileName);

      final sourceFile = File(file.path);
      final newFile = File(newFilePath);

      if (await sourceFile.exists()) {
        await sourceFile.copy(newFilePath);

        final copiedFile = AudioFile(
          id: newId,
          name: '${file.name}_副本',
          path: newFilePath,
          createdAt: DateTime.now(),
          size: file.size,
          format: file.format,
          duration: file.duration,
        );

        state = [copiedFile, ...state];
      }
    } catch (e) {
      print('Failed to copy audio file: $e');
    }
  }
}

/// 初始化提供器：在应用启动时加载配置
final ttsInitializerProvider = FutureProvider<void>((ref) async {
  await ref.read(ttsConfigProvider.notifier).loadConfig();
  await ref.read(synthesisConfigProvider.notifier).loadConfig();
  await ref.read(audioFilesProvider.notifier).loadAudioFiles();
});
