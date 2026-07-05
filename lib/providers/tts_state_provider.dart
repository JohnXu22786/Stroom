import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/file_manifest.dart';
import 'provider_config.dart';
import 'tts_provider.dart' as tts_provider_base;
import 'tts_state_shared.dart';
export 'tts_state_shared.dart';
import '../utils/audio_trim.dart';
import '../utils/audio_utils.dart';

/// @deprecated 不再使用，保留以备外部引用。
/// 如需合成，请使用 [TTSStateNotifier.synthesize] 并传入 config。
final ttsProviderProvider = Provider<tts_provider_base.BaseTTSProvider?>((ref) {
  final entriesState = ref.watch(providerEntriesProvider);
  final ttsEntry =
      entriesState.entries.where((e) => e.name == 'TTS供应商').firstOrNull;
  if (ttsEntry == null || ttsEntry.configs.isEmpty) return null;
  final config = ttsEntry.configs.first;
  if (config.host.isEmpty || config.key.isEmpty) return null;
  return tts_provider_base.createProviderFromConfig(config);
});

/// 合成配置提供器（支持持久化）
final synthesisConfigProvider =
    StateNotifierProvider<SynthesisConfigNotifier, SynthesisConfig>((ref) {
  final notifier = SynthesisConfigNotifier();
  notifier.loadConfig();
  return notifier;
});

class SynthesisConfigNotifier extends StateNotifier<SynthesisConfig> {
  SynthesisConfigNotifier() : super(const SynthesisConfig());

