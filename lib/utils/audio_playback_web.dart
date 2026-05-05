import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// 全局 Audio 元素（用于 playAudioBytes / playAudioUrl / stopAudio）
html.AudioElement? _globalAudio;

// ===========================================================================
// AudioPlayerAdapter — 用于 AudioPlayerPage 的跨平台播放器
// ===========================================================================

/// Web 实现：使用 HTML5 AudioElement
class AudioPlayerAdapter {
  html.AudioElement? _audio;
  Timer? _positionTimer;
  bool _playing = false;

  final StreamController<Duration> _positionCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationCtrl =
      StreamController<Duration?>.broadcast();
  final StreamController<void> _stateCtrl =
      StreamController<void>.broadcast();

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

  /// 从 URL 加载音频
  Future<void> load(String url) async {
    _audio?.pause();
    _audio = html.AudioElement();
    _audio!.src = url;
    _audio!.preload = 'auto';

    final completer = Completer<void>();
    StreamSubscription? errSub;
    StreamSubscription? canPlaySub;
    StreamSubscription? metaSub;

    void onLoad() {
      errSub?.cancel();
      canPlaySub?.cancel();
      metaSub?.cancel();
      if (!completer.isCompleted) completer.complete();
    }

    void onError(html.Event event) {
      errSub?.cancel();
      canPlaySub?.cancel();
      metaSub?.cancel();
      if (!completer.isCompleted) {
        final mediaError = _audio?.error;
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
        completer.completeError(
          Exception('加载音频失败：$fullMsg'),
        );
      }
    }

    errSub = _audio!.onError.listen(onError);
    canPlaySub = _audio!.onCanPlay.listen((_) => onLoad());
    metaSub = _audio!.onLoadedMetadata.listen((_) => onLoad());

    await completer.future.timeout(const Duration(seconds: 30),
        onTimeout: onLoad);

    // 通知时长
    final seconds = _audio!.duration;
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

  /// 播放
  Future<void> play() async {
    if (_audio == null) return;
    _playing = true;
    _audio!.play();
    _stateCtrl.add(null);
  }

  /// 暂停
  void pause() {
    if (_audio == null) return;
    _playing = false;
    _audio!.pause();
    _stateCtrl.add(null);
  }

  /// 停止
  void stop() {
    if (_audio == null) return;
    _playing = false;
    _audio!.pause();
    _audio!.currentTime = 0;
    _positionCtrl.add(Duration.zero);
    _stateCtrl.add(null);
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

  /// 释放资源
  void dispose() {
    _audio?.pause();
    _positionTimer?.cancel();
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
  html.Url.revokeObjectUrl(url);
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
