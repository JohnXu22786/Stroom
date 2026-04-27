import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../utils/storage_service.dart';
import '../utils/audio_playback.dart';
import '../utils/audio_utils.dart';

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
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<void>? _stateSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
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

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadAudio() async {
    final extension =
        path.extension(widget.filePath).replaceAll('.', '').toLowerCase();
    var mimeType = _getMimeType(extension);

    var data = await StorageService.readFile(widget.filePath);

    if (data != null && data.isNotEmpty) {
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
    } else {
      await _player!.play();
    }
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
      body: _buildBody(fileName),
    );
  }

  Widget _buildBody(String fileName) {
    if (_hasError) {
      return _buildErrorView();
    }

    if (!_isInitialized) {
      return _buildLoadingView();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 音频图标
          Icon(
            Icons.audio_file,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),

          // 文件名
          Text(
            fileName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 格式标签
          Chip(
            label: Text(
              path.extension(widget.filePath).replaceAll('.', '').toUpperCase(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),

          // 进度条
          Column(
            children: [
              Slider(
                value: _position.inMilliseconds.toDouble(),
                max: _duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  _seek(Duration(milliseconds: value.toInt()));
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position)),
                    Text(_formatDuration(_duration)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 播放控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 停止按钮
              IconButton(
                icon: const Icon(Icons.stop),
                iconSize: 36,
                color: Colors.red,
                onPressed: _stop,
              ),
              const SizedBox(width: 24),

              // 播放/暂停按钮
              FloatingActionButton(
                onPressed: _togglePlayPause,
                child: Icon(
                  _player?.playing == true ? Icons.pause : Icons.play_arrow,
                  size: 36,
                ),
              ),
              const SizedBox(width: 24),

              // 音量按钮
              IconButton(
                icon: Icon(
                  _player?.volume == 0 ? Icons.volume_off : Icons.volume_up,
                ),
                iconSize: 36,
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
          const SizedBox(height: 24),

          // 播放状态
          Text(
            _player?.playing == true ? '正在播放...' : '已暂停',
            style: TextStyle(
              color: _player?.playing == true ? Colors.green : Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _hasError = false;
                _errorMessage = '';
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
    super.dispose();
  }
}
