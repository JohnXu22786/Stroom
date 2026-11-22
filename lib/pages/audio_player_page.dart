import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:stroom/widgets/modal_bottom_sheet_constraints.dart';

import '../l10n/app_localizations.dart';
import '../providers/provider_config.dart';
import '../providers/tts_state_provider.dart';
import '../utils/file_manifest.dart';
import '../utils/audio_source_text_saver.dart';
import '../utils/text_manifest.dart';
import '../utils/audio_playback.dart';
import '../utils/audio_player_temp_file.dart';
import '../utils/audio_utils.dart';
import '../utils/system_pick_utils.dart';
import '../widgets/app_media_picker_dialog.dart';
import 'audio_player_shared.dart';
import 'audio_source_header.dart';
import 'audio_separation_shared.dart';
import 'tts_create_page.dart';

import '../widgets/constrained_text.dart';

/// 音频播放器页面
/// 跨平台：Web 用 HTML5 AudioElement，Native 用 just_audio
class AudioPlayerPage extends ConsumerStatefulWidget {
  final String filePath;
  final String? displayName;

  const AudioPlayerPage({super.key, required this.filePath, this.displayName});

  @override
  ConsumerState<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends ConsumerState<AudioPlayerPage> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  AudioPlayerAdapter? _player;
  bool _isInitialized = false;
  bool _isRetrying = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _diagnosticInfo = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  String? _tempFilePath;

  // 源文本
  String _sourceText = '';
  bool _textLoading = true;
  final _textController = TextEditingController();
  double _fontSize = 14;
  static const double _minFontSize = 10;
  static const double _maxFontSize = 28;

  // 播放速度
  double _playbackSpeed = 1.0;

  // 音量（记住用户设置）
  final double _volume = 1.0;

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
  Future<void>? _playerDisposal;

  /// 清理播放器资源（取消订阅 + dispose），避免重试时泄漏
  Future<void> _disposePlayer() {
    return _playerDisposal ??= _disposePlayerResources().whenComplete(() {
      _playerDisposal = null;
    });
  }

  Future<void> _disposePlayerResources() async {
    await _posSub?.cancel();
    _posSub = null;
    await _durSub?.cancel();
    _durSub = null;
    await _stateSub?.cancel();
    _stateSub = null;
    await _player?.dispose();
    _player = null;
    _isInitialized = false;
    _position = Duration.zero;
    _duration = Duration.zero;
  }

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
        _sourceText = utf8.decode(textData, allowMalformed: true);
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

