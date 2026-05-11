import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

// ===========================================================================
// AudioPlayerAdapter — 用于 AudioPlayerPage 的跨平台播放器
// Native 实现：包装 just_audio 的 AudioPlayer
// ===========================================================================

/// Native 平台播放器适配器
/// 内部使用 just_audio 的 AudioPlayer
class AudioPlayerAdapter {
  AudioPlayer? _player;

  final StreamController<Duration> _positionCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationCtrl =
      StreamController<Duration?>.broadcast();
  final StreamController<void> _stateCtrl = StreamController<void>.broadcast();

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  /// 当前播放状态
  bool get playing => _player?.playing ?? false;

  /// 音量 0.0–1.0
  double get volume => _player?.volume ?? 1.0;

  /// 播放进度流
  Stream<Duration> get positionStream => _positionCtrl.stream;

  /// 总时长流
  Stream<Duration?> get durationStream => _durationCtrl.stream;

  /// 状态变化触发流（用于 setState）
  Stream<void> get stateStream => _stateCtrl.stream;

  /// Native 端通过文件路径加载
  Future<void> loadFile(String filePath) async {
    // 实际由 just_audio 的 AudioSource.file 实现
    // 这里 stub 不需要实际实现
    throw UnimplementedError('Stub should not be used directly');
  }

  /// 从 URL 加载音频（data URI 或网络 URL）
  Future<void> load(String url) async {
    _disposePlayer();
    _player = AudioPlayer();
    _setupListeners();

    try {
      await _player!.setAudioSource(AudioSource.uri(Uri.file(url)));
      _stateCtrl.add(null);
    } catch (e) {
      // just_audio 会把 error 通过 stateStream 广播，我们在这里也抛一下
      rethrow;
    }
  }

  /// 播放
  Future<void> play() async {
    await _player?.play();
  }

  /// 暂停
  void pause() {
    _player?.pause();
  }

  /// 停止
  void stop() {
    _player?.stop();
    _positionCtrl.add(Duration.zero);
    _stateCtrl.add(null);
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _player?.setVolume(volume.clamp(0.0, 1.0));
    _stateCtrl.add(null);
  }

  /// 设置播放速度
  void setPlaybackSpeed(double speed) {
    _player?.setSpeed(speed);
  }

  /// 释放资源
  void dispose() {
    _disposePlayer();
  }

  void _setupListeners() {
    _posSub = _player!.positionStream.listen((pos) {
      _positionCtrl.add(pos);
    });
    _durSub = _player!.durationStream.listen((dur) {
      _durationCtrl.add(dur);
    });
    _stateSub = _player!.playerStateStream.listen((_) {
      _stateCtrl.add(null);
    });
  }

  void _disposePlayer() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _posSub = null;
    _durSub = null;
    _stateSub = null;
    _player?.dispose();
    _player = null;
  }
}

// ===========================================================================
// 简单播放辅助函数（无 UI）
// ===========================================================================

/// 播放音频字节（创建 data URI 并通过 just_audio 播放）
void playAudioBytes(Uint8List data, String mimeType) {
  stopAudio();
  final uri = Uri.dataFromBytes(data, mimeType: mimeType);
  _getOrCreatePlayer().setAudioSource(AudioSource.uri(uri));
  _getOrCreatePlayer().play();
}

/// 从 URL 播放音频
void playAudioUrl(String url) {
  stopAudio();
  _getOrCreatePlayer().setAudioSource(AudioSource.uri(Uri.parse(url)));
  _getOrCreatePlayer().play();
}

/// 从字节创建音频 URL（data URI）
String createAudioUrl(Uint8List data, String mimeType) {
  return Uri.dataFromBytes(data, mimeType: mimeType).toString();
}

/// Native: 下载到本地通过文件选择器实现（在 tts_page.dart 中处理）
void downloadAudioFile(Uint8List data, String fileName, String mimeType) {
  throw UnsupportedError('Native 平台使用 file_picker + dart:io 下载');
}

/// 停止当前音频播放
void stopAudio() {
  _globalPlayer?.stop();
  _globalPlayer?.dispose();
  _globalPlayer = null;
}

/// 全局播放器实例（用于 playAudioBytes / playAudioUrl 辅助函数）
AudioPlayer? _globalPlayer;

AudioPlayer _getOrCreatePlayer() {
  _globalPlayer ??= AudioPlayer();
  return _globalPlayer!;
}
