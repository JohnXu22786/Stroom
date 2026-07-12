import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../providers/tts_state_provider.dart';
import '../utils/file_manifest.dart';

/// 录音页面 - 使用 audio_waveforms 重构，带波形图与暂停/恢复功能
class AudioRecordingPage extends ConsumerStatefulWidget {
  const AudioRecordingPage({super.key});

  @override
  ConsumerState<AudioRecordingPage> createState() => _AudioRecordingPageState();
}

class _AudioRecordingPageState extends ConsumerState<AudioRecordingPage> {
  final RecorderController _controller = RecorderController();
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isPermissionGranted = false;
  String? _recordedFilePath;
  String? _activeRecordingPath;
  int _recordDurationSeconds = 0;
  bool _isSaving = false;
  bool _isStarting = false;
  bool _isStopping = false;
  StreamSubscription<RecorderState>? _stateSub;
  StreamSubscription<Duration>? _durationSub;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    _isInitialized = true;

    // 监听录制器状态变化
    _stateSub = _controller.onRecorderStateChanged.listen(_onRecorderState);

    // 监听录音时长变化
    _durationSub = _controller.onCurrentDuration.listen((duration) {
      if (mounted) {
        setState(() {
          _recordDurationSeconds = duration.inSeconds;
        });
      }
    });

