import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../utils/audio_separation.dart';
import '../providers/tts_state_provider.dart';
import '../providers/background_task_provider.dart';
import '../utils/file_manifest.dart';
import '../widgets/folder_picker_dialog.dart';
import 'tts_page.dart';

/// 视频音频分离页面
///
/// 允许用户选择视频文件，提取音频并保存到音频库。
/// 桌面端使用 FFmpeg 进行音频提取，Web 端暂不支持。
class AudioSeparationPage extends ConsumerStatefulWidget {
  const AudioSeparationPage({super.key});

  @override
  ConsumerState<AudioSeparationPage> createState() =>
      _AudioSeparationPageState();
}

class _AudioSeparationPageState extends ConsumerState<AudioSeparationPage> {
  // 音频分离引擎
  final AudioSeparationEngine _engine = AudioSeparationEngine();

  // 选中的视频文件信息
  Uint8List? _videoBytes;
  String? _videoName;
  String? _videoFormat;

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
          if (_videoBytes != null && !_isProcessing)
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
                label: const Text('选择视频来源',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceCard(
                      icon: Icons.file_present,
                      title: '从系统相册选择',
                      subtitle: '从设备存储中选择视频文件',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickVideoFile();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ChoiceCard(
                      icon: Icons.video_library,
                      title: '从应用相册选择',
                      subtitle: '从应用内已保存的视频中选择',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickFromVideoLibrary();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick from video library (placeholder)
  void _pickFromVideoLibrary() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('视频库功能开发中')),
      );
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
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '未检测到 FFmpeg，部分功能不可用',
                  style:
                      TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              '请安装 FFmpeg 后重启应用，或使用桌面版应用。',
              style:
                  TextStyle(fontSize: 11, color: Colors.orange[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_videoBytes == null) {
      return _buildEmptyState(cs);
    }

    return _buildVideoInfo(cs);
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_file_outlined,
              size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
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

  Widget _buildVideoInfo(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam, size: 48, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                _videoName ?? '未知文件',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '格式: ${_videoFormat?.toUpperCase() ?? 'N/A'}  |  大小: ${_formatFileSize(_videoBytes!.length)}',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _showVideoSourcePanel,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新选择'),
                ),
              ),
            ],
          ),
        ),
      ),
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
            child: Icon(Icons.error_outline,
                color: cs.onErrorContainer, size: 18),
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
          TextButton(
            onPressed: _goToAudioLibrary,
            child: const Text('查看'),
          ),
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
          border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Save-to folder selector (above start button)
            _buildSaveToSelector(cs),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed:
                    _videoBytes == null || _isProcessing ? null : _startSeparation,
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
                  style:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
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
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
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
              Icon(
                Icons.chevron_right,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
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
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法读取视频文件')),
          );
        }
        return;
      }

      setState(() {
        _videoBytes = bytes;
        _videoName = file.name;
        _videoFormat = _detectFormat(file.name);
        _hasError = false;
        _errorMessage = '';
        _success = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择视频文件失败: $e')),
        );
      }
    }
  }

  void _clearAll() {
    setState(() {
      _videoBytes = null;
      _videoName = null;
      _videoFormat = null;
      _hasError = false;
      _errorMessage = '';
      _success = false;
    });
  }

  // ==================================================================
  // Audio Extraction
  // ==================================================================

  Future<void> _startSeparation() async {
    if (_videoBytes == null) return;

    if (kIsWeb) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Web 端暂不支持音频提取功能，请使用桌面版或移动版应用';
      });
      return;
    }

    if (!_engineAvailable) {
      setState(() {
        _hasError = true;
        _errorMessage = '音频分离引擎不可用，请确保设备支持此功能';
      });
      return;
    }

    // Create a background task for tracking
    final videoName = _videoName ?? '视频音频';
    final taskId = ref.read(backgroundTasksProvider.notifier).addTask(
      type: BackgroundTaskType.audioSeparation,
      title: '音频分离_${p.basenameWithoutExtension(videoName)}',
    );

    // Pop back to home page immediately so user can see task progress
    if (mounted) {
      Navigator.pop(context);
    }

    // Continue processing in the background using the engine
    try {
      final audioBytes = await _engine.extractAudio(
        videoBytes: _videoBytes!,
        videoFormat: _videoFormat ?? 'mp4',
      );

      // 保存到音频库
      await _saveAudioToLibrary(audioBytes);

      // Mark task as completed
      ref.read(backgroundTasksProvider.notifier).completeTask(taskId);
    } catch (e) {
      // Mark task as failed (widget may be gone, but notifier is independent)
      ref.read(backgroundTasksProvider.notifier).failTask(
        taskId,
        error: '音频提取失败: $e',
      );
    }
  }

  Future<void> _saveAudioToLibrary(Uint8List audioBytes) async {
    if (audioBytes.isEmpty) {
      throw Exception('提取的音频数据为空');
    }

    final timestamp = DateTime.now();
    final displayName =
        '${p.basenameWithoutExtension(_videoName ?? '视频音频')}_${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

    final hash = computeAudioHash(audioBytes);
    final format = 'mp3';

    // 保存音频文件
    await FileManifest.writeFile('$hash.$format', audioBytes);

    // 创建记录
    final record = AudioRecord(
      name: displayName,
      hash: hash,
      format: format,
      createdAt: timestamp,
      size: audioBytes.length,
      sourceText: '',
      folder: _saveFolder,
    );

    await FileManifest.addRecord(record);
    // Fire-and-forget: refresh the audio library list asynchronously
    unawaited(ref.read(audioRecordsProvider.notifier).loadRecords());
  }

  void _goToAudioLibrary() {
    // Navigate to TtsPage (audio library) and pop the separation page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TtsPage()),
    );
  }

  // ==================================================================
  // Helpers
  // ==================================================================

  String _detectFormat(String? name) {
    if (name == null) return 'mp4';
    final lower = name.toLowerCase();
    if (lower.endsWith('.mov')) return 'mov';
    if (lower.endsWith('.avi')) return 'avi';
    if (lower.endsWith('.mkv')) return 'mkv';
    if (lower.endsWith('.webm')) return 'webm';
    if (lower.endsWith('.flv')) return 'flv';
    if (lower.endsWith('.m4v')) return 'm4v';
    if (lower.endsWith('.3gp')) return '3gp';
    return 'mp4';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ============================================================================
// ChoiceCard Widget
// ============================================================================

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: cs.shadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
