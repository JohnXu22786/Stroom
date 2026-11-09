import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/tts_audio_saver.dart';

void main() {
  final audio = Uint8List.fromList([1, 2, 3]);
  final text = Uint8List.fromList(utf8.encode('hello'));

  AudioRecord record({String hash = 'same-hash', String format = 'wav'}) =>
      AudioRecord(
        name: 'speech',
        hash: hash,
        format: format,
        createdAt: DateTime(2025),
        size: audio.length,
        sourceText: 'hello',
      );

  test(
    'failed publication removes the audio file written for the save',
    () async {
      final candidate = record();
      final files = <String, Uint8List>{};
      final failure = StateError('record insert failed');

      await expectLater(
        writeTtsAudioAndPublish(
          candidate,
          audio,
          null,
          writeFile: (name, bytes) async {
            files[name] = bytes;
          },
          addRecord: (_) async => throw failure,
          loadRecords: () async => [],
          deleteFile: (name) async {
            files.remove(name);
          },
        ),
        throwsA(same(failure)),
      );

      expect(files, isEmpty);
    },
  );

  test('partial audio write failure removes its unreferenced file', () async {
    final candidate = record();
    final files = <String, Uint8List>{};
    final failure = StateError('audio write failed');

    await expectLater(
      writeTtsAudioAndPublish(
        candidate,
        audio,
        null,
        writeFile: (name, bytes) async {
          files[name] = Uint8List.fromList(bytes.take(1).toList());
          throw failure;
        },
        addRecord: (_) async {},
        loadRecords: () async => [],
        deleteFile: (name) async {
          files.remove(name);
        },
      ),
      throwsA(same(failure)),
    );

    expect(files, isEmpty);
  });

  test(
    'failed companion write removes partial audio and text destinations',
    () async {
      final candidate = record();
      final files = <String, Uint8List>{};
      final failure = StateError('text write failed');

      await expectLater(
        writeTtsAudioAndPublish(
          candidate,
          audio,
          text,
          writeFile: (name, bytes) async {
            files[name] = bytes;
            if (name == candidate.textStoragePath) throw failure;
          },
          addRecord: (_) async {},
          loadRecords: () async => [],
          deleteFile: (name) async {
            files.remove(name);
          },
        ),
        throwsA(same(failure)),
      );

      expect(files, isEmpty);
    },
  );

  test(
    'cleanup keeps destinations shared with an existing manifest record',
    () async {
      final candidate = record();
      final existing = record();
      final files = <String, Uint8List>{};

      await expectLater(
        writeTtsAudioAndPublish(
          candidate,
          audio,
          text,
          writeFile: (name, bytes) async {
            files[name] = bytes;
          },
          addRecord: (_) async => throw StateError('record insert failed'),
          loadRecords: () async => [existing],
          deleteFile: (name) async {
            files.remove(name);
          },
        ),
        throwsStateError,
      );

      expect(files.keys, contains(candidate.textStoragePath));
      expect(files[candidate.textStoragePath], text);
      expect(files[candidate.storageFileName], audio);
    },
  );

  test(
    'successful save publishes record and leaves expected contents',
    () async {
      final candidate = record();
      final files = <String, Uint8List>{};
      final records = <AudioRecord>[];

      final saved = await writeTtsAudioAndPublish(
        candidate,
        audio,
        text,
        writeFile: (name, bytes) async {
          files[name] = bytes;
        },
        addRecord: (savedRecord) async {
          records.add(savedRecord);
        },
        loadRecords: () async => records,
        deleteFile: (name) async {
          files.remove(name);
        },
      );

      expect(saved, same(candidate));
      expect(records, [candidate]);
      expect(files[candidate.storageFileName], audio);
      expect(files[candidate.textStoragePath], text);
    },
  );
}
