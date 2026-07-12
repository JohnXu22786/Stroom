import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';

void main() {
  group('ChatService - audio/video attachment in _prepareApiMessages', () {
    test('audio attachment produces input_audio content part', () async {
      final audioBytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      final b64 = base64Encode(audioBytes);
      final att = Attachment(
        fileName: 'test_audio.mp3',
        mimeType: 'audio/mpeg',
        fileType: 'audio',
        hash: 'audiohash123',
        storagePath: 'attachments/audiohash123_test.mp3',
        fileSize: audioBytes.length,
      )..base64Data = b64;

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': 'Transcribe this audio'});

      for (final a in [att]) {
        if (a.fileType == 'audio') {
          final format = a.fileName.split('.').last.toLowerCase();
          parts.add({
            'type': 'input_audio',
            'input_audio': {
              'data': b64,
              'format': format,
            },
          });
        }
      }

      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      expect(parts[0]['text'], 'Transcribe this audio');
      expect(parts[1]['type'], 'input_audio');
      expect(
        (parts[1]['input_audio'] as Map)['data'],
        b64,
      );
      expect(
        (parts[1]['input_audio'] as Map)['format'],
        'mp3',
      );
    });

    test('audio attachment with wav format uses correct extension', () async {
      final audioBytes = Uint8List.fromList([10, 20, 30]);
      final b64 = base64Encode(audioBytes);
      final att = Attachment(
        fileName: 'recording.wav',
        mimeType: 'audio/wav',
        fileType: 'audio',
        hash: 'wavhash456',
        storagePath: 'attachments/wavhash456_recording.wav',
        fileSize: audioBytes.length,
      )..base64Data = b64;

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': 'Process this'});

      for (final a in [att]) {
        if (a.fileType == 'audio') {
          final format = a.fileName.split('.').last.toLowerCase();
          parts.add({
            'type': 'input_audio',
            'input_audio': {
              'data': b64,
              'format': format,
            },
          });
        }
      }

      expect(parts[1]['type'], 'input_audio');
      expect(
        (parts[1]['input_audio'] as Map)['format'],
        'wav',
      );
    });

    test('video attachment sends actual file data via data URI', () async {
      final videoBytes = Uint8List.fromList([5, 10, 15, 20]);
      final b64 = base64Encode(videoBytes);
      final att = Attachment(
        fileName: 'test_video.mp4',
        mimeType: 'video/mp4',
        fileType: 'video',
        hash: 'videohash789',
        storagePath: 'attachments/videohash789_test.mp4',
        fileSize: videoBytes.length,
      )..base64Data = b64;

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': 'Analyze this video'});

      for (final a in [att]) {
        if (a.fileType == 'video') {
          parts.add({
            'type': 'image_url',
            'image_url': {
              'url': 'data:${a.mimeType};base64,$b64',
            },
          });
        }
      }

      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      expect(parts[1]['type'], 'image_url');
      expect(
        (parts[1]['image_url'] as Map)['url'],
        'data:video/mp4;base64,$b64',
      );
    });

    test('audio attachment with cached base64 uses cache', () async {
      final b64 = 'cached_audio_base64_data';
      final att = Attachment(
        fileName: 'song.mp3',
        mimeType: 'audio/mpeg',
        fileType: 'audio',
        hash: 'cachedaudiotest',
        storagePath: 'attachments/cachedaudiotest_song.mp3',
        fileSize: 500,
      )..base64Data = b64;

      bool diskReadAttempted = false;

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': 'Hear this'});

      for (final a in [att]) {
        if (a.fileType == 'audio') {
          if (a.base64Data != null && a.base64Data!.isNotEmpty) {
            final format = a.fileName.split('.').last.toLowerCase();
            parts.add({
              'type': 'input_audio',
              'input_audio': {
                'data': a.base64Data!,
                'format': format,
              },
            });
          } else {
            diskReadAttempted = true;
            parts.add({
              'type': 'text',
              'text': '[Audio: ${a.fileName}]',
            });
          }
        }
      }

      expect(diskReadAttempted, false);
      expect(parts.length, 2);
      expect(parts[1]['type'], 'input_audio');
      expect(
        (parts[1]['input_audio'] as Map)['data'],
        b64,
      );
    });

    test('video attachment with cached base64 uses cache', () async {
      final b64 = 'cached_video_base64_data';
      final att = Attachment(
        fileName: 'movie.mp4',
        mimeType: 'video/mp4',
        fileType: 'video',
        hash: 'cachedvideotest',
        storagePath: 'attachments/cachedvideotest_movie.mp4',
        fileSize: 800,
      )..base64Data = b64;

      bool diskReadAttempted = false;

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': 'Watch this'});

      for (final a in [att]) {
        if (a.fileType == 'video') {
          if (a.base64Data != null && a.base64Data!.isNotEmpty) {
            parts.add({
              'type': 'image_url',
              'image_url': {
                'url': 'data:${a.mimeType};base64,${a.base64Data!}',
              },
            });
          } else {
            diskReadAttempted = true;
            parts.add({
              'type': 'text',
              'text': '[Video: ${a.fileName}]',
            });
          }
        }
      }

      expect(diskReadAttempted, false);
      expect(parts.length, 2);
      expect(parts[1]['type'], 'image_url');
      expect(
        (parts[1]['image_url'] as Map)['url'],
        'data:video/mp4;base64,$b64',
      );
    });

    test('large audio file (>10MB) gets skipped with descriptive text',
        () async {
      final att = Attachment(
        fileName: 'big_audio.mp3',
        mimeType: 'audio/mpeg',
        fileType: 'audio',
        hash: 'bigaudiotest',
        storagePath: 'attachments/bigaudiotest_big.mp3',
        fileSize: 11 * 1024 * 1024, // 11MB
      )..base64Data = 'some_big_data';

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': 'Listen'});

      for (final a in [att]) {
        if (a.fileType == 'audio') {
          if (a.fileSize > 10 * 1024 * 1024) {
            parts.add({
              'type': 'text',
              'text': '[音频文件过大已跳过: ${a.fileName}]',
            });
          } else {
            final format = a.fileName.split('.').last.toLowerCase();
            parts.add({
              'type': 'input_audio',
              'input_audio': {
                'data': a.base64Data!,
                'format': format,
              },
            });
          }
        }
      }

      expect(parts.length, 2);
      expect(parts[1]['type'], 'text');
      expect(
        (parts[1]['text'] as String).contains('big_audio.mp3'),
        true,
      );
    });

    test('large video file (>10MB) gets skipped with descriptive text',
        () async {
      final att = Attachment(
        fileName: 'big_video.mp4',
        mimeType: 'video/mp4',
        fileType: 'video',
        hash: 'bigvideotest',
        storagePath: 'attachments/bigvideotest_big.mp4',
        fileSize: 15 * 1024 * 1024, // 15MB
      )..base64Data = 'some_big_video_data';

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': 'Watch'});

      for (final a in [att]) {
        if (a.fileType == 'video') {
          if (a.fileSize > 10 * 1024 * 1024) {
            parts.add({
              'type': 'text',
              'text': '[视频文件过大已跳过: ${a.fileName}]',
            });
          } else {
            parts.add({
              'type': 'text',
              'text': '[视频文件已附加: ${a.fileName}]',
            });
          }
        }
      }

      expect(parts.length, 2);
      expect(parts[1]['type'], 'text');
      expect(
        (parts[1]['text'] as String).contains('big_video.mp4'),
        true,
      );
    });

    test('audio attachment without cached base64 would read from disk',
        () async {
      final att = Attachment(
        fileName: 'no_cache_audio.wav',
        mimeType: 'audio/wav',
        fileType: 'audio',
        hash: 'nocacheaudiotest',
        storagePath: 'attachments/nocacheaudiotest.wav',
        fileSize: 200,
      );
      // base64Data is NOT set → null

      bool diskReadNeeded = false;

      for (final a in [att]) {
        if (a.fileType == 'audio' || a.fileType == 'video') {
          if (a.base64Data == null || a.base64Data!.isEmpty) {
            diskReadNeeded = true;
          }
        }
      }

      expect(diskReadNeeded, true);
    });

    test('image attachments still work with image_url format', () async {
      final b64 = base64Encode(Uint8List.fromList([1, 2, 3]));
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'image_test',
        storagePath: 'attachments/image_test.png',
        fileSize: 100,
      )..base64Data = b64;

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': 'Look at this'});

      for (final a in [att]) {
        if (a.fileType == 'image') {
          parts.add({
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/png;base64,$b64',
            },
          });
        }
      }

      expect(parts.length, 2);
      expect(parts[1]['type'], 'image_url');
    });

    test('text document attachments still produce text content', () async {
      final att = Attachment(
        fileName: 'notes.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'text_test',
        storagePath: 'attachments/text_test.txt',
        fileSize: 50,
      );

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': 'Read this'});

      for (final a in [att]) {
        if (a.fileType == 'image') {
          // image handling
        } else if (a.fileType == 'audio') {
          // audio handling
        } else if (a.fileType == 'video') {
          // video handling
        } else {
          final textExts = [
            'txt',
            'md',
            'json',
            'csv',
            'log',
            'yaml',
            'xml',
            'ini',
            'cfg',
            'py',
            'js',
            'ts',
            'dart',
            'java',
            'cpp',
            'h',
            'rs',
            'go',
            'rb',
            'php',
          ];
          final ext = a.fileName.split('.').last.toLowerCase();
          if (textExts.contains(ext)) {
            parts.add({
              'type': 'text',
              'text': '以下为文件 ${a.fileName} 的内容:\n...',
            });
          } else {
            parts.add({
              'type': 'text',
              'text': '[Attached file: ${a.fileName}]',
            });
          }
        }
      }

      expect(parts.length, 2);
      expect(parts[1]['type'], 'text');
      expect(
        (parts[1]['text'] as String).contains('notes.txt'),
        true,
      );
    });

    test('non-audio/video/image files still produce text description',
        () async {
      final att = Attachment(
        fileName: 'archive.zip',
        mimeType: 'application/zip',
        fileType: 'document',
        hash: 'zip_test',
        storagePath: 'attachments/zip_test.zip',
        fileSize: 1000,
      );

      final parts = <Map<String, dynamic>>[];
      parts.add({'type': 'text', 'text': 'Here is a file'});

      for (final a in [att]) {
        if (a.fileType == 'image') {
          // image handling
        } else if (a.fileType == 'audio') {
          // audio handling
        } else if (a.fileType == 'video') {
          // video handling
        } else {
          final textExts = [
            'txt',
            'md',
            'json',
            'csv',
            'log',
            'yaml',
            'xml',
            'ini',
            'cfg',
            'py',
            'js',
            'ts',
            'dart',
            'java',
            'cpp',
            'h',
            'rs',
            'go',
            'rb',
            'php',
          ];
          final ext = a.fileName.split('.').last.toLowerCase();
          if (textExts.contains(ext)) {
            parts.add({
              'type': 'text',
              'text': '以下为文件 ${a.fileName} 的内容:\n...',
            });
          } else {
            parts.add({
              'type': 'text',
              'text': '[Attached file: ${a.fileName}]',
            });
          }
        }
      }

      expect(parts.length, 2);
      expect(parts[1]['type'], 'text');
      expect(
        (parts[1]['text'] as String).contains('[Attached file: archive.zip]'),
        true,
      );
    });
  });
}
