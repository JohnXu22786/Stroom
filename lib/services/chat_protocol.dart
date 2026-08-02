import 'dart:convert';
import 'dart:typed_data';

import '../models/chat_message.dart';
import '../models/tool_call.dart';
import 'anthropic_protocol.dart';
import 'attachment_storage.dart';
import 'context_manager.dart'
    show
        kCompactedToolResultPlaceholder,
        kInterruptedToolResultPlaceholder,
        kToolOutputTruncatedSuffix;
import 'openai_protocol.dart';

export 'anthropic_protocol.dart' show AnthropicProtocol;
export 'openai_protocol.dart' show OpenAIProtocol;

// ============================================================================
// ChatProtocol — 聊天协议抽象层
// ============================================================================
//
// 对话数据（ChatMessage / ToolCallData / MessageBlock）是协议中立的，
// 每次请求都从"中立历史"经协议重建为具体的 API 格式（OpenAI 兼容 /
// Anthropic Messages）。这保证了用户中途切换端点类型（甚至切换供应商）
// 后，下一条请求自动使用新格式，无需迁移历史数据。
//
// 协议实现必须是纯函数、无状态的（除单轮内的 thinking 签名透传）：
// 绝不持久化 API 原始格式的消息。
// ============================================================================

/// 一次协议构建请求的结果。
///
/// [messages] 是 API 格式的 message 列表；[system] 是 Anthropic 风格
/// 的顶层 system 字段（OpenAI 协议返回 null，system 提示词以
/// role=system 消息的形式包含在 [messages] 中）。
class ProtocolRequest {
  final List<Map<String, dynamic>> messages;
  final String? system;

  const ProtocolRequest({required this.messages, this.system});
}

/// 协议中立的工具调用表示，供工具循环使用。
///
/// 无论底层是 OpenAI 的 tool_calls 还是 Anthropic 的 tool_use 块，
/// 统一转换为 (id, name, argumentsJson)。argumentsJson 保持 JSON 字符串
/// 形态，与 OpenAI 流的 arguments 一致，便于解析与重放。
class NeutralToolCall {
  final String id;
  final String name;
  final String argumentsJson;

  const NeutralToolCall({
    required this.id,
    required this.name,
    required this.argumentsJson,
  });
}

/// 一次工具执行的结果（协议中立）。
class ToolCallResult {
  final String toolCallId;
  final String result;

  const ToolCallResult({required this.toolCallId, required this.result});
}

/// 将 provider 事件里的工具调用（OpenAI 形状或 Anthropic 形状）
/// 归一化为 [NeutralToolCall]。
NeutralToolCall normalizeToolCall(Map<String, dynamic> tc) {
  final fn = tc['function'] as Map<String, dynamic>?;
  if (fn != null) {
    // OpenAI 形状: {id, type, function: {name, arguments}}
    return NeutralToolCall(
      id: tc['id'] as String? ?? '',
      name: fn['name'] as String? ?? 'unknown',
      argumentsJson: fn['arguments'] as String? ?? '{}',
    );
  }
  // Anthropic 形状: {id, name, input}
  final input = tc['input'];
  return NeutralToolCall(
    id: tc['id'] as String? ?? '',
    name: tc['name'] as String? ?? 'unknown',
    argumentsJson:
        input is Map ? jsonEncode(input) : (input?.toString() ?? '{}'),
  );
}

/// 附件读取结果状态。
enum AttachmentReadStatus { ok, tooLarge, unreadable }

/// 附件 base64 读取结果。
class AttachmentReadOutcome {
  final AttachmentReadStatus status;
  final String? base64;

  const AttachmentReadOutcome(this.status, this.base64);
}

/// 单个附件允许的最大字节数（10 MB，与既有逻辑一致）。
const int maxAttachmentBytes = 10 * 1024 * 1024;

