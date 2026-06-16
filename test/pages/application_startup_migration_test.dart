import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/application.dart';
import 'package:stroom/providers/theme_provider.dart';

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

  group('Application - Startup Migration', () {
    testWidgets('shows migration dialog when data format is outdated',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0, // 旧版本，需要迁移
      });

      await tester.pumpWidget(_buildTestApp());
      // Process post-frame callback → _performStartupChecks starts
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // Migration dialog should appear with spinner
      expect(find.text('数据迁移'), findsOneWidget);
      expect(find.text('正在数据迁移到新版本'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does not show migration dialog when format is current',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1, // 当前版本，不需要迁移
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // No migration dialog
      expect(find.text('数据迁移'), findsNothing);
    });
  });
}
