import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../providers/audio_provider.dart';
import '../providers/tts_config_provider.dart';
import '../services/tts_service.dart';
import '../services/audio_player_service.dart';
import '../tts/services/tts_service.dart' as new_tts;
import 'widgets/tts_config_panel.dart';

/// TTS错误类型
enum TtsErrorType {
  apiKeyMissing,
  networkError,
  providerUnavailable,
  quotaExceeded,
  unknown,
}

/// TTS错误信息
class TtsErrorInfo {
  final TtsErrorType type;
  final String message;
  final String solution;
  final bool shouldShowConfigButton;

  const TtsErrorInfo({
    required this.type,
    required this.message,
    required this.solution,
    required this.shouldShowConfigButton,
  });

  @override
  String toString() => '$message ($solution)';
}

class AudioPage extends ConsumerStatefulWidget {
  const AudioPage({super.key});

  @override
  ConsumerState<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends ConsumerState<AudioPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final TTSService _ttsService = TTSService();
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final new_tts.TTSService _newTtsService = new_tts.TTSService();

  bool _isGenerating = false;
  bool _newTtsAvailable = false;
  bool _oldTtsAvailable = true;
  String? _errorMessage;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _textFocusNode.dispose();
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _ttsService.dispose();
    _audioPlayerService.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      // 尝试初始化新TTS服务
      try {
        await _newTtsService.initialize();
        _newTtsAvailable = true;
        debugPrint('新TTS服务初始化成功');
      } catch (e) {
        _newTtsAvailable = false;
        final errorMessage = _classifyTtsError(e);
        debugPrint('新TTS服务初始化失败: $errorMessage, 使用旧TTS服务作为后备');
      }

      // 始终初始化旧TTS服务作为后备
      try {
        await _ttsService.initialize();
        _oldTtsAvailable = true;
        debugPrint('旧TTS服务初始化成功');
      } catch (e) {
        _oldTtsAvailable = false;
        debugPrint('旧TTS服务初始化失败: $e');
      }

      // 初始化音频播放器
      try {
        await _audioPlayerService.initialize();
      } catch (e) {
        debugPrint('音频播放器初始化失败: $e');
        // 音频播放器失败不影响主要功能，继续
      }

      // 只有两个服务都失败时才显示错误
      if (!_newTtsAvailable && !_oldTtsAvailable) {
        if (mounted) {
          setState(() {
            _errorMessage = 'TTS服务初始化失败，语音功能可能不可用';
          });
        }
      }

