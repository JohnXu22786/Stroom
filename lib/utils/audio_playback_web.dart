import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// 全局 Audio 元素（用于 playAudioBytes / playAudioUrl / stopAudio）
html.AudioElement? _globalAudio;

class _PendingAudioLoad {
  final Completer<void> completer = Completer<void>();
  final List<StreamSubscription<html.Event>> subscriptions = [];

  void cancel() {
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    subscriptions.clear();
    if (!completer.isCompleted) completer.complete();
  }
}

// ===========================================================================
// AudioPlayerAdapter — 用于 AudioPlayerPage 的跨平台播放器
// ===========================================================================

/// Web 实现：使用 HTML5 AudioElement
class AudioPlayerAdapter {
  AudioPlayerAdapter({html.AudioElement Function()? createAudio})
      : _createAudio = createAudio ?? html.AudioElement.new;

  final html.AudioElement Function() _createAudio;
  html.AudioElement? _audio;
  _PendingAudioLoad? _pendingLoad;
  String? _streamObjectUrl;
  StreamSubscription<Uint8List>? _streamInputSubscription;
  StreamSubscription<html.Event>? _streamEndedSubscription;
  StreamSubscription<html.Event>? _streamErrorSubscription;
  Completer<void>? _streamInputDone;
  Completer<void>? _streamPlaybackDone;
  int _loadGeneration = 0;
  bool _disposed = false;
  Timer? _positionTimer;
  StreamSubscription<html.Event>? _endedSub;
  bool _playing = false;
  bool _streamInputCancelled = false;
  bool _streamLoadInProgress = false;

  final StreamController<Duration> _positionCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationCtrl =
      StreamController<Duration?>.broadcast();
  final StreamController<void> _stateCtrl = StreamController<void>.broadcast();

  /// 当前播放状态
  bool get playing => _playing;

  /// 音量 0.0–1.0
  double get volume => (_audio?.volume ?? 1.0).toDouble();

  /// 播放进度流
  Stream<Duration> get positionStream => _positionCtrl.stream;

  /// 总时长流
  Stream<Duration?> get durationStream => _durationCtrl.stream;

  /// 状态变化触发流（用于 setState）
  Stream<void> get stateStream => _stateCtrl.stream;

  /// Native 端通过文件路径加载（Web 端不使用，留空）
  Future<void> loadFile(String filePath) async {
    // Web 端不支持直接加载文件路径，抛出错误
    throw UnsupportedError('Web 不支持直接加载文件路径');
  }

  /// 从 URL 加载音频
  Future<void> load(String url) async {
    if (_disposed) return;

    final isStreamLoad = _streamLoadInProgress && url == _streamObjectUrl;
    if (!isStreamLoad &&
        (_streamInputSubscription != null ||
            _streamLoadInProgress ||
            _streamPlaybackDone != null)) {
      final wasLoadingStream = _streamLoadInProgress;
      _cancelStreamPlayback();
      if (wasLoadingStream) {
        _pendingLoad?.cancel();
        _pendingLoad = null;
        _loadGeneration++;
        _streamLoadInProgress = false;
      }
      _playing = false;
      _stateCtrl.add(null);
    }

    final previousStreamObjectUrl = _streamObjectUrl;
    if (previousStreamObjectUrl != null && previousStreamObjectUrl != url) {
      html.Url.revokeObjectUrl(previousStreamObjectUrl);
      _streamObjectUrl = null;
    }

    final generation = ++_loadGeneration;
    _pendingLoad?.cancel();
    _pendingLoad = null;
    unawaited(_endedSub?.cancel());
    _endedSub = null;
    _audio?.pause();
    final audio = _createAudio();
    _audio = audio;
    _endedSub = audio.onEnded.listen((_) {
      if (_disposed || !identical(_audio, audio)) return;

      _playing = false;
      final seconds =
          audio.duration.isFinite ? audio.duration : audio.currentTime;
      _positionCtrl.add(Duration(milliseconds: (seconds * 1000).toInt()));
      _stateCtrl.add(null);
    });
    audio.src = url;
    audio.preload = 'auto';

    final attempt = _PendingAudioLoad();
    _pendingLoad = attempt;

    bool isCurrent() =>
        !_disposed && generation == _loadGeneration && identical(_audio, audio);

    void onLoad() {
      attempt.cancel();
      if (identical(_pendingLoad, attempt)) _pendingLoad = null;
    }

    void onError(html.Event event) {
      if (!isCurrent()) {
        onLoad();
        return;
      }
      if (!attempt.completer.isCompleted) {
        final mediaError = audio.error;
        final errorCode = mediaError?.code ?? -1;
        final errorMsg = mediaError?.message ?? '';
        String detail;
        switch (errorCode) {
          case 1:
            detail = '获取音频被中断';
            break;
          case 2:
            detail = '网络错误';
            break;
          case 3:
            detail = '音频解码失败，浏览器不支持该格式';
            break;
          case 4:
            detail = '浏览器不支持该音频格式';
            break;
          default:
            detail = '未知错误';
        }
        final fullMsg = errorMsg.isNotEmpty ? '$detail（$errorMsg）' : detail;
        attempt.completer.completeError(Exception('加载音频失败：$fullMsg'));
      }
      for (final subscription in attempt.subscriptions) {
        unawaited(subscription.cancel());
      }
      attempt.subscriptions.clear();
      if (identical(_pendingLoad, attempt)) _pendingLoad = null;
    }

    attempt.subscriptions.add(audio.onError.listen(onError));
    attempt.subscriptions.add(audio.onCanPlay.listen((_) => onLoad()));
    attempt.subscriptions.add(audio.onLoadedMetadata.listen((_) => onLoad()));

    await attempt.completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: onLoad,
    );

