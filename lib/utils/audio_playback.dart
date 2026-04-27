/// 跨平台音频播放
/// Web: 使用 HTML5 Audio 元素
/// Native: 使用 just_audio
export 'audio_playback_stub.dart'
    if (dart.library.html) 'audio_playback_web.dart';
