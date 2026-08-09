import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/text_storage_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: TextStoragePage()),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('TextStoragePage', () {
    // ═══════════════════════════════════════════════════
    // File extension icon display tests
    // ═══════════════════════════════════════════════════

    testWidgets('file icon renders mmd extension without overflow',
        (tester) async {
      // Insert an mmd record
      const initialCode = 'graph TD\n  A[Start] --> B[End]';
      final bytes = Uint8List.fromList(utf8.encode(initialCode));
      await TextManifest.addRecord(
        TextRecord(
          name: 'test_diagram',
          hash: computeTextHash(bytes),
          format: 'mmd',
          createdAt: DateTime.now(),
          size: bytes.length,
          folder: '',
          textLength: initialCode.length,
        ),
      );

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The mmd extension text should be visible in the file icon area
      // and should not overflow — verify by checking no overflow errors
      expect(find.text('MMD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('file popup menu shows 预览 exactly once', (tester) async {
      final bytes = Uint8List.fromList(utf8.encode('Hello'));
      await TextManifest.addRecord(
        TextRecord(
          id: 'txt_dup_preview_test',
          name: 'test_text',
          hash: computeTextHash(bytes),
          format: 'txt',
          createdAt: DateTime.now(),
          size: bytes.length,
          folder: '',
          textLength: 5,
        ),
      );

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Open the file popup menu
      await tester.tap(
        find.byKey(const Key('fm_file_popup_txt_dup_preview_test')),
      );
      await tester.pumpAndSettle();

      // The default menu already includes 预览; the page config must not
      // add a duplicate entry.
      expect(find.text('预览'), findsOneWidget);
    });

    testWidgets('file icon renders txt extension correctly', (tester) async {
      const content = 'Hello World';
      final bytes = Uint8List.fromList(utf8.encode(content));
      await TextManifest.addRecord(
        TextRecord(
          name: 'test_text',
          hash: computeTextHash(bytes),
          format: 'txt',
          createdAt: DateTime.now(),
          size: bytes.length,
          folder: '',
          textLength: content.length,
        ),
      );

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The txt extension should be visible without overflow
      expect(find.text('TXT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
