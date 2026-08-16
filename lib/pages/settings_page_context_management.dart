part of 'settings_page.dart';

extension _SettingsPageContextManagementExt on _SettingsPageState {
  // ================================================================
  // 上下文管理（prune / 压缩触发）
  // ================================================================

  Widget _buildContextManagementSettings() {
    final settings = ref.watch(contextManagementSettingsProvider);
    final notifier = ref.read(contextManagementSettingsProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('工具结果自动清理 (Prune)'),
              subtitle: const Text(
                '旧工具结果超过阈值时自动压缩为占位符，释放存储与上下文',
              ),
              value: settings.pruneEnabled,
              onChanged: notifier.setPruneEnabled,
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.compress),
              title: '压缩触发设置',
              subtitle: settings.compactionEnabled
                  ? _compactionSummary(settings)
                  : '已关闭（不触发压缩）',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _CompactionSettingsPanel(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _compactionSummary(ContextManagementSettings settings) {
    final overrides = settings.perModelCompaction.values
        .where((c) => c.enabled && c.threshold != null)
        .length;
    final base = '全局触发 ${settings.globalCompactionPercent}%';
    return overrides > 0 ? '$base · $overrides 个模型独立设置' : base;
  }
}

/// 压缩触发设置面板：总开关 + 全局百分比 + 逐模型独立设置。
///
/// - 总开关（[ContextManagementSettings.compactionEnabled]）关闭后，
///   下方所有设置置灰且不可操作。
/// - 全局百分比默认 [kDefaultCompactionPercent]，可修改并一键重置。
/// - 每个模型带独立开关：开启后填写具体 token 触发值（非百分比），
///   关闭则跟随全局百分比。模型显示名与对话页一致（"模型名 | 供应商"）。
class _CompactionSettingsPanel extends ConsumerStatefulWidget {
  const _CompactionSettingsPanel();

  @override
  ConsumerState<_CompactionSettingsPanel> createState() =>
      _CompactionSettingsPanelState();
}

class _CompactionSettingsPanelState
    extends ConsumerState<_CompactionSettingsPanel> {
  /// 对话页保存的全局模型拖动排序，用于与对话页一致的显示顺序。
  List<String>? _savedModelOrder;

  @override
  void initState() {
    super.initState();
    _loadSavedModelOrder();
  }

  Future<void> _loadSavedModelOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _savedModelOrder = prefs.getStringList('model_order'));
    } catch (e) {
      debugPrint('CompactionSettingsPanel load model order failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(contextManagementSettingsProvider);
    final notifier = ref.read(contextManagementSettingsProvider.notifier);
    ref.watch(providerEntriesProvider); // 供应商配置变化时重建模型列表
    final enabled = settings.compactionEnabled;
    final colorScheme = Theme.of(context).colorScheme;
    final models = _buildModelList();

    return Scaffold(
      appBar: AppBar(title: const Text('压缩触发设置'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('上下文自动压缩'),
            subtitle: const Text('关闭后所有模型都不触发压缩'),
            value: settings.compactionEnabled,
            onChanged: notifier.setCompactionEnabled,
          ),
          const Divider(height: 24),
          // 总开关关闭时，下方所有设置置灰且不可操作。
          Opacity(
            key: const Key('compaction-settings-body'),
            opacity: enabled ? 1.0 : 0.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '全局触发百分比',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '未单独设置的模型，按模型上下文窗口的该百分比触发压缩',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PercentField(
                        value: settings.globalCompactionPercent,
                        enabled: enabled,
                        onChanged: notifier.setGlobalCompactionPercent,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: '重置为 $kDefaultCompactionPercent%',
                      onPressed: enabled
                          ? notifier.resetGlobalCompactionPercent
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text(
                  '按模型设置',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                if (models.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '暂无已配置的模型',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final m in models)
                    _PerModelRow(
                      modelKey: m.modelKey,
                      displayName: m.displayName,
                      config: settings.perModelConfig(m.modelKey),
                      globalPercent: settings.globalCompactionPercent,
                      enabled: enabled,
                      onToggle: (v) =>
                          notifier.setPerModelEnabled(m.modelKey, v),
                      onThresholdChanged: (v) =>
                          notifier.setPerModelThreshold(m.modelKey, v),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 从 LLM 供应商配置构建模型列表，显示格式与对话页一致
  /// （"模型名 | 供应商名"），并按保存的全局拖动排序展示。
  /// 持久化 key 使用 [compactionModelKey]（含供应商维度）；
  /// 无 modelId 的模型无法按模型定位，跳过（跟随全局百分比）。
  List<_PanelModel> _buildModelList() {
    final entries = ref.read(providerEntriesProvider);
    final llmEntry = entries.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry == null) return const [];
    final result = <_PanelModel>[];
    // 相同的 (providerName, modelId) 视为同一模型：只显示一行，
    // 避免同供应商配置多个 host 时出现共享同一设置的重复行。
    final seen = <String>{};
    for (final config in llmEntry.configs) {
      for (final model in config.models) {
        if (model.modelId.trim().isEmpty) continue;
        final modelKey = compactionModelKey(
          modelId: model.modelId,
          providerName: config.providerName,
        );
        if (!seen.add(modelKey)) continue;
        result.add(_PanelModel(
          modelKey: modelKey,
          displayName:
              '${model.name.isNotEmpty ? model.name : model.modelId} | ${config.providerName}',
        ));
      }
    }
    final savedOrder = _savedModelOrder;
    if (savedOrder != null && savedOrder.isNotEmpty && result.length > 1) {
      final ordered =
          applySavedOrder(result.map((m) => m.displayName).toList(), savedOrder);
      result.sort((a, b) => ordered
          .indexOf(a.displayName)
          .compareTo(ordered.indexOf(b.displayName)));
    }
    return result;
  }
}

class _PanelModel {
  final String modelKey;
  final String displayName;

  const _PanelModel({required this.modelKey, required this.displayName});
}

/// 单个模型的压缩设置行：独立开关 + （开启时）具体 token 触发值输入框。
class _PerModelRow extends StatelessWidget {
  final String modelKey;
  final String displayName;
  final PerModelCompactionConfig? config;
  final int globalPercent;

  /// 总开关是否开启（关闭时整行置灰不可操作）。
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int?> onThresholdChanged;

  const _PerModelRow({
    required this.modelKey,
    required this.displayName,
    required this.config,
    required this.globalPercent,
    required this.enabled,
    required this.onToggle,
    required this.onThresholdChanged,
  });

  @override
  Widget build(BuildContext context) {
    final perModelEnabled = config?.enabled ?? false;
    final threshold = config?.threshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(displayName, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            perModelEnabled
                ? (threshold != null
                    ? '独立触发值 $threshold token'
                    : '填写下方独立触发值')
                : '跟随全局 $globalPercent%',
          ),
          value: perModelEnabled,
          onChanged: enabled ? onToggle : null,
        ),
        if (perModelEnabled)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: _TokenField(
              key: ValueKey('model-token-$modelKey'),
              value: threshold,
              enabled: enabled,
              onChanged: onThresholdChanged,
            ),
          ),
      ],
    );
  }
}

/// 模型独立压缩触发值输入框（token 数）：受控 controller + 外部状态同步。
///
/// 用 controller 而非 initialValue（非受控）：非法输入/清空时
/// provider 状态被置 null（该模型回退全局百分比），输入框必须同步清空，
/// 否则 UI 与状态脱节（显示已无效的文本）。
class _TokenField extends StatefulWidget {
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _TokenField({
    super.key,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  State<_TokenField> createState() => _TokenFieldState();
}

class _TokenFieldState extends State<_TokenField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value?.toString() ?? '');

  /// 最近一次被 provider 接受的值（非法/过小输入失焦时回退显示）。
  String _lastValidText = '';

  @override
  void initState() {
    super.initState();
    _lastValidText = widget.value?.toString() ?? '';
  }

  @override
  void didUpdateWidget(_TokenField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部值真正变化时（重置/外部修改）同步输入框。无关重建
    // （oldWidget.value == widget.value）不触碰正在编辑的输入框，
    // 避免把未生效的中间输入（如未达下限的 token）覆盖掉。
    if (widget.value != oldWidget.value) {
      final expected = widget.value?.toString() ?? '';
      _lastValidText = expected;
      if (_controller.text != expected) {
        _controller.text = expected;
      }
    }
  }

  /// 失焦/提交时校验：非法或过小（<[kMinCompactionThreshold]）的输入
  /// 回退为最近一次有效值，保持 UI 与 provider 状态一致。
  void _revertIfInvalid() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < kMinCompactionThreshold) {
      _controller.text = _lastValidText;
    } else {
      _lastValidText = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      decoration: const InputDecoration(
        labelText: '独立触发值 (token)',
        hintText: '如 48000（非百分比，直接填写 token 数）',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      // 输入即保存：空 → 清除该模型独立设置（回退全局百分比）；
      // 有效值（≥kMinCompactionThreshold）→ 保存。非法/过小值不推给
      // provider（保持原值，避免逐位输入数字时被下限拦截导致输入框清空），
      // 失焦/提交时回退显示。
      onChanged: (v) {
        final trimmed = v.trim();
        if (trimmed.isEmpty) {
          _lastValidText = '';
          widget.onChanged(null);
          return;
        }
        final parsed = int.tryParse(trimmed);
        if (parsed != null && parsed >= kMinCompactionThreshold) {
          _lastValidText = trimmed;
          widget.onChanged(parsed);
        }
      },
      // 失焦时：先回退非法输入，再真正失焦。自定义 onTapOutside 会完全
      // 替换框架默认的 EditableTextTapOutsideIntent（应用的全局
      // tap-outside 失焦覆盖因此不会生效），必须在这里显式失焦，否则
      // 光标会一直留在框内。
      onTapOutside: (_) {
        _revertIfInvalid();
        FocusScope.of(context).unfocus();
      },
      onFieldSubmitted: (_) => _revertIfInvalid(),
    );
  }
}

/// 全局压缩触发百分比输入框（1–100）：受控 controller + 外部状态同步。
class _PercentField extends StatefulWidget {
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _PercentField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_PercentField> createState() => _PercentFieldState();
}

class _PercentFieldState extends State<_PercentField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value.toString());

