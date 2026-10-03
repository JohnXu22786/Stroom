// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_stream_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stream setup resolves its assistant model from the supplied snapshot',
      () async {
    final original = ModelConfig(name: 'Original', modelId: 'original-model');
    final config = ProviderConfigItem(
      providerName: 'Provider',
      host: 'https://example.invalid',
      key: 'test-key',
      models: [original],
    );
    final snapshot = ProviderEntriesState(
      entries: [
        ProviderEntry(name: 'LLM', type: 'llm', configs: [config]),
      ],
    );
    final assistant = Assistant(
      id: 'assistant',
      name: 'Assistant',
      prompt: 'Original prompt',
      defaultModelId: original.modelId,
      defaultProviderName: config.providerName,
    );
    final manager = ChatStreamManager();
    addTearDown(manager.dispose);
    final pending = manager.startStreaming(
      text: 'Summarize',
      convId: 'flow-snapshot',
      history: [ChatMessage(role: 'user', content: 'Summarize')],
      assistant: assistant,
      entriesStateOverride: snapshot,
    );
    // Setup occurs synchronously before compaction/streaming yields. Cancel
    // before the stream starts: this regression never makes a network request.
    final service = manager.adapter.currentChatService;
    manager.cancel('flow-snapshot');
    expect(service?.modelConfig?.modelId, 'original-model');
    expect((await pending).cancelled, true);
  });
}
