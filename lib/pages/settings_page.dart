import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';

import '../providers/theme_provider.dart';
import '../providers/tts_state_provider.dart';
import '../providers/tts_config.dart';

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

  // TTS配置相关变量
  TTSProvider? _selectedTTSProvider;
  String _ttsApiKey = '';
  String _ttsModel = '';
  String _ttsVoice = '';
  String _ttsBaseUrl = '';

  @override
  void initState() {
    super.initState();
    // 加载TTS配置
    _loadTTSConfig();
  }

  Future<void> _loadTTSConfig() async {
    final config = ref.read(ttsConfigProvider);
    setState(() {
      _selectedTTSProvider = config.selectedProvider;
      _ttsApiKey = config.apiKey ?? '';
      _ttsModel = config.model ?? '';
      _ttsVoice = config.voice ?? '';
      _ttsBaseUrl = config.baseUrl ?? '';
    });
  }

  Future<void> _saveTTSConfig() async {
    final notifier = ref.read(ttsConfigProvider.notifier);
    await notifier.saveConfig(TTSConfigState(
      selectedProvider: _selectedTTSProvider,
      apiKey: _ttsApiKey.isNotEmpty ? _ttsApiKey : null,
      model: _ttsModel.isNotEmpty ? _ttsModel : null,
      voice: _ttsVoice.isNotEmpty ? _ttsVoice : null,
      baseUrl: _ttsBaseUrl.isNotEmpty ? _ttsBaseUrl : null,
    ));
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
          // 主题设置部分
          _buildSectionHeader('主题'),
          _buildThemeSettings(themeMode, themeNotifier),

          const SizedBox(height: 24),

          // 相机设置部分
          _buildSectionHeader('相机设置'),
          _buildCameraSettings(),

          const SizedBox(height: 24),

          // TTS配置部分
          _buildSectionHeader('语音合成设置'),
          _buildTTSSettings(),

          const SizedBox(height: 24),

          // 应用信息部分
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
                onChanged: (value) {
                  themeNotifier.setLight();
                },
              ),
              onTap: () {
                themeNotifier.setLight();
              },
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.dark_mode, color: Colors.indigo),
              title: '深色模式',
              trailing: Radio<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeMode,
                onChanged: (value) {
                  themeNotifier.setDark();
                },
              ),
              onTap: () {
                themeNotifier.setDark();
              },
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.settings_suggest, color: Colors.grey),
              title: '跟随系统',
              trailing: Radio<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeMode,
                onChanged: (value) {
                  themeNotifier.setSystem();
                },
              ),
              onTap: () {
                themeNotifier.setSystem();
              },
            ),
          ],
        ),
      ),
    );
  }

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
                onChanged: (value) {
                  setState(() {
                    _saveToGallery = value;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  _saveToGallery = !_saveToGallery;
                });
              },
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.high_quality, color: Colors.purple),
              title: '高质量照片',
              subtitle: '使用更高的分辨率拍摄照片',
              trailing: Switch(
                value: _highQuality,
                onChanged: (value) {
                  setState(() {
                    _highQuality = value;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  _highQuality = !_highQuality;
                });
              },
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
                      const Text(
                        '压缩质量',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '${(_compressionQuality * 100).toInt()}%',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: _compressionQuality,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: '${(_compressionQuality * 100).toInt()}%',
                    onChanged: (value) {
                      setState(() {
                        _compressionQuality = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTTSSettings() {
    // 获取支持的供应商列表
    final providerOptions = TTSProvider.values;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // 供应商选择
            _buildListTile(
              leading: const Icon(Icons.business, color: Colors.purple),
              title: '供应商',
              subtitle: _selectedTTSProvider?.value ?? '未选择',
              trailing: DropdownButton<TTSProvider>(
                value: _selectedTTSProvider,
                onChanged: (TTSProvider? newValue) {
                  setState(() {
                    _selectedTTSProvider = newValue;
                    // 当供应商改变时，重置模型和音色
                    if (newValue != null) {
                      final voices = TTSConfig.getSupportedVoices(newValue);
                      if (voices.isNotEmpty) {
                        _ttsVoice = voices.first;
                      }
                      // 重置API密钥和模型为默认值
                      final defaultConfig = TTSConfig.getDefaultParams(newValue);
                      _ttsApiKey = defaultConfig.apiKey ?? '';
                      _ttsModel = defaultConfig.model ?? '';
                      _ttsBaseUrl = defaultConfig.baseUrl ?? '';
                    }
                    _saveTTSConfig();
                  });
                },
                items: providerOptions.map((TTSProvider provider) {
                  return DropdownMenuItem<TTSProvider>(
                    value: provider,
                    child: Text(provider.value),
                  );
                }).toList(),
              ),
              onTap: () {},
            ),
            const Divider(height: 1),

            // API密钥输入
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'API密钥',
                  hintText: '输入供应商API密钥',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key, color: Colors.amber),
                ),
                obscureText: true,
                controller: TextEditingController(text: _ttsApiKey),
                onChanged: (value) {
                  setState(() {
                    _ttsApiKey = value;
                  });
                  _saveTTSConfig();
                },
              ),
            ),

            // 模型输入（仅AIHUBMIX需要）
            if (_selectedTTSProvider == TTSProvider.aihubmixTts)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '模型',
                    hintText: '例如: gpt-4o-mini-tts',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.model_training, color: Colors.green),
                  ),
                  controller: TextEditingController(text: _ttsModel),
                  onChanged: (value) {
                    setState(() {
                      _ttsModel = value;
                    });
                    _saveTTSConfig();
                  },
                ),
              ),

            // 音色选择
            if (_selectedTTSProvider != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: '音色',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.record_voice_over, color: Colors.blue),
                  ),
                  value: _ttsVoice.isNotEmpty ? _ttsVoice : null,
                  onChanged: (String? newValue) {
                    setState(() {
                      _ttsVoice = newValue ?? '';
                    });
                    _saveTTSConfig();
                  },
                  items: TTSConfig.getSupportedVoices(_selectedTTSProvider!)
                      .map((String voice) {
                    return DropdownMenuItem<String>(
                      value: voice,
                      child: Text(voice),
                    );
                  }).toList(),
                ),
              ),

            // 基础URL（仅AIHUBMIX需要）
            if (_selectedTTSProvider == TTSProvider.aihubmixTts)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'API基础URL',
                    hintText: 'https://aihubmix.com/v1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link, color: Colors.orange),
                  ),
                  controller: TextEditingController(text: _ttsBaseUrl),
                  onChanged: (value) {
                    setState(() {
                      _ttsBaseUrl = value;
                    });
                    _saveTTSConfig();
                  },
                ),
              ),

            // 保存按钮
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _saveTTSConfig,
                icon: const Icon(Icons.save),
                label: const Text('保存配置'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _buildListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
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
              onTap: () {
                _showLicenseDialog();
              },
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.privacy_tip, color: Colors.red),
              title: '隐私政策',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showPrivacyDialog();
              },
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
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}
