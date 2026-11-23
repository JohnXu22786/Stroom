import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/models/tts_models.dart' show ModelConfig;
import 'package:stroom/providers/chat_api_shared.dart';
import 'package:stroom/services/chat_protocol.dart';
import 'package:stroom/services/chat_service.dart';

void main() {
  group('ChatService cancellation during protocol construction', () {
    test(
      'sendStream does not start a cancelled build after a replacement starts',
      () async {
        final protocol = _DelayedFirstBuildProtocol();
        final provider = _CountingProvider();
        final service = ChatService(
          provider: provider,
          modelConfig: _modelConfig,
          protocol: protocol,
        );

        final cancelledStream = service.sendStream('cancelled', history: []);
        final cancelledDone = cancelledStream.drain<void>();
        await protocol.firstBuildStarted.future;

        service.cancel();
        final replacementDone =
            service.sendStream('replacement', history: []).drain<void>();
        await provider.firstCall.future;

        protocol.firstBuild.complete(_request);
        await cancelledDone;
        await replacementDone;

        expect(provider.callCount, 1);
      },
    );

    test(
      'sendPrompt does not start a request when canceled during protocol build',
      () async {
        final protocol = _DelayedFirstBuildProtocol();
        final provider = _CountingProvider();
        final service = ChatService(
          provider: provider,
          modelConfig: _modelConfig,
          protocol: protocol,
        );

        final response = service.sendPrompt(
          systemPrompt: 'system',
          history: const [],
        );
        await protocol.firstBuildStarted.future;

        service.cancel();
        protocol.firstBuild.complete(_request);

        expect(await response, isEmpty);
        expect(provider.callCount, 0);
      },
    );
  });
}

final _modelConfig = ModelConfig(name: 'test', modelId: 'test-model');
const _request = ProtocolRequest(messages: []);

class _DelayedFirstBuildProtocol implements ChatProtocol {
  final firstBuild = Completer<ProtocolRequest>();
  final firstBuildStarted = Completer<void>();
  var _buildCount = 0;

  @override
  String get name => 'openai';

  @override
  Future<ProtocolRequest> buildRequest({
    required List<ChatMessage> history,
    String? assistantPrompt,
    String? contextSummary,
    int? toolOutputMaxChars,
    RequestContentCache? contentCache,
  }) {
    _buildCount++;
    if (_buildCount == 1) {
      firstBuildStarted.complete();
      return firstBuild.future;
    }
    return Future.value(_request);
  }

  @override
  List<Map<String, dynamic>> toolDefsToJson(List<ToolDefinition> tools) => [];

  @override
  List<Map<String, dynamic>> buildAssistantChainMessage({
    required String content,
    required List<NeutralToolCall> toolCalls,
    String? roundReasoning,
    String? thinkingSignature,
  }) =>
      [];

  @override
  List<Map<String, dynamic>> buildToolResultMessages(
    List<ToolCallResult> results, {
    int? toolOutputMaxChars,
  }) =>
      [];
}

class _CountingProvider extends BaseChatProvider {
  var callCount = 0;
  final firstCall = Completer<void>();

  @override
  String get name => 'Counting';

  @override
  List<String> get supportedModelIds => const [];

  @override
  Map<String, dynamic> get defaultParams => const {};

  @override
  Future<String> chat(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
    String? system,
  }) =>
      throw UnimplementedError();

  @override
  Stream<AIStreamEvent> chatStream(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
    String? system,
  }) {
    callCount++;
    if (!firstCall.isCompleted) firstCall.complete();
    return Stream.value(AIStreamEvent('reply'));
  }
}
