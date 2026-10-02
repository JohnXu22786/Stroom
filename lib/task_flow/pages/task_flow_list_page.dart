import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pages/unified_task_list/task_utils.dart';
import '../models/task_flow_definition.dart';
import '../models/task_flow_templates.dart';
import '../providers/task_flow_provider.dart';
import 'task_flow_builder_page.dart';

/// Page that lists all saved task flows.
///
/// Shows each flow with its name, description, block count, and last update.
/// Long-press for context menu (edit, duplicate, delete).
/// Tap to go to the execution page.
class TaskFlowListPage extends ConsumerWidget {
  const TaskFlowListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flows = ref.watch(taskFlowListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务流'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _showTemplates(context),
            tooltip: '示例模板',
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewFlow(context, ref),
        child: const Icon(Icons.add),
      ),
      body: flows.isEmpty
          ? _buildEmptyState(cs, context)
          : _buildFlowList(flows, cs, context, ref),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 72,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无流程，点击 + 创建',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showTemplates(context),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('从示例模板开始'),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowList(
    List<TaskFlowDefinition> flows,
    ColorScheme cs,
    BuildContext context,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(taskFlowListProvider.notifier).restoreFromPersistence();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: flows.length,
        itemBuilder: (_, i) {
          final flow = flows[i];
          return _buildFlowCard(flow, cs, context, ref);
        },
      ),
    );
  }

  Widget _buildFlowCard(
    TaskFlowDefinition flow,
    ColorScheme cs,
    BuildContext context,
    WidgetRef ref,
  ) {
    final defs = flow.blocks
        .map((b) => b.getDefinition()?.label ?? b.typeKey.name)
        .join(' → ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TaskFlowBuilderPage(flowId: flow.id, startInRunMode: true),
            ),
          );
        },
        onLongPress: () => _showContextMenu(context, ref, flow),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_tree,
                      size: 20,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flow.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (flow.description.isNotEmpty)
                          Text(
                            flow.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    tooltip: '流程操作',
                    onPressed: () => _showContextMenu(context, ref, flow),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Block chain preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.layers,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${flow.blocks.length} 个功能块',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatRelativeTime(flow.updatedAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    if (defs.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        defs,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    TaskFlowDefinition flow,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, size: 22),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TaskFlowBuilderPage(flowId: flow.id),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy, size: 22),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(taskFlowListProvider.notifier).duplicateFlow(flow.id);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('已复制')));
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                size: 22,
                color: Colors.red,
              ),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('确认删除'),
                    content: Text('确定要删除任务流「${flow.name}」吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dCtx);
                          ref
                              .read(taskFlowListProvider.notifier)
                              .removeFlow(flow.id);
                        },
                        child: const Text(
                          '删除',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createNewFlow(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TaskFlowBuilderPage()),
    );
  }

  void _showTemplates(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择示例模板', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('模板会打开为待配置的草稿，选择模型和助手后再保存。'),
                for (final template in taskFlowTemplates)
                  ListTile(
                    title: Text(template.name),
                    subtitle: Text(
                      '${template.description}\n${template.requirements}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TaskFlowBuilderPage(
                            initialDraft: template.createDraft(),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
