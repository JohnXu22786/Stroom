import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/assistant.dart';
import '../providers/assistant_provider.dart';
import 'topic_selection_page.dart';

// ============================================================================
// Emoji picker data — expanded set with categories
// ============================================================================

const List<String> _allEmojis = [
  // Smileys & People
  '😀', '😃', '😄', '😁', '😅', '🤣', '😂', '🙂', '😊', '😇',
  '🥰', '😍', '🤩', '😘', '😗', '😚', '😙', '🥲', '😋', '😛',
  '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨',
  '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥', '😌', '😔',
  // Gestures & People
  '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👋', '🤚',
  '✋', '🖐️', '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲',
  // Animals & Nature
  '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
  '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🐤', '🦆',
  // Food & Drink
  '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
  '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑',
  // Activities
  '⚽', '🏀', '🏈', '⚾', '🎾', '🏐', '🏉', '🎱', '🏓', '🏸',
  '🥊', '🥋', '⛸️', '🎣', '🤿', '🎯', '🎳', '🎲', '🧩', '♟️',
  // Objects
  '💻', '📱', '⌚', '📷', '🎥', '📸', '🖥️', '🖨️', '⌨️', '🖱️',
  '📚', '📖', '📝', '✏️', '📌', '📍', '✂️', '🔒', '🔓', '🔑',
  // Symbols
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
  '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️',
  // Travel & Places
  '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐',
  '✈️', '🚀', '🛸', '🚁', '🛶', '⛵', '🚤', '🛳️', '🚂', '🏠',
];

// ============================================================================
// Helper widgets
// ============================================================================

/// Emoji grid widget used in create/edit dialogs.
class _EmojiGrid extends StatelessWidget {
  final String selectedEmoji;
  final ValueChanged<String> onSelected;

  const _EmojiGrid({
    required this.selectedEmoji,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _allEmojis.map((e) {
        final isSelected = e == selectedEmoji;
        return GestureDetector(
          onTap: () => onSelected(e),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected ? cs.primaryContainer : null,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: cs.primary)
                  : null,
            ),
            child: Text(e, style: const TextStyle(fontSize: 22)),
          ),
        );
      }).toList(),
    );
  }
}

/// Image picker tab content.
class _ImagePickerTab extends StatelessWidget {
  final String? selectedImagePath;
  final ValueChanged<String?> onImagePicked;

  const _ImagePickerTab({
    required this.selectedImagePath,
    required this.onImagePicked,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Preview
        if (selectedImagePath != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(selectedImagePath!),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('移除图片'),
            onPressed: () => onImagePicked(null),
          ),
          const SizedBox(height: 12),
        ],
        // From gallery
        FilledButton.icon(
          icon: const Icon(Icons.photo_library),
          label: const Text('从相册选择'),
          onPressed: () async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 256,
              maxHeight: 256,
            );
            if (picked != null) {
              onImagePicked(picked.path);
            }
          },
        ),
        const SizedBox(height: 8),
        // From camera
        OutlinedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text('拍照'),
          onPressed: () async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: ImageSource.camera,
              maxWidth: 256,
              maxHeight: 256,
            );
            if (picked != null) {
              onImagePicked(picked.path);
            }
          },
        ),
      ],
    );
  }
}

