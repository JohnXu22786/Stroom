import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:convert';

/// 录音数据模型
class Recording {
  final String id;
  final String text;
  final String filePath;
  final int duration; // 单位：秒
  final DateTime createdAt;
  final String language;

  const Recording({
    required this.id,
    required this.text,
    required this.filePath,
    required this.duration,
    required this.createdAt,
    required this.language,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'filePath': filePath,
      'duration': duration,
      'createdAt': createdAt.toIso8601String(),
      'language': language,
    };
  }

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'],
      text: json['text'],
      filePath: json['filePath'],
      duration: json['duration'],
      createdAt: DateTime.parse(json['createdAt']),
      language: json['language'],
    );
  }

  Recording copyWith({
    String? id,
    String? text,
    String? filePath,
    int? duration,
    DateTime? createdAt,
    String? language,
  }) {
    return Recording(
      id: id ?? this.id,
      text: text ?? this.text,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recording &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 播放状态枚举
enum PlaybackState {
  stopped,
  playing,
  paused,
}

/// 音频应用状态，管理录音列表和播放状态
class AudioState {
  final List<Recording> recordings;
  final String? currentRecordingId;
  final PlaybackState playbackState;
  final double playbackPosition; // 播放位置，0.0 到 1.0
  final bool isGeneratingTTS;
  final String? error;

  const AudioState({
    this.recordings = const [],
    this.currentRecordingId,
    this.playbackState = PlaybackState.stopped,
    this.playbackPosition = 0.0,
    this.isGeneratingTTS = false,
    this.error,
  });

  /// 获取当前正在播放的录音
  Recording? get currentRecording {
    if (currentRecordingId == null) return null;
    return recordings.firstWhere(
      (recording) => recording.id == currentRecordingId,
      orElse: () => Recording(
        id: '',
        text: '',
        filePath: '',
        duration: 0,
        createdAt: DateTime.now(),
        language: '',
      ),
    );
  }

  AudioState copyWith({
    List<Recording>? recordings,
    String? currentRecordingId,
    PlaybackState? playbackState,
    double? playbackPosition,
    bool? isGeneratingTTS,
    String? error,
  }) {
    return AudioState(
      recordings: recordings ?? this.recordings,
      currentRecordingId: currentRecordingId ?? this.currentRecordingId,
      playbackState: playbackState ?? this.playbackState,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      isGeneratingTTS: isGeneratingTTS ?? this.isGeneratingTTS,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioState &&
          runtimeType == other.runtimeType &&
          recordings == other.recordings &&
          currentRecordingId == other.currentRecordingId &&
          playbackState == other.playbackState &&
          playbackPosition == other.playbackPosition &&
          isGeneratingTTS == other.isGeneratingTTS &&
          error == other.error;

  @override
  int get hashCode =>
      recordings.hashCode ^
      currentRecordingId.hashCode ^
      playbackState.hashCode ^
      playbackPosition.hashCode ^
      isGeneratingTTS.hashCode ^
      error.hashCode;
}

/// 音频状态通知器，管理录音和播放状态
class AudioNotifier extends StateNotifier<AudioState> {
  AudioNotifier() : super(const AudioState()) {
    _init();
  }

  Future<void> _init() async {
    await loadRecordings();
  }

  /// 加载已保存的录音
  Future<void> loadRecordings() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final metadataFile = File(path.join(appDir.path, 'audio_metadata.json'));

      if (await metadataFile.exists()) {
        final content = await metadataFile.readAsString();
        final jsonData = jsonDecode(content);
        final recordings = (jsonData['recordings'] as List)
            .map((item) => Recording.fromJson(item))
            .toList();

        // 按创建时间排序（最新的在前）
        recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        state = state.copyWith(recordings: recordings);
      }
    } catch (e) {
      // 如果加载失败，保持空列表
      print('加载录音元数据失败: $e');
    }
  }

  /// 保存录音元数据到文件
  Future<void> _saveRecordings() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final metadataFile = File(path.join(appDir.path, 'audio_metadata.json'));

      final jsonData = {
        'recordings': state.recordings.map((recording) => recording.toJson()).toList(),
      };

      await metadataFile.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      print('保存录音元数据失败: $e');
      state = state.copyWith(error: '保存录音元数据失败');
    }
  }

  /// 添加新录音
  Future<void> addRecording({
    required String text,
    required String filePath,
    required int duration,
    required String language,
  }) async {
    final recording = Recording(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      filePath: filePath,
      duration: duration,
      createdAt: DateTime.now(),
      language: language,
    );

    final newRecordings = List<Recording>.from(state.recordings);
    newRecordings.insert(0, recording); // 最新录音放在最前面

    state = state.copyWith(recordings: newRecordings);
    await _saveRecordings();
  }

  /// 删除录音
  Future<void> deleteRecording(String recordingId) async {
    final recording = state.recordings.firstWhere(
      (r) => r.id == recordingId,
      orElse: () => Recording(
        id: '',
        text: '',
        filePath: '',
        duration: 0,
        createdAt: DateTime.now(),
        language: '',
      ),
    );

    if (recording.id.isEmpty) return;

    // 删除音频文件
    try {
      final audioFile = File(recording.filePath);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
    } catch (e) {
      print('删除音频文件失败: $e');
    }

    final newRecordings = List<Recording>.from(state.recordings);
    newRecordings.removeWhere((r) => r.id == recordingId);

    // 如果删除的是当前正在播放的录音，则停止播放
    String? newCurrentRecordingId = state.currentRecordingId;
    PlaybackState newPlaybackState = state.playbackState;
    if (recordingId == state.currentRecordingId) {
      newCurrentRecordingId = null;
      newPlaybackState = PlaybackState.stopped;
    }

    state = state.copyWith(
      recordings: newRecordings,
      currentRecordingId: newCurrentRecordingId,
      playbackState: newPlaybackState,
      playbackPosition: 0.0,
    );

    await _saveRecordings();
  }

  /// 清空所有录音
  Future<void> clearRecordings() async {
    // 删除所有音频文件
    for (final recording in state.recordings) {
      try {
        final audioFile = File(recording.filePath);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (e) {
        print('删除音频文件失败: $e');
      }
    }

    // 删除元数据文件
    try {
      final appDir = await getApplicationSupportDirectory();
      final metadataFile = File(path.join(appDir.path, 'audio_metadata.json'));
      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }
    } catch (e) {
      print('删除元数据文件失败: $e');
    }

    state = const AudioState();
  }

  /// 开始播放录音
  void startPlayback(String recordingId) {
    if (state.currentRecordingId == recordingId &&
        state.playbackState == PlaybackState.paused) {
      // 从暂停状态恢复播放
      state = state.copyWith(
        playbackState: PlaybackState.playing,
      );
    } else {
      // 开始播放新录音
      state = state.copyWith(
        currentRecordingId: recordingId,
        playbackState: PlaybackState.playing,
        playbackPosition: 0.0,
      );
    }
  }

  /// 暂停播放
  void pausePlayback() {
    state = state.copyWith(
      playbackState: PlaybackState.paused,
    );
  }

  /// 停止播放
  void stopPlayback() {
    state = state.copyWith(
      playbackState: PlaybackState.stopped,
      playbackPosition: 0.0,
    );
  }

  /// 更新播放位置
  void updatePlaybackPosition(double position) {
    state = state.copyWith(
      playbackPosition: position.clamp(0.0, 1.0),
    );
  }

  /// 设置TTS生成状态
  void setGeneratingTTS(bool isGenerating) {
    state = state.copyWith(
      isGeneratingTTS: isGenerating,
    );
  }

  /// 设置错误信息
  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  /// 清除错误信息
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 获取录音数量
  int get recordingCount => state.recordings.length;

  /// 获取所有录音
  List<Recording> get allRecordings => state.recordings;
}

/// 音频状态提供器
final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>(
  (ref) => AudioNotifier(),
);
