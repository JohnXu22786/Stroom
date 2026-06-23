import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/ocr_page.dart';

Widget _buildTestApp() {
  return const ProviderScope(child: MaterialApp(home: OcrPage()));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OcrPage - Camera button', () {
    testWidgets('renders 拍照识别 button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // The "拍照识别" button should be rendered
      expect(find.text('拍照识别'), findsOneWidget);
    });

    testWidgets('renders 相册选择 button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.text('相册选择'), findsOneWidget);
    });
  });
}
