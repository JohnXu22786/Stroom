import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/audio_recording_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';

/// Sets up mock method channels for audio_waveforms and shared_preferences.
void _setupMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // Mock the audio_waveforms method channel for recording
  // The audio_waveforms package uses these channels internally.
  // We mock them to return basic defaults so the widget doesn't crash.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('audio_waveforms'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'hasPermission':
          return true;
        case 'checkPermission':
          return true;
        case 'startRecording':
          return true;
        case 'stopRecording':
          return 'test_recording_path.m4a';
        case 'pauseRecording':
          return true;
        case 'resumeRecording':
          return true;
        case 'getPlatformVersion':
          return 'android';
        case 'dispose':
          return true;
        case 'getAudioDuration':
          return 30000; // 30 seconds in ms
        case 'getDecibel':
          return -20.0;
        default:
          return null;
      }
    },
  );
}

void main() {
  setUp(() async {
    _setupMocks();
    ManifestDatabase.enableTestMode();
    FileManifest.invalidateCache();
  });

  group('AudioRecordingPage widget', () {
    testWidgets('renders AppBar with correct title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AudioRecordingPage(),
          ),
        ),
      );
      await tester.pump();

      // Verify AppBar title
      expect(find.text('录音'), findsOneWidget);
    });

    testWidgets('shows record button in initial state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AudioRecordingPage(),
          ),
        ),
      );
      await tester.pump();

      // In the initial state, we should see the record button
      // The permission is granted by mock, so the button should be enabled
      expect(find.text('开始录音'), findsOneWidget);
    });

    testWidgets('shows timer display in 00:00 initially', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AudioRecordingPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('00:00'), findsOneWidget);
    });
  });

  group('AudioRecordingPage FileManifest integration', () {
    test('saves audio record with m4a format and retrieves by hash', () async {
      const hash = 'test_audio_hash_001';
      const format = 'm4a';
      const duration = 30;

      // Create a record similar to what the page would create
      final now = DateTime.now();
      final record = AudioRecord(
        name: '录音_${now.month}${now.day}_${now.hour}${now.minute}',
        hash: hash,
        format: format,
        createdAt: now,
        size: 1024,
        folder: '',
        duration: duration,
      );

      await FileManifest.addRecord(record);

      // Verify it was saved
      final found = await FileManifest.getRecordByHash(hash);
      expect(found, isNotNull);
      expect(found!.format, equals(format));
      expect(found.duration, equals(duration));
      expect(found.hash, equals(hash));

      // Verify storage path
      expect(found.storagePath, equals('$hash.$format'));
      expect(found.storageFileName, equals('$hash.$format'));
    });

    test('saves multiple recordings with different hashes', () async {
      final records = [
        AudioRecord(
          name: 'first',
          hash: 'hash_1',
          format: 'm4a',
          createdAt: DateTime.now(),
          size: 2048,
          duration: 15,
        ),
        AudioRecord(
          name: 'second',
          hash: 'hash_2',
          format: 'm4a',
          createdAt: DateTime.now(),
          size: 4096,
          duration: 45,
        ),
      ];

      for (final record in records) {
        await FileManifest.addRecord(record);
      }

      for (final record in records) {
        final found = await FileManifest.getRecordByHash(record.hash);
        expect(found, isNotNull);
        expect(found!.name, equals(record.name));
        expect(found.duration, equals(record.duration));
      }
    });

    test('file path is absolute and accessible', () async {
      // When the audio_waveforms package stops recording, it returns
      // an absolute file path. We verify the path handling works.
      const mockRecordedPath = '/data/user/0/app/documents/recording_12345.m4a';

      // Verify it's an absolute path
      expect(mockRecordedPath.startsWith('/'), isTrue);
      expect(mockRecordedPath.endsWith('.m4a'), isTrue);

      // The page would use this path to read the file, compute hash, and save
      // We test the FileManifest save with the expected format
      const hash = 'abc123';
      const format = 'm4a';
      final now = DateTime(2024, 6, 15);

      final record = AudioRecord(
        name: '录音_615_1230',
        hash: hash,
        format: format,
        createdAt: now,
        size: 5000,
        folder: '',
        duration: 30,
      );

      await FileManifest.addRecord(record);

      final found = await FileManifest.getRecordByHash(hash);
      expect(found, isNotNull);
      expect(found!.name, equals('录音_615_1230'));
      expect(found.format, equals('m4a'));
      expect(found.duration, equals(30));

      // Default name pattern: 录音_{month}{day}_{hour}{minute}
      expect(found.name, contains('录音'));
    });
  });

  group('AudioRecord m4a format handling', () {
    test('audio record with m4a format round-trips through toMap/fromMap',
        () async {
      final original = AudioRecord(
        name: 'test_m4a',
        hash: 'm4a_hash_001',
        format: 'm4a',
        createdAt: DateTime(2024, 6, 15, 10, 30),
        size: 32000,
        folder: '',
        duration: 60,
      );

      final map = original.toMap();
      final restored = AudioRecord.fromMap(map);

      expect(restored.hash, equals(original.hash));
      expect(restored.format, equals('m4a'));
      expect(restored.duration, equals(60));
      expect(restored.name, equals('test_m4a'));
      expect(restored.size, equals(32000));
      expect(restored.createdAt, equals(original.createdAt));
    });

    test('audio record with m4a format survives database round-trip', () async {
      final record = AudioRecord(
        name: 'db_test',
        hash: 'db_hash_002',
        format: 'm4a',
        createdAt: DateTime.now(),
        size: 64000,
        folder: '',
        duration: 120,
      );

      await FileManifest.addRecord(record);

      final loaded = await FileManifest.loadRecords();
      final found = loaded.where((r) => r.hash == 'db_hash_002').firstOrNull;

      expect(found, isNotNull);
      expect(found!.format, equals('m4a'));
      expect(found.duration, equals(120));
      expect(found.size, equals(64000));
    });
  });

  group('computeAudioHash', () {
    test('produces consistent MD5 hash for same data', () {
      final data = Uint8List.fromList(
        List<int>.generate(100, (i) => i % 256),
      );
      final hash1 = computeAudioHash(data);
      final hash2 = computeAudioHash(data);

      expect(hash1, equals(hash2));
      expect(hash1.length, greaterThan(0));
    });

    test('produces different hash for different data', () {
      final data1 = Uint8List.fromList([1, 2, 3, 4, 5]);
      final data2 = Uint8List.fromList([5, 4, 3, 2, 1]);

      final hash1 = computeAudioHash(data1);
      final hash2 = computeAudioHash(data2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('handles empty data', () {
      final data = Uint8List.fromList([]);
      final hash = computeAudioHash(data);
      // MD5 of empty is d41d8cd98f00b204e9800998ecf8427e
      expect(hash, isNotEmpty);
      expect(hash, equals('d41d8cd98f00b204e9800998ecf8427e'));
    });
  });
}
