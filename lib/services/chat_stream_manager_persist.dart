part of 'chat_stream_manager.dart';

extension _ChatStreamManagerPersistExt on ChatStreamManager {
  /// Periodic partial persistence for the given conversation's stream.
  Future<void> _doPeriodicPersist(_ConversationStreamState s) {
    final inFlight = s._periodicPersistFuture;
    if (inFlight != null) return inFlight;

    final future = _persistPeriodically(s);
    s._periodicPersistFuture = future;
    return future.whenComplete(() {
      if (identical(s._periodicPersistFuture, future)) {
        s._periodicPersistFuture = null;
      }
    });
  }

  Future<void> _persistPeriodically(_ConversationStreamState s) async {
    // Guard: if the timer was cancelled (stream ended), the state might
    // still be referenced from a late-arriving timer callback. The final
    // save has already run by now; don't overwrite it with partial data.
    if (s.persistTimer == null) return;
    if (s.cancelledByUser) return;
    // 纯工具轮（无文本/推理但已有工具结果）也要持久化——并行执行时
    // 一轮的全部工具同时启动，崩溃会一次丢失所有工具卡片。
    if (!s.hasTextContent &&
        !s.hasReasoningContent &&
        s.accumulatedToolCalls.isEmpty) {
      return;
    }
    if (s._isPersisting) return;
    s._isPersisting = true;
    final ref = _ref;
    if (ref == null) {
      debugPrint('[ChatStreamManager] 定期持久化失败: _ref is null');
      s._isPersisting = false;
      return;
    }
    try {
      final checkpoint = s.streamCheckpointDelta();
      await ref.read(conversationsProvider.notifier).updateMessagesPeriodically(
            s.convId,
            checkpoint: checkpoint,
            resetTemporaryCountdown: true,
          );
      s.markStreamCheckpointPersisted(checkpoint);
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
      await ref.read(conversationsProvider.notifier).updateMessages(
          convId, List<ChatMessage>.from(history),
          resetTemporaryCountdown: true);
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
