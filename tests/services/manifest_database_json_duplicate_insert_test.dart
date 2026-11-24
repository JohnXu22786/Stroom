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
}
