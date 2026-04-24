import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'tts_config.dart' as cfg;
import 'tts_provider.dart' as tts_provider_base;
import '../utils/storage_service.dart';

/// TTS 供应商配置状态
///
/// 每个供应商拥有独立配置（API密钥、模型、音色等），互不共用。
class TTSConfigState {
  /// 当前选中的供应商
  final cfg.TTSProvider? selectedProvider;

  /// GLM-TTS 独立配置
  final cfg.GlmConfig? glmConfig;

  /// AIHUBMIX-TTS 独立配置
  final cfg.AihubmixConfig? aihubmixConfig;

  const TTSConfigState({
    this.selectedProvider,
    this.glmConfig,
    this.aihubmixConfig,
  });

  /// 当前选中供应商的配置是否已配好
  bool get isConfigured {
    if (selectedProvider == null) return false;
    switch (selectedProvider!) {
      case cfg.TTSProvider.glmTts:
        return glmConfig?.isConfigured == true;
      case cfg.TTSProvider.aihubmixTts:
        return aihubmixConfig?.isConfigured == true;
    }
  }

  /// 当前选中供应商的 API 密钥
  String? get apiKey {
    if (selectedProvider == null) return null;
    switch (selectedProvider!) {
      case cfg.TTSProvider.glmTts:
        return glmConfig?.apiKey;
      case cfg.TTSProvider.aihubmixTts:
        return aihubmixConfig?.apiKey;
    }
  }

  /// 当前选中供应商的 baseUrl
  String? get baseUrl {
    if (selectedProvider == null) return null;
    switch (selectedProvider!) {
      case cfg.TTSProvider.glmTts:
        return glmConfig?.baseUrl;
      case cfg.TTSProvider.aihubmixTts:
        return aihubmixConfig?.baseUrl;
    }
  }

  /// 当前选中供应商的 model（仅 AIHUBMIX 使用）
  String? get model {
    if (selectedProvider == null) return null;
    switch (selectedProvider!) {
      case cfg.TTSProvider.glmTts:
        return null;
      case cfg.TTSProvider.aihubmixTts:
        return aihubmixConfig?.model;
    }
  }

  TTSConfigState copyWith({
    cfg.TTSProvider? selectedProvider,
    cfg.GlmConfig? glmConfig,
    cfg.AihubmixConfig? aihubmixConfig,
  }) {
    return TTSConfigState(
      selectedProvider: selectedProvider ?? this.selectedProvider,
      glmConfig: glmConfig ?? this.glmConfig,
      aihubmixConfig: aihubmixConfig ?? this.aihubmixConfig,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selectedProvider': selectedProvider?.value,
      'glmConfig': glmConfig?.toMap(),
      'aihubmixConfig': aihubmixConfig?.toMap(),
    };
  }

  factory TTSConfigState.fromMap(Map<String, dynamic> map) {
    return TTSConfigState(
      selectedProvider: map['selectedProvider'] != null
          ? cfg.TTSProvider.fromValue(map['selectedProvider'] as String)
          : null,
      glmConfig: map['glmConfig'] != null
          ? cfg.GlmConfig.fromMap(
              Map<String, dynamic>.from(map['glmConfig'] as Map))
          : null,
      aihubmixConfig: map['aihubmixConfig'] != null
          ? cfg.AihubmixConfig.fromMap(
              Map<String, dynamic>.from(map['aihubmixConfig'] as Map))
          : null,
    );
  }
}

/// TTS 供应商配置提供器（持久化）
final ttsConfigProvider =
    StateNotifierProvider<TTSConfigNotifier, TTSConfigState>((ref) {
  final notifier = TTSConfigNotifier();
  notifier.loadConfig();
  return notifier;
});

class TTSConfigNotifier extends StateNotifier<TTSConfigState> {
  TTSConfigNotifier() : super(const TTSConfigState());

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('tts_config_v2');
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

  Future<void> _persist(TTSConfigState config) async {
    try {
      state = config;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tts_config_v2', jsonEncode(config.toMap()));
    } catch (e) {
      print('Failed to persist TTS config: $e');
    }
  }

  /// 切换/保存选中的供应商
  Future<void> selectProvider(cfg.TTSProvider provider) async {
    final config = state.copyWith(selectedProvider: provider);
    // 如果该供应商还没有配置，给一个默认值
    config._ensureDefaults();
    await _persist(config);
  }

  /// 保存 GLM-TTS 的独立配置
  Future<void> saveGlmConfig(cfg.GlmConfig glmConfig) async {
    final config = state.copyWith(glmConfig: glmConfig);
    await _persist(config);
  }

  /// 保存 AIHUBMIX-TTS 的独立配置
  Future<void> saveAihubmixConfig(cfg.AihubmixConfig aihubmixConfig) async {
    final config = state.copyWith(aihubmixConfig: aihubmixConfig);
    await _persist(config);
  }
}

/// 确保每个已选供应商至少有一个默认空配置，防止 null 访问
extension _ConfigDefaults on TTSConfigState {
  void _ensureDefaults() {
    // 此方法仅在构造时使用，实际状态通过 Notifier 更新
  }
}

