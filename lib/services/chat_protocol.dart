import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../utils/image_send_compressor.dart';
import 'anthropic_protocol.dart';
import 'attachment_storage.dart';
import 'context_manager.dart'
    show
        kCompactedToolResultPlaceholder,
        kInterruptedToolResultPlaceholder,
        kToolOutputTruncatedSuffix,
        truncateUtf8;
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

  /// 实际载荷的 MIME 类型。
  ///
  /// 图片超限自动压缩可能改变格式（PNG→JPEG）。非 null 时协议层必须
  /// 用它覆盖 [Attachment] 的 mimeType 声明，否则 API 会收到
  /// "宣称 PNG 实为 JPEG" 的不一致载荷。null 表示格式未变。
  final String? mimeType;

  const AttachmentReadOutcome(this.status, this.base64, {this.mimeType});
}

/// 单个附件允许的最大字节数（10 MB，与既有逻辑一致）。
///
/// 这是**硬顶**：图片压缩后仍超过该值（无法解码的 HEIC/损坏文件、
/// 病理级超大图）时，跳过该附件以保住整条请求。
const int maxAttachmentBytes = 10 * 1024 * 1024;

/// 图片发送压缩的**通用阈值**（2 MB，原始字节）。
///
/// 所有超过该值的图片在发送前都会被压缩到不超过该值——不做逐供应商
/// 优化，因为各家 API 对请求体总量的容忍度都有限：
/// - Anthropic Messages API：请求体上限 32MB，单图 base64 上限 10MB
///   （Bedrock/GCP 5MB）；
/// - Google Gemini：inline 数据总量上限约 20MB；
/// - OpenAI：512MB 总量（宽松）；
/// - OpenRouter：透传上游，部分模型的请求体上限甚至低至 4.5MB
///   （2 张以上图片或多轮历史时仍可能 413，属上游模型限制）。
/// base64 还会让载荷膨胀约 33%，且多轮对话每轮都会重发历史图片，
/// 所以单图目标压缩到 2MB 以内（base64 ≈ 2.7MB）：
/// 12MP 照片 ≈ q60（约 1.9MB，模型侧本来就会内部缩放），
/// 每轮 5-7 张图片的总量仍在 Anthropic 32MB / Gemini 20MB 之内。
const int imageCompressThresholdBytes = 2 * 1024 * 1024;

/// 图片选中后立即后台预压缩（供 composer 在图片选中时调用）。
///
/// - 输入未超阈值 / 无法解码 / 压缩无收益 → 不改动 [att]，返回 false。
/// - 成功 → 压缩结果写入内存缓存（[Attachment.base64Data]，发送路径
///   直接复用、发送时零压缩等待），并在 [conversationId] 或
///   [Attachment.conversationId] 非空时写入磁盘缓存
///   （`temp_compressed/<conversationId>/<hash>`，见
///   [AttachmentStorage.saveCompressedImage]），保证重启后依然零压缩等待。
/// - [isStillRelevant]：压缩耗时期间附件可能已被移除/编辑/对话已切换，
///   写入前再次确认（返回 false 则跳过一切写入，避免复活已被清理的
///   缓存）。
///
/// 压缩本身在后台 isolate 执行（[compressImageForSend]），不占用
/// 前台资源；失败静默忽略，发送路径会按需重新压缩兜底。
Future<bool> preCompressImageForPendingAttachment(
  Attachment att,
  Uint8List rawBytes, {
  required int maxBytes,
  String? conversationId,
  bool Function()? isStillRelevant,
}) async {
  if (rawBytes.isEmpty || rawBytes.length <= maxBytes) return false;
  final result = await compressImageForSend(rawBytes, maxBytes: maxBytes);
  if (!result.decodable || result.compressed == null) return false;
  if (isStillRelevant != null && !isStillRelevant()) return false;
  att.base64Data = base64Encode(result.compressed!.bytes);
  final convId = conversationId ?? att.conversationId;
  if (convId != null) {
    try {
      final saved = await AttachmentStorage.saveCompressedImage(
        conversationId: convId,
        hash: att.hash,
        bytes: result.compressed!.bytes,
        mimeType: result.compressed!.mimeType,
      );
      // 缓存写入哪个对话就登记到哪个对话：清理/复用路径都依赖
      // att.conversationId 定位（发送前对话归属变化时由调用方重置）。
      // 仅在真实写入后才标记已落盘（空 hash/convId 时为 no-op）。
      if (saved != null) {
        att.conversationId ??= convId;
        att.compressedCachePersisted = true;
      }
    } catch (e) {
      debugPrint('[ChatProtocol] 图片压缩缓存写入失败: $e');
    }
  }
  return true;
}

