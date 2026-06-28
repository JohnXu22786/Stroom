import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/application.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

/// Builds the test app matching the real app structure.
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
    ],
    child: const Application(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Application - Startup (migration handled by StartupApp)', () {
    testWidgets('does not show migration dialog when data format is outdated'
        ' (migration is handled by StartupPage)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0, // 旧版本 — 但 Application 不再处理迁移
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // Application no longer shows migration dialog — it now shows
      // HomePage directly. Migration is handled by StartupPage.
      expect(find.text('数据迁移'), findsNothing);
    });

    testWidgets('does not show migration dialog when format is current',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 2, // 当前版本，不需要迁移
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // No migration dialog (migration is handled by StartupPage)
      expect(find.text('数据迁移'), findsNothing);
    });
  });
}
