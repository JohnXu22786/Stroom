/// 音频分离引擎
///
/// 跨平台音频分离功能：
/// - 桌面端 (Win/Mac/Linux)：使用系统 FFmpeg 或内置 FFmpeg
/// - 移动端 (Android/iOS)：使用系统 FFmpeg 或内置 FFmpeg
/// - Web 端：使用纯 Dart 方式（仅支持音频格式转换）
///
/// 使用条件导出实现平台适配：
/// - `dart.library.io` (原生平台): `audio_separation_native.dart`
/// - `dart.library.html` (Web): `audio_separation_web.dart`
export 'audio_separation_native.dart'
    if (dart.library.html) 'audio_separation_web.dart';