    if (!isCurrent()) return;

    // 通知时长
    final seconds = audio.duration;
    final duration = seconds.isFinite
        ? Duration(milliseconds: (seconds * 1000).toInt())
        : null;
    _durationCtrl.add(duration);
    _stateCtrl.add(null);

    // 启动位置轮询
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_audio != null) {
        final pos = (_audio!.currentTime * 1000).toInt();
        _positionCtrl.add(Duration(milliseconds: pos));
      }
    });
  }

  /// Buffers streamed bytes into a browser media resource and plays it.
  /// HTMLAudioElement does not support appending arbitrary TTS chunks.
  Future<bool> playStream(
    Stream<Uint8List> chunks, {
    required String contentType,
  }) async {
    if (_disposed) return false;
    _streamInputCancelled = false;
    final bytes = BytesBuilder(copy: false);
    final inputDone = Completer<void>();
    _streamInputDone = inputDone;
    final subscription = chunks.listen(
      (chunk) {
        if (chunk.isNotEmpty) bytes.add(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!inputDone.isCompleted) inputDone.completeError(error, stackTrace);
      },
      onDone: () {
        if (!inputDone.isCompleted) inputDone.complete();
      },
    );
    _streamInputSubscription = subscription;
    try {
      await inputDone.future;
    } finally {
      if (identical(_streamInputSubscription, subscription)) {
        _streamInputSubscription = null;
        _streamInputDone = null;
      }
      await subscription.cancel();
    }
    if (_disposed || _streamInputCancelled) return false;

    _revokeStreamObjectUrl();
    final url = html.Url.createObjectUrl(
      html.Blob([bytes.takeBytes()], contentType),
    );
    _streamObjectUrl = url;
    _streamLoadInProgress = true;
    try {
      await load(url);
    } finally {
      _streamLoadInProgress = false;
    }
    if (_disposed || _streamInputCancelled) return false;

    final playbackDone = Completer<void>();
    _streamPlaybackDone = playbackDone;
    final audio = _audio!;
    final endedSubscription = audio.onEnded.listen((_) {
      if (!playbackDone.isCompleted) playbackDone.complete();
    });
    _streamEndedSubscription = endedSubscription;
    final errorSubscription = audio.onError.listen((_) {
      if (playbackDone.isCompleted) return;
      final message = audio.error?.message;
      playbackDone.completeError(
        Exception(
          message == null || message.isEmpty
              ? 'Audio playback failed'
              : 'Audio playback failed: $message',
        ),
      );
    });
    _streamErrorSubscription = errorSubscription;
    try {
      try {
        await Future.any([play(), playbackDone.future]);
      } on Object catch (error) {
        if (_isAutoplayBlocked(error)) return true;
        rethrow;
      }
      await playbackDone.future;
      return false;
    } finally {
      await endedSubscription.cancel();
      await errorSubscription.cancel();
      if (identical(_streamEndedSubscription, endedSubscription)) {
        _streamEndedSubscription = null;
        _streamErrorSubscription = null;
        _streamPlaybackDone = null;
      }
    }
  }

  /// 播放
  Future<void> play() async {
    if (_audio == null) return;
    _playing = true;
    final playback = _audio!.play();
    _stateCtrl.add(null);
    try {
      await playback;
    } catch (_) {
      _playing = false;
      _stateCtrl.add(null);
      rethrow;
    }
  }

  bool _isAutoplayBlocked(Object error) =>
      error.toString().contains('NotAllowedError');

  /// 暂停
  void pause() {
    if (_audio == null) return;
    _playing = false;
    _audio!.pause();
    _stateCtrl.add(null);
  }

  /// 停止
  void stop() {
    final wasLoadingStream = _streamLoadInProgress;
    _cancelStreamPlayback();
    if (wasLoadingStream) {
      _pendingLoad?.cancel();
      _pendingLoad = null;
      _loadGeneration++;
    }
    if (_audio != null) {
      _playing = false;
      _audio!.pause();
      _audio!.currentTime = 0;
      _positionCtrl.add(Duration.zero);
      _stateCtrl.add(null);
    }
    _revokeStreamObjectUrl();
  }

  void _revokeStreamObjectUrl() {
    final url = _streamObjectUrl;
    if (url == null) return;
    html.Url.revokeObjectUrl(url);
    _streamObjectUrl = null;
  }

  void _cancelStreamPlayback() {
    _streamInputCancelled = true;
    unawaited(_streamInputSubscription?.cancel());
    _streamInputSubscription = null;
    final inputDone = _streamInputDone;
    if (inputDone != null && !inputDone.isCompleted) inputDone.complete();
    _streamInputDone = null;
    unawaited(_streamEndedSubscription?.cancel());
    _streamEndedSubscription = null;
    unawaited(_streamErrorSubscription?.cancel());
    _streamErrorSubscription = null;
    final playbackDone = _streamPlaybackDone;
    if (playbackDone != null && !playbackDone.isCompleted) {
      playbackDone.complete();
    }
    _streamPlaybackDone = null;
  }

  /// 跳转到指定位置
  void seek(Duration position) {
    if (_audio == null) return;
    _audio!.currentTime = position.inMilliseconds / 1000;
  }

  /// 设置音量
  void setVolume(double volume) {
    if (_audio == null) return;
    _audio!.volume = volume.clamp(0.0, 1.0);
    _stateCtrl.add(null);
  }

  /// 设置播放速度
  void setPlaybackSpeed(double speed) {
    if (_audio == null) return;
    _audio!.playbackRate = speed.clamp(0.25, 4.0);
    _stateCtrl.add(null);
  }

  /// 释放资源
  Future<void> dispose() async {
    _disposed = true;
    _loadGeneration++;
    _pendingLoad?.cancel();
    _pendingLoad = null;
    unawaited(_endedSub?.cancel());
    _endedSub = null;
    _audio?.pause();
    _positionTimer?.cancel();
    _cancelStreamPlayback();
    _revokeStreamObjectUrl();
    _audio = null;
    _positionTimer = null;
    _playing = false;
  }
}

