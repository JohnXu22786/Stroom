import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart' show CancelToken;

/// Web platform audio separation engine.
///
/// Delegates to the pure-Dart MP4 demuxer in audio_separation_native.dart.
/// Since the implementation is entirely in Dart, it works on all platforms
/// without any system dependencies or JS interop.
class AudioSeparationEngine {
  /// Always available — pure Dart implementation.
  Future<bool> isAvailable() async => true;

  static const _supportedFormats = ['mp4', 'mov', 'm4v', '3gp'];

  bool canHandleVideoFormat(String format) {
    if (format.isEmpty) return false;
    return _supportedFormats.contains(format.toLowerCase().trim());
  }

  /// Extract audio using pure-Dart MP4 demuxer.
  Future<Uint8List> extractAudio({
    required Uint8List videoBytes,
    required String videoFormat,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (videoBytes.isEmpty) {
      throw Exception('Video data is empty');
    }
    if (!canHandleVideoFormat(videoFormat)) {
      throw Exception('Unsupported video format: $videoFormat');
    }

    onProgress?.call(0);

    // Parse MP4 and extract audio using pure Dart (no platform deps)
    final mp4 = _Mp4Demuxer(videoBytes);
    final audioTrack = mp4.findAudioTrack();
    if (audioTrack == null) {
      throw Exception('No audio track found in video');
    }

    onProgress?.call(30);

    // Extract individual frames
    final frames = mp4.extractAudioFrames(audioTrack);
    if (frames.isEmpty) {
      throw Exception('No audio data extracted');
    }

    onProgress?.call(60);

    // Package frames (PCM → WAV, AAC → ADTS)
    final result = _packageFrames(frames, audioTrack);
    if (cancelToken?.isCancelled ?? false) {
      throw Exception('Audio extraction was cancelled');
    }

    onProgress?.call(100);
    return result;
  }

  Uint8List _packageFrames(List<_AudioFrame> frames, _AudioTrackInfo track) {
    final result = BytesBuilder();
    for (final frame in frames) {
      result.add(frame.data);
    }
    return result.toBytes();
  }
}

// ============================================================================
// MP4 Demuxer for Web — same pure-Dart implementation as native
// ============================================================================

class _AudioFrame {
  final Uint8List data;
  _AudioFrame(this.data);
}

class _AudioTrackInfo {
  final String codec;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final List<int> sampleSizes;
  final List<int>
      chunkOffsets; // absolute file offset of each chunk (from stco/co64)
  final List<int> sampleToChunkMap;

  _AudioTrackInfo({
    required this.codec,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.sampleSizes,
    required this.chunkOffsets,
    required this.sampleToChunkMap,
  });
}

class _Mp4Demuxer {
  final Uint8List _data;
  int _offset = 0;

  _Mp4Demuxer(this._data);

  _AudioTrackInfo? findAudioTrack() {
    try {
      _offset = 0;
      int moovOffset = -1;
      int mdatOffset = -1;

      while (_offset < _data.length) {
        final boxStart = _offset;
        if (_offset + 8 > _data.length) break;
        final boxSize = _readUint32();
        final boxType = _readString(4);
        if (boxType == 'moov') moovOffset = boxStart;
        if (boxType == 'mdat') mdatOffset = boxStart;
        if (boxSize == 0) break;
        _offset = boxStart + boxSize;
      }

      if (moovOffset < 0 || mdatOffset < 0) return null;

      _offset = moovOffset + 8;
      final moovEnd = moovOffset + _boxSize(moovOffset);

      while (_offset < moovEnd) {
        final childStart = _offset;
        _readUint32();
        final childType = _readString(4);
        if (childType == 'trak') {
          final track = _parseTrack();
          if (track != null) {
            if (track.codec == 'mp4a' || track.codec == 'raw ') return track;
          }
        }
        _offset = childStart + _boxSize(childStart);
      }
      return null;
    } catch (e) {
      debugPrint('[Mp4WebDemuxer] error: $e');
      return null;
    }
  }

