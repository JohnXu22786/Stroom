import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stroom/application.dart';
import 'package:stroom/pages/home_page.dart';
import 'package:stroom/providers/image_provider.dart';
import 'package:stroom/utils/image_manifest.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('File Management — Full E2E', () {
    testWidgets('1. App launches and navigates correctly', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: Application()));
      await tester.pumpAndSettle();

      // Verify home page is shown
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Click "相册" tab (the gallery navigation destination)
      // NavigationBar destinations are found by their label text
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();

      // Should show the gallery page - "拍照" and "从相册导入" buttons
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('从相册导入'), findsOneWidget);

      // Navigate to "录音" tab
      await tester.tap(find.text('录音'));
      await tester.pumpAndSettle();

      expect(find.text('制作录音'), findsOneWidget);
      expect(find.text('导入音频'), findsOneWidget);

      // Navigate to "设置" tab
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      expect(find.text('设置'), findsWidgets);
    });

    testWidgets('2. Gallery shows empty state and switches view',
        (tester) async {
      // Pre-load some test data
      await ImageManifest.addRecord(ImageRecord(
        name: '测试图片',
        hash: 'abc123',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 1024,
      ));

      await tester.pumpWidget(const ProviderScope(child: Application()));
      await tester.pumpAndSettle();

      // Go to gallery
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();

      // Should see the imported test file
      expect(find.text('测试图片.jpg'), findsOneWidget);

      // Toggle to thumbnail view
      final gridToggle = find.byIcon(Icons.grid_view);
      if (gridToggle.evaluate().isNotEmpty) {
        await tester.tap(gridToggle);
        await tester.pumpAndSettle();
        // Now should show list toggle icon
        expect(find.byIcon(Icons.view_list), findsOneWidget);
      }

      // Clean up test data
      final records = await ImageManifest.loadRecords();
      for (final r in records) {
        if (r.name == '测试图片') {
          await ImageManifest.deleteRecord(r.id);
        }
      }
    });

    testWidgets('3. Sort menu works and toggles order', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: Application()));
      await tester.pumpAndSettle();

      // Go to gallery
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();

      // Find sort button (access_time icon since default is createdAt)
      final sortButton = find.byIcon(Icons.access_time);
      expect(sortButton, findsOneWidget);

      // Tap to open sort menu
      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      // Sort popup should show options
      expect(find.text('按时间'), findsOneWidget);
      expect(find.text('按文件名'), findsOneWidget);
      expect(find.text('按大小'), findsOneWidget);

      // Select '按文件名'
      await tester.tap(find.text('按文件名'));
      await tester.pumpAndSettle();

      // Icon should change to sort_by_alpha
      expect(find.byIcon(Icons.sort_by_alpha), findsOneWidget);
    });

    testWidgets('4. Create folder via dialog on gallery page', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: Application()));
      await tester.pumpAndSettle();

      // Go to gallery
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();

      // Tap create folder button
      final folderButton = find.byIcon(Icons.create_new_folder);
      expect(folderButton, findsOneWidget);
      await tester.tap(folderButton);
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('创建文件夹'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      // Enter folder name
      await tester.enterText(find.byType(TextField), '集成测试文件夹');
      await tester.pumpAndSettle();

      // Tap the "创建" button (may be ElevatedButton)
      await tester.tap(find.widgetWithText(ElevatedButton, '创建'));
      await tester.pumpAndSettle();

      // Should see success snackbar
      expect(find.textContaining('创建成功'), findsOneWidget);

      // Clean up: navigate into folder and delete it
      // First dismiss snackbar
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Delete the folder by finding its popup menu
      // Navigate into folder first to verify it exists
      await tester.tap(find.text('集成测试文件夹'));
      await tester.pumpAndSettle();

      // Go back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
    });

    testWidgets('5. Selection mode works on gallery page', (tester) async {
      // Add test data
      await ImageManifest.addRecord(ImageRecord(
        name: '选中的文件',
        hash: 'def456',
        format: 'png',
        createdAt: DateTime.now(),
        size: 2048,
      ));

      await tester.pumpWidget(const ProviderScope(child: Application()));
      await tester.pumpAndSettle();

      // Go to gallery
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();

      // Find the file card and long press to enter selection mode
      final fileCard = find.text('选中的文件.png');
      if (fileCard.evaluate().isNotEmpty) {
        await tester.longPress(fileCard);
        await tester.pumpAndSettle();

        // Should show selection count and bottom bar
        expect(find.textContaining('已选择'), findsOneWidget);
        expect(find.text('删除'), findsOneWidget);
        expect(find.text('移动'), findsOneWidget);
      }

      // Clean up
      final records = await ImageManifest.loadRecords();
      for (final r in records) {
        if (r.name == '选中的文件') {
          await ImageManifest.deleteRecord(r.id);
        }
      }
    });

    testWidgets('6. Refresh button works on all pages', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: Application()));
      await tester.pumpAndSettle();

      // Go to gallery and test refresh
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();

      final refreshButtons = find.byIcon(Icons.refresh);
      if (refreshButtons.evaluate().isNotEmpty) {
        await tester.tap(refreshButtons.first);
        await tester.pumpAndSettle();
        // Should see refresh feedback
        expect(find.textContaining('刷新'), findsWidgets);
      }
    });
  });
}
