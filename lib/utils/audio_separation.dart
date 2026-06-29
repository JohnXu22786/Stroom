/// 音频分离引擎
///
/// 纯 Dart 实现的 MP4/ISOBMFF 容器解析和音频提取引擎。
/// 基于 FFmpeg 的 demux 思路：解析容器 → 找到音频流 → 提取音频数据。
///
/// 所有平台通用，无需系统组件或外部 FFmpeg 安装。
export 'audio_separation_native.dart';