// ===========================================================================
// 简单播放辅助函数（无 UI）
// ===========================================================================

/// 使用 HTML5 Audio 元素播放音频字节（data URI 方式）
void playAudioBytes(Uint8List data, String mimeType) {
  stopAudio();
  final uri = Uri.dataFromBytes(data, mimeType: mimeType).toString();
  _globalAudio = html.AudioElement(uri);
  _globalAudio?.play();
}

/// Web: 下载音频文件到本地（浏览器下载）
void downloadAudioFile(Uint8List data, String fileName, String mimeType) {
  final blob = html.Blob([data], mimeType);
  final url = html.Url.createObjectUrl(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body!.children.add(anchor);
  anchor.click();
  html.document.body!.children.remove(anchor);
  Timer(const Duration(seconds: 1), () => html.Url.revokeObjectUrl(url));
}

/// 从 URL 播放音频
void playAudioUrl(String url) {
  stopAudio();
  _globalAudio = html.AudioElement(url);
  _globalAudio?.play();
}

/// 从字节创建音频 URL（data URI，兼容性优于 Blob URL）
String createAudioUrl(Uint8List data, String mimeType) {
  return Uri.dataFromBytes(data, mimeType: mimeType).toString();
}

/// 停止当前音频播放
void stopAudio() {
  _globalAudio?.pause();
  _globalAudio = null;
}
