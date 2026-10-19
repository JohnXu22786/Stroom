import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../models/assistant.dart'
    show Assistant, AssistantSettings, CustomParameter;
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/mcp.dart';
import '../models/tool_call.dart';
import '../providers/chat_api_provider.dart';
import '../providers/llm_routed_chat_provider.dart';
import '../providers/provider_config.dart';
import '../utils/provider_models.dart'
    show flattenProviderModels, resolveProviderModel;
import 'llm_chat_runtime.dart';
import 'llm_model_group_provider.dart';
import 'chat_protocol.dart';
import 'chat_service.dart';
import 'http_tool_service.dart';
import 'mcp_client.dart';
import 'todo_tool_service.dart';
import 'web_search_service.dart';

part 'chat_adapter_mcp.dart';
part 'chat_adapter_http_tools.dart';

/// Built-in search integrations are configured alongside MCP providers and
/// follow the MCP master switch, even though their handlers are registered
/// locally rather than discovered from an MCP server.
const kMcpSearchToolNames = <String>{
  'brave_web_search',
  'bocha_web_search',
  'querit_search',
  'searxng_search',
  'web_search',
};

bool isMcpMasterSwitchEnabled(ProviderEntriesState entriesState) {
  if (!entriesState.isLoaded) return false;
  final mcpEntry = entriesState.entries
      .where((entry) => entry.type == 'mcp')
      .firstOrNull;
  return mcpEntry?.enabled ?? true;
}

List<ToolDefinition> filterMcpSearchToolDefinitions(
  List<ToolDefinition> tools, {
  required bool mcpEnabled,
}) {
  if (mcpEnabled) return tools;
  return tools
      .where((tool) => !kMcpSearchToolNames.contains(tool.name))
      .toList();
}

/// 表示一个可选的模型项
class AvailableModel {
  /// 显示名："[model.name ?? model.modelId] | [providerName]"
  final String displayName;

  /// Model reference used by assistant settings and conversation history.
  /// Routed group models may use an opaque stable member ID here.
  final String modelId;

  /// 供应商名称（与 [displayName] 中的供应商部分一致）
  final String providerName;

  /// Stable group identity for opaque routed-member references.
  final String? modelGroupId;

  /// 指向 llmEntry.configs[configIndex]
  final int configIndex;

  /// 指向 configs[configIndex].models[modelIndex]
  final int modelIndex;

  const AvailableModel({
    required this.displayName,
    this.modelId = '',
    this.providerName = '',
    this.modelGroupId,
    required this.configIndex,
    required this.modelIndex,
  });
}

/// 桥接层：将我们的供应商/模型配置系统适配到 flutter_chat_ui 的流式调用
class ChatAdapter {
  final Future<LlmChatRoutingRuntime>? _routingRuntime;

  ChatAdapter({Future<LlmChatRoutingRuntime>? routingRuntime})
    : _routingRuntime = routingRuntime;

  /// Per-conversation ChatService instances, keyed by conversation ID.
  /// Each conversation gets its own independent HTTP connection, enabling
  /// multiple conversations to stream concurrently without interference.
  final Map<String, ChatService> _activeServices = {};

  /// 按对话登记的任务瞬时 service（压缩等内部任务），keyed by convId。
  ///
  /// 内部任务运行在独立的一次性 [ChatService] 上（不进入
  /// [_activeServices]），取消对话时同样需要中止其未完成的请求，
  /// 否则在途压缩请求会继续执行并可能写入用户可见状态。
  final Map<String, ChatService> _pendingTaskServices = {};

  /// Cached parts of the last [configure] / [selectModel] call, used as
  /// a template to create new per-conversation services on demand.
  BaseChatProvider? _cachedProvider;
  ModelConfig? _cachedModelConfig;
  ProviderConfigItem? _cachedProviderConfig;

  /// 有效端点类型（模型覆盖 > 供应商 > 'openai'），
  /// 由 [configure] / [selectModel] 解析并缓存，用于创建协议与服务。
  String _cachedEndpointType = 'openai';

  /// 当前有效端点类型（'openai' | 'anthropic'）。
  String get endpointType => _cachedEndpointType;

  /// 当前缓存的模型配置（供上下文管理估算用）。
  ModelConfig? get modelConfig => _cachedModelConfig;

  /// Stable identity of the endpoint used for an unbound assistant's next
  /// request. Flow launches capture it before their execution is queued.
  Map<String, String>? get selectedProviderModelReference {
    final config = _cachedProviderConfig;
    final model = _cachedModelConfig;
    if (config == null || model == null) return null;
    return {'configId': config.id, 'modelId': model.id};
  }

  /// 当前缓存的对话助手 system prompt（供上下文管理注入用）。
  String? get assistantPrompt => _cachedAssistantPrompt;