/// 读取附件 base64 载荷。
///
/// 优先使用附件内存缓存（[Attachment.base64Data]），避免重复读取磁盘。
///
/// **所有图片都会尽量压缩到 [maxBytes]（默认通用阈值 2MB）以内**：
/// 用户已选择的图片必须发送，而大多数服务器不接受总量过大的请求
/// （Anthropic Messages API 请求体上限 32MB、Gemini inline 约 20MB、
/// base64 膨胀 33%、多轮对话每轮重发历史图片），因此超过阈值的图片
/// 会在发送前自动压缩（无损优先、JPEG 渐进降级，见
/// [compressImageForSend]）。未超过阈值的图片字节原样保留（真正无损、
/// 零开销）。压缩结果回写 [Attachment.base64Data]，同一会话内后续轮次
/// （工具链、追问）直接复用。
///
/// 图片载荷的实际格式（PNG/JPEG）总是通过 [AttachmentReadOutcome.mimeType]
/// 告知协议层——包括缓存复用、压缩无收益等路径——避免 API 收到
/// "宣称 PNG 实为 JPEG" 的不一致载荷（Anthropic 会整条 400）。
/// 无法解码或压缩无收益的图片在 2MB~10MB 硬顶之间按原字节尽力发送；
/// 超过 [maxAttachmentBytes]（10MB）硬顶的才返回
/// [AttachmentReadStatus.tooLarge] 占位。
///
/// 非图片附件（音频/视频等）超过 [maxAttachmentBytes] 仍返回
/// [AttachmentReadStatus.tooLarge]（无法无损压缩，且提前按 fileSize
/// 拦截可避免读取超大文件）。
///
/// 读取失败返回 [AttachmentReadStatus.unreadable]。
Future<AttachmentReadOutcome> readAttachmentBase64(
  Attachment att, {
  int maxBytes = imageCompressThresholdBytes,
}) async {
  // 已缓存：先尝试解码缓存（损坏缓存回退磁盘读取）
  Uint8List? bytes;
  if (att.base64Data != null && att.base64Data!.isNotEmpty) {
    try {
      bytes = base64Decode(att.base64Data!);
    } catch (_) {
      bytes = null;
    }
  }

  if (bytes == null) {
    // 非图片超限：按 fileSize 提前拦截，避免加载超大文件
    if (att.fileSize > maxAttachmentBytes && att.fileType != 'image') {
      return const AttachmentReadOutcome(AttachmentReadStatus.tooLarge, null);
    }
    try {
      final diskBytes = await AttachmentStorage.readFile(att.storagePath);
      if (diskBytes == null || diskBytes.isEmpty) {
        return const AttachmentReadOutcome(
            AttachmentReadStatus.unreadable, null);
      }
      bytes = diskBytes;
    } catch (e) {
      // 瞬时 IO 异常（权限、磁盘满等）：降级为 unreadable 占位，
      // 与 readTextAttachmentContent 行为一致——不能让整次发送失败。
      debugPrint('[ChatProtocol] 附件读取失败: ${att.fileName}: $e');
      return const AttachmentReadOutcome(AttachmentReadStatus.unreadable, null);
    }
  }

  // 图片超过通用阈值 → 自动压缩（替代旧行为的"跳过"）
  String? mimeTypeOverride;
  if (att.fileType == 'image' && bytes.length > maxBytes) {
    // 1) 磁盘缓存优先：图片选中时后台预压缩 / 上次发送时压缩的产物
    //    （temp_compressed/<conversationId>/<hash>）。内存缓存
    //    （base64Data）在重启或历史重载后丢失，命中磁盘缓存即可
    //    零压缩等待复用，避免"每次发送都重新压缩"。
    CompressedImage? cached;
    if (att.conversationId != null && att.hash.isNotEmpty) {
      try {
        cached = await AttachmentStorage.readCompressedImage(
          conversationId: att.conversationId,
          hash: att.hash,
        );
        if (cached != null && cached.bytes.length > maxBytes) {
          cached = null; // 防御：超限缓存视为未命中，重新压缩
        }
      } catch (_) {
        cached = null; // 缓存 IO 失败不影响发送
      }
    }
    if (cached != null) {
      bytes = cached.bytes;
      mimeTypeOverride = _detectImagePayloadMimeType(bytes);
      att.compressedCachePersisted = true;
    } else {
      final compression = await compressImageForSend(
        bytes,
        maxBytes: maxBytes,
      );
      if (compression.decodable && compression.compressed != null) {
        bytes = compression.compressed!.bytes;
        mimeTypeOverride = compression.compressed!.mimeType;
        // 产物写入磁盘缓存：后续发送（含重启后）直接复用，不再等待
        if (att.conversationId != null && att.hash.isNotEmpty) {
          try {
            await AttachmentStorage.saveCompressedImage(
              conversationId: att.conversationId,
              hash: att.hash,
              bytes: bytes,
              mimeType: mimeTypeOverride,
            );
            att.compressedCachePersisted = true;
          } catch (e) {
            debugPrint('[ChatProtocol] 图片压缩缓存写入失败: $e');
          }
        }
      }
      // 压缩后仍超过 10MB 硬顶（无法解码的 HEIC/损坏文件，或病理级
      // 超大图在极限压缩下仍超限）：发送必然整条请求被 API 拒绝，且
      // 白白撑大请求体 → 保持"过大跳过"占位，让其余图片/文本正常发送。
      if (bytes.length > maxAttachmentBytes) {
        return const AttachmentReadOutcome(AttachmentReadStatus.tooLarge, null);
      }
      // 压缩后 > 阈值但 ≤ 硬顶（如 48MP 照片）：尽力发送
    }
  } else if (att.fileType == 'image' &&
      !att.compressedCachePersisted &&
      bytes.length <= maxBytes &&
      att.fileSize > maxBytes &&
      att.conversationId != null &&
      att.hash.isNotEmpty) {
    // 2) 内存缓存命中（选中时后台预压缩的结果，或上一轮压缩的缓存）：
    //    该附件在本次会话中尚未落盘压缩缓存（例如选中时对话尚未创建、
    //    旧数据），首次经过发送路径时补齐磁盘缓存，重启后不再等待。
    try {
      await AttachmentStorage.saveCompressedImage(
        conversationId: att.conversationId,
        hash: att.hash,
        bytes: bytes,
        mimeType: _detectImagePayloadMimeType(bytes) ?? att.mimeType,
      );
      att.compressedCachePersisted = true;
    } catch (e) {
      debugPrint('[ChatProtocol] 图片压缩缓存写入失败: $e');
    }
  }

  if (bytes.length > maxAttachmentBytes && att.fileType != 'image') {
    return const AttachmentReadOutcome(AttachmentReadStatus.tooLarge, null);
  }

  // 图片载荷的真实格式：压缩器没有产出格式的路径（缓存复用上一轮的
  // 压缩结果、无压缩收益、磁盘直读的旧数据）按魔数检测——否则 JPEG
  // 载荷会被声明成 att.mimeType（PNG），Anthropic 会整条 400。
  if (att.fileType == 'image' && mimeTypeOverride == null) {
    mimeTypeOverride = _detectImagePayloadMimeType(bytes);
  }

  final b64 = base64Encode(bytes);
  // 缓存（压缩后的）base64 供后续复用
  att.base64Data = b64;
  return AttachmentReadOutcome(AttachmentReadStatus.ok, b64,
      mimeType: mimeTypeOverride);
}

