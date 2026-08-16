part of 'settings_page.dart';

extension _SettingsPageSystemAssistantExt on _SettingsPageState {
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
    final llmModels =
        availableLlmModels(ref.watch(providerEntriesProvider));
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '自动任务（标题生成 / 上下文压缩）独立配置使用的模型与提示词，'
                '默认跟随对话页当前模型并使用内置提示词',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            _buildSystemAssistantTile(
              icon: Icons.title,
              iconColor: Colors.teal,
              title: '标题生成助手',
              subtitle: '自动生成对话标题',
              task: settings.title,
              llmModels: llmModels,
              defaultAssistantId: kBuiltInTitleAssistantId,
              onSave: (cfg) => ref
                  .read(systemAssistantSettingsProvider.notifier)
                  .setTitleTask(cfg),
            ),
            const Divider(height: 1),
            _buildSystemAssistantTile(
              icon: Icons.compress,
              iconColor: Colors.indigo,
              title: '上下文压缩助手',
              subtitle: '对话过长时压缩为锚定摘要',
              task: settings.compaction,
              llmModels: llmModels,
              defaultAssistantId: kBuiltInCompactionAssistantId,
              onSave: (cfg) => ref
                  .read(systemAssistantSettingsProvider.notifier)
                  .setCompactionTask(cfg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemAssistantTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required SystemAssistantTaskConfig task,
    required List<AvailableModel> llmModels,
    required String defaultAssistantId,
    required ValueChanged<SystemAssistantTaskConfig> onSave,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      // 模型名显示格式与对话页一致（"模型名 | 供应商名"）；未配置时
      // 提示跟随对话页当前模型。
      subtitle: Text(
        _systemAssistantModelSubtitle(task, llmModels),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showSystemAssistantPanel(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        defaultAssistantId: defaultAssistantId,
        task: task,
        onSave: onSave,
      ),
    );
  }

  /// 任务使用的模型显示名（对话页格式）；未配置时返回跟随提示。
  String _systemAssistantModelSubtitle(
    SystemAssistantTaskConfig task,
    List<AvailableModel> models,
  ) {
    final resolved = resolveModelRef(
      models: models,
      modelId: task.modelId,
      providerName: task.providerName,
      displayName: task.modelDisplayName,
    );
    if (resolved != null) return resolved.displayName;
    if (task.modelDisplayName != null && task.modelDisplayName!.isNotEmpty) {
      return task.modelDisplayName!;
    }
    return '跟随对话页当前模型';
  }

  Future<void> _showSystemAssistantPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String defaultAssistantId,
    required SystemAssistantTaskConfig task,
    required ValueChanged<SystemAssistantTaskConfig> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SystemAssistantConfigPanel(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        defaultAssistantId: defaultAssistantId,
        initial: task,
        onSave: onSave,
      ),
    );
  }
}

/// 系统助手配置面板：选择使用的模型 + 编辑提示词 + 重置为默认。
///
/// 采用草稿制：面板内修改不立即持久化，点「保存」才写入；「重置为默认
/// 提示词」带二次确认（AlertDialog），确认后仅把草稿恢复为内置默认，
/// 同样随保存生效。
class _SystemAssistantConfigPanel extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String defaultAssistantId;

  /// 面板打开时的任务配置（草稿起点）。
  final SystemAssistantTaskConfig initial;

  /// 保存回调：面板组装好的完整任务配置（模型引用 + 提示词）。
  final ValueChanged<SystemAssistantTaskConfig> onSave;

  const _SystemAssistantConfigPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.defaultAssistantId,
    required this.initial,
    required this.onSave,
  });

  @override
  ConsumerState<_SystemAssistantConfigPanel> createState() =>
      _SystemAssistantConfigPanelState();
}