  /// 当前缓存的对话助手设置（供上下文管理估算用：
  /// 工具结果渲染截断上限与发送侧保持同一来源）。
  AssistantSettings? get assistantSettings => _cachedAssistantSettings;

  /// The first active [ChatService] instance, or null if none are running.
  /// **Warning**: nondeterministic when multiple conversations are streaming
  /// concurrently. Use [getOrCreateService] with an explicit convId for
  /// per-conversation access.
  ChatService? get currentChatService => _activeServices.values.firstOrNull;

  /// MCP 客户端管理器
  final McpClientManager _mcpClientManager = McpClientManager();

  /// 缓存的 MCP 工具列表（占位工具定义）
  List<ToolDefinition> _mcpToolDefinitions = [];

  /// Built-in search tools use local handlers but belong to the MCP provider
  /// group, so their selectable definitions follow its master switch.
  bool _mcpMasterSwitchEnabled = false;

  /// 上一份已处理的 MCP 供应商条目实例。
  ///
  /// 用于跳过重复初始化：页面重复进入、或其它供应商（TTS/OCR 等）配置
  /// 变更时，MCP 条目与组别可用状态都不变，跳过占位符/客户端重建。
  /// MCP 条目或组别列表变化时触发重建。
  ProviderEntry? _lastMcpEntry;
  List<McpProviderGroup>? _lastMcpGroups;
  Map<String, Object> _lastMcpConfigSourcesByName = {};
  Set<String> _disabledMcpToolNames = {};

  /// 当前选中的配置索引（指向 llmEntry.configs）
  int currentConfigIndex = -1;

  /// 当前选中的模型索引（指向 configs[currentConfigIndex].models）
  int currentModelIndex = -1;

  bool get isConfigured => _cachedProvider != null;

  /// Whether the current model has reasoning parameters configured.
  /// A model with only an empty toggle (all fields empty) has no reasoning
  /// params configured, so the chat page should not show the reasoning toggle.
  /// Provider-level reasoning params count too: a provider-declared toggle
  /// or effort param is enough to enable the chat reasoning UI.
  bool get hasReasoningParams {
    final config = _cachedModelConfig;
    if (config == null) return false;
    final merged = reasoningParams;
    if (merged.isEmpty) return false;
    // At least one param must be actually configured (not all-empty toggle)
    return merged.any((rp) {
      if (rp.isReasoningToggle) {
        return rp.isFilledToggle;
      }
      return rp.paramName.trim().isNotEmpty;
    });
  }

