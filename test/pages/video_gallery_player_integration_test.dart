import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/pages/video_gallery_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VideoGalleryPage player integration', () {
    testWidgets('renders gallery with 录制 and 导入 buttons', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VideoGalleryPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('录制'), findsOneWidget);
      expect(find.text('导入'), findsOneWidget);
    });

    test('VideoGalleryPage constructor creates non-null instance', () {
      const page = VideoGalleryPage();
      expect(page, isNotNull);
    });
  });
}
