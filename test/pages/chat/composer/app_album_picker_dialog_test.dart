import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/chat_album_picker_dialog.dart';

void main() {
  group('AppAlbumPickerDialog tests', () {
    testWidgets('dialog opens and shows title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppAlbumPickerDialog(context);
                  },
                  child: const Text('Open Album'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Album'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // Should show the picker title
      expect(find.text('应用内相册'), findsOneWidget);
    });

    testWidgets('dialog has close/dismiss button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppAlbumPickerDialog(context);
                  },
                  child: const Text('Open Album'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Album'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // Find close button
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap close to dismiss
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('应用内相册'), findsNothing);
    });

    testWidgets('dialog dismisses on background tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppAlbumPickerDialog(context);
                  },
                  child: const Text('Open Album'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Album'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('应用内相册'), findsOneWidget);

      // Tap on background barrier
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('应用内相册'), findsNothing);
    });
  });
}
