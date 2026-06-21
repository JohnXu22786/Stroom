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
      expect(result.editAfterCapture, false);
    });

    test('can be created with custom folder', () {
      const result = CameraChoiceResult(
        choice: CameraChoice.system,
        folder: 'my_folder',
      );
      expect(result.choice, CameraChoice.system);
      expect(result.folder, 'my_folder');
      expect(result.editAfterCapture, false);
    });

    test('can be created with editAfterCapture true', () {
      const result = CameraChoiceResult(
        choice: CameraChoice.app,
        folder: 'f1',
        editAfterCapture: true,
      );
      expect(result.choice, CameraChoice.app);
      expect(result.folder, 'f1');
      expect(result.editAfterCapture, true);
    });

    test('equality works', () {
      const a = CameraChoiceResult(choice: CameraChoice.app, folder: 'f1');
      const b = CameraChoiceResult(choice: CameraChoice.app, folder: 'f1');
      const c = CameraChoiceResult(choice: CameraChoice.system, folder: 'f1');
      expect(a, b);
      expect(a == c, false);
    });

    test('equality respects editAfterCapture', () {
      const a = CameraChoiceResult(
        choice: CameraChoice.app,
        folder: 'f1',
        editAfterCapture: true,
      );
      const b = CameraChoiceResult(
        choice: CameraChoice.app,
        folder: 'f1',
        editAfterCapture: false,
      );
      expect(a == b, false);
    });
  });

  group('showCameraChoiceDialog', () {
    testWidgets('renders both camera options, folder section, and edit toggle',
        (tester) async {
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

      // Should show edit after capture toggle
      expect(find.text('拍完编辑'), findsOneWidget);

      // Should show the switch widget
      expect(find.byType(Switch), findsOneWidget);

      // App camera card exists
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('showFolderSection:false hides folder and edit toggle',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showCameraChoiceDialog(
                    context,
                    showFolderSection: false,
                  ),
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

      // Should show title and camera choices
      expect(find.text('选择拍照方式'), findsOneWidget);
      expect(find.text('应用相机'), findsOneWidget);
      expect(find.text('系统相机'), findsOneWidget);

      // Should NOT show folder section
      expect(find.text('添加至文件夹'), findsNothing);
      // Should NOT show edit after capture toggle
      expect(find.text('拍完编辑'), findsNothing);
      // Should NOT show the switch widget
      expect(find.byType(Switch), findsNothing);
      // Should NOT show folder icon
      expect(find.byIcon(Icons.folder_outlined), findsNothing);
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

    testWidgets('selecting app camera returns result with correct fields',
        (tester) async {
      CameraChoiceResult? result;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showCameraChoiceDialog(context).then((r) => result = r);
                  },
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

      // Select app camera
      await tester.tap(find.text('应用相机'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isNotNull);
      expect(result!.choice, CameraChoice.app);
      expect(result!.editAfterCapture, false);

      // Open again and select system camera
      result = null;
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('系统相机'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isNotNull);
      expect(result!.choice, CameraChoice.system);
    });

    testWidgets(
        'selecting app camera with showFolderSection:false returns result',
        (tester) async {
      CameraChoiceResult? result;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showCameraChoiceDialog(
                      context,
                      showFolderSection: false,
                    ).then((r) => result = r);
                  },
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

      // Select app camera
      await tester.tap(find.text('应用相机'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isNotNull);
      expect(result!.choice, CameraChoice.app);
      // When showFolderSection is false, folder/editaftercapture are irrelevant
      // but the result should still have default values
    });
  });

  group('CameraChoiceDialog - unified colors (app=green, system=blue)', () {
    testWidgets('app camera card uses green color', (tester) async {
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

      // The app camera icon container should use green color
      // Find the Icon widget with camera_alt and check its parent container's color
      final iconFinder = find.byIcon(Icons.camera_alt);
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, Colors.green);
    });

    testWidgets('system camera card uses blue color', (tester) async {
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

      // The system camera icon container should use blue color
      final iconFinder = find.byIcon(Icons.phone_android);
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, Colors.blue);
    });
  });
}
