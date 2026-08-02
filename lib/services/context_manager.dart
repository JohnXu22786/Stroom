import '../models/chat_message.dart';
import '../models/message_block.dart';
import '../models/tool_call.dart';
import '../utils/token_estimator.dart';
// ============================================================================
// ContextManager — 上下文管理（工具 prune / 估算）
// ============================================================================
//
// 对齐 opencode 的 compaction.ts prune 语义：
// - 软删除：不物理删除消息，只把旧工具结果标记为 compacted（占位文本）
// - 从新到旧扫描，跳过最近 [tailUserTurns] 轮用户消息
// - 只统计 status == completed 的工具结果
// - 遇到已 compacted 的条目即停止（避免重复扫描）
// - 累计超过 [pruneProtectTokens] 后才开始收集；
//   收集总量超过 [pruneMinimumTokens] 才执行压缩
//
// 说明：当前历史消息发送到 API 时只含文本内容，工具结果不进请求体；
// prune 的真实收益是 UI 渲染与 SharedPreferences 持久化体积（长 agent
// 会话的工具结果会迅速膨胀）。占位文本保留在 result 中，未来若把
// 工具结果纳入 API 历史（Anthropic tool_result 配对），占位符直接生效。
// ============================================================================

/// 工具结果被压缩后的占位文本（与协议层一致，渲染时替换）。
const String kCompactedToolResultPlaceholder = '[旧工具结果已清除]';

/// 中断/未完成工具结果的占位文本（协议层历史重建引用）。
const String kInterruptedToolResultPlaceholder = '[工具执行被中断]';

/// 工具结果发送渲染的截断后缀（协议层 truncateToolOutput 共用，
/// 保证 token 估算与真实发送文本一致）。
const String kToolOutputTruncatedSuffix = '\n... [已截断]';

/// prune 保护的工具（对齐 opencode PRUNE_PROTECTED_TOOLS = ["skill"]）。
///
/// 状态性工具的结果即使过期也不 prune：todo 列表是 agent 的
/// 工作状态，清理后模型会丢失任务上下文。
const Set<String> kPruneProtectedTools = {'todowrite', 'todoread'};

class ContextManager {
  /// 压缩的最小可压缩量（token 估算值）：低于此值不执行。
  static const int pruneMinimumTokens = 20000;

  /// 保护期：从新到旧累计未超过此值前不收集。
  static const int pruneProtectTokens = 40000;

  /// 扫描时跳过最近 N 轮用户消息（保留最近上下文）。
  static const int defaultTailUserTurns = 2;

  /// 对历史执行工具结果 prune（软删除）。
  ///
  /// 返回新的历史列表；未发生压缩时返回原列表引用（调用方可据此判断）。
  /// 原 [history] 本身不被修改。
  static List<ChatMessage> pruneToolResults(
    List<ChatMessage> history, {
    int tailUserTurns = defaultTailUserTurns,
    int pruneMinimumTokens = pruneMinimumTokens,
    int pruneProtectTokens = pruneProtectTokens,

    /// 压缩边界（对齐 opencode "遇到 summary 消息 break loop"）：
    /// 对话被压缩过时传入尾部起点消息 ID（[Conversation.compactionTailStartId]），
    /// 扫描到该消息即停止——它及其之前是已压缩内容，不再处理。
    String? stopAtMessageId,
  }) {
    if (history.isEmpty) return history;

    // 从新到旧扫描，收集可压缩的工具结果
    var userTurns = 0;
    var collectedTokens = 0;
    final toPrune = <_PruneTarget>[];

    for (var i = history.length - 1; i >= 0; i--) {
      final msg = history[i];
      if (msg.role == 'user') {
        userTurns++;
        if (userTurns < tailUserTurns) continue;
      }
      if (userTurns < tailUserTurns) continue;

      // 压缩边界：到达尾部起点（已压缩内容）即停止
      if (stopAtMessageId != null && msg.id == stopAtMessageId) break;

      // 收集该消息内的工具结果
      final targets = _collectMessageToolResults(msg);
      if (targets == null) break; // 遇到已压缩的条目：整条链停止

      for (final t in targets) {
        collectedTokens += t.tokens;
        if (collectedTokens <= pruneProtectTokens) continue;
        toPrune.add(t);
      }
    }

    // 可压缩总量不足时不执行（opencode: pruned > PRUNE_MINIMUM 才落印）
    var prunedTokens = 0;
    for (final t in toPrune) {
      prunedTokens += t.tokens;
    }
    if (prunedTokens <= pruneMinimumTokens) {
      return history;
    }

    // 执行压缩：按消息重建，把目标工具结果替换为占位文本
    final prunedIds = toPrune.map((t) => t.key).toSet();
    final result = <ChatMessage>[];
    for (final msg in history) {
      final msgKeys = _collectMessageToolResults(msg);
      final hasTarget =
          msgKeys != null && msgKeys.any((t) => prunedIds.contains(t.key));
      if (!hasTarget) {
        result.add(msg);
        continue;
      }
      result.add(_compactMessage(msg, prunedIds));
    }
    return result;
  }