/// 按魔数检测图片载荷的真实格式（PNG/JPEG）。
/// 未知格式（GIF/WebP/BMP 等）返回 null，调用方保持 [Attachment.mimeType]
/// 声明。
String? _detectImagePayloadMimeType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return 'image/jpeg';
  }
  return null;
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

/// 读取文本类附件的内容，超长（>4000 字节）截断（UTF-8 边界安全）。
/// 失败返回 null。
Future<String?> readTextAttachmentContent(
  String fileName,
  String storagePath,
) async {
  try {
    final bytes = await AttachmentStorage.readFile(storagePath);
    if (bytes == null || bytes.isEmpty) return null;
    final textContent = utf8.decode(bytes);
    if (utf8.encode(textContent).length > 4000) {
      return '${truncateUtf8(textContent, 4000)}\n... [truncated]';
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
  try {
    return await AttachmentStorage.readFile(att.storagePath);
  } catch (e) {
    // 瞬时 IO 异常（权限、磁盘满等）：返回 null 走占位降级，
    // 不让整次发送失败。
    debugPrint('[ChatProtocol] 附件原始字节读取失败: ${att.fileName}: $e');
    return null;
  }
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
/// truncateUtf8 实现位于 context_manager（估算侧与发送侧共用，
/// 见其注释——token 估算与真实发送文本必须一致）。
String truncateToolOutput(String text) {
  // 按 UTF-8 字节截断（kToolOutputMaxChars 语义为字节上限，
  // 对齐 opencode TOOL_OUTPUT_MAX_CHARS），并回退到字符边界。
  if (utf8.encode(text).length <= kToolOutputMaxChars) return text;
  // 与 context_manager 的估算渲染共用同一后缀（kToolOutputTruncatedSuffix），
  // 保证 token 估算与真实发送文本一致。
  return '${truncateUtf8(text, kToolOutputMaxChars)}$kToolOutputTruncatedSuffix';
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