  /// 显示选择源文本来源的面板（应用内文本 / 系统文本文件）
  void _showSourceTextChoicePanel() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      constraints: modalBottomSheetWidthConstraints(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _l10n.audioPlayerSourceTextSource,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  ChoiceCard(
                    icon: Icons.description_outlined,
                    title: _l10n.audioPlayerChooseInAppText,
                    subtitle: _l10n.audioPlayerChooseSavedTextSubtitle,
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickSourceTextFromApp();
                    },
                  ),
                  const SizedBox(height: 8),
                  ChoiceCard(
                    icon: Icons.upload_file,
                    title: _l10n.audioPlayerChooseSystemText,
                    subtitle: _l10n.audioPlayerChooseDeviceTextSubtitle,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickSourceTextFromSystem();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 从应用内已保存的文本文件中选择源文本
  Future<void> _pickSourceTextFromApp() async {
    try {
      final result = await showMediaPickerDialog<TextRecord>(
        context,
        MediaPickerConfig<TextRecord>(
          title: _l10n.audioPlayerSelectInAppText,
          emptyIcon: Icons.description_outlined,
          emptyText: _l10n.audioPlayerNoTextFiles,
          fileIcon: Icons.description,
          fileIconColor: Colors.orange,
          multiSelect: false,
          loadRecords: TextManifest.loadRecords,
          loadFolders: TextManifest.getAllFolders,
          readFile: (record) => TextManifest.readFile(record.storagePath),
          displayName: (record) => record.name,
          subtitleBuilder: (record) => Row(
            children: [
              Text(
                _l10n.audioPlayerCharacterCount(record.textLength),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatFileSize(record.size),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );

      if (result == null || result.isEmpty || !mounted) return;

      await _applySourceTextContent(result.first.value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.audioPlayerSelectTextFailure(e.toString())),
          ),
        );
      }
    }
  }

  /// 从设备文件系统中选择源文本文件
  Future<void> _pickSourceTextFromSystem() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        initialDirectory: SystemPickDirectories.documents(),
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_l10n.audioPlayerCannotReadTextFile)),
          );
        }
        return;
      }

      await _applySourceTextContent(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.audioPlayerUploadTextFailure(e.toString())),
          ),
        );
      }
    }
  }

  /// 将原始字节解码为文本并应用到源文本（保存 + 更新 UI）
  Future<void> _applySourceTextContent(Uint8List bytes) async {
    if (bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.audioPlayerTextContentEmpty)),
        );
      }
      return;
    }

    String textContent;
    try {
      textContent = utf8.decode(bytes);
    } catch (_) {
      textContent = utf8.decode(bytes, allowMalformed: true);
    }

    if (textContent.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.audioPlayerTextContentEmpty)),
        );
      }
      return;
    }

    try {
      await _saveSourceText(textContent);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.audioPlayerSaveTextFailure(e.toString())),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final wasEmpty = _sourceText.isEmpty;
    setState(() {
      _sourceText = textContent;
      _textController.text = textContent;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasEmpty
              ? _l10n.audioPlayerSourceTextUploaded
              : _l10n.audioPlayerSourceTextUpdated,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 上传或修改源文本文件 — 弹出选择面板
  void _uploadSourceText() {
    _showSourceTextChoicePanel();
  }

  /// 保存源文本到伴生文件并更新 AudioRecord
  Future<void> _saveSourceText(String text) async {
    await saveAudioSourceText(widget.filePath, text);
  }

  Future<void> _initPlayer() async {
    try {
      _player = AudioPlayerAdapter();
      // 恢复音量 & 速度
      _player!.setVolume(_volume);
      _player!.setPlaybackSpeed(_playbackSpeed);

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
        try {
          await _disposePlayer();
        } catch (disposeError) {
          debugPrint('AudioPlayerPage 清理失败: $disposeError');
        }
        if (!mounted) return;
        final ext = path
            .extension(widget.filePath)
            .replaceAll('.', '')
            .toLowerCase();
        final diag =
            '文件: ${path.basename(widget.filePath)} | '
            '扩展名: $ext | '
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
    final extension = path
        .extension(widget.filePath)
        .replaceAll('.', '')
        .toLowerCase();

    if (!kIsWeb) {
      // Native: read into memory, validate/convert format, play from temp
      final data = await FileManifest.readFile(widget.filePath);
      if (!mounted) return;
      if (data == null || data.isEmpty) {
        throw Exception(_l10n.audioPlayerFileNotFound(widget.filePath));
      }
      final fixed = ensureValidAudioFormat(
        data,
        requestedFormat: extension,
        sampleRate: 24000,
      );
      final tempFile = await writeAudioPlayerTempFile(
        bytes: fixed.$1,
        extension: fixed.$2,
        isDisposed: () => !mounted,
      );
      if (tempFile == null) return;
      if (!mounted) {
        await deleteAudioPlayerTempFile(tempFile);
        return;
      }
      _tempFilePath = tempFile.path;
      final player = _player;
      if (player == null) {
        await deleteAudioPlayerTempFile(tempFile);
        _tempFilePath = null;
        return;
      }
      await player.load(tempFile.path);
    } else {
      // Web: 读取文件并创建 Blob URL
      final data = await FileManifest.readFile(widget.filePath);
      if (data == null || data.isEmpty) {
        throw Exception(_l10n.audioPlayerUnableToLoadAudio);
      }
      debugPrint('_loadAudio: ${widget.filePath} → ${data.length} 字节');

      final result = ensureValidAudioFormat(
        data,
        requestedFormat: extension,
        sampleRate: 24000,
      );
      final audioData = result.$1;
      final mimeType = getMimeType(result.$2);
      final audioUrl = createAudioUrl(audioData, mimeType);
      await _player!.load(audioUrl);
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

    await _player!.play();
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
      _showSnackBar(_l10n.audioPlayerConfigureTtsProvider);
      return;
    }

    // 收集所有支持流式的模型
    final streamingModels = <StreamModelOption>[];
    for (final configItem in ttsEntry.configs) {
      for (final model in configItem.models) {
        if (model.supportStream) {
          streamingModels.add(StreamModelOption(model, configItem));
        }
      }
    }

    if (streamingModels.isEmpty) {
      _showSnackBar(_l10n.audioPlayerNoStreamingModels);
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

  void _showStreamModelDialog(String text, List<StreamModelOption> models) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: ConstrainedText(
          _l10n.audioPlayerSelectStreamingModel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: models.length,
            itemBuilder: (context, index) {
              final opt = models[index];
              return ListTile(
                title: Text(opt.model.name),
                subtitle: Text(
                  opt.configItem.providerName.isNotEmpty
                      ? opt.configItem.providerName
                      : _l10n.audioPlayerProviderFallback,
                ),
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
            child: ConstrainedText(
              _l10n.cancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _startStreamingPlayback(String text, StreamModelOption opt) {
    // 使用 TTSStateNotifier 的 startStreaming 方法
    ref
        .read(ttsStateProvider.notifier)
        .startStreaming(
          text,
          providerConfig: opt.configItem,
          modelConfig: opt.model,
        );
    _showSnackBar(_l10n.audioPlayerStartStreaming(opt.model.name));
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
        title: ConstrainedText(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return AudioPlayerErrorView(
        errorMessage: _errorMessage,
        diagnosticInfo: _diagnosticInfo,
        onRetry: () async {
          if (_isRetrying) return;
          _isRetrying = true;
          final tempFilePath = _tempFilePath;
          try {
            await disposeAudioPlayerTempFile(
              disposePlayer: _disposePlayer,
              tempFilePath: tempFilePath,
            );
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _isRetrying = false;
              _errorMessage = e.toString();
            });
            return;
          }
          if (!mounted) return;
          _tempFilePath = null;
          setState(() {
            _isRetrying = false;
            _hasError = false;
            _errorMessage = '';
            _diagnosticInfo = '';
          });
          _initPlayer();
        },
      );
    }

    if (!_isInitialized || _textLoading) {
      return buildAudioLoadingView(context);
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
                    AudioSourceHeader(
                      title: _l10n.audioPlayerSourceText,
                      hasSource: _sourceText.isNotEmpty,
                      emptyMessage: _l10n.audioPlayerNoSourceText,
                      uploadLabel: _l10n.audioPlayerUploadSourceText,
                      editLabel: _l10n.audioPlayerEditSourceText,
                      fontSize: _fontSize.toInt(),
                      onUpload: _uploadSourceText,
                      onDecreaseFontSize: _decreaseFontSize,
                      onIncreaseFontSize: _increaseFontSize,
                      canDecreaseFontSize: _fontSize > _minFontSize,
                      canIncreaseFontSize: _fontSize < _maxFontSize,
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
                                _l10n.audioPlayerCompanionTextMissing,
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
            child: AudioPlayerSelectionToolbar(
              playLabel: _l10n.audioPlayerPlaySelection,
              generateLabel: _l10n.audioPlayerGenerateSelection,
              onPlay: _onPlaySelectedText,
              onGenerate: _onGenerateSelectedText,
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

  Widget _buildPlayerPanel() {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _playerExpanded ? _playerExpandedH : _playerCollapsedH,
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
        child: _playerExpanded
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
              child: Icon(
                Icons.audio_file,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            // 文件名
            Expanded(
              child: ConstrainedText(
                widget.displayName ?? path.basename(widget.filePath),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
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
              child: Icon(
                Icons.keyboard_arrow_up,
                size: 28,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 展开态：完整播放器控制
  Widget _buildExpandedContent() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 折叠按钮栏
          Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                Icons.audio_file,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ConstrainedText(
                  widget.displayName ?? path.basename(widget.filePath),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 倍速显示按钮（左侧）
              GestureDetector(
                onTap: _showSpeedPopup,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_playbackSpeed.toStringAsFixed(1)}x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 播放/暂停
              FloatingActionButton.small(
                onPressed: _togglePlayPause,
                child: Icon(
                  _player?.playing == true ? Icons.pause : Icons.play_arrow,
                  size: 24,
                ),
              ),
              // 右侧预留空位
              const SizedBox(width: 16),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _player?.playing == true
                ? _l10n.audioPlayerPlaying
                : _l10n.audioPlayerPaused,
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

  /// 倍速调节弹窗（数字在上，滑块在下）
  void _showSpeedPopup() {
    double temp = _playbackSpeed;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: ConstrainedText(
            _l10n.audioPlayerPlaybackSpeed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          content: SizedBox(
            width: 260,
            height: 80,
            child: Column(
              children: [
                Text(
                  '${temp.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: temp,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    label: '${temp.toStringAsFixed(1)}x',
                    onChanged: (v) {
                      temp = (v * 10).roundToDouble() / 10;
                      setDialogState(() {});
                      setState(() => _playbackSpeed = temp);
                      _player?.setPlaybackSpeed(temp);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: ConstrainedText(
                _l10n.audioPlayerClose,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    final tempFilePath = _tempFilePath;
    _tempFilePath = null;
    unawaited(
      disposeAudioPlayerTempFile(
        disposePlayer: _disposePlayer,
        tempFilePath: tempFilePath,
      ).catchError((Object error, StackTrace stackTrace) {
        debugPrint('AudioPlayerPage 清理播放器失败: $error');
      }),
    );
    _textController.dispose();
    super.dispose();
  }
}
