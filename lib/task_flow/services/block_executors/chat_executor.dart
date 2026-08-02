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

/// Executes a chat (assistant conversation) block.
///
/// Sends [input] to the current assistant model via [ChatStreamManager]
/// and returns the assistant's text response as output.
Future<String> executeChatBlock({
  required TaskFlowBlock block,
  required BlockTypeDefinition def,
  required String input,
  required String execId,
  required TaskFlowExecutionNotifier execNotifier,
  required FlowSubTask flowSubTask,
  required BackgroundTaskNotifier bgNotifier,
  required ChatStreamManager chatManager,
  Duration maxWait = const Duration(minutes: 10),
}) async {
  final promptPrefix = asStringParam(block.params, 'promptPrefix', '').trim();
  final prompt = promptPrefix.isNotEmpty ? '$promptPrefix\n\n$input' : input;

  final taskId = 'chat_${flowSubTask.id}';
  execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
  execNotifier.updateSubTaskStatus(execId, flowSubTask.id, TaskStatus.running);
  bgNotifier.addTask(
    type: BackgroundTaskType.chat,
    title: '助手对话',
    taskId: taskId,
  );

  try {
    bgNotifier.updateStep(taskId, 0, running: true);

    // Generate a unique conversation ID for this block execution.
    // Using the flow sub-task ID ensures each execution has its own
    // conversation context (no cross-contamination with other flows).
    final convId = 'flow_${flowSubTask.id}';

    final result = await chatManager.startStreaming(
      text: prompt,
      convId: convId,
      history: [], // Fresh conversation – no prior context
      tools: [], // No tool access in flow blocks
    ).timeout(maxWait, onTimeout: () {
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

    // Save text via the shared helper (with folder dedup).
    final textPath = await saveTextForFlow(
      reply,
      saveFolder: '',
      title: '助手对话_${flowSubTask.id}',
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