    // 检查权限
    await _checkPermission();
    if (mounted) {
      setState(() {});
    }
  }

  void _onRecorderState(RecorderState state) {
    if (!mounted) return;
    setState(() {
      _isRecording = state.isRecording;
      _isPaused = state.isPaused;
      if (state.isStopped) {
        _isRecording = false;
        _isPaused = false;
      }
    });
  }

  Future<void> _checkPermission() async {
    if (kIsWeb) return;
    try {
      final granted = await _controller.checkPermission();
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
    _stateSub?.cancel();
    _durationSub?.cancel();
    // RecorderController.dispose() 内部已经处理了停止录音和资源释放
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isStarting) return;

    if (kIsWeb) {
      _showSnackBar('浏览器暂不支持录音功能，请使用 App 版本');
      return;
    }

    setState(() => _isStarting = true);

    try {
      // 请求权限
      if (!_isPermissionGranted) {
        final granted = await _controller.checkPermission();
        if (!granted) {
          _showSnackBar('需要麦克风权限才能录音', isError: true);
          if (mounted) {
            setState(() => _isStarting = false);
          }
          return;
        }
        if (mounted) {
          setState(() => _isPermissionGranted = true);
        }
      }

      // 创建临时文件路径（.m4a = AAC 格式）
      final tempDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = p.join(tempDir.path, 'recording_$timestamp.m4a');
      _activeRecordingPath = filePath;

      // 开始录音 - audio_waveforms 自动输出 AAC/M4A 格式
      // Android: AndroidEncoder.aacLc → .m4a
      // iOS: IosEncoder.kAudioFormatMPEG4AAC → .m4a
      await _controller.record(
        path: filePath,
        recorderSettings: const RecorderSettings(
          sampleRate: 44100,
          bitRate: 128000,
          androidEncoderSettings: AndroidEncoderSettings(
            androidEncoder: AndroidEncoder.aacLc,
          ),
          iosEncoderSettings: IosEncoderSetting(
            iosEncoder: IosEncoder.kAudioFormatMPEG4AAC,
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordDurationSeconds = 0;
          _recordedFilePath = null;
          _isStarting = false;
        });
      }
    } catch (e) {
      _showSnackBar('开始录音失败: $e', isError: true);
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  Future<void> _pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    try {
      await _controller.pause();
      // _onRecorderState 会自动更新 _isPaused
    } catch (e) {
      _showSnackBar('暂停录音失败: $e', isError: true);
    }
  }

  Future<void> _resumeRecording() async {
    if (!_isPaused) return;
    try {
      // 暂停后调用 record() 恢复录音
      await _controller.record(path: _activeRecordingPath);
      // _onRecorderState 会自动更新 _isPaused
    } catch (e) {
      _showSnackBar('恢复录音失败: $e', isError: true);
    }
  }

  Future<void> _stopRecording() async {
    if ((!_isRecording && !_isPaused) || _isStopping) return;

    setState(() => _isStopping = true);

    try {
      final path = await _controller.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isPaused = false;
        });
        if (path != null && path.isNotEmpty) {
          _recordedFilePath = path;
          _activeRecordingPath = null;
        } else {
          _showSnackBar('录音文件无效，请重新录制', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isPaused = false;
        });
        _showSnackBar('停止录音失败: $e', isError: true);
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
        _showSnackBar('录音文件不存在', isError: true);
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showSnackBar('录音文件为空', isError: true);
        return;
      }

      // 计算 hash 并保存
      final hash = computeAudioHash(bytes);
      const format = 'm4a';
      await FileManifest.writeFile('$hash.$format', bytes);

      final now = DateTime.now();
      final defaultName = '录音_${now.month}${now.day}_${now.hour}${now.minute}';

      await FileManifest.addRecord(AudioRecord(
        name: defaultName,
        hash: hash,
        format: format,
        createdAt: now,
        size: bytes.length,
        folder: '',
        duration: _recordDurationSeconds,
      ));

      // 删除临时文件
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      if (mounted) {
        // 刷新记录列表
        await ref.read(audioRecordsProvider.notifier).loadRecords();
        await ref.read(folderListProvider.notifier).loadFolders();
        if (!mounted) return;

        _showSnackBar('录音已保存: $defaultName');

        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('保存录音失败: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resetForReRecord() {
    _controller.reset();
    setState(() {
      _recordedFilePath = null;
      _recordDurationSeconds = 0;
    });
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('录音'),
        centerTitle: true,
      ),
      body: Center(
        child: !_isInitialized
            ? const CircularProgressIndicator()
            : kIsWeb
                ? _buildWebNotice()
                : _buildRecordingUI(theme),
      ),
    );
  }

  Widget _buildWebNotice() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 64, color: Colors.orange[300]),
          const SizedBox(height: 16),
          const Text(
            '浏览器暂不支持录音功能',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '请使用 App 版本进行录音',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingUI(ThemeData theme) {
    // 录制中或已暂停 → 显示波形图和控制按钮
    // 录制完成但未保存 → 显示保存/重录
    // 初始状态 → 显示开始按钮
    final isIdle = !_isRecording && !_isPaused && _recordedFilePath == null;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),

          // 波形可视化区域 — 录制/暂停时显示实时波形
          if (_isRecording || _isPaused) ...[
            _buildWaveformArea(theme),
            const SizedBox(height: 24),
          ],

          // 录音时长显示
          Text(
            _recordedFilePath != null
                ? _formatDuration(_recordDurationSeconds)
                : (_isRecording || _isPaused
                    ? _formatDuration(_recordDurationSeconds)
                    : '00:00'),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w200,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: _isPaused
                  ? Colors.orange
                  : _isRecording
                      ? Colors.red
                      : null,
            ),
          ),
          const SizedBox(height: 8),

          // 录制/暂停状态标签
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '录制中 ●',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          if (_isPaused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '已暂停 ||',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ),

          const SizedBox(height: 32),

          // 控制按钮
          if (isIdle) ...[
            // 初始状态：开始录音
            _buildActionButton(
              onPressed: _isPermissionGranted ? _startRecording : null,
              icon: Icons.fiber_manual_record,
              label: _isStarting ? '准备中...' : '开始录音',
              color: Colors.red,
              isLoading: _isStarting,
            ),
          ] else if (_isRecording) ...[
            // 录制中：暂停 + 停止
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  onPressed: _pauseRecording,
                  icon: Icons.pause_circle_filled,
                  label: '暂停',
                  color: Colors.orange,
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  onPressed: _stopRecording,
                  icon: Icons.stop,
                  label: _isStopping ? '停止中...' : '停止',
                  color: Colors.red,
                  isLoading: _isStopping,
                ),
              ],
            ),
          ] else if (_isPaused) ...[
            // 已暂停：恢复 + 停止
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  onPressed: _resumeRecording,
                  icon: Icons.play_circle_filled,
                  label: '恢复',
                  color: Colors.green,
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  onPressed: _stopRecording,
                  icon: Icons.stop,
                  label: _isStopping ? '停止中...' : '停止',
                  color: Colors.red,
                  isLoading: _isStopping,
                ),
              ],
            ),
          ] else if (_recordedFilePath != null) ...[
            // 录音完成：保存 + 重录
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  onPressed: _isSaving ? null : _saveRecording,
                  icon: Icons.save,
                  label: _isSaving ? '保存中...' : '保存录音',
                  color: theme.colorScheme.primary,
                  isLoading: _isSaving,
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  onPressed: _isSaving ? null : _resetForReRecord,
                  icon: Icons.refresh,
                  label: '重新录制',
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaveformArea(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        children: [
          // 波形可视化 — audio_waveforms 内置控件
          // 录制时波形随音量实时跳动
          AudioWaveforms(
            size: const Size(double.infinity, 80),
            recorderController: _controller,
            waveStyle: WaveStyle(
              waveColor: _isPaused
                  ? Colors.orange.withValues(alpha: 0.6)
                  : Colors.red.withValues(alpha: 0.8),
              showMiddleLine: false,
              showTop: true,
              showBottom: true,
              spacing: 6.0,
              waveThickness: 3.0,
              waveCap: StrokeCap.round,
              extendWaveform: true,
              scaleFactor: 25.0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.05),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            margin: EdgeInsets.zero,
          ),
          const SizedBox(height: 4),
          // 波形提示文字
          Text(
            _isPaused ? '暂停录制，波形已冻结' : '音量波形实时显示',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isLoading = false,
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
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
