import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';

import '../providers/theme_provider.dart';

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
