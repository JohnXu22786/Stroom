import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/provider_config_page.dart';
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

/// 构建只包含 TTS、LLM 和 OCR 的已保存数据（模拟旧版本用户升级，无 ASR）
String _savedDataWithoutAsr() {
  final entries = [
    {
      'id': 'builtin_tts',
      'type': 'tts',
      'name': 'TTS供应商',
      'configs': <Map<String, dynamic>>[],
    },
    {
      'id': 'builtin_llm',
      'type': 'llm',
      'name': 'LLM供应商',
      'configs': <Map<String, dynamic>>[],
    },
    {
      'id': 'builtin_ocr',
      'type': 'ocr',
      'name': 'OCR供应商',
      'configs': <Map<String, dynamic>>[],
    },
  ];
  return jsonEncode(entries);
}

void main() {
  group('SettingsPage - ASR (语音识别) supplier display', () {
    testWidgets('shows ASR supplier entry when loaded with default entries',
        (tester) async {
      // Use a large viewport so all content is visible
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // No saved data → defaults including ASR
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('TTS供应商'), findsOneWidget);
      expect(find.text('LLM供应商'), findsOneWidget);
      expect(find.text('OCR供应商'), findsOneWidget);
      expect(find.text('语音识别供应商'), findsOneWidget);
    });

    testWidgets(
        'shows ASR supplier after migration from saved data without it',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithoutAsr(),
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // ASR should be migrated in and displayed
      expect(find.text('TTS供应商'), findsOneWidget);
      expect(find.text('LLM供应商'), findsOneWidget);
      expect(find.text('OCR供应商'), findsOneWidget);
      expect(find.text('语音识别供应商'), findsOneWidget);
    });

    testWidgets(
        'ASR supplier entry is tappable and navigates to config page',
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

      // Verify ASR supplier is visible
      expect(find.text('语音识别供应商'), findsOneWidget);

      // Tap the ASR supplier entry
      await tester.tap(find.text('语音识别供应商'));
      await tester.pumpAndSettle();

      // Should navigate to ProviderConfigPage which has title "供应商配置"
      expect(find.text('供应商配置'), findsOneWidget);
    });
  });
}
