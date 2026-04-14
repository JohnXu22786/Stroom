import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

/// Audio player service that manages audio playback using just_audio.
/// Handles initialization, playback control, and state management.
class AudioPlayerService {
  late final AudioPlayer _audioPlayer;
  bool _isInitialized = false;

  /// Current playback state
  PlayerState get playerState => _audioPlayer.playerState;

  /// Current playback position
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  /// Buffered position
  Stream<Duration> get bufferedPositionStream =>
      _audioPlayer.bufferedPositionStream;

  /// Total duration of current audio
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  /// Playback state stream
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  /// Constructor
  AudioPlayerService();

  /// Initialize the audio player and audio session
  Future<void> initialize() async {
    if (_isInitialized) return;

    _audioPlayer = AudioPlayer();

    // Configure audio session for speech playback
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());

    _isInitialized = true;
  }

  /// Play audio from file path
  Future<void> play(String filePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
    } catch (e) {
      throw Exception('Failed to play audio: $e');
    }
  }

  /// Pause current playback
  Future<void> pause() async {
    if (!_isInitialized) return;
    await _audioPlayer.pause();
  }

  /// Stop current playback and reset
  Future<void> stop() async {
    if (!_isInitialized) return;
    await _audioPlayer.stop();
    await _audioPlayer.seek(Duration.zero);
  }

  /// Seek to specific position
  Future<void> seek(Duration position) async {
    if (!_isInitialized) return;
    await _audioPlayer.seek(position);
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) return;
    await _audioPlayer.setVolume(volume);
  }

  /// Set playback speed (0.5 to 2.0)
  Future<void> setSpeed(double speed) async {
    if (!_isInitialized) return;
    await _audioPlayer.setSpeed(speed);
  }

  /// Dispose the audio player
  Future<void> dispose() async {
    if (!_isInitialized) return;
    await _audioPlayer.dispose();
    _isInitialized = false;
  }

  /// Check if audio is currently playing
  bool get isPlaying => playerState.playing;

  /// Get current playback position
  Duration? get currentPosition => _audioPlayer.position;

  /// Get total duration of current audio
  Duration? get currentDuration => _audioPlayer.duration;
}
