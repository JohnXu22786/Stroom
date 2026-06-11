import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../catcatch/engine/ffmpeg_converter.dart';
import '../providers/tts_state_provider.dart';
import '../providers/background_task_provider.dart';
import '../utils/file_manifest.dart';
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
  // 选中的视频文件信息
  Uint8List? _videoBytes;
  String? _videoName;
  String? _videoFormat;

  bool _isProcessing = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _ffmpegChecked = false;
  bool _ffmpegAvailable = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _checkFfmpeg();
  }

  Future<void> _checkFfmpeg() async {
    if (kIsWeb) {
      setState(() {
        _ffmpegChecked = true;
        _ffmpegAvailable = false;
      });
      return;
    }

    try {
      final available = await FFmpegConverter.isFFmpegAvailable();
      if (mounted) {
        setState(() {
          _ffmpegChecked = true;
          _ffmpegAvailable = available;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ffmpegChecked = true;
          _ffmpegAvailable = false;
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
          if (_ffmpegChecked && !_ffmpegAvailable && !kIsWeb)
            _buildFfmpegWarning(cs),

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
                onPressed: _isProcessing ? null : _pickVideoFile,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.video_file_outlined, size: 20),
                label: const Text('选择视频文件',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFfmpegWarning(ColorScheme cs) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '未检测到 FFmpeg，请安装后使用此功能',
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
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
                  onPressed: _isProcessing ? null : _pickVideoFile,
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
        child: SizedBox(
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
      ),
    );
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
        _errorMessage = 'Web 端暂不支持音频提取功能，请使用桌面版应用';
      });
      return;
    }

    if (!_ffmpegAvailable) {
      setState(() {
        _hasError = true;
        _errorMessage = '未检测到 FFmpeg，请先安装 FFmpeg 后重试';
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

    // Continue processing in the background
    try {
      final tempDir = await getTemporaryDirectory();

      // 写入临时视频文件
      final videoExt = _videoFormat ?? 'mp4';
      final tempVideoPath =
          p.join(tempDir.path, 'input_video.$videoExt');
      await File(tempVideoPath).writeAsBytes(_videoBytes!);

      // 输出音频文件路径
      final outputName =
          '${p.basenameWithoutExtension(_videoName ?? 'audio')}.mp3';
      final tempAudioPath = p.join(tempDir.path, outputName);

      // 使用 FFmpeg 提取音频
      await FFmpegConverter.extractAudio(
        inputPath: tempVideoPath,
        outputPath: tempAudioPath,
      );

      // 读取提取的音频数据
      final audioFile = File(tempAudioPath);
      if (!await audioFile.exists()) {
        throw Exception('音频提取失败：输出文件不存在');
      }
      final audioBytes = await audioFile.readAsBytes();

      // 清理临时文件
      try {
        await File(tempVideoPath).delete();
      } catch (_) {}
      try {
        await audioFile.delete();
      } catch (_) {}

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
    );

    await FileManifest.addRecord(record);
    ref.read(audioRecordsProvider.notifier).loadRecords();
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