/// 读取附件 base64 载荷，遵守 10 MB 上限。
///
/// 优先使用附件内存缓存（[Attachment.base64Data]），避免重复读取磁盘。
/// 超过大小限制返回 [AttachmentReadStatus.tooLarge]，
/// 读取失败返回 [AttachmentReadStatus.unreadable]。
Future<AttachmentReadOutcome> readAttachmentBase64(Attachment att) async {
  if (att.base64Data != null && att.base64Data!.isNotEmpty) {
    // 已缓存：检查大小（即使缓存也可能超限）
    if (att.fileSize > maxAttachmentBytes) {
      return const AttachmentReadOutcome(AttachmentReadStatus.tooLarge, null);
    }
    return AttachmentReadOutcome(AttachmentReadStatus.ok, att.base64Data);
  }
  // 未缓存：先按大小检查避免加载超大文件
  if (att.fileSize > maxAttachmentBytes) {
    return const AttachmentReadOutcome(AttachmentReadStatus.tooLarge, null);
  }
  final bytes = await AttachmentStorage.readFile(att.storagePath);
  if (bytes == null || bytes.isEmpty) {
    return const AttachmentReadOutcome(AttachmentReadStatus.unreadable, null);
  }
  final b64 = base64Encode(bytes);
  // 缓存 base64 供后续复用
  att.base64Data = b64;
  return AttachmentReadOutcome(AttachmentReadStatus.ok, b64);
}

/// 文本类附件的扩展名列表（可从文件中读取 UTF-8 文本）。
const List<String> textAttachmentExtensions = [
  // Documentation & markup
  'txt',
  'md',
  'tex',
  'rst',
  'asciidoc',
  // Data & config
  'json',
  'csv',
  'log',
  'yaml',
  'yml',
  'xml',
  'toml',
  'ini',
  'cfg',
  'conf',
  'env',
  'properties',
  'plist',
  // Web
  'html',
  'htm',
  'css',
  'scss',
  'less',
  'svg',
  // Shell & scripts
  'sh',
  'bash',
  'zsh',
  'ps1',
  'bat',
  'cmd',
  'py',
  'js',
  'ts',
  'jsx',
  'tsx',
  'dart',
  'java',
  'cpp',
  'c',
  'h',
  'hpp',
  'rs',
  'go',
  'rb',
  'php',
  'swift',
  'kt',
  'scala',
  'r',
  'lua',
  'pl',
  'sql',
  // Git & project
  'gitignore',
  'editorconfig',
  'makefile',
  'dockerfile',
];

/// 读取文本类附件的内容，超长（>4000 字符）截断。
/// 失败返回 null。
Future<String?> readTextAttachmentContent(
  String fileName,
  String storagePath,
) async {
  try {
    final bytes = await AttachmentStorage.readFile(storagePath);
    if (bytes == null || bytes.isEmpty) return null;
    final textContent = utf8.decode(bytes);
    if (textContent.length > 4000) {
      return '${textContent.substring(0, 4000)}\n... [truncated]';
    }
    return textContent;
  } catch (_) {
    return null;
  }
}

/// 附件是否为文本类型（可读取内容）。
bool isTextAttachment(Attachment att) {
  final ext = att.fileName.split('.').last.toLowerCase();
  return textAttachmentExtensions.contains(ext);
}

/// 读取非文本附件的原始字节（用于 PDF 等文档）。
/// 返回 null 表示无法读取。
Future<Uint8List?> readRawAttachmentBytes(Attachment att) async {
  if (att.base64Data != null && att.base64Data!.isNotEmpty) {
    try {
      return base64Decode(att.base64Data!);
    } catch (_) {
      // 缓存损坏，回退到磁盘读取
    }
  }
  return AttachmentStorage.readFile(att.storagePath);
}

// ============================================================================
// 中立工具调用 / 结果辅助（历史重建用）
// ============================================================================

/// 发送给模型的工具结果渲染截断（对齐 opencode TOOL_OUTPUT_MAX_CHARS）。
///
/// 存储保留完整结果（50KB 内），只在**发送给模型时**截断——
/// 与 opencode toModelMessages 的 toolOutputMaxChars 语义一致。
const int kToolOutputMaxChars = 2000;

