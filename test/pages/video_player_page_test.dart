import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/video_gallery_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPlayerPage', () {
    test('constructor creates non-null instance', () {
      const page = VideoPlayerPage(
        filePath: '/path/to/video.mp4',
        displayName: 'video.mp4',
      );
      expect(page, isNotNull);
      expect(page.filePath, equals('/path/to/video.mp4'));
      expect(page.displayName, equals('video.mp4'));
    });

    testWidgets('renders loading indicator initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerPage(
            filePath: '/nonexistent/video.mp4',
            displayName: 'test_video.mp4',
          ),
        ),
      );

      // Should show loading spinner initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

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

    testWidgets('displays displayName in AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerPage(
            filePath: '/nonexistent/video.mp4',
            displayName: 'my_video.mp4',
          ),
        ),
      );

      // AppBar should show the display name
      expect(find.text('my_video.mp4'), findsOneWidget);
    });

    testWidgets('has Scaffold with dark background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerPage(
            filePath: '/nonexistent/video.mp4',
            displayName: 'test.mp4',
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.black));
    });

    testWidgets('dispose runs without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerPage(
            filePath: '/nonexistent/video.mp4',
            displayName: 'test.mp4',
          ),
        ),
      );

      // Removing the widget should trigger dispose without errors
      await tester.pumpWidget(
        const MaterialApp(home: Text('dummy')),
      );
      await tester.pump();
      // If no errors, test passes
    });
  });
}