/// TTS 提供者实例提供器 —— 从当前选中的供应商配置创建 provider 实例
final ttsProviderProvider =
    Provider<tts_provider_base.BaseTTSProvider?>((ref) {
  final config = ref.watch(ttsConfigProvider);

  if (!config.isConfigured) {
    return null;
  }

  try {
    final provider = config.selectedProvider!;

    switch (provider) {
      case cfg.TTSProvider.glmTts:
        final glm = config.glmConfig!;
        return tts_provider_base.GLMTTSProvider(
          apiKey: glm.apiKey,
          baseUrl: glm.baseUrl,
          forceTrim: glm.forceTrim,
        );
      case cfg.TTSProvider.aihubmixTts:
        final aihubmix = config.aihubmixConfig!;
        return tts_provider_base.AIHUBMIXTTSProvider(
          apiKey: aihubmix.apiKey,
          baseUrl: aihubmix.baseUrl,
          model: aihubmix.model ?? aihubmix.defaultModel,
        );
    }
  } catch (e) {
    print('Failed to create TTS provider: $e');
    return null;
  }
});

// ============================================================================
// 音频文件实体 & 列表管理（以下部分保持不变）
// ============================================================================

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
final synthesisConfigProvider =
    StateNotifierProvider<SynthesisConfigNotifier, SynthesisConfig>((ref) {
  final notifier = SynthesisConfigNotifier();
  notifier.loadConfig();
  return notifier;
});

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

/// TTS 合成状态
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

/// TTS 合成状态提供器
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

      final stream = provider.streamSynthesize(
        text,
        params: {
          'voice': config.voice,
          'speed': config.speed,
          'volume': config.volume,
          'format': config.format,
        },
      );

      await for (final chunk in stream) {
        // 处理音频数据块
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

    String filePath;
    final fileSize = audioData.length;

    if (kIsWeb) {
      filePath = await StorageService.writeFile(fileName, audioData);
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      final ttsDir = Directory(path.join(appDocDir.path, 'tts_audio'));

      if (!await ttsDir.exists()) {
        await ttsDir.create(recursive: true);
      }

      filePath = path.join(ttsDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(audioData);
    }

    return AudioFile(
      id: id,
      name: name,
      path: filePath,
      createdAt: DateTime.now(),
      size: fileSize,
      format: format,
    );
  }
}

/// 音频文件列表提供器
final audioFilesProvider =
    StateNotifierProvider<AudioFilesNotifier, List<AudioFile>>(
  (ref) => AudioFilesNotifier(),
);

class AudioFilesNotifier extends StateNotifier<List<AudioFile>> {
  AudioFilesNotifier() : super([]);

  Future<void> loadAudioFiles() async {
    try {
      if (kIsWeb) {
        final files = await StorageService.listFiles();
        final audioFiles = files.map((f) {
          final parts = f.name.replaceFirst('tts_', '').split('_');
          final timestamp = int.tryParse(parts.isNotEmpty ? parts[0] : '');
          final idPart = parts.length > 1 ? parts[1].split('.').first : '';

          return AudioFile(
            id: '${timestamp ?? DateTime.now().millisecondsSinceEpoch}_$idPart',
            name: _generateNameFromTimestamp(timestamp),
            path: f.path,
            createdAt: f.modifiedAt,
            size: f.size,
            format: f.extension,
          );
        }).toList();

        audioFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = audioFiles;
        return;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final ttsDir = Directory(path.join(appDocDir.path, 'tts_audio'));

      if (!await ttsDir.exists()) {
        state = [];
        return;
      }

      final files =
          await ttsDir.list().where((entity) => entity is File).toList();
      final audioFiles = <AudioFile>[];

      for (final fileEntity in files.cast<File>()) {
        try {
          final stat = await fileEntity.stat();
          final fileName = path.basename(fileEntity.path);
          final format = path.extension(fileName).replaceAll('.', '');

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

      if (kIsWeb) {
        await StorageService.deleteFile(file.path);
      } else {
        final fileObj = File(file.path);
        if (await fileObj.exists()) {
          await fileObj.delete();
        }
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
    if (kIsWeb) {
      return;
    }
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

      if (kIsWeb) {
        final fileName = file.path.split('/').last;
        final newPath = '/tts_audio/$targetFolder/$fileName';
        final data = await StorageService.readFile(file.path);
        if (data != null) {
          await StorageService.deleteFile(file.path);
          await StorageService.writeFile('$targetFolder/$fileName', data);

          final index = state.indexWhere((f) => f.id == id);
          if (index != -1) {
            final newFile = AudioFile(
              id: file.id,
              name: file.name,
              path: newPath,
              createdAt: file.createdAt,
              size: file.size,
              format: file.format,
              duration: file.duration,
            );
            state = List.from(state)..[index] = newFile;
          }
        }
        return;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final targetPath = path.join(
          appDocDir.path, 'tts_audio', targetFolder, path.basename(file.path));

      final sourceFile = File(file.path);
      if (await sourceFile.exists()) {
        final targetDir = Directory(path.dirname(targetPath));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        await sourceFile.copy(targetPath);
        await sourceFile.delete();

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
      final newFileName =
          'tts_${DateTime.now().millisecondsSinceEpoch}_${newId.substring(0, 8)}.${file.format}';

      if (kIsWeb) {
        final newPath = await StorageService.copyFile(file.path, newFileName);
        if (newPath != null) {
          final copiedFile = AudioFile(
            id: newId,
            name: '${file.name}_副本',
            path: newPath,
            createdAt: DateTime.now(),
            size: file.size,
            format: file.format,
            duration: file.duration,
          );
          state = [copiedFile, ...state];
        }
        return;
      }

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