  /// 已知的 voice ID 白名单（非语音名称）
  static const _knownVoiceIds = {
    'female',
    'male',
    'alloy',
    'echo',
    'fable',
    'onyx',
    'nova',
    'shimmer',
  };

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('synthesis_config');
      if (configJson != null) {
        final configMap = Map<String, dynamic>.from(
          (jsonDecode(configJson) as Map).cast<String, dynamic>(),
        );
        var config = SynthesisConfig.fromMap(configMap);
        // 统一强制为 wav 格式，忽略旧数据中的 mp3
        config = config.copyWith(format: 'wav');

        // 迁移旧 voice name → voice ID：如果 voice 包含中文字符，则是旧名称
        final voice = config.voice;
        if (voice.contains(RegExp(r'[\u4e00-\u9fff]')) ||
            (voice.isNotEmpty &&
                !_knownVoiceIds.contains(voice) &&
                !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(voice))) {
          config = config.copyWith(voice: 'female');
          // 覆写持久化值
          await prefs.setString('synthesis_config', jsonEncode(config.toMap()));
        }

        state = config;
      }
    } catch (e) {
      debugPrint('Failed to load synthesis config: $e');
    }
  }

  Future<void> saveConfig(SynthesisConfig config) async {
    try {
      state = config;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('synthesis_config', jsonEncode(config.toMap()));
    } catch (e) {
      debugPrint('Failed to save synthesis config: $e');
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

/// 音频文件记录列表提供器（基于 manifest）
final audioRecordsProvider =
    StateNotifierProvider<AudioRecordsNotifier, List<AudioRecord>>(
  (ref) => AudioRecordsNotifier(),
);

/// 文件夹列表提供器
final folderListProvider =
    StateNotifierProvider<FolderListNotifier, Set<String>>(
  (ref) => FolderListNotifier(),
);

/// 文件夹列表状态管理
class FolderListNotifier extends StateNotifier<Set<String>> {
  FolderListNotifier() : super({});

  Future<void> loadFolders() async {
    final folders = await FileManifest.getAllFolders();
    state = folders;
  }

  Future<void> addFolder(String name) async {
    await FileManifest.addFolder(name);
    await loadFolders();
  }

  Future<void> removeFolder(String name) async {
    await FileManifest.removeFolder(name);
    await loadFolders();
  }
}

class AudioRecordsNotifier extends StateNotifier<List<AudioRecord>> {
  AudioRecordsNotifier() : super([]);

  Future<void> loadRecords() async {
    final records = await FileManifest.loadRecords();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = List<AudioRecord>.from(records);
  }

  Future<void> addRecord(AudioRecord record) async {
    await FileManifest.addRecord(record);
    await loadRecords();
  }

  Future<void> deleteRecord(String id) async {
    await FileManifest.deleteRecord(id);
    await loadRecords();
  }

  Future<void> deleteRecords(List<String> ids) async {
    await FileManifest.deleteRecords(ids);
    await loadRecords();
  }

  Future<void> renameRecord(String id, String newName) async {
    FileManifest.invalidateCache();
    await FileManifest.renameRecord(id, newName);
    await loadRecords();
  }

  Future<void> moveRecord(String id, String targetFolder) async {
    await FileManifest.moveRecord(id, targetFolder);
    await loadRecords();
  }

  // ====================================================================
  // 文件夹管理
  // ====================================================================

  /// 获取所有有效文件夹（含空文件夹 + 记录中存在的文件夹）
  Future<Set<String>> getFolders() async {
    return FileManifest.getAllFolders();
  }

  /// 创建文件夹
  Future<void> createFolder(String folderName) async {
    await FileManifest.addFolder(folderName);
  }

  /// 删除文件夹（同时删除内部所有记录）
  Future<void> deleteFolder(String folderName) async {
    await FileManifest.removeFolder(folderName);
    await loadRecords();
  }

  /// 重命名文件夹（只更新末级名称，保留层级结构）
  Future<void> renameFolder(String oldName, String newName) async {
    FileManifest.invalidateCache();
    final parentPath = FileManifest.getParentFolderPath(oldName);
    final newPath = parentPath.isEmpty ? newName : '$parentPath/$newName';

    final records = await FileManifest.loadRecords();

    // 更新 oldName 本身的记录
    for (final r in records) {
      if (r.folder == oldName) {
        await FileManifest.moveRecord(r.id, newPath);
      }
    }

    // 更新所有后代文件夹的记录
    final oldDescendants =
        await FileManifest.getAllDescendantFolderPaths(oldName);
    for (final desc in oldDescendants) {
      final suffix = desc.substring(oldName.length); // e.g., "/sub"
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await FileManifest.moveRecord(r.id, newDescPath);
        }
      }
    }

    await FileManifest.addFolderPath(newPath);
    await FileManifest.removeFolder(oldName); // 已无记录，仅清理缓存
    await loadRecords();
  }

  /// 移动文件夹（保持层级结构，整体搬入目标文件夹）
  Future<void> moveFolder(String oldName, String targetFolder) async {
    FileManifest.invalidateCache();
    final baseName = FileManifest.getFolderBaseName(oldName);
    final newPath = targetFolder.isEmpty ? baseName : '$targetFolder/$baseName';

    final records = await FileManifest.loadRecords();

    // 移动 oldName 本身的记录到 newPath
    for (final r in records) {
      if (r.folder == oldName) {
        await FileManifest.moveRecord(r.id, newPath);
      }
    }

    // 移动所有后代文件夹的记录
    final oldDescendants =
        await FileManifest.getAllDescendantFolderPaths(oldName);
    for (final desc in oldDescendants) {
      final suffix = desc.substring(oldName.length); // e.g., "/sub"
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await FileManifest.moveRecord(r.id, newDescPath);
        }
      }
    }

    // 更新文件夹缓存
    await FileManifest.addFolderPath(newPath);
    if (targetFolder.isNotEmpty) {
      await FileManifest.addFolder(targetFolder); // 确保目标存在
    }
    await FileManifest.removeFolder(oldName); // 已无记录，仅清理缓存
    await loadRecords();
  }

  /// 复制文件夹（保持层级结构，整体复制到目标文件夹）
  Future<void> copyFolder(String sourceFolder, String targetFolder) async {
    final baseName = FileManifest.getFolderBaseName(sourceFolder);
    final newPath = targetFolder.isEmpty ? baseName : '$targetFolder/$baseName';

    final records = await FileManifest.loadRecords();

    // 复制 sourceFolder 本身的记录
    for (final r in records) {
      if (r.folder == sourceFolder) {
        await FileManifest.addRecord(AudioRecord(
          name: r.name,
          hash: r.hash,
          format: r.format,
          createdAt: DateTime.now(),
          size: r.size,
          folder: newPath,
          sourceText: r.sourceText,
        ));
      }
    }

    // 复制所有后代文件夹的记录
    final descendants =
        await FileManifest.getAllDescendantFolderPaths(sourceFolder);
    for (final desc in descendants) {
      final suffix = desc.substring(sourceFolder.length);
      final newDescPath = '$newPath$suffix';
      for (final r in records) {
        if (r.folder == desc) {
          await FileManifest.addRecord(AudioRecord(
            name: r.name,
            hash: r.hash,
            format: r.format,
            createdAt: DateTime.now(),
            size: r.size,
            folder: newDescPath,
            sourceText: r.sourceText,
          ));
        }
      }
    }

    await FileManifest.addFolderPath(newPath);
    if (targetFolder.isNotEmpty) {
      await FileManifest.addFolder(targetFolder);
    }
    await loadRecords();
  }
}

