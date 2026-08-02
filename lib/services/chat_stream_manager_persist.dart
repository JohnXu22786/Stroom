part of 'chat_stream_manager.dart';

extension _ChatStreamManagerPersistExt on ChatStreamManager {
  /// Periodic partial persistence for the given conversation's stream.
  void _doPeriodicPersist(_ConversationStreamState s) {
    // Guard: if the timer was cancelled (stream ended), the state might
    // still be referenced from a late-arriving timer callback. The final
    // save has already run by now; don't overwrite it with partial data.
    if (s.persistTimer == null) return;
    if (s.cancelledByUser) return;
    if (s.fullReply.isEmpty && s.reasoningBuffer.isEmpty) return;
    if (s._isPersisting) return;
    s._isPersisting = true;
    final ref = _ref;
    if (ref == null) {
      debugPrint('[ChatStreamManager] 定期持久化失败: _ref is null');
      s._isPersisting = false;
      return;
    }
    try {
      final partialHistory = List<ChatMessage>.from(s.history);
      // 纯推理轮（fullReply 空但推理非空）也持久化：崩溃重进后
      // 已流出的思考过程不丢失。
      if (s.fullReply.isNotEmpty ||
          s.reasoningSections.any((c) => c.isNotEmpty)) {
        final exists = partialHistory.any((m) => m.id == s.streamingMsgId);
        if (!exists) {
          // reasoningContent 用全量累计（sections 拼接），与 finalize
          // 的消息构造保持一致（reasoningBuffer 只含最后一轮）。
          final fullReasoning = s.reasoningSections.join('\n');
          partialHistory.add(ChatMessage(
            role: 'assistant',
            content: s.fullReply,
            id: s.streamingMsgId ?? '',
            reasoningContent: fullReasoning.isNotEmpty ? fullReasoning : null,
            toolCalls: s.accumulatedToolCalls.isNotEmpty
                ? List<ToolCallData>.from(s.accumulatedToolCalls)
                : null,
            reasoningSections: s.reasoningSections.isNotEmpty
                ? List<String>.from(s.reasoningSections)
                : null,
            textSections: s.textChunks.any((c) => c.isNotEmpty)
                ? List<String>.from(s.textChunks)
                : null,
            toolCallRoundStarts: s.toolCallRoundStarts.isNotEmpty
                ? List<int>.from(s.toolCallRoundStarts)
                : null,
          ));
        }
      }
      ref.read(conversationsProvider.notifier).updateMessages(
            s.convId,
            partialHistory,
          );
    } catch (e) {
      debugPrint('[ChatStreamManager] 定期持久化失败: $e');
    } finally {
      s._isPersisting = false;
    }
  }

  Future<void> _saveMessages({
    required String convId,
    required List<ChatMessage> history,
  }) async {
    final ref = _ref;
    if (ref == null) {
      await AppLogService.warning(
          'ChatStreamManager', '保存消息失败: _ref is null, convId=$convId');
      return;
    }
    try {
      await ref
          .read(conversationsProvider.notifier)
          .updateMessages(convId, List<ChatMessage>.from(history));
      final lastMsg = history.isNotEmpty ? history.last : null;
      await AppLogService.info(
          'ChatStreamManager',
          '保存消息成功, convId=$convId, historyLen=${history.length}, '
              'hasToolCalls=${lastMsg?.toolCalls?.isNotEmpty ?? false}, '
              'hasReasoning=${lastMsg?.reasoningSections?.isNotEmpty ?? false}');
    } catch (e, s) {
      try {
        await AppLogService.error('ChatStreamManager', '保存消息失败', e, s);
      } catch (_) {}
    }
  }
}
