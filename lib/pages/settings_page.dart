import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../providers/theme_provider.dart';
import '../providers/tts_state_provider.dart';
import '../providers/tts_config.dart';
import '../utils/audio_playback.dart';
import '../utils/audio_trim.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _saveToGallery = true;
  bool _highQuality = false;
  double _compressionQuality = 0.85;
  bool _isTesting = false;

  // ===== TTS 配置（每个供应商完全独立） =====
  String? _selectedProviderId;

  // GLM-TTS 独立配置
  late GlmConfig _glmConfig;

  // AIHUBMIX-TTS 独立配置
  late AihubmixConfig _aihubmixConfig;

  // TextEditingController — 每个供应商独立
  late final TextEditingController _glmApiKeyController;
  late final TextEditingController _glmBaseUrlController;

  late final TextEditingController _aihubmixApiKeyController;
  late final TextEditingController _aihubmixModelController;
  late final TextEditingController _aihubmixBaseUrlController;

  // 自定义供应商
  late final TextEditingController _customApiKeyController;

  @override
  void initState() {
    super.initState();
    _glmApiKeyController = TextEditingController();
    _glmBaseUrlController = TextEditingController();
    _aihubmixApiKeyController = TextEditingController();
    _aihubmixModelController = TextEditingController();
    _aihubmixBaseUrlController = TextEditingController();
    _customApiKeyController = TextEditingController();

    _loadTTSConfig();
  }

  @override
  void dispose() {
    _glmApiKeyController.dispose();
    _glmBaseUrlController.dispose();
    _aihubmixApiKeyController.dispose();
    _aihubmixModelController.dispose();
    _aihubmixBaseUrlController.dispose();
    _customApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadTTSConfig() async {
    final config = ref.read(ttsConfigProvider);
    _applyConfig(config);
  }

  void _applyConfig(TTSConfigState config) {
    setState(() {
      _selectedProviderId = config.selectedProviderId;
      _glmConfig = config.glmConfig;
      _aihubmixConfig = config.aihubmixConfig;
    });
    // 同步各个 Controller 的文本（不触发 onChanged）
    _glmApiKeyController.text = _glmConfig.apiKey ?? '';
    _glmBaseUrlController.text = _glmConfig.baseUrl ?? '';
    _aihubmixApiKeyController.text = _aihubmixConfig.apiKey ?? '';
    _aihubmixModelController.text =
        _aihubmixConfig.model ?? _aihubmixConfig.defaultModel;
    _aihubmixBaseUrlController.text = _aihubmixConfig.baseUrl ?? '';

    // 自定义供应商：读取通用配置中的 apiKey
    final customConfig =
        config.providerConfigs[_selectedProviderId];
    _customApiKeyController.text =
        (customConfig?['apiKey'] as String?) ?? '';
  }

  /// 保存 GLM-TTS 独立配置
  Future<bool> _saveGlmConfig() async {
    final notifier = ref.read(ttsConfigProvider.notifier);
    try {
      final glm = GlmConfig(
        apiKey: _glmApiKeyController.text.isNotEmpty
            ? _glmApiKeyController.text
            : null,
        baseUrl: _glmBaseUrlController.text.isNotEmpty
            ? _glmBaseUrlController.text
            : null,
        trimMode: _glmConfig.trimMode,
      );
      await notifier.saveGlmConfig(glm);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 保存 AIHUBMIX-TTS 独立配置
  Future<bool> _saveAihubmixConfig() async {
    final notifier = ref.read(ttsConfigProvider.notifier);
    try {
      final aihubmix = AihubmixConfig(
        apiKey: _aihubmixApiKeyController.text.isNotEmpty
            ? _aihubmixApiKeyController.text
            : null,
        baseUrl: _aihubmixBaseUrlController.text.isNotEmpty
            ? _aihubmixBaseUrlController.text
            : null,
        model: _aihubmixModelController.text.isNotEmpty
            ? _aihubmixModelController.text
            : null,
        voice: _aihubmixConfig.voice,
      );
      await notifier.saveAihubmixConfig(aihubmix);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('主题'),
          _buildThemeSettings(themeMode, themeNotifier),

          const SizedBox(height: 24),

          _buildSectionHeader('相机设置'),
          _buildCameraSettings(),

          const SizedBox(height: 24),

          _buildSectionHeader('语音合成设置'),
          _buildTTSSettings(),

          const SizedBox(height: 24),

          _buildSectionHeader('关于'),
          _buildAboutSection(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

  // ================================================================
  // 主题设置
  // ================================================================

  Widget _buildThemeSettings(ThemeMode themeMode, ThemeNotifier themeNotifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _buildListTile(
              leading: const Icon(Icons.light_mode, color: Colors.amber),
              title: '浅色模式',
              trailing: Radio<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeMode,
                onChanged: (_) => themeNotifier.setLight(),
              ),
              onTap: () => themeNotifier.setLight(),
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.dark_mode, color: Colors.indigo),
              title: '深色模式',
              trailing: Radio<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeMode,
                onChanged: (_) => themeNotifier.setDark(),
              ),
              onTap: () => themeNotifier.setDark(),
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.settings_suggest, color: Colors.grey),
              title: '跟随系统',
              trailing: Radio<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeMode,
                onChanged: (_) => themeNotifier.setSystem(),
              ),
              onTap: () => themeNotifier.setSystem(),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // 相机设置
  // ================================================================

  Widget _buildCameraSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _buildListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: '保存到相册',
              subtitle: '自动将拍摄的照片保存到设备相册',
              trailing: Switch(
                value: _saveToGallery,
                onChanged: (v) => setState(() => _saveToGallery = v),
              ),
              onTap: () =>
                  setState(() => _saveToGallery = !_saveToGallery),
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.high_quality, color: Colors.purple),
              title: '高质量照片',
              subtitle: '使用更高的分辨率拍摄照片',
              trailing: Switch(
                value: _highQuality,
                onChanged: (v) => setState(() => _highQuality = v),
              ),
              onTap: () => setState(() => _highQuality = !_highQuality),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('压缩质量',
                          style: TextStyle(fontSize: 16)),
                      Text(
                        '${(_compressionQuality * 100).toInt()}%',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: _compressionQuality,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: '${(_compressionQuality * 100).toInt()}%',
                    onChanged: (v) =>
                        setState(() => _compressionQuality = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // TTS 设置 —— 每个供应商独立配置，完全分离
  // ================================================================

  Widget _buildTTSSettings() {
    final providerOptions = TTSProviderRegistry.getAll();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 供应商选择下拉框 ----
            _buildListTile(
              leading: const Icon(Icons.business, color: Colors.purple),
              title: '供应商',
              subtitle: _selectedProviderId != null
                  ? (TTSProviderRegistry.get(_selectedProviderId!)?.label ??
                      '未选择')
                  : '未选择',
              trailing: DropdownButton<TTSProviderDefinition>(
                value: _selectedProviderId != null
                    ? TTSProviderRegistry.get(_selectedProviderId!)
                    : null,
                onChanged: (TTSProviderDefinition? newValue) async {
                  if (newValue == null) return;
                  // 先保存当前选中的配置
                  if (_selectedProviderId != null) {
                    await _saveCurrentProviderConfig();
                  }
                  // 切换供应商
                  setState(() {
                    _selectedProviderId = newValue.id;
                  });
                  // 通知 provider 更新选中状态
                  await ref
                      .read(ttsConfigProvider.notifier)
                      .selectProvider(newValue.id);
                  // 重新加载 UI
                  _loadTTSConfig();
                },
                items: providerOptions.map((TTSProviderDefinition def) {
                  return DropdownMenuItem<TTSProviderDefinition>(
                    value: def,
                    child: Text(def.label),
                  );
                }).toList(),
              ),
              onTap: () {},
            ),

            const Divider(height: 1),

            // ---- 按当前选中的供应商显示其独立配置区 ----
            if (_selectedProviderId == 'glm_tts')
              _buildGlmConfigSection()
            else if (_selectedProviderId == 'aihubmix_tts')
              _buildAihubmixConfigSection()
            else if (_selectedProviderId != null &&
                TTSProviderRegistry.isRegistered(_selectedProviderId!))
              _buildCustomProviderConfigSection()
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('请先选择一个供应商',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),

            // ---- 管理自定义供应商 ----
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.add_business, color: Colors.teal),
              title: '管理自定义供应商',
              subtitle: '添加/编辑/删除自定义 TTS 供应商',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCustomProviderManagementDialog(),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // GLM-TTS 独立配置区
  // ----------------------------------------------------------------
  Widget _buildGlmConfigSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区域标题
          Row(
            children: [
              Icon(Icons.settings, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Text(
                'GLM-TTS 配置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '此配置仅作用于 GLM-TTS，与 AIHUBMIX 完全独立。',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          // API 密钥
          TextField(
            controller: _glmApiKeyController,
            decoration: const InputDecoration(
              labelText: 'API 密钥',
              hintText: '输入 GLM API 密钥',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key, color: Colors.amber),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),

          // Base URL
          TextField(
            controller: _glmBaseUrlController,
            decoration: InputDecoration(
              labelText: 'API 基础 URL（可选）',
              hintText: GlmConfig().baseUrl ??
                  'https://open.bigmodel.cn/api/paas/v4',
              border: const OutlineInputBorder(),
              prefixIcon:
                  const Icon(Icons.link, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 12),

          // 音频头部裁切模式选择
          const Text(
            '音频头部裁切',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          ...GlmTrimMode.values.map((mode) => RadioListTile<GlmTrimMode>(
            contentPadding: EdgeInsets.zero,
            title: Text(mode.label),
            value: mode,
            groupValue: _glmConfig.trimMode,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _glmConfig = _glmConfig.copyWith(trimMode: v);
              });
            },
          )),
          const SizedBox(height: 8),

          // 测试播放按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isTesting ? null : _playTestAudio,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('播放测试 "这是一段测试音频"'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 保存按钮（仅保存 GLM 配置）
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final ok = await _saveGlmConfig();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(ok ? 'GLM 配置已保存' : '保存失败'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('保存 GLM 配置'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // AIHUBMIX-TTS 独立配置区
  // ----------------------------------------------------------------
  Widget _buildAihubmixConfigSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区域标题
          Row(
            children: [
              Icon(Icons.settings, size: 18, color: Colors.green[700]),
              const SizedBox(width: 6),
              Text(
                'AIHUBMIX-TTS 配置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '此配置仅作用于 AIHUBMIX-TTS，与 GLM 完全独立。',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          // API 密钥
          TextField(
            controller: _aihubmixApiKeyController,
            decoration: const InputDecoration(
              labelText: 'API 密钥',
              hintText: '输入 AIHUBMIX API 密钥',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key, color: Colors.amber),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),

          // 模型
          TextField(
            controller: _aihubmixModelController,
            decoration: const InputDecoration(
              labelText: '模型',
              hintText: '例如: gpt-4o-mini-tts',
              border: OutlineInputBorder(),
              prefixIcon:
                  Icon(Icons.model_training, color: Colors.green),
            ),
          ),
          const SizedBox(height: 12),

          // Base URL
          TextField(
            controller: _aihubmixBaseUrlController,
            decoration: InputDecoration(
              labelText: 'API 基础 URL（可选）',
              hintText: 'https://aihubmix.com/v1',
              border: const OutlineInputBorder(),
              prefixIcon:
                  const Icon(Icons.link, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 12),

          // 音色选择
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '默认音色',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.record_voice_over,
                  color: Colors.blue),
            ),
            value: _aihubmixConfig.voice?.isNotEmpty == true
                ? _aihubmixConfig.voice
                : null,
            hint: const Text('选择默认音色'),
            onChanged: (String? newVoice) {
              if (newVoice == null) return;
              setState(() {
                _aihubmixConfig =
                    _aihubmixConfig.copyWith(voice: newVoice);
              });
            },
            items: AihubmixConfig.supportedVoices.map((String v) {
              return DropdownMenuItem<String>(
                value: v,
                child: Text(v),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // 保存按钮（仅保存 AIHUBMIX 配置）
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final ok = await _saveAihubmixConfig();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        ok ? 'AIHUBMIX 配置已保存' : '保存失败'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('保存 AIHUBMIX 配置'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // 自定义供应商配置区（通用配置 UI）
  // ----------------------------------------------------------------
  Widget _buildCustomProviderConfigSection() {
    final def = TTSProviderRegistry.get(_selectedProviderId!);
    final label = def?.label ?? _selectedProviderId!;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区域标题
          Row(
            children: [
              Icon(Icons.settings, size: 18, color: Colors.teal[700]),
              const SizedBox(width: 6),
              Text(
                '$label 配置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '此配置仅作用于 $label。',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          // API 密钥
          TextField(
            controller: _customApiKeyController,
            decoration: const InputDecoration(
              labelText: 'API 密钥',
              hintText: '输入 API 密钥',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key, color: Colors.amber),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),

          // Base URL（只读）
          TextField(
            decoration: InputDecoration(
              labelText: 'API 基础 URL',
              hintText: def?.defaultBaseUrl ?? '',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.link, color: Colors.orange),
            ),
            readOnly: true,
            controller: TextEditingController(text: def?.defaultBaseUrl ?? ''),
          ),
          const SizedBox(height: 12),

          // 模型名（只读）
          TextField(
            decoration: InputDecoration(
              labelText: '模型名',
              hintText: '无',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.model_training, color: Colors.green),
            ),
            readOnly: true,
            controller: TextEditingController(
              text: (def?.defaultConfig['model'] as String?)?.isNotEmpty == true
                  ? (def?.defaultConfig['model'] as String)!
                  : '无',
            ),
          ),
          const SizedBox(height: 12),

          // 音色列表（只读）
          TextField(
            decoration: InputDecoration(
              labelText: '音色列表',
              hintText: '无',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.record_voice_over, color: Colors.blue),
            ),
            readOnly: true,
            controller: TextEditingController(
              text: def?.supportedVoices != null && def!.supportedVoices.isNotEmpty
                  ? def.supportedVoices.join(', ')
                  : '无',
            ),
          ),
          const SizedBox(height: 16),

          // 保存按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final ok = await _saveCustomProviderConfig();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '$label 配置已保存' : '保存失败'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('保存配置'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 保存自定义供应商通用配置
  Future<bool> _saveCustomProviderConfig() async {
    if (_selectedProviderId == null) return false;
    final notifier = ref.read(ttsConfigProvider.notifier);
    try {
      final configMap = <String, dynamic>{
        'apiKey': _customApiKeyController.text.isNotEmpty
            ? _customApiKeyController.text
            : null,
        'baseUrl': TTSProviderRegistry.get(_selectedProviderId!)?.defaultBaseUrl,
      };
      await notifier.saveProviderConfig(_selectedProviderId!, configMap);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 保存当前选中供应商的配置（切换供应商时自动调用）
  Future<void> _saveCurrentProviderConfig() async {
    if (_selectedProviderId == null) return;
    if (_selectedProviderId == 'glm_tts') {
      await _saveGlmConfig();
    } else if (_selectedProviderId == 'aihubmix_tts') {
      await _saveAihubmixConfig();
    } else if (TTSProviderRegistry.isRegistered(_selectedProviderId!)) {
      await _saveCustomProviderConfig();
    }
  }

  /// 显示自定义供应商管理对话框
  Future<void> _showCustomProviderManagementDialog() async {
    final customDefs = ref.read(customProvidersProvider);
    final notifier = ref.read(customProvidersProvider.notifier);

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('管理自定义供应商'),
              content: SizedBox(
                width: double.maxFinite,
                child: customDefs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('暂无自定义供应商',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: customDefs.length,
                        itemBuilder: (context, index) {
                          final def = customDefs[index];
                          return ListTile(
                            leading: const Icon(Icons.business,
                                color: Colors.teal),
                            title: Text(def.label),
                            subtitle: Text(def.baseUrl),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _showCustomProviderEditDialog(
                                        existing: def);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () async {
                                    await notifier.remove(def.id);
                                    if (!context.mounted) return;
                                    setDialogState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showCustomProviderEditDialog();
                  },
                  child: const Text('添加新供应商'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 显示添加/编辑自定义供应商对话框
  Future<void> _showCustomProviderEditDialog({
    CustomProviderDefinition? existing,
  }) async {
    final isEditing = existing != null;
    final labelController =
        TextEditingController(text: existing?.label ?? '');
    final baseUrlController =
        TextEditingController(text: existing?.baseUrl ?? '');
    final voicesController = TextEditingController(
        text: existing?.voices.join(', ') ?? '');
    final speedMinController = TextEditingController(
        text: existing?.speedMin.toString() ?? '0.25');
    final speedMaxController = TextEditingController(
        text: existing?.speedMax.toString() ?? '4.0');
    final volumeMinController = TextEditingController(
        text: existing?.volumeMin.toString() ?? '0.0');
    final volumeMaxController = TextEditingController(
        text: existing?.volumeMax.toString() ?? '2.0');

    final modelController =
        TextEditingController(text: existing?.model ?? '');

    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? '编辑供应商' : '添加新供应商'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ---- 基本信息 ----
                      TextField(
                        controller: labelController,
                        decoration: const InputDecoration(
                          labelText: '供应商名称',
                          hintText: '例如: 我的TTS服务',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.label, color: Colors.teal),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'API 基础 URL *',
                          hintText: 'https://api.example.com/tts',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.link, color: Colors.orange),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ---- 模型名 ----
                      TextField(
                        controller: modelController,
                        decoration: const InputDecoration(
                          labelText: '模型名（可选）',
                          hintText: '例如: tts-1',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.model_training, color: Colors.green),
                          helperText: '部分 API 需要指定模型名',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ---- 音色列表 ----
                      TextField(
                        controller: voicesController,
                        decoration: const InputDecoration(
                          labelText: '音色列表',
                          hintText: '用逗号分隔，例如: alloy,echo,fable',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.record_voice_over,
                              color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ---- 语速范围 ----
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: speedMinController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '最小语速',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: speedMaxController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '最大语速',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ---- 音量范围 ----
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: volumeMinController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '最小音量',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: volumeMaxController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '最大音量',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final label = labelController.text.trim();
                    final baseUrl = baseUrlController.text.trim();
                    if (label.isEmpty || baseUrl.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('请填写供应商名称和 API 基础 URL'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }



                    final model = modelController.text.trim();

                    final voices = voicesController.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    final speedMin =
                        double.tryParse(speedMinController.text) ?? 0.25;
                    final speedMax =
                        double.tryParse(speedMaxController.text) ?? 4.0;
                    final volumeMin =
                        double.tryParse(volumeMinController.text) ?? 0.0;
                    final volumeMax =
                        double.tryParse(volumeMaxController.text) ?? 2.0;

                    final def = CustomProviderDefinition(
                      id: isEditing
                          ? existing!.id
                          : 'custom_${const Uuid().v4()}',
                      label: label,
                      baseUrl: baseUrl,
                      model: model,
                      voices: voices,
                      speedMin: speedMin,
                      speedMax: speedMax,
                      volumeMin: volumeMin,
                      volumeMax: volumeMax,
                    );

                    final notifier =
                        ref.read(customProvidersProvider.notifier);
                    if (isEditing) {
                      await notifier.update(existing!.id, def);
                    } else {
                      await notifier.add(def);
                    }

                    if (!context.mounted) return;
                    Navigator.of(context).pop();

                    // 立即切换到新添加/编辑的供应商
                    await _saveCurrentProviderConfig();
                    setState(() {
                      _selectedProviderId = def.id;
                    });
                    await ref
                        .read(ttsConfigProvider.notifier)
                        .selectProvider(def.id);
                    _loadTTSConfig();

                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing
                            ? '供应商已更新'
                            : '供应商已添加'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Text(isEditing ? '保存' : '添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }



  /// 播放测试音频
  Future<void> _playTestAudio() async {
    final config = ref.read(ttsConfigProvider);
    if (!config.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先配置TTS供应商'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final provider = ref.read(ttsProviderProvider);
      if (provider == null) {
        throw Exception('TTS供应商未初始化');
      }

      final synthesisConfig = ref.read(synthesisConfigProvider);
      final audioData = await provider.synthesize(
        '这是一段测试音频',
        params: {
          'voice': synthesisConfig.voice,
          'speed': synthesisConfig.speed,
          'volume': synthesisConfig.volume,
          'format': 'wav',
          'response_format': 'wav',
        },
      );

      // GLM 测试预览时应用裁切，让用户听到裁切效果
      Uint8List playData = audioData;
      if (provider.name == 'glm_tts' && _glmConfig.trimMode != GlmTrimMode.none) {
        playData = trimGlmAudio(playData, sampleRate: 24000, trimMode: _glmConfig.trimMode, force: true);
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

  // ================================================================
  // 关于
  // ================================================================

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _buildListTile(
              leading:
                  const Icon(Icons.info_outline, color: Colors.blue),
              title: '应用版本',
              subtitle: '1.0.0',
              trailing: null,
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.code, color: Colors.orange),
              title: '开源许可',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLicenseDialog(),
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.privacy_tip, color: Colors.red),
              title: '隐私政策',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPrivacyDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required Widget leading,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showLicenseDialog() {
    showLicensePage(
      context: context,
      applicationName: 'Stroom',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2023 Stroom Team',
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('隐私政策'),
          content: const SingleChildScrollView(
            child: Text(
              'Stroom尊重并保护所有使用服务用户的个人隐私权。\n\n'
              '1. 相机权限：仅用于拍摄照片，不会收集或上传任何图像数据。\n'
              '2. 相册权限：仅用于选择照片和保存照片，所有照片都保存在本地设备。\n'
              '3. 数据安全：所有拍摄的照片都保存在您的设备本地，我们不会访问或上传任何数据。\n'
              '4. 第三方服务：本应用不包含任何第三方分析或广告服务。\n\n'
              '如果您有任何疑问，请联系我们。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}
