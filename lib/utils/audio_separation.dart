/// 音频分离引擎
///
/// 跨平台音频分离功能，无需用户额外安装 FFmpeg：
/// - Android/iOS/macOS：使用 ffmpeg_kit_flutter 内置 FFmpeg
/// - Windows/Linux：使用 asset 中捆绑的 FFmpeg 二进制文件
/// - Web：使用 ffmpeg.wasm（WebAssembly，首次需从 CDN 下载约 31MB）
///
/// 使用条件导出实现平台适配：
/// - `dart.library.io` (原生平台): `audio_separation_native.dart`
/// - `dart.library.html` (Web): `audio_separation_web.dart`
export 'audio_separation_native.dart'
    if (dart.library.html) 'audio_separation_web.dart';
