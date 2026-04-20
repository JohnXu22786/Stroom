import 'dart:async';
import 'dart:typed_data';

/// TTS供应商抽象基类
///
/// 采用策略模式(Strategy Pattern)设计，为不同的语音合成服务提供统一的调用接口，
/// 同时允许具体供应商实现针对各自API优化的内部逻辑。
///
/// 所有具体供应商必须继承此类并实现所有抽象方法和属性。
abstract class TTSProvider {
  /// 供应商名称（对应TTSProvider枚举中的值）
  String get name;

  /// 支持的模型列表
  List<String> get supportedModels;

  /// 默认参数配置
  /// 具体供应商可以重写此getter来提供供应商特定的默认参数
  Map<String, dynamic> get defaultParams => const {};

  /// 合成语音，返回音频字节数据
  ///
  /// [text] 要合成的文本
  /// [kwargs] 合成参数（语音、速度、音量、格式等）
  ///
  /// 返回包含完整音频数据的Future
  Future<Uint8List> synthesize(String text, [Map<String, dynamic>? kwargs]);

  /// 流式合成语音，返回音频数据流
  ///
  /// [text] 要合成的文本
  /// [kwargs] 合成参数
  ///
  /// 返回音频数据块的Stream，支持实时播放
  Stream<Uint8List> streamSynthesize(String text, [Map<String, dynamic>? kwargs]);

  /// 验证并合并参数
  ///
  /// [kwargs] 用户提供的参数
  ///
  /// 返回验证后的完整参数集
  /// 具体供应商可以重写此方法以添加供应商特定的验证逻辑
  Map<String, dynamic> validateParams(Map<String, dynamic>? kwargs) {
    final params = Map<String, dynamic>.from(defaultParams);

    // 合并用户提供的参数，用户参数覆盖默认参数
    if (kwargs != null) {
      params.addAll(kwargs);
    }

    return params;
  }

  /// 获取供应商的字符串表示，便于调试
  @override
  String toString() {
    return '$runtimeType(name: "$name", supportedModels: $supportedModels)';
  }
}
