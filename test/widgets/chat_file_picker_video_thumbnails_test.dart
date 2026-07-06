import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/chat_file_picker_dialog.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/video_manifest.dart';

// ============================================================================
// Tests: video thumbnails in chat file picker dialog
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    VideoManifest.invalidateCache();
  });

  Widget _buildTestApp() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showAppFilePickerDialog(context),
              child: const Text('Open Picker'),
            );
          },
        ),
      ),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    );
  }

  group('ChatFilePickerDialog video thumbnails', () {
    testWidgets('shows video file item with thumbnail fallback icon', (
      tester,
    ) async {
      // Insert a video record into the test database
      await VideoManifest.addRecord(
        VideoRecord(
          name: 'test_video',
          hash: 'test_hash_1',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 1024,
          duration: 5000,
        ),
      );

      await tester.pumpWidget(_buildTestApp());

      // Open the picker
      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      // Wait for all tab data to load (4 tabs load async)
      await tester.pump(const Duration(seconds: 1));

      // The dialog should be open
      expect(find.text('选择文件'), findsOneWidget);

      // Switch to the video tab
      await tester.tap(find.byIcon(Icons.videocam_outlined));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The video file should be listed with its display name
      expect(find.text('test_video.mp4'), findsOneWidget);

      // Fallback videocam icon should be present (no thumbnail cached)
      // The tab icon and the fallback icon both use videocam_outlined
      expect(find.byIcon(Icons.videocam_outlined), findsAtLeastNWidgets(1));
    });

    testWidgets('video thumbnail shows Image.memory when cached data exists', (
      tester,
    ) async {
      // Insert a video record
      await VideoManifest.addRecord(
        VideoRecord(
          name: 'cached_video',
          hash: 'cached_hash',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 2048,
          duration: 3000,
        ),
      );

      // Write a cached thumbnail (256 bytes of valid-looking data)
      final thumbData = Uint8List(256);
      thumbData[0] = 0xFF;
      thumbData[1] = 0xD8;
      thumbData[2] = 0xFF;
      await VideoManifest.writeThumbnail('cached_hash', thumbData);

      // Verify thumbnail was stored
      final stored = await VideoManifest.readThumbnail('cached_hash');
      expect(stored, isNotNull);

      await tester.pumpWidget(_buildTestApp());

      // Open the picker
      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Switch to video tab
      await tester.tap(find.byIcon(Icons.videocam_outlined));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The video file should be listed with its display name
      expect(find.text('cached_video.mp4'), findsOneWidget);
    });

    testWidgets('video thumbnail shows fallback icon when no cached data', (
      tester,
    ) async {
      // Insert a video record WITHOUT thumbnail
      await VideoManifest.addRecord(
        VideoRecord(
          name: 'no_thumb_video',
          hash: 'no_thumb_hash',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 512,
          duration: 1000,
        ),
      );

      await tester.pumpWidget(_buildTestApp());

      // Open the picker
      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Switch to video tab
      await tester.tap(find.byIcon(Icons.videocam_outlined));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The video file should be listed
      expect(find.text('no_thumb_video.mp4'), findsOneWidget);

      // Fallback videocam icon should be shown
      expect(find.byIcon(Icons.videocam_outlined), findsAtLeastNWidgets(1));
    });
  });
}
