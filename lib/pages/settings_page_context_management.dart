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
                '旧工具结果超过阈值时自动压缩为占位符，'
                '释放存储与上下文（opencode 语义）',
              ),
              value: settings.pruneEnabled,
              onChanged: notifier.setPruneEnabled,
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自定义压缩触发值'),
              subtitle: const Text(
                '关闭时：到达模型设置的上下文窗口即压缩；'
                '开启后：可设置更小的触发值',
              ),
              value: settings.customCompactionThresholdEnabled,
              onChanged: notifier.setCustomCompactionThresholdEnabled,
            ),
            if (settings.customCompactionThresholdEnabled) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _CompactionThresholdField(
                  value: settings.compactionThreshold,
                  onChanged: notifier.setCompactionThreshold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 压缩触发值输入框：受控 controller + 外部状态同步。
///
/// 用 controller 而非 initialValue（非受控）：非法输入/清空时
/// provider 状态被置 null（回退模型 context），输入框必须同步清空，
/// 否则 UI 与状态脱节（显示已无效的文本）。
class _CompactionThresholdField extends StatefulWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _CompactionThresholdField({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_CompactionThresholdField> createState() =>
      _CompactionThresholdFieldState();
}

class _CompactionThresholdFieldState extends State<_CompactionThresholdField> {
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
  void didUpdateWidget(_CompactionThresholdField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部值变化（如开关重新打开、设置被外部重置）时同步输入框。
    if (widget.value != null) {
      final expected = widget.value.toString();
      _lastValidText = expected;
      if (_controller.text != expected) {
        _controller.text = expected;
      }
    }
  }

  /// 失焦/提交时校验：非法或过小（<1000，provider 会拒绝）的输入
  /// 回退为最近一次有效值，保持 UI 与 provider 状态一致。
  void _revertIfInvalid() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1000) {
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
      decoration: const InputDecoration(
        labelText: '压缩触发值 (token)',
        hintText: '如 48000（小于模型上下文时提前压缩）',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      // 输入即保存：空 → 清除自定义值（回退模型 context）；
      // 有效值（≥1000）→ 保存。非法/过小值不推给 provider
      // （保持原值，避免逐位输入数字时被下限拦截导致输入框清空），
      // 失焦/提交时回退显示。
      onChanged: (v) {
        final trimmed = v.trim();
        if (trimmed.isEmpty) {
          _lastValidText = '';
          widget.onChanged(null);
          return;
        }
        final parsed = int.tryParse(trimmed);
        if (parsed != null && parsed >= 1000) {
          _lastValidText = trimmed;
          widget.onChanged(parsed);
        }
      },
      onTapOutside: (_) => _revertIfInvalid(),
      onFieldSubmitted: (_) => _revertIfInvalid(),
    );
  }
}