  /// 最近一次被 provider 接受的值（非法/越界输入失焦时回退显示）。
  late String _lastValidText;

  @override
  void initState() {
    super.initState();
    _lastValidText = widget.value.toString();
  }

  @override
  void didUpdateWidget(_PercentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部值真正变化时（如一键重置）同步输入框。无关重建
    // （oldWidget.value == widget.value）不触碰正在编辑的输入框，
    // 避免把未生效的中间输入（如越界的百分比）覆盖掉。
    if (widget.value != oldWidget.value) {
      final expected = widget.value.toString();
      _lastValidText = expected;
      if (_controller.text != expected) {
        _controller.text = expected;
      }
    }
  }

  /// 失焦/提交时校验：非法或越界（<1 或 >100）的输入回退为最近一次
  /// 有效值，保持 UI 与 provider 状态一致。
  void _revertIfInvalid() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _controller.text = _lastValidText;
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1 || parsed > 100) {
      _controller.text = _lastValidText;
    } else {
      _lastValidText = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const Key('global-percent-field'),
      controller: _controller,
      enabled: widget.enabled,
      decoration: const InputDecoration(
        labelText: '百分比',
        hintText: '如 $kDefaultCompactionPercent',
        suffixText: '%',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final trimmed = v.trim();
        if (trimmed.isEmpty) return; // 失焦时回退显示，不推 null
        final parsed = int.tryParse(trimmed);
        if (parsed != null && parsed >= 1 && parsed <= 100) {
          _lastValidText = trimmed;
          widget.onChanged(parsed);
        }
      },
      onTapOutside: (_) {
        _revertIfInvalid();
        FocusScope.of(context).unfocus();
      },
      onFieldSubmitted: (_) => _revertIfInvalid(),
    );
  }
}
