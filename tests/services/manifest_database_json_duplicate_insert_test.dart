// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
  });

  test('image insert replaces an existing record with the same ID', () async {
    await ManifestDatabase.insertImageRecord({
      'id': 'image-1',
      'name': 'old image',
      'hash': 'old-hash',
    });
    await ManifestDatabase.insertImageRecord({
      'id': 'image-1',
      'name': 'new image',
      'hash': 'new-hash',
    });

    final records = await ManifestDatabase.getAllImageRecords();
    expect(records, hasLength(1));
    expect(records.single['name'], 'new image');
    expect(records.single['hash'], 'new-hash');
  });

  test('audio insert replaces an existing record with the same ID', () async {
    await ManifestDatabase.insertAudioRecord({
      'id': 'audio-1',
      'name': 'old audio',
      'hash': 'old-hash',
    });
    await ManifestDatabase.insertAudioRecord({
      'id': 'audio-1',
      'name': 'new audio',
      'hash': 'new-hash',
    });

    final records = await ManifestDatabase.getAllAudioRecords();
    expect(records, hasLength(1));
    expect(records.single['name'], 'new audio');
    expect(records.single['hash'], 'new-hash');
  });

  test('video insert replaces an existing record with the same ID', () async {
    await ManifestDatabase.insertVideoRecord({
      'id': 'video-1',
      'name': 'old video',
      'hash': 'old-hash',
    });
    await ManifestDatabase.insertVideoRecord({
      'id': 'video-1',
      'name': 'new video',
      'hash': 'new-hash',
    });

    final records = await ManifestDatabase.getAllVideoRecords();
    expect(records, hasLength(1));
    expect(records.single['name'], 'new video');
    expect(records.single['hash'], 'new-hash');
  });

  test('text insert replaces an existing record with the same ID', () async {
    await ManifestDatabase.insertTextRecord({
      'id': 'text-1',
      'name': 'old text',
      'hash': 'old-hash',
    });
    await ManifestDatabase.insertTextRecord({
      'id': 'text-1',
      'name': 'new text',
      'hash': 'new-hash',
    });

    final records = await ManifestDatabase.getAllTextRecords();
    expect(records, hasLength(1));
    expect(records.single['name'], 'new text');
    expect(records.single['hash'], 'new-hash');
  });

  test('direct inserts collapse previously duplicated IDs', () async {
    Map<String, dynamic> record(String id, String name) => {
          'id': id,
          'name': name,
          'hash': name,
        };
    final seededData = {
      ManifestTables.imageRecords: [
        record('image-duplicate', 'old image'),
        record('image-duplicate', 'stale image'),
      ],
      ManifestTables.audioRecords: [
        record('audio-duplicate', 'old audio'),
        record('audio-duplicate', 'stale audio'),
      ],
      ManifestTables.videoRecords: [
        record('video-duplicate', 'old video'),
        record('video-duplicate', 'stale video'),
      ],
      ManifestTables.textRecords: [
        record('text-duplicate', 'old text'),
        record('text-duplicate', 'stale text'),
      ],
    };
    await WebFileStore.write(
      'manifest_database_data',
      Uint8List.fromList(utf8.encode(jsonEncode(seededData))),
    );
    ManifestDatabase.invalidateWebDataCacheForTesting();

    await ManifestDatabase.insertImageRecord(
      record('image-duplicate', 'new image'),
    );
    await ManifestDatabase.insertAudioRecord(
      record('audio-duplicate', 'new audio'),
    );
    await ManifestDatabase.insertVideoRecord(
      record('video-duplicate', 'new video'),
    );
    await ManifestDatabase.insertTextRecord(
      record('text-duplicate', 'new text'),
    );

    final imageRecords = await ManifestDatabase.getAllImageRecords();
    expect(imageRecords, hasLength(1));
    expect(imageRecords.single['name'], 'new image');
    final audioRecords = await ManifestDatabase.getAllAudioRecords();
    expect(audioRecords, hasLength(1));
    expect(audioRecords.single['name'], 'new audio');
    final videoRecords = await ManifestDatabase.getAllVideoRecords();
    expect(videoRecords, hasLength(1));
    expect(videoRecords.single['name'], 'new video');
    final textRecords = await ManifestDatabase.getAllTextRecords();
    expect(textRecords, hasLength(1));
    expect(textRecords.single['name'], 'new text');
  });

  test('direct inserts keep records with null IDs', () async {
    await ManifestDatabase.insertImageRecord({'name': 'first image'});
    await ManifestDatabase.insertImageRecord(
        {'id': null, 'name': 'second image'});
    await ManifestDatabase.insertAudioRecord({'name': 'first audio'});
    await ManifestDatabase.insertAudioRecord(
        {'id': null, 'name': 'second audio'});
    await ManifestDatabase.insertVideoRecord({'name': 'first video'});
    await ManifestDatabase.insertVideoRecord(
        {'id': null, 'name': 'second video'});
    await ManifestDatabase.insertTextRecord({'name': 'first text'});
    await ManifestDatabase.insertTextRecord(
        {'id': null, 'name': 'second text'});

    expect(await ManifestDatabase.getAllImageRecords(), hasLength(2));
    expect(await ManifestDatabase.getAllAudioRecords(), hasLength(2));
    expect(await ManifestDatabase.getAllVideoRecords(), hasLength(2));
    expect(await ManifestDatabase.getAllTextRecords(), hasLength(2));

    final reusedNullIdRecord = {'id': null, 'name': 'reused text'};
    await ManifestDatabase.insertTextRecord(reusedNullIdRecord);
    var commitChecks = 0;
    await expectLater(
      ManifestDatabase.insertTextRecord(
        reusedNullIdRecord,
        beforeCommit: () {
          commitChecks++;
          if (commitChecks == 2) throw StateError('cancelled');
        },
      ),
      throwsStateError,
    );
    expect(
      (await ManifestDatabase.getAllTextRecords())
          .map((record) => record['name']),
      ['first text', 'second text', 'reused text'],
    );
  });

  test('direct inserts match numeric IDs to their SQLite text form', () async {
    await ManifestDatabase.insertImageRecord({'id': '1', 'name': 'old image'});
    await ManifestDatabase.insertImageRecord({'id': 1, 'name': 'new image'});
    await ManifestDatabase.insertAudioRecord({'id': '1', 'name': 'old audio'});
    await ManifestDatabase.insertAudioRecord({'id': 1, 'name': 'new audio'});
    await ManifestDatabase.insertVideoRecord({'id': '1', 'name': 'old video'});
    await ManifestDatabase.insertVideoRecord({'id': 1, 'name': 'new video'});
    await ManifestDatabase.insertTextRecord({'id': '1', 'name': 'old text'});
    await ManifestDatabase.insertTextRecord({'id': 1, 'name': 'new text'});

    final imageRecords = await ManifestDatabase.getAllImageRecords();
    expect(imageRecords, hasLength(1));
    expect(imageRecords.single['name'], 'new image');
    expect(imageRecords.single['id'], '1');
    final audioRecords = await ManifestDatabase.getAllAudioRecords();
    expect(audioRecords, hasLength(1));
    expect(audioRecords.single['name'], 'new audio');
    final videoRecords = await ManifestDatabase.getAllVideoRecords();
    expect(videoRecords, hasLength(1));
    expect(videoRecords.single['name'], 'new video');
    final textRecords = await ManifestDatabase.getAllTextRecords();
    expect(textRecords, hasLength(1));
    expect(textRecords.single['name'], 'new text');
  });
}
