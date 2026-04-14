import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../providers/audio_provider.dart';
import '../services/tts_service.dart';
import '../services/audio_player_service.dart';

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

  bool _isGenerating = false;
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
      await _ttsService.initialize();
      await _audioPlayerService.initialize();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '服务初始化失败: $e';
        });
      }
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
      // Generate audio file using TTS service
      final filePath = await _ttsService.synthesizeToFile(text);

      if (filePath == null) {
        throw Exception('生成音频文件失败');
      }

      // Get file duration (placeholder for now, should get actual duration)
      final duration = 5; // Placeholder duration in seconds

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
      _errorMessage = '生成录音失败: $e';
      _showErrorSnackBar('生成录音失败');
    } finally {
      setState(() {
        _isGenerating = false;
      });
      ref.read(audioProvider.notifier).setGeneratingTTS(false);
    }
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

      // Set up position updates
      _positionSubscription?.cancel();
      _positionSubscription = _audioPlayerService.positionStream.listen(
        (position) {
          final duration = _audioPlayerService.currentDuration;
          if (duration != null && duration.inMilliseconds > 0) {
            final positionPercent = position.inMilliseconds / duration.inMilliseconds;
            notifier.updatePlaybackPosition(positionPercent);
          }
        },
      );

      // Set up completion listener
      _stateSubscription?.cancel();
      _stateSubscription = _audioPlayerService.playerStateStream.listen(
        (state) {
          if (state.playing == false && state.processingState == ProcessingState.completed) {
            notifier.stopPlayback();
            notifier.updatePlaybackPosition(0.0);
          }
        },
      );
    } catch (e) {
      _showErrorSnackBar('播放失败: $e');
    }
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Build text input section
  Widget _buildTextInputSection() {
    return Card(
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
        onLongPress: () => _deleteRecording(recording.id),
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

  /// Build empty state for recording list
  Widget _buildEmptyState() {
    return Center(
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
    );
  }

  /// Build error display
  Widget _buildErrorDisplay() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
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
                ],
              ),
            ),

            // Error display
            _buildErrorDisplay(),

            // Text input section
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTextInputSection(),
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
                  ? _buildEmptyState()
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
}
