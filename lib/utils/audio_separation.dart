/// 音频分离引擎
///
/// 暂不可用（FFmpeg 未集成到应用中）。
/// 使用条件导出实现平台适配：
/// - `dart.library.io` (原生平台): `audio_separation_native.dart`
/// - `dart.library.html` (Web): `audio_separation_web.dart`
export 'audio_separation_native.dart'
    if (dart.library.html) 'audio_separation_web.dart';