/// TTS 合成状态提供器
final ttsStateProvider = StateNotifierProvider<TTSStateNotifier, TTSState>(
  (ref) => TTSStateNotifier(ref),
);

class TTSStateNotifier extends StateNotifier<TTSState> {
  final Ref ref;

  TTSStateNotifier(this.ref) : super(const TTSState());

  /// 合成语音
  ///
  /// [text] 要合成的文本
  /// [providerConfig] 供应商配置（含 host/key）
  /// [modelConfig] 选中的模型配置（含 modelId、自定义参数等）
  /// [customParams] 用户在页面上输入的自定义参数值
  /// [trimPreset] 裁切预设，包含 durationSeconds(秒) 和 direction('head'/'tail')
  Future<AudioRecord?> synthesize(
    String text, {
    required ProviderConfigItem providerConfig,
    required ModelConfig modelConfig,
    Map<String, String>? customParams,
    Map<String, dynamic>? trimPreset,
    String title = '',
  }) async {
    if (state.isSynthesizing) {
      return null;
    }

    if (providerConfig.host.isEmpty || providerConfig.key.isEmpty) {
      state = state.copyWith(error: '请先配置TTS供应商的API地址和密钥');
      return null;
    }

    final provider = tts_provider_base.createProviderFromConfig(providerConfig);
    final synthConfig = ref.read(synthesisConfigProvider);

    try {
      state = state.copyWith(
        isSynthesizing: true,
        currentText: text,
        progress: 0,
        error: null,
      );

      state = state.copyWith(progress: 0.3);

      // 构建参数：通用参数 + 模型ID + 自定义参数
      final params = <String, dynamic>{
        'voice': synthConfig.voice,
        'speed': synthConfig.speed,
        'volume': synthConfig.volume,
        'format': synthConfig.format,
        'response_format': synthConfig.format,
        'model': modelConfig.modelId,
      };
      if (customParams != null) {
        params.addAll(customParams);
      }
      // Parse JSON-type custom params from string to actual JSON
      // objects/arrays so they are sent as raw JSON, not quoted strings.
      _parseJsonCustomParams(params, modelConfig);

      // 执行合成
      var audioData = await provider.synthesize(
        text,
        params: params,
      );

      state = state.copyWith(progress: 0.7);

      // 格式校验：确保音频数据含有效文件头，裸 PCM 自动补 WAV 头
      var actualFormat = synthConfig.format;
      if (audioData.isNotEmpty) {
        final fixed = ensureValidAudioFormat(
          audioData,
          requestedFormat: synthConfig.format,
          sampleRate: 24000,
        );
        audioData = fixed.$1;
        actualFormat = fixed.$2;
      }

      // 如果指定了裁切预设，应用裁切
      if (trimPreset != null && audioData.isNotEmpty) {
        try {
          audioData = trimAudio(audioData, preset: trimPreset);
        } catch (e) {
          debugPrint('Failed to trim audio: $e');
        }
      }

      // 保存音频文件（使用 actualFormat 确保扩展名与数据格式一致）
      final audioFile =
          await _saveAudioFile(audioData, actualFormat, text, name: title);

      state = state.copyWith(
        isSynthesizing: false,
        progress: 1.0,
        lastGeneratedAudio: audioFile,
      );

      // 触发音频文件列表更新
      ref.read(audioRecordsProvider.notifier).loadRecords();

      return audioFile;
    } catch (e) {
      state = state.copyWith(
        isSynthesizing: false,
        error: '合成失败: $e',
      );
      return null;
    }
  }

