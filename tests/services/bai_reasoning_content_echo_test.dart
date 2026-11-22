import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/bai_reasoning_content_echo.dart';

void main() {
  const sourceModelId = 'deepseek-reasoner';

  List<Map<String, dynamic>> echo(
    List<Map<String, dynamic>> messages, {
    String providerPresetId = 'bai',
    String providerId = 'openai-compatibility',
    String protocolId = 'openai.chat_completions',
    String modelId = sourceModelId,
  }) =>
      prepareBaiDeepSeekReasoningContentEcho(
        messages: messages,
        originalMessages: messages,
        providerId: providerId,
        providerPresetId: providerPresetId,
        protocolId: protocolId,
        modelId: modelId,
      );

  test('preserves authentic reasoning_content exactly', () {
    const authenticReasoning = '  source-returned reasoning\n ';
    final messages = <Map<String, dynamic>>[
      {
        'role': 'assistant',
        'content': 'answer',
        'reasoning_content': authenticReasoning
      },
    ];

    final result = echo(messages);

    expect(result.single['reasoning_content'], authenticReasoning);
    expect(messages.single['reasoning_content'], authenticReasoning);

    final replaySanitized = <Map<String, dynamic>>[
      {'role': 'assistant', 'content': 'answer'},
    ];
    final preserved = prepareBaiDeepSeekReasoningContentEcho(
      messages: replaySanitized,
      originalMessages: messages,
      providerId: 'openai-compatibility',
      providerPresetId: 'bai',
      protocolId: 'openai.chat_completions',
      modelId: sourceModelId,
    );
    expect(preserved.single['reasoning_content'], authenticReasoning);
  });

  test('preserves the reasoning alias without adding a duplicate field', () {
    final messages = <Map<String, dynamic>>[
      {
        'role': 'assistant',
        'content': 'answer',
        'reasoning': 'source reasoning'
      },
    ];

    final result = echo(messages);

    expect(result.single['reasoning'], 'source reasoning');
    expect(result.single.containsKey('reasoning_content'), isFalse);
  });

  test('adds a single-space structural marker to assistant history only', () {
    final userMessage = {'role': 'user', 'content': 'question'};
    final toolMessage = {'role': 'tool', 'content': 'tool result'};
    final assistantMessage = {
      'role': 'assistant',
      'content': 'answer',
      'custom': {'preserved': true},
    };
    final messages = <Map<String, dynamic>>[
      userMessage,
      assistantMessage,
      toolMessage,
    ];

    final result = echo(messages);

    expect(result[0], same(userMessage));
    expect(result[1]['reasoning_content'], ' ');
    expect(result[1]['custom'], {'preserved': true});
    expect(result[2], same(toolMessage));
    expect(assistantMessage.containsKey('reasoning_content'), isFalse);
  });

  test('does not inject for unrelated providers, protocols, or models', () {
    final assistantMessage = {'role': 'assistant', 'content': 'answer'};

    for (final result in [
      echo([assistantMessage], providerPresetId: 'other-provider'),
      echo([assistantMessage], protocolId: 'openai.responses'),
      echo([assistantMessage], modelId: 'deepseek-chat'),
      echo([assistantMessage], modelId: 'kimi-k2-thinking'),
    ]) {
      expect(result.single.containsKey('reasoning_content'), isFalse);
    }
  });

  test(
      'recognizes the source-listed b.ai DeepSeek Reasoner model case-insensitively',
      () {
    final result = echo(
      [
        <String, dynamic>{'role': 'assistant', 'content': 'answer'}
      ],
      modelId: 'DeepSeek-Reasoner',
    );

    expect(result.single['reasoning_content'], ' ');
  });
}
