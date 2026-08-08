import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/video_gallery_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPlayerPage', () {
    testWidgets('renders error state when player initialization fails',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerPage(
            filePath: '/nonexistent/video.mp4',
            displayName: 'test_video.mp4',
          ),
        ),
      );

      // Wait for async init to complete (will fail since file doesn't exist)
      await tester.pump(const Duration(seconds: 1));

      // Should show error UI
      expect(find.text('视频加载失败'), findsOneWidget);
    });
  });
}
