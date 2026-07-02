import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/widgets/draggable_floating_panel.dart';

void main() {
  group('DraggableFloatingPanel', () {
    testWidgets('renders with empty state when no URLs provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const [],
              onConfirmCapture: (_) {},
            ),
          ),
        ),
      );

      // Should show empty state
      expect(find.textContaining('暂无'), findsOneWidget);
      expect(find.textContaining('等待'), findsOneWidget);
    });

    testWidgets('displays detected URLs in a list', (tester) async {
      final urls = [
        'https://cdn.example.com/video1.mp4',
        'https://cdn.example.com/video2.m3u8',
        'https://cdn.example.com/audio.mp3',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: urls,
              onConfirmCapture: (_) {},
            ),
          ),
        ),
      );

      // Should show all URLs
      for (final url in urls) {
        expect(find.textContaining(url), findsOneWidget);
      }
    });

    testWidgets('calls onConfirmCapture when capture button tapped',
        (tester) async {
      String? capturedUrl;
      final urls = ['https://cdn.example.com/video.mp4'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: urls,
              onConfirmCapture: (url) {
                capturedUrl = url;
              },
            ),
          ),
        ),
      );

      // First, find and tap the first item to select it
      await tester.tap(find.textContaining('video.mp4'));
      await tester.pumpAndSettle();

      // Then tap the confirm button
      await tester.tap(find.text('确认捕获'));
      await tester.pumpAndSettle();

      expect(capturedUrl, equals('https://cdn.example.com/video.mp4'));
    });

    testWidgets('supports selecting different URL then confirming',
        (tester) async {
      String? capturedUrl;
      final urls = [
        'https://cdn.example.com/video1.mp4',
        'https://cdn.example.com/video2.mp4',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: urls,
              onConfirmCapture: (url) {
                capturedUrl = url;
              },
            ),
          ),
        ),
      );

      // Select the second URL
      await tester.tap(find.textContaining('video2.mp4'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认捕获'));
      await tester.pumpAndSettle();

      expect(capturedUrl, equals('https://cdn.example.com/video2.mp4'));
    });

    testWidgets('does not show confirm button or call callback on empty list',
        (tester) async {
      bool captureCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const [],
              onConfirmCapture: (_) {
                captureCalled = true;
              },
            ),
          ),
        ),
      );

      // The confirm button should NOT exist when list is empty
      expect(find.text('确认捕获'), findsNothing);
      expect(captureCalled, isFalse);
    });

    testWidgets('shows media type icon for each URL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const ['https://cdn.example.com/video.mp4'],
              onConfirmCapture: (_) {},
            ),
          ),
        ),
      );

      // Should show a video icon
      expect(find.byIcon(Icons.videocam), findsOneWidget);
    });

    testWidgets('shows audio icon for audio URLs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const ['https://cdn.example.com/audio.mp3'],
              onConfirmCapture: (_) {},
            ),
          ),
        ),
      );

      // Should show an audio icon
      expect(find.byIcon(Icons.audio_file), findsOneWidget);
    });
  });
}
