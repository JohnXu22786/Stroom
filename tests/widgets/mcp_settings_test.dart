import 'dart:async';
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
Widget _buildTestApp({Future<void>? updateGate}) {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      providerEntriesProvider.overrideWith((ref) {
        final notifier = updateGate == null
            ? ProviderEntriesNotifier()
            : _BlockingProviderEntriesNotifier(updateGate);
        // load() is normally called in the provider factory, so we call it here too.
        notifier.load();
        return notifier;
      }),
      updateProvider.overrideWith((ref) => UpdateNotifier()),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

class _BlockingProviderEntriesNotifier extends ProviderEntriesNotifier {
  _BlockingProviderEntriesNotifier(this._updateGate);

  final Future<void> _updateGate;

  @override
  Future<void> update(
    String id,
    ProviderEntry updated, {
    bool requirePersistence = false,
  }) async {
    await _updateGate;
    await super.update(id, updated, requirePersistence: requirePersistence);
  }
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

Finder _commandFieldFinder() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '例如: npx',
    );

Finder _argsFieldFinder() => find.byWidgetPredicate(
      (w) =>
          w is TextField && w.decoration?.hintText?.startsWith('用逗号分隔') == true,
    );

Finder _urlFieldFinder() => find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == '例如: http://localhost:3001/sse',
    );

Finder _readOnlyDescriptionFinder() => find.byWidgetPredicate(
      (w) => w is mcp_shared.ReadOnlyField && w.label == '描述',
    );

Finder _readOnlyDescriptionValueFinder(String value) => find.descendant(
      of: _readOnlyDescriptionFinder(),
      matching: find.text(value),
    );

