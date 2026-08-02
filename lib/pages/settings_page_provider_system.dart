part of 'settings_page.dart';

extension _SettingsPageProviderSystemExt on _SettingsPageState {
  Widget _buildProviderSettings() {
    final entriesState = ref.watch(providerEntriesProvider);
    final entries = entriesState.entries;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [...entries.map((entry) => _buildProviderEntryTile(entry))],
        ),
      ),
    );
  }

  Widget _buildProviderEntryTile(ProviderEntry entry) {
    return ListTile(
      leading: Icon(
        Icons.business,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(entry.name),
      trailing: const Icon(Icons.chevron_right),
      contentPadding: EdgeInsets.zero,
      onTap: () => _openProviderConfig(entry.id),
    );
  }

  void _openProviderConfig(String entryId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProviderConfigPage(entryId: entryId)),
    );
  }

  // ================================================================
  // 系统助手（标题生成 / 上下文压缩）
  // ================================================================

  Widget _buildSystemAssistantSettings() {
    final settings = ref.watch(systemAssistantSettingsProvider);
    final assistants = ref.watch(assistantProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '对话页自动任务使用的助手（默认内置，可替换为自己的助手）',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            _buildSystemAssistantPickerTile(
              icon: Icons.title,
              iconColor: Colors.teal,
              title: '标题生成助手',
              subtitle: '自动生成对话标题',
              currentId: settings.titleAssistantId,
              assistants: assistants,
              onSelect: (id) => ref
                  .read(systemAssistantSettingsProvider.notifier)
                  .setTitleAssistant(id),
            ),
            const Divider(height: 1),
            _buildSystemAssistantPickerTile(
              icon: Icons.compress,
              iconColor: Colors.indigo,
              title: '上下文压缩助手',
              subtitle: '对话过长时压缩为锚定摘要',
              currentId: settings.compactionAssistantId,
              assistants: assistants,
              onSelect: (id) => ref
                  .read(systemAssistantSettingsProvider.notifier)
                  .setCompactionAssistant(id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemAssistantPickerTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String currentId,
    required List<Assistant> assistants,
    required ValueChanged<String> onSelect,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(
        systemAssistantDisplayName(
          assistantId: currentId,
          userAssistants: assistants,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showSystemAssistantPicker(
        title: title,
        currentId: currentId,
        assistants: assistants,
        onSelect: onSelect,
      ),
    );
  }

  Future<void> _showSystemAssistantPicker({
    required String title,
    required String currentId,
    required List<Assistant> assistants,
    required ValueChanged<String> onSelect,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('选择$title'),
        children: [
          for (final builtIn in builtInSystemAssistants)
            RadioListTile<String>(
              value: builtIn.id,
              // ignore: deprecated_member_use
              groupValue: currentId,
              title: Text('${builtIn.emoji} ${builtIn.name}'),
              subtitle: Text(
                builtIn.description,
                style: const TextStyle(fontSize: 12),
              ),
              // ignore: deprecated_member_use
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          for (final a in assistants)
            RadioListTile<String>(
              value: a.id,
              // ignore: deprecated_member_use
              groupValue: currentId,
              title: Text(a.name),
              subtitle: const Text(
                '自定义助手',
                style: TextStyle(fontSize: 12),
              ),
              // ignore: deprecated_member_use
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (selected != null) onSelect(selected);
  }
}
