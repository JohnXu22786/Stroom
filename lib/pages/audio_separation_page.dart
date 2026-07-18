import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../utils/audio_separation.dart';
import '../utils/audio_utils.dart' show detectAudioFormat, normalizeAudioFormat;
import '../providers/tts_state_provider.dart';
import '../providers/background_task_provider.dart';
import '../utils/file_manifest.dart';
import '../widgets/folder_picker_dialog.dart';
import 'tts_page.dart';
import 'audio_separation_shared.dart';
import 'chat/composer/video_album_picker_dialog.dart';

/// 视频音频分离页面
///
/// 允许用户选择视频文件，提取音频并保存到音频库。
/// 桌面端使用 FFmpeg 进行音频提取，Web 端暂不支持。
class AudioSeparationPage extends ConsumerStatefulWidget {
  const AudioSeparationPage({super.key, this.retryData});

  /// Retry data to pre-populate the form (video files, etc.).
  final Map<String, dynamic>? retryData;

  @override
  ConsumerState<AudioSeparationPage> createState() =>
      _AudioSeparationPageState();
}

/// Represents a single selected video file for audio separation.
class SelectedVideo {
  final Uint8List bytes;
  final String name;
  final String format;

  SelectedVideo({
    required this.bytes,
    required this.name,
    this.format = 'mp4',
  });
}

class _AudioSeparationPageState extends ConsumerState<AudioSeparationPage> {
  // 音频分离引擎
  final AudioSeparationEngine _engine = AudioSeparationEngine();

  // 选中的视频文件列表（支持多选）
  final List<SelectedVideo> _selectedVideos = [];

  final bool _isProcessing = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _engineChecked = false;
  bool _engineAvailable = false;
  bool _success = false;

  /// Save-to folder selection
  String _saveFolder = '';

  @override
  void initState() {
    super.initState();
    _checkEngine();
    _applyRetryData();
  }

  /// Pre-populate form from retry data if available.
  void _applyRetryData() {
    final data = widget.retryData;
    if (data == null) return;

    final videosData = data['videos'] as List<dynamic>?;
    if (videosData != null) {
      for (final videoData in videosData) {
        if (videoData is Map) {
          final bytesStr = videoData['bytes'] as String?;
          if (bytesStr != null) {
            try {
              final bytes = base64Decode(bytesStr);
              _selectedVideos.add(SelectedVideo(
                bytes: bytes,
                name: videoData['name'] as String? ?? 'video',
                format: videoData['format'] as String? ?? 'mp4',
              ));
            } catch (e) {
              debugPrint('Failed to decode retry video: $e');
            }
          }
        }
      }
    }
  }

