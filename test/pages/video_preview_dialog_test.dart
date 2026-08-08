import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/chat/dialogs/video_preview_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPreviewDialog', () {
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
  });
}
