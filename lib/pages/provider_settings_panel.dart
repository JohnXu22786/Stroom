import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/provider_config.dart';
import 'llm_model_config_shared.dart';

/// Shows a full-screen dialog to edit provider basic info and parameters.
/// Pattern follows [showAssistantFullEditDialog] from assistant_selection_page.dart.
Future<ProviderConfigItem?> showProviderSettingsPanel({
  required BuildContext context,
  required ProviderConfigItem config,
  required String providerType,
}) {
  return showDialog<ProviderConfigItem>(
    context: context,
    builder: (ctx) => _ProviderSettingsPanel(
      config: config.copy(),
      providerType: providerType,
    ),
  );
}

class _ProviderSettingsPanel extends StatefulWidget {
  final ProviderConfigItem config;
  final String providerType;

  const _ProviderSettingsPanel({
    required this.config,
    required this.providerType,
  });

  @override
  State<_ProviderSettingsPanel> createState() => _ProviderSettingsPanelState();
}

class _ProviderSettingsPanelState extends State<_ProviderSettingsPanel>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _keyController;
  bool _obscureKey = true;

  // Provider-level params (same structure as model params)
  late double _temperature;
  late double _topP;
  late double _frequencyPenalty;
  late double _presencePenalty;
  late bool _enableTemperature;
  late bool _enableTopP;
  late bool _enableFrequencyPenalty;
  late bool _enablePresencePenalty;
  late bool _enableMaxTokens;
  late bool _enableSeed;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _seedController;
  late List<CustomParam> _customParams;
  late List<ReasoningParam> _reasoningParams;

  bool get _isLlmType => widget.providerType == 'llm';

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _nameController = TextEditingController(text: c.providerName);
    _hostController = TextEditingController(text: c.host);
    _keyController = TextEditingController(text: c.key);

    _temperature = (c.typeConfig['temperature'] as num?)?.toDouble() ?? 0.7;
    _topP = (c.typeConfig['topP'] as num?)?.toDouble() ?? 1.0;
    _frequencyPenalty =
        (c.typeConfig['frequencyPenalty'] as num?)?.toDouble() ?? 0.0;
    _presencePenalty =
        (c.typeConfig['presencePenalty'] as num?)?.toDouble() ?? 0.0;

    _enableTemperature = c.typeConfig['enableTemperature'] as bool? ?? false;
    _enableTopP = c.typeConfig['enableTopP'] as bool? ?? false;
    _enableFrequencyPenalty =
        c.typeConfig['enableFrequencyPenalty'] as bool? ?? false;
    _enablePresencePenalty =
        c.typeConfig['enablePresencePenalty'] as bool? ?? false;
    _enableMaxTokens = c.typeConfig['enableMaxTokens'] as bool? ?? false;
    _enableSeed = c.typeConfig['enableSeed'] as bool? ?? false;

    final maxTokens = (c.typeConfig['maxTokens'] as num?)?.toInt();
    _maxTokensController = TextEditingController(
        text: maxTokens != null ? maxTokens.toString() : '');
    final seed = c.typeConfig['seed'];
    _seedController =
        TextEditingController(text: seed != null ? seed.toString() : '');

    _customParams = c.customParams.map((p) => p.copy()).toList();
    _reasoningParams = c.reasoningParams.map((p) => p.copy()).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _keyController.dispose();
    _maxTokensController.dispose();
    _seedController.dispose();
    super.dispose();
  }

  // =================================================================
  // Custom params
  // =================================================================
  void _addCustomParam() {
    setState(() {
      _customParams.insert(0, CustomParam(paramName: '', defaultValue: ''));
    });
  }

  void _removeCustomParam(int index) {
    setState(() {
      _customParams.removeAt(index);
    });
  }

  // =================================================================
  // Reasoning params (including inference intensity)
  // =================================================================
  void _addReasoningParam({bool isToggle = false}) {
    setState(() {
      _reasoningParams.add(ReasoningParam(
        paramName: '',
        enabled: false,
        isReasoningToggle: isToggle,
        options: [],
      ));
    });
  }

  void _removeReasoningParam(int index) {
    setState(() {
      _reasoningParams.removeAt(index);
    });
  }

  void _addOptionToParam(int paramIndex) {
    setState(() {
      _reasoningParams[paramIndex].options.add('');
    });
  }

  void _removeOptionFromParam(int paramIndex, int optionIndex) {
    setState(() {
      _reasoningParams[paramIndex].options.removeAt(optionIndex);
    });
  }

  ReasoningParam? get _toggleReasoningParam =>
      _reasoningParams.cast<ReasoningParam?>().firstWhere(
            (p) => p?.isReasoningToggle ?? false,
            orElse: () => null,
          );

  // =================================================================
  // Save
  // =================================================================
  bool _validate() {
    final name = _nameController.text.trim();
    final host = _hostController.text.trim();
    final key = _keyController.text.trim();

    if (name.isEmpty || host.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('供应商名称、API 地址 和 Key 均为必填项'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    // Validate custom params
    final seenNames = <String>{};
    for (final param in _customParams) {
      final pn = param.paramName.trim();
      if (pn.isEmpty || param.defaultValue.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('自定义参数的参数名和默认值不能为空'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      if (!seenNames.add(pn)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已存在该参数: $pn'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      // JSON 类型的默认值必须是合法 JSON
      if (param.type == 'json' && param.defaultValue.trim().isNotEmpty) {
        try {
          jsonDecode(param.defaultValue.trim());
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('参数 "$pn" 的默认值不是合法 JSON：${param.defaultValue}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return false;
        }
      }
    }

    // Validate reasoning params
    final toggleParam = _toggleReasoningParam;
    final hasNonToggleParams = _reasoningParams
        .any((p) => !p.isReasoningToggle && p.paramName.trim().isNotEmpty);

    if (hasNonToggleParams &&
        (toggleParam == null || !toggleParam.isFilledToggle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('推理开关必须先填写完整，其他推理参数才能生效'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    for (final param in _reasoningParams) {
      final error = param.validationError;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('推理参数错误：$error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    // Duplicate name check
    for (final param in _reasoningParams) {
      final pn = param.paramName.trim();
      if (pn.isEmpty) continue;
      if (!seenNames.add(pn)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('推理参数与自定义参数存在重名: $pn'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    // Validate maxTokens
    final maxTokensStr = _maxTokensController.text.trim();
    if (maxTokensStr.isNotEmpty) {
      final maxTokens = int.tryParse(maxTokensStr);
      if (maxTokens == null || maxTokens <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最大输出 Token 数必须为正整数'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    // Validate seed
    final seedStr = _seedController.text.trim();
    if (seedStr.isNotEmpty) {
      if (int.tryParse(seedStr) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('随机种子必须为整数'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    return true;
  }

  ProviderConfigItem _buildConfig() {
    final typeConfig = <String, dynamic>{};

    if (_enableTemperature) {
      typeConfig['temperature'] = _temperature;
    }
    if (_enableTopP) {
      typeConfig['topP'] = _topP;
    }
    if (_enableFrequencyPenalty) {
      typeConfig['frequencyPenalty'] = _frequencyPenalty;
    }
    if (_enablePresencePenalty) {
      typeConfig['presencePenalty'] = _presencePenalty;
    }

    typeConfig['enableTemperature'] = _enableTemperature;
    typeConfig['enableTopP'] = _enableTopP;
    typeConfig['enableFrequencyPenalty'] = _enableFrequencyPenalty;
    typeConfig['enablePresencePenalty'] = _enablePresencePenalty;
    typeConfig['enableMaxTokens'] = _enableMaxTokens;
    typeConfig['enableSeed'] = _enableSeed;

    final maxTokensStr = _maxTokensController.text.trim();
    if (maxTokensStr.isNotEmpty) {
      typeConfig['maxTokens'] = int.parse(maxTokensStr);
    }

    final seedStr = _seedController.text.trim();
    if (seedStr.isNotEmpty) {
      typeConfig['seed'] = int.tryParse(seedStr);
    }

    return ProviderConfigItem(
      providerName: _nameController.text.trim(),
      host: _hostController.text.trim(),
      key: _keyController.text.trim(),
      models: widget.config.models.map((m) => m.copy()).toList(),
      typeConfig: typeConfig,
      customParams: _customParams.map((p) => p.copy()).toList(),
      reasoningParams: _reasoningParams.map((p) => p.copy()).toList(),
    );
  }

  // =================================================================
  // Build - Basic Info Tab
  // =================================================================
  Widget _buildBasicInfoTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '供应商名称',
              hintText: '输入供应商名称',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label, color: Colors.teal),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'API 地址',
              hintText: '输入完整的 API 端点地址',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            decoration: InputDecoration(
              labelText: 'Key',
              hintText: '输入 API 密钥',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key, color: Colors.amber),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
            obscureText: _obscureKey,
          ),
        ],
      ),
    );
  }

  // =================================================================
  // Build - Parameter Settings Tab
  // =================================================================
  Widget _buildParameterSettingsTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Override rule explanation (like assistant settings)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '请求时将同时使用供应商和模型的所有已开启参数；如果存在重复参数，模型的参数值将覆盖供应商的。',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================================
          // 推理参数
          // ==========================================================
          if (_isLlmType) ...[
            Text('推理参数',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.primary)),
            const SizedBox(height: 4),
            Text(
              '推理开关控制聊天页面中推理功能的开启和关闭。'
              '推理力度参数允许只填参数名而不添加选项值。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _buildReasoningToggleSection(cs),
            _buildInferenceIntensitySection(cs),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: Icon(Icons.add,
                    size: 16,
                    color: _toggleReasoningParam != null ? null : Colors.grey),
                label: Text('添加推理参数',
                    style: TextStyle(
                        fontSize: 13,
                        color: _toggleReasoningParam != null
                            ? null
                            : Colors.grey)),
                onPressed: _toggleReasoningParam != null
                    ? () => _addReasoningParam()
                    : null,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ==========================================================
          // LLM 参数
          // ==========================================================
          if (_isLlmType) ...[
            Text('LLM 参数',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.primary)),
            const SizedBox(height: 4),
            Text(
              '开启的参数将作为默认值发送到 API 请求中',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            LlmToggleSlider(
              label: '温度 (Temperature)',
              value: _temperature,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              enabled: _enableTemperature,
              onChanged: (v) => setState(() => _temperature = v),
              onToggle: (v) => setState(() => _enableTemperature = v),
              description: '控制输出的随机性，值越高越有创造性',
            ),
            LlmToggleSlider(
              label: 'Top P',
              value: _topP,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              enabled: _enableTopP,
              onChanged: (v) => setState(() => _topP = v),
              onToggle: (v) => setState(() => _enableTopP = v),
              description: '核采样参数，控制词汇选择的累积概率',
            ),
            LlmToggleSlider(
              label: '频率惩罚 (Frequency Penalty)',
              value: _frequencyPenalty,
              min: -2.0,
              max: 2.0,
              divisions: 40,
              enabled: _enableFrequencyPenalty,
              onChanged: (v) => setState(() => _frequencyPenalty = v),
              onToggle: (v) => setState(() => _enableFrequencyPenalty = v),
              description: '减少重复词的频率，负值增加重复',
            ),
            LlmToggleSlider(
              label: '存在惩罚 (Presence Penalty)',
              value: _presencePenalty,
              min: -2.0,
              max: 2.0,
              divisions: 40,
              enabled: _enablePresencePenalty,
              onChanged: (v) => setState(() => _presencePenalty = v),
              onToggle: (v) => setState(() => _enablePresencePenalty = v),
              description: '鼓励讨论新话题，负值鼓励重复话题',
            ),
            LlmToggleTextField(
              label: '最大输出 Token 数',
              controller: _maxTokensController,
              enabled: _enableMaxTokens,
              onToggle: (v) => setState(() => _enableMaxTokens = v),
              hintText: '可选，如 4096',
              keyboardType: TextInputType.number,
              description: '每次响应最多生成的 token 数',
            ),
            LlmToggleTextField(
              label: '随机种子 (Seed)',
              controller: _seedController,
              enabled: _enableSeed,
              onToggle: (v) => setState(() => _enableSeed = v),
              hintText: '可选，如 42',
              keyboardType: TextInputType.number,
              description: '设置后可使输出结果可复现',
            ),
            const SizedBox(height: 24),
          ],

          // ==========================================================
          // 自定义参数
          // ==========================================================
          Row(
            children: [
              const Text('自定义参数',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加参数'),
                onPressed: _addCustomParam,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_customParams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('暂无自定义参数', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...List.generate(_customParams.length, (i) {
              final param = _customParams[i];
              final name = param.paramName.trim();
              final isDuplicate = name.isNotEmpty &&
                  (_customParams
                          .indexWhere((p) => p.paramName.trim() == name) !=
                      i);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: param.paramName,
                              decoration: InputDecoration(
                                labelText: '参数名',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                errorText: isDuplicate ? '已存在该参数' : null,
                                errorStyle: const TextStyle(fontSize: 11),
                              ),
                              onChanged: (v) {
                                param.paramName = v;
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 110,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: param.type,
                                isDense: true,
                                items: ParamType.values
                                    .map((t) => DropdownMenuItem(
                                          value: t.value,
                                          child: Text(t.label,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => param.type = v);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                            onPressed: () => _removeCustomParam(i),
                            tooltip: '删除参数',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: param.defaultValue,
                        decoration: InputDecoration(
                          labelText: '默认参数值',
                          hintText: param.paramType.defaultValueHint,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => param.defaultValue = v,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // =================================================================
  // Reasoning toggle section
  // =================================================================
  Widget _buildReasoningToggleSection(ColorScheme cs) {
    final toggle = _toggleReasoningParam;
    if (toggle == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('添加推理开关', style: TextStyle(fontSize: 13)),
            onPressed: () => _addReasoningParam(isToggle: true),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.toggle_on_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('推理开关',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      )),
                ),
                _buildTypeDropdown(toggle, cs),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () =>
                      _removeReasoningParam(_reasoningParams.indexOf(toggle)),
                  tooltip: '删除推理开关',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: toggle.paramName,
              decoration: const InputDecoration(
                labelText: '参数名',
                hintText: '如 thinking.type、reasoning',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                toggle.paramName = v;
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: toggle.onValue ?? '',
                    decoration: const InputDecoration(
                      labelText: '开启时值',
                      hintText: '如 enabled、true',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      toggle.onValue = v;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: toggle.offValue ?? '',
                    decoration: const InputDecoration(
                      labelText: '关闭时值',
                      hintText: '如 disabled、false',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      toggle.offValue = v;
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '推理开关打开时发送「${toggle.onValue ?? ''}」，'
              '关闭时发送「${toggle.offValue ?? ''}」',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =================================================================
  // Inference intensity section (provider version: name-only allowed)
  // =================================================================
  Widget _buildInferenceIntensitySection(ColorScheme cs) {
    final hasToggle = _toggleReasoningParam != null;

    // Find existing inference intensity param (non-toggle)
    final intensityParams =
        _reasoningParams.where((p) => !p.isReasoningToggle).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('推理力度',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: cs.primary)),
        const SizedBox(height: 4),
        Text(
          '推理力度参数支持只填参数名而不添加具体选项值'
          '${!hasToggle ? '（需先添加推理开关后才能配置）' : ''}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (intensityParams.isNotEmpty)
          ...List.generate(intensityParams.length, (i) {
            final param = intensityParams[i];
            final actualIndex = _reasoningParams.indexOf(param);
            return _buildIntensityParamCard(param, actualIndex, i, cs);
          }),
        const SizedBox(height: 4),
        TextButton.icon(
          icon:
              Icon(Icons.add, size: 16, color: hasToggle ? null : Colors.grey),
          label: Text('添加推理力度参数',
              style: TextStyle(
                  fontSize: 13, color: hasToggle ? null : Colors.grey)),
          onPressed: hasToggle
              ? () {
                  final newParam = ReasoningParam(
                    paramName: '',
                    isReasoningToggle: false,
                    enabled: true,
                    options: [],
                  );
                  setState(() {
                    _reasoningParams.add(newParam);
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildIntensityParamCard(
      ReasoningParam param, int actualIndex, int displayIndex, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: param.paramName,
                    decoration: InputDecoration(
                      labelText: '参数名（支持点号嵌套）',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: '如 reasoning_effort',
                    ),
                    onChanged: (v) {
                      param.paramName = v;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 4),
                _buildTypeDropdown(param, cs),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removeReasoningParam(actualIndex),
                  tooltip: '删除参数',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('选项值（可选，仅填参数名时发送参数名本身）',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                )),
            const SizedBox(height: 8),
            ...List.generate(param.options.length, (j) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: param.options[j],
                        decoration: InputDecoration(
                          labelText: '选项 ${j + 1}',
                          hintText: '如 low, medium, high',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          param.options[j] = v;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (param.options.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle,
                            color: Colors.red, size: 18),
                        onPressed: () => _removeOptionFromParam(actualIndex, j),
                        tooltip: '删除选项',
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加选项', style: TextStyle(fontSize: 13)),
              onPressed: () => _addOptionToParam(actualIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeDropdown(ReasoningParam param, ColorScheme cs) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ParamType.values.any((t) => t.value == param.type)
              ? param.type
              : 'string',
          isDense: true,
          items: ParamType.values
              .map((t) => DropdownMenuItem(
                    value: t.value,
                    child: Text(t.label, style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => param.type = v);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.config.providerName.isNotEmpty
        ? widget.config.providerName
        : '供应商配置';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SizedBox(
        width: double.maxFinite,
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              TabBar(
                labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                tabs: const [
                  Tab(text: '基本信息'),
                  Tab(text: '参数设置'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildBasicInfoTab(cs),
                    _buildParameterSettingsTab(cs),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () {
                        if (_validate()) {
                          Navigator.pop(context, _buildConfig());
                        }
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
