import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/chat/dialogs/video_preview_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPreviewDialog', () {
    testWidgets('renders loading indicator initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const VideoPreviewDialog(
                    filePath: '/nonexistent/video.mp4',
                    fileName: 'test_video.mp4',
                  ),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show'));
      await tester.pump();

      // Dialog should be visible with loading indicator
      expect(find.byType(VideoPreviewDialog), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows fileName in dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const VideoPreviewDialog(
                    filePath: '/nonexistent/video.mp4',
                    fileName: 'my_video_file.mp4',
                  ),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();

      // File name should be displayed
      expect(find.text('my_video_file.mp4'), findsOneWidget);
    });

    testWidgets('close button is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const VideoPreviewDialog(
                    filePath: '/nonexistent/video.mp4',
                    fileName: 'test.mp4',
                  ),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();

      // Close button should be present
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('close button dismisses the dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const VideoPreviewDialog(
                    filePath: '/nonexistent/video.mp4',
                    fileName: 'test.mp4',
                  ),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(VideoPreviewDialog), findsNothing);
    });

    test('constructor creates non-null instance', () {
      const dialog = VideoPreviewDialog(
        filePath: '/path/to/video.mp4',
        fileName: 'video.mp4',
      );
      expect(dialog, isNotNull);
      expect(dialog.filePath, equals('/path/to/video.mp4'));
      expect(dialog.fileName, equals('video.mp4'));
    });
  });
}
