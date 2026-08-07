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
/// - Default tools: tools NOT toggled on here stay OFF in new conversations.
///
/// These defaults only apply at conversation creation. Existing topics keep
/// their own per-conversation model/tool state, and changes made inside a
/// topic (model switch, tool toggles) persist for that topic independently
/// of other conversations and of these defaults.
class AssistantDefaultsTab extends ConsumerWidget {
  final String? defaultModelName;
  final Set<String> defaultToolNames;
  final ValueChanged<String?> onDefaultModelChanged;
  final void Function(String toolName, bool enabled) onDefaultToolToggled;

  const AssistantDefaultsTab({
    super.key,
    required this.defaultModelName,
    required this.defaultToolNames,
    required this.onDefaultModelChanged,
    required this.onDefaultToolToggled,
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
    final models = adapter.availableModels(entriesState);
    final tools = _availableTools(ref);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Scope explanation
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
                      '以下默认值仅应用于在该助手下新建的话题；已存在的话题保留各自的模型与工具设置，互不影响。',
                      style: TextStyle(
                          fontSize: 12, color: cs.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Default model ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '默认模型',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          // "跟随全局设置" is always shown — it is also the effective
          // selection when no default is recorded or the recorded model
          // was removed from the provider configs (stale name).
          _ModelOptionTile(
            label: '跟随全局设置',
            selected: defaultModelName == null ||
                !models.any((m) => m.displayName == defaultModelName),
            onTap: () => onDefaultModelChanged(null),
          ),
          if (models.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '暂无可用模型，请在设置中配置 LLM 供应商',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            )
          else
            for (final m in models)
              _ModelOptionTile(
                label: m.displayName,
                selected: defaultModelName == m.displayName,
                onTap: () => onDefaultModelChanged(m.displayName),
              ),
          const SizedBox(height: 8),

          // ── Default tools ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '默认启用工具',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              '未添加的工具，在该助手的新话题中保持关闭。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          if (tools.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '暂无可用工具',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            )
          else
            for (final tool in tools)
              SwitchListTile(
                dense: true,
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
                value: defaultToolNames.contains(tool.name),
                activeThumbColor: cs.primary,
                onChanged: (enabled) =>
                    onDefaultToolToggled(tool.name, enabled),
              ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// A selectable row for the default model list (same style as the chat
/// page's model panel: trailing check mark on the selected entry).
class _ModelOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModelOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: ListTile(
          dense: true,
          title: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: cs.onSurface,
            ),
          ),
          trailing:
              selected ? Icon(Icons.check, size: 18, color: cs.primary) : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
