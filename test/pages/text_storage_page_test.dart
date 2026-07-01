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
    test('can be created', () {
      const page = TextStoragePage();
      expect(page, isNotNull);
    });

    testWidgets('renders with file manager view', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show the app bar title '文本'
      expect(find.text('文本'), findsOneWidget);

      // Should show the action buttons (shortened)
      expect(find.text('新建'), findsOneWidget);
      expect(find.text('导入'), findsOneWidget);

      // Should show the file manager scaffold
      expect(find.byKey(const Key('fm_scaffold')), findsOneWidget);
    });
  });
}
