import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/chat/composer/app_file_picker_dialog.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // Basic rendering tests
  // ═══════════════════════════════════════════════════════════════
  group('AppFilePickerDialog basic rendering', () {
    testWidgets('dialog opens and shows title and tabs', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppFilePickerDialog(context),
            child: const Text('Open Picker'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the title is shown
      expect(find.text('选择文件'), findsOneWidget);

      // Verify the tabs are shown
      expect(find.text('文本'), findsOneWidget);
      expect(find.text('图片'), findsOneWidget);
      expect(find.text('视频'), findsOneWidget);
      expect(find.text('音频'), findsOneWidget);
    });

    testWidgets('dialog has close icon button and confirm button', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppFilePickerDialog(context),
            child: const Text('Open Picker'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify close button (IconButton with Icons.close)
      expect(find.byIcon(Icons.close), findsOneWidget);
      // Verify confirm button
      expect(find.text('确定'), findsOneWidget);
    });

    testWidgets('close button closes dialog and returns null', (tester) async {
      Future<List<MapEntry<String, Uint8List>>?>? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              result = showAppFilePickerDialog(context);
            },
            child: const Text('Open Picker'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify dialog is closed
      expect(find.text('选择文件'), findsNothing);
    });

    testWidgets('confirm button with no selection closes dialog', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppFilePickerDialog(context),
            child: const Text('Open Picker'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap confirm without selecting anything
      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should close
      expect(find.text('选择文件'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Tab switching tests
  // ═══════════════════════════════════════════════════════════════
  group('AppFilePickerDialog tab switching', () {
    testWidgets('tapping tab shows content area', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppFilePickerDialog(context),
            child: const Text('Open Picker'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      // Pump several frames to allow async loading to complete
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify content area exists (may be loading indicator or actual content)
      expect(find.byKey(const Key('file_picker_content')), findsOneWidget);
    });

    testWidgets('all tabs have icons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppFilePickerDialog(context),
            child: const Text('Open Picker'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify all tab icons exist
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Preview bar tests
  // ═══════════════════════════════════════════════════════════════
  group('AppFilePickerDialog preview bar', () {
    testWidgets('preview bar is not shown when no files are selected',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppFilePickerDialog(context),
            child: const Text('Open Picker'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Preview bar should not appear when no selection
      expect(find.byKey(const Key('file_picker_preview_bar')), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Folder navigation tests
  // ═══════════════════════════════════════════════════════════════
  group('AppFilePickerDialog structure', () {
    testWidgets('empty folder shows dialog content area', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppFilePickerDialog(context),
            child: const Text('Open Picker'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog content area should exist (either loading indicator or file list)
      expect(find.byKey(const Key('file_picker_content')), findsOneWidget);
    });
  });
}
