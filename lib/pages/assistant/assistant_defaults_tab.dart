import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mcp.dart' show McpServerConfig;
import '../../models/tool_call.dart';
import '../../providers/chat_manager_provider.dart';
import '../../providers/provider_config.dart';
import '../../services/chat_adapter.dart'
    show AvailableModel, resolveModelRef;
import '../../services/chat_service.dart';
import '../../services/http_tool_service.dart';
import '../../services/todo_tool_service.dart';
import '../../services/web_search_service.dart';

/// "默认设置" tab of the assistant edit dialog: the default model and the
/// default enabled tools that NEW conversations (topics) created under this
/// assistant start with.
///
/// - Default model: null ("跟随全局设置") falls back to the global saved
///   model selection.
/// - Default tools: null ("从未配置") keeps the legacy behavior — new topics
///   auto-enable ALL available tools — so the tab displays every tool as ON
///   in that state. A non-null set (including an empty one) is the explicit
///   configuration: tools NOT in the set stay OFF in new topics.
///
/// These defaults only apply at conversation creation. Existing topics keep
/// their own per-conversation model/tool state, and changes made inside a
/// topic (model switch, tool toggles) persist for that topic independently
/// of other conversations and of these defaults.
class AssistantDefaultsTab extends ConsumerWidget {
  final String? defaultModelName;

  /// 默认模型的 API 模型 ID（绝对身份）。显示名重命名后仍可解析。
  final String? defaultModelId;

  /// 默认模型所属供应商名称（绝对身份的一部分）。
  final String? defaultProviderName;

  /// null = 从未配置默认工具：新话题自动启用全部工具（本 tab 显示为全部开启）。
  final Set<String>? defaultToolNames;

  /// 用户选择默认模型时回调完整的 [AvailableModel]（null = 跟随全局设置），
  /// 供对话框同时保存显示名与绝对身份（供应商 + 模型ID）。
  final ValueChanged<AvailableModel?> onDefaultModelChanged;

  /// 用户改动任何工具开关（或使用"全部启用/全部关闭"）时，回调完整的
  /// 新默认工具集合。tab 本身不再产生 null（"恢复未配置"按钮已移除）。
  final ValueChanged<Set<String>?> onDefaultToolsChanged;

  const AssistantDefaultsTab({
    super.key,
    required this.defaultModelName,
    required this.defaultModelId,
    required this.defaultProviderName,
    required this.defaultToolNames,
    required this.onDefaultModelChanged,
    required this.onDefaultToolsChanged,
  });

