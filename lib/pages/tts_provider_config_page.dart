import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tts_config.dart';
import '../providers/tts_state_provider.dart';
import '../utils/audio_playback.dart';
import '../utils/audio_trim.dart';
import 'tts_model_config_page.dart';

class TTSProviderConfigPage extends ConsumerStatefulWidget {
  final String providerId;
  const TTSProviderConfigPage({super.key, required this.providerId});

  @override
  ConsumerState<TTSProviderConfigPage> createState() =>
      _TTSProviderConfigPageState();
}

class _TTSProviderConfigPageState
    extends ConsumerState<TTSProviderConfigPage> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();

  /// 自定义供应商模型列表
  List<Map<String, dynamic>> _customModels = [];

  /// GLM 专用
  GlmTrimMode _trimMode = GlmTrimMode.beep;

  bool _isTesting = false;
  bool _isSaving = false;

  /// 是否为内置供应商
  bool get _isBuiltIn =>
      widget.providerId == 'glm_tts' || widget.providerId == 'aihubmix_tts';

  /// 是否为自定义供应商
  bool get _isCustom => !_isBuiltIn;

  TTSProviderDefinition? get _providerDef =>
      TTSProviderRegistry.get(widget.providerId);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final config = ref.read(ttsConfigProvider);
    final providerConfig = config.providerConfigs[widget.providerId] ?? {};

    _apiKeyController.text = (providerConfig['apiKey'] as String?) ?? '';
    _baseUrlController.text = (providerConfig['baseUrl'] as String?) ?? '';

    if (widget.providerId == 'glm_tts') {
      _trimMode = GlmTrimMode.fromValue(
              providerConfig['trimMode'] as String?) ??
          GlmTrimMode.beep;
    }

    if (_isCustom) {
      final modelsList = providerConfig['models'] as List<dynamic>?;
      _customModels = modelsList != null
          ? modelsList.map((m) => Map<String, dynamic>.from(m as Map)).toList()
          : [];
    }
  }

  void _reloadModels() {
    final config = ref.read(ttsConfigProvider);
    final providerConfig = config.providerConfigs[widget.providerId] ?? {};
    if (_isCustom) {
      final modelsList = providerConfig['models'] as List<dynamic>?;
      _customModels = modelsList != null
          ? modelsList.map((m) => Map<String, dynamic>.from(m as Map)).toList()
          : [];
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // Save
  // ----------------------------------------------------------------

  Future<bool> _saveConfig() async {
    final notifier = ref.read(ttsConfigProvider.notifier);
    try {
      final configMap = <String, dynamic>{
        'apiKey':
            _apiKeyController.text.isNotEmpty ? _apiKeyController.text : null,
        'baseUrl': _baseUrlController.text.isNotEmpty
            ? _baseUrlController.text
            : null,
      };

      if (widget.providerId == 'glm_tts') {
        configMap['trimMode'] = _trimMode.value;
      }

      if (_isCustom) {
        configMap['models'] = _customModels;
      }

      await notifier.saveProviderConfig(widget.providerId, configMap);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final ok = await _saveConfig();
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '配置已保存' : '保存失败'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ----------------------------------------------------------------
  // Model navigation (custom providers)
  // ----------------------------------------------------------------

  Future<void> _addModel() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TTSModelConfigPage(
          providerId: widget.providerId,
          modelIndex: -1,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _reloadModels();
      setState(() {});
    }
  }

  Future<void> _openModelConfig(int index) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TTSModelConfigPage(
          providerId: widget.providerId,
          modelIndex: index,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _reloadModels();
      setState(() {});
    }
  }

  Future<void> _deleteModel(int index) async {
    _customModels.removeAt(index);
    await _saveConfig();
    if (!mounted) return;
    setState(() {});
  }

  // ----------------------------------------------------------------
  // Test audio
  // ----------------------------------------------------------------

  Future<void> _playTestAudio() async {
    final config = ref.read(ttsConfigProvider);
    final providerConfig = config.providerConfigs[widget.providerId];
    if (providerConfig == null ||
        (providerConfig['apiKey'] as String?)?.isEmpty != false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先配置 API 密钥'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final provider = ref.read(ttsProviderProvider);
      if (provider == null) {
        // 如果全局 provider 不是当前供应商，手动构建
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先切换到此供应商再测试'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final audioData = await provider.synthesize(
        '这是一段测试音频',
        params: {
          'voice': _providerDef?.supportedVoices.isNotEmpty == true
              ? _providerDef!.supportedVoices.first
              : null,
          'speed': 1.0,
          'volume': 1.0,
          'format': 'wav',
          'response_format': 'wav',
        },
      );

      // GLM 测试预览时应用裁切
      Uint8List playData = audioData;
      if (widget.providerId == 'glm_tts' &&
          _trimMode != GlmTrimMode.none) {
        playData = trimGlmAudio(
          playData,
          sampleRate: 24000,
          trimMode: _trimMode,
          force: true,
        );
      }

      if (playData.isNotEmpty) {
        playAudioBytes(playData, 'audio/wav');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放测试失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final def = _providerDef;
    final label = def?.label ?? widget.providerId;

    return Scaffold(
      appBar: AppBar(
        title: Text(label),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================================
                // 基本信息
                // ==========================================================
                _buildSectionHeader('基本信息'),
                _buildInfoTile('Provider ID', widget.providerId),
                if (_isCustom) _buildInfoTile('Provider Label', label),
                const Divider(height: 1),

                const SizedBox(height: 16),

                // ==========================================================
                // API 配置
                // ==========================================================
                _buildSectionHeader('API 配置'),

                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API 密钥',
                    hintText: '输入 API 密钥',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key, color: Colors.amber),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrlController,
                  decoration: InputDecoration(
                    labelText: 'API 基础 URL（可选）',
                    hintText: def?.defaultBaseUrl ?? 'https://...',
                    border: const OutlineInputBorder(),
                    prefixIcon:
                        const Icon(Icons.link, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('保存配置'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ==========================================================
                // 模型列表
                // ==========================================================
                _buildSectionHeader('模型列表'),

                if (_isCustom) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('添加模型'),
                      onPressed: _addModel,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                if (_isBuiltIn) ...[
                  ..._buildBuiltinModelTiles(),
                ],

                if (_isCustom) ...[
                  ..._buildCustomModelTiles(),
                ],

                const SizedBox(height: 24),

                // ==========================================================
                // GLM-TTS 裁切模式
                // ==========================================================
                if (widget.providerId == 'glm_tts') ...[
                  _buildSectionHeader('音频头部裁切'),
                  const SizedBox(height: 8),
                  ...GlmTrimMode.values.map(
                    (mode) => RadioListTile<GlmTrimMode>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(mode.label),
                      value: mode,
                      groupValue: _trimMode,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _trimMode = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ==========================================================
                // 测试
                // ==========================================================
                _buildSectionHeader('测试'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _playTestAudio,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('播放测试音频'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Built-in model tiles (read-only)
  // ----------------------------------------------------------------

  List<Widget> _buildBuiltinModelTiles() {
    final def = _providerDef;
    if (def == null) return [];

    return List.generate(def.supportedModels.length, (i) {
      final model = def.supportedModels[i];
      final voicesCount = model.voices.length;
      return ListTile(
        leading: const Icon(Icons.smart_toy),
        title: Text(model.name),
        subtitle: Text(
          voicesCount > 0 ? '$voicesCount 种音色' : '无音色',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openModelConfig(i),
      );
    });
  }

  // ----------------------------------------------------------------
  // Custom model tiles (editable)
  // ----------------------------------------------------------------

  List<Widget> _buildCustomModelTiles() {
    return List.generate(_customModels.length, (i) {
      final model = _customModels[i];
      final name = model['name'] as String? ?? '';
      final voices = (model['voices'] as List?)?.cast<String>() ?? [];
      final voicesCount = voices.length;
      return ListTile(
        leading: const Icon(Icons.smart_toy),
        title: Text(name.isNotEmpty ? name : '（未命名）'),
        subtitle: Text(
          voicesCount > 0 ? '$voicesCount 种音色' : '无音色',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteModel(i),
              tooltip: '删除模型',
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _openModelConfig(i),
      );
    });
  }
}
