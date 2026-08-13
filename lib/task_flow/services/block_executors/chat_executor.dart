import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;

import '../../../models/assistant.dart';
import '../../../models/chat_message.dart';
import '../../../providers/background_task_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../services/app_log_service.dart';
import '../../../services/chat_stream_manager.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

/// Output record name for a chat block: 助手回复_<短名>.
///
/// The "短名" comes from the previous block's passed-in content — a file
/// path uses its basename, plain text uses its first 20 chars — so the
/// record is traceable back to what was sent to the assistant.
///
/// Never throws: the file check is skipped on web (dart:io File methods
/// throw UnsupportedError there) and any file-system error falls back to
/// the plain-text branch, so the caller can await this safely.
@visibleForTesting
Future<String> chatOutputTitle(String input) async {
  if (!kIsWeb) {
    try {
      final file = File(input);
      if (await file.exists()) {
        return '助手回复_${p.basenameWithoutExtension(input)}';
      }
    } catch (_) {
      // Web / unreadable path → treat as plain text below.
    }
  }
  final t = input.trim();
  final short = t.length > 20 ? t.substring(0, 20) : (t.isEmpty ? '对话' : t);
  return '助手回复_$short';
}

/// Executes a chat (assistant conversation) block.
///
/// Sends [input] (the previous block's output) to the selected assistant
/// (or the currently selected one when [assistant] is null) via
/// [ChatStreamManager] and returns the assistant's text response.
Future<String> executeChatBlock({
  required TaskFlowBlock block,
  required BlockTypeDefinition def,
  required String input,
  required String execId,
  required TaskFlowExecutionNotifier execNotifier,
  required FlowSubTask flowSubTask,
  required BackgroundTaskNotifier bgNotifier,
  required ChatStreamManager chatManager,
  Assistant? assistant,
  Duration maxWait = const Duration(minutes: 10),
}) async {
  // The execId prefix keeps the convId/taskId aligned with the delete
  // path's derivation (removeFlowSubTaskTasks cancels
  // 'flow_<execution.id>_<st.id>') — both sides must use the same shape.
  final taskId = 'chat_${execId}_${flowSubTask.id}';
  execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
  execNotifier.updateSubTaskStatus(execId, flowSubTask.id, TaskStatus.running);
  final title = await chatOutputTitle(input);
  bgNotifier.addTask(
    type: BackgroundTaskType.chat,
    title: title,
    taskId: taskId,
  );

  try {
    bgNotifier.updateStep(taskId, 0, running: true);

    final convId = 'flow_${execId}_${flowSubTask.id}';

    // The previous block's output is sent VERBATIM as a role:user message
    // (no prefix editing). The assistant's own prompt is injected by the
    // stream manager as the system message. A fresh per-execution
    // conversation — no prior context from other flows.
    final userMessage = ChatMessage(role: 'user', content: input);
    final result = await chatManager
        .startStreaming(
      text: input,
      convId: convId,
      history: [userMessage],
      tools: [], // No tool access in flow blocks
      assistant: assistant,
    )
        .timeout(maxWait, onTimeout: () {
      // A stalled model stream must not hang the flow forever —
      // cancel the stream and surface the failure like any other.
      chatManager.cancel(convId);
      return const StreamResult(history: [], cancelled: true);
    });

    // A cancelled stream (user stop or timeout) only has a partial
    // reply — treat it as a failure, never a successful step.
    if (result.cancelled) {
      failSubTask(
        bgNotifier,
        taskId,
        execNotifier,
        execId,
        flowSubTask.id,
        '对话超时或已取消',
      );
      throw BlockExecutionException(
        '对话超时或已取消',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }

    final reply = result.fullReply;

    // On a stream error the manager folds the formatted error text into
    // fullReply (cancelled stays false) — an error reply must fail the
    // block, not flow on as successful output.
    if (result.assistantMessage?.isError == true) {
      failSubTask(
        bgNotifier,
        taskId,
        execNotifier,
        execId,
        flowSubTask.id,
        '对话失败: $reply',
        // Carry the failed message's raw request/response onto the
        // background task — the unified task list then shows the
        // "查看错误详情" dialog (same form as the chat page's error
        // bubble: status code, request/response body).
        rawRequest: result.assistantMessage?.rawRequest,
        rawResponse: result.assistantMessage?.rawResponse,
      );
      throw BlockExecutionException(
        '对话失败: $reply',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }

    bgNotifier.updateStep(taskId, 0, completed: true);
    bgNotifier.setResult(taskId, reply);

    if (reply.isEmpty) {
      failSubTask(
        bgNotifier,
        taskId,
        execNotifier,
        execId,
        flowSubTask.id,
        '助手未返回内容',
      );
      throw BlockExecutionException(
        '助手未返回内容',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }

    // The flow may have been deleted while the stream was running —
    // don't save an orphaned text record.
    if (!execNotifier.state.any((e) => e.id == execId)) {
      throw BlockExecutionException(
        '任务流已删除',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }

    // Save text via the shared helper (with folder dedup). The title is a
    // friendly name — the record shows in the text gallery by name, and a
    // raw UUID suffix would be an opaque string (dedup appends (2), (3)...).
    final textPath = await saveTextForFlow(
      reply,
      saveFolder: '',
      title: title,
      // Guard against a flow deleted mid-save (narrow race after the
      // existence check above).
      shouldCommit: () => execNotifier.state.any((e) => e.id == execId),
    );

    bgNotifier.completeTask(taskId, downloadedFilePath: textPath);
    execNotifier.updateSubTaskStatus(
      execId,
      flowSubTask.id,
      TaskStatus.completed,
    );
    AppLogService.info('TaskFlow', '助手对话完成: ${reply.length} chars ($execId)');

    return reply;
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '对话失败: $e',
    );
    throw BlockExecutionException(
      e.toString(),
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }
}
