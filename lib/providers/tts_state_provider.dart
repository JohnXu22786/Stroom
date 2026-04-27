import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'tts_config.dart';
import 'tts_provider.dart' as tts_provider_base;
import '../utils/storage_service.dart';
import '../utils/audio_trim.dart';

/// TTS 供应商配置状态
///
/// 每个供应商拥有独立配置（API密钥、模型、音色等），互不共用。
class TTSConfigState {
  /// 当前选中的供应商 ID
  final String? selectedProviderId;

  /// 所有供应商的配置 Map：providerId → config Map
  final Map<String, Map<String, dynamic>> providerConfigs;

  const TTSConfigState({
    this.selectedProviderId,
    this.providerConfigs = const {},
  });

  /// 当前选中供应商的配置 Map
  Map<String, dynamic>? get selectedConfig =>
      selectedProviderId != null ? providerConfigs[selectedProviderId] : null;

  bool get isConfigured {
    if (selectedProviderId == null) return false;
    final cfg = selectedConfig;
    return cfg != null && (cfg['apiKey'] as String?)?.isNotEmpty == true;
  }

  String? get apiKey => selectedConfig?['apiKey'] as String?;
  String? get baseUrl => selectedConfig?['baseUrl'] as String?;

  // Provider-specific config convenience getters
  GlmConfig get glmConfig => GlmConfig.fromMap(
      providerConfigs['glm_tts'] ?? <String, dynamic>{});
  AihubmixConfig get aihubmixConfig => AihubmixConfig.fromMap(
      providerConfigs['aihubmix_tts'] ?? <String, dynamic>{});

  TTSConfigState copyWith({
    String? selectedProviderId,
    Map<String, Map<String, dynamic>>? providerConfigs,
  }) {
    return TTSConfigState(
      selectedProviderId: selectedProviderId ?? this.selectedProviderId,
      providerConfigs: providerConfigs ?? this.providerConfigs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selectedProviderId': selectedProviderId,
      'providerConfigs': providerConfigs,
    };
  }

  factory TTSConfigState.fromMap(Map<String, dynamic> map) {
    final configs = map['providerConfigs'] as Map<String, dynamic>? ?? {};
    return TTSConfigState(
      selectedProviderId: map['selectedProviderId'] as String?,
      providerConfigs: configs.map((k, v) =>
          MapEntry(k, Map<String, dynamic>.from(v as Map))),
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

  Future<void> selectProvider(String providerId) async {
    var configs = Map<String, Map<String, dynamic>>.from(state.providerConfigs);
    // 如果该供应商还没有配置，给一个默认值
    if (!configs.containsKey(providerId)) {
      final def = TTSProviderRegistry.get(providerId);
      configs[providerId] = Map<String, dynamic>.from(def?.defaultConfig ?? {});
    }
    await _persist(TTSConfigState(
      selectedProviderId: providerId,
      providerConfigs: configs,
    ));
  }

  Future<void> saveGlmConfig(GlmConfig glmConfig) async {
    var configs = Map<String, Map<String, dynamic>>.from(state.providerConfigs);
    configs['glm_tts'] = glmConfig.toMap();
    await _persist(TTSConfigState(
      selectedProviderId: state.selectedProviderId,
      providerConfigs: configs,
    ));
  }

  Future<void> saveAihubmixConfig(AihubmixConfig aihubmixConfig) async {
    var configs = Map<String, Map<String, dynamic>>.from(state.providerConfigs);
    configs['aihubmix_tts'] = aihubmixConfig.toMap();
    await _persist(TTSConfigState(
      selectedProviderId: state.selectedProviderId,
      providerConfigs: configs,
    ));
  }

  /// 通用保存：更新某供应商的配置 Map
  Future<void> saveProviderConfig(String providerId, Map<String, dynamic> config) async {
    var configs = Map<String, Map<String, dynamic>>.from(state.providerConfigs);
    configs[providerId] = config;
    await _persist(TTSConfigState(
      selectedProviderId: state.selectedProviderId,
      providerConfigs: configs,
    ));
  }
}



/// TTS 提供者实例提供器 —— 从当前选中的供应商配置创建 provider 实例
final ttsProviderProvider =
    Provider<tts_provider_base.BaseTTSProvider?>((ref) {
  final config = ref.watch(ttsConfigProvider);
  final providerId = config.selectedProviderId;

  if (providerId == null || !config.isConfigured) {
    return null;
  }

  try {
    switch (providerId) {
      case 'glm_tts':
        return tts_provider_base.GLMTTSProvider(
          apiKey: config.glmConfig.apiKey,
          baseUrl: config.glmConfig.baseUrl,
        );
      case 'aihubmix_tts':
        final aihubmix = config.aihubmixConfig;
        return tts_provider_base.AIHUBMIXTTSProvider(
          apiKey: aihubmix.apiKey,
          baseUrl: aihubmix.baseUrl,
          model: aihubmix.model ?? aihubmix.defaultModel,
        );
      default:
        print('Unknown provider: $providerId');
        return null;
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
          'response_format': config.format,
        },
      );

      state = state.copyWith(progress: 0.7);

      // 仅 GLM 需要裁切头部蜂鸣声
      Uint8List trimmed = audioData;
      if (provider.name == 'glm_tts') {
        final ttsConfig = ref.read(ttsConfigProvider);
        final glmCfg = ttsConfig.glmConfig;
        if (glmCfg.trimMode != GlmTrimMode.none) {
          final def = TTSProviderRegistry.get('glm_tts');
          final sampleRate = def?.defaultSampleRate ?? 24000;
          print('TTSStateNotifier: 应用GLM音频裁切...');
          trimmed = trimGlmAudio(trimmed, sampleRate: sampleRate, trimMode: glmCfg.trimMode, force: true);
          print('TTSStateNotifier: 裁切完成 - 大小: ${trimmed.length} 字节');
        }
      }

      // 保存音频文件
      final audioFile = await _saveAudioFile(trimmed, config.format, text);

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
          'response_format': config.format,
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

    filePath = await StorageService.writeFile(fileName, audioData);

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
