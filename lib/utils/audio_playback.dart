/// 跨平台音频播放
/// Web: 使用 HTML5 Audio 元素
/// Native: 空实现（需接入 just_audio 等原生播放器）
export 'audio_playback_stub.dart'
    if (dart.library.html) 'audio_playback_web.dart';