  /// 估算历史（含 system 提示词）的 token 数，供压缩触发判断。
  ///
  /// 估算**实际会发送到 API 的内容**：消息文本 + 附件文件名 +
  /// 工具定义 + 工具链重建（tool_calls 参数与渲染后的结果——
  /// 2K 截断 / compacted 占位 / 中断占位，与协议层渲染一致）。
  static int estimateHistoryTokens(
    List<ChatMessage> history, {
    String? assistantPrompt,
    List<ToolDefinition> tools = const [],
  }) {
    var total = 0;
    if (assistantPrompt != null && assistantPrompt.isNotEmpty) {
      total += estimateTokens(assistantPrompt);
    }
    for (final msg in history) {
      total += estimateTokens(msg.content);
      for (final att in msg.attachments) {
        // 附件只估算文件名（内容以 base64 或文本形式随消息发送）
        total += estimateTokens(att.fileName) + 8;
      }
      // 工具链重建进入请求体：按发送渲染估算
      final toolCalls = msg.toolCalls;
      if (toolCalls != null) {
        for (final tc in toolCalls) {
          total += estimateTokens(tc.name);
          total += estimateJsonTokens(tc.arguments);
          total += estimateTokens(_renderToolResult(tc));
        }
      }
    }
    for (final def in tools) {
      total += estimateJsonTokens(def.toJson());
    }
    return total;
  }
}

// ============================================================================
// 内部实现
// ============================================================================

/// 发送给模型时工具结果的渲染截断（与协议层 kToolOutputMaxChars 一致；
/// 本地常量避免循环 import）。
const int _kToolOutputRenderMaxChars = 2000;

/// 工具结果发送渲染（对齐协议层 rebuildToolResultText）：
/// compacted → 占位；completed → 2K 截断；其余 → 中断占位。
String _renderToolResult(ToolCallData tc) {
  if (tc.compactedAt != null) {
    return kCompactedToolResultPlaceholder;
  }
  if (tc.status == ToolCallStatus.completed && tc.result != null) {
    final r = tc.result!;
    return r.length > _kToolOutputRenderMaxChars
        ? '${r.substring(0, _kToolOutputRenderMaxChars)}$kToolOutputTruncatedSuffix'
        : r;
  }
  return kInterruptedToolResultPlaceholder;
}

/// 一个可压缩的工具结果条目。
class _PruneTarget {
  /// 唯一标识（消息索引 + 工具 id），用于压缩时定位。
  final String key;
  final int tokens;

  const _PruneTarget(this.key, this.tokens);
}

/// 标记：消息内存在已压缩条目（扫描停止信号）。
class _CompactedMarker extends _PruneTarget {
  const _CompactedMarker() : super('', 0);
}

