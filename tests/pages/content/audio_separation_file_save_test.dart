import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/audio_separation_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    FileManifest.invalidateCache();
  });

  test('removes written audio when record registration fails without references',
      () async {
    const hash = 'audio_register_failure';
    const storageName = '$hash.wav';
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    await expectLater(
      saveAudioSeparationFile(
        bytes,
        hash: hash,
        format: 'wav',
        saveFolder: '',
        registerRecord: (record) async {
          expect(record.storageFileName, storageName);
          expect(await FileManifest.readFile(storageName), bytes);
          throw StateError('registration failed');
        },
      ),
      throwsA(isA<StateError>()),
    );

    expect(await FileManifest.readFile(storageName), isNull,
        reason: 'unreferenced bytes from the failed save should be removed');
    expect(await FileManifest.loadRecords(), isEmpty);
  });

  test('preserves written audio when another record references the same file',
      () async {
    const hash = 'audio_shared_register_failure';
    const storageName = '$hash.wav';
    final bytes = Uint8List.fromList([5, 6, 7, 8]);
    final existingRecord = AudioRecord(
      id: 'existing_audio_record',
      name: 'existing',
      hash: hash,
      format: 'wav',
      createdAt: DateTime(2025),
      size: bytes.length,
    );
    await FileManifest.addRecord(existingRecord);

    await expectLater(
      saveAudioSeparationFile(
        bytes,
        hash: hash,
        format: 'wav',
        saveFolder: '',
        registerRecord: (_) async => throw StateError('registration failed'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await FileManifest.readFile(storageName), bytes,
        reason: 'a record still references this shared storage file');
    final records = await FileManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.id, existingRecord.id);
  });

  test('registers a record and returns the saved path on success', () async {
    const hash = 'audio_register_success';
    const storageName = '$hash.wav';
    final bytes = Uint8List.fromList([9, 10, 11, 12]);

    final path = await saveAudioSeparationFile(
      bytes,
      hash: hash,
      format: 'wav',
      displayName: 'separated audio',
      saveFolder: '',
    );

    expect(path, 'tts_audio/$storageName');
    expect(await FileManifest.readFile(storageName), bytes);
    final records = await FileManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.storageFileName, storageName);
    expect(records.single.name, 'separated audio');
  });
}
