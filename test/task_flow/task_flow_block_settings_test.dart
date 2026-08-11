import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/widgets/block_editor_dialog.dart';
import 'package:stroom/task_flow/widgets/flow_block_card.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';

class _FakeEntriesNotifier extends ProviderEntriesNotifier {
  _FakeEntriesNotifier(ProviderEntriesState entries) {
    state = entries;
  }
}

class _FakeAssistantsNotifier extends AssistantsNotifier {
  _FakeAssistantsNotifier(List<Assistant> assistants) {
    state = assistants;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPanel(
    WidgetTester tester, {
    required TaskFlowBlock block,
    ProviderEntriesState? entries,
    List<Assistant> assistants = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) =>
                _FakeEntriesNotifier(entries ?? const ProviderEntriesState()),
          ),
          assistantProvider.overrideWith(
            (ref) => _FakeAssistantsNotifier(assistants),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showBlockEditorDialog(context, block: block),
                  child: const Text('打开设置'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();
  }

  ProviderEntriesState _ttsEntries() {
    return ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'tts-1',
          type: 'tts',
          name: 'TTS',
          configs: [
            ProviderConfigItem(
              providerName: 'EdgeTTS',
              host: 'https://example.com',
              key: 'k',
              models: [
                ModelConfig(
                  name: 'edge',
                  modelId: 'edge',
                  voices: [
                    VoiceEntry(name: '晓晓', id: 'zh-CN-XiaoxiaoNeural'),
                    VoiceEntry(name: '云希', id: 'zh-CN-YunxiNeural'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  testWidgets('TTS block panel shows voice dropdown from configured voices',
      (tester) async {
    await pumpPanel(
      tester,
      block: TaskFlowBlock(typeKey: BlockType.tts),
      entries: _ttsEntries(),
    );

    // Panel title
    expect(find.text('语音合成 设置'), findsOneWidget);
    // Voice dropdown present with configured voices
    await tester.tap(find.text('选择音色'));
    await tester.pumpAndSettle();
    expect(find.textContaining('晓晓'), findsOneWidget);
    expect(find.textContaining('云希'), findsOneWidget);

    // Select a voice
    await tester.tap(find.textContaining('晓晓').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
  });

  group('flowFolderSourceFor', () {
    test('text-output blocks (asr/ocr/chat) list the TEXT page folders', () {
      expect(flowFolderSourceFor(BlockType.asr, 'saveFolder'),
          FlowFolderSource.text);
      expect(flowFolderSourceFor(BlockType.ocr, 'saveFolder'),
          FlowFolderSource.text);
      expect(flowFolderSourceFor(BlockType.chat, 'saveFolder'),
          FlowFolderSource.text);
    });

    test('audio-output blocks list the FILE page folders', () {
      expect(flowFolderSourceFor(BlockType.tts, 'saveFolder'),
          FlowFolderSource.file);
      expect(flowFolderSourceFor(BlockType.audioSeparation, 'saveFolder'),
          FlowFolderSource.file);
      expect(flowFolderSourceFor(BlockType.catcatch, 'audioFolder'),
          FlowFolderSource.file);
    });

    test('catcatch video folder lists the VIDEO page folders', () {
      expect(flowFolderSourceFor(BlockType.catcatch, 'videoFolder'),
          FlowFolderSource.video);
    });
  });

  testWidgets(
      'ASR block save-folder picker lists TEXT page folders, not the '
      'audio/file page ones (records must land where the user sees them)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    FileManifest.invalidateCache();
    TextManifest.invalidateCache();
    // A folder that exists ONLY in the text gallery and one that exists
    // ONLY in the file (audio) gallery.
    await TextManifest.addRecord(TextRecord(
      name: '笔记',
      hash: 'txt_dir_hash',
      format: 'txt',
      createdAt: DateTime.now(),
      size: 1,
      folder: 'text_dir',
      textLength: 1,
    ));
    await FileManifest.addRecord(AudioRecord(
      name: '音频',
      hash: 'aud_dir_hash',
      format: 'mp3',
      createdAt: DateTime.now(),
      size: 1,
      folder: 'audio_dir',
    ));

    await pumpPanel(
      tester,
      block: TaskFlowBlock(typeKey: BlockType.asr),
    );

    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();

    expect(find.text('text_dir'), findsOneWidget,
        reason: 'text-output blocks must offer the text page folders');
    expect(find.text('audio_dir'), findsNothing,
        reason: 'audio/page folders do not exist in the text manifest');
  });

  testWidgets('chat block panel shows assistant picker and input note',
      (tester) async {
    final assistants = [
      Assistant(
        id: 'a1',
        name: '翻译助手',
        prompt: '你是翻译',
        emoji: '🌐',
      ),
      Assistant(
        id: 'a2',
        name: '代码助手',
        prompt: '你是代码',
        emoji: '💻',
      ),
    ];
    await pumpPanel(
      tester,
      block: TaskFlowBlock(typeKey: BlockType.chat),
      assistants: assistants,
    );

    // Input note about the user message being the previous step's output.
    expect(find.text('发送给助手的用户消息 = 上一步的输出'), findsOneWidget);
    // The 开头提示语 param is gone — the block sends the previous step
    // verbatim as role:user, no prefix editing.
    expect(find.text('开头提示语'), findsNothing);
    // The field shows 未指定（使用当前选中的助手） — no built-in default.
    expect(find.text('未指定（使用当前选中的助手）'), findsOneWidget);
    // Tapping the field opens the picker panel with ONLY the user's
    // assistants — built-in prompts are not offered on blocks.
    await tester.tap(find.text('未指定（使用当前选中的助手）'));
    await tester.pumpAndSettle();
    expect(find.text('内置助手'), findsNothing);
    expect(find.textContaining('通用助手'), findsNothing);
    expect(find.text('我的助手'), findsOneWidget);
    expect(find.textContaining('翻译助手'), findsOneWidget);
    expect(find.textContaining('代码助手'), findsOneWidget);
  });

  ProviderEntriesState _asrEntries() {
    return ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'asr-1',
          type: 'asr',
          name: 'ASR',
          configs: [
            ProviderConfigItem(
              providerName: 'OpenAI',
              host: 'https://api.openai.com',
              key: 'k',
              models: [
                ModelConfig(name: 'whisper-1', modelId: 'whisper-1'),
                ModelConfig(name: 'whisper-large', modelId: 'whisper-large'),
              ],
            ),
            ProviderConfigItem(
              providerName: 'Groq',
              host: 'https://api.groq.com',
              key: 'k',
              models: [
                ModelConfig(name: 'distil-whisper', modelId: 'distil-whisper'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  testWidgets(
      'ASR block panel lists MODELS as "modelName | providerName" '
      '(same granularity as the ASR page)', (tester) async {
    await pumpPanel(
      tester,
      block: TaskFlowBlock(typeKey: BlockType.asr),
      entries: _asrEntries(),
    );

    // All three models across both configs are selectable.
    await tester.tap(find.text('whisper-1 | OpenAI'));
    await tester.pumpAndSettle();
    expect(find.text('whisper-large | OpenAI'), findsOneWidget);
    expect(find.text('distil-whisper | Groq'), findsOneWidget);

    // Select a model from the second provider.
    await tester.tap(find.text('distil-whisper | Groq').last);
    await tester.pumpAndSettle();
    expect(find.text('distil-whisper | Groq'), findsOneWidget);
  });

  testWidgets(
      'ASR panel excludes models of configs without host/key '
      '(index alignment with the executor)', (tester) async {
    final entries = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'asr-1',
          type: 'asr',
          name: 'ASR',
          configs: [
            ProviderConfigItem(
              providerName: 'OpenAI',
              host: 'https://api.openai.com',
              key: 'k',
              models: [
                ModelConfig(name: 'whisper-1', modelId: 'whisper-1'),
              ],
            ),
            // Empty host/key — its model must NOT appear in the panel
            // (the executor and the ASR page skip it too; including it
            // would shift the selected index to a different model).
            ProviderConfigItem(
              providerName: '未配置',
              host: '',
              key: '',
              models: [
                ModelConfig(name: 'ghost-model', modelId: 'ghost'),
              ],
            ),
            ProviderConfigItem(
              providerName: 'Groq',
              host: 'https://api.groq.com',
              key: 'k',
              models: [
                ModelConfig(name: 'distil-whisper', modelId: 'distil-whisper'),
              ],
            ),
          ],
        ),
      ],
    );
    await pumpPanel(
      tester,
      block: TaskFlowBlock(typeKey: BlockType.asr),
      entries: entries,
    );

    // Only the two valid configs' models are listed (the field shows the
    // selected one; the ghost config's model is absent everywhere).
    expect(find.text('whisper-1 | OpenAI'), findsOneWidget);
    expect(find.textContaining('ghost-model'), findsNothing);
    // Index 1 in the panel == index 1 in the executor's flattened list:
    // opening the dropdown lists distil-whisper at the same index the
    // executor resolves for modelIndex 1.
    await tester.tap(find.text('whisper-1 | OpenAI'));
    await tester.pumpAndSettle();
    expect(find.text('distil-whisper | Groq'), findsOneWidget);
  });

  testWidgets(
      'chat panel with a DELETED assistant id shows the warning line '
      '(no crash, re-selection works)', (tester) async {
    await pumpPanel(
      tester,
      block: TaskFlowBlock(
        typeKey: BlockType.chat,
        params: {'assistantId': 'deleted-id'},
      ),
      assistants: [
        Assistant(id: 'a1', name: '现存助手', prompt: 'p'),
      ],
    );

    // The stale id resolves to nothing — the warning line guides
    // re-selection via the picker panel.
    expect(find.text('助手不存在'), findsOneWidget);
    expect(find.text('配置的助手已删除，请重新选择'), findsOneWidget);
    await tester.tap(find.text('助手不存在'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('现存助手'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('现存助手'), findsOneWidget);

    // Re-selecting a valid assistant clears the warning.
    await tester.tap(find.textContaining('现存助手').last);
    await tester.pumpAndSettle();
    expect(find.text('配置的助手已删除，请重新选择'), findsNothing);
  });

  testWidgets('new chat block defaults to 未指定 (follows current assistant)',
      (tester) async {
    await pumpPanel(
      tester,
      block: TaskFlowBlock(typeKey: BlockType.chat),
      assistants: const [],
    );

    // No built-in default — the field guides toward the current
    // assistant instead of showing a built-in preset name.
    expect(find.text('未指定（使用当前选中的助手）'), findsOneWidget);
    expect(find.textContaining('通用助手'), findsNothing);
  });

  testWidgets(
      'TTS panel with a stale voice id shows 音色已失效 (never the '
      'raw id string)', (tester) async {
    final entries = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'tts-1',
          type: 'tts',
          name: 'TTS',
          configs: [
            ProviderConfigItem(
              providerName: 'EdgeTTS',
              host: 'https://example.com',
              key: 'k',
              models: [
                ModelConfig(
                  name: 'edge-a',
                  modelId: 'edge-a',
                  voices: [
                    VoiceEntry(name: '晓晓', id: 'zh-CN-XiaoxiaoNeural'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await pumpPanel(
      tester,
      block: TaskFlowBlock(
        typeKey: BlockType.tts,
        // A voice that no longer exists in the configured model.
        params: {'voice': 'deleted-voice-id'},
      ),
      entries: entries,
    );

    // The hint guides re-selection; the raw id must not appear.
    expect(find.text('音色已失效，请重新选择'), findsOneWidget);
    expect(find.text('deleted-voice-id'), findsNothing);
  });

  testWidgets('block card shows friendly param names, not raw ids',
      (tester) async {
    final entries = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'tts-1',
          type: 'tts',
          name: 'TTS',
          configs: [
            ProviderConfigItem(
              providerName: 'EdgeTTS',
              host: 'https://example.com',
              key: 'k',
              models: [
                ModelConfig(
                  name: 'edge-a',
                  modelId: 'edge-a',
                  voices: [
                    VoiceEntry(name: '晓晓', id: 'zh-CN-XiaoxiaoNeural'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => _FakeEntriesNotifier(entries),
          ),
          assistantProvider.overrideWith(
            (ref) => _FakeAssistantsNotifier([
              Assistant(id: 'a1', name: '翻译助手', prompt: 'p', emoji: '🌐'),
            ]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FlowBlockCard(
                  block: TaskFlowBlock(
                    typeKey: BlockType.tts,
                    params: {'voice': 'zh-CN-XiaoxiaoNeural'},
                  ),
                  index: 1,
                ),
                FlowBlockCard(
                  block: TaskFlowBlock(
                    typeKey: BlockType.chat,
                    params: {'assistantId': 'a1'},
                  ),
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Friendly names, never raw ids.
    expect(find.text('语音: 晓晓'), findsOneWidget);
    expect(find.textContaining('zh-CN-XiaoxiaoNeural'), findsNothing);
    expect(find.text('助手: 🌐 翻译助手'), findsOneWidget);
    expect(find.textContaining('a1'), findsNothing);
  });

  testWidgets(
      'block card shows the save folder even when it is the root folder '
      '(empty value → 根目录, not hidden)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => _FakeEntriesNotifier(_asrEntries()),
          ),
          assistantProvider.overrideWith(
            (ref) => _FakeAssistantsNotifier(const []),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FlowBlockCard(
                  block: TaskFlowBlock(
                    typeKey: BlockType.asr,
                    params: {'saveFolder': ''},
                  ),
                  index: 1,
                ),
                FlowBlockCard(
                  block: TaskFlowBlock(
                    typeKey: BlockType.asr,
                    params: {'saveFolder': 'records/会议'},
                  ),
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Root folder must appear (it was previously filtered as "default").
    expect(find.text('保存文件夹: 根目录'), findsOneWidget);
    expect(find.text('保存文件夹: records/会议'), findsOneWidget);
  });

  testWidgets(
      'block card shows the MODEL name for modelSelector params '
      '(no raw index)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => _FakeEntriesNotifier(_asrEntries()),
          ),
          assistantProvider.overrideWith(
            (ref) => _FakeAssistantsNotifier(const []),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: FlowBlockCard(
              block: TaskFlowBlock(
                typeKey: BlockType.asr,
                params: {'modelIndex': 1},
              ),
              index: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Index 1 = whisper-large | OpenAI in the shared flattened list.
    expect(find.text('识别模型: whisper-large | OpenAI'), findsOneWidget);
    expect(find.textContaining('modelIndex'), findsNothing);
  });

  testWidgets('TTS voice dropdown follows the selected model', (tester) async {
    final entries = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'tts-1',
          type: 'tts',
          name: 'TTS',
          configs: [
            ProviderConfigItem(
              providerName: 'EdgeTTS',
              host: 'https://example.com',
              key: 'k',
              models: [
                ModelConfig(
                  name: 'edge-a',
                  modelId: 'edge-a',
                  voices: [
                    VoiceEntry(name: '晓晓', id: 'zh-CN-XiaoxiaoNeural'),
                  ],
                ),
                ModelConfig(
                  name: 'edge-b',
                  modelId: 'edge-b',
                  voices: [
                    VoiceEntry(name: '云希', id: 'zh-CN-YunxiNeural'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await pumpPanel(
      tester,
      block: TaskFlowBlock(typeKey: BlockType.tts),
      entries: entries,
    );

    // Default model (index 0) → open the voice dropdown: only 晓晓.
    await tester.tap(find.text('选择音色'));
    await tester.pumpAndSettle();
    expect(find.textContaining('晓晓'), findsOneWidget);
    expect(find.textContaining('云希'), findsNothing);
    // Close the voice menu by tapping outside.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Switch 合成模型 to edge-b → the voice dropdown lists 云希.
    await tester.tap(find.text('edge-a | EdgeTTS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('edge-b | EdgeTTS').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择音色'));
    await tester.pumpAndSettle();
    expect(find.textContaining('云希'), findsOneWidget);
    expect(find.textContaining('晓晓'), findsNothing);
  });

  testWidgets(
      'a stale voice (not in the selected model) resets on confirm '
      '(no invalid id survives)', (tester) async {
    TaskFlowBlock? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => _FakeEntriesNotifier(_ttsEntries()),
          ),
          assistantProvider.overrideWith(
            (ref) => _FakeAssistantsNotifier(const []),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showBlockEditorDialog(
                      context,
                      block: TaskFlowBlock(
                        typeKey: BlockType.tts,
                        params: {'voice': 'deleted-voice'},
                      ),
                    );
                  },
                  child: const Text('打开设置'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();

    // The stale voice shows the 音色已失效 hint; confirming resets it.
    expect(find.text('音色已失效，请重新选择'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.params['voice'], '',
        reason: 'a stale voice must reset to the model default, not '
            'survive confirm');
  });

  testWidgets('manual voice fallback keeps typed input across rebuilds',
      (tester) async {
    // A TTS config whose model has NO voices → the panel shows the manual
    // TextField; a typed id must survive unrelated rebuilds and confirm.
    final entries = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'tts-1',
          type: 'tts',
          name: 'TTS',
          configs: [
            ProviderConfigItem(
              providerName: 'CustomTTS',
              host: 'https://example.com',
              key: 'k',
              models: [
                ModelConfig(name: 'custom', modelId: 'custom'),
              ],
            ),
          ],
        ),
      ],
    );
    TaskFlowBlock? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => _FakeEntriesNotifier(entries),
          ),
          assistantProvider.overrideWith(
            (ref) => _FakeAssistantsNotifier(const []),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showBlockEditorDialog(
                      context,
                      block: TaskFlowBlock(typeKey: BlockType.tts),
                    );
                  },
                  child: const Text('打开设置'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();

    // Manual fallback field with the hint.
    expect(find.text('未配置TTS音色，可手动输入ID'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      'custom-voice-id',
    );
    await tester.pumpAndSettle();

    // Confirm — the typed id must survive (no unrelated rebuild wipes it).
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.params['voice'], 'custom-voice-id');
  });

  testWidgets(
      'TTS panel with duplicate voice ids within one model does not '
      'crash (deduped dropdown)', (tester) async {
    final entries = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'tts-1',
          type: 'tts',
          name: 'TTS',
          configs: [
            ProviderConfigItem(
              providerName: 'EdgeTTS',
              host: 'https://example.com',
              key: 'k',
              models: [
                ModelConfig(
                  name: 'edge-a',
                  modelId: 'edge-a',
                  voices: [
                    VoiceEntry(name: '晓晓', id: 'shared-voice'),
                    VoiceEntry(name: '晓晓（备选）', id: 'shared-voice'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await pumpPanel(
      tester,
      block: TaskFlowBlock(
        typeKey: BlockType.tts,
        params: {'voice': 'shared-voice'},
      ),
      entries: entries,
    );

    // The dropdown renders with the persisted voice selected (exactly one
    // matching item after dedup) — no debug assert.
    expect(find.textContaining('晓晓'), findsOneWidget);
  });
}
