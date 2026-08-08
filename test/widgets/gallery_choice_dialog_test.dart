import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/gallery_choice_dialog.dart';

void main() {
  group('showGalleryChoiceDialog', () {
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
