import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/provider_config.dart';
import '../services/asr_service.dart';
import 'llm_model_config_shared.dart';

part 'provider_settings_panel_custom_params.dart';
part 'provider_settings_panel_reasoning.dart';
part 'provider_settings_panel_save.dart';
part 'provider_settings_panel_tab_basic.dart';
part 'provider_settings_panel_tab_asr.dart';

/// Format a JSON parse error with detailed position information.
///
/// Extracts line and column numbers from the exception's offset and the
/// source text, producing a Chinese message like
/// "第 3 行第 10 列: Unexpected token".
String formatJsonError(String source, dynamic error) {
  if (error is FormatException) {
    final offset = error.offset;
    final msg = error.message;
    if (offset != null && offset >= 0 && offset <= source.length) {
      final before = source.substring(0, offset);
      final lines = before.split('\n');
      final line = lines.length;
      final col = lines.last.length + 1;
      return '第 $line 行第 $col 列: $msg';
    }
    return 'JSON 格式错误: $msg';
  }
  return 'JSON 格式不正确';
}

/// Validate a value as JSON when the param type is 'json'.
///
/// Returns an error string if invalid, or null if valid / not applicable.
/// Exported for testing.
String? validateJsonValue(String type, String value) {
  if (type == 'json' && value.trim().isNotEmpty) {
    try {
      jsonDecode(value.trim());
    } catch (e) {
      return formatJsonError(value, e);
    }
  }
  return null;
}

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
  late String _endpointType;

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
  final Map<int, String?> _jsonErrors = {};

  // ASR upload settings
  AudioUploadMethod _uploadMethod = AudioUploadMethod.multipart;
  double _maxFileSizeMb = 25.0;
  late final TextEditingController _maxFileSizeController;

  // ASR preprocessing & chunking
  String _preprocessing = 'none'; // 'none' | 'resampleMono'
  String _chunking =
      'none'; // 'none' | 'silence' | 'fixedDuration' | 'fixedSize'
  String _compression = 'none'; // 'none' | 'adpcm' | 'flac'
  String _fallbackMethod = 'none'; // 'none' | 'specific' | 'generic' | 'all'

  bool get _isLlmType => widget.providerType == 'llm';
  bool get _isAsrType => widget.providerType == 'asr';

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _nameController = TextEditingController(text: c.providerName);
    _hostController = TextEditingController(text: c.host);
    _keyController = TextEditingController(text: c.key);
    _endpointType = c.endpointType;

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
      text: maxTokens != null ? maxTokens.toString() : '',
    );
    final seed = c.typeConfig['seed'];
    _seedController = TextEditingController(
      text: seed != null ? seed.toString() : '',
    );

    _customParams = c.customParams.map((p) => p.copy()).toList();
    _reasoningParams = c.reasoningParams.map((p) => p.copy()).toList();
    // Initialize JSON validation for existing params
    for (int i = 0; i < _customParams.length; i++) {
      _validateJsonField(i, _customParams[i]);
    }

    // ASR upload settings
    if (_isAsrType) {
      final uploadMethodStr = c.typeConfig['uploadMethod'] as String?;
      if (uploadMethodStr != null) {
        _uploadMethod = AudioUploadMethod.values.firstWhere(
          (m) => m.name == uploadMethodStr,
          orElse: () => AudioUploadMethod.multipart,
        );
      }
      _maxFileSizeMb =
          (c.typeConfig['maxFileSizeMb'] as num?)?.toDouble() ?? 25.0;
      _maxFileSizeController = TextEditingController(
        text: _maxFileSizeMb.toStringAsFixed(1),
      );
      _preprocessing = c.typeConfig['preprocessing'] as String? ?? 'none';
      _chunking = c.typeConfig['chunking'] as String? ?? 'none';
      _compression = c.typeConfig['compression'] as String? ?? 'none';
      _fallbackMethod = c.typeConfig['fallbackMethod'] as String? ?? 'none';
    } else {
      _maxFileSizeController = TextEditingController(text: '25.0');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _keyController.dispose();
    _maxTokensController.dispose();
    _seedController.dispose();
    _maxFileSizeController.dispose();
    super.dispose();
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
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