  Future<void> _checkEngine() async {
    try {
      final available = await _engine.isAvailable();
      if (mounted) {
        setState(() {
          _engineChecked = true;
          _engineAvailable = available;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _engineChecked = true;
          _engineAvailable = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('视频音频分离'),
        centerTitle: true,
        actions: [
          if (_selectedVideos.isNotEmpty && !_isProcessing)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('清空'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Video source button
          _buildVideoSourceBar(cs),

          // FFmpeg status
          if (_engineChecked && !_engineAvailable && !kIsWeb)
            _buildEngineWarning(cs),

          // Content area
          Expanded(child: _buildContent(cs)),

          // Error message
          if (_hasError) _buildErrorBanner(cs),

          // Success message
          if (_success) _buildSuccessBanner(cs),

          // Bottom action bar
          _buildBottomBar(cs),
        ],
      ),
    );
  }

  Widget _buildVideoSourceBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _showVideoSourcePanel,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.video_file_outlined, size: 20),
                label: const Text(
                  '选择视频来源',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show video source selection panel with choice cards
  void _showVideoSourcePanel() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                '选择视频来源',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  ChoiceCard(
                    icon: Icons.video_library,
                    title: '从应用相册选择',
                    subtitle: '从应用内已保存的视频中选择',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickFromVideoLibrary();
                    },
                  ),
                  const SizedBox(height: 8),
                  ChoiceCard(
                    icon: Icons.file_present,
                    title: '从系统相册选择',
                    subtitle: '从设备存储中选择视频文件',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickVideoFile();
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

  /// Pick from video library - shows folder-navigable video album picker.
  Future<void> _pickFromVideoLibrary() async {
    try {
      final results =
          await showAppVideoPickerDialog(context, multiSelect: true);
      if (results == null || results.isEmpty || !mounted) return;

      final newVideos = <SelectedVideo>[];
      for (final result in results) {
        newVideos.add(
          SelectedVideo(
            bytes: result.bytes,
            name: result.record.name,
            format: result.record.format,
          ),
        );
      }

      setState(() {
        _selectedVideos.addAll(newVideos);
        _hasError = false;
        _errorMessage = '';
        _success = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择视频失败: $e')));
      }
    }
  }

  Widget _buildEngineWarning(ColorScheme cs) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '未检测到音频分离引擎',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              '请重启应用或检查应用资源完整性。',
              style: TextStyle(fontSize: 11, color: Colors.orange[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_selectedVideos.isEmpty) {
      return _buildEmptyState(cs);
    }

    return _buildVideoList(cs);
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_file_outlined,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '暂未选择视频文件',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持 mp4、mov、avi、mkv 等常见视频格式',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList(ColorScheme cs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _selectedVideos.length,
      itemBuilder: (context, index) {
        final video = _selectedVideos[index];
        return Card(
          key: ValueKey('video_${video.name}_$index'),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.videocam, color: cs.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${video.format.toUpperCase()}  |  ${formatFileSize(video.bytes.length)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isProcessing)
                  IconButton(
                    icon:
                        Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                    onPressed: () => _removeVideo(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.errorContainer,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline,
              color: cs.onErrorContainer,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: cs.onErrorContainer, size: 18),
            onPressed: () => setState(() {
              _hasError = false;
              _errorMessage = '';
            }),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.primaryContainer.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: cs.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '音频已成功提取并保存到录音库',
              style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13),
            ),
          ),
          TextButton(onPressed: _goToAudioLibrary, child: const Text('查看')),
          IconButton(
            icon: Icon(Icons.close, color: cs.onPrimaryContainer, size: 18),
            onPressed: () => setState(() => _success = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Save-to folder selector (above start button)
            _buildSaveToSelector(cs),
            if (_selectedVideos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.videocam,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '已选 ${_selectedVideos.length} 个视频',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _selectedVideos.isEmpty || _isProcessing
                    ? null
                    : _startSeparation,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.audio_file, size: 20),
                label: Text(
                  _isProcessing ? '提取中...' : '提取音频',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  // Save-to Folder Selector
  // ==================================================================

  Widget _buildSaveToSelector(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _pickSaveFolder,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '保存至',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              Text(
                _saveFolder.isEmpty ? '根目录' : _saveFolder,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSaveFolder() async {
    final folders = await FileManifest.getAllFolders();
    if (!mounted) return;
    final result = await FolderPickerDialog.show(
      context,
      currentFolder: _saveFolder,
      availableFolders: folders,
      title: '选择保存文件夹',
    );
    if (result != null && mounted) {
      setState(() => _saveFolder = result);
    }
  }

  // ==================================================================
  // Video Source Methods
  // ==================================================================

  Future<void> _pickVideoFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.video,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final newVideos = <SelectedVideo>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        newVideos.add(
          SelectedVideo(
            bytes: bytes,
            name: file.name,
            format: detectFormat(file.name),
          ),
        );
      }

      if (newVideos.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('无法读取视频文件')));
        }
        return;
      }

      setState(() {
        _selectedVideos.addAll(newVideos);
        _hasError = false;
        _errorMessage = '';
        _success = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择视频文件失败: $e')));
      }
    }
  }

  void _clearAll() {
    setState(() {
      _selectedVideos.clear();
      _hasError = false;
      _errorMessage = '';
      _success = false;
    });
  }

  void _removeVideo(int index) {
    if (index < 0 || index >= _selectedVideos.length) return;
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  // ==================================================================
  // Audio Extraction
  // ==================================================================

  Future<void> _startSeparation() async {
    if (_selectedVideos.isEmpty) return;

    if (!_engineAvailable) {
      setState(() {
        _hasError = true;
        _errorMessage = '音频分离引擎不可用。';
      });
      return;
    }

    final videosToProcess = List<SelectedVideo>.from(_selectedVideos);

    // Capture notifier references BEFORE Navigator.pop — after the widget is
    // disposed, ConsumerState.ref may become unreliable for read() calls.
    final bgNotifier = ref.read(backgroundTasksProvider.notifier);
    final audioRecordsNotifier = ref.read(audioRecordsProvider.notifier);

    // Add ALL tasks to the task list first so they appear simultaneously.
    // Each video gets its own background task with a unique title.
    final taskIds = <String>[];
    for (final video in videosToProcess) {
      final title = '音频分离_${p.basenameWithoutExtension(video.name)}';

      // Build retry data: encode only the current video bytes as base64
      // so they can be restored on retry (each task handles one file)
      final retryData = <String, dynamic>{
        'type': 'audioSeparation',
        'videos': [
          <String, dynamic>{
            'bytes': base64Encode(video.bytes),
            'name': video.name,
            'format': video.format,
          },
        ],
      };

      final taskId = bgNotifier.addTask(
        type: BackgroundTaskType.audioSeparation,
        title: title,
        retryData: retryData,
      );
      taskIds.add(taskId);
    }

    // Pop back to home page so user can see ALL task progress
    if (mounted) {
      Navigator.pop(context);
    }

    // Now process each video sequentially
    for (int i = 0; i < videosToProcess.length; i++) {
      final video = videosToProcess[i];
      final taskId = taskIds[i];
      final title = '音频分离_${p.basenameWithoutExtension(video.name)}';

      try {
        // Step 0: 分离音频 - mark as running
        bgNotifier.updateStep(taskId, 0, running: true);

        final audioBytes = await _engine.extractAudio(
          videoBytes: video.bytes,
          videoFormat: video.format,
          onProgress: (progress) {
            bgNotifier.setResult(taskId, '正在提取音频... $progress%');
          },
        );

        // Step 0: 分离音频 - mark as completed
        bgNotifier.updateStep(taskId, 0, completed: true);

        // Step 1: 保存到文件 - mark as running
        bgNotifier.updateStep(taskId, 1, running: true);

        // 保存到音频库 (返回文件路径)
        final filePath = await _saveAudioToLibrary(
          audioBytes,
          audioRecordsNotifier: audioRecordsNotifier,
          displayName: title,
          videoName: video.name,
        );

        // Step 1: 保存到文件 - mark as completed
        bgNotifier.updateStep(taskId, 1, completed: true);

        // Mark task as completed with file path
        bgNotifier.completeTask(taskId, downloadedFilePath: filePath);
      } catch (e) {
        // Mark task as failed (notifier is independent of widget lifecycle)
        bgNotifier.failTask(taskId, error: '音频提取失败: $e');
      }
    }

    // Fire-and-forget: refresh the audio library list after all tasks complete
    unawaited(audioRecordsNotifier.loadRecords());
  }

  /// 保存音频到音频库，并返回保存的文件路径。如果获取路径失败则返回 null。
  Future<String?> _saveAudioToLibrary(
    Uint8List audioBytes, {
    AudioRecordsNotifier? audioRecordsNotifier,
    String? displayName,
    String? videoName,
  }) async {
    if (audioBytes.isEmpty) {
      throw Exception('提取的音频数据为空');
    }

    final timestamp = DateTime.now();
    final effectiveVideoName = videoName ?? '视频音频';
    final name =
        displayName ?? '音频分离_${p.basenameWithoutExtension(effectiveVideoName)}';

    final hash = computeAudioHash(audioBytes);
    // 检测原始格式（可能为 'aac'）后规范化为面向用户的扩展名（如 'm4a'），
    // 这样保存的文件以 .m4a 命名、AudioRecord.format 也为 'm4a'，与显示名
    // (M4A) 保持一致。
    final detectedFormat = detectAudioFormat(audioBytes);
    final format = normalizeAudioFormat(detectedFormat);

    // 保存音频文件
    await FileManifest.writeFile('$hash.$format', audioBytes);

    // 创建记录
    final record = AudioRecord(
      name: name,
      hash: hash,
      format: format,
      createdAt: timestamp,
      size: audioBytes.length,
      sourceText: '',
      folder: _saveFolder,
    );

    await FileManifest.addRecord(record);

    // 获取文件路径用于"打开文件"按钮
    final filePath = await FileManifest.readFilePath('$hash.$format');

    // Fire-and-forget: refresh the audio library list asynchronously
    // Use captured notifier if provided (safer after widget dispose)
    if (audioRecordsNotifier != null) {
      unawaited(audioRecordsNotifier.loadRecords());
    } else {
      unawaited(ref.read(audioRecordsProvider.notifier).loadRecords());
    }

    return filePath;
  }

  void _goToAudioLibrary() {
    // Navigate to TtsPage (audio library) and pop the separation page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TtsPage()),
    );
  }
}
