// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

/// Makes a live TTS response available to just_audio as its bytes arrive.
class TtsStreamAudioSource extends StreamAudioSource {
  TtsStreamAudioSource(this._chunks, {required this.contentType}) {
    // A player can stop listening before synthesis reports a stream error.
    unawaited(_completed.future.catchError((Object _) {}));
  }

  final Stream<Uint8List> _chunks;
  final String contentType;
  final Completer<void> _completed = Completer<void>();
  StreamSubscription<Uint8List>? _chunksSubscription;
  bool _requested = false;

  /// Completes when synthesis finishes, or fails with its stream error.
  Future<void> get completed => _completed.future;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    if (start != null || end != null) {
      throw UnsupportedError('TTS streams cannot serve byte ranges');
    }
    if (_requested) {
      throw StateError('The TTS stream has already been requested');
    }
    _requested = true;

    final controller = StreamController<List<int>>();
    controller.onListen = () {
      _chunksSubscription = _chunks.listen(
        controller.add,
        onError: (Object error, StackTrace stackTrace) {
          if (!_completed.isCompleted) {
            _completed.completeError(error, stackTrace);
          }
          controller.addError(error, stackTrace);
          unawaited(controller.close());
        },
        onDone: () {
          if (!_completed.isCompleted) _completed.complete();
          unawaited(controller.close());
        },
      );
    };
    controller.onCancel = () async {
      await _chunksSubscription?.cancel();
      _chunksSubscription = null;
      if (!_completed.isCompleted) _completed.complete();
    };

    return StreamAudioResponse(
      rangeRequestsSupported: false,
      sourceLength: null,
      contentLength: null,
      offset: null,
      stream: controller.stream,
      contentType: contentType,
    );
  }
}
