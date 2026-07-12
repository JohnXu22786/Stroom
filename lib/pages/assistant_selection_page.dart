import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assistant.dart';
import '../providers/assistant_provider.dart';
import 'assistant/assistant_shared.dart';
export 'assistant/assistant_shared.dart';

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
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 64,
                    color: cs.onSurfaceVariant.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无助手，请先创建',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
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
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: assistants.length,
                  itemBuilder: (context, index) {
                    final assistant = assistants[index];
                    return AssistantCard(
                      assistant: assistant,
                      onTap: () =>
                          _onAssistantSelected(context, ref, assistant),
                      onLongPress: () =>
                          _showAssistantMenu(context, ref, assistant),
                    );
                  },
                );
              },
            ),
    );
  }

  void _onAssistantSelected(
    BuildContext context,
    WidgetRef ref,
    Assistant assistant,
  ) {
    // Set the selected assistant
    ref.read(selectedAssistantIdProvider.notifier).state = assistant.id;
    // Navigate to topic selection within the chat tab's nested navigator
    Navigator.of(context).pushNamed('/topic-selection');
  }

  void _showCreateAssistantDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final promptController = TextEditingController(
      text: '你是一个有帮助的AI助手。请用中文回答用户的问题。',
    );
    String selectedEmoji = '🤖';
    final descriptionController = TextEditingController();

    void disposeControllers() {
      nameController.dispose();
      promptController.dispose();
      descriptionController.dispose();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('新建助手'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji picker (only emoji avatar supported)
                CategorizedEmojiPicker(
                  selectedEmoji: selectedEmoji,
                  onEmojiSelected: (e) => setDlgState(() => selectedEmoji = e),
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
              onPressed: () {
                disposeControllers();
                Navigator.pop(ctx);
              },
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
                disposeControllers();
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
    BuildContext context,
    WidgetRef ref,
    Assistant assistant,
  ) {
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
                showAssistantFullEditDialog(context, ref, assistant);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(
                '删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteAssistantConfirmation(context, ref, assistant);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAssistantConfirmation(
    BuildContext context,
    WidgetRef ref,
    Assistant assistant,
  ) {
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
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Public dialog functions for assistant editing, settings, and custom params
// ============================================================================

/// Shows a combined dialog to edit both basic info and model settings
/// of an assistant. Used from both [AssistantSelectionPage] and
/// [TopicSelectionPage].
void showAssistantFullEditDialog(
  BuildContext context,
  WidgetRef ref,
  Assistant assistant,
) {
  final nameController = TextEditingController(text: assistant.name);
  final promptController = TextEditingController(text: assistant.prompt);
  String selectedEmoji = assistant.emoji;
  final descriptionController = TextEditingController(
    text: assistant.description,
  );

  // Settings state
  double temperature = assistant.settings.temperature;
  bool enableTemperature = assistant.settings.enableTemperature;
  double topP = assistant.settings.topP;
  bool enableTopP = assistant.settings.enableTopP;
  int maxTokens = assistant.settings.maxTokens;
  bool enableMaxTokens = assistant.settings.enableMaxTokens;
  bool streamOutput = assistant.settings.streamOutput;
  bool enableWebSearch = assistant.settings.enableWebSearch;
  double frequencyPenalty = assistant.settings.frequencyPenalty;
  bool enableFrequencyPenalty = assistant.settings.enableFrequencyPenalty;
  double presencePenalty = assistant.settings.presencePenalty;
  bool enablePresencePenalty = assistant.settings.enablePresencePenalty;
  int? seed = assistant.settings.seed;
  bool enableSeed = assistant.settings.enableSeed;
  final seedController = TextEditingController(text: seed?.toString() ?? '');
  List<CustomParameter> customParameters = List.from(
    assistant.settings.customParameters,
  );

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: const Text('编辑助手'),
        content: SizedBox(
          width: double.maxFinite,
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tab bar
                TabBar(
                  tabAlignment: TabAlignment.center,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                  tabs: const [
                    Tab(text: '基本设置'),
                    Tab(text: '参数设置'),
                  ],
                ),
                // Tab content area - expands to fill remaining space
                Expanded(
                  child: TabBarView(
                    children: [
                      // ============ Tab 1: 基本设置 ============
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            // Emoji picker (only emoji avatar supported)
                            CategorizedEmojiPicker(
                              selectedEmoji: selectedEmoji,
                              onEmojiSelected: (e) =>
                                  setDlgState(() => selectedEmoji = e),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: '助手名称',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextField(
                                controller: descriptionController,
                                decoration: const InputDecoration(
                                  labelText: '描述（可选）',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextField(
                                controller: promptController,
                                decoration: const InputDecoration(
                                  labelText: '系统提示词',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 4,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),

                      // ============ Tab 2: 参数设置 ============
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            // Override rule explanation
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .tertiaryContainer
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.tertiary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '助手的参数开关打开时覆盖模型参数；关闭时使用模型参数。',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onTertiaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Temperature
                            SwitchListTile(
                              title: const Text('温度 (Temperature)'),
                              subtitle: Text('$temperature'),
                              value: enableTemperature,
                              onChanged: (v) =>
                                  setDlgState(() => enableTemperature = v),
                            ),
                            if (enableTemperature)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Slider(
                                  value: temperature,
                                  min: 0,
                                  max: 2,
                                  divisions: 40,
                                  label: temperature.toStringAsFixed(2),
                                  onChanged: (v) =>
                                      setDlgState(() => temperature = v),
                                ),
                              ),
                            const Divider(),

                            // Top P
                            SwitchListTile(
                              title: const Text('Top P'),
                              subtitle: Text('$topP'),
                              value: enableTopP,
                              onChanged: (v) =>
                                  setDlgState(() => enableTopP = v),
                            ),
                            if (enableTopP)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Slider(
                                  value: topP,
                                  min: 0,
                                  max: 1,
                                  divisions: 20,
                                  label: topP.toStringAsFixed(2),
                                  onChanged: (v) => setDlgState(() => topP = v),
                                ),
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
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Slider(
                                  value: maxTokens.toDouble(),
                                  min: 256,
                                  max: 32768,
                                  divisions: 127,
                                  label: '$maxTokens',
                                  onChanged: (v) =>
                                      setDlgState(() => maxTokens = v.round()),
                                ),
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

                            // Frequency Penalty
                            SwitchListTile(
                              title: const Text('频率惩罚 (Frequency Penalty)'),
                              subtitle: Text('$frequencyPenalty'),
                              value: enableFrequencyPenalty,
                              onChanged: (v) =>
                                  setDlgState(() => enableFrequencyPenalty = v),
                            ),
                            if (enableFrequencyPenalty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Slider(
                                  value: frequencyPenalty,
                                  min: -2,
                                  max: 2,
                                  divisions: 40,
                                  label: frequencyPenalty.toStringAsFixed(2),
                                  onChanged: (v) =>
                                      setDlgState(() => frequencyPenalty = v),
                                ),
                              ),
                            const Divider(),

                            // Presence Penalty
                            SwitchListTile(
                              title: const Text('存在惩罚 (Presence Penalty)'),
                              subtitle: Text('$presencePenalty'),
                              value: enablePresencePenalty,
                              onChanged: (v) =>
                                  setDlgState(() => enablePresencePenalty = v),
                            ),
                            if (enablePresencePenalty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Slider(
                                  value: presencePenalty,
                                  min: -2,
                                  max: 2,
                                  divisions: 40,
                                  label: presencePenalty.toStringAsFixed(2),
                                  onChanged: (v) =>
                                      setDlgState(() => presencePenalty = v),
                                ),
                              ),
                            const Divider(),

                            // Seed
                            SwitchListTile(
                              title: const Text('随机种子 (Seed)'),
                              subtitle: Text(seed?.toString() ?? '未设置'),
                              value: enableSeed,
                              onChanged: (v) =>
                                  setDlgState(() => enableSeed = v),
                            ),
                            if (enableSeed)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: '种子值',
                                    hintText: '输入整数种子',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: seedController,
                                  onChanged: (v) => setDlgState(() {
                                    seed = int.tryParse(v);
                                  }),
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
                            const Divider(),

                            // Custom Parameters section
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    '自定义参数',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 20,
                                    ),
                                    tooltip: '添加参数',
                                    onPressed: () {
                                      showAddCustomParameterDialog(context, (
                                        name,
                                        type,
                                        value,
                                      ) {
                                        setDlgState(() {
                                          customParameters.add(
                                            CustomParameter(
                                              name: name,
                                              type: type,
                                              value: value,
                                            ),
                                          );
                                        });
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (customParameters.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Text(
                                  '暂无自定义参数',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              ...customParameters.asMap().entries.map((entry) {
                                final i = entry.key;
                                final cp = entry.value;
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    cp.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${cp.type}: ${cp.value?.toString() ?? 'null'}',
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    onPressed: () {
                                      setDlgState(() {
                                        customParameters.removeAt(i);
                                      });
                                    },
                                  ),
                                  onTap: () {
                                    showEditCustomParameterDialog(context, cp, (
                                      name,
                                      type,
                                      value,
                                    ) {
                                      setDlgState(() {
                                        customParameters[i] = CustomParameter(
                                          name: name,
                                          type: type,
                                          value: value,
                                        );
                                      });
                                    });
                                  },
                                );
                              }),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

              // Update basic info
              ref.read(assistantProvider.notifier).updateAssistant(
                    id: assistant.id,
                    name: name,
                    prompt: promptController.text.trim(),
                    emoji: selectedEmoji,
                    description: descriptionController.text.trim(),
                  );

              // Update settings
              ref.read(assistantProvider.notifier).updateAssistantSettings(
                    assistantId: assistant.id,
                    temperature: temperature,
                    enableTemperature: enableTemperature,
                    topP: topP,
                    enableTopP: enableTopP,
                    maxTokens: maxTokens,
                    enableMaxTokens: enableMaxTokens,
                    streamOutput: streamOutput,
                    enableWebSearch: enableWebSearch,
                    frequencyPenalty: frequencyPenalty,
                    enableFrequencyPenalty: enableFrequencyPenalty,
                    presencePenalty: presencePenalty,
                    enablePresencePenalty: enablePresencePenalty,
                    seed: seed,
                    enableSeed: enableSeed,
                    customParameters: customParameters,
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

/// Shows a dialog to add a custom parameter to an assistant.
void showAddCustomParameterDialog(
  BuildContext context,
  void Function(String name, String type, dynamic value) onAdd,
) {
  final nameController = TextEditingController();
  String type = 'string';
  final valueController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: const Text('添加自定义参数'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '参数名',
                hintText: '如: top_k',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(
                labelText: '类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'string', child: Text('字符串')),
                DropdownMenuItem(value: 'number', child: Text('数字')),
                DropdownMenuItem(value: 'boolean', child: Text('布尔')),
                DropdownMenuItem(value: 'json', child: Text('JSON')),
              ],
              onChanged: (v) {
                if (v != null) setDlgState(() => type = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueController,
              decoration: InputDecoration(
                labelText: '值',
                hintText: type == 'boolean'
                    ? 'true 或 false'
                    : type == 'number'
                        ? '输入数字'
                        : type == 'json'
                            ? '例如: {"key": "value"}'
                            : '输入值',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
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
              dynamic value = valueController.text.trim();
              if (type == 'number') {
                value = double.tryParse(value) ??
                    int.tryParse(value) ??
                    value;
              } else if (type == 'boolean') {
                value = (value as String).toLowerCase() == 'true';
              } else if (type == 'json') {
                try {
                  value = jsonDecode(value as String);
                } catch (_) {
                  // Keep as string if not valid JSON
                }
              }
              onAdd(name, type, value);
              nameController.dispose();
              valueController.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    ),
  );
}

/// Shows a dialog to edit an existing custom parameter.
void showEditCustomParameterDialog(
  BuildContext context,
  CustomParameter cp,
  void Function(String name, String type, dynamic value) onEdit,
) {
  final nameController = TextEditingController(text: cp.name);
  String type = cp.type;
  // Display JSON values using jsonEncode (proper JSON format) instead of
  // .toString() (Dart format like {key: value}) which would produce
  // invalid JSON and break round-trip editing.
  String initialValue;
  if (cp.type == 'json' && (cp.value is Map || cp.value is List)) {
    initialValue = jsonEncode(cp.value);
  } else {
    initialValue = cp.value?.toString() ?? '';
  }
  final valueController = TextEditingController(text: initialValue);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: const Text('编辑自定义参数'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '参数名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(
                labelText: '类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'string', child: Text('字符串')),
                DropdownMenuItem(value: 'number', child: Text('数字')),
                DropdownMenuItem(value: 'boolean', child: Text('布尔')),
                DropdownMenuItem(value: 'json', child: Text('JSON')),
              ],
              onChanged: (v) {
                if (v != null) setDlgState(() => type = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: '值',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
              dynamic value = valueController.text.trim();
              if (type == 'number') {
                value = double.tryParse(value) ??
                    int.tryParse(value) ??
                    value;
              } else if (type == 'boolean') {
                value = (value as String).toLowerCase() == 'true';
              } else if (type == 'json') {
                try {
                  value = jsonDecode(value as String);
                } catch (_) {
                  // Keep as string if not valid JSON
                }
              }
              onEdit(name, type, value);
              nameController.dispose();
              valueController.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}
