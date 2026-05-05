import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import '../providers/provider_config.dart';
import '../providers/tts_state_provider.dart';
import '../utils/file_manifest.dart';
import '../utils/audio_playback.dart';
import '../utils/audio_utils.dart';
import 'tts_create_page.dart';

/// 音频播放器页面
/// 跨平台：Web 用 HTML5 AudioElement，Native 用 just_audio
class AudioPlayerPage extends ConsumerStatefulWidget {
  final String filePath;
  final String? displayName;

  const AudioPlayerPage({
    super.key,
    required this.filePath,
    this.displayName,
  });

  @override
  ConsumerState<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends ConsumerState<AudioPlayerPage> {
  AudioPlayerAdapter? _player;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _diagnosticInfo = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // 源文本
  String _sourceText = '';
  bool _textLoading = true;
  final _textController = TextEditingController();
  double _fontSize = 14;
  static const double _minFontSize = 10;
  static const double _maxFontSize = 28;

  // 哈希校验
  String _expectedHash = '';
  Uint8List? _rawAudioData;
  bool _hashVerified = true;
  bool _hashCheckDone = false;

  // 播放器折叠状态
  bool _playerExpanded = true;
  static const double _playerCollapsedH = 52;
  static const double _playerExpandedH = 200;
  static const double _playerMargin = 8;

  double get _playerCurrentH =>
      _playerExpanded ? _playerExpandedH : _playerCollapsedH;

  /// 文本区的底部内边距（给播放器面板+间距让位）
  double get _textBottomPadding => _playerCurrentH + _playerMargin + 8;

  void _decreaseFontSize() {
    setState(() {
      _fontSize = (_fontSize - 2).clamp(_minFontSize, _maxFontSize);
    });
  }

  void _increaseFontSize() {
    setState(() {
      _fontSize = (_fontSize + 2).clamp(_minFontSize, _maxFontSize);
    });
  }

  void _togglePlayer() {
    setState(() {
      _playerExpanded = !_playerExpanded;
    });
  }

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<void>? _stateSub;

  @override
  void initState() {
    super.initState();
    _loadSourceText();
    _initPlayer();
  }

  /// 加载伴生 .txt 文件中的源文本
  Future<void> _loadSourceText() async {
    try {
      // 从 audio filePath 推导 text filePath：替换扩展名为 .txt
      final withoutExt = path.withoutExtension(widget.filePath);
      final textFilePath = '$withoutExt.txt';

      final textData = await FileManifest.readFile(textFilePath);
      if (textData != null && textData.isNotEmpty) {
        _sourceText = utf8.decode(textData);
      }
    } catch (_) {
      // 老录音可能没有 companion text，忽略
    }
    if (mounted) {
      _textController.text = _sourceText;
      setState(() {
        _textLoading = false;
      });
    }
  }

  Future<void> _initPlayer() async {
    try {
      _player = AudioPlayerAdapter();

      // 监听进度
      _posSub = _player!.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      // 监听总时长
      _durSub = _player!.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _duration = duration;
          });
        }
      });

      // 监听状态变化（用于刷新 UI）
      _stateSub = _player!.stateStream.listen((_) {
        if (mounted) {
          setState(() {});
        }
      });

      // 加载音频
      await _loadAudio();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        final ext = path.extension(widget.filePath).replaceAll('.', '').toLowerCase();
        final diag = '文件: ${path.basename(widget.filePath)} | '
            '扩展名: $ext | '
            '数据大小: ${_rawAudioData?.length ?? 0} bytes | '
            '源错: $e';
        debugPrint('AudioPlayerPage 错误: $diag');
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _diagnosticInfo = diag;
        });
      }
    }
  }

  Future<void> _loadAudio() async {
    final extension =
        path.extension(widget.filePath).replaceAll('.', '').toLowerCase();
    var mimeType = _getMimeType(extension);

    // 从文件路径中提取哈希值（文件名不含扩展名即为哈希）
    _expectedHash = path.basenameWithoutExtension(widget.filePath);

    var data = await FileManifest.readFile(widget.filePath);

    if (data != null && data.isNotEmpty) {
      // 保存原始数据用于哈希校验
      _rawAudioData = Uint8List.fromList(data);

      // 通用格式校验：确保音频数据含有效文件头，浏览器才可播放
      final result = ensureValidAudioFormat(
        data,
        requestedFormat: extension,
        sampleRate: 24000,
      );
      data = result.$1;
      mimeType = getMimeType(result.$2);

      // 跨平台：Web → Blob URL, Native → data URI
      final audioUrl = createAudioUrl(data, mimeType);
      await _player!.load(audioUrl);
    } else {
      throw Exception('无法加载音频数据');
    }
  }

  String _getMimeType(String extension) {
    switch (extension) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'pcm':
        return 'audio/L16;rate=24000;channels=1';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/wav';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlayPause() async {
    if (_player == null) return;

    if (_player!.playing) {
      _player!.pause();
      return;
    }

    // 首次播放前进行哈希校验
    if (!_hashCheckDone && _rawAudioData != null && _expectedHash.isNotEmpty) {
      final actualHash = md5.convert(_rawAudioData!).toString();
      _hashCheckDone = true;

      if (actualHash != _expectedHash) {
        setState(() {
          _hashVerified = false;
        });
        return; // 不播放，显示错误信息
      } else {
        setState(() {
          _hashVerified = true;
        });
      }
    }

    await _player!.play();
  }

  void _stop() {
    _player?.stop();
    if (mounted) {
      setState(() {
        _position = Duration.zero;
      });
    }
  }

  void _seek(Duration position) {
    _player?.seek(position);
  }

  /// 获取当前选中文本
  String get _selectedText {
    final selection = _textController.selection;
    if (!selection.isValid || selection.isCollapsed) return '';
    return _textController.text.substring(selection.start, selection.end);
  }

  /// 播放选中文本 - 弹出模型选择对话框
  void _onPlaySelectedText() {
    final selected = _selectedText;
    if (selected.isEmpty) return;

    // 获取支持流式输出的模型
    final entriesState = ref.read(providerEntriesProvider);
    final ttsEntry = entriesState.entries
        .where((e) => e.name == 'TTS供应商')
        .firstOrNull;
    if (ttsEntry == null) {
      _showSnackBar('请先配置TTS供应商');
      return;
    }

    // 收集所有支持流式的模型
    final streamingModels = <_StreamModelOption>[];
    for (final configItem in ttsEntry.configs) {
      for (final model in configItem.models) {
        if (model.supportStream) {
          streamingModels.add(_StreamModelOption(model, configItem));
        }
      }
    }

    if (streamingModels.isEmpty) {
      _showSnackBar('没有支持流式播放的模型');
      return;
    }

    _showStreamModelDialog(selected, streamingModels);
  }

  /// 生成选中文本 - 跳转到 TTS 创建页面
  void _onGenerateSelectedText() {
    final selected = _selectedText;
    if (selected.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TTSCreatePage(initialText: selected),
      ),
    );
  }

  void _showStreamModelDialog(
      String text, List<_StreamModelOption> models) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择流式播放模型'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: models.length,
            itemBuilder: (context, index) {
              final opt = models[index];
              return ListTile(
                title: Text(opt.model.name),
                subtitle: Text(opt.configItem.providerName.isNotEmpty
                    ? opt.configItem.providerName
                    : '供应商'),
                onTap: () {
                  Navigator.pop(context);
                  _startStreamingPlayback(text, opt);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _startStreamingPlayback(String text, _StreamModelOption opt) {
    // 使用 TTSStateNotifier 的 startStreaming 方法
    ref.read(ttsStateProvider.notifier).startStreaming(
          text,
          providerConfig: opt.configItem,
          modelConfig: opt.model,
        );
    _showSnackBar('开始流式播放: ${opt.model.name}');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.displayName ?? path.basename(widget.filePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return _buildErrorView();
    }

    if (!_isInitialized || _textLoading) {
      return _buildLoadingView();
    }

    final hasSelection = _selectedText.isNotEmpty;

    return Stack(
      children: [
        // 背景：源文本显示区（填满全屏）
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, _textBottomPadding),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '源文本',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_sourceText.isEmpty)
                          Text(
                            '（无源文本）',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        if (_sourceText.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_fontSize.toInt()}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: _fontSize > _minFontSize ? _decreaseFontSize : null,
                                child: Icon(Icons.text_decrease,
                                  size: 20,
                                  color: _fontSize > _minFontSize
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: _fontSize < _maxFontSize ? _increaseFontSize : null,
                                child: Icon(Icons.text_increase,
                                  size: 20,
                                  color: _fontSize < _maxFontSize
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _sourceText.isNotEmpty
                          ? TextField(
                              controller: _textController,
                              readOnly: true,
                              maxLines: null,
                              expands: true,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.all(12),
                              ),
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.5,
                              ),
                            )
                          : Center(
                              child: Text(
                                '未找到伴生文本文件',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 选中文本操作悬浮栏（文本选中时自动出现）
        if (_sourceText.isNotEmpty && hasSelection)
          Positioned(
            left: _playerMargin + 8,
            right: _playerMargin + 8,
            bottom: _textBottomPadding + 4,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toolbarButton(
                      icon: Icons.play_arrow,
                      label: '播放选中',
                      onTap: _onPlaySelectedText,
                    ),
                    const SizedBox(width: 4),
                    _toolbarButton(
                      icon: Icons.auto_awesome,
                      label: '生成选中',
                      onTap: _onGenerateSelectedText,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 悬浮底部：可折叠播放器面板
        Positioned(
          left: _playerMargin,
          right: _playerMargin,
          bottom: _playerMargin,
          child: _buildPlayerPanel(),
        ),
      ],
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerPanel() {
    final theme = Theme.of(context);

    // 哈希校验失败时展开显示错误（强制展开）
    final forceExpanded = _hashCheckDone && !_hashVerified;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: (forceExpanded || _playerExpanded) ? _playerExpandedH : _playerCollapsedH,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: forceExpanded || _playerExpanded
            ? _buildExpandedContent()
            : _buildCollapsedContent(),
      ),
    );
  }

  /// 折叠态：任务栏样式
  Widget _buildCollapsedContent() {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _togglePlayer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 音频图标
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.audio_file, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            // 文件名
            Expanded(
              child: Text(
                widget.displayName ?? path.basename(widget.filePath),
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 播放/暂停（GestureDetector 避免触发父级展开）
            GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  _player?.playing == true ? Icons.pause : Icons.play_arrow,
                  size: 28,
                ),
              ),
            ),
            // 展开箭头
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.keyboard_arrow_up, size: 28, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  /// 展开态：完整播放器控制
  Widget _buildExpandedContent() {
    final theme = Theme.of(context);

    // 哈希校验失败
    if (_hashCheckDone && !_hashVerified) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 28),
                  onPressed: _togglePlayer,
                ),
              ],
            ),
            const Icon(Icons.error_outline, size: 36, color: Colors.red),
            const SizedBox(height: 8),
            const Text(
              '文件已损坏或不一致',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 4),
            Text(
              '哈希值与记录不匹配，可能已被修改或损坏。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _onRegenerate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重新生成', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 折叠按钮栏
          Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.audio_file, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.displayName ?? path.basename(widget.filePath),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 28),
                onPressed: _togglePlayer,
              ),
            ],
          ),
          // 进度条
          Slider(
            value: _position.inMilliseconds.toDouble(),
            max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
            onChanged: (value) => _seek(Duration(milliseconds: value.toInt())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position), style: const TextStyle(fontSize: 12)),
                Text(_formatDuration(_duration), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.stop),
                iconSize: 28,
                color: Colors.red,
                onPressed: _stop,
              ),
              const SizedBox(width: 16),
              FloatingActionButton.small(
                onPressed: _togglePlayPause,
                child: Icon(
                  _player?.playing == true ? Icons.pause : Icons.play_arrow,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  _player?.volume == 0 ? Icons.volume_off : Icons.volume_up,
                ),
                iconSize: 28,
                onPressed: () {
                  if (_player?.volume == 0) {
                    _player?.setVolume(1.0);
                  } else {
                    _player?.setVolume(0.0);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _player?.playing == true ? '正在播放...' : '已暂停',
            style: TextStyle(
              color: _player?.playing == true ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 重新生成按钮：跳转到制作录音页面，预填源文本
  void _onRegenerate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TTSCreatePage(initialText: _sourceText.isNotEmpty ? _sourceText : null),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在加载音频...'),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            '播放失败',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          if (_diagnosticInfo.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SelectableText(
                _diagnosticInfo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _hasError = false;
                _errorMessage = '';
                _diagnosticInfo = '';
              });
              _initPlayer();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    _textController.dispose();
    super.dispose();
  }
}

/// 流式模型选项（内部辅助类）
class _StreamModelOption {
  final ModelConfig model;
  final ProviderConfigItem configItem;

  const _StreamModelOption(this.model, this.configItem);
}