/// 收集单条消息内的可压缩工具结果。
///
/// 返回 null 表示该消息内已有已压缩条目（扫描应立即停止，opencode
/// `break loop` 语义：prune 边界之后不再扫描更早的消息）。
/// 返回空列表表示无可压缩条目（继续扫描更早的消息）。
///
/// toolCalls 与 blocks 是同一工具结果的双写（persistence 冗余），
/// 按工具 id 去重，避免同一结果被重复计入阈值。
/// 受保护的工具（[kPruneProtectedTools]，状态性）不参与。
List<_PruneTarget>? _collectMessageToolResults(ChatMessage msg) {
  final targets = <_PruneTarget>[];
  final seenIds = <String>{};

  void collect(String id, String name, String? result, DateTime? compactedAt) {
    if (compactedAt != null) {
      targets.clear();
      targets.add(_CompactedMarker());
      return;
    }
    // 受保护的工具（对齐 opencode PRUNE_PROTECTED_TOOLS）：不 prune
    if (kPruneProtectedTools.contains(name)) return;
    if (result == null || result.isEmpty) return;
    if (!seenIds.add(id)) return; // 双写去重
    targets.add(_PruneTarget(
      '${msg.id}:$id',
      estimateTokens(result),
    ));
  }

  // toolCalls 与 blocks 可能同时存在（双写），统一收集（按 id 去重）。
  // 对齐 opencode：消息内**从新到旧**扫描（parts 倒序）——
  // 同一消息内较新的工具先进保护窗（40K），更旧的才被收集。
  final toolCalls = msg.toolCalls;
  if (toolCalls != null) {
    for (final tc in toolCalls.reversed) {
      if (tc.status != ToolCallStatus.completed) continue;
      collect(tc.id, tc.name, tc.result, tc.compactedAt);
    }
  }
  final blocks = msg.blocks;
  if (blocks != null) {
    for (final b in blocks.reversed) {
      if (b is ToolCallBlock) {
        if (b.status != ToolCallStatus.completed) continue;
        collect(b.id, b.name, b.result, b.compactedAt);
      }
    }
  }
  if (targets.any((t) => t is _CompactedMarker)) return null;
  return targets;
}

/// 重建消息：把 [prunedIds] 命中的工具结果**标记**为已压缩。
///
/// 对齐 opencode prune 语义：**只软删除（标记 compactedAt），
/// 不物理删除 result 数据**——UI/存储中完整结果仍可查看（占位符
/// 由协议层 rebuildToolResultText 在发送/渲染时应用），
/// 仅发送给模型时（历史重建）渲染为占位符释放上下文。
ChatMessage _compactMessage(ChatMessage msg, Set<String> prunedIds) {
  List<ToolCallData>? newToolCalls;
  final toolCalls = msg.toolCalls;
  if (toolCalls != null) {
    var changed = false;
    final list = <ToolCallData>[];
    for (final tc in toolCalls) {
      final key = '${msg.id}:${tc.id}';
      if (prunedIds.contains(key) && tc.compactedAt == null) {
        list.add(tc.copyWith(compactedAt: DateTime.now()));
        changed = true;
      } else {
        list.add(tc);
      }
    }
    if (changed) newToolCalls = list;
  }

  List<MessageBlock>? newBlocks;
  final blocks = msg.blocks;
  if (blocks != null) {
    var changed = false;
    final list = <MessageBlock>[];
    for (final b in blocks) {
      if (b is ToolCallBlock) {
        final key = '${msg.id}:${b.id}';
        if (prunedIds.contains(key) && b.compactedAt == null) {
          list.add(b.copyWith(compactedAt: DateTime.now()));
          changed = true;
        } else {
          list.add(b);
        }
      } else {
        list.add(b);
      }
    }
    if (changed) newBlocks = list;
  }

  if (newToolCalls == null && newBlocks == null) return msg;
  return msg.copyWith(toolCalls: newToolCalls, blocks: newBlocks);
}