  Future<void> startStreaming(
    String text, {
    required ProviderConfigItem providerConfig,
    required ModelConfig modelConfig,
    Map<String, String>? customParams,
  }) async {
    if (state.isStreaming) {
      return;
    }

    if (providerConfig.host.isEmpty || providerConfig.key.isEmpty) {
      state = state.copyWith(error: '请先配置TTS供应商的API地址和密钥');
      return;
    }

    final provider = tts_provider_base.createProviderFromConfig(providerConfig);
    final synthConfig = ref.read(synthesisConfigProvider);

    try {
      state = state.copyWith(
        isStreaming: true,
        currentText: text,
        error: null,
      );

      // 构建参数：通用参数 + 模型ID + 自定义参数
      final params = <String, dynamic>{
        'voice': synthConfig.voice,
        'speed': synthConfig.speed,
        'volume': synthConfig.volume,
        'format': synthConfig.format,
        'response_format': synthConfig.format,
        'model': modelConfig.modelId,
      };
      if (customParams != null) {
        params.addAll(customParams);
      }
      // Parse JSON-type custom params from string to actual JSON
      // objects/arrays so they are sent as raw JSON, not quoted strings.
      _parseJsonCustomParams(params, modelConfig);

      final stream = provider.streamSynthesize(
        text,
        params: params,
      );

      await for (final _ in stream) {
        // 流式数据已由 streamSynthesize 内部处理
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

  Future<AudioRecord> _saveAudioFile(
    Uint8List audioData,
    String format,
    String text, {
    String name = '',
  }) async {
    final timestamp = DateTime.now();

    // Use provided name or generate default
    final displayName = name.isNotEmpty
        ? name
        : '录音_${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}-${timestamp.minute.toString().padLeft(2, '0')}-${timestamp.second.toString().padLeft(2, '0')}';

    // Compute MD5 hash of audio data
    final hash = computeAudioHash(audioData);

    // Save audio file using hash as filename
    await FileManifest.writeFile('$hash.$format', audioData);

    // Save source text companion file
    if (text.isNotEmpty) {
      final textBytes = Uint8List.fromList(utf8.encode(text));
      await FileManifest.writeFile('$hash.txt', textBytes);
    }

    final record = AudioRecord(
      name: displayName,
      hash: hash,
      format: format,
      createdAt: timestamp,
      size: audioData.length,
      sourceText: text,
    );

    // Add to manifest
    await FileManifest.addRecord(record);

    return record;
  }

  /// Parse JSON-type custom param values from string to actual JSON
  /// objects/arrays so they are sent as raw JSON, not quoted strings.
  void _parseJsonCustomParams(
      Map<String, dynamic> params, ModelConfig modelConfig) {
    for (final cp in modelConfig.customParams) {
      if (cp.type != 'json') continue;
      if (!params.containsKey(cp.paramName)) continue;
      final rawValue = params[cp.paramName];
      if (rawValue is String) {
        try {
          params[cp.paramName] = jsonDecode(rawValue);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }
    }
  }
}
