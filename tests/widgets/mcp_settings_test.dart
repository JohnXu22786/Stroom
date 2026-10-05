import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/mcp_server_config_shared.dart' as mcp_shared;
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

Finder _apiKeyFieldFinder() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '输入 API Key（可选）',
    );

Finder _readOnlyApiKeyFinder() => find.byWidgetPredicate(
      (w) => w is mcp_shared.ReadOnlyField && w.label == 'API 密钥',
    );

Finder _descriptionFieldFinder() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '输入此 MCP 服务器的描述信息（可选）',
    );

Finder _readOnlyDescriptionFinder() => find.byWidgetPredicate(
      (w) => w is mcp_shared.ReadOnlyField && w.label == '描述',
    );

Finder _readOnlyDescriptionValueFinder(String value) => find.descendant(
      of: _readOnlyDescriptionFinder(),
      matching: find.text(value),
    );

Future<void> _openCustomMcpConfig(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'provider_entries': jsonEncode([
      {
        'id': 'builtin_mcp',
        'type': 'mcp',
        'name': 'MCP供应商',
        'configs': [
          {
            'providerName': 'Custom MCP',
            'host': 'https://mcp.example.com/sse',
            'key': '',
            'models': [
              {
                'name': 'Custom MCP',
                'modelId': 'sse',
                'typeConfig': {
                  'transport': 'sse',
                  'url': 'https://mcp.example.com/sse',
                  'description': 'Original description',
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
  await tester.tap(find.text('Custom MCP'));
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsPage - MCP section', () {
    setUp(() {
      registerBuiltinProviderTypes();
    });

    testWidgets(
        'built-in MCP details keep the "Bearer " placeholder unset and expose '
        'an empty key field only after entering edit mode', (tester) async {
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

      // Navigate to the built-in Jina AI MCP server details page.
      await tester.tap(find.text('MCP供应商'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jina AI'));
      await tester.pumpAndSettle();

      // Existing configs stay read-only until explicitly switched to edit mode.
      expect(_apiKeyFieldFinder(), findsNothing);
      expect(_readOnlyApiKeyFinder(), findsOneWidget);
      expect(
        find.descendant(
          of: _readOnlyApiKeyFinder(),
          matching: find.text('（未设置）'),
        ),
        findsOneWidget,
        reason: 'the "Bearer " placeholder must remain unset, not become a '
            'fake API key',
      );

      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // The placeholder must not be auto-filled as a key in edit mode either.
      final apiKeyField = tester.widget<TextField>(_apiKeyFieldFinder());
      expect(
        apiKeyField.controller!.text,
        isEmpty,
        reason: 'the "Bearer " header placeholder must not be auto-filled '
            'as the API key',
      );

      // The key must be viewable: the eye toggle reveals it.
      expect(apiKeyField.obscureText, isTrue);
      await tester.tap(find.byTooltip('显示密钥'));
      await tester.pump();
      expect(
        tester.widget<TextField>(_apiKeyFieldFinder()).obscureText,
        isFalse,
        reason: 'the API key must be viewable via the visibility toggle',
      );
    });

    testWidgets(
      'built-in MCP details mask a real key until edit mode and preserve '
      'visibility behavior',
      (tester) async {
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

        // A real key remains hidden in the default details view.
        expect(_apiKeyFieldFinder(), findsNothing);
        expect(_readOnlyApiKeyFinder(), findsOneWidget);
        expect(find.text('••••••••'), findsOneWidget);
        expect(find.text('sk-123'), findsNothing);

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();

        final apiKeyField = tester.widget<TextField>(_apiKeyFieldFinder());
        expect(
          apiKeyField.controller!.text,
          'sk-123',
          reason: 'edit mode must expose the actual key from the '
              'Authorization header',
        );
        expect(
          apiKeyField.obscureText,
          isTrue,
          reason: 'the actual API key must start masked while editing',
        );

        await tester.tap(find.byTooltip('显示密钥'));
        await tester.pump();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).obscureText,
          isFalse,
        );

        await tester.tap(find.byTooltip('隐藏密钥'));
        await tester.pump();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).obscureText,
          isTrue,
        );
      },
    );

    testWidgets(
      'custom MCP descriptions stay read-only until edit and discard restores',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await _openCustomMcpConfig(tester);

        expect(_descriptionFieldFinder(), findsNothing);
        expect(_readOnlyDescriptionFinder(), findsOneWidget);
        expect(
          _readOnlyDescriptionValueFinder('Original description'),
          findsOneWidget,
        );

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_descriptionFieldFinder()).controller!.text,
          'Original description',
        );

        await tester.enterText(
          _descriptionFieldFinder(),
          'Discarded description',
        );
        await tester.tap(find.text('放弃'));
        await tester.pumpAndSettle();
        expect(_descriptionFieldFinder(), findsNothing);
        expect(
          _readOnlyDescriptionValueFinder('Original description'),
          findsOneWidget,
        );
        expect(find.text('Discarded description'), findsNothing);
      },
    );

    testWidgets(
      'saving a custom MCP description persists it and returns to read-only',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await _openCustomMcpConfig(tester);

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        await tester.enterText(_descriptionFieldFinder(), 'Saved description');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(_descriptionFieldFinder(), findsNothing);
        expect(_readOnlyDescriptionFinder(), findsOneWidget);
        expect(
          _readOnlyDescriptionValueFinder('Saved description'),
          findsOneWidget,
        );

        final preferences = await SharedPreferences.getInstance();
        final entries =
            jsonDecode(preferences.getString('provider_entries')!) as List;
        final entry = entries.singleWhere(
          (item) => item['id'] == 'builtin_mcp',
        ) as Map<String, dynamic>;
        final config =
            (entry['configs'] as List).cast<Map<String, dynamic>>().firstWhere(
                  (item) => item['providerName'] == 'Custom MCP',
                );
        final model =
            (config['models'] as List).cast<Map<String, dynamic>>().firstWhere(
                  (item) => item['name'] == 'Custom MCP',
                );
        expect(
          (model['typeConfig'] as Map<String, dynamic>)['description'],
          'Saved description',
        );
      },
    );
  });
}