// ============================================================================
// First page: assistant grid
// ============================================================================

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
    ref.read(selectedAssistantIdProvider.notifier).state = assistant.id;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TopicSelectionPage()),
    );
  }

  // --------------------------------------------------------------------------
  // Create assistant dialog
  // --------------------------------------------------------------------------

  void _showCreateAssistantDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final promptController = TextEditingController(
        text: '你是一个有帮助的AI助手。请用中文回答用户的问题。');
    String selectedEmoji = '🤖';
    String? selectedImagePath;
    final descriptionController = TextEditingController();
    int avatarTabIndex = 0; // 0=Emoji, 1=Image

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('新建助手'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab bar for Emoji / Image picker
                  const Text('头像', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: Row(
                      children: [
                        _buildTab('Emoji', avatarTabIndex == 0, () =>
                            setDlgState(() => avatarTabIndex = 0)),
                        const SizedBox(width: 8),
                        _buildTab('图片', avatarTabIndex == 1, () =>
                            setDlgState(() => avatarTabIndex = 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tab content
                  SizedBox(
                    height: 140,
                    child: avatarTabIndex == 0
                        ? _EmojiGrid(
                            selectedEmoji: selectedEmoji,
                            onSelected: (e) => setDlgState(() {
                              selectedEmoji = e;
                              selectedImagePath = null;
                            }),
                          )
                        : _ImagePickerTab(
                            selectedImagePath: selectedImagePath,
                            onImagePicked: (path) => setDlgState(() {
                              selectedImagePath = path;
                            }),
                          ),
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
                    maxLines: 3,
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
                ref.read(assistantProvider.notifier).createAssistant(
                      name: name,
                      prompt: promptController.text.trim(),
                      emoji: selectedEmoji,
                      avatarPath: selectedImagePath,
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

  // --------------------------------------------------------------------------
  // Helper: build a tab button
  // --------------------------------------------------------------------------

  Widget _buildTab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.grey.shade400,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Assistant bottom menu
  // --------------------------------------------------------------------------

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
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
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

  // --------------------------------------------------------------------------
  // Edit assistant dialog
  // --------------------------------------------------------------------------

  void _showEditAssistantDialog(
      BuildContext context, WidgetRef ref, Assistant assistant) {
    final nameController = TextEditingController(text: assistant.name);
    final promptController = TextEditingController(text: assistant.prompt);
    String selectedEmoji = assistant.emoji;
    String? selectedImagePath = assistant.avatarPath;
    final descriptionController =
        TextEditingController(text: assistant.description);
    int avatarTabIndex = assistant.avatarPath != null ? 1 : 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('编辑助手'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab bar for Emoji / Image picker
                  const Text('头像', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: Row(
                      children: [
                        _buildTab('Emoji', avatarTabIndex == 0, () =>
                            setDlgState(() => avatarTabIndex = 0)),
                        const SizedBox(width: 8),
                        _buildTab('图片', avatarTabIndex == 1, () =>
                            setDlgState(() => avatarTabIndex = 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tab content
                  SizedBox(
                    height: 140,
                    child: avatarTabIndex == 0
                        ? _EmojiGrid(
                            selectedEmoji: selectedEmoji,
                            onSelected: (e) => setDlgState(() {
                              selectedEmoji = e;
                              selectedImagePath = null;
                            }),
                          )
                        : _ImagePickerTab(
                            selectedImagePath: selectedImagePath,
                            onImagePicked: (path) => setDlgState(() {
                              selectedImagePath = path;
                            }),
                          ),
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
                    maxLines: 3,
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
                ref.read(assistantProvider.notifier).updateAssistant(
                      id: assistant.id,
                      name: name,
                      prompt: promptController.text.trim(),
                      emoji: selectedEmoji,
                      avatarPath: selectedImagePath,
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

  // --------------------------------------------------------------------------
  // Assistant settings dialog — extended params + custom params + override
  // --------------------------------------------------------------------------

  void _showAssistantSettingsDialog(
      BuildContext context, WidgetRef ref, Assistant assistant) {
    // Clone current settings for editing
    double temperature = assistant.settings.temperature;
    bool enableTemperature = assistant.settings.enableTemperature;
    double topP = assistant.settings.topP;
    bool enableTopP = assistant.settings.enableTopP;
    int maxTokens = assistant.settings.maxTokens;
    bool enableMaxTokens = assistant.settings.enableMaxTokens;
    int topK = assistant.settings.topK;
    bool enableTopK = assistant.settings.enableTopK;
    double frequencyPenalty = assistant.settings.frequencyPenalty;
    bool enableFrequencyPenalty = assistant.settings.enableFrequencyPenalty;
    double presencePenalty = assistant.settings.presencePenalty;
    bool enablePresencePenalty = assistant.settings.enablePresencePenalty;
    bool streamOutput = assistant.settings.streamOutput;
    String reasoningEffort = assistant.settings.reasoningEffort;
    bool enableWebSearch = assistant.settings.enableWebSearch;
    int maxToolCalls = assistant.settings.maxToolCalls;
    bool enableMaxToolCalls = assistant.settings.enableMaxToolCalls;
    bool overrideModelSettings = assistant.settings.overrideModelSettings;
    List<CustomParameter> customParameters =
        List.from(assistant.settings.customParameters);

    // Controllers for adding a custom parameter
    final paramNameController = TextEditingController();
    final paramValueController = TextEditingController();
    String paramType = 'string';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('助手参数设置'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------------------------------
                  // Temperature
                  // ------------------------------------------------------------------
                  _buildParamSwitch(
                    label: '温度 (Temperature)',
                    subtitle: temperature.toStringAsFixed(2),
                    value: enableTemperature,
                    onChanged: (v) => setDlgState(() => enableTemperature = v),
                  ),
                  if (enableTemperature)
                    _buildSlider(
                      value: temperature,
                      min: 0,
                      max: 2,
                      divisions: 40,
                      label: temperature.toStringAsFixed(2),
                      onChanged: (v) => setDlgState(() => temperature = v),
                    ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Top P
                  // ------------------------------------------------------------------
                  _buildParamSwitch(
                    label: 'Top P',
                    subtitle: topP.toStringAsFixed(2),
                    value: enableTopP,
                    onChanged: (v) => setDlgState(() => enableTopP = v),
                  ),
                  if (enableTopP)
                    _buildSlider(
                      value: topP,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: topP.toStringAsFixed(2),
                      onChanged: (v) => setDlgState(() => topP = v),
                    ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Top K
                  // ------------------------------------------------------------------
                  _buildParamSwitch(
                    label: 'Top K',
                    subtitle: topK.toString(),
                    value: enableTopK,
                    onChanged: (v) => setDlgState(() => enableTopK = v),
                  ),
                  if (enableTopK)
                    _buildSlider(
                      value: topK.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: topK.toString(),
                      onChanged: (v) => setDlgState(() => topK = v.round()),
                    ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Max Tokens
                  // ------------------------------------------------------------------
                  _buildParamSwitch(
                    label: '最大Token数 (Max Tokens)',
                    subtitle: maxTokens.toString(),
                    value: enableMaxTokens,
                    onChanged: (v) => setDlgState(() => enableMaxTokens = v),
                  ),
                  if (enableMaxTokens)
                    _buildSlider(
                      value: maxTokens.toDouble(),
                      min: 256,
                      max: 32768,
                      divisions: 127,
                      label: maxTokens.toString(),
                      onChanged: (v) =>
                          setDlgState(() => maxTokens = v.round()),
                    ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Frequency Penalty
                  // ------------------------------------------------------------------
                  _buildParamSwitch(
                    label: '频率惩罚 (Frequency Penalty)',
                    subtitle: frequencyPenalty.toStringAsFixed(2),
                    value: enableFrequencyPenalty,
                    onChanged: (v) =>
                        setDlgState(() => enableFrequencyPenalty = v),
                  ),
                  if (enableFrequencyPenalty)
                    _buildSlider(
                      value: frequencyPenalty,
                      min: -2,
                      max: 2,
                      divisions: 40,
                      label: frequencyPenalty.toStringAsFixed(2),
                      onChanged: (v) =>
                          setDlgState(() => frequencyPenalty = v),
                    ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Presence Penalty
                  // ------------------------------------------------------------------
                  _buildParamSwitch(
                    label: '存在惩罚 (Presence Penalty)',
                    subtitle: presencePenalty.toStringAsFixed(2),
                    value: enablePresencePenalty,
                    onChanged: (v) =>
                        setDlgState(() => enablePresencePenalty = v),
                  ),
                  if (enablePresencePenalty)
                    _buildSlider(
                      value: presencePenalty,
                      min: -2,
                      max: 2,
                      divisions: 40,
                      label: presencePenalty.toStringAsFixed(2),
                      onChanged: (v) =>
                          setDlgState(() => presencePenalty = v),
                    ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Stream Output
                  // ------------------------------------------------------------------
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('流式输出 (Stream Output)',
                        style: TextStyle(fontSize: 14)),
                    value: streamOutput,
                    onChanged: (v) => setDlgState(() => streamOutput = v),
                  ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Reasoning Effort
                  // ------------------------------------------------------------------
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('推理努力度',
                        style: TextStyle(fontSize: 14)),
                    subtitle: Text(_reasoningLabel(reasoningEffort),
                        style: const TextStyle(fontSize: 12)),
                    trailing: DropdownButton<String>(
                      value: reasoningEffort,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                            value: 'default', child: Text('默认')),
                        DropdownMenuItem(value: 'low', child: Text('低')),
                        DropdownMenuItem(value: 'high', child: Text('高')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDlgState(() => reasoningEffort = v);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Web Search
                  // ------------------------------------------------------------------
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('联网搜索',
                        style: TextStyle(fontSize: 14)),
                    value: enableWebSearch,
                    onChanged: (v) =>
                        setDlgState(() => enableWebSearch = v),
                  ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Max Tool Calls
                  // ------------------------------------------------------------------
                  _buildParamSwitch(
                    label: '最大工具调用数 (Max Tool Calls)',
                    subtitle: maxToolCalls.toString(),
                    value: enableMaxToolCalls,
                    onChanged: (v) =>
                        setDlgState(() => enableMaxToolCalls = v),
                  ),
                  if (enableMaxToolCalls)
                    _buildSlider(
                      value: maxToolCalls.toDouble(),
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: maxToolCalls.toString(),
                      onChanged: (v) =>
                          setDlgState(() => maxToolCalls = v.round()),
                    ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Override Model Settings
                  // ------------------------------------------------------------------
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('覆盖模型设置',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text('启用后，助手参数将覆盖模型同名参数',
                        style: TextStyle(fontSize: 11)),
                    value: overrideModelSettings,
                    onChanged: (v) =>
                        setDlgState(() => overrideModelSettings = v),
                  ),
                  const Divider(height: 8),

                  // ------------------------------------------------------------------
                  // Custom Parameters
                  // ------------------------------------------------------------------
                  const Text('自定义参数',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  // Existing custom params
                  ...customParameters.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.code, size: 18),
                      title: Text(p.name,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${p.type}: ${p.value}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => setDlgState(() {
                          customParameters.removeAt(i);
                        }),
                      ),
                    );
                  }),
                  // Add new custom param
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: paramNameController,
                          decoration: const InputDecoration(
                            hintText: '参数名',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: paramType,
                          isDense: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 12),
                          items: const [
                            DropdownMenuItem(
                                value: 'string', child: Text('string')),
                            DropdownMenuItem(
                                value: 'number', child: Text('number')),
                            DropdownMenuItem(
                                value: 'boolean', child: Text('boolean')),
                            DropdownMenuItem(
                                value: 'json', child: Text('json')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDlgState(() => paramType = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: paramValueController,
                          decoration: const InputDecoration(
                            hintText: '值',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加参数',
                          style: TextStyle(fontSize: 13)),
                      onPressed: () {
                        final name = paramNameController.text.trim();
                        final valueStr = paramValueController.text.trim();
                        if (name.isEmpty || valueStr.isEmpty) return;

                        dynamic parsedValue = valueStr;
                        if (paramType == 'number') {
                          parsedValue = num.tryParse(valueStr) ?? valueStr;
                        } else if (paramType == 'boolean') {
                          parsedValue =
                              valueStr.toLowerCase() == 'true';
                        } else if (paramType == 'json') {
                          try {
                            parsedValue = 
                                // ignore: avoid_dynamic_calls
                                (jsonDecode(valueStr) as dynamic);
                          } catch (_) {
                            parsedValue = valueStr;
                          }
                        }

                        setDlgState(() {
                          customParameters.add(CustomParameter(
                            name: name,
                            type: paramType,
                            value: parsedValue,
                          ));
                          paramNameController.clear();
                          paramValueController.clear();
                        });
                      },
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
                ref.read(assistantProvider.notifier).updateAssistantSettings(
                      assistantId: assistant.id,
                      temperature: temperature,
                      enableTemperature: enableTemperature,
                      topP: topP,
                      enableTopP: enableTopP,
                      maxTokens: maxTokens,
                      enableMaxTokens: enableMaxTokens,
                      topK: topK,
                      enableTopK: enableTopK,
                      frequencyPenalty: frequencyPenalty,
                      enableFrequencyPenalty: enableFrequencyPenalty,
                      presencePenalty: presencePenalty,
                      enablePresencePenalty: enablePresencePenalty,
                      streamOutput: streamOutput,
                      reasoningEffort: reasoningEffort,
                      enableWebSearch: enableWebSearch,
                      maxToolCalls: maxToolCalls,
                      enableMaxToolCalls: enableMaxToolCalls,
                      overrideModelSettings: overrideModelSettings,
                      customParameters: customParameters,
                    );
                paramNameController.dispose();
                paramValueController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  String _reasoningLabel(String value) {
    switch (value) {
      case 'low':
        return '低';
      case 'high':
        return '高';
      default:
        return '默认';
    }
  }

  // --------------------------------------------------------------------------
  // Delete confirmation
  // --------------------------------------------------------------------------

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

  // --------------------------------------------------------------------------
  // Widget builders
  // --------------------------------------------------------------------------

  Widget _buildParamSwitch({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
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
    final hasAvatar = assistant.avatarPath != null;

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
              // Avatar: image or emoji
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: hasAvatar
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(assistant.avatarPath!),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(assistant.emoji,
                                style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                      )
                    : Center(
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