Future<void> _openCustomMcpConfig(
  WidgetTester tester, {
  Future<void>? updateGate,
  bool stdio = false,
  String? apiKey,
  Map<String, String>? headers,
  Map<String, String>? env,
}) async {
  SharedPreferences.setMockInitialValues({
    'provider_entries': jsonEncode([
      {
        'id': 'builtin_mcp',
        'type': 'mcp',
        'name': 'MCP供应商',
        'configs': [
          {
            'providerName': 'Custom MCP',
            'host': stdio ? '' : 'https://mcp.example.com/sse',
            'key': '',
            'models': [
              {
                'name': 'Custom MCP',
                'modelId': stdio ? 'stdio' : 'sse',
                'typeConfig': stdio
                    ? {
                        'transport': 'stdio',
                        'command': 'npx',
                        'args': ['-y', 'example-server'],
                        'description': 'Original description',
                        if (env != null) 'env': env,
                      }
                    : {
                        'transport': 'sse',
                        'url': 'https://mcp.example.com/sse',
                        'description': 'Original description',
                        if (apiKey != null) 'apiKey': apiKey,
                        if (headers != null) 'headers': headers,
                        if (env != null) 'env': env,
                      },
              },
            ],
          },
        ],
      },
    ]),
  });

  await tester.pumpWidget(_buildTestApp(updateGate: updateGate));
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
      'updating a header-backed API key replaces credential sources',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await _openCustomMcpConfig(
          tester,
          apiKey: 'sk-current',
          headers: {
            'X-Mode': 'keep-this-header',
            'Authorization': 'Bearer sk-header-old',
          },
          env: {
            'CUSTOM_SETTING': 'keep-this-value',
            'CUSTOM_API_KEY': 'sk-env-old',
            'PATH': '/custom/bin',
          },
        );

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).controller!.text,
          'sk-current',
        );
        await tester.enterText(_apiKeyFieldFinder(), 'sk-new');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        final preferences = await SharedPreferences.getInstance();
        final entries =
            jsonDecode(preferences.getString('provider_entries')!) as List;
        final entry = entries.singleWhere(
          (item) => item['id'] == 'builtin_mcp',
        ) as Map<String, dynamic>;
        final config =
            (entry['configs'] as List).cast<Map<String, dynamic>>().first;
        final model =
            (config['models'] as List).cast<Map<String, dynamic>>().first;
        final typeConfig = model['typeConfig'] as Map<String, dynamic>;
        expect(typeConfig['apiKey'], 'sk-new');
        expect(
          typeConfig['headers'],
          {
            'X-Mode': 'keep-this-header',
            'Authorization': 'Bearer sk-new',
          },
        );
        expect(
          typeConfig['env'],
          {
            'CUSTOM_SETTING': 'keep-this-value',
            'CUSTOM_API_KEY': 'sk-new',
            'PATH': '/custom/bin',
          },
        );
        expect(find.text('••••••••'), findsOneWidget);

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).controller!.text,
          'sk-new',
        );
      },
    );

    testWidgets(
      'clearing a header-backed API key removes it but preserves unrelated headers',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await _openCustomMcpConfig(
          tester,
          headers: {
            'X-Mode': 'keep-this-header',
            'Authorization': 'Bearer sk-header',
          },
        );

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).controller!.text,
          'sk-header',
        );
        await tester.enterText(_apiKeyFieldFinder(), '');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        final preferences = await SharedPreferences.getInstance();
        final entries =
            jsonDecode(preferences.getString('provider_entries')!) as List;
        final entry = entries.singleWhere(
          (item) => item['id'] == 'builtin_mcp',
        ) as Map<String, dynamic>;
        final config =
            (entry['configs'] as List).cast<Map<String, dynamic>>().first;
        final model =
            (config['models'] as List).cast<Map<String, dynamic>>().first;
        final typeConfig = model['typeConfig'] as Map<String, dynamic>;
        expect(typeConfig['headers'], {'X-Mode': 'keep-this-header'});
        expect(
          find.descendant(
            of: _readOnlyApiKeyFinder(),
            matching: find.text('（未设置）'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets(
      'clearing an environment-backed API key removes it but preserves unrelated environment values',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await _openCustomMcpConfig(
          tester,
          stdio: true,
          env: {
            'KEYBOARD_LAYOUT': 'us',
            'CUSTOM_SETTING': 'keep-this-value',
            'CUSTOM_API_KEY': 'sk-env',
            'PATH': '/custom/bin',
          },
        );

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).controller!.text,
          'sk-env',
        );
        await tester.enterText(_apiKeyFieldFinder(), '');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        final preferences = await SharedPreferences.getInstance();
        final entries =
            jsonDecode(preferences.getString('provider_entries')!) as List;
        final entry = entries.singleWhere(
          (item) => item['id'] == 'builtin_mcp',
        ) as Map<String, dynamic>;
        final config =
            (entry['configs'] as List).cast<Map<String, dynamic>>().first;
        final model =
            (config['models'] as List).cast<Map<String, dynamic>>().first;
        final typeConfig = model['typeConfig'] as Map<String, dynamic>;
        expect(
          typeConfig['env'],
          {
            'KEYBOARD_LAYOUT': 'us',
            'CUSTOM_SETTING': 'keep-this-value',
            'PATH': '/custom/bin',
          },
        );
        expect(
          find.descendant(
            of: _readOnlyApiKeyFinder(),
            matching: find.text('（未设置）'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets(
      'clearing a saved API key stays unset after persistence',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await _openCustomMcpConfig(
          tester,
          apiKey: 'sk-123',
          headers: {
            'X-Mode': 'keep-this-header',
            'Authorization': 'Bearer stale-header-key',
          },
          env: {
            'CUSTOM_SETTING': 'keep-this-value',
            'CUSTOM_API_KEY': 'stale-env-key',
            'PATH': '/custom/bin',
          },
        );

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).controller!.text,
          'sk-123',
        );
        await tester.enterText(_apiKeyFieldFinder(), '');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        final preferences = await SharedPreferences.getInstance();
        final entries =
            jsonDecode(preferences.getString('provider_entries')!) as List;
        final entry = entries.singleWhere(
          (item) => item['id'] == 'builtin_mcp',
        ) as Map<String, dynamic>;
        final config =
            (entry['configs'] as List).cast<Map<String, dynamic>>().first;
        final model =
            (config['models'] as List).cast<Map<String, dynamic>>().first;
        final typeConfig = model['typeConfig'] as Map<String, dynamic>;
        expect(typeConfig, isNot(contains('apiKey')));
        expect(typeConfig['headers'], {'X-Mode': 'keep-this-header'});
        expect(
          typeConfig['env'],
          {
            'CUSTOM_SETTING': 'keep-this-value',
            'PATH': '/custom/bin',
          },
        );
        expect(
          find.descendant(
            of: _readOnlyApiKeyFinder(),
            matching: find.text('（未设置）'),
          ),
          findsOneWidget,
        );
        expect(find.text('••••••••'), findsNothing);

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets(
      'saving a transport switch clears fields omitted from persisted config',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await _openCustomMcpConfig(tester, stdio: true);

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(_commandFieldFinder()).controller!.text,
            'npx');
        expect(
          tester.widget<TextField>(_argsFieldFinder()).controller!.text,
          '-y, example-server',
        );

        await tester.tap(find.text('远程 (SSE)'));
        await tester.pumpAndSettle();
        await tester.enterText(
          _urlFieldFinder(),
          'https://remote.example.com/sse',
        );
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        final preferences = await SharedPreferences.getInstance();
        final entries =
            jsonDecode(preferences.getString('provider_entries')!) as List;
        final entry = entries.singleWhere(
          (item) => item['id'] == 'builtin_mcp',
        ) as Map<String, dynamic>;
        final config =
            (entry['configs'] as List).cast<Map<String, dynamic>>().first;
        final model =
            (config['models'] as List).cast<Map<String, dynamic>>().first;
        final typeConfig = model['typeConfig'] as Map<String, dynamic>;
        expect(typeConfig['transport'], 'sse');
        expect(typeConfig, isNot(contains('command')));
        expect(typeConfig, isNot(contains('args')));

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('本地 (stdio)'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_commandFieldFinder()).controller!.text,
          isEmpty,
          reason: 'switching back must not reveal the omitted command value',
        );
        expect(
          tester.widget<TextField>(_argsFieldFinder()).controller!.text,
          isEmpty,
          reason: 'switching back must not reveal omitted argument values',
        );
      },
    );

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

      await tester.enterText(_apiKeyFieldFinder(), '   ');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(_readOnlyApiKeyFinder(), findsOneWidget);
      expect(
        find.descendant(
          of: _readOnlyApiKeyFinder(),
          matching: find.text('（未设置）'),
        ),
        findsOneWidget,
        reason: 'whitespace-only input must not appear as a saved key',
      );
      expect(find.text('••••••••'), findsNothing);

      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_apiKeyFieldFinder()).controller!.text,
        isEmpty,
        reason: 'the editor must match the persisted empty placeholder',
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

        await tester.tap(find.byTooltip('显示密钥'));
        await tester.pump();
        await tester.tap(find.text('放弃'));
        await tester.pumpAndSettle();
        expect(find.text('sk-123'), findsNothing);

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).obscureText,
          isTrue,
          reason: 'the key must be masked again after discarding edit mode',
        );

        await tester.tap(find.byTooltip('显示密钥'));
        await tester.pump();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(find.text('sk-123'), findsNothing);

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_apiKeyFieldFinder()).obscureText,
          isTrue,
          reason: 'the key must be masked again after saving edit mode',
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
        await tester.enterText(
          _descriptionFieldFinder(),
          '  Saved description  ',
        );
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(_descriptionFieldFinder(), findsNothing);
        expect(_readOnlyDescriptionFinder(), findsOneWidget);
        expect(
          _readOnlyDescriptionValueFinder('Saved description'),
          findsOneWidget,
          reason: 'the read-only view must display the persisted trimmed value',
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

        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_descriptionFieldFinder()).controller!.text,
          'Saved description',
        );
      },
    );

    testWidgets(
      'custom MCP fields are disabled while a save is pending',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final updateGate = Completer<void>();
        await _openCustomMcpConfig(tester, updateGate: updateGate.future);
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        await tester.enterText(_descriptionFieldFinder(), 'Saved description');
        await tester.tap(find.text('保存'));
        await tester.pump();

        final dialogFields = tester.widgetList<TextField>(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(TextField),
          ),
        );
        final allFieldsDisabled = dialogFields.isNotEmpty &&
            dialogFields.every((field) => field.enabled == false);

        try {
          if (!allFieldsDisabled) {
            await tester.enterText(
              _descriptionFieldFinder(),
              'Changed while save was pending',
            );
          }
        } finally {
          updateGate.complete();
        }
        await tester.pumpAndSettle();

        expect(
          allFieldsDisabled,
          isTrue,
          reason: 'form fields must not accept edits during persistence',
        );
        expect(
          _readOnlyDescriptionValueFinder('Saved description'),
          findsOneWidget,
        );
        expect(
          _readOnlyDescriptionValueFinder('Changed while save was pending'),
          findsNothing,
        );
      },
    );
  });
}
