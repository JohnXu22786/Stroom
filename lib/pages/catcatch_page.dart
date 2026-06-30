import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catcatch/providers/catcatch_provider.dart';
import '../utils/duration_parser.dart';
import '../utils/file_manifest.dart';
import '../utils/video_manifest.dart';
import '../widgets/folder_picker_dialog.dart';
import 'browser_page.dart';
import 'unified_task_list_page.dart';

// =============================================================================
// 主页面
// =============================================================================

class CatCatchPage extends ConsumerStatefulWidget {
  final String? initialUrl;
  final int? initialDurationSec;

  const CatCatchPage({super.key, this.initialUrl, this.initialDurationSec});

  @override
  ConsumerState<CatCatchPage> createState() => _CatCatchPageState();
}

class _CatCatchPageState extends ConsumerState<CatCatchPage> {
  final _urlController = TextEditingController();
  final _hourController = TextEditingController();
  final _minuteController = TextEditingController();
  final _secondController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _previewText = '00:00:00';
  String _videoFolder = '';
  String _audioFolder = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
    }
    if (widget.initialDurationSec != null && widget.initialDurationSec! > 0) {
      final totalSec = widget.initialDurationSec!;
      final h = totalSec ~/ 3600;
      final m = (totalSec % 3600) ~/ 60;
      final s = totalSec % 60;
      _hourController.text = h.toString();
      _minuteController.text = m.toString();
      _secondController.text = s.toString();
      _updatePreview();
    }
    _hourController.addListener(_updatePreview);
    _minuteController.addListener(_updatePreview);
    _secondController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  int _parseInt(String text) => int.tryParse(text.trim()) ?? 0;

  void _updatePreview() {
    final h = _parseInt(_hourController.text);
    final m = _parseInt(_minuteController.text);
    final s = _parseInt(_secondController.text);
    final total = totalSeconds(hours: h, minutes: m, seconds: s);
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    setState(() {
      _previewText = formatHms(
        DurationResult(hours: hours, minutes: minutes, seconds: seconds),
      );
    });
  }

  void _startTask() {
    if (!_formKey.currentState!.validate()) return;

    final url = _urlController.text.trim();
    final h = _parseInt(_hourController.text);
    final m = _parseInt(_minuteController.text);
    final s = _parseInt(_secondController.text);
    final totalSec = totalSeconds(hours: h, minutes: m, seconds: s);

    if (totalSec <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入视频时长'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      ref.read(catcatchTasksProvider.notifier).addTask(
            url,
            totalSec,
            videoFolder: _videoFolder,
            audioFolder: _audioFolder,
          );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('分析失败: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('任务已添加'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '查看任务列表',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UnifiedTaskListPage()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载网页资源'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.language, size: 20),
            tooltip: '内置浏览器',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const BrowserPage(initialUrl: 'https://www.google.com'),
              ),
            ),
          ),
        ],
      ),
      body: _buildInputSection(colorScheme),
    );
  }

  Widget _buildInputSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: '请输入视频/音频网页URL',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入URL';
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                  return '请输入有效的URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hourController,
                    decoration: InputDecoration(
                      labelText: '时',
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _minuteController,
                    decoration: InputDecoration(
                      labelText: '分',
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _secondController,
                    decoration: InputDecoration(
                      labelText: '秒',
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _startTask(),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '预览: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _previewText,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '时:分:秒',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                '按时长筛选视频资源，不匹配的将不会出现在结果列表中',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '使用右上角按钮，在应用内浏览器登录，以获得需要登录才能获得的资源',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 视频保存文件夹选择
            _buildFolderSelector(
              context: context,
              colorScheme: colorScheme,
              icon: Icons.videocam,
              label: '视频保存至',
              currentFolder: _videoFolder,
              onTap: () => _pickVideoFolder(),
            ),
            const SizedBox(height: 8),

            // 音频保存文件夹选择
            _buildFolderSelector(
              context: context,
              colorScheme: colorScheme,
              icon: Icons.audio_file,
              label: '音频保存至',
              currentFolder: _audioFolder,
              onTap: () => _pickAudioFolder(),
            ),
            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: _startTask,
              icon: const Icon(Icons.search),
              label: const Text('开始分析'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // 文件夹选择
  // ====================================================================

  Future<void> _pickVideoFolder() async {
    final folders = await VideoManifest.getAllFolders();
    if (!mounted) return;
    final result = await FolderPickerDialog.show(
      context,
      currentFolder: _videoFolder,
      availableFolders: folders,
      title: '视频保存至文件夹',
    );
    if (result != null && mounted) {
      setState(() => _videoFolder = result);
    }
  }

  Future<void> _pickAudioFolder() async {
    final folders = await FileManifest.getAllFolders();
    if (!mounted) return;
    final result = await FolderPickerDialog.show(
      context,
      currentFolder: _audioFolder,
      availableFolders: folders,
      title: '音频保存至文件夹',
    );
    if (result != null && mounted) {
      setState(() => _audioFolder = result);
    }
  }

  Widget _buildFolderSelector({
    required BuildContext context,
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required String currentFolder,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currentFolder.isEmpty ? '根目录' : currentFolder,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
