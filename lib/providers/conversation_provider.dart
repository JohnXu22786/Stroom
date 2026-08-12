import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/assistant.dart';
import '../models/chat_message.dart';
import '../services/app_log_service.dart';
import 'assistant_provider.dart';

part 'conversation_notifier_persistence.dart';
part 'conversation_notifier_mutations.dart';

// ============================================================================
// Helper: auto-fix conversations with null assistantId
// ============================================================================

/// Ensures all conversations have an assigned assistantId.
///
/// On every load, any conversation with a null assistantId is assigned to the
/// default assistant. This replaces the old one-time migration flag approach
/// which failed if new null-assistantId conversations were created after the
/// migration flag was set, or if the default assistant wasn't persisted yet.
///
/// Returns true if any conversations were modified.
Future<bool> assignNullAssistantConversations(
    SharedPreferences prefs, List<Conversation> conversations) async {
  try {
    // Check if any conversation has null assistantId
    final hasNull = conversations.any((c) => c.assistantId == null);
    if (!hasNull) return false;

    // Resolve the default assistant ID
    final defaultId = await _resolveDefaultAssistantId(prefs);
    if (defaultId == null) return false;

    // Assign the default ID to all null-assistantId conversations
    bool changed = false;
    for (final conv in conversations) {
      if (conv.assistantId == null) {
        conv.assistantId = defaultId;
        changed = true;
      }
    }

    // Persist the fix
    if (changed) {
      await prefs.setString('conversations',
          jsonEncode(conversations.map((e) => e.toMap()).toList()));
      debugPrint(
          'Auto-assigned null-assistantId conversations to default assistant ($defaultId)');
    }

    return changed;
  } catch (e) {
    debugPrint('Failed to auto-assign null-assistantId conversations: $e');
    return false;
  }
}

/// Resolves the default assistant ID from in-memory state or SharedPreferences.
///
/// Tries in order:
/// 1. The first assistant from [assistantProvider] (in-memory, if initialized)
/// 2. The first assistant from SharedPreferences
/// 3. Creates a new default assistant and persists it
Future<String?> _resolveDefaultAssistantId(SharedPreferences prefs) async {
  // Try from SharedPreferences first (safe across provider boundaries)
  final assistantsJson = prefs.getString('assistants');
  if (assistantsJson != null && assistantsJson.isNotEmpty) {
    final list =
        (jsonDecode(assistantsJson) as List).cast<Map<String, dynamic>>();
    if (list.isNotEmpty) {
      return list.first['id'] as String;
    }
  }

  // No assistants exist yet - create a default one
  final defaultAssistant = Assistant(
    name: '默认助手',
    prompt: '你是一个有帮助的AI助手。请用中文回答用户的问题。',
    emoji: '🤖',
  );
  await prefs.setString('assistants', jsonEncode([defaultAssistant.toMap()]));
  debugPrint(
      'Created default assistant during migration (${defaultAssistant.id})');
  return defaultAssistant.id;
}

// ============================================================================
// Conversation model
// ============================================================================

class Conversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  List<ChatMessage> messages;
  bool isPinned;
  int sortOrder;
  String? assistantId;
  String draftText;

  /// 未发送的附件草稿（按对话隔离，与 [draftText] 一起持久化）。
  ///
  /// 图片附件带预压缩 base64（[Attachment.base64Data]，序列化时仅
  /// 携带已压缩完成的载荷，见 _saveDraftImmediately 的快照规则）；
  /// 文件/未压缩完成的图片只存引用（storagePath），恢复时重新读取。
  /// 发送成功后清空。
  List<Attachment> draftAttachments = [];

  /// Per-conversation set of MCP/built-in tool names that the user has enabled.
  /// Defaults to empty (interpreted by the chat page as "auto-enable all
  /// available tools" for new conversations; explicit empty is preserved
  /// via [hasExplicitEnabledMcpTools]).
  Set<String> enabledMcpToolNames = {};

  /// Whether the user has explicitly touched the MCP/built-in tool toggles
  /// in the "可用工具" panel for this conversation. Used to distinguish
  /// "new conversation — auto-enable all" (false) from "user toggled every
  /// tool off" (true). Persisted as a boolean flag so an explicit-empty
  /// set survives serialization.
  bool hasExplicitEnabledMcpTools = false;

  /// 上下文压缩产生的锚定摘要（对话被压缩过时为非空）。
  /// 注入后续请求的 system 级内容；UI 显示"上下文已压缩"banner。
  /// v3 原位演进：旧数据缺省 null。
  String? contextSummary;

  /// 压缩时记录的"尾部起点"消息 ID（对齐 opencode compaction part 的
  /// tail_start_id）。
  ///
  /// prune 扫描时遇到该消息即停止（它及其之前 = 已压缩内容，不再处理，
  /// 对齐 opencode "遇到 summary 消息 break loop" 的边界语义）。
  String? compactionTailStartId;

  /// 标题是否为自动生成（截断或 AI 标题）。
  /// true 表示用户可以放心让 AI 标题助手覆盖；
  /// false 表示用户手动改过，不得覆盖（opencode isDefaultTitle 语义）。
  bool titleAutoGenerated = false;

  /// The display name of the model that was last used to send a message
  /// in this conversation. When set, the chat page restores this model
  /// on re-entry, taking priority over the globally saved model index.
  /// Also pre-set at creation from the assistant's default model
  /// ([Assistant.defaultModelName]) so new topics honor the assistant
  /// defaults on first entry; the user's own switches afterwards always
  /// win (see [updateLastUsedModel]).
  /// Null for conversations that haven't used a specific model yet.
  String? lastUsedModelName;

  /// 最近一次请求的实际输入 token 数（来自 API 返回的 usage，非估算）。
  /// 用于标题栏下方的上下文显示与压缩触发判断。null = 尚无计量。
  int? lastInputTokens;

  /// 最近一次请求的实际输出 token 数（来自 API usage）。
  int? lastOutputTokens;

  /// 累计花费（美元）。每次请求完成后按模型价格累加。
  double totalCost = 0;

  Conversation({
    String? id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    this.isPinned = false,
    this.sortOrder = 0,
    this.assistantId,
    this.draftText = '',
    List<Attachment>? draftAttachments,
    Set<String>? enabledMcpToolNames,
    this.hasExplicitEnabledMcpTools = false,
    this.contextSummary,
    this.compactionTailStartId,
    this.titleAutoGenerated = false,
    this.lastUsedModelName,
    this.lastInputTokens,
    this.lastOutputTokens,
    this.totalCost = 0,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [],
        enabledMcpToolNames = enabledMcpToolNames ?? {},
        draftAttachments = draftAttachments ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
        'isPinned': isPinned,
        'sortOrder': sortOrder,
        if (assistantId != null) 'assistantId': assistantId,
        'draftText': draftText,
        // 草稿附件序列化时携带 base64Data：快照在 composer 侧已过滤
        // （仅图片的压缩产物），历史消息附件不走此路径不受影响。
        if (draftAttachments.isNotEmpty)
          'draftAttachments': draftAttachments
              .map((a) => a.toMap(includeBase64Data: true))
              .toList(),
        if (contextSummary != null) 'contextSummary': contextSummary,
        if (compactionTailStartId != null)
          'compactionTailStartId': compactionTailStartId,
        if (titleAutoGenerated) 'titleAutoGenerated': true,
        // Persist the explicit-empty flag so a user who toggled every tool
        // off doesn't accidentally get them all re-enabled next time.
        if (hasExplicitEnabledMcpTools) 'hasExplicitEnabledMcpTools': true,
        // Persist the set whenever the user has explicitly touched the toggles,
        // even if it's empty. Otherwise omit it so new conversations fall back
        // to the "auto-enable all" default.
        if (hasExplicitEnabledMcpTools)
          'enabledMcpToolNames': enabledMcpToolNames.toList(),
        if (lastUsedModelName != null && lastUsedModelName!.isNotEmpty)
          'lastUsedModelName': lastUsedModelName,
        if (lastInputTokens != null) 'lastInputTokens': lastInputTokens,
        if (lastOutputTokens != null) 'lastOutputTokens': lastOutputTokens,
        if (totalCost > 0) 'totalCost': totalCost,
      };

  factory Conversation.fromMap(Map<String, dynamic> map) {
    // Defensive DateTime parsing for createdAt
    DateTime? createdAt;
    final createdAtRaw = map['createdAt'];
    if (createdAtRaw != null && createdAtRaw is String) {
      try {
        createdAt = DateTime.parse(createdAtRaw);
      } catch (_) {
        createdAt = DateTime.now();
      }
    }

    // Defensive DateTime parsing for updatedAt
    DateTime? updatedAt;
    final updatedAtRaw = map['updatedAt'];
    if (updatedAtRaw != null && updatedAtRaw is String) {
      try {
        updatedAt = DateTime.parse(updatedAtRaw);
      } catch (_) {
        updatedAt = DateTime.now();
      }
    }

    // Defensive message parsing: skip invalid entries so a single corrupt
    // message does not prevent loading the entire conversation.
    List<ChatMessage> messages = [];
    final messagesRaw = map['messages'];
    if (messagesRaw is List) {
      for (final e in messagesRaw) {
        if (e is Map) {
          try {
            messages.add(ChatMessage.fromMap(Map<String, dynamic>.from(e)));
          } catch (_) {
            // Skip corrupt message — log is optional to avoid noise
          }
        }
      }
    }

    // 回填附件所属对话 ID（功能上线前的旧数据没有该字段）：
    // 图片压缩磁盘缓存按（对话, 哈希）定位，回填后旧对话的图片也能
    // 在发送时/选中后写入缓存，避免"重启后每次发送都重新压缩"。
    final backfillConvId = map['id'];
    if (backfillConvId is String && backfillConvId.isNotEmpty) {
      for (final m in messages) {
        for (final a in m.attachments) {
          a.conversationId ??= backfillConvId;
        }
      }
    }

    // Defensive draft attachment parsing（草稿附件，含图片压缩 base64）
    List<Attachment> draftAttachments = [];
    final draftAttsRaw = map['draftAttachments'];
    if (draftAttsRaw is List) {
      for (final e in draftAttsRaw) {
        if (e is Map) {
          try {
            final a = Attachment.fromMap(Map<String, dynamic>.from(e));
            if (a.fileName.isNotEmpty || a.storagePath.isNotEmpty) {
              a.conversationId ??=
                  backfillConvId is String ? backfillConvId : null;
              draftAttachments.add(a);
            }
          } catch (_) {
            // Skip corrupt draft attachment
          }
        }
      }
    }

    // Defensive enabledMcpToolNames parsing
    Set<String> enabledMcpToolNames = {};
    final toolsRaw = map['enabledMcpToolNames'];
    if (toolsRaw is List) {
      enabledMcpToolNames = toolsRaw.map((e) => e.toString()).toSet();
    }
    // 迁移：todowrite / todoread 已合并为单一 todowrite（读写一体）。
    // 旧数据里仅显式开启 todoread 的对话，把该偏好迁移为 todowrite，
    // 避免合并后 todo 工具在该对话中静默失效（仅开启 todoread 时
    // 新工具名不在启用集里，会被当成"未启用"）。
    if (enabledMcpToolNames.remove('todoread')) {
      enabledMcpToolNames.add('todowrite');
    }
    // hasExplicitEnabledMcpTools is true if the user has touched the toggles
    // for this conversation. Defaults to false (new conversation → auto-enable
    // all available tools). Persisted explicitly so an empty
    // enabledMcpToolNames set survives serialization.
    final hasExplicitRaw = map['hasExplicitEnabledMcpTools'];
    final hasExplicit = hasExplicitRaw is bool ? hasExplicitRaw : false;
    final lastUsedRaw = map['lastUsedModelName'];
    final lastUsedModel = lastUsedRaw is String ? lastUsedRaw : null;

    // 数值字段统一用 num 兼容（web 端 JSON 大整数可能反序列化为
    // double，如 sortOrder 存成 3.0）；类型不匹配时给默认值而非
    // 抛错丢弃整条对话（与 messages 逐条防御力度一致）。
    final sortOrderRaw = map['sortOrder'];
    final sortOrder = sortOrderRaw is num ? sortOrderRaw.toInt() : 0;
    final lastInputRaw = map['lastInputTokens'];
    final lastOutputRaw = map['lastOutputTokens'];
    final idRaw = map['id'];
    final titleRaw = map['title'];
    final assistantIdRaw = map['assistantId'];
    final draftRaw = map['draftText'];
    final contextSummaryRaw = map['contextSummary'];
    final tailStartRaw = map['compactionTailStartId'];
    final titleAutoRaw = map['titleAutoGenerated'];
    final isPinnedRaw = map['isPinned'];

    return Conversation(
      id: idRaw is String ? idRaw : null,
      title: titleRaw is String ? titleRaw : '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      messages: messages,
      isPinned: isPinnedRaw is bool ? isPinnedRaw : false,
      sortOrder: sortOrder,
      assistantId: assistantIdRaw is String ? assistantIdRaw : null,
      draftText: draftRaw is String ? draftRaw : '',
      draftAttachments: draftAttachments,
      enabledMcpToolNames: enabledMcpToolNames,
      hasExplicitEnabledMcpTools: hasExplicit,
      contextSummary: contextSummaryRaw is String ? contextSummaryRaw : null,
      compactionTailStartId: tailStartRaw is String ? tailStartRaw : null,
      titleAutoGenerated: titleAutoRaw is bool ? titleAutoRaw : false,
      lastUsedModelName: lastUsedModel,
      lastInputTokens: lastInputRaw is num ? lastInputRaw.toInt() : null,
      lastOutputTokens: lastOutputRaw is num ? lastOutputRaw.toInt() : null,
      totalCost:
          (map['totalCost'] is num) ? (map['totalCost'] as num).toDouble() : 0,
    );
  }

  @override
  String toString() => 'Conversation(id: $id, title: $title)';
}

