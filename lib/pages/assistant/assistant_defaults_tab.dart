import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tool_call.dart';
import '../../providers/chat_manager_provider.dart';
import '../../providers/provider_config.dart';
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

  /// null = 从未配置默认工具：新话题自动启用全部工具（本 tab 显示为全部开启）。
  final Set<String>? defaultToolNames;
  final ValueChanged<String?> onDefaultModelChanged;

  /// 用户改动任何工具开关（或使用"全部启用/全部关闭"）时，回调完整的
  /// 新默认工具集合；传 null 表示"恢复未配置"（新话题重新自动启用全部工具）。
  final ValueChanged<Set<String>?> onDefaultToolsChanged;

  const AssistantDefaultsTab({
    super.key,
    required this.defaultModelName,
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

    // 生效中的工具集合：null（从未配置）→ 全部工具自动启用，因此显示为
    // 全部开启；配置过（含空集合）则严格按集合显示。
    final effectiveToolNames = defaultToolNames ?? allToolNames;
    final isToolsConfigured = defaultToolNames != null;

    // 生效中的默认模型：记录的模型已被删除（stale）时退化为"跟随全局设置"。
    final effectiveModelName = defaultModelName != null &&
            models.any((m) => m.displayName == defaultModelName)
        ? defaultModelName!
        : null;

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
                  onDefaultModelChanged(value);
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
          _SectionCard(
            icon: Icons.build_outlined,
            title: '默认启用工具',
            subtitle: isToolsConfigured
                ? '未启用的工具，在该助手的新话题中不会自动开启。'
                : '尚未配置默认工具，新话题将自动启用全部工具。',
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
                            // 只保留当前仍存在的工具：已失效的工具名（如被
                            // 删除的 MCP 服务器）在单次开关时顺带清理，与
                            // 默认模型的失效自愈保持一致。
                            final next = Set<String>.from(
                              effectiveToolNames.intersection(allToolNames),
                            );
                            if (enabled) {
                              next.add(tool.name);
                            } else {
                              next.remove(tool.name);
                            }
                            onDefaultToolsChanged(next);
                          },
                        ),
                      const Divider(height: 1),
                      // Wrap（而非 Row）：手机宽度下按钮放不下时自动换行，
                      // 避免 RenderFlex 溢出。
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        children: [
                          if (isToolsConfigured)
                            TextButton(
                              onPressed: () => onDefaultToolsChanged(null),
                              child: const Text('取消配置（自动启用全部）'),
                            ),
                          // 未配置时"全部启用"没有意义（当前已自动启用全部），
                          // 且会悄悄把集合冻结为今天的工具列表——不显示。
                          if (isToolsConfigured)
                            TextButton(
                              onPressed: () =>
                                  onDefaultToolsChanged(allToolNames),
                              child: const Text('全部启用'),
                            ),
                          TextButton(
                            onPressed: () => onDefaultToolsChanged(const {}),
                            child: const Text('全部关闭'),
                          ),
                        ],
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
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
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
