part of 'assistant_selection_page.dart';

/// Mutable holder for the parameter settings edited in
/// [showAssistantFullEditDialog]'s "参数设置" tab.
class _EditDialogVars {
  _EditDialogVars({
    required this.temperature,
    required this.enableTemperature,
    required this.topP,
    required this.enableTopP,
    required this.maxTokens,
    required this.enableMaxTokens,
    required this.maxToolCalls,
    required this.enableMaxToolCalls,
    required this.streamOutput,
    required this.enableWebSearch,
    required this.frequencyPenalty,
    required this.enableFrequencyPenalty,
    required this.presencePenalty,
    required this.enablePresencePenalty,
    required this.seed,
    required this.enableSeed,
    required this.customParameters,
    this.defaultModelName,
    this.defaultToolNames = const {},
  });

  double temperature;
  bool enableTemperature;
  double topP;
  bool enableTopP;
  int maxTokens;
  bool enableMaxTokens;
  int maxToolCalls;
  bool enableMaxToolCalls;
  bool streamOutput;
  bool enableWebSearch;
  double frequencyPenalty;
  bool enableFrequencyPenalty;
  double presencePenalty;
  bool enablePresencePenalty;
  int? seed;
  bool enableSeed;
  List<CustomParameter> customParameters;

  /// 默认模型显示名（新建话题时应用；null = 跟随全局选择）。
  String? defaultModelName;

  /// 默认启用工具集合（新建话题时应用；未添加的工具保持关闭）。
  Set<String> defaultToolNames;

  /// 用户是否在"默认设置"tab 中改过默认模型。仅当为 true 时才把
  /// [defaultModelName] 写回助手——否则（如只改了名称/提示词就保存）
  /// 保持助手原有的默认模型不变。
  bool defaultsModelEngaged = false;

  /// 用户是否在"默认设置"tab 中改过默认工具。仅当为 true 时才把
  /// [defaultToolNames] 写回助手——否则保持"从未配置"（null）的
  /// 原始状态，新话题继续自动启用全部工具。
  bool defaultsToolsEngaged = false;
}

/// Builds the "参数设置" tab of the assistant edit dialog.
/// Reads and mutates settings through [vars]; every mutation must be wrapped
/// in [setDlgState] by the caller of this builder.
Widget _buildEditParamsTab({
  required BuildContext context,
  required StateSetter setDlgState,
  required _EditDialogVars vars,
  required TextEditingController seedController,
}) {
  return SingleChildScrollView(
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
                  .withValues(alpha: 0.3),
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
          subtitle: Text('${vars.temperature}'),
          value: vars.enableTemperature,
          onChanged: (v) => setDlgState(() => vars.enableTemperature = v),
        ),
        if (vars.enableTemperature)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Slider(
              value: vars.temperature,
              min: 0,
              max: 2,
              divisions: 40,
              label: vars.temperature.toStringAsFixed(2),
              onChanged: (v) => setDlgState(() => vars.temperature = v),
            ),
          ),
        const Divider(),

        // Top P
        SwitchListTile(
          title: const Text('Top P'),
          subtitle: Text('${vars.topP}'),
          value: vars.enableTopP,
          onChanged: (v) => setDlgState(() => vars.enableTopP = v),
        ),
        if (vars.enableTopP)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Slider(
              value: vars.topP,
              min: 0,
              max: 1,
              divisions: 20,
              label: vars.topP.toStringAsFixed(2),
              onChanged: (v) => setDlgState(() => vars.topP = v),
            ),
          ),
        const Divider(),

        // Max Tokens
        SwitchListTile(
          title: const Text('最大Token数 (Max Tokens)'),
          subtitle: Text('${vars.maxTokens}'),
          value: vars.enableMaxTokens,
          onChanged: (v) => setDlgState(() => vars.enableMaxTokens = v),
        ),
        if (vars.enableMaxTokens)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Slider(
              value: vars.maxTokens.toDouble(),
              min: 256,
              max: 32768,
              divisions: 127,
              label: '${vars.maxTokens}',
              onChanged: (v) => setDlgState(() => vars.maxTokens = v.round()),
            ),
          ),
        const Divider(),

        // Max Tool Calls
        SwitchListTile(
          title: const Text('工具调用上限 (Max Tool Calls)'),
          subtitle: vars.enableMaxToolCalls
              ? Text('${vars.maxToolCalls} 轮')
              : const Text('无限制'),
          value: vars.enableMaxToolCalls,
          onChanged: (v) => setDlgState(() => vars.enableMaxToolCalls = v),
        ),
        if (vars.enableMaxToolCalls)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: '轮数',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: '${vars.maxToolCalls}'),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0) vars.maxToolCalls = n;
              },
            ),
          ),
        const Divider(),

        // Stream Output
        SwitchListTile(
          title: const Text('流式输出 (Stream Output)'),
          value: vars.streamOutput,
          onChanged: (v) => setDlgState(() => vars.streamOutput = v),
        ),
        const Divider(),

        // Frequency Penalty
        SwitchListTile(
          title: const Text('频率惩罚 (Frequency Penalty)'),
          subtitle: Text('${vars.frequencyPenalty}'),
          value: vars.enableFrequencyPenalty,
          onChanged: (v) => setDlgState(() => vars.enableFrequencyPenalty = v),
        ),
        if (vars.enableFrequencyPenalty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Slider(
              value: vars.frequencyPenalty,
              min: -2,
              max: 2,
              divisions: 40,
              label: vars.frequencyPenalty.toStringAsFixed(2),
              onChanged: (v) => setDlgState(() => vars.frequencyPenalty = v),
            ),
          ),
        const Divider(),

        // Presence Penalty
        SwitchListTile(
          title: const Text('存在惩罚 (Presence Penalty)'),
          subtitle: Text('${vars.presencePenalty}'),
          value: vars.enablePresencePenalty,
          onChanged: (v) => setDlgState(() => vars.enablePresencePenalty = v),
        ),
        if (vars.enablePresencePenalty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Slider(
              value: vars.presencePenalty,
              min: -2,
              max: 2,
              divisions: 40,
              label: vars.presencePenalty.toStringAsFixed(2),
              onChanged: (v) => setDlgState(() => vars.presencePenalty = v),
            ),
          ),
        const Divider(),

        // Seed
        SwitchListTile(
          title: const Text('随机种子 (Seed)'),
          subtitle: Text(vars.seed?.toString() ?? '未设置'),
          value: vars.enableSeed,
          onChanged: (v) => setDlgState(() => vars.enableSeed = v),
        ),
        if (vars.enableSeed)
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
                vars.seed = int.tryParse(v);
              }),
            ),
          ),
        const Divider(),

        // Web Search
        SwitchListTile(
          title: const Text('联网搜索'),
          value: vars.enableWebSearch,
          onChanged: (v) => setDlgState(() => vars.enableWebSearch = v),
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
                      vars.customParameters.add(
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
        if (vars.customParameters.isEmpty)
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
          ...vars.customParameters.asMap().entries.map((entry) {
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
                    vars.customParameters.removeAt(i);
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
                    vars.customParameters[i] = CustomParameter(
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
  );
}