// ============================================================================
// Providers
// ============================================================================

/// ID of the currently active conversation, or null if none is selected.
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

final conversationSearchQueryProvider = StateProvider<String>((ref) => '');

/// Persistent list of all conversations.
final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, List<Conversation>>((ref) {
  final notifier = ConversationsNotifier(ref);
  notifier._load();
  return notifier;
});

class ConversationsNotifier extends StateNotifier<List<Conversation>> {
  final Ref _ref;

  ConversationsNotifier(this._ref) : super([]);

  Timer? _persistTimer;

  /// Whether the initial async _load has completed at least once.
  /// Used to skip a no-op persist triggered before any data has loaded.
  bool _loadHasRun = false;

  @override
  void dispose() {
    _persistNow();
    super.dispose();
  }
}

// ============================================================================
// Legacy: one-time conversation migration (left for test compatibility)
// ============================================================================

/// One-time migration that assigns [assistantId] to all conversations
/// lacking one, guarded by a [migrated_old_conversations] flag.
///
/// Returns the migrated conversation list, or `null` if already done.
Future<List<Conversation>?> migrateConversationsFromPrefs(
    SharedPreferences prefs) async {
  try {
    if (prefs.getBool('migrated_old_conversations') == true) return null;

    final assistantsJson = prefs.getString('assistants');
    if (assistantsJson == null || assistantsJson.isEmpty) {
      final defaultAssistant = Assistant(
        name: '默认助手',
        prompt: '你是一个有帮助的AI助手。请用中文回答用户的问题。',
        emoji: '🤖',
      );
      await prefs.setString(
          'assistants', jsonEncode([defaultAssistant.toMap()]));
    }

    final refreshedJson = prefs.getString('assistants');
    if (refreshedJson == null || refreshedJson.isEmpty) return null;
    final tempList = jsonDecode(refreshedJson);
    if (tempList is! List) return null;
    final assistants = tempList.cast<Map<String, dynamic>>();
    if (assistants.isEmpty) return null;
    final defaultId = assistants.first['id'];
    if (defaultId is! String) return null;

    final conversationsJson = prefs.getString('conversations');
    if (conversationsJson == null || conversationsJson.isEmpty) return null;

    final tempConv = jsonDecode(conversationsJson);
    if (tempConv is! List) return null;
    final conversations = tempConv.cast<Map<String, dynamic>>();

    bool changed = false;
    for (final conv in conversations) {
      if (conv['assistantId'] == null) {
        conv['assistantId'] = defaultId;
        changed = true;
      }
    }

    if (changed) {
      await prefs.setString('conversations', jsonEncode(conversations));
    }

    await prefs.setBool('migrated_old_conversations', true);

    return conversations.map((e) => Conversation.fromMap(e)).toList();
  } catch (e) {
    debugPrint('migrateConversationsFromPrefs failed: $e');
    return null;
  }
}