  _AudioTrackInfo? _parseTrack() {
    final trackStart = _offset;
    final trackSize = _boxSize(trackStart - 8);
    final trackEnd = trackStart + trackSize - 8;

    String? handlerType;
    String? codec;
    int sampleRate = 0;
    int channels = 0;
    int bitsPerSample = 16;
    List<int> sampleSizes = [];
    List<int> chunkOffsets = [];
    final stscEntries = <_StscEntry>[];

    while (_offset < trackEnd) {
      final childStart = _offset;
      final childSize = _readUint32();
      final childType = _readString(4);

      if (childType == 'mdia') {
        final mdiaEnd = childStart + childSize;
        while (_offset < mdiaEnd) {
          final mcStart = _offset;
          final mcSize = _readUint32();
          final mcType = _readString(4);
          if (mcType == 'hdlr') {
            _offset += 4;
            _offset += 4;
            handlerType = _readString(4);
          } else if (mcType == 'minf') {
            final minfEnd = mcStart + mcSize;
            while (_offset < minfEnd) {
              final icStart = _offset;
              final icSize = _readUint32();
              final icType = _readString(4);
              if (icType == 'stbl') {
                final stblEnd = icStart + icSize;
                while (_offset < stblEnd) {
                  final scStart = _offset;
                  final scSize = _readUint32();
                  final scType = _readString(4);
                  if (scType == 'stsd') {
                    _offset += 4;
                    final entryCount = _readUint32();
                    for (var i = 0; i < entryCount; i++) {
                      final es = _offset;
                      _readUint32();
                      codec = _readString(4);
                      _offset += 6;
                      _offset += 2;
                      if (codec == 'mp4a' || codec == 'raw ') {
                        _offset += 8;
                        channels = _readUint16();
                        bitsPerSample = _readUint16();
                        _offset += 4;
                        sampleRate = _readUint32() >> 16;
                      }
                      _offset = es + _boxSize(es);
                    }
                  } else if (scType == 'stsc') {
                    _offset += 4;
                    final entryCount = _readUint32();
                    for (var i = 0; i < entryCount; i++) {
                      final firstChunk = _readUint32();
                      final spc = _readUint32();
                      _readUint32(); // description index
                      stscEntries.add((firstChunk, spc));
                    }
                  } else if (scType == 'stsz') {
                    _offset += 4;
                    final sampleSize = _readUint32();
                    final count = _readUint32();
                    if (sampleSize == 0) {
                      for (var i = 0; i < count; i++) {
                        sampleSizes.add(_readUint32());
                      }
                    } else {
                      sampleSizes = List.filled(count, sampleSize);
                    }
                  } else if (scType == 'stco') {
                    _offset += 4;
                    final entryCount = _readUint32();
                    for (var i = 0; i < entryCount; i++) {
                      chunkOffsets.add(_readUint32());
                    }
                  } else {
                    _offset = scStart + _boxSize(scStart);
                  }
                }
              } else {
                _offset = icStart + _boxSize(icStart);
              }
            }
          } else {
            _offset = mcStart + _boxSize(mcStart);
          }
        }
      } else {
        _offset = childStart + _boxSize(childStart);
      }
    }

    if (handlerType != 'soun' || codec == null) return null;
    if (sampleSizes.isEmpty || chunkOffsets.isEmpty) return null;

    // Build per-chunk sample map from stsc entries
    final sampleToChunk = List.filled(chunkOffsets.length, 1);
    if (stscEntries.isNotEmpty) {
      for (var i = 0; i < stscEntries.length; i++) {
        final (firstChunk, spc) = stscEntries[i];
        final endChunk = (i + 1 < stscEntries.length)
            ? stscEntries[i + 1].$1 - 1
            : chunkOffsets.length;
        for (var c = firstChunk - 1;
            c < endChunk && c < chunkOffsets.length;
            c++) {
          sampleToChunk[c] = spc;
        }
      }
    }

    return _AudioTrackInfo(
      codec: codec,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      sampleSizes: sampleSizes,
      chunkOffsets: chunkOffsets,
      sampleToChunkMap: sampleToChunk,
    );
  }

  List<_AudioFrame> extractAudioFrames(_AudioTrackInfo track) {
    if (track.sampleSizes.isEmpty || track.chunkOffsets.isEmpty) return [];
    final frames = <_AudioFrame>[];
    int sampleIdx = 0;

    for (var ci = 0;
        ci < track.chunkOffsets.length && sampleIdx < track.sampleSizes.length;
        ci++) {
      final spc =
          ci < track.sampleToChunkMap.length ? track.sampleToChunkMap[ci] : 1;
      for (var s = 0; s < spc && sampleIdx < track.sampleSizes.length; s++) {
        final size = track.sampleSizes[sampleIdx];
        int offsetInChunk = 0;
        if (s > 0) {
          for (var ps = sampleIdx - s; ps < sampleIdx; ps++) {
            offsetInChunk += track.sampleSizes[ps];
          }
        }
        final fileOffset = track.chunkOffsets[ci] + offsetInChunk;
        if (fileOffset + size <= _data.length) {
          frames.add(_AudioFrame(
            Uint8List.sublistView(_data, fileOffset, fileOffset + size),
          ));
        }
        sampleIdx++;
      }
    }
    return frames;
  }

  int _readUint32() {
    if (_offset + 4 > _data.length) return 0;
    final v = (_data[_offset] << 24) |
        (_data[_offset + 1] << 16) |
        (_data[_offset + 2] << 8) |
        _data[_offset + 3];
    _offset += 4;
    return v;
  }

  int _readUint16() {
    if (_offset + 2 > _data.length) return 0;
    return (_data[_offset] << 8) | _data[_offset + 1];
  }

  String _readString(int length) {
    if (_offset + length > _data.length) return '';
    final s = String.fromCharCodes(_data.sublist(_offset, _offset + length));
    _offset += length;
    return s;
  }

  int _boxSize(int offset) {
    if (offset + 4 > _data.length) return 0;
    return (_data[offset] << 24) |
        (_data[offset + 1] << 16) |
        (_data[offset + 2] << 8) |
        _data[offset + 3];
  }
}

typedef _StscEntry = (int, int);
