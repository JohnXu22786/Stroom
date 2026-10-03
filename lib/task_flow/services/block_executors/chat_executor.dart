import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;

import '../../../models/assistant.dart';
import '../../../models/chat_message.dart';
import '../../../providers/background_task_provider.dart';
import '../../../providers/conversation_provider.dart';
import '../../../providers/provider_config.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../services/app_log_service.dart';
import '../../../services/chat_stream_manager.dart';
import '../../../services/attachment_storage.dart';
import '../../../services/chat_protocol.dart'
    show maxAttachmentBytes, effectiveEndpointType;
import '../../../services/chat_adapter.dart'
    show availableLlmModels, resolveModelRef;
import '../../../utils/web_file_store.dart';
import '../../models/block_type_definition.dart';
import '../../models/flow_payload.dart';
import '../../models/io_type.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

/// Background-task title for a chat block: 助手回复_<短名>.
///
/// The "短名" comes from the previous block's passed-in content — a file
/// path uses its basename, plain text uses its first 20 chars — so the
/// unified-task-list card is traceable back to what was sent to the
/// assistant. (The conversation itself gets its title through the normal
/// chat-title derivation on the conversation record.)
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

/// Reuse chat's model-reference resolution; unbound assistants use the
/// currently configured chat endpoint. No provider/model selection is changed.
String flowChatEndpointType(
  Assistant? assistant,
  ProviderEntriesState providers, {
  String fallback = 'openai',
}) {
  if (assistant == null) return fallback;
  final reference = assistant.modelId ??
      assistant.defaultModelId ??
      assistant.defaultModelName;
  if (reference == null || reference.isEmpty) return fallback;
  final selected = resolveModelRef(
    models: availableLlmModels(providers),
    modelId: reference,
    providerName: assistant.modelId == null || assistant.modelId!.isEmpty
        ? assistant.defaultProviderName
        : null,
    displayName: reference,
  );
  final entry =
      providers.entries.where((entry) => entry.type == 'llm').firstOrNull;
  if (selected == null || entry == null) return fallback;
  final config = entry.configs[selected.configIndex];
  final model = config.models[selected.modelIndex];
  return effectiveEndpointType(model.endpointType, config.endpointType);
}

String? flowChatInputError(
  IOType type,
  String endpointType, {
  String? mimeType,
  List<int>? headerBytes,
}) {
  if (endpointType != 'anthropic') return null;
  if (type == IOType.audio || type == IOType.video) {
    return '此助手的 Anthropic 对话格式不支持${type.label}附件，请选择支持此媒体的助手';
  }
  if (type == IOType.file &&
      mimeType != null &&
      (mimeType.split(';').first.trim().toLowerCase() != 'application/pdf' ||
          headerBytes == null ||
          headerBytes.length < 4 ||
          headerBytes[0] != 0x25 ||
          headerBytes[1] != 0x50 ||
          headerBytes[2] != 0x44 ||
          headerBytes[3] != 0x46)) {
    // MIME lookup falls back to the extension when its magic table has no
    // match. A renamed DOCX can therefore report application/pdf unless the
    // PDF signature is checked as well.
    return '此助手的 Anthropic 对话格式只支持图片和 PDF 附件，请选择支持此文件的助手';
  }
  return null;
}

