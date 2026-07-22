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

  /// Check if a trimmed string is a valid URL.
  static bool _isValidUrl(String trimmed) {
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  /// Parse all valid URLs from the multi-line input.
  List<String> _parsedUrls() {
    final lines = _urlController.text.split('\n');
    final urls = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_isValidUrl(trimmed)) {
        urls.add(trimmed);
      }
    }
    return urls;
  }

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

  void _clearAll() {
    _urlController.clear();
    _hourController.clear();
    _minuteController.clear();
    _secondController.clear();
    setState(() {
      _previewText = '00:00:00';
    });
  }

  void _startTask() {
    if (!_formKey.currentState!.validate()) return;

    final urls = _parsedUrls();
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入至少一个有效的URL'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final h = _parseInt(_hourController.text);
    final m = _parseInt(_minuteController.text);
    final s = _parseInt(_secondController.text);
    final totalSec = totalSeconds(hours: h, minutes: m, seconds: s);

    int successCount = 0;
    for (final url in urls) {
      try {
        ref.read(catcatchTasksProvider.notifier).addTask(
              url,
              totalSec,
              videoFolder: _videoFolder,
              audioFolder: _audioFolder,
            );
        successCount++;
      } catch (e) {
        // Continue with other URLs even if one fails
      }
    }

    if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successCount == 1 ? '任务已添加' : '已添加 $successCount 个任务',
          ),
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
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final urls = _parsedUrls();

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载网页资源'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (_urlController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all, size: 20),
              tooltip: '清空所有输入',
              onPressed: _clearAll,
            ),
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
      body: Column(
        children: [
          _buildUrlInputSection(colorScheme),
          _buildDurationSection(colorScheme),
          Expanded(
            child: urls.isEmpty
                ? _buildEmptyState(colorScheme)
                : _buildUrlListSection(colorScheme, urls),
          ),
          _buildBottomBar(colorScheme, urls.length),
        ],
      ),
    );
  }

  // ====================================================================
  // URL Input Section
  // ====================================================================

  Widget _buildUrlInputSection(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _urlController,
          maxLines: null,
          minLines: 3,
          decoration: InputDecoration(
            hintText: '请输入视频/音频网页URL，每行一个',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(Icons.link),
            ),
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
          textInputAction: TextInputAction.newline,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return '请输入至少一个URL';
            // Check that at least one valid URL exists
            final lines = v.split('\n');
            for (final line in lines) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) continue;
              if (_isValidUrl(trimmed)) {
                return null; // At least one valid URL
              }
            }
            return '请输入有效的URL';
          },
        ),
      ),
    );
  }

  // ====================================================================
  // Duration Section
  // ====================================================================

  Widget _buildDurationSection(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                '可选：按时长筛选视频资源。留空则展示全部资源供选择',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '使用右上角按钮，在应用内浏览器登录，以获得需要登录才能获得的资源',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // URL List Section
  // ====================================================================

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '请输入网页URL',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持多行粘贴，每行一个URL，同时添加多个下载任务',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUrlListSection(
    ColorScheme colorScheme,
    List<String> urls,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListView.separated(
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final url = urls[index];
          return Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      url,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ====================================================================
  // Bottom Action Bar
  // ====================================================================

  Widget _buildBottomBar(ColorScheme colorScheme, int urlCount) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video folder selector
            _buildFolderSelector(
              colorScheme: colorScheme,
              icon: Icons.videocam,
              label: '视频保存至',
              currentFolder: _videoFolder,
              onTap: () => _pickVideoFolder(),
            ),
            const SizedBox(height: 4),
            // Audio folder selector
            _buildFolderSelector(
              colorScheme: colorScheme,
              icon: Icons.audio_file,
              label: '音频保存至',
              currentFolder: _audioFolder,
              onTap: () => _pickAudioFolder(),
            ),
            const SizedBox(height: 4),
            // URL count
            if (urlCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.link,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '已输入 $urlCount 个URL',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            // Start button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: urlCount == 0 ? null : _startTask,
                icon: const Icon(Icons.search, size: 20),
                label: const Text(
                  '开始分析',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
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
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required String currentFolder,
    required VoidCallback onTap,
  }) {
    // Use the same compact style as OCR/ASR bottom bar folder selectors
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              Text(
                currentFolder.isEmpty ? '根目录' : currentFolder,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
