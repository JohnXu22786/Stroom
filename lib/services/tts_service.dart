import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// TTS服务类，封装文本转语音功能
class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  /// 初始化TTS引擎
  Future<void> initialize() async {
    try {
      // 设置默认参数
      await _tts.setLanguage("zh-CN");
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.5);

      _isInitialized = true;
      print('TTS服务初始化成功');
    } catch (e) {
      print('TTS服务初始化失败: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// 检查TTS是否可用
  Future<bool> isAvailable() async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        return false;
      }
    }
    return _isInitialized;
  }

  /// 获取支持的语音列表
  Future<List<dynamic>> getAvailableVoices() async {
    if (!_isInitialized) {
      await initialize();
    }
    try {
      return await _tts.getVoices;
    } catch (e) {
      print('获取语音列表失败: $e');
      return [];
    }
  }

  /// 获取支持的语言列表
  Future<List<dynamic>> getAvailableLanguages() async {
    if (!_isInitialized) {
      await initialize();
    }
    try {
      return await _tts.getLanguages;
    } catch (e) {
      print('获取语言列表失败: $e');
      return [];
    }
  }

  /// 将文本转换为语音并保存到文件
  /// 返回保存的文件路径
  Future<String?> synthesizeToFile(String text, {String? fileName}) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 创建音频目录
      final appDir = await getApplicationSupportDirectory();
      final audioDir = Directory(path.join(appDir.path, 'audio'));
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      // 生成文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFileName = fileName ?? 'recording_$timestamp';
      final filePath = path.join(audioDir.path, '$safeFileName.mp3');

      // TODO: 实现实际的TTS合成和保存
      // 由于API暂时不编写，这里返回模拟文件路径
      print('模拟生成音频文件: $filePath for text: $text');

      // 模拟生成一个空的音频文件（实际使用时应调用TTS引擎）
      final file = File(filePath);
      await file.writeAsBytes([]); // 空文件占位

      return filePath;
    } catch (e) {
      print('TTS合成失败: $e');
      return null;
    }
  }

  /// 播放文本（不保存文件）
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _tts.speak(text);
    } catch (e) {
      print('播放语音失败: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      print('停止播放失败: $e');
    }
  }

  /// 设置语言
  Future<void> setLanguage(String languageCode) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _tts.setLanguage(languageCode);
    } catch (e) {
      print('设置语言失败: $e');
    }
  }

  /// 设置语速 (0.0 - 1.0)
  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      print('设置语速失败: $e');
    }
  }

  /// 设置音调 (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _tts.setPitch(pitch);
    } catch (e) {
      print('设置音调失败: $e');
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _tts.setVolume(volume);
    } catch (e) {
      print('设置音量失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _tts.stop();
    _isInitialized = false;
  }
}