/// Persist media with the same AttachmentStorage and Attachment metadata as
/// the chat composer. The shared protocol handles compression and API encoding.
/// Path-shaped textual content stays text; no filesystem guessing is involved.
Future<ChatMessage> prepareFlowChatMessage(
  FlowPayload payload,
  String conversationId, {
  String endpointType = 'openai',
}) async {
  if (!BlockTypeDefinition.chat.acceptsInput(payload.type)) {
    throw const FormatException('助手对话不支持此输入类型，请指定文本或媒体类型');
  }
  final unsupported = flowChatInputError(payload.type, endpointType);
  if (unsupported != null) throw FormatException(unsupported);
  if (!FlowPayload.isFileType(payload.type)) {
    return ChatMessage(role: 'user', content: payload.text);
  }
  final reference = payload.fileReference;
  if (reference == null || reference.isEmpty) {
    throw const FormatException('媒体文件路径为空，请重新选择文件');
  }
  final Uint8List bytes;
  if (kIsWeb) {
    bytes = await WebFileStore.read(reference) ?? Uint8List(0);
  } else {
    final file = File(reference);
    // A generic file can actually be an image, which the chat pipeline
    // compresses. Sniff only its header before a large read so documents,
    // audio and video still fail without loading the whole file.
    final length = await file.length();
    if (length > maxAttachmentBytes) {
      final header = await file.openRead(0, 32).first;
      final detectedType = flowMimeType(
        flowFileMimeType(
          reference,
          headerBytes: header,
          mimeType: payload.mimeType,
        ),
      );
      if (payload.type != IOType.file && detectedType != payload.type) {
        throw FormatException(
          '文件实际类型为${detectedType.label}，需要${payload.type.label}，请重新选择文件',
        );
      }
      if (detectedType != IOType.image) {
        throw const FormatException('助手对话附件超过 10 MB，请选择较小文件');
      }
      if (length > maxFlowImageInputBytes) {
        throw const FormatException('助手对话图片超过 20 MB，请选择较小图片');
      }
    }
    bytes = await file.readAsBytes();
  }
  if (bytes.isEmpty) {
    throw const FormatException('媒体文件为空或无法读取，请重新选择文件');
  }
  final mimeType = flowFileMimeType(
    reference,
    headerBytes: bytes,
    mimeType: payload.mimeType,
  );
  final actualType = flowMimeType(mimeType);
  if (actualType == IOType.image && bytes.length > maxFlowImageInputBytes) {
    throw const FormatException('助手对话图片超过 20 MB，请选择较小图片');
  }
  if (actualType != IOType.image && bytes.length > maxAttachmentBytes) {
    throw const FormatException('助手对话附件超过 10 MB，请选择较小文件');
  }
  if (payload.type != IOType.file && actualType != payload.type) {
    throw FormatException(
      '文件实际类型为${actualType.label}，需要${payload.type.label}，请重新选择文件',
    );
  }
  final unsupportedFile = flowChatInputError(
    actualType,
    endpointType,
    mimeType: mimeType,
    headerBytes: bytes,
  );
  if (unsupportedFile != null) throw FormatException(unsupportedFile);
  final name = p.basename(payload.fileName ?? reference);
  final storagePath = await AttachmentStorage.saveFile(name, bytes);
  final attachment = Attachment(
    fileName: name,
    mimeType: mimeType,
    fileType: actualType == IOType.file ? 'document' : actualType.name,
    hash: AttachmentStorage.computeHash(bytes),
    storagePath: storagePath,
    fileSize: bytes.length,
    conversationId: conversationId,
  );
  return ChatMessage(
    role: 'user',
    content: payload.text,
    attachments: [attachment],
  );
}

