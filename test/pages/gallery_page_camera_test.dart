import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/gallery_page.dart';

/// Builds a test app wrapping GalleryPage with required providers.
Widget _buildTestApp() {
  return const ProviderScope(child: MaterialApp(home: GalleryPage()));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GalleryPage - Camera and import buttons', () {
    testWidgets('renders 拍照 button with camera icon and 从相册导入 button',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Camera button should be present
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      expect(find.text('拍照'), findsOneWidget);

      // Import from gallery button should also be present
      expect(find.text('从相册导入'), findsOneWidget);
    });
  });
}
