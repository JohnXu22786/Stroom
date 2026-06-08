import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assistant.dart';
import '../providers/assistant_provider.dart';
import 'topic_selection_page.dart';

/// First page in the chat flow: select an assistant.
/// Displays assistants in a grid of cards, similar to Cherry Studio's design.
class AssistantSelectionPage extends ConsumerWidget {
  const AssistantSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistants = ref.watch(assistantProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('选择助手'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建助手',
            onPressed: () => _showCreateAssistantDialog(context, ref),
          ),
        ],
      ),
      body: assistants.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined,
                      size: 64, color: cs.onSurfaceVariant.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text('暂无助手，请先创建',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('创建助手'),
                    onPressed: () => _showCreateAssistantDialog(context, ref),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // Responsive grid: 2 columns on narrow, 3 on wide
                final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: assistants.length,
                  itemBuilder: (context, index) {
                    final assistant = assistants[index];
                    return _AssistantCard(
                      assistant: assistant,
                      onTap: () => _onAssistantSelected(
                          context, ref, assistant),
                      onLongPress: () => _showAssistantMenu(
                          context, ref, assistant),
                    );
                  },
                );
              },
            ),
    );
  }

  void _onAssistantSelected(
      BuildContext context, WidgetRef ref, Assistant assistant) {
    // Set the selected assistant
    ref.read(selectedAssistantIdProvider.notifier).state = assistant.id;
    // Navigate to topic selection
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TopicSelectionPage()),
    );
  }

  void _showCreateAssistantDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final promptController = TextEditingController(
        text: '你是一个有帮助的AI助手。请用中文回答用户的问题。');
    String selectedEmoji = '🤖';
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('新建助手'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji picker
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '🤖', '😊', '🎨', '📝', '🔍', '📊', '🎵', '🧮',
                    '🌐', '⚡', '💡', '🎯', '📚', '🛠️', '🧠', '🌟',
                  ].map((e) {
                    final isSelected = e == selectedEmoji;
                    return GestureDetector(
                      onTap: () => setDlgState(() => selectedEmoji = e),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(ctx)
                                  .colorScheme
                                  .primaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(ctx).colorScheme.primary)
                              : null,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '助手名称',
                    hintText: '输入助手名称',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    hintText: '简短描述此助手的功能',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: promptController,
                  decoration: const InputDecoration(
                    labelText: '系统提示词',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
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
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                ref.read(assistantProvider.notifier).createAssistant(
                      name: name,
                      prompt: promptController.text.trim(),
                      emoji: selectedEmoji,
                      description: descriptionController.text.trim(),
                    );
                nameController.dispose();
                promptController.dispose();
                descriptionController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssistantMenu(
      BuildContext context, WidgetRef ref, Assistant assistant) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditAssistantDialog(context, ref, assistant);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(ctx);
                _showAssistantSettingsDialog(context, ref, assistant);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('删除',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteAssistant(context, ref, assistant);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAssistantDialog(
      BuildContext context, WidgetRef ref, Assistant assistant) {
    final nameController = TextEditingController(text: assistant.name);
    final promptController = TextEditingController(text: assistant.prompt);
    String selectedEmoji = assistant.emoji;
    final descriptionController =
        TextEditingController(text: assistant.description);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('编辑助手'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '🤖', '😊', '🎨', '📝', '🔍', '📊', '🎵', '🧮',
                    '🌐', '⚡', '💡', '🎯', '📚', '🛠️', '🧠', '🌟',
                  ].map((e) {
                    final isSelected = e == selectedEmoji;
                    return GestureDetector(
                      onTap: () => setDlgState(() => selectedEmoji = e),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(ctx)
                                  .colorScheme
                                  .primaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(ctx).colorScheme.primary)
                              : null,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '助手名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: promptController,
                  decoration: const InputDecoration(
                    labelText: '系统提示词',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
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
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                ref.read(assistantProvider.notifier).updateAssistant(
                      id: assistant.id,
                      name: name,
                      prompt: promptController.text.trim(),
                      emoji: selectedEmoji,
                      description: descriptionController.text.trim(),
                    );
                nameController.dispose();
                promptController.dispose();
                descriptionController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssistantSettingsDialog(
      BuildContext context, WidgetRef ref, Assistant assistant) {
    double temperature = assistant.settings.temperature;
    bool enableTemperature = assistant.settings.enableTemperature;
    double topP = assistant.settings.topP;
    bool enableTopP = assistant.settings.enableTopP;
    int maxTokens = assistant.settings.maxTokens;
    bool enableMaxTokens = assistant.settings.enableMaxTokens;
    bool streamOutput = assistant.settings.streamOutput;
    String reasoningEffort = assistant.settings.reasoningEffort;
    bool enableWebSearch = assistant.settings.enableWebSearch;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('助手参数设置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Temperature
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
                const Divider(),

                // Top P
                SwitchListTile(
                  title: const Text('Top P'),
                  subtitle: Text('$topP'),
                  value: enableTopP,
                  onChanged: (v) => setDlgState(() => enableTopP = v),
                ),
                if (enableTopP)
                  Slider(
                    value: topP,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: topP.toStringAsFixed(2),
                    onChanged: (v) => setDlgState(() => topP = v),
                  ),
                const Divider(),

                // Max Tokens
                SwitchListTile(
                  title: const Text('最大Token数 (Max Tokens)'),
                  subtitle: Text('$maxTokens'),
                  value: enableMaxTokens,
                  onChanged: (v) =>
                      setDlgState(() => enableMaxTokens = v),
                ),
                if (enableMaxTokens)
                  Slider(
                    value: maxTokens.toDouble(),
                    min: 256,
                    max: 32768,
                    divisions: 127,
                    label: '$maxTokens',
                    onChanged: (v) =>
                        setDlgState(() => maxTokens = v.round()),
                  ),
                const Divider(),

                // Stream Output
                SwitchListTile(
                  title: const Text('流式输出 (Stream Output)'),
                  value: streamOutput,
                  onChanged: (v) =>
                      setDlgState(() => streamOutput = v),
                ),
                const Divider(),

                // Reasoning Effort
                ListTile(
                  title: const Text('推理努力度'),
                  subtitle: Text(reasoningEffort),
                  trailing: DropdownButton<String>(
                    value: reasoningEffort,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                          value: 'default', child: Text('默认')),
                      DropdownMenuItem(
                          value: 'low', child: Text('低')),
                      DropdownMenuItem(
                          value: 'high', child: Text('高')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDlgState(() => reasoningEffort = v);
                      }
                    },
                  ),
                ),
                const Divider(),

                // Web Search
                SwitchListTile(
                  title: const Text('联网搜索'),
                  value: enableWebSearch,
                  onChanged: (v) =>
                      setDlgState(() => enableWebSearch = v),
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
                ref.read(assistantProvider.notifier).updateAssistantSettings(
                      assistantId: assistant.id,
                      temperature: temperature,
                      enableTemperature: enableTemperature,
                      topP: topP,
                      enableTopP: enableTopP,
                      maxTokens: maxTokens,
                      enableMaxTokens: enableMaxTokens,
                      streamOutput: streamOutput,
                      reasoningEffort: reasoningEffort,
                      enableWebSearch: enableWebSearch,
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

  void _confirmDeleteAssistant(
      BuildContext context, WidgetRef ref, Assistant assistant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除助手'),
        content: Text('确定要删除助手「${assistant.name}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(assistantProvider.notifier)
                  .deleteAssistant(assistant.id);
              // Clear selected assistant if it was the deleted one
              final currentId = ref.read(selectedAssistantIdProvider);
              if (currentId == assistant.id) {
                ref.read(selectedAssistantIdProvider.notifier).state = null;
              }
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
}

// ============================================================================
// Assistant card widget
// ============================================================================

class _AssistantCard extends StatelessWidget {
  final Assistant assistant;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AssistantCard({
    required this.assistant,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    assistant.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                assistant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              // Description
              if (assistant.description.isNotEmpty)
                Text(
                  assistant.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              // Prompt preview
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  assistant.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
