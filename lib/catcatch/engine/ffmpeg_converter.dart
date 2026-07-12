/// 格式转换器
///
/// 将下载的 TS 分段合并/转换为 MP4。
/// 使用 fvp 底层的 mdk.Player 编码引擎进行转换。
///
/// ## 平台差异
/// - **Native** (`dart.library.io`): 使用 [ffmpeg_converter_io.dart]，
///   通过 `package:fvp/mdk.dart` 进行实际转换。
/// - **Web** (`dart.library.html`): 使用 [ffmpeg_converter_stub.dart]，
///   抛出 [UnsupportedError]，因为 Web 不支持文件系统媒体转换。
export 'ffmpeg_converter_io.dart'
    if (dart.library.html) 'ffmpeg_converter_stub.dart';
