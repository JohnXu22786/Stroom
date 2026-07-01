import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/text_storage_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Widget _buildTestApp() {
  return MaterialApp(
    home: const TextCreatePage(),
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('TextCreatePage', () {
    testWidgets('renders with title and content fields', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.text('新建'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows format dropdown with txt and md options',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Should show a format selector with 'txt' as default
      expect(find.text('txt'), findsOneWidget);

      // Tap the dropdown to see options
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();

      // Should show both txt and md options
      expect(find.text('txt'), findsWidgets);
      expect(find.text('md'), findsOneWidget);
    });

    testWidgets('can switch to md format', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Open dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();

      // Select md
      await tester.tap(find.text('md').last);
      await tester.pump();

      // Should now show md as selected
      expect(find.text('md'), findsOneWidget);
    });

    testWidgets('saves with md format when selected', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter title
      await tester.enterText(
        find.widgetWithText(TextField, '标题').first,
        'test_md_file',
      );
      await tester.pump();

      // Enter content
      await tester.enterText(
        find.byType(TextField).last,
        '# Hello\n\nThis is **markdown**',
      );
      await tester.pump();

      // Switch to md format
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();
      await tester.tap(find.text('md').last);
      await tester.pump();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify the record was saved with md format
      final records = await TextManifest.loadRecords();
      expect(records.length, equals(1));
      expect(records[0].name, equals('test_md_file'));
      expect(records[0].format, equals('md'));
    });

    testWidgets('rejects empty title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Try to save without a title
      await tester.tap(find.text('保存'));
      await tester.pump();

      // Should show error snackbar
      expect(find.text('请输入标题'), findsOneWidget);
    });

    testWidgets('allows saving with empty content', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter title
      await tester.enterText(
        find.widgetWithText(TextField, '标题').first,
        'empty_content',
      );
      await tester.pump();

      // Leave content empty and save
      await tester.tap(find.text('保存'));
      // Use pump() instead of pumpAndSettle() to avoid overflow errors
      // during the save process
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should save successfully
      final records = await TextManifest.loadRecords();
      expect(records.length, equals(1));
      expect(records[0].name, equals('empty_content'));
      expect(records[0].textLength, equals(0));
      expect(records[0].size, equals(0));
    });
  });
}
