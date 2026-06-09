import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/home_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: HomePage(),
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

  group('HomePage modular blocks', () {
    testWidgets('renders welcome text on home page', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show the welcome text
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('shows module cards on home page', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show OCR module card
      expect(find.text('OCR'), findsOneWidget);
    });

    testWidgets('OCR module card is tappable', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the OCR module
      await tester.tap(find.text('OCR'));
      await tester.pumpAndSettle();

      // Should navigate to OCR page (check for OCR page title)
      expect(find.text('文字识别'), findsOneWidget);
    });

    testWidgets('home page has module grid layout', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify the module grid exists
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('module cards have correct icons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // OCR icon should be present
      expect(find.byIcon(Icons.text_snippet), findsOneWidget);
    });
  });
}