  /// All tools the user can pick from: the built-in tools plus any MCP
  /// tools already discovered by the adapter.
  ///
  /// Built-ins come from the ChatService registry when the chat page has
  /// already initialized it (keeps this tab in lockstep with the chat
  /// panel), falling back to the static service definitions when the
  /// registry is still empty (dialog opened before the chat page ever ran).
  ///
  /// MCP 工具始终列出（MCP 总开关由 adapter 层控制：总开关关闭时
  /// adapter 已清空 mcpToolDefinitions，这里自然不显示）。
  List<ToolDefinition> _availableTools(WidgetRef ref) {
    final adapter = ref.read(chatStreamManagerProvider).adapter;
    final registered = ChatService.getRegisteredToolDefinitions();
    final builtins = registered.isNotEmpty
        ? registered
        : [
            ...HttpToolService.toolDefinitions,
            ...TodoToolService.toolDefinitions,
            ...WebSearchService.toolDefinitions,
          ];
    final seen = <String>{};
    final tools = <ToolDefinition>[];
    for (final t in [...builtins, ...adapter.mcpToolDefinitions]) {
      if (seen.add(t.name)) tools.add(t);
    }
    return tools;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final entriesState = ref.watch(providerEntriesProvider);
    final adapter = ref.read(chatStreamManagerProvider).adapter;
    // 按显示名去重：两个供应商配置同名模型时只保留第一个（与聊天页
    // "first match wins" 的约定一致），否则 RadioGroup 会因重复 value 崩溃。
    final seenModelNames = <String>{};
    final models = [
      for (final m in adapter.availableModels(entriesState))
        if (seenModelNames.add(m.displayName)) m,
    ];
    final tools = _availableTools(ref);
    final allToolNames = tools.map((t) => t.name).toSet();
    // 清理用的"有效工具名"：除当前显示的工具外，还包含被 MCP 总开关
    // 隐藏的 MCP 工具。它们只是被隐藏、并未失效——单次开关/全部启用
    // 不应把它们从默认配置中静默清除，恢复显示后默认配置保留。
    // 注意从**配置**推导（而非 adapter 的占位列表）：总开关关闭时 adapter
    // 已清空占位工具，只有配置里还能拿到这些名字。
    final validMcpToolNames = <String>{};
    final mcpEntry =
        entriesState.entries.where((e) => e.type == 'mcp').firstOrNull;
    for (final c in mcpEntry?.configs ?? const <ProviderConfigItem>[]) {
      final typeConfig = c.models.isNotEmpty ? c.models[0].typeConfig : null;
      if (typeConfig?['isHttpTool'] == true) continue;
      final serverConfig = McpServerConfig.fromProviderConfig(
        providerName: c.providerName,
        typeConfig: typeConfig,
      );
      if (serverConfig != null) {
        validMcpToolNames.add(
          McpServerConfig.placeholderToolName(serverConfig.name),
        );
      }
    }
    final validToolNames = <String>{...allToolNames, ...validMcpToolNames};

    // 生效中的工具集合：null（从未配置）→ 全部工具自动启用，因此显示为
    // 全部开启；配置过（含空集合）则严格按集合显示。
    // 基线用 validToolNames（含被隐藏的 MCP 工具）而非 allToolNames：
    // 从未配置时第一次开关某个工具，生成的显式集合与"全部启用"按钮
    // 一致——被隐藏但有效的 MCP 工具不会在 null→已配置 的转换中丢失。
    final effectiveToolNames = defaultToolNames ?? validToolNames;
    final isToolsConfigured = defaultToolNames != null;

    // 生效中的默认模型：记录的模型已被删除（stale）时退化为"跟随全局设置"。
    // 与聊天页/保存逻辑一致地按绝对身份优先解析（resolveModelRef）：
    // (providerName, modelId) 精确 → modelId → 显示名，显示名重命名后
    // 仍能高亮正确模型（含跨供应商同名 modelId 的消歧）。
    final effectiveModel = resolveModelRef(
      models: models,
      modelId: defaultModelId,
      providerName: defaultProviderName,
      displayName: defaultModelName,
    );
    final effectiveModelName = effectiveModel?.displayName;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // ── 作用范围说明 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: cs.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '以下默认值仅应用于在该助手下新建的话题；已存在的话题保留各自的模型与工具设置，不受影响。',
                      style: TextStyle(
                          fontSize: 12, color: cs.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 默认模型 ──
          _SectionCard(
            icon: Icons.smart_toy_outlined,
            title: '默认模型',
            subtitle: '新建话题使用的模型；未设置时跟随全局设置。',
            child: RadioGroup<String>(
              groupValue: effectiveModelName ?? _followGlobalSentinel,
              onChanged: (value) {
                if (value == _followGlobalSentinel) {
                  onDefaultModelChanged(null);
                } else {
                  // 把完整模型（含绝对身份）传给对话框，保存时同时
                  // 记录显示名与模型ID+供应商名。
                  final model = models
                      .where((m) => m.displayName == value)
                      .firstOrNull;
                  onDefaultModelChanged(model);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _followGlobalSentinel,
                    title: Text(
                      '跟随全局设置',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: effectiveModelName == null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (models.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        '暂无可用模型，请在设置中配置 LLM 供应商',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    )
                  else
                    for (final m in models)
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: m.displayName,
                        title: Text(
                          m.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: effectiveModelName == m.displayName
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── 默认启用工具 ──
          // 头部右侧放"全部启用/全部关闭"两个批量操作按钮；逐个工具的
          // 开关仍在下方列表中。
          _SectionCard(
            icon: Icons.build_outlined,
            title: '默认启用工具',
            subtitle: isToolsConfigured
                ? '未启用的工具，在该助手的新话题中不会自动开启。'
                : '尚未配置默认工具，新话题将自动启用全部工具。',
            trailing: tools.isEmpty
                ? null
                : Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    children: [
                      // 未配置时"全部启用"没有意义（当前已自动启用全部），
                      // 且会悄悄把集合冻结为今天的工具列表——不显示。
                      if (isToolsConfigured)
                        TextButton(
                          onPressed: () =>
                              onDefaultToolsChanged(validToolNames),
                          child: const Text('全部启用'),
                        ),
                      TextButton(
                        onPressed: () => onDefaultToolsChanged(const {}),
                        child: const Text('全部关闭'),
                      ),
                    ],
                  ),
            child: tools.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '暂无可用工具',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final tool in tools)
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            tool.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                          subtitle: tool.description.isNotEmpty
                              ? Text(
                                  tool.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                )
                              : null,
                          value: effectiveToolNames.contains(tool.name),
                          activeThumbColor: cs.primary,
                          onChanged: (enabled) {
                            // 只保留当前仍有效的工具：已失效的工具名
                            // （如被删除的 MCP 服务器）在单次开关时顺带
                            // 清理；被 MCP 总开关隐藏的工具不在
                            // allToolNames 中但在 validToolNames 中，
                            // 不会被清理（见 validToolNames 注释）。
                            final next = Set<String>.from(
                              effectiveToolNames.intersection(validToolNames),
                            );
                            if (enabled) {
                              next.add(tool.name);
                            } else {
                              next.remove(tool.name);
                            }
                            onDefaultToolsChanged(next);
                          },
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // ── 效果预览：直接反映新建话题的实际行为 ──
          // 细边框区分于上方的说明 banner（同为浅色调容器）。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 16, color: cs.secondary),
                      const SizedBox(width: 8),
                      Text(
                        '新建话题效果',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: '模型',
                    value: effectiveModelName ?? '跟随全局设置',
                  ),
                  const SizedBox(height: 6),
                  _SummaryRow(
                    label: '工具',
                    value: tools.isEmpty
                        ? '暂无可用工具'
                        : isToolsConfigured
                            // 只统计当前仍存在的工具，避免已失效的工具名
                            // 使摘要数量与上方开关不一致。
                            ? '已启用 ${effectiveToolNames.intersection(allToolNames).length} / ${tools.length}'
                            : '全部自动启用（未配置）',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Sentinel value for the "跟随全局设置" radio. 含 NUL 字符，真实模型的
/// 显示名（用户可任意配置）不可能包含 NUL——保证不会与模型名冲突，
/// 避免 RadioGroup 因重复 value 崩溃。
const _followGlobalSentinel = '\u0000__follow_global__';

/// 配置区块卡片：图标 + 标题 + 说明 + 内容。
/// [trailing] 渲染在标题行右侧（右对齐），用于放置区块级操作按钮
/// （如"全部启用/全部关闭"）；窄屏下自动换行，不溢出。
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: cs.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 18, color: cs.tertiary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    // Expanded + Wrap：按钮占满标题行剩余空间，右对齐；
                    // 空间不足时按钮换行，避免 RenderFlex 溢出。
                    Expanded(
                      child: trailing!,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 效果预览卡中的一行：标签 + 右对齐的值。
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