      // 检查API密钥状态
      _checkApiKeyStatus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '服务初始化失败: $e';
        });
      }
    }
  }

  /// 检查API密钥状态并显示相应提示
  void _checkApiKeyStatus() {
    if (!mounted) return;


    final notifier = ref.read(ttsConfigProvider.notifier);
    final hasApiKey = notifier.hasApiKey();

    if (_newTtsAvailable && !hasApiKey) {
      // 新TTS服务可用但API密钥未配置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('TTS服务已就绪，但需要配置API密钥以获得完整功能'),
                        const SizedBox(height: 4),
                        Text(
                          '当前使用模拟模式，音频质量有限',
                          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue[50],
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: '去配置',
                textColor: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  _showApiKeyMissingDialog();
                },
              ),
            ),
          );
        }
      });
    }
  }

  /// Generate audio from text using TTS
  Future<void> _generateAudio() async {
    final text = _textEditingController.text.trim();
    if (text.isEmpty) {
      _showErrorSnackBar('请输入文本内容');
      return;
    }

    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    ref.read(audioProvider.notifier).setGeneratingTTS(true);

    try {
      String? filePath;

      // 优先使用新TTS服务，如果可用
      if (_newTtsAvailable) {
        try {
          // 获取TTS配置
          final config = ref.read(ttsConfigProvider);
          final ttsParams = new_tts.TTSParams(
            text: text,
            provider: config.providerType,
            apiKey: config.apiKey,
            voice: config.voice,
            speed: config.speed,
            volume: config.volume,
            format: config.format,
            sampleRate: config.sampleRate,
          );

          filePath = await _newTtsService.synthesizeToFile(text, params: ttsParams);
          debugPrint('新TTS服务合成成功: $filePath');
        } catch (e) {
          final errorInfo = _classifyTtsError(e);
          debugPrint('新TTS服务合成失败: $errorInfo, 使用旧TTS服务作为后备');

          // 如果是API密钥缺失错误，显示引导信息
          if (_isApiKeyMissingError(e)) {
            _showApiKeyMissingWarning();
            // 仍然尝试使用旧TTS服务作为后备
          }

          // 标记新TTS服务为不可用，下次尝试使用旧服务
          _newTtsAvailable = false;
        }
      }

      // 如果新TTS服务失败或不可用，使用旧TTS服务
      if (filePath == null && _oldTtsAvailable) {
        try {
          filePath = await _ttsService.synthesizeToFile(text);
          debugPrint('旧TTS服务合成成功: $filePath');
        } catch (e) {
          debugPrint('旧TTS服务合成失败: $e');
          throw Exception('所有TTS服务都不可用: $e');
        }
      }

      // 如果两个服务都失败
      if (filePath == null) {
        throw Exception('生成音频文件失败: 无可用TTS服务');
      }

      // Get file duration (placeholder for now, should get actual duration)
      const duration = 5; // Placeholder duration in seconds

      // Add recording to state
      await ref.read(audioProvider.notifier).addRecording(
        text: text,
        filePath: filePath,
        duration: duration,
        language: 'zh-CN',
      );

      // Clear text input
      _textEditingController.clear();

      // Show success message
      _showSuccessSnackBar('录音生成成功');
    } catch (e) {
      final errorInfo = _classifyTtsError(e);
      _errorMessage = '生成录音失败: ${errorInfo.message}';
      _showErrorSnackBar('生成录音失败: ${errorInfo.message}');

      // 如果是API密钥缺失，显示额外的引导信息
      if (_isApiKeyMissingError(e)) {
        _showApiKeyMissingDialog();
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
      ref.read(audioProvider.notifier).setGeneratingTTS(false);
    }
  }

  /// 生成测试音频录音
  Future<void> _generateTestAudio() async {
    const testText = '这是一个测试录音，用于验证TTS服务功能是否正常工作。';
    _textEditingController.text = testText;
    await _generateAudio();
  }

  /// 分类TTS错误，提供友好的错误信息
  TtsErrorInfo _classifyTtsError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // 检查API密钥缺失
    if (errorString.contains('api key') ||
        errorString.contains('apikey') ||
        errorString.contains('unauthorized') ||
        errorString.contains('authentication') ||
        errorString.contains('403') ||
        errorString.contains('401')) {
      return const TtsErrorInfo(
        type: TtsErrorType.apiKeyMissing,
        message: 'API密钥缺失或无效',
        solution: '请前往TTS配置面板设置有效的API密钥',
        shouldShowConfigButton: true,
      );
    }

    // 检查网络错误
    if (error is SocketException ||
        errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return const TtsErrorInfo(
        type: TtsErrorType.networkError,
        message: '网络连接失败',
        solution: '请检查网络连接并重试',
        shouldShowConfigButton: false,
      );
    }

    // 检查供应商不可用
    if (errorString.contains('provider') ||
        errorString.contains('service unavailable') ||
        errorString.contains('503') ||
        errorString.contains('server error')) {
      return const TtsErrorInfo(
        type: TtsErrorType.providerUnavailable,
        message: 'TTS服务暂时不可用',
        solution: '请稍后重试，或切换到其他供应商',
        shouldShowConfigButton: true,
      );
    }

    // 检查额度不足
    if (errorString.contains('quota') ||
        errorString.contains('limit') ||
        errorString.contains('exceeded') ||
        errorString.contains('insufficient')) {
      return const TtsErrorInfo(
        type: TtsErrorType.quotaExceeded,
        message: 'API调用额度已用完',
        solution: '请等待额度恢复或升级服务',
        shouldShowConfigButton: true,
      );
    }

    // 默认错误
    return TtsErrorInfo(
      type: TtsErrorType.unknown,
      message: '未知错误: $error',
      solution: '请检查配置并重试',
      shouldShowConfigButton: false,
    );
  }

  /// 检查是否是API密钥缺失错误
  bool _isApiKeyMissingError(dynamic error) {
    final errorInfo = _classifyTtsError(error);
    return errorInfo.type == TtsErrorType.apiKeyMissing;
  }

  /// 显示API密钥缺失警告
  void _showApiKeyMissingWarning() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('API密钥未配置，TTS功能可能受限'),
            ),
          ],
        ),
        backgroundColor: Colors.amber[50],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '去配置',
          textColor: Theme.of(context).colorScheme.primary,
          onPressed: () {
            _showApiKeyMissingDialog();
          },
        ),
      ),
    );
  }

  /// 显示API密钥缺失对话框
  void _showApiKeyMissingDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Colors.amber),
            SizedBox(width: 8),
            Text('API密钥配置'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('要使用TTS功能，需要配置API密钥：'),
            SizedBox(height: 12),
            Text('1. 从TTS供应商处获取API密钥'),
            Text('2. 在配置面板中输入API密钥'),
            Text('3. 保存配置后即可使用'),
            SizedBox(height: 16),
            Text(
              '提示：旧版TTS服务仍可使用，但功能有限',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后配置'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              TTSConfigDialog.show(context);
            },
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  /// Play or pause a recording
  Future<void> _togglePlayback(Recording recording) async {
    final audioState = ref.read(audioProvider);
    final notifier = ref.read(audioProvider.notifier);

    // If this recording is already playing, pause it
    if (audioState.currentRecordingId == recording.id &&
        audioState.playbackState == PlaybackState.playing) {
      await _audioPlayerService.pause();
      notifier.pausePlayback();
      return;
    }

    // If this recording is paused, resume it
    if (audioState.currentRecordingId == recording.id &&
        audioState.playbackState == PlaybackState.paused) {
      await _audioPlayerService.play(recording.filePath);
      notifier.startPlayback(recording.id);
      return;
    }

    // If another recording is playing, stop it first
    if (audioState.currentRecordingId != null) {
      await _audioPlayerService.stop();
    }

    // Start playing this recording
    try {
      await _audioPlayerService.play(recording.filePath);
      notifier.startPlayback(recording.id);
    } catch (e) {
      _showErrorSnackBar('播放失败: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final audioState = ref.watch(audioProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '录音',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (audioState.recordings.isNotEmpty)
                    Text(
                      '${audioState.recordings.length} 个录音',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings, size: 20),
                    onPressed: () => TTSConfigDialog.show(context),
                    tooltip: 'TTS供应商配置',
                  ),
                ],
              ),
            ),

            // Error display
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // TTS Configuration panel
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              child: TTSConfigPanel(
                initiallyExpanded: true,
                onConfigSaved: () {
                  // 配置保存后重新初始化服务
                  _initializeServices();
                },
              ),
            ),

            // TTS服务状态显示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TTS服务状态',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // 新TTS服务状态
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _newTtsAvailable ? Colors.green.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _newTtsAvailable ? Colors.green.shade200 : Colors.orange.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _newTtsAvailable ? Icons.check_circle : Icons.warning,
                                        size: 16,
                                        color: _newTtsAvailable ? Colors.green.shade700 : Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '新TTS服务',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _newTtsAvailable ? Colors.green.shade800 : Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _newTtsAvailable ? '已启用' : '未配置',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _newTtsAvailable ? Colors.green.shade600 : Colors.orange.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 旧TTS服务状态
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _oldTtsAvailable ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _oldTtsAvailable ? Colors.green.shade200 : Colors.red.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _oldTtsAvailable ? Icons.check_circle : Icons.error,
                                        size: 16,
                                        color: _oldTtsAvailable ? Colors.green.shade700 : Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '旧TTS服务',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _oldTtsAvailable ? Colors.green.shade800 : Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _oldTtsAvailable ? '已启用' : '不可用',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _oldTtsAvailable ? Colors.green.shade600 : Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // API密钥状态
                      Consumer(
                        builder: (context, ref, child) {
                          final config = ref.watch(ttsConfigProvider);
                          final hasApiKey = config.apiKey != null && config.apiKey!.isNotEmpty;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: hasApiKey ? Colors.blue.shade50 : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: hasApiKey ? Colors.blue.shade200 : Colors.amber.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      hasApiKey ? Icons.key : Icons.key_off,
                                      size: 16,
                                      color: hasApiKey ? Colors.blue.shade700 : Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'API密钥',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: hasApiKey ? Colors.blue.shade800 : Colors.amber.shade800,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hasApiKey ? Colors.blue.shade100 : Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        config.providerDisplayName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: hasApiKey ? Colors.blue.shade600 : Colors.amber.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasApiKey ? '已配置' : '未配置',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasApiKey ? Colors.blue.shade600 : Colors.amber.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 测试按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateTestAudio,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('测试TTS服务'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            // Text input section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '生成录音',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _textEditingController,
                        focusNode: _textFocusNode,
                        maxLines: 4,
                        minLines: 2,
                        decoration: const InputDecoration(
                          hintText: '输入要转换为语音的文本...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onSubmitted: (_) => _generateAudio(),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isGenerating ? null : _generateAudio,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isGenerating
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('生成中...'),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mic),
                                  SizedBox(width: 8),
                                  Text('生成录音'),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Recording list header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '录音列表',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (audioState.recordings.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('清空所有录音'),
                            content: const Text('确定要删除所有录音吗？此操作不可撤销。'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('清空', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await ref.read(audioProvider.notifier).clearRecordings();
                          _showSuccessSnackBar('所有录音已清空');
                        }
                      },
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: const Text('清空'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
            ),

            // Recording list
            Expanded(
              child: audioState.recordings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.audiotrack,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '还没有录音',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '输入文本并点击"生成录音"开始创建',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(audioProvider.notifier).loadRecordings(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: audioState.recordings.length,
                        itemBuilder: (context, index) {
                          final recording = audioState.recordings[index];
                          return _buildRecordingItem(recording, audioState);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build recording list item
  Widget _buildRecordingItem(Recording recording, AudioState audioState) {
    final isCurrentRecording = audioState.currentRecordingId == recording.id;
    final isPlaying = isCurrentRecording && audioState.playbackState == PlaybackState.playing;
    final isPaused = isCurrentRecording && audioState.playbackState == PlaybackState.paused;
    final position = isCurrentRecording ? audioState.playbackPosition : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _togglePlayback(recording),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : isPaused
                            ? Icons.play_circle_filled
                            : Icons.play_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recording.text.length > 50
                              ? '${recording.text.substring(0, 50)}...'
                              : recording.text,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${recording.duration}秒 • ${_formatDateTime(recording.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteRecording(recording.id),
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    tooltip: '删除录音',
                  ),
                ],
              ),
              if (isCurrentRecording)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                    value: position,
                    backgroundColor: Colors.grey[200],
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      return '今天 ${_formatTime(dateTime)}';
    } else if (date == yesterday) {
      return '昨天 ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.month}/${dateTime.day} ${_formatTime(dateTime)}';
    }
  }

  /// Format time for display
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Delete a recording
  Future<void> _deleteRecording(String recordingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除录音'),
        content: const Text('确定要删除这个录音吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(audioProvider.notifier).deleteRecording(recordingId);
      _showSuccessSnackBar('录音已删除');
    }
  }
}
