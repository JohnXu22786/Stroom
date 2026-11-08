import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/provider_preset_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/llm_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProviderEntriesNotifier.load - corrupt data handling', () {
    test(
        'non-array provider_entries is quarantined before migration '
        'overwrite', () async {
      // 回归：chat_configs 存在时 _migrateOldChatConfigs 会重写
      // provider_entries —— 现有数据损坏（非数组）必须先隔离再覆盖，
      // 否则损坏现场被永久销毁（备份恢复都救不回来）。
      SharedPreferences.setMockInitialValues({
        'provider_entries': '{"not": "an array"}',
        'chat_configs': jsonEncode([
          {
            'providerName': 'Old',
            'host': '',
            'key': '',
            'models': [
              {'modelId': 'm1', 'temperature': 0.5},
            ],
          },
        ]),
      });

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty, reason: '覆盖前必须隔离原始损坏数据');
      expect(
        corruptKeys.any((k) => prefs.getString(k) == '{"not": "an array"}'),
        isTrue,
      );
      // 迁移后的 llm 条目被加载进状态。
      expect(notifier.state.entries.any((e) => e.id == 'migrated_llm'), isTrue);
    });

    test(
      'unparseable provider_entries is quarantined and defaults loaded',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': 'not-json{{{',
        });

        final notifier = ProviderEntriesNotifier();
        await notifier.load();

        final prefs = await SharedPreferences.getInstance();
        final corruptKeys = prefs
            .getKeys()
            .where((k) => k.startsWith('provider_entries_corrupt_'))
            .toList();
        expect(corruptKeys, isNotEmpty);
        expect(
          corruptKeys.any((k) => prefs.getString(k) == 'not-json{{{'),
          isTrue,
          reason: '原始损坏数据必须保留（含 API key 的配置不可恢复地丢失）',
        );
        // 回退默认预置，应用仍可正常使用。
        expect(notifier.state.entries, isNotEmpty);
      },
    );

    test(
      'persists a fresh non-LLM provider edit without an LLM key change',
      () async {
        SharedPreferences.setMockInitialValues({});
        final notifier = ProviderEntriesNotifier();
        await notifier.load();

        final added = ProviderEntry(
          id: 'fresh-ocr-entry',
          type: 'ocr',
          name: 'Fresh OCR provider',
        );
        await notifier.addFirst(added);

        final prefs = await SharedPreferences.getInstance();
        final stored =
            jsonDecode(prefs.getString('provider_entries')!) as List<dynamic>;
        expect(
          stored.whereType<Map>().any((entry) => entry['id'] == added.id),
          isTrue,
        );
      },
    );

    test('does not overwrite provider settings changed after load', () async {
      const initialEntries =
          '[{"id":"original-tts","type":"tts","name":"Original TTS","configs":[]}]';
      const externalEntries =
          '[{"id":"external-tts","type":"tts","name":"External TTS","configs":[]}]';
      SharedPreferences.setMockInitialValues({
        'provider_entries': initialEntries,
      });

      final notifier = ProviderEntriesNotifier();
      addTearDown(notifier.dispose);
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('provider_entries', externalEntries);

      await expectLater(
        notifier.addFirst(
          ProviderEntry(
            id: 'stale-added-tts',
            type: 'tts',
            name: 'Stale added TTS',
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(prefs.getString('provider_entries'), externalEntries);
    });

    test('required updates fail when the provider entry was removed', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {
            'id': 'removed-entry',
            'type': 'tts',
            'name': 'Removed entry',
            'configs': [],
          },
        ]),
      });
      final notifier = ProviderEntriesNotifier();
      addTearDown(notifier.dispose);
      await notifier.load();
      await notifier.remove('removed-entry');

      await expectLater(
        notifier.update(
          'removed-entry',
          ProviderEntry(id: 'removed-entry', type: 'tts', name: 'Stale save'),
          requirePersistence: true,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        notifier.state.entries.any((entry) => entry.id == 'removed-entry'),
        isFalse,
      );
    });

    test(
      'does not retry a stale required update after a persistence conflict',
      () async {
        SharedPreferences.setMockInitialValues({});
        final notifier = ProviderEntriesNotifier();
        addTearDown(notifier.dispose);
        await notifier.load();

        final prefs = await SharedPreferences.getInstance();
        final originalTts = notifier.state.entries.firstWhere(
          (entry) => entry.id == 'builtin_tts',
        );
        final staleUpdate = ProviderEntry(
          id: originalTts.id,
          type: originalTts.type,
          name: 'Stale TTS edit',
          configs: originalTts.configs.map((config) => config.copy()).toList(),
          legacyFields: originalTts.legacyFields,
        );
        final externallyUpdatedEntries = notifier.state.entries
            .map((entry) {
              if (entry.id != originalTts.id) return entry;
              return ProviderEntry(
                id: entry.id,
                type: entry.type,
                name: 'Newer external TTS edit',
                configs: [
                  ProviderConfigItem(
                    id: 'newer-external-config',
                    providerName: 'Newer external config',
                  ),
                ],
                legacyFields: entry.legacyFields,
              );
            })
            .map((entry) => entry.toMap())
            .toList();
        final externalJson = jsonEncode(externallyUpdatedEntries);
        await prefs.setString('provider_entries', externalJson);

        await expectLater(
          notifier.update(
            originalTts.id,
            staleUpdate,
            requirePersistence: true,
          ),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          notifier.update(
            originalTts.id,
            staleUpdate,
            requirePersistence: true,
          ),
          throwsA(isA<StateError>()),
        );

        final savedEntries =
            jsonDecode(prefs.getString('provider_entries')!) as List<dynamic>;
        final savedTts = savedEntries.whereType<Map>().singleWhere(
              (entry) => entry['id'] == originalTts.id,
            );
        expect(savedTts['name'], 'Newer external TTS edit');
        expect(
          (savedTts['configs'] as List).single['id'],
          'newer-external-config',
        );
      },
    );

    test(
      'does not retry a stale update after a provider source change during credential migration',
      () async {
        const accountId = 'racing-account';
        const credentialRef = 'stroom.llm.credential.racing-account';
        SharedPreferences.setMockInitialValues({
          'provider_entries': jsonEncode([
            {
              'id': 'racing-llm-entry',
              'type': 'llm',
              'name': 'Original entry',
              'configs': [
                {
                  'id': accountId,
                  'providerName': 'Original provider',
                  'key': 'migration-secret',
                  'models': [],
                },
              ],
            },
          ]),
        });
        final prefs = await SharedPreferences.getInstance();
        final credentialStore = _RacingCredentialStore(
          prefs: prefs,
          credentialRef: credentialRef,
          externalEntries: jsonEncode([
            {
              'id': 'racing-llm-entry',
              'type': 'llm',
              'name': 'Newer external entry',
              'configs': [
                {
                  'id': accountId,
                  'providerName': 'Newer external provider',
                  'credentialRef': credentialRef,
                  'models': [],
                },
              ],
            },
          ]),
        );
        final notifier = ProviderEntriesNotifier(
          credentialStore: credentialStore,
        );
        addTearDown(notifier.dispose);
        await notifier.load();

        final original = notifier.state.entries.singleWhere(
          (entry) => entry.id == 'racing-llm-entry',
        );
        final staleUpdate = ProviderEntry(
          id: original.id,
          type: original.type,
          name: 'Stale update',
          configs: original.configs.map((config) => config.copy()).toList(),
          legacyFields: original.legacyFields,
        );
        credentialStore.arm();

        await expectLater(
          notifier.update(original.id, staleUpdate, requirePersistence: true),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          notifier.update(original.id, staleUpdate, requirePersistence: true),
          throwsA(isA<StateError>()),
        );

        final savedEntries =
            jsonDecode(prefs.getString('provider_entries')!) as List<dynamic>;
        final savedEntry = savedEntries
            .whereType<Map>()
            .singleWhere((entry) => entry['id'] == 'racing-llm-entry');
        expect(savedEntry['name'], 'Newer external entry');
        expect(
          ((savedEntry['configs'] as List).single as Map)['providerName'],
          'Newer external provider',
        );
      },
    );
  });

  group('built-in provider display localization', () {
    const presets = <String, (String, String)>{
      'Exa': (
        '通过 Exa MCP 接口进行网络搜索、内容提取和深度研究，支持语义搜索与关键词搜索',
        '请在 Exa 官网获取 API Key',
      ),
      'Tavily': (
        'AI 原生搜索引擎，专为大语言模型优化的实时网络搜索服务',
        '请在 Tavily 官网获取 API Key，支持 ?tavilyApiKey= 或 Authorization: Bearer',
      ),
      'Jina AI': (
        '多模态 AI 服务，支持网页内容提取、Embedding 和搜索结果抓取',
        '请在 Jina AI 官网获取 API Key (Bearer Token)',
      ),
      'Firecrawl': (
        '网页抓取与内容提取服务，可将任意网页转为干净的 Markdown 或结构化数据',
        '请在 Firecrawl 官网获取 API Key，也可免 Key 试用（免费版有限额）',
      ),
      'Zhipu': (
        '智谱 AI 开放平台的网页阅读器 MCP 服务，支持网页内容抓取与理解',
        '请在智谱 AI 开放平台获取 API Key (Bearer Token)',
      ),
      'Brave Search': (
        '隐私优先的独立搜索引擎，提供高质量网络搜索结果（需配置 API Key）',
        '请在 Brave Search 官网获取 API Key',
      ),
      'Bocha': (
        '博查 AI 网络搜索服务，提供智能化的中文网页搜索结果',
        '请在博查 AI 开放平台获取 API Key (Bearer Token)',
      ),
      'Querit': (
        'Querit AI 搜索服务，提供智能搜索与内容发现能力',
        '请在 Querit 官网获取 API Key (Bearer Token)',
      ),
      'Searxng': (
        '自托管的元搜索引擎，聚合多种搜索源，注重隐私保护（需自建实例）',
        '设置 SearXNG 实例 URL（如 http://your-instance:8080），可选 API Key',
      ),
    };

    test('localizes all built-in descriptions and setup hints', () async {
      final english = await AppLocalizations.delegate.load(const Locale('en'));
      final chinese = await AppLocalizations.delegate.load(const Locale('zh'));
      final chineseDescriptions = {
        'Exa': chinese.providerPresetExaDescription,
        'Tavily': chinese.providerPresetTavilyDescription,
        'Jina AI': chinese.providerPresetJinaDescription,
        'Firecrawl': chinese.providerPresetFirecrawlDescription,
        'Zhipu': chinese.providerPresetZhipuDescription,
        'Brave Search': chinese.providerPresetBraveSearchDescription,
        'Bocha': chinese.providerPresetBochaDescription,
        'Querit': chinese.providerPresetQueritDescription,
        'Searxng': chinese.providerPresetSearxngDescription,
      };
      final chineseHints = {
        'Exa': chinese.providerPresetExaApiKeyHint,
        'Tavily': chinese.providerPresetTavilyApiKeyHint,
        'Jina AI': chinese.providerPresetJinaApiKeyHint,
        'Firecrawl': chinese.providerPresetFirecrawlApiKeyHint,
        'Zhipu': chinese.providerPresetZhipuApiKeyHint,
        'Brave Search': chinese.providerPresetBraveSearchApiKeyHint,
        'Bocha': chinese.providerPresetBochaApiKeyHint,
        'Querit': chinese.providerPresetQueritApiKeyHint,
        'Searxng': chinese.providerPresetSearxngApiKeyHint,
      };

      expect(presets, hasLength(9));
      for (final entry in presets.entries) {
        final (description, hint) = entry.value;
        final englishDescription = localizedProviderPresetDescription(
          english,
          entry.key,
          description,
          isVendor: true,
        );
        final englishHint = localizedProviderPresetApiKeyHint(
          english,
          entry.key,
          hint,
          isVendor: true,
        );
        expect(englishDescription, isNot(description), reason: entry.key);
        expect(englishHint, isNot(hint), reason: entry.key);
        expect(englishDescription, isNotEmpty, reason: entry.key);
        expect(englishHint, isNotEmpty, reason: entry.key);
        expect(
          localizedProviderPresetDescription(
            chinese,
            entry.key,
            description,
            isVendor: true,
          ),
          chineseDescriptions[entry.key],
          reason: entry.key,
        );
        expect(
          localizedProviderPresetApiKeyHint(
            chinese,
            entry.key,
            hint,
            isVendor: true,
          ),
          chineseHints[entry.key],
          reason: entry.key,
        );
      }
    });

    test('preserves user-authored descriptions and hints verbatim', () async {
      final english = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        localizedProviderPresetDescription(
          english,
          'Exa',
          'My custom notes',
          isVendor: false,
        ),
        'My custom notes',
      );
      expect(
        localizedProviderPresetDescription(
          english,
          'Exa',
          presets['Exa']!.$1,
          isVendor: false,
        ),
        presets['Exa']!.$1,
        reason: 'a custom provider named Exa must keep its own description',
      );
      expect(
        localizedProviderPresetApiKeyHint(
          english,
          'Exa',
          'Use our internal credential vault',
          isVendor: false,
        ),
        'Use our internal credential vault',
      );
      expect(
        localizedProviderPresetApiKeyHint(
          english,
          'Exa',
          presets['Exa']!.$2,
          isVendor: false,
        ),
        presets['Exa']!.$2,
        reason: 'a custom provider named Exa must keep its own hint',
      );
      expect(
        localizedProviderPresetDescription(
          english,
          'Custom Provider',
          'Text',
          isVendor: false,
        ),
        'Text',
      );
    });
  });
}

class _RacingCredentialStore implements LlmCredentialStore {
  final SharedPreferences prefs;
  final String credentialRef;
  final String externalEntries;
  final Map<String, String> values = {};
  var _armed = false;
  var _sourceChanged = false;

  _RacingCredentialStore({
    required this.prefs,
    required this.credentialRef,
    required this.externalEntries,
  });

  void arm() => _armed = true;

  @override
  Future<String?> read(String reference) async {
    if (_armed && !_sourceChanged && reference == credentialRef) return null;
    return values[reference];
  }

  @override
  Future<void> write(String reference, String secret) async {
    if (_armed && !_sourceChanged && reference == credentialRef) {
      _sourceChanged = true;
      await prefs.setString('provider_entries', externalEntries);
    }
    values[reference] = secret;
  }

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }
}
