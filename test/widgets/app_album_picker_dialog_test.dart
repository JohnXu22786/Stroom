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
      // 异步加载需要先 pump 让 dialog 显示
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show the title
      expect(find.text('应用内相册'), findsOneWidget);

      // Should have a close button
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

      // Close button should close the dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be gone
      expect(find.text('应用内相册'), findsNothing);
    });
  });
}
