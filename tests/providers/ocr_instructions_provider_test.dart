import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/ocr_instructions_provider.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderEntry _ocrEntryWithInstructions(
    List<Map<String, dynamic>> instructions,
  ) {
    return ProviderEntry(
      id: 'test_ocr',
      type: 'ocr',
      name: 'OCR供应商',
      configs: [
        ProviderConfigItem(
          providerName: 'OpenAI',
          host: 'https://api.openai.com',
          key: 'test-key',
          models: [
            ModelConfig(
              name: 'GPT-4o',
              modelId: 'gpt-4o',
              typeConfig: {'userInstructions': instructions},
            ),
          ],
        ),
      ],
    );
  }

  ProviderContainer _containerWithEntries(List<ProviderEntry> entries) {
    return ProviderContainer(
      overrides: [
        providerEntriesProvider.overrideWith((ref) {
          final notifier = ProviderEntriesNotifier();
          notifier.state = ProviderEntriesState(entries: entries);
          return notifier;
        }),
      ],
    );
  }

  group('migrateLegacyOcrInstructions', () {
    test('migrates the first OCR model with a userInstructions list', () {
      final result = migrateLegacyOcrInstructions([
        _ocrEntryWithInstructions([
          {'name': '发票', 'content': '提取发票号码和金额'},
          {'name': '', 'content': '提取表格内容'},
        ]),
        _ocrEntryWithInstructions([
          {'name': '第二模型', 'content': '不会被取用'},
        ]),
      ]);

      expect(result, const [
        OcrInstruction(name: '发票', content: '提取发票号码和金额'),
        OcrInstruction(content: '提取表格内容'),
      ]);
    });

    test('migrates legacy single-string userInstruction', () {
      final entry = ProviderEntry(
        id: 'test_ocr',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'OpenAI',
            host: 'https://api.openai.com',
            key: 'k',
            models: [
              ModelConfig(
                name: 'M',
                modelId: 'm',
                typeConfig: {'userInstruction': '  旧指令内容  '},
              ),
            ],
          ),
        ],
      );

      expect(migrateLegacyOcrInstructions([entry]), const [
        OcrInstruction(content: '旧指令内容'),
      ]);
    });

    test('drops blank-content and trims entries', () {
      final result = migrateLegacyOcrInstructions([
        _ocrEntryWithInstructions([
          {'name': '空白', 'content': '   \n\n '},
          {'name': ' 名称 ', 'content': ' 内容 '},
        ]),
      ]);

      expect(result, const [OcrInstruction(name: '名称', content: '内容')]);
    });

    test('returns empty when no OCR model has instructions', () {
      expect(migrateLegacyOcrInstructions([]), isEmpty);
      expect(
        migrateLegacyOcrInstructions([
          ProviderEntry(
            id: 'test_ocr',
            type: 'ocr',
            name: 'OCR供应商',
            configs: [
              ProviderConfigItem(
                providerName: 'OpenAI',
                host: 'https://api.openai.com',
                key: 'k',
                models: [ModelConfig(name: 'M', modelId: 'm')],
              ),
            ],
          ),
        ]),
        isEmpty,
      );
    });

    test('ignores non-OCR entries', () {
      final result = migrateLegacyOcrInstructions([
        ProviderEntry(
          id: 'test_llm',
          type: 'llm',
          name: 'LLM供应商',
          configs: [
            ProviderConfigItem(
              providerName: 'X',
              host: 'h',
              key: 'k',
              models: [
                ModelConfig(
                  name: 'M',
                  modelId: 'm',
                  typeConfig: {
                    'userInstructions': [
                      {'name': '指令', 'content': '内容'},
                    ]
                  },
                ),
              ],
            ),
          ],
        ),
      ]);
      expect(result, isEmpty);
    });
  });

  group('OcrInstructionsNotifier', () {
    test('loads empty when nothing is stored', () async {
      final container = _containerWithEntries([]);
      await container.read(ocrInstructionsProvider.notifier).load();
      expect(container.read(ocrInstructionsProvider), isEmpty);
      container.dispose();
    });

    test('add / update / remove mutate the list', () async {
      final container = _containerWithEntries([]);
      final notifier = container.read(ocrInstructionsProvider.notifier);
      await notifier.load();

      await notifier.add('发票', '提取发票号码');
      await notifier.add('', '提取表格内容');
      expect(container.read(ocrInstructionsProvider), const [
        OcrInstruction(name: '发票', content: '提取发票号码'),
        OcrInstruction(content: '提取表格内容'),
      ]);

      await notifier.update(0, '发票更新', '提取发票金额');
      expect(container.read(ocrInstructionsProvider).first,
          const OcrInstruction(name: '发票更新', content: '提取发票金额'));

      await notifier.remove(1);
      expect(container.read(ocrInstructionsProvider), const [
        OcrInstruction(name: '发票更新', content: '提取发票金额'),
      ]);
      container.dispose();
    });

    test('blank-content add is ignored', () async {
      final container = _containerWithEntries([]);
      final notifier = container.read(ocrInstructionsProvider.notifier);
      await notifier.add('空', '   \n\n  ');
      expect(container.read(ocrInstructionsProvider), isEmpty);
      container.dispose();
    });

    test('mutations persist and reload in a fresh notifier', () async {
      final container = _containerWithEntries([]);
      final notifier = container.read(ocrInstructionsProvider.notifier);
      await notifier.load();
      await notifier.add('发票', '提取发票号码');
      container.dispose();

      // A brand-new provider scope reads the stored list back.
      final container2 = _containerWithEntries([]);
      await container2.read(ocrInstructionsProvider.notifier).load();
      expect(container2.read(ocrInstructionsProvider), const [
        OcrInstruction(name: '发票', content: '提取发票号码'),
      ]);
      container2.dispose();
    });

    test('loads stored list and drops blank-content entries', () async {
      SharedPreferences.setMockInitialValues({
        'ocr_instructions': jsonEncode([
          {'name': '发票', 'content': '提取发票号码'},
          {'name': '空白', 'content': '  '},
        ]),
      });
      final container = _containerWithEntries([]);
      await container.read(ocrInstructionsProvider.notifier).load();
      expect(container.read(ocrInstructionsProvider), const [
        OcrInstruction(name: '发票', content: '提取发票号码'),
      ]);
      container.dispose();
    });

    test('seeds from legacy per-model instructions when store is empty',
        () async {
      final container = _containerWithEntries([
        _ocrEntryWithInstructions([
          {'name': '发票', 'content': '提取发票号码和金额'},
        ]),
      ]);
      await container.read(ocrInstructionsProvider.notifier).load();
      expect(container.read(ocrInstructionsProvider), const [
        OcrInstruction(name: '发票', content: '提取发票号码和金额'),
      ]);
      container.dispose();
    });

    test('does not re-migrate once the store has been written', () async {
      final container = _containerWithEntries([
        _ocrEntryWithInstructions([
          {'name': '发票', 'content': '提取发票号码和金额'},
        ]),
      ]);
      final notifier = container.read(ocrInstructionsProvider.notifier);
      await notifier.load();
      // User edits the list — now the store is non-empty.
      await notifier.remove(0);
      container.dispose();

      // Even though the legacy model instructions still exist, a fresh
      // load reads the (now empty) store and must NOT resurrect them.
      final container2 = _containerWithEntries([
        _ocrEntryWithInstructions([
          {'name': '发票', 'content': '提取发票号码和金额'},
        ]),
      ]);
      await container2.read(ocrInstructionsProvider.notifier).load();
      expect(container2.read(ocrInstructionsProvider), isEmpty);
      container2.dispose();
    });
  });
}
