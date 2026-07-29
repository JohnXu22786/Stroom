import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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

/// Runs the full extraction pipeline for one video in a single background
/// Isolate: MP4 parsing, audio extraction, MD5 hash, and format detection.
///
/// Combining all CPU-bound work into one [Isolate.run] call avoids the
/// overhead of spawning and tearing down a second isolate, and eliminates
/// the intermediate transfer of extracted audio bytes back to the main
/// thread before hash/format computation.
Future<({Uint8List audioBytes, String hash, String format})>
    _extractAndComputeMetaInIsolate(Uint8List videoBytes, String videoFormat) {
  return Isolate.run(() {
    final audioBytes =
        extractAudioSync(videoBytes: videoBytes, videoFormat: videoFormat);
    final hash = computeAudioHash(audioBytes);
    final format = normalizeAudioFormat(detectAudioFormat(audioBytes));
    return (audioBytes: audioBytes, hash: hash, format: format);
  });
}

/// Processes the audio separation pipeline for each video, completely
/// decoupled from the widget lifecycle. All state is passed in as
/// captured values — no access to `this`, `context`, or `ref`.
///
/// Called via [unawaited] from [_startSeparation] after the pop
/// animation has fully completed.
Future<void> _runAudioSeparation({
  required List<SelectedVideo> videos,
  required BackgroundTaskNotifier bgNotifier,
  required AudioRecordsNotifier audioRecordsNotifier,
  required String saveFolder,
}) async {
  for (final video in videos) {
    final title = '音频分离_${p.basenameWithoutExtension(video.name)}';
    final taskId = bgNotifier.addTask(
      type: BackgroundTaskType.audioSeparation,
      title: title,
      retryData: null,
    );
    await Future<void>.delayed(Duration.zero);

    try {
      bgNotifier.updateStep(taskId, 0, running: true);
      await Future<void>.delayed(Duration.zero);

      final result =
          await _extractAndComputeMetaInIsolate(video.bytes, video.format);

      bgNotifier.updateStep(taskId, 0, completed: true);
      await Future<void>.delayed(Duration.zero);

      bgNotifier.updateStep(taskId, 1, running: true);
      await Future<void>.delayed(Duration.zero);

      final filePath = await _saveAudioSeparationFile(
        result.audioBytes,
        hash: result.hash,
        format: result.format,
        audioRecordsNotifier: audioRecordsNotifier,
        displayName: title,
        videoName: video.name,
        saveFolder: saveFolder,
      );

      bgNotifier.updateStep(taskId, 1, completed: true);
      await Future<void>.delayed(Duration.zero);

      bgNotifier.completeTask(taskId, downloadedFilePath: filePath);
      await Future<void>.delayed(Duration.zero);
    } catch (e) {
      try {
        bgNotifier.failTask(taskId, error: '音频提取失败: $e');
      } catch (_) {
        // failTask itself may throw (e.g. if the notifier has been
        // disposed).  Since _runAudioSeparation is fire-and-forget
        // (unawaited), an uncaught exception would crash the app.
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  unawaited(audioRecordsNotifier.loadRecords());
}

/// Saves extracted audio bytes to the library and returns the file path.
/// All parameters are explicitly passed — no dependency on widget state.
Future<String?> _saveAudioSeparationFile(
  Uint8List audioBytes, {
  required String hash,
  required String format,
  required AudioRecordsNotifier audioRecordsNotifier,
  String? displayName,
  String? videoName,
  required String saveFolder,
}) async {
  if (audioBytes.isEmpty) {
    throw Exception('提取的音频数据为空');
  }

  final timestamp = DateTime.now();
  final effectiveVideoName = videoName ?? '视频音频';
  final name =
      displayName ?? '音频分离_${p.basenameWithoutExtension(effectiveVideoName)}';

  await FileManifest.writeFile('$hash.$format', audioBytes);

  final record = AudioRecord(
    name: name,
    hash: hash,
    format: format,
    createdAt: timestamp,
    size: audioBytes.length,
    sourceText: '',
    folder: saveFolder,
  );
  await FileManifest.addRecord(record);

  final filePath = await FileManifest.readFilePath('$hash.$format');
  unawaited(audioRecordsNotifier.loadRecords());

  return filePath;
}

class _AudioSeparationPageState extends ConsumerState<AudioSeparationPage> {
  // 音频分离引擎
  final AudioSeparationEngine _engine = AudioSeparationEngine();

  // 选中的视频文件列表（支持多选）
  final List<SelectedVideo> _selectedVideos = [];

  bool _isProcessing = false;
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

    // Guard against double-tap: disable the button immediately.
    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

    // Capture everything the processing pipeline needs BEFORE pop.
    // After the widget is disposed, `ref` and `_saveFolder` are invalid.
    final videosToProcess = List<SelectedVideo>.from(_selectedVideos);
    final bgNotifier = ref.read(backgroundTasksProvider.notifier);
    final audioRecordsNotifier = ref.read(audioRecordsProvider.notifier);
    final saveFolder = _saveFolder;
    final route = ModalRoute.of(context);

    // Pop IMMEDIATELY — schedule the route transition now.
    if (mounted) {
      Navigator.pop(context);
    }

    // Wait for the pop animation to finish BEFORE starting any
    // processing.  addTask / updateStep / completeTask trigger
    // Riverpod state updates that cascade to home-page watchers;
    // if those rebuilds happen during the pop animation they
    // compete with the transition frames and freeze it mid-flight.
    //
    // We use the route's AnimationController status to detect
    // the exact moment the exit transition completes.  (Using
    // route.popped won't work — it completes synchronously in
    // ModalRoute.didPop, BEFORE the animation even starts.)
    final animation = route?.animation;
    if (animation != null &&
        animation.status != AnimationStatus.dismissed) {
      final done = Completer<void>();
      void listener(AnimationStatus s) {
        if (s == AnimationStatus.dismissed) {
          if (!done.isCompleted) done.complete();
          animation.removeStatusListener(listener);
        }
      }

      animation.addStatusListener(listener);
      await done.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          animation.removeStatusListener(listener);
        },
      );
    } else if (route == null) {
      // No route — unexpected, but guard with a fallback delay.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    // Implicit else: animation already dismissed — no wait needed;
    // fall through to fire-and-forget immediately.

    // Route transition is complete — now fire-and-forget the pipeline.
    // _runAudioSeparation is a top-level function with no access to
    // `this`, `ref`, or `context`, so it's safe to call after dispose.
    unawaited(_runAudioSeparation(
      videos: videosToProcess,
      bgNotifier: bgNotifier,
      audioRecordsNotifier: audioRecordsNotifier,
      saveFolder: saveFolder,
    ));
  }

  void _goToAudioLibrary() {
    // Navigate to TtsPage (audio library) and pop the separation page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TtsPage()),
    );
  }
}
