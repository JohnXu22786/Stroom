/// 音频分离引擎
///
/// 使用 media_kit 组件实现音频提取。
/// - 原生平台: 通过 media_kit 的 Player + mpv 编码功能输出音频文件
/// - Web: 通过 Web Audio API 提取音频轨道
export 'audio_separation_native.dart'
    if (dart.library.html) 'audio_separation_web.dart';
