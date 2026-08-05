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

  testWidgets('chat block panel shows assistant dropdown and input note',
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
    expect(find.textContaining('上一步的输出'), findsOneWidget);
    // Assistant dropdown lists the user-defined assistants.
    await tester.tap(
      find.byType(DropdownButtonFormField<String?>),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('翻译助手'), findsOneWidget);
    expect(find.textContaining('代码助手'), findsOneWidget);
  });

  testWidgets(
      'chat panel with a DELETED assistant id does not crash '
      '(hint guides re-selection)', (tester) async {
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

    // Panel renders without a debug assert (the stale id must not be
    // passed as the dropdown value — no matching item would crash);
    // the dropdown still opens and lists the existing assistant.
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    expect(find.textContaining('现存助手'), findsOneWidget);
  });

  testWidgets(
      'TTS panel with duplicate voice ids across models does not '
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
                  ],
                ),
                ModelConfig(
                  name: 'edge-b',
                  modelId: 'edge-b',
                  voices: [
                    VoiceEntry(name: '晓晓', id: 'shared-voice'),
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
