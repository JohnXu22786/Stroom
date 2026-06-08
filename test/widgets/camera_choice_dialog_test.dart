import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/camera_choice_dialog.dart';

void main() {
  group('CameraChoiceResult', () {
    test('can be created with default values', () {
      const result = CameraChoiceResult(choice: CameraChoice.app);
      expect(result.choice, CameraChoice.app);
      expect(result.folder, '');
    });

    test('can be created with custom folder', () {
      const result = CameraChoiceResult(
        choice: CameraChoice.system,
        folder: 'my_folder',
      );
      expect(result.choice, CameraChoice.system);
      expect(result.folder, 'my_folder');
    });

    test('equality works', () {
      const a = CameraChoiceResult(choice: CameraChoice.app, folder: 'f1');
      const b = CameraChoiceResult(choice: CameraChoice.app, folder: 'f1');
      const c = CameraChoiceResult(choice: CameraChoice.system, folder: 'f1');
      expect(a, b);
      expect(a == c, false);
    });
  });

  group('showCameraChoiceDialog', () {
    testWidgets('renders both camera options and folder section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showCameraChoiceDialog(context),
                  child: Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show title
      expect(find.text('选择拍照方式'), findsOneWidget);

      // Should show both camera choices
      expect(find.text('应用相机'), findsOneWidget);
      expect(find.text('系统相机'), findsOneWidget);

      // Should show folder section
      expect(find.text('添加至文件夹'), findsOneWidget);

      // App camera card exists
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('default folder is root (empty)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showCameraChoiceDialog(context),
                  child: Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Default display should show "根目录" (root)
      expect(find.textContaining('根目录'), findsOneWidget);
    });
  });
}
