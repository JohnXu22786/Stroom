import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assistant.dart';
import '../providers/assistant_provider.dart';
import '../providers/conversation_provider.dart';
import '../widgets/llm/assistant_avatar.dart';

/// Second page in the chat flow: after selecting an assistant,
/// choose or create a topic (conversation).
class TopicSelectionPage extends ConsumerWidget {
  const TopicSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedAssistant = ref.watch(selectedAssistantProvider);
    final conversations = ref.watch(conversationsProvider);
    final cs = Theme.of(context).colorScheme;

    // Filter conversations by this assistant's ID
    final assistantId = ref.watch(selectedAssistantIdProvider);
    final assistantTopics = conversations
        .where((c) => c.assistantId == assistantId)
        .toList()
      ..sort((a, b) {
        // Pinned first, then preserve list order (same as ConversationsPage)
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return 0;
      });

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Row(
          children: [
            if (selectedAssistant != null) ...[
              AssistantAvatar(
                assistant: selectedAssistant,
                size: 28,
                borderRadius: 8,
              ),
              const SizedBox(width: 8),
            ],
            const Text('选择话题'),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新话题',
            onPressed: () => _createNewTopic(context, ref),
          ),
          // Switch assistant button
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: '切换助手',
            onPressed: () {
              ref.read(selectedAssistantIdProvider.notifier).state = null;
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: selectedAssistant == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text('未选择助手',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      ref.read(selectedAssistantIdProvider.notifier).state =
                          null;
                      Navigator.pop(context);
                    },
                    child: const Text('返回选择助手'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Selected assistant info bar
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.primaryContainer,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      AssistantAvatar(
                        assistant: selectedAssistant,
                        size: 40,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedAssistant.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            if (selectedAssistant.description.isNotEmpty)
                              Text(
                                selectedAssistant.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Settings button
                      IconButton(
                        icon: const Icon(Icons.tune, size: 20),
                        tooltip: '参数设置',
                        onPressed: () => _showQuickSettings(
                            context, ref, selectedAssistant),
                      ),
                    ],
                  ),
                ),

                // Topic list
                Expanded(
                  child: assistantTopics.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 48,
                                  color: cs.onSurfaceVariant.withOpacity(0.4)),
                              const SizedBox(height: 16),
                              Text('暂无话题',
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant)),
                              const SizedBox(height: 8),
                              Text('创建一个新话题开始对话',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurfaceVariant
                                          .withOpacity(0.7))),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('新话题'),
                                onPressed: () =>
                                    _createNewTopic(context, ref),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: assistantTopics.length,
                          itemBuilder: (context, index) {
                            final topic = assistantTopics[index];
                            return _TopicItem(
                              topic: topic,
                              onTap: () => _onTopicSelected(
                                  context, ref, topic),
                              onDelete: () => _deleteTopic(
                                  context, ref, topic),
                            );
                          },
                        ),
                ),

                // Bottom: create new topic button
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('新话题'),
                        onPressed: () => _createNewTopic(context, ref),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _createNewTopic(BuildContext context, WidgetRef ref) {
    final assistantId = ref.read(selectedAssistantIdProvider);
    if (assistantId == null) return;

    // Create a new conversation associated with this assistant
    ref.read(conversationsProvider.notifier)
        .createConversation(assistantId: assistantId);

    // Navigate to chat page within the chat tab's nested navigator
    Navigator.of(context).pushNamed('/chat');
  }

  void _onTopicSelected(
      BuildContext context, WidgetRef ref, Conversation topic) {
    ref.read(conversationsProvider.notifier).selectConversation(topic.id);
    // Navigate to chat page within the chat tab's nested navigator
    Navigator.of(context).pushNamed('/chat');
  }

  void _deleteTopic(
      BuildContext context, WidgetRef ref, Conversation topic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除话题'),
        content: Text('确定要删除话题「${topic.title.isEmpty ? '新话题' : topic.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(conversationsProvider.notifier)
                  .deleteConversation(topic.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showQuickSettings(
      BuildContext context, WidgetRef ref, Assistant assistant) {
    double temperature = assistant.settings.temperature;
    bool enableTemperature = assistant.settings.enableTemperature;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              AssistantAvatar(
                assistant: assistant,
                size: 24,
                borderRadius: 6,
              ),
              const SizedBox(width: 8),
              Text('${assistant.name} 参数'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('温度 (Temperature)'),
                  subtitle: Text('$temperature'),
                  value: enableTemperature,
                  onChanged: (v) =>
                      setDlgState(() => enableTemperature = v),
                ),
                if (enableTemperature)
                  Slider(
                    value: temperature,
                    min: 0,
                    max: 2,
                    divisions: 40,
                    label: temperature.toStringAsFixed(2),
                    onChanged: (v) =>
                        setDlgState(() => temperature = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(assistantProvider.notifier)
                    .updateAssistantSettings(
                      assistantId: assistant.id,
                      temperature: temperature,
                      enableTemperature: enableTemperature,
                    );
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Topic item widget
// ============================================================================

class _TopicItem extends StatelessWidget {
  final Conversation topic;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TopicItem({
    required this.topic,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = topic.title.isEmpty ? '新话题' : topic.title;
    final subtitle = _formatDate(topic.updatedAt);
    final msgCount = topic.messages.length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cs.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  topic.isPinned
                      ? Icons.push_pin
                      : Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: topic.isPinned
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (topic.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin,
                                size: 12, color: cs.primary),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (msgCount > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.message_outlined,
                              size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text(
                            '$msgCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: cs.onSurfaceVariant.withOpacity(0.6)),
                tooltip: '删除',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