class _SystemAssistantConfigPanelState
    extends ConsumerState<_SystemAssistantConfigPanel> {
  late SystemAssistantTaskConfig _draft;
  late bool _isCustomPrompt;
  late final String _defaultPrompt;
  late final TextEditingController _promptController;
  List<AvailableModel> _models = const [];
  List<String> _modelNames = const [];

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _isCustomPrompt = widget.initial.hasPrompt;
    _defaultPrompt =
        builtInSystemAssistantById(widget.defaultAssistantId)?.prompt ?? '';
    _promptController = TextEditingController(
      text: _isCustomPrompt ? widget.initial.prompt! : _defaultPrompt,
    );
    _models = availableLlmModels(ref.read(providerEntriesProvider));
    final baseNames = _models.map((m) => m.displayName).toList();
    _modelNames = baseNames;
    // 模型列表顺序与对话页共用同一份保存顺序（拖动排序）。
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _modelNames =
            applySavedOrder(baseNames, prefs.getStringList('model_order'));
      });
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  /// 当前选择在模型列表中的显示名（解析到最新显示名；引用已失效时
  /// 展示保存的显示名兜底）。
  String get _selectedModelDisplay {
    final resolved = resolveModelRef(
      models: _models,
      modelId: _draft.modelId,
      providerName: _draft.providerName,
      displayName: _draft.modelDisplayName,
    );
    if (resolved != null) return resolved.displayName;
    if (_draft.modelDisplayName != null && _draft.modelDisplayName!.isNotEmpty) {
      return _draft.modelDisplayName!;
    }
    return '跟随对话页当前模型';
  }

  Future<void> _pickModel() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final currentDisplay = _selectedModelDisplay;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  '选择模型',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              // 回退到"跟随对话页当前模型"的选项：即使没有可用模型
              // 也始终提供（可清除已保存的失效引用）。
              ListTile(
                dense: true,
                title: const Text('跟随对话页当前模型'),
                trailing: !_draft.hasModel
                    ? Icon(Icons.check, size: 18, color: cs.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final name in _modelNames)
                ListTile(
                  dense: true,
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: currentDisplay == name
                      ? Icon(Icons.check, size: 18, color: cs.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, name),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() {
      if (selected.isEmpty) {
        _draft = _draft.copyWithModel(clearModel: true);
      } else {
        final resolved =
            _models.where((m) => m.displayName == selected).firstOrNull;
        _draft = _draft.copyWithModel(
          modelId: resolved?.modelId,
          providerName: resolved?.providerName,
          modelDisplayName: resolved?.displayName ?? selected,
        );
      }
    });
  }

  /// 重置提示词为默认：先二次确认，再把草稿恢复为内置默认提示词。
  Future<void> _resetPromptToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置为默认提示词'),
        content: Text(
          '将「${widget.title}」的提示词恢复为内置默认，'
          '当前自定义内容将被丢弃。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('重置'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _isCustomPrompt = false;
      _promptController.text = _defaultPrompt;
    });
  }

  void _save() {
    final text = _promptController.text.trim();
    // 自定义但为空 → 视为默认（避免空字符串提示词被当作自定义生效）。
    final prompt = _isCustomPrompt && text.isNotEmpty ? text : null;
    widget.onSave(_draft.copyWithPrompt(prompt));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[350],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(widget.icon, size: 18, color: widget.iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        widget.subtitle,
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
            const SizedBox(height: 16),
            // 使用的模型
            Text(
              '使用的模型',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Material(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  _selectedModelDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                ),
                // 始终可点：无可用模型时选择面板仍提供
                // "跟随对话页当前模型"（清除失效引用）。
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _pickModel,
              ),
            ),
            const SizedBox(height: 16),
            // 提示词
            Text(
              '提示词',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _promptController,
              maxLines: 6,
              minLines: 4,
              style: const TextStyle(fontSize: 13, height: 1.4),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: '修改后将作为自定义提示词生效',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              onChanged: (v) {
                // 清空 → 视为回到默认提示词（保存时 prompt=null），
                // 与标签/重置按钮状态保持一致；输入内容 → 自定义。
                final isEmpty = v.trim().isEmpty;
                if (isEmpty && _isCustomPrompt) {
                  setState(() => _isCustomPrompt = false);
                } else if (!isEmpty && !_isCustomPrompt) {
                  setState(() => _isCustomPrompt = true);
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isCustomPrompt ? '当前使用自定义提示词' : '当前使用默认提示词',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isCustomPrompt ? _resetPromptToDefault : null,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('重置为默认提示词'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}