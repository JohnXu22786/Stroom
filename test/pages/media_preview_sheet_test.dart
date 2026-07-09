import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/unified_task_list/media_preview_sheet.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaPreviewSheet', () {
    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaPreviewSheet(
              resource: MediaResource(
                url: 'https://example.com/video.mp4',
                name: 'test_video',
                ext: 'mp4',
              ),
              taskTitle: 'Test Task',
            ),
          ),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows task title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaPreviewSheet(
              resource: MediaResource(
                url: 'https://example.com/video.mp4',
                name: 'test_video',
                ext: 'mp4',
              ),
              taskTitle: 'My Preview Task',
            ),
          ),
        ),
      );

      expect(find.text('My Preview Task'), findsOneWidget);
    });

    testWidgets('shows unsupported format error for unknown extensions',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaPreviewSheet(
              resource: MediaResource(
                url: 'https://example.com/file.xyz',
                name: 'file',
                ext: 'xyz',
              ),
              taskTitle: 'Test',
            ),
          ),
        ),
      );

      // Wait for async init
      await tester.pump(const Duration(seconds: 1));

      // Should show error about unsupported format
      expect(find.text('不支持此格式预览'), findsOneWidget);
    });
  });
}
