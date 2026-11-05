import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/services/chat_media_tool_service.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/image_manifest.dart';

Attachment _attachment(String id, String type) => Attachment(
      id: id,
      fileName: '$id.${type == 'image' ? 'png' : 'wav'}',
      mimeType: type == 'image' ? 'image/png' : 'audio/wav',
      fileType: type,
      hash: id,
      storagePath: 'attachments/$id',
      fileSize: 12,
    );

void main() {
  group('ChatMediaToolService', () {
    test('includes attachments from the current outgoing user message', () {
      final existing = _attachment('previous', 'image');
      final current = _attachment('current', 'image');
      final messages = [
        ChatMessage(
          role: 'user',
          content: 'previous',
          attachments: [existing],
        ),
        ChatMessage(
          role: 'user',
          content: 'analyze this image',
          attachments: [current],
        ),
      ];

      final attachments =
          ChatMediaToolService.attachmentsFromMessages(messages);

      expect(attachments.map((attachment) => attachment.id), [
        'previous',
        'current',
      ]);
    });

    test('lists bounded app media metadata without storage paths', () {
      final records = [
        for (var i = 0; i < 3; i++)
          ImageRecord(
            id: 'image-$i',
            name: 'Diagram $i',
            hash: 'hash-$i',
            format: 'png',
            createdAt: DateTime.utc(2026, 1, i + 1),
            size: 1024,
          ),
      ];

      final result = ChatMediaToolService.formatMediaList(
        records,
        type: 'image',
        limit: 2,
      );
      final decoded = jsonDecode(result) as List<dynamic>;

      expect(decoded, hasLength(2));
      expect(decoded.first['id'], 'image-2');
      expect(decoded.first['name'], 'Diagram 2');
      expect(decoded.first['type'], 'image');
      expect(result, isNot(contains('storagePath')));
      expect(result, isNot(contains('hash-2')));
    });

    test('resolves a library record by opaque ID only', () {
      final records = [
        ImageRecord(
          id: 'image-1',
          name: 'Diagram',
          hash: 'hash',
          format: 'png',
          createdAt: DateTime.utc(2026),
          size: 5,
        ),
      ];

      expect(
        ChatMediaToolService.findRecordById(records, 'image-1')?.name,
        'Diagram',
      );
      expect(ChatMediaToolService.findRecordById(records, 'hash'), isNull);
    });

    test(
      'lists only requested media and honors limit and record names',
      () async {
        var audioLoaded = false;
        final result = await ChatMediaToolService.handleLibraryList(
          const {'media_type': 'image', 'limit': 1},
          loadImages: () async => [
            ImageRecord(
              id: 'newer',
              name: 'Newer',
              hash: 'private-hash',
              format: 'png',
              createdAt: DateTime.utc(2026, 1, 2),
              size: 4,
            ),
            ImageRecord(
              id: 'older',
              name: 'Older',
              hash: 'older-hash',
              format: 'jpg',
              createdAt: DateTime.utc(2026, 1, 1),
              size: 3,
            ),
          ],
          loadAudio: () async {
            audioLoaded = true;
            return [
              AudioRecord(
                id: 'audio',
                name: 'Audio',
                hash: 'audio-hash',
                format: 'wav',
                createdAt: DateTime.utc(2026),
                size: 9,
              ),
            ];
          },
        );
        final decoded = jsonDecode(result) as List<dynamic>;

        expect(audioLoaded, isFalse);
        expect(decoded, hasLength(1));
        expect(decoded.single['id'], 'newer');
        expect(decoded.single['type'], 'image');
        expect(result, isNot(contains('private-hash')));
        expect(result, isNot(contains('storagePath')));
      },
    );

    test('rejects an out-of-range media list limit', () async {
      var loaded = false;
      final result = await ChatMediaToolService.handleLibraryList(
        const {'limit': 51},
        loadImages: () async {
          loaded = true;
          return [];
        },
        loadAudio: () async => [],
      );

      expect(loaded, isFalse);
      expect(result, contains('limit must be an integer from 1 to 50'));
    });

    test('library OCR and ASR reject a path instead of resolving it', () async {
      var imageRead = false;
      var audioRead = false;
      final imageResult = await ChatMediaToolService.handleOcr(
        const {'image_id': '/private/image.png'},
        attachments: const [],
        recognize: (_) async => 'unexpected',
        recognizeLibraryImage: (id) async {
          imageRead = true;
          return ChatMediaToolService.findRecordById([
                    ImageRecord(
                      id: 'image-id',
                      name: 'Image',
                      hash: 'hash',
                      format: 'png',
                      createdAt: DateTime.utc(2026),
                      size: 1,
                    ),
                  ], id) ==
                  null
              ? 'Error: the selected Stroom image was not found.'
              : 'unexpected';
        },
      );
      final audioResult = await ChatMediaToolService.handleAsr(
        const {'audio_id': '/private/audio.wav'},
        attachments: const [],
        transcribe: (_) async => 'unexpected',
        transcribeLibraryAudio: (id) async {
          audioRead = true;
          return ChatMediaToolService.findRecordById([
                    AudioRecord(
                      id: 'audio-id',
                      name: 'Audio',
                      hash: 'hash',
                      format: 'wav',
                      createdAt: DateTime.utc(2026),
                      size: 1,
                    ),
                  ], id) ==
                  null
              ? 'Error: the selected Stroom audio file was not found.'
              : 'unexpected';
        },
      );

      expect(imageRead, isTrue);
      expect(audioRead, isTrue);
      expect(imageResult, contains('not found'));
      expect(audioResult, contains('not found'));
    });

    test(
      'defaults to the newest matching attachment in this conversation',
      () async {
        final oldImage = _attachment('old', 'image');
        final audio = _attachment('audio', 'audio');
        final newImage = _attachment('new', 'image');

        final result = await ChatMediaToolService.handleOcr(
          const {},
          attachments: [oldImage, audio, newImage],
          recognize: (attachment) async => attachment.id,
        );

        expect(result, 'new');
      },
    );

    test(
      'uses the requested index among matching media attachments only',
      () async {
        final first = _attachment('first', 'audio');
        final image = _attachment('image', 'image');
        final second = _attachment('second', 'audio');

        final result = await ChatMediaToolService.handleAsr(
          const {'attachment_index': 0},
          attachments: [first, image, second],
          transcribe: (attachment) async => attachment.id,
        );

        expect(result, 'first');
      },
    );

    test(
      'does not pass through a path or resolve attachments outside the list',
      () async {
        var called = false;
        final result = await ChatMediaToolService.handleOcr(
          const {'path': '/private/other-chat.png', 'attachment_index': 2},
          attachments: [_attachment('current-chat', 'image')],
          recognize: (_) async {
            called = true;
            return 'unexpected';
          },
        );

        expect(called, isFalse);
        expect(result, contains('does not identify an image'));
      },
    );

    test(
      'rejects missing media and non-integer indexes without calling runner',
      () async {
        var called = false;
        final result = await ChatMediaToolService.handleAsr(
          const {'attachment_index': '0'},
          attachments: [_attachment('audio', 'audio')],
          transcribe: (_) async {
            called = true;
            return 'unexpected';
          },
        );

        expect(called, isFalse);
        expect(result, contains('does not identify audio'));
      },
    );

    test('uses the decoded image MIME after chat attachment processing', () {
      expect(
        ChatMediaToolService.imageFormat(
          _attachment('image', 'image'),
          mimeType: 'image/jpeg',
        ),
        'jpeg',
      );
    });

    test('rejects empty speech text before invoking TTS', () async {
      var called = false;
      final result = await ChatMediaToolService.handleTts(
        const {'text': '  '},
        synthesize: (_, _) async {
          called = true;
          return 'saved';
        },
      );

      expect(called, isFalse);
      expect(result, contains('text must contain'));
    });
  });
}
