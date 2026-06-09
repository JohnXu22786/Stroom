import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/camera_settings_provider.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

/// Builds the test app with all required provider overrides.
/// Uses a large screen size to avoid needing to scroll.
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      cameraSettingsProvider.overrideWith((ref) => CameraSettingsNotifier()),
      providerEntriesProvider.overrideWith(
        (ref) {
          final notifier = ProviderEntriesNotifier();
          // load() is normally called in the provider factory, so we call it here too.
          notifier.load();
          return notifier;
        },
      ),
      updateProvider.overrideWith((ref) => UpdateNotifier()),
    ],
    child: const MaterialApp(
      home: SettingsPage(),
    ),
  );
}

void main() {
  group('SettingsPage - MCP section', () {
    setUp(() {
      registerBuiltinProviderTypes();
    });

    testWidgets('settings page shows MCP供应商 entry when MCP type is registered',
        (tester) async {
      // Use a large viewport so all content is visible
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // No saved data → defaults including MCP
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('MCP供应商'), findsOneWidget);
      expect(find.text('TTS供应商'), findsOneWidget);
      expect(find.text('LLM供应商'), findsOneWidget);
      expect(find.text('OCR供应商'), findsOneWidget);
      expect(find.text('语音识别供应商'), findsOneWidget);
    });

    testWidgets('tapping MCP entry navigates to MCP config page',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Find and tap the MCP供应商 entry
      await tester.tap(find.text('MCP供应商'));
      await tester.pumpAndSettle();

      // Should navigate to ProviderConfigPage with MCP供应商 title
      // Since we have no configs, it should show "暂无供应商配置，请点击"添加"创建"
      expect(find.text('暂无供应商配置，请点击"添加"创建'), findsOneWidget);
    });

    testWidgets('MCP config page allows adding a new MCP server',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Navigate to MCP config page
      await tester.tap(find.text('MCP供应商'));
      await tester.pumpAndSettle();

      // Tap "添加" to add a new config
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // Should navigate to ProviderConfigDetailPage for MCP
      // The page shows "新建MCP供应商配置"
      expect(find.textContaining('新建'), findsOneWidget);
    });
  });
}
