import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../utils/file_manifest.dart';
import '../providers/tts_state_provider.dart';

/// 录音页面 - 应用内直接录制音频
class AudioRecordingPage extends ConsumerStatefulWidget {
  const AudioRecordingPage({super.key});

  @override
  ConsumerState<AudioRecordingPage> createState() =>
      _AudioRecordingPageState();
}

class _AudioRecordingPageState extends ConsumerState<AudioRecordingPage> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPermissionGranted = false;
  String? _recordedFilePath;
  int _recordDurationSeconds = 0;
  bool _isSaving = false;
  bool _isStarting = false;
  bool _isStopping = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (kIsWeb) {
      // Web 不支持录音
      return;
    }
    try {
      final granted = await _recorder.hasPermission();
      if (mounted) {
        setState(() => _isPermissionGranted = granted);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isPermissionGranted = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // 如果页面关闭时仍在录音，尝试停止并清理
    if (_isRecording) {
      _recorder.stop().then((path) {
        if (path != null && path.isNotEmpty) {
          File(path).delete().catchError((_) {});
        }
      }).catchError((_) {});
    }
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isStarting) return;

    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('浏览器暂不支持录音功能，请使用 App 版本'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isStarting = true);

    try {
      // 请求权限
      if (!_isPermissionGranted) {
        final granted = await _recorder.hasPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('需要麦克风权限才能录音'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        if (mounted) {
          setState(() => _isPermissionGranted = true);
        }
      }

      // 创建临时文件路径
      final tempDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = p.join(tempDir.path, 'recording_$timestamp.m4a');

      // 开始录音
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordDurationSeconds = 0;
          _recordedFilePath = null;
        });
      }

      // 启动计时器更新录音时长
      _startTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('开始录音失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }
      setState(() => _recordDurationSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _isStopping) return;

    setState(() => _isStopping = true);

    try {
      _timer?.cancel();
      final path = await _recorder.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        if (path != null && path.isNotEmpty) {
          _recordedFilePath = path;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('录音文件无效，请重新录制'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('停止录音失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStopping = false);
      }
    }
  }

  Future<void> _saveRecording() async {
    if (_recordedFilePath == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final file = File(_recordedFilePath!);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('录音文件不存在'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('录音文件为空'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 计算 hash 并保存
      final hash = computeAudioHash(bytes);
      final format = 'm4a';
      await FileManifest.writeFile('$hash.$format', bytes);

      final now = DateTime.now();
      final defaultName =
          '录音_${now.month}${now.day}_${now.hour}${now.minute}';

      await FileManifest.addRecord(AudioRecord(
        name: defaultName,
        hash: hash,
        format: format,
        createdAt: now,
        size: bytes.length,
        folder: '',
      ));

      // 删除临时文件
      try {
        await file.delete();
      } catch (_) {}

      if (mounted) {
        // 刷新记录列表
        await ref.read(audioRecordsProvider.notifier).loadRecords();
        await ref.read(folderListProvider.notifier).loadFolders();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('录音已保存: $defaultName'),
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存录音失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('录音'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 64, color: Colors.orange[300]),
                    const SizedBox(height: 16),
                    const Text(
                      '浏览器暂不支持录音功能',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请使用 App 版本进行录音',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else ...[
              // 录音状态指示器
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.grey,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: _isRecording
                      ? const Icon(Icons.mic, size: 48, color: Colors.red)
                      : Icon(Icons.mic_none,
                          size: 48, color: Colors.grey[400]),
                ),
              ),
              const SizedBox(height: 24),

              // 录音时长显示
              Text(
                _isRecording ? _formatDuration(_recordDurationSeconds) : '00:00',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 32),

              // 控制按钮
              if (!_isRecording && _recordedFilePath == null) ...[
                // 开始录音按钮
                _buildActionButton(
                  onPressed: _isPermissionGranted ? _startRecording : null,
                  icon: Icons.fiber_manual_record,
                  label: '开始录音',
                  color: Colors.red,
                ),
              ] else if (_isRecording) ...[
                // 停止录音按钮
                _buildActionButton(
                  onPressed: _stopRecording,
                  icon: Icons.stop,
                  label: '停止录音',
                  color: Colors.red,
                ),
              ] else ...[
                // 录音完成 - 保存或重录
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      onPressed: _isSaving ? null : _saveRecording,
                      icon: Icons.save,
                      label: '保存录音',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _recordedFilePath = null;
                                _recordDurationSeconds = 0;
                              });
                            },
                      icon: Icons.refresh,
                      label: '重新录制',
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: 160,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 2,
        ),
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
