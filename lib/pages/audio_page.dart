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
  String? _errorMessage;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;

  // 临时配置状态
  bool _useTempConfigForSession = true; // true: 本次应用期间, false: 本次音频
  Map<String, dynamic> _tempTTSConfig = {
    'voice': 'female',
    'speed': 1.0,
    'volume': 1.0,
    'format': 'wav',
    'sampleRate': 24000,
  };
  bool _showTempConfigPanel = false;

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

      // 初始化音频播放器
      try {
        await _audioPlayerService.initialize();
      } catch (e) {
        debugPrint('音频播放器初始化失败: $e');
        // 音频播放器失败不影响主要功能，继续
      }

      // 只有新TTS服务失败时才显示错误
      if (!_newTtsAvailable) {
        if (mounted) {
          setState(() {
            _errorMessage = 'TTS服务初始化失败，语音功能可能不可用';
          });
        }
      }

      // 检查API密钥状态
      _checkApiKeyStatus();

      // 从全局配置初始化临时配置
      _initTempConfigFromGlobal();


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
                  const Expanded(
                    child: Text('API密钥未配置，TTS功能可能受限'),
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

    // 检查新TTS服务是否可用
    if (!_newTtsAvailable) {
      _showErrorSnackBar('TTS服务不可用，请检查配置');
      return;
    }

    // 检查API密钥是否配置
    final hasApiKey = ref.read(ttsConfigProvider.notifier).hasApiKey();
    if (!hasApiKey) {
      _showApiKeyMissingDialog();
      return;
    }

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
          // 获取TTS配置，使用临时配置覆盖
          final config = ref.read(ttsConfigProvider);
          final ttsParams = new_tts.TTSParams(
            text: text,
            provider: config.providerType,
            apiKey: config.apiKey,
            voice: _tempTTSConfig['voice'] as String,
            speed: _tempTTSConfig['speed'] as double,
            volume: _tempTTSConfig['volume'] as double,
            format: _tempTTSConfig['format'] as String,
            sampleRate: _tempTTSConfig['sampleRate'] as int,
          );

          filePath = await _newTtsService.synthesizeToFile(text, params: ttsParams);
          debugPrint('新TTS服务合成成功: $filePath');
        } catch (e) {
          final errorInfo = _classifyTtsError(e);
          debugPrint('新TTS服务合成失败: $errorInfo');

          // 重新抛出错误，不再尝试后备服务
          rethrow;
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
              _showTTSConfigDialog(context);
            },
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  /// 显示TTS配置对话框
  void _showTTSConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TTSConfigDialog(),
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
                    onPressed: () => _showTTSConfigDialog(context),
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

            // Text input section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '生成录音',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(_showTempConfigPanel ? Icons.expand_less : Icons.settings),
                            onPressed: () {
                              setState(() {
                                _showTempConfigPanel = !_showTempConfigPanel;
                              });
                            },
                            tooltip: '临时配置',
                          ),
                        ],
                      ),
                      if (_showTempConfigPanel) ...[
                        const SizedBox(height: 12),
                        _buildTempConfigPanel(context),
                        const SizedBox(height: 12),
                      ],
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

  /// 构建临时配置面板
  Widget _buildTempConfigPanel(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '临时配置',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Switch(
                  value: _useTempConfigForSession,
                  onChanged: (value) {
                    setState(() {
                      _useTempConfigForSession = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _useTempConfigForSession ? '本次应用期间' : '仅本次音频',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            _buildTempConfigSlider(
              label: '语速',
              value: _tempTTSConfig['speed'] as double,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (value) {
                setState(() {
                  _tempTTSConfig['speed'] = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildTempConfigSlider(
              label: '音量',
              value: _tempTTSConfig['volume'] as double,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              onChanged: (value) {
                setState(() {
                  _tempTTSConfig['volume'] = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '音色',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: _tempTTSConfig['voice'] as String,
                        isExpanded: true,
                        items: ['female', 'male', 'neutral']
                            .map((voice) => DropdownMenuItem<String>(
                                  value: voice,
                                  child: Text(voice),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _tempTTSConfig['voice'] = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '采样率',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<int>(
                        value: _tempTTSConfig['sampleRate'] as int,
                        isExpanded: true,
                        items: [16000, 24000, 44100, 48000]
                            .map((rate) => DropdownMenuItem<int>(
                                  value: rate,
                                  child: Text('$rate Hz'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _tempTTSConfig['sampleRate'] = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建临时配置滑块
  Widget _buildTempConfigSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 从全局配置初始化临时配置
  void _initTempConfigFromGlobal() {
    final config = ref.read(ttsConfigProvider);
    setState(() {
      _tempTTSConfig = {
        'voice': config.voice,
        'speed': config.speed,
        'volume': config.volume,
        'format': config.format,
        'sampleRate': config.sampleRate,
      };
    });
  }




}
