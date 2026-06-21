import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/app_media_picker_dialog.dart';

// ============================================================================
// Helper: A simple test record model
// ============================================================================

class _TestRecord {
  final String id;
  final String name;
  final String format;
  final int size;
  final String folder;

  const _TestRecord({
    required this.id,
    required this.name,
    this.format = 'wav',
    this.size = 1024,
    this.folder = '',
  });
}

// ============================================================================
// Helper: build test app wrapping the picker trigger
// ============================================================================

Widget _buildTestApp(Widget trigger) {
  return MaterialApp(
    home: Scaffold(body: trigger),
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
  );
}

// ============================================================================
// Helper: create a media picker config for testing
// ============================================================================

MediaPickerConfig<_TestRecord> _createTestConfig({
  bool multiSelect = false,
  List<_TestRecord> records = const [],
  Set<String> folders = const {},
  Uint8List? fileData,
}) {
  return MediaPickerConfig<_TestRecord>(
    title: '测试选择器',
    emptyIcon: Icons.folder_outlined,
    emptyText: '暂无文件',
    fileIcon: Icons.insert_drive_file,
    fileIconColor: Colors.blue,
    multiSelect: multiSelect,
    loadRecords: () async => records,
    loadFolders: () async => folders,
    readFile: (record) async => fileData ?? Uint8List.fromList([1, 2, 3]),
    displayName: (record) => record.name,
    subtitleBuilder: (record) => Text(
      '${record.format.toUpperCase()}  ${_formatSize(record.size)}',
      style: const TextStyle(fontSize: 12),
    ),
  );
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// ============================================================================
// Tests
// ============================================================================

void main() {
  group('UnifiedMediaPickerDialog', () {
    testWidgets('shows title and close button', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () =>
                    showMediaPickerDialog(context, _createTestConfig()),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show the configured title
      expect(find.text('测试选择器'), findsOneWidget);
      // Should have a close button
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows loading state momentarily before data resolves',
        (tester) async {
      // Use a delayed future to keep loading visible
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showMediaPickerDialog(
              context,
              MediaPickerConfig<_TestRecord>(
                title: '测试选择器',
                emptyIcon: Icons.folder_outlined,
                emptyText: '暂无文件',
                fileIcon: Icons.insert_drive_file,
                loadRecords: () => Future.delayed(
                    const Duration(seconds: 5), () => <_TestRecord>[]),
                loadFolders: () async => <String>{},
                readFile: (record) async => Uint8List.fromList([1, 2, 3]),
                displayName: (record) => record.name,
                subtitleBuilder: (record) => const Text(''),
              ),
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Loading indicator should be visible before data resolves
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Advance past the delayed future to avoid pending timer
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows empty state when no records', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showMediaPickerDialog(
                  context,
                  _createTestConfig(records: const []),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show empty state text
      expect(find.text('暂无文件'), findsOneWidget);
    });

    testWidgets('shows records when data is loaded', (tester) async {
      final records = [
        const _TestRecord(id: '1', name: '测试文件1', format: 'wav', size: 2048),
        const _TestRecord(id: '2', name: '测试文件2', format: 'mp3', size: 4096),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showMediaPickerDialog(
                  context,
                  _createTestConfig(records: records),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show file names
      expect(find.text('测试文件1'), findsOneWidget);
      expect(find.text('测试文件2'), findsOneWidget);
      // Should show format and size info
      expect(find.textContaining('WAV'), findsWidgets);
      expect(find.textContaining('MP3'), findsWidgets);
    });

    testWidgets('single-select: tapping item closes dialog and returns data', (
      tester,
    ) async {
      List<MapEntry<String, Uint8List>>? pickerResult;

      final records = [
        const _TestRecord(id: '1', name: '测试文件', format: 'wav', size: 1024),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  pickerResult = await showMediaPickerDialog(
                    context,
                    _createTestConfig(
                      records: records,
                      multiSelect: false,
                      fileData: Uint8List.fromList([10, 20, 30]),
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the file
      await tester.tap(find.text('测试文件'));
      await tester.pumpAndSettle();

      // Should return the selected file (key is the displayName, no extension)
      expect(pickerResult, isNotNull);
      expect(pickerResult!.length, equals(1));
      expect(pickerResult!.first.key, '测试文件');
      expect(pickerResult!.first.value, equals([10, 20, 30]));
    });

    testWidgets('single-select: dialog closes after item tap', (tester) async {
      final records = [
        const _TestRecord(id: '1', name: '测试文件', format: 'wav', size: 1024),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showMediaPickerDialog(
                  context,
                  _createTestConfig(records: records),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog is visible
      expect(find.text('测试选择器'), findsOneWidget);

      // Tap the file
      await tester.tap(find.text('测试文件'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('测试选择器'), findsNothing);
    });

    testWidgets('multi-select: shows checkboxes and preview bar', (
      tester,
    ) async {
      final records = [
        const _TestRecord(id: '1', name: '文件1', format: 'wav', size: 1024),
        const _TestRecord(id: '2', name: '文件2', format: 'mp3', size: 2048),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showMediaPickerDialog(
                  context,
                  _createTestConfig(records: records, multiSelect: true),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show checkboxes (multi-select mode)
      expect(find.byType(Checkbox), findsNWidgets(2));

      // Tap first file to select
      await tester.tap(find.text('文件1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Preview bar should appear
      expect(find.byKey(const Key('media_picker_preview_bar')), findsOneWidget);

      // Confirm button should show count
      expect(find.textContaining('确定'), findsWidgets);
    });

    testWidgets('multi-select: confirm button returns selected items', (
      tester,
    ) async {
      List<MapEntry<String, Uint8List>>? pickerResult;

      final records = [
        const _TestRecord(id: '1', name: '文件1', format: 'wav', size: 1024),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  pickerResult = await showMediaPickerDialog(
                    context,
                    _createTestConfig(records: records, multiSelect: true),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Select the file
      await tester.tap(find.text('文件1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap confirm
      await tester.tap(find.byKey(const Key('media_picker_confirm_btn')));
      await tester.pumpAndSettle();

      // Should return the selected file (key is the displayName, no extension)
      expect(pickerResult, isNotNull);
      expect(pickerResult!.length, equals(1));
      expect(pickerResult!.first.key, '文件1');
    });

    testWidgets('multi-select: clear button removes all selections', (
      tester,
    ) async {
      final records = [
        const _TestRecord(id: '1', name: '文件1', format: 'wav', size: 1024),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showMediaPickerDialog(
                  context,
                  _createTestConfig(records: records, multiSelect: true),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Select the file
      await tester.tap(find.text('文件1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Preview bar should appear
      expect(find.byKey(const Key('media_picker_preview_bar')), findsOneWidget);

      // Tap clear
      await tester.tap(find.byKey(const Key('media_picker_clear_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Preview bar should be gone
      expect(find.byKey(const Key('media_picker_preview_bar')), findsNothing);
    });

    testWidgets('folder navigation: shows folders and navigates into them', (
      tester,
    ) async {
      final records = [
        const _TestRecord(
          id: '1',
          name: '内部文件',
          format: 'wav',
          size: 512,
          folder: '子文件夹',
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showMediaPickerDialog(
                  context,
                  _createTestConfig(records: records, folders: {'子文件夹'}),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show folder (not the file since it's in a folder)
      expect(find.text('子文件夹'), findsOneWidget);
      expect(find.text('内部文件'), findsNothing);

      // Navigate into folder
      await tester.tap(find.text('子文件夹'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show the file inside the folder
      expect(find.text('内部文件'), findsOneWidget);
    });

    testWidgets('folder navigation: back button returns to parent', (
      tester,
    ) async {
      final records = [
        const _TestRecord(
          id: '1',
          name: '内部文件',
          format: 'wav',
          size: 512,
          folder: '子文件夹',
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showMediaPickerDialog(
                  context,
                  _createTestConfig(records: records, folders: {'子文件夹'}),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Navigate into folder
      await tester.tap(find.text('子文件夹'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should see back button
      expect(find.byKey(const Key('media_picker_back_item')), findsOneWidget);

      // Tap back
      await tester.tap(find.byKey(const Key('media_picker_back_item')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should be back at root
      expect(find.text('子文件夹'), findsOneWidget);
      expect(find.text('内部文件'), findsNothing);
    });

    testWidgets('close button dismisses dialog without result', (tester) async {
      List<MapEntry<String, Uint8List>>? pickerResult;

      final records = [
        const _TestRecord(id: '1', name: '测试文件', format: 'wav', size: 1024),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  pickerResult = await showMediaPickerDialog(
                    context,
                    _createTestConfig(records: records),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Close the dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Should return null
      expect(pickerResult, isNull);
    });

    testWidgets('handles file read failure with snackbar (single-select)', (
      tester,
    ) async {
      final records = [
        const _TestRecord(id: '1', name: '缺失文件', format: 'wav', size: 1024),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showMediaPickerDialog(
                  context,
                  MediaPickerConfig<_TestRecord>(
                    title: '测试选择器',
                    emptyIcon: Icons.folder_outlined,
                    emptyText: '暂无文件',
                    fileIcon: Icons.insert_drive_file,
                    loadRecords: () async => records,
                    loadFolders: () async => <String>{},
                    readFile: (record) async => null, // File read fails
                    displayName: (record) => record.name,
                    subtitleBuilder: (record) => const Text(''),
                  ),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Try to select the file
      await tester.tap(find.text('缺失文件'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show error snackbar (may appear in both SnackBar and overlay)
      expect(find.text('无法读取文件'), findsAtLeastNWidgets(1));
      // Dialog should remain open
      expect(find.text('测试选择器'), findsOneWidget);
    });

    testWidgets('handles file read failure with snackbar (multi-select)', (
      tester,
    ) async {
      final records = [
        const _TestRecord(id: '1', name: '缺失文件', format: 'wav', size: 1024),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showMediaPickerDialog(
                  context,
                  MediaPickerConfig<_TestRecord>(
                    title: '测试选择器',
                    emptyIcon: Icons.folder_outlined,
                    emptyText: '暂无文件',
                    fileIcon: Icons.insert_drive_file,
                    multiSelect: true,
                    loadRecords: () async => records,
                    loadFolders: () async => <String>{},
                    readFile: (record) async => null, // File read fails
                    displayName: (record) => record.name,
                    subtitleBuilder: (record) => const Text(''),
                  ),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Try to select the file
      await tester.tap(find.text('缺失文件'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show error snackbar (may appear in both SnackBar and overlay)
      expect(find.text('无法读取文件'), findsAtLeastNWidgets(1));
      // Dialog should remain open
      expect(find.text('测试选择器'), findsOneWidget);
    });

    testWidgets('subtitle builder renders correct media-specific info', (
      tester,
    ) async {
      final records = [
        const _TestRecord(id: '1', name: '音频文件', format: 'wav', size: 2048),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showMediaPickerDialog(
                  context,
                  _createTestConfig(records: records),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show subtitle info
      expect(find.textContaining('WAV'), findsOneWidget);
      expect(find.textContaining('2.0 KB'), findsOneWidget);
    });
  });
}