/// Executes a chat (assistant conversation) block.
///
/// Sends [input] (the previous block's output) to the selected assistant
/// (or the currently selected one when [assistant] is null) via
/// [ChatStreamManager] and returns the assistant's text response.
///
/// The exchange persists as a REAL conversation (id `flow_<execId>_<sub>`,
/// created up-front before streaming): the manager's periodic + final
/// message saves land in [ConversationsNotifier] exactly like a user-typed
/// conversation, so the record is viewable and continuable from the
/// topic-selection page. On any failure the conversation is removed again —
/// a failed block must not leave an orphan stub. No text file is saved.
Future<String> executeChatBlock({
  required TaskFlowBlock block,
  required BlockTypeDefinition def,
  required String input,
  FlowPayload? payload,
  String endpointType = 'openai',
  ProviderEntriesState? providerEntries,
  required String execId,
  required TaskFlowExecutionNotifier execNotifier,
  required FlowSubTask flowSubTask,
  required BackgroundTaskNotifier bgNotifier,
  required ChatStreamManager chatManager,
  required ConversationsNotifier conversationsNotifier,
  Assistant? assistant,
  Duration maxWait = const Duration(minutes: 10),
}) async {
  // The execId prefix keeps the convId/taskId aligned with the delete
  // path's derivation (removeFlowSubTaskTasks cancels
  // 'flow_<execution.id>_<st.id>') — both sides must use the same shape.
  final taskId = 'chat_${execId}_${flowSubTask.id}';
  final convId = 'flow_${execId}_${flowSubTask.id}';
  bool isLive() {
    return execNotifier.execution(execId)?.status ==
        FlowExecutionStatus.running;
  }

  var conversationCreated = false;
  var flowAttachments = <Attachment>[];
  Future<void> discardConversation() async {
    var removed = !conversationCreated;
    if (conversationCreated && conversationsNotifier.mounted) {
      removed = await conversationsNotifier.deleteFlowConversationWithFiles(
        convId,
      );
    }
    // If the removal could not be saved, the old conversation remains on
    // disk. Its attachment copies must remain readable too.
    if (!removed) return;
    for (final attachment in flowAttachments) {
      try {
        await AttachmentStorage.deleteFile(attachment.storagePath);
      } catch (_) {
        // The failed exchange is already gone; cleanup is best effort.
      }
    }
    if (flowAttachments.isNotEmpty) {
      try {
        await AttachmentStorage.deleteConversationCompressedImages(convId);
      } catch (_) {}
    }
  }

  Future<Never> stopInactiveExecution() async {
    chatManager.cancel(convId);
    if (bgNotifier.mounted) bgNotifier.removeTask(taskId);
    await discardConversation();
    throw BlockExecutionException(
      '任务流已删除或已停止',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  try {
    if (!isLive()) await stopInactiveExecution();
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
    execNotifier.updateSubTaskStatus(
      execId,
      flowSubTask.id,
      TaskStatus.running,
    );
    final title = await chatOutputTitle(input);
    if (!isLive()) await stopInactiveExecution();
    bgNotifier.addTask(
      type: BackgroundTaskType.chat,
      title: title,
      taskId: taskId,
    );
    bgNotifier.updateStep(taskId, 0, running: true);

    // A cold retry reuses this step's deterministic conversation ID. Wait for
    // the asynchronous disk load, then remove a previous partial exchange and
    // its stored attachment copies before creating the replacement. Otherwise
    // _load can restore the old entry after creation, or createConversation
    // can prepend a second entry with the same ID.
    await conversationsNotifier.ready;
    if (!isLive() || !conversationsNotifier.mounted) {
      await stopInactiveExecution();
    }
    if (!await conversationsNotifier.deleteFlowConversationWithFiles(convId)) {
      throw StateError('旧会话清理未能保存，请稍后重试');
    }
    if (!isLive() || !conversationsNotifier.mounted) {
      await stopInactiveExecution();
    }

    // Create the REAL conversation before streaming (id == convId) so the
    // stream manager's periodic + final persists land in a real, viewable
    // conversation — semantically identical to the user typing the message
    // in the chat page. `activate` is skipped: a background flow must not
    // hijack the chat tab's active conversation.
    conversationsNotifier.createConversation(
      id: convId,
      assistantId: assistant?.id,
      activate: false,
    );
    conversationCreated = true;

    // The typed input uses the chat composer's normal attachment contract.
    // Textual content stays verbatim and media paths never become prompt text.
    final userMessage = await prepareFlowChatMessage(
      payload ?? FlowPayload.text(input),
      convId,
      endpointType: endpointType,
    );
    flowAttachments = userMessage.attachments;
    if (!isLive()) await stopInactiveExecution();
    // Persist attachments before streaming so failure cleanup can find them.
    if (!await conversationsNotifier
        .updateFlowMessagesChecked(convId, [userMessage])) {
      throw StateError('用户消息未能保存，对话未发送');
    }
    // Cancellation before a stream exists cannot be handled by manager.cancel.
    // Check synchronously after preparation/persistence, before starting it.
    if (!isLive()) await stopInactiveExecution();

    // The previous block's text is sent VERBATIM as a role:user message
    // (no prefix editing). The assistant's own prompt is injected by the
    // stream manager as the system message. A fresh per-execution
    // conversation — no prior context from other flows.
    final result = await chatManager
        .startStreaming(
      text: userMessage.content,
      convId: convId,
      history: [userMessage],
      tools: [], // No tool access in flow blocks
      assistant: assistant,
      entriesStateOverride: providerEntries,
    )
        .timeout(
      maxWait,
      onTimeout: () {
        // A stalled model stream must not hang the flow forever —
        // cancel the stream and surface the failure like any other.
        chatManager.cancel(convId);
        return const StreamResult(history: [], cancelled: true);
      },
    );

    if (!isLive()) await stopInactiveExecution();

    // A cancelled stream (user stop or timeout) only has a partial
    // reply — treat it as a failure, never a successful step. The stub
    // conversation must not linger in the topic list either.
    if (result.cancelled) {
      await discardConversation();
      if (!isLive()) await stopInactiveExecution();
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
    // block, not flow on as successful output. The error exchange is not
    // worth keeping as a conversation.
    if (result.assistantMessage?.isError == true) {
      await discardConversation();
      if (!isLive()) await stopInactiveExecution();
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

    if (reply.isEmpty) {
      await discardConversation();
      if (!isLive()) await stopInactiveExecution();
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

    if (!isLive()) await stopInactiveExecution();

    // Deterministic final persist: the stream manager normally saves the
    // full history through its own finalize path (periodic + final
    // updateMessages keyed on convId), but a silent save failure there
    // must not leave a stub conversation behind. updateMessages is a full
    // replace, so re-persisting the same history is idempotent.
    if (!await conversationsNotifier.updateFlowMessagesChecked(
        convId, result.history)) {
      throw StateError('助手回复未能保存，对话未完成');
    }
    if (!isLive()) await stopInactiveExecution();

    // The full [user, assistant] exchange now lives in a real conversation
    // — viewable and continuable from the topic-selection page. The task
    // card keeps the reply text; no text file is saved.
    bgNotifier.updateStep(taskId, 0, completed: true);
    bgNotifier.setResult(taskId, reply);
    bgNotifier.completeTask(taskId);
    execNotifier.updateSubTaskStatus(
      execId,
      flowSubTask.id,
      TaskStatus.completed,
    );
    AppLogService.info('TaskFlow', '助手对话完成: ${reply.length} chars ($execId)');

    return reply;
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    if (!isLive()) await stopInactiveExecution();
    await discardConversation();
    if (!isLive()) await stopInactiveExecution();
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