  /// Gets the reasoning parameters for the current model, merged with the
  /// provider-level reasoning params (model params override provider params
  /// with the same name, mirroring the request-building merge in
  /// ChatService._buildExtraParams). The chat UI consumes this merged view
  /// so provider-declared params (e.g. the effort param name) work even
  /// when the model itself doesn't define them.
  ///
  /// 力度参数遮蔽：模型有自己的力度参数（含旧数据回退识别）时，
  /// 供应商的力度参数被模型版本遮蔽——从合并视图中移除，避免
  /// 不可见的陈旧参数（陈旧值会注入请求且 UI 无法清除）。
  ///
  /// Provider-origin params are returned as copies: the chat panel toggles
  /// `param.enabled` in place on these objects, and writing through to the
  /// shared provider config would corrupt every model of the provider (and
  /// the next provider-settings save). Model params keep the pre-existing
  /// live-reference behavior (per-model cached config, replaced on model
  /// switch).
  List<ReasoningParam> get reasoningParams {
    final config = _cachedModelConfig;
    if (config == null) return const [];
    final providerParams = _cachedProviderConfig?.reasoningParams ?? [];
    // 力度参数模型优先（对模型列表独立解析：旧数据回退不被供应商的
    // 现代参数干扰）
    final modelEffort = findEffortParam(config.reasoningParams);
    var merged = mergeReasoningParams(providerParams, config.reasoningParams);
    if (modelEffort != null) {
      merged = merged
          .where((p) => !p.isEffortParam || p == modelEffort)
          .toList();
    }
    final providerNames = providerParams
        .map((p) => p.paramName.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    final modelNames = config.reasoningParams
        .map((p) => p.paramName.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    return merged.map((p) {
      final name = p.paramName.trim();
      final isProviderOrigin =
          name.isNotEmpty &&
          providerNames.contains(name) &&
          !modelNames.contains(name);
      return isProviderOrigin ? p.copy() : p;
    }).toList();
  }

  /// 获取当前 MCP 工具定义列表
  List<ToolDefinition> get mcpToolDefinitions =>
      List.unmodifiable(_mcpToolDefinitions);

  // ── Per-conversation service management ───────────────────────────────

  /// Creates (or returns an existing) [ChatService] for the given
  /// conversation. Each conversation gets an independent HTTP connection,
  /// enabling concurrent streaming across multiple conversations.
  /// Returns null when no requested or cached model can be resolved.
  ///
  /// When [assistant] is provided (with [entriesState]), the service is
  /// built from the assistant's bound model (its `modelId`) and carries
  /// the assistant's prompt/settings — the global cached model selection
  /// is NOT touched, so a task-flow chat block and the chat page can run
  /// concurrently with different models/assistants. The assistant model
  /// resolution does NOT depend on the global cache: it works even in a
  /// fresh session where the chat page was never opened. If an assistant has
  /// a configured model reference and it cannot be resolved, this returns null
  /// instead of silently switching to the global model.
  /// An explicit [modelReference] selects exact local config/model IDs from
  /// [entriesState], independently of the global cache. An unresolved explicit
  /// reference cannot fall back to another model.
  ChatService? getOrCreateService(
    String convId, {
    Assistant? assistant,
    ProviderEntriesState? entriesState,
    Map<String, String>? modelReference,
  }) {
    if (modelReference != null) {
      final selected = entriesState == null
          ? null
          : resolveProviderModel(entriesState, 'llm', modelReference);
      if (selected == null) return null;
      final config = selected.config;
      final model = selected.model;
      final endpointType = effectiveEndpointType(
        model.endpointType,
        config.endpointType,
      );
      return _activeServices.putIfAbsent(
        convId,
        () => _buildService(
          _providerForModel(config, model, endpointType),
          model,
          config,
          endpointType,
          assistant: assistant,
        ),
      );
    }
    if (assistant != null && entriesState != null) {
      // The assistant editor stores the default model as a DISPLAY name
      // (Assistant.defaultModelName) plus its absolute identity
      // (Assistant.defaultModelId / defaultProviderName); Assistant.modelId
      // stays null unless set elsewhere. Resolve the absolute identity
      // first, then the display name, so a chat block honors the
      // assistant's configured default model even after renames.
      // 仅当走默认模型引用时才带供应商名消歧：绑定模型（modelId）没有
      // 供应商信息，带上的话可能把同一 modelId 的错误供应商配对。
      final useDefaultRef =
          assistant.modelId == null || assistant.modelId!.isEmpty;
      final hasBoundModelId = assistant.modelId?.isNotEmpty == true;
      final modelRef = hasBoundModelId
          ? assistant.modelId
          : assistant.defaultModelId?.isNotEmpty == true
          ? assistant.defaultModelId
          : null;
      final resolved = _resolveAssistantModel(
        modelRef,
        entriesState,
        providerName: useDefaultRef ? assistant.defaultProviderName : null,
        modelDisplayName: hasBoundModelId
            ? assistant.modelId
            : assistant.defaultModelName,
      );
      if (resolved != null) {
        final (config, modelConfig) = resolved;
        final endpointType = effectiveEndpointType(
          modelConfig.endpointType,
          config.endpointType,
        );
        final provider = _providerForModel(config, modelConfig, endpointType);
        return _activeServices.putIfAbsent(convId, () {
          return _buildService(
            provider,
            modelConfig,
            config,
            endpointType,
            assistant: assistant,
          );
        });
      }
    }

    if (_hasConfiguredAssistantModelReference(assistant)) return null;

    // Fallback: the global cached model (requires the adapter to have
    // been configured — e.g. the chat page opened this session).
    // 先返回该对话已有的 service（可能是带 assistant 绑定的路径创建的），
    // 避免全局缓存为空（如本会话尚未打开过对话页）时误判为未配置——
    // 上下文压缩等内部调用依赖这里拿到与主请求一致的模型身份。
    final existing = _activeServices[convId];
    if (existing != null) return existing;
    if (_cachedProvider == null || _cachedModelConfig == null) return null;
    return _activeServices.putIfAbsent(convId, () {
      final svc = _buildService(
        _cachedProvider!,
        _cachedModelConfig!,
        _cachedProviderConfig,
        _cachedEndpointType,
        assistant: assistant,
      );
      return svc;
    });
  }

  ChatService _buildService(
    BaseChatProvider provider,
    ModelConfig modelConfig,
    ProviderConfigItem? providerConfig,
    String endpointType, {
    Assistant? assistant,
  }) {
    final svc = ChatService(
      provider: provider,
      modelConfig: modelConfig,
      providerConfig: providerConfig,
      endpointType: endpointType,
    );
    // Apply the assistant prompt/settings (explicit assistant wins over
    // the global cached assistant template).
    final prompt = assistant?.prompt ?? _cachedAssistantPrompt;
    final settings = assistant?.settings ?? _cachedAssistantSettings;
    final customParams =
        assistant?.settings.customParameters ?? _cachedAssistantCustomParams;
    if (prompt != null) {
      svc.setAssistantPrompt(prompt);
    }
    if (settings != null) {
      svc.setAssistantSettings(settings);
    }
    if (customParams != null) {
      svc.setAssistantCustomParams(customParams);
    }
    return svc;
  }

  /// Resolves an assistant's bound model (its `modelId`) to its
  /// (config, model) pair within the LLM provider entries.
  ///
  /// Matches by (providerName, modelId) first when a provider was saved,
  /// then by modelId alone only for provider-less references, then by the
  /// model's display name (`name | providerName`) within the saved provider.
  /// The assistant editor stores the default model as its DISPLAY name
  /// ([Assistant.defaultModelName]) plus its absolute identity
  /// ([Assistant.defaultModelId] / [Assistant.defaultProviderName]),
  /// while `Assistant.modelId` stays null unless set elsewhere — matching
  /// on the absolute identity lets a chat block honor the assistant's
  /// configured default model even after renames.
  (ProviderConfigItem, ModelConfig)? _resolveAssistantModel(
    String? modelRef,
    ProviderEntriesState entriesState, {
    String? providerName,
    String? modelDisplayName,
  }) {
    if ((modelRef == null || modelRef.isEmpty) &&
        (modelDisplayName == null || modelDisplayName.isEmpty)) {
      return null;
    }
    return _resolveModelRefPair(
      entriesState,
      modelId: modelRef,
      providerName: providerName,
      modelDisplayName: modelDisplayName,
    );
  }

  /// 按模型引用解析唯一的 (config, model) 对。
  ///
  /// Provider/model identity remains the primary match. If multiple stable
  /// groups preserve that same legacy pair, the saved display name can
  /// disambiguate them. Opaque custom-group member IDs already encode the
  /// stable group identity, so they survive changes to the group's provider
  /// display name. Unresolved ambiguity returns null instead of picking the
  /// first group.
  (ProviderConfigItem, ModelConfig)? _resolveModelRefPair(
    ProviderEntriesState entriesState, {
    String? modelId,
    String? providerName,
    String? modelDisplayName,
  }) {
    final llmEntry = entriesState.entries
        .where((e) => e.type == 'llm')
        .firstOrNull;
    if (llmEntry == null) return null;

    final candidates = flattenProviderModels(
      ProviderEntriesState(entries: [llmEntry]),
      'llm',
      includeUnavailableGroupModels: true,
    ).map((selected) => (selected.config, selected.model)).toList();

    bool matchesDisplayName((ProviderConfigItem, ModelConfig) pair) {
      final (config, model) = pair;
      final displayName =
          '${model.name.isNotEmpty ? model.name : model.modelId} | ${config.providerName}';
      return modelDisplayName != null &&
          modelDisplayName.isNotEmpty &&
          displayName == modelDisplayName;
    }

    final id = modelId;
    if (id != null && id.isNotEmpty) {
      final idMatches = candidates
          .where((pair) => pair.$2.modelId == id)
          .toList(growable: false);
      final hasProvider = providerName != null && providerName.isNotEmpty;
      final providerMatches = hasProvider
          ? idMatches
                .where((pair) => pair.$1.providerName == providerName)
                .toList(growable: false)
          : const <(ProviderConfigItem, ModelConfig)>[];
      final groupReference = llmModelGroupMemberReferenceForModelId(id);
      final stableGroupMatches = groupReference == null
          ? const <(ProviderConfigItem, ModelConfig)>[]
          : idMatches
                .where(
                  (pair) =>
                      llmModelGroupIdForConfig(pair.$1) ==
                          groupReference.groupId &&
                      pair.$2.id == groupReference.localModelId,
                )
                .toList(growable: false);
      final preferred = hasProvider
          ? providerMatches.isNotEmpty
                ? providerMatches
                : stableGroupMatches
          : idMatches;
      if (preferred.length == 1) return preferred.single;
      if (preferred.length > 1) {
        final byName = preferred.where(matchesDisplayName).toList();
        return byName.length == 1 ? byName.single : null;
      }
      // A saved stable ID is authoritative. Display-name lookup remains for
      // legacy references that never stored an ID, not as a replacement when
      // the referenced group has disappeared.
      return null;
    }

    if (modelDisplayName != null && modelDisplayName.isNotEmpty) {
      final byName = candidates
          .where(matchesDisplayName)
          .where(
            (pair) =>
                providerName == null ||
                providerName.isEmpty ||
                pair.$1.providerName == providerName,
          )
          .toList();
      if (byName.length == 1) return byName.single;
    }
    return null;
  }

  /// 创建一次性 [ChatService]（不缓存、不进入 _activeServices）。
  ///
  /// 供 fire-and-forget 内部任务（如标题生成）使用：若通过
  /// [getOrCreateService] 创建会被 putIfAbsent 缓存，下次流的
  /// cancelService 不会移除它，导致模型切换被旧配置 service 吞掉
  /// （"UI 显示模型 B、请求走模型 A"）。用后即弃，随 GC 回收。
  /// 返回 null 表示 adapter 尚未配置当前模型。
  ChatService? createTransientService() {
    if (_cachedProvider == null || _cachedModelConfig == null) return null;
    return _buildTransientService(
      _cachedProvider!,
      _cachedModelConfig!,
      _cachedProviderConfig,
      _cachedEndpointType,
    );
  }

  /// 按系统助手任务的模型引用创建一次性 [ChatService]。
  ///
  /// 供标题生成 / 上下文压缩等内部任务使用：任务的模型与对话页当前
  /// 模型独立（设置面板可单独指定）。仅当没有配置模型引用时才
  /// 回退到 [createTransientService]；已配置但无法解析时返回 null。
  /// 与 [createTransientService] 一样：不缓存、不进入 _activeServices。
  ///
  /// 传入 [convId] 时注册到 [_pendingTaskServices]，后续
  /// [cancelService]（对话流取消、切换）会中止其中的在途请求——
  /// 压缩请求运行在独立 service 上，不注册则取消对话时压缩请求
  /// 仍会执行完并污染结果。
  ChatService? createTransientServiceForModel({
    required ProviderEntriesState entriesState,
    String? modelId,
    String? providerName,
    String? modelDisplayName,
    String? convId,
  }) {
    final hasConfiguredReference =
        (modelId != null && modelId.isNotEmpty) ||
        (modelDisplayName != null && modelDisplayName.isNotEmpty);
    final resolved = _resolveModelRefPair(
      entriesState,
      modelId: modelId,
      providerName: providerName,
      modelDisplayName: modelDisplayName,
    );
    ChatService? svc;
    if (resolved != null) {
      final (config, modelConfig) = resolved;
      final endpointType = effectiveEndpointType(
        modelConfig.endpointType,
        config.endpointType,
      );
      final provider = _providerForModel(config, modelConfig, endpointType);
      svc = _buildTransientService(provider, modelConfig, config, endpointType);
    } else if (!hasConfiguredReference) {
      svc = createTransientService();
    } else {
      return null;
    }
    if (svc == null) return null;
    if (convId != null && convId.isNotEmpty) {
      // 同对话的新任务注册时释放旧的瞬时 service（防御：正常流程
      // 下同一对话同一时刻只有一个任务在途，取消路径会先移除）。
      final prev = _pendingTaskServices[convId];
      prev?.cancel();
      prev?.dispose();
      _pendingTaskServices[convId] = svc;
    }
    return svc;
  }

  bool _hasConfiguredAssistantModelReference(Assistant? assistant) =>
      assistant != null &&
      ((assistant.modelId != null && assistant.modelId!.isNotEmpty) ||
          (assistant.defaultModelId != null &&
              assistant.defaultModelId!.isNotEmpty) ||
          (assistant.defaultModelName != null &&
              assistant.defaultModelName!.isNotEmpty));

  /// 用模板配置（缓存/覆盖值）构建一次性 [ChatService]。
  ChatService _buildTransientService(
    BaseChatProvider provider,
    ModelConfig modelConfig,
    ProviderConfigItem? providerConfig,
    String endpointType,
  ) {
    final svc = ChatService(
      provider: provider,
      modelConfig: modelConfig,
      providerConfig: providerConfig,
      endpointType: endpointType,
    );
    if (_cachedAssistantPrompt != null) {
      svc.setAssistantPrompt(_cachedAssistantPrompt);
    }
    if (_cachedAssistantSettings != null) {
      svc.setAssistantSettings(_cachedAssistantSettings);
    }
    if (_cachedAssistantCustomParams != null) {
      svc.setAssistantCustomParams(_cachedAssistantCustomParams);
    }
    return svc;
  }

  /// Cancels and disposes the [ChatService] for [convId].
  void cancelService(String convId) {
    final svc = _activeServices.remove(convId);
    svc?.cancel();
    svc?.dispose();
    // 同步中止该对话的任务瞬时服务（压缩等）。
    releaseTaskService(convId);
  }

  /// 释放已完成的对话任务瞬时 service（压缩请求结束后调用）。
  ///
  /// 与 [cancelService] 中的清理幂等：若已被取消移除则为空操作。
  void releaseTaskService(String convId) {
    final taskSvc = _pendingTaskServices.remove(convId);
    taskSvc?.cancel();
    taskSvc?.dispose();
  }

  /// Cancels and disposes ALL per-conversation services.
  void cancelAllServices() {
    for (final svc in _activeServices.values) {
      svc.cancel();
      svc.dispose();
    }
    _activeServices.clear();
    for (final svc in _pendingTaskServices.values) {
      svc.cancel();
      svc.dispose();
    }
    _pendingTaskServices.clear();
  }

  // Cached assistant config applied to newly created services.
  String? _cachedAssistantPrompt;
  AssistantSettings? _cachedAssistantSettings;
  List<CustomParameter>? _cachedAssistantCustomParams;

  /// Register HTTP tool handlers in ChatService (idempotent — uses static flag)
  static bool _httpToolsRegistered = false;

  /// 从 ProviderEntriesState 解析出所有可选的模型列表
  List<AvailableModel> availableModels(ProviderEntriesState entriesState) =>
      availableLlmModels(entriesState);

  /// 从 ProviderEntriesState 读取 LLM 配置并初始化 ChatService
  void configure(ProviderEntriesState entriesState) {
    final llmEntry = entriesState.entries
        .where((e) => e.type == 'llm')
        .firstOrNull;
    final firstModel = availableLlmModels(entriesState).firstOrNull;
    if (llmEntry == null || firstModel == null) {
      debugPrint('ChatAdapter.configure: no LLM entry or configs');
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      _cachedEndpointType = 'openai';
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final config = llmEntry.configs[firstModel.configIndex];
    final modelConfig = config.models[firstModel.modelIndex];
    final endpointType = effectiveEndpointType(
      modelConfig.endpointType,
      config.endpointType,
    );
    debugPrint(
      'ChatAdapter.configure: host=${config.host} model=${modelConfig.modelId} '
      'endpoint=$endpointType',
    );
    final provider = _providerForModel(config, modelConfig, endpointType);
    _cachedProvider = provider;
    _cachedModelConfig = modelConfig;
    _cachedProviderConfig = config;
    _cachedEndpointType = endpointType;
    currentConfigIndex = firstModel.configIndex;
    currentModelIndex = firstModel.modelIndex;
  }

  /// 根据 configIndex / modelIndex 更新模板配置
  /// Existing per-conversation services keep their old config until the
  /// conversation's stream completes; new streams pick up the updated model.
  void selectModel(
    ProviderEntriesState entriesState,
    int configIndex,
    int modelIndex,
  ) {
    final llmEntry = entriesState.entries
        .where((e) => e.type == 'llm')
        .firstOrNull;
    if (llmEntry == null ||
        configIndex < 0 ||
        configIndex >= llmEntry.configs.length) {
      debugPrint('ChatAdapter.selectModel: invalid configIndex=$configIndex');
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      _cachedEndpointType = 'openai';
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final config = llmEntry.configs[configIndex];
    if (!isLlmModelGroupProviderConfig(config) &&
        (config.host.isEmpty || config.key.isEmpty)) {
      debugPrint(
        'ChatAdapter.selectModel: config[$configIndex] host or key empty',
      );
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      _cachedEndpointType = 'openai';
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    if (modelIndex < 0 || modelIndex >= config.models.length) {
      debugPrint('ChatAdapter.selectModel: invalid modelIndex=$modelIndex');
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      _cachedEndpointType = 'openai';
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final modelConfig = config.models[modelIndex];
    final endpointType = effectiveEndpointType(
      modelConfig.endpointType,
      config.endpointType,
    );
    debugPrint(
      'ChatAdapter.selectModel: using config[$configIndex] '
      'host=${config.host} model=${modelConfig.modelId} endpoint=$endpointType',
    );
    final provider = _providerForModel(config, modelConfig, endpointType);
    _cachedProvider = provider;
    _cachedModelConfig = modelConfig;
    _cachedProviderConfig = config;
    _cachedEndpointType = endpointType;
    currentConfigIndex = configIndex;
    currentModelIndex = modelIndex;
  }

  /// 取消所有活跃流的 HTTP 请求
  void cancel() {
    for (final svc in _activeServices.values) {
      svc.cancel();
    }
  }

  BaseChatProvider _providerForModel(
    ProviderConfigItem config,
    ModelConfig model,
    String endpointType,
  ) {
    final routingRuntime = _routingRuntime;
    if (routingRuntime != null) {
      return LlmRoutedChatProvider(
        runtime: routingRuntime,
        groupId:
            llmModelGroupIdForConfig(config) ??
            stableLlmModelGroupId(config.id, model.id),
        localModelId: model.id,
        endpointType: endpointType,
      );
    }
    return createChatProviderFromConfig(
      providerName: config.providerName,
      baseUrl: config.host,
      apiKey: config.key,
      endpointType: endpointType,
    );
  }

  /// Injects a [ChatService] instance for testing.
  /// Stores it as the template for future per-conversation services.
  @visibleForTesting
  void forceService(ChatService service) {
    // Extract config from the service for use as template.
    // ignore: invalid_use_of_visible_for_testing_member
    _cachedProvider = service.provider;
    _cachedModelConfig = service.modelConfig;
    // ignore: invalid_use_of_visible_for_testing_member
    _cachedProviderConfig = service.providerConfig;
    // 传播注入服务的端点类型，保证派生 service 的协议一致
    // ignore: invalid_use_of_visible_for_testing_member
    _cachedEndpointType = service.protocol.name;
    currentConfigIndex = 0;
    currentModelIndex = 0;
  }

  /// 释放所有资源
  void dispose() {
    cancelAllServices();
    _cachedProvider = null;
    _cachedModelConfig = null;
    _cachedProviderConfig = null;
    _cachedEndpointType = 'openai';
    currentConfigIndex = -1;
    currentModelIndex = -1;
    disposeMcp();
  }

  /// 获取所有可用工具定义（内置 + MCP）
  List<ToolDefinition> getAllToolDefinitions() {
    // Built-in tools are registered statically via ChatService.registerTool()
    // MCP tools are discovered dynamically
    return [
      ...filterMcpSearchToolDefinitions(
        ChatService.getRegisteredToolDefinitions()
            .where((tool) => !_disabledMcpToolNames.contains(tool.name))
            .toList(),
        mcpEnabled: _mcpMasterSwitchEnabled,
      ),
      ..._mcpToolDefinitions,
    ];
  }

  /// Pass assistant-level custom parameters to the underlying ChatService.
  /// These will be merged into the API request body alongside model-level params.
  void setAssistantCustomParams(List<CustomParameter>? params) {
    _cachedAssistantCustomParams = params;
    for (final svc in _activeServices.values) {
      svc.setAssistantCustomParams(params);
    }
  }

  /// Pass the assistant's system prompt to the underlying ChatService.
  /// This prompt will be prepended as a system-role message in API requests.
  void setAssistantPrompt(String? prompt) {
    _cachedAssistantPrompt = prompt;
    for (final svc in _activeServices.values) {
      svc.setAssistantPrompt(prompt);
    }
  }

  /// Pass assistant-level settings to the underlying ChatService.
  /// When an assistant setting's enable flag is true, it overrides the
  /// corresponding model parameter. When false, the model parameter is used.
  void setAssistantSettings(AssistantSettings? settings) {
    _cachedAssistantSettings = settings;
    for (final svc in _activeServices.values) {
      svc.setAssistantSettings(settings);
    }
  }

  Stream<String> sendStream(
    String text, {
    required List<ChatMessage> history,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    String convId = '',
  }) {
    final svc = convId.isNotEmpty
        ? getOrCreateService(convId)
        : currentChatService;
    if (svc == null) {
      return Stream.error('请先配置聊天供应商');
    }
    return svc.sendStream(
      text,
      history: history,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
    );
  }

  /// Send a message with tool call support.
  /// Returns a stream of [ChatEvent] (text chunks and tool call events).
  /// [convId] routes the request to the correct per-conversation service.
  Stream<ChatEvent> sendStreamWithTools(
    String text, {
    required List<ChatMessage> history,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    List<ToolDefinition> tools = const [],
    String convId = '',
    Assistant? assistant,
    ProviderEntriesState? entriesState,
  }) {
    final svc = convId.isNotEmpty
        ? getOrCreateService(
            convId,
            assistant: assistant,
            entriesState: entriesState,
          )
        : currentChatService;
    if (svc == null) {
      return Stream.error(
        _hasConfiguredAssistantModelReference(assistant)
            ? '助手配置的模型不可用，请检查助手模型选择。'
            : '请先配置聊天供应商',
      );
    }
    return svc.sendStreamWithTools(
      text,
      history: history,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
      tools: tools,
    );
  }

  String get reasoningContent => currentChatService?.reasoningContent ?? '';

  Map<String, dynamic>? get lastRequestBody =>
      currentChatService?.lastRequestBody;
  Map<String, dynamic>? get lastResponseData =>
      currentChatService?.lastResponseData;
  Map<String, String>? get lastRequestHeaders =>
      currentChatService?.lastRequestHeaders;
  String? get lastRequestUrl => currentChatService?.lastRequestUrl;
  int? get lastResponseStatusCode => currentChatService?.lastResponseStatusCode;
  Map<String, List<String>>? get lastResponseHeaders =>
      currentChatService?.lastResponseHeaders;
}

/// Resolve the set of tool names to enable for the current conversation.
///
/// Behavior:
/// - If [hasExplicitSavedPrefs] is true (the user has touched the toggles
///   for this conversation), the [savedEnabledNames] set is returned as-is.
///   This is the case for both "user selected some tools" and
///   "user toggled every tool off" — both must survive serialization.
/// - If [hasExplicitSavedPrefs] is false (the conversation has no saved
///   preferences — the default for new conversations), all available tool
///   names are returned so that built-in HTTP tools and built-in remote
///   SSE MCP providers (Exa, Tavily, Jina, Firecrawl, Zhipu) are
///   immediately visible in the conversation page's tool list. Users can
///   still opt-out specific tools via the "可用工具" panel; the opt-out set
///   will be persisted on the next save (with hasExplicitEnabledMcpTools
///   flipped to true).
///
/// This is a pure function to keep the policy testable and easy to reason
/// about. The actual side-effect of writing to [enabledToolNamesProvider]
/// stays in the chat page.
Set<String> resolveEnabledToolNames({
  required List<ToolDefinition> allTools,
  required Set<String> savedEnabledNames,
  required bool hasExplicitSavedPrefs,
}) {
  if (hasExplicitSavedPrefs) {
    return Set<String>.from(savedEnabledNames);
  }
  return allTools.map((t) => t.name).toSet();
}

/// Resolves which model the chat page should restore for the active
/// conversation, when the conversation has a per-conversation record
/// ([Conversation.lastUsedModelName] / [Conversation.lastUsedModelId] /
/// [Conversation.lastUsedProviderName] — set by an assistant default at
/// creation or by the user's own switch inside that conversation).
///
/// Returns the model display name when it still exists among
/// [availableModels]; returns null when the conversation has no record or
/// the recorded model was removed from the provider configs — in both
/// cases the assistant default / first model applies (the fallback).
///
/// Pure so the priority policy is unit-testable; the side effects (adapter
/// select + per-model settings restore) live in the chat page.
String? perConversationModelToRestore({
  String? lastUsedModelName,
  String? lastUsedModelId,
  String? lastUsedProviderName,
  required List<AvailableModel> availableModels,
}) {
  return resolveModelRef(
    models: availableModels,
    modelId: lastUsedModelId,
    providerName: lastUsedProviderName,
    displayName: lastUsedModelName,
  )?.displayName;
}

/// 从 ProviderEntriesState 解析出所有可选的 LLM 模型（显示名格式与
/// 对话页一致："模型名 | 供应商名"）。
///
/// 与 [ChatAdapter.availableModels] 等效；设置页等无适配器上下文的
/// 调用方直接使用此顶层函数。
///
/// Legacy configs need host/key; in-memory model-group configs intentionally
/// omit both because the routed provider reads endpoint credentials at runtime.
List<AvailableModel> availableLlmModels(ProviderEntriesState entriesState) {
  final llmEntry = entriesState.entries
      .where((e) => e.type == 'llm')
      .firstOrNull;
  if (llmEntry == null) return const [];

  final result = <AvailableModel>[];
  for (final selected in flattenProviderModels(entriesState, 'llm')) {
    final ci = llmEntry.configs.indexWhere(
      (config) => identical(config, selected.config),
    );
    if (ci < 0) continue;
    final mi = selected.config.models.indexWhere(
      (model) => identical(model, selected.model),
    );
    if (mi < 0) continue;
    final config = selected.config;
    final model = selected.model;
    final displayName =
        '${model.name.isNotEmpty ? model.name : model.modelId} | ${config.providerName}';
    result.add(
      AvailableModel(
        displayName: displayName,
        modelId: model.modelId,
        providerName: config.providerName,
        modelGroupId: llmModelGroupIdForConfig(config),
        configIndex: ci,
        modelIndex: mi,
      ),
    );
  }
  return result;
}

/// 按持久化的模型引用解析出当前可用的 [AvailableModel]。
///
/// Resolve opaque custom-group member IDs by their stable identity when the
/// saved provider label is stale after a group rename. Other references keep
/// their saved provider name authoritative; display names only resolve legacy
/// references that have no stable model ID.
///
/// 多个模型保留了同一旧身份时，显示名必须唯一指向其中一个，否则返回
/// null，避免按列表顺序切换到另一个稳定模型组。
AvailableModel? resolveModelRef({
  required List<AvailableModel> models,
  String? modelId,
  String? providerName,
  String? displayName,
}) {
  AvailableModel? selectUnique(Iterable<AvailableModel> candidates) {
    final matches = candidates.toList(growable: false);
    if (matches.length == 1) return matches.single;
    if (matches.length < 2 || displayName == null || displayName.isEmpty) {
      return null;
    }
    final named = matches
        .where((model) => model.displayName == displayName)
        .toList(growable: false);
    return named.length == 1 ? named.single : null;
  }

  final id = modelId;
  final provider = providerName;
  final hasProvider = provider != null && provider.isNotEmpty;
  if (id != null && id.isNotEmpty) {
    final byId = models.where((model) => model.modelId == id).toList();
    if (hasProvider) {
      final exact = byId.where((model) => model.providerName == provider);
      if (exact.isNotEmpty) return selectUnique(exact);
      final groupReference = llmModelGroupMemberReferenceForModelId(id);
      if (groupReference != null) {
        final stableGroupMatches = byId
            .where((model) => model.modelGroupId == groupReference.groupId)
            .toList(growable: false);
        if (stableGroupMatches.length == 1) {
          return stableGroupMatches.single;
        }
      }
    } else if (byId.isNotEmpty) {
      return selectUnique(byId);
    }
    // A saved stable identity must not bind another model just because its
    // display label happens to match. Display-only lookup is for legacy refs.
    return null;
  }
  if (displayName != null && displayName.isNotEmpty) {
    final byName = models
        .where(
          (model) =>
              model.displayName == displayName &&
              (!hasProvider || model.providerName == provider),
        )
        .toList(growable: false);
    if (byName.length == 1) return byName.single;
  }
  return null;
}