/// 渲染截断工具结果（发送给模型用）。
String truncateToolOutput(String text) {
  if (text.length <= kToolOutputMaxChars) return text;
  // 与 context_manager 的估算渲染共用同一后缀（kToolOutputTruncatedSuffix），
  // 保证 token 估算与真实发送文本一致。
  return '${text.substring(0, kToolOutputMaxChars)}$kToolOutputTruncatedSuffix';
}

/// 解析历史中单个工具结果的重建文本。
///
/// - 已压缩（compactedAt）：占位符（opencode compacted 渲染语义，
///   数据仍保留，仅发送时替换）
/// - 完成且有结果：原文（渲染截断 2K）
/// - 未完成/失败/结果缺失：中断占位（OpenAI/Anthropic 都要求
///   每个工具调用有配对结果，否则下一轮请求报错）
String rebuildToolResultText(ToolCallData tc) {
  if (tc.compactedAt != null) {
    return kCompactedToolResultPlaceholder;
  }
  if (tc.status == ToolCallStatus.completed && tc.result != null) {
    return truncateToolOutput(tc.result!);
  }
  return kInterruptedToolResultPlaceholder;
}

// ============================================================================
// 抽象协议
// ============================================================================

abstract class ChatProtocol {
  /// 协议名称：'openai' | 'anthropic'
  String get name;

  /// 将中立历史构建为 API 请求消息。
  ///
  /// [assistantPrompt] 为对话助手的系统提示词（OpenAI 协议会将其作为
  /// system 消息前置；Anthropic 协议放入 [ProtocolRequest.system]）。
  ///
  /// [contextSummary] 为上下文压缩产生的锚定摘要（对话被压缩过时传入），
  /// 以 system 级内容注入（OpenAI：附加 system 消息；Anthropic：system 拼接）。
  Future<ProtocolRequest> buildRequest({
    required List<ChatMessage> history,
    String? assistantPrompt,
    String? contextSummary,
  });

  /// 将工具定义转换为协议要求的 JSON 数组。
  List<Map<String, dynamic>> toolDefsToJson(List<ToolDefinition> tools);

  /// 构建携带工具调用（及可选推理内容）的助手消息，用于工具循环链。
  ///
  /// [content] 当前轮累计的可见文本；[roundReasoning] 当前轮推理文本；
  /// [thinkingSignature] Anthropic extended thinking 签名（仅 anthropic 使用）。
  List<Map<String, dynamic>> buildAssistantChainMessage({
    required String content,
    required List<NeutralToolCall> toolCalls,
    String? roundReasoning,
    String? thinkingSignature,
  });

  /// 构建工具结果消息，紧跟在助手消息之后。
  List<Map<String, dynamic>> buildToolResultMessages(
      List<ToolCallResult> results);

  /// 返回"禁用工具"的请求体参数（tool_choice: none 的协议差异）。
  ///
  /// 与 tools 一起发送：收尾轮仍需携带工具定义（Anthropic 要求
  /// 历史含 tool_use/tool_result 块时必须定义 tools），
  /// 用 tool_choice: none 显式禁止调用。
  Map<String, dynamic> toolChoiceNoneJson();
}

/// 根据端点类型创建协议实例。
///
/// [endpointType] 取值 'anthropic' 或 'openai'（默认）。
ChatProtocol createChatProtocol(String endpointType) {
  return endpointType == 'anthropic' ? AnthropicProtocol() : OpenAIProtocol();
}

/// 计算有效端点类型：模型覆盖 > 供应商 > 'openai'。
///
/// 旧配置（没有 endpointType 字段）天然落到 'openai'，即数据迁移的默认路径。
String effectiveEndpointType(
    String? modelEndpointType, String? providerEndpointType) {
  if (modelEndpointType != null && modelEndpointType.isNotEmpty) {
    return modelEndpointType;
  }
  if (providerEndpointType != null && providerEndpointType.isNotEmpty) {
    return providerEndpointType;
  }
  return 'openai';
}
