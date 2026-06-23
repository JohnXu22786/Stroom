import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/video_gallery_page.dart';

Widget _buildTestApp() {
  return const ProviderScope(child: MaterialApp(home: VideoGalleryPage()));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('VideoGalleryPage - Record button', () {
    testWidgets('renders 录制视频 button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // The "录制视频" button should be rendered
      expect(find.text('录制视频'), findsOneWidget);
    });

    testWidgets('renders 从相册导入 button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.text('从相册导入'), findsOneWidget);
    });
  });
}
