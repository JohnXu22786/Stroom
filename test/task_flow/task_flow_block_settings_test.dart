import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifier;
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/widgets/block_editor_dialog.dart';

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
    // The field shows the default built-in assistant by name.
    expect(find.textContaining('通用助手'), findsOneWidget);
    // Tapping the field opens the picker panel with built-in AND
    // user-defined assistants.
    await tester.tap(find.textContaining('通用助手'));
    await tester.pumpAndSettle();
    expect(find.text('内置助手'), findsOneWidget);
    expect(find.textContaining('通用助手'), findsWidgets);
    // The user-defined section is below the fold — scroll to it.
    await tester.scrollUntilVisible(
      find.text('我的助手'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
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

  testWidgets('new chat block defaults to the first built-in assistant',
      (tester) async {
    await pumpPanel(
      tester,
      block: TaskFlowBlock(typeKey: BlockType.chat),
      assistants: const [],
    );

    // The picker field shows the default built-in assistant by name
    // (not a confusing placeholder).
    expect(find.textContaining('通用助手'), findsOneWidget);
    expect(find.text('（使用当前选中的助手）'), findsNothing);
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
