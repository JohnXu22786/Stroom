import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/gallery_choice_dialog.dart';

void main() {
  group('GalleryChoiceResult', () {
    test('can be created with default values', () {
      const result = GalleryChoiceResult(choice: GalleryChoice.system);
      expect(result.choice, GalleryChoice.system);
    });

    test('can be created with app gallery choice', () {
      const result = GalleryChoiceResult(choice: GalleryChoice.app);
      expect(result.choice, GalleryChoice.app);
    });

    test('equality works', () {
      const a = GalleryChoiceResult(choice: GalleryChoice.system);
      const b = GalleryChoiceResult(choice: GalleryChoice.system);
      const c = GalleryChoiceResult(choice: GalleryChoice.app);
      expect(a, b);
      expect(a == c, false);
    });
  });

  group('showGalleryChoiceDialog', () {
    testWidgets('renders both gallery options with same UI style as camera dialog',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showGalleryChoiceDialog(context),
                child: Text('Open'),
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
      expect(find.text('选择图片来源'), findsOneWidget);

      // Should show both gallery choices (same style as camera dialog)
      expect(find.text('系统相册'), findsOneWidget);
      expect(find.text('应用相册'), findsOneWidget);

      // Should have the same UI pattern as camera choice dialog:
      // - Choice cards with icons
      expect(find.byIcon(Icons.photo_library), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);

      // Should NOT have camera-specific elements
      expect(find.text('选择拍照方式'), findsNothing);
      expect(find.text('应用相机'), findsNothing);
      expect(find.text('系统相机'), findsNothing);
    });

    testWidgets('has card-based layout matching camera dialog design',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showGalleryChoiceDialog(context),
                child: Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Both cards should be visible in a column layout (vertical list),
      // matching the file page style design pattern
      expect(find.byIcon(Icons.photo_library), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('selecting system gallery returns GalleryChoice.system',
        (tester) async {
      GalleryChoiceResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showGalleryChoiceDialog(context).then((r) => result = r);
                },
                child: Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Select system gallery
      await tester.tap(find.text('系统相册'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isNotNull);
      expect(result!.choice, GalleryChoice.system);
    });

    testWidgets('selecting app gallery returns GalleryChoice.app',
        (tester) async {
      GalleryChoiceResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showGalleryChoiceDialog(context).then((r) => result = r);
                },
                child: Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Select app gallery
      await tester.tap(find.text('应用相册'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isNotNull);
      expect(result!.choice, GalleryChoice.app);
    });
  });
}
