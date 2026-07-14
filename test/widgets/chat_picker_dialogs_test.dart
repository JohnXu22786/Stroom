// Merged from:
//   - app_album_picker_dialog_test.dart
// Note: app_media_picker_dialog_test.dart is kept as a standalone file
// (it is too large to safely merge into a thematic file).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/chat_album_picker_dialog.dart';

Widget _buildTestApp(Widget body) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: body),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  group('AppAlbumPickerDialog', () {
    testWidgets('shows title and close button', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showAppAlbumPickerDialog(context),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('应用内相册'), findsOneWidget);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('dialog can be closed with close button', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showAppAlbumPickerDialog(context),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('应用内相册'), findsNothing);
    });
  });
}
