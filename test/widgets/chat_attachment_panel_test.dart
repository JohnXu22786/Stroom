import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/chat_attachment_panel.dart';

/// Helper to open the panel in a test environment.
Future<void> openPanel(WidgetTester tester) async {
  await tester.tap(find.text('Open Panel'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300)); // For animation

  // DraggableScrollableSheet inside modal bottom sheet needs pump
  await tester.pump(const Duration(milliseconds: 100));
}

/// Builds the test app and opens the file-only panel.
Future<void> showPanelForTest(
  WidgetTester tester, {
  void Function()? onPickFromCamera,
  void Function()? onPickFromGallery,
  void Function()? onPickFromFilePicker,
  void Function()? onPickFromAppFiles,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showChatAttachmentPanel(
                  context: context,
                  onPickFromCamera: onPickFromCamera ?? () {},
                  onPickFromGallery: onPickFromGallery ?? () {},
                  onPickFromFilePicker: onPickFromFilePicker ?? () {},
                  onPickFromAppFiles: onPickFromAppFiles ?? () {},
                );
              },
              child: const Text('Open Panel'),
            );
          },
        ),
      ),
    ),
  );

  await openPanel(tester);
}

void main() {
  group('ChatAttachmentPanel widget tests (file-only panel)', () {
    testWidgets('panel opens with file transfer title', (tester) async {
      await showPanelForTest(tester);

      // The panel should show a file-related title
      expect(find.text('传文件'), findsOneWidget);
    });

    testWidgets('panel shows camera, gallery, file, and app file buttons',
        (tester) async {
      await showPanelForTest(tester);

      // File action buttons should be visible
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('相册'), findsOneWidget);
      expect(find.text('文件'), findsOneWidget);
      expect(find.text('应用内文件'), findsOneWidget);
    });

    testWidgets('camera callback fires when camera button is tapped',
        (tester) async {
      bool cameraCalled = false;
      await showPanelForTest(
        tester,
        onPickFromCamera: () => cameraCalled = true,
      );

      await tester.tap(find.text('拍照'));
      await tester.pump();
      expect(cameraCalled, true);
    });

    testWidgets('gallery callback fires when gallery button is tapped',
        (tester) async {
      bool galleryCalled = false;
      await showPanelForTest(
        tester,
        onPickFromGallery: () => galleryCalled = true,
      );

      await tester.tap(find.text('相册'));
      await tester.pump();
      expect(galleryCalled, true);
    });

    testWidgets('file picker callback fires when file button is tapped',
        (tester) async {
      bool filePickerCalled = false;
      await showPanelForTest(
        tester,
        onPickFromFilePicker: () => filePickerCalled = true,
      );

      await tester.tap(find.text('文件'));
      await tester.pump();
      expect(filePickerCalled, true);
    });

    testWidgets('app files callback fires when app internal file button is tapped',
        (tester) async {
      bool appFilesCalled = false;
      await showPanelForTest(
        tester,
        onPickFromAppFiles: () => appFilesCalled = true,
      );

      await tester.tap(find.text('应用内文件'));
      await tester.pump();
      expect(appFilesCalled, true);
    });

    testWidgets('panel does not show model, tools, or reasoning sections',
        (tester) async {
      await showPanelForTest(tester);

      // These settings sections should NOT exist in the file-only panel
      expect(find.text('模型'), findsNothing);
      expect(find.text('工具'), findsNothing);
      expect(find.text('推理设置'), findsNothing);
    });

    testWidgets('panel dismisses when tapping overlay background',
        (tester) async {
      await showPanelForTest(tester);

      // Panel should show its title
      expect(find.text('传文件'), findsOneWidget);

      // Tap on the barrier (background overlay)
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Panel should dismiss
      expect(find.text('传文件'), findsNothing);
    });
  });
}
