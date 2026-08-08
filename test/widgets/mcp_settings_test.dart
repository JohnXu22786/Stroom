import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

/// Builds the test app with all required provider overrides.
/// Uses a large screen size to avoid needing to scroll.
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      providerEntriesProvider.overrideWith((ref) {
        final notifier = ProviderEntriesNotifier();
        // load() is normally called in the provider factory, so we call it here too.
        notifier.load();
        return notifier;
      }),
      updateProvider.overrideWith((ref) => UpdateNotifier()),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

void main() {
  group('SettingsPage - MCP section', () {
    setUp(() {
      registerBuiltinProviderTypes();
    });

    testWidgets(
        'tapping MCP entry navigates to MCP config page with built-in configs',
        (
      tester,
    ) async {
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

      // Should navigate to ProviderConfigPage with built-in configs visible
      // The page should show at least some built-in MCP server names
      expect(find.text('MCP供应商'), findsOneWidget);
      expect(find.text('Exa'), findsOneWidget);
    });

    testWidgets('MCP config page allows adding a new MCP server', (
      tester,
    ) async {
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

    testWidgets(
        'built-in MCP edit page does not auto-fill the "Bearer " placeholder '
        'as API key, and the key field can be revealed', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Saved MCP entry with a Jina AI config whose Authorization header is
      // only the "Bearer " prefix placeholder (no real key).
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
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
          {
            'id': 'builtin_asr',
            'type': 'asr',
            'name': '音频转写供应商',
            'configs': <Map<String, dynamic>>[],
          },
          {
            'id': 'builtin_mcp',
            'type': 'mcp',
            'name': 'MCP供应商',
            'configs': [
              {
                'providerName': 'Jina AI',
                'host': 'https://mcp.jina.ai/sse',
                'key': '',
                'models': [
                  {
                    'name': 'Jina AI',
                    'modelId': 'sse',
                    'typeConfig': {
                      'transport': 'sse',
                      'url': 'https://mcp.jina.ai/sse',
                      'isVendor': true,
                      'headers': {'Authorization': 'Bearer '},
                    },
                  },
                ],
              },
            ],
          },
        ]),
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Navigate to the built-in Jina AI MCP server edit page.
      await tester.tap(find.text('MCP供应商'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jina AI'));
      await tester.pumpAndSettle();

      TextField apiKeyField() => tester.widget<TextField>(
            find.byWidgetPredicate((w) =>
                w is TextField && w.decoration?.hintText == '输入 API Key（可选）'),
          );

      // The "Bearer " placeholder must NOT be auto-filled as the API key
      // (regression: the 6-char "Bearer" was shown in the field).
      expect(apiKeyField().controller!.text, isEmpty,
          reason: 'the "Bearer " header placeholder must not be auto-filled '
              'as the API key (regression: 6-char "Bearer")');

      // The key must be viewable: the eye toggle reveals it.
      expect(apiKeyField().obscureText, isTrue);
      await tester.tap(find.byTooltip('显示密钥'));
      await tester.pump();
      expect(apiKeyField().obscureText, isFalse,
          reason: 'the API key must be viewable via the visibility toggle');
    });

    testWidgets(
        'built-in MCP edit page shows a real key from the Authorization '
        'header', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Jina AI config with a REAL key in the Authorization header.
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {
            'id': 'builtin_mcp',
            'type': 'mcp',
            'name': 'MCP供应商',
            'configs': [
              {
                'providerName': 'Jina AI',
                'host': 'https://mcp.jina.ai/sse',
                'key': '',
                'models': [
                  {
                    'name': 'Jina AI',
                    'modelId': 'sse',
                    'typeConfig': {
                      'transport': 'sse',
                      'url': 'https://mcp.jina.ai/sse',
                      'isVendor': true,
                      'headers': {'Authorization': 'Bearer sk-123'},
                    },
                  },
                ],
              },
            ],
          },
        ]),
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('MCP供应商'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jina AI'));
      await tester.pumpAndSettle();

      final apiKeyField = tester.widget<TextField>(
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == '输入 API Key（可选）'),
      );
      expect(apiKeyField.controller!.text, 'sk-123',
          reason: 'a real "Bearer <key>" header must be shown as the API key');
    });
  });
}
