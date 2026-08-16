import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/pages/model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/widgets/block_editor_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderEntriesState ttsEntries() {
    return ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'tts-1',
          type: 'tts',
          name: 'TTS供应商',
          configs: [
            ProviderConfigItem(
              providerName: 'EdgeTTS',
              host: 'https://example.com',
              key: 'k',
              // Provider-level data that ModelConfigPage._save must NOT
              // drop when it rebuilds the config (regression guard).
              typeConfig: const {'temperature': 0.7},
              customParams: [
                CustomParam(paramName: 'style', defaultValue: 'calm'),
              ],
              reasoningParams: [
                ReasoningParam(paramName: 'effort', options: ['low']),
              ],
              endpointType: 'anthropic',
              models: [
                ModelConfig(
                  name: 'edge',
                  modelId: 'edge',
                  maxWordsPerRequest: 1000,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  testWidgets(
      'voices saved on a model via the model config page appear in the '
      'provider state and in the flow block voice dropdown', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        providerEntriesProvider.overrideWith(
          (ref) => ProviderEntriesNotifier()..state = ttsEntries(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // 1. Open the model config page for a NEW model in the existing
    //    config (configIndex 0, modelIndex -1) and add a voice through
    //    the VoiceEditorPage.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ModelConfigPage(
            entryId: 'tts-1',
            configIndex: 0,
            modelIndex: -1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Fill the required form fields first (模型名称, 模型ID, 单次最长音频字数).
    final formFields = find.byType(TextField);
    expect(formFields,
        findsNWidgets(7)); // name, modelId, vol min/max, spd min/max, maxWords
    await tester.enterText(formFields.at(0), 'edge-2');
    await tester.enterText(formFields.at(1), 'edge-2');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, '单次最长音频字数 *'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(formFields.at(6), '1000');

    // Tap the 音色 entry card to open the voice editor.
    await tester.scrollUntilVisible(
      find.textContaining('音色 (0)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.textContaining('音色 (0)'));
    await tester.pumpAndSettle();
    expect(find.text('音色编辑'), findsOneWidget);

    // Add one voice row, fill name + id, save.
    await tester.tap(find.text('添加一行'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '晓晓');
    await tester.enterText(fields.at(1), 'zh-CN-XiaoxiaoNeural');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // Back on the model config page: the card now shows the voice.
    expect(find.textContaining('音色 (1)'), findsOneWidget);

    // Save the model.
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 2. The persisted provider state must contain the voice — and the
    //    provider-level config fields must survive the model save.
    final entries = container.read(providerEntriesProvider).entries;
    final config = entries.first.configs.first;
    final model = config.models.first;
    expect(model.voices.length, 1);
    expect(model.voices.first.name, '晓晓');
    expect(model.voices.first.id, 'zh-CN-XiaoxiaoNeural');
    expect(config.typeConfig['temperature'], 0.7);
    expect(config.customParams.length, 1);
    expect(config.reasoningParams.length, 1);
    expect(config.endpointType, 'anthropic');

    // 3. The flow block editor must list the voice.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: UniqueKey(), // fresh Navigator — the previous one was popped
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showBlockEditorDialog(
                    context,
                    block: TaskFlowBlock(typeKey: BlockType.tts),
                  ),
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

    // The voice dropdown must offer the saved voice — NOT the
    // 所有TTS模型均未配置音色 manual-input fallback.
    expect(find.text('所有TTS模型均未配置音色，可手动输入ID'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('晓晓'), findsOneWidget);
  });

  testWidgets(
      'voices added to an EXISTING model via the model config page '
      'persist and reach the block voice dropdown', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        providerEntriesProvider.overrideWith(
          (ref) => ProviderEntriesNotifier()..state = ttsEntries(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Edit the existing model (modelIndex 0): open the model config page,
    // add a voice through the VoiceEditorPage, save.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ModelConfigPage(
            entryId: 'tts-1',
            configIndex: 0,
            modelIndex: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('音色 (0)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.textContaining('音色 (0)'));
    await tester.pumpAndSettle();
    expect(find.text('音色编辑'), findsOneWidget);

    await tester.tap(find.text('添加一行'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '云希');
    await tester.enterText(fields.at(1), 'zh-CN-YunxiNeural');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('音色 (1)'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // The persisted model must carry the voice.
    final model = container
        .read(providerEntriesProvider)
        .entries
        .first
        .configs
        .first
        .models
        .first;
    expect(model.voices.length, 1);
    expect(model.voices.first.name, '云希');

    // And the block editor must offer it.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: UniqueKey(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showBlockEditorDialog(
                    context,
                    block: TaskFlowBlock(typeKey: BlockType.tts),
                  ),
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

    expect(find.text('所有TTS模型均未配置音色，可手动输入ID'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('云希'), findsOneWidget);
  });

  testWidgets('voices survive an app restart (prefs round-trip)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // First "session": seed a TTS entry with a model carrying voices via
    // the REAL notifier so _persist writes them to prefs.
    final notifier = ProviderEntriesNotifier()..state = ttsEntries();
    final seeded = notifier.state;
    await notifier.update(
      'tts-1',
      ProviderEntry(
        id: seeded.entries.first.id,
        type: seeded.entries.first.type,
        name: seeded.entries.first.name,
        configs: seeded.entries.first.configs,
      ),
    );
    // The model has no voices yet — simulate the user's save by writing
    // the voice through the notifier exactly like ModelConfigPage._save.
    final entries = notifier.state.entries;
    final config = entries.first.configs.first;
    final model = config.models.first.copy()
      ..voices = [VoiceEntry(name: '晓晓', id: 'zh-CN-XiaoxiaoNeural')];
    await notifier.update(
      'tts-1',
      ProviderEntry(
        id: entries.first.id,
        type: entries.first.type,
        name: entries.first.name,
        configs: [
          ProviderConfigItem(
            providerName: config.providerName,
            host: config.host,
            key: config.key,
            models: [model],
          ),
        ],
      ),
    );

    // Second "session": fresh notifier, load from prefs.
    final reloaded = ProviderEntriesNotifier();
    await reloaded.load();
    final container = ProviderContainer(
      overrides: [
        providerEntriesProvider.overrideWith((ref) => reloaded),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showBlockEditorDialog(
                    context,
                    block: TaskFlowBlock(typeKey: BlockType.tts),
                  ),
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

    expect(find.text('所有TTS模型均未配置音色，可手动输入ID'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('晓晓'), findsOneWidget);
  });

  testWidgets(
      'block editor opened while the provider is still loading updates '
      'in place once entries arrive (no stale 未配置 fallback)', (
    tester,
  ) async {
    final notifier = ProviderEntriesNotifier()
      ..state = const ProviderEntriesState();
    final container = ProviderContainer(
      overrides: [
        providerEntriesProvider.overrideWith((ref) => notifier),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showBlockEditorDialog(
                    context,
                    block: TaskFlowBlock(typeKey: BlockType.tts),
                  ),
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

    // Provider still empty → the manual fallback is shown.
    expect(find.text('所有TTS模型均未配置音色，可手动输入ID'), findsOneWidget);

    // The provider finishes loading: TTS entry with a model carrying a voice.
    notifier.state = ProviderEntriesState(
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
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    // The open sheet must now offer the voice — not the fallback hint.
    // Bounded retry: the sheet rebuild happens on a scheduled frame; a
    // tight loop keeps the assertion robust against scheduling hiccups.
    for (var i = 0; i < 20; i++) {
      if (find.text('所有TTS模型均未配置音色，可手动输入ID').evaluate().isEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('所有TTS模型均未配置音色，可手动输入ID'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('晓晓'), findsOneWidget);
  });

  testWidgets(
      'an out-of-range modelIndex is clamped into the loaded models on '
      'confirm (late-load panel cannot persist a bad index)', (tester) async {
    final notifier = ProviderEntriesNotifier()
      ..state = const ProviderEntriesState();
    final container = ProviderContainer(
      overrides: [
        providerEntriesProvider.overrideWith((ref) => notifier),
      ],
    );
    addTearDown(container.dispose);

    TaskFlowBlock? result;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
                        params: {'modelIndex': 5},
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

    // Provider loads AFTER the panel opened: one TTS model with a voice.
    notifier.state = ProviderEntriesState(
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
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    // Confirm without touching the dropdowns: the persisted index must be
    // the clamped 0 — a raw 5 would fail at execution.
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.params['modelIndex'], 0);
  });
}
