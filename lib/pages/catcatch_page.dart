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
// 单个任务卡片数据
// =============================================================================

/// 每个任务卡片拥有独立的输入控制器。
class _TaskEntry {
  final TextEditingController urlController;
  final TextEditingController hourController;
  final TextEditingController minuteController;
  final TextEditingController secondController;

  _TaskEntry({
    String? initialUrl,
    int? initialDurationSec,
  })  : urlController = TextEditingController(text: initialUrl ?? ''),
        hourController = TextEditingController(),
        minuteController = TextEditingController(),
        secondController = TextEditingController() {
    if (initialDurationSec != null && initialDurationSec > 0) {
      final h = initialDurationSec ~/ 3600;
      final m = (initialDurationSec % 3600) ~/ 60;
      final s = initialDurationSec % 60;
      hourController.text = h.toString();
      minuteController.text = m.toString();
      secondController.text = s.toString();
    }
  }

  void dispose() {
    urlController.dispose();
    hourController.dispose();
    minuteController.dispose();
    secondController.dispose();
  }
}

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
  final List<_TaskEntry> _tasks = [];
  String _videoFolder = '';
  String _audioFolder = '';

  @override
  void initState() {
    super.initState();
    // 仅当带有初始参数时预填充第一个卡片
    if (widget.initialUrl != null || widget.initialDurationSec != null) {
      _addTaskEntry(
        initialUrl: widget.initialUrl,
        initialDurationSec: widget.initialDurationSec,
      );
    }
  }

  @override
  void dispose() {
    for (final task in _tasks) {
      task.dispose();
    }
    super.dispose();
  }

  // ====================================================================
  // 任务卡片管理
  // ====================================================================

  void _addTaskEntry({String? initialUrl, int? initialDurationSec}) {
    final entry = _TaskEntry(
      initialUrl: initialUrl,
      initialDurationSec: initialDurationSec,
    );
    // 监听时长输入变化以更新预览
    entry.hourController.addListener(_triggerRebuild);
    entry.minuteController.addListener(_triggerRebuild);
    entry.secondController.addListener(_triggerRebuild);
    setState(() {
      _tasks.add(entry);
    });
  }

  void _removeTaskEntry(int index) {
    _tasks[index].dispose();
    setState(() {
      _tasks.removeAt(index);
    });
  }

  void _triggerRebuild() {
    setState(() {});
  }

  // ====================================================================
  // 工具方法
  // ====================================================================

  int _parseInt(String text) => int.tryParse(text.trim()) ?? 0;

  String _computePreview(
    TextEditingController hour,
    TextEditingController minute,
    TextEditingController second,
  ) {
    final h = _parseInt(hour.text);
    final m = _parseInt(minute.text);
    final s = _parseInt(second.text);
    final total = totalSeconds(hours: h, minutes: m, seconds: s);
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    return formatHms(
      DurationResult(hours: hours, minutes: minutes, seconds: seconds),
    );
  }

  bool _isValidUrl(String trimmed) {
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  // ====================================================================
  // 启动任务
  // ====================================================================

  void _startTask() {
    // 过滤出有效任务
    final validEntries = <_TaskEntry>[];
    for (final task in _tasks) {
      final url = task.urlController.text.trim();
      if (url.isNotEmpty && _isValidUrl(url)) {
        validEntries.add(task);
      }
    }

    if (validEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请至少输入一个有效的URL'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int successCount = 0;
    for (final entry in validEntries) {
      final url = entry.urlController.text.trim();
      final h = _parseInt(entry.hourController.text);
      final m = _parseInt(entry.minuteController.text);
      final s = _parseInt(entry.secondController.text);
      final totalSec = totalSeconds(hours: h, minutes: m, seconds: s);

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

  // ====================================================================
  // Build
  // ====================================================================

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
            key: const Key('catcatch_add_task'),
            icon: const Icon(Icons.add, size: 22),
            tooltip: '添加任务',
            onPressed: () => _addTaskEntry(),
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
          Expanded(
            child: _tasks.isEmpty
                ? _buildEmptyState(colorScheme)
                : _buildTaskList(colorScheme),
          ),
          _buildBottomBar(colorScheme),
        ],
      ),
    );
  }

  // ====================================================================
  // 空状态
  // ====================================================================

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无下载任务',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 添加下载任务',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 任务卡片列表
  // ====================================================================

  Widget _buildTaskList(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (int i = 0; i < _tasks.length; i++)
              _buildTaskCard(colorScheme, i),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(ColorScheme colorScheme, int index) {
    final task = _tasks[index];
    final previewText = _computePreview(
      task.hourController,
      task.minuteController,
      task.secondController,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ============================================================
              // 第1行：URL 输入 + 删除按钮
              // ============================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: task.urlController,
                      decoration: InputDecoration(
                        hintText: '请输入视频/音频网页URL',
                        prefixIcon: const Icon(Icons.link, size: 20),
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
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      onPressed: () => _removeTaskEntry(index),
                      tooltip: '删除此任务',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ============================================================
              // 第2行：时长输入 (时/分/秒)
              // ============================================================
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: task.hourController,
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
                      controller: task.minuteController,
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
                      controller: task.secondController,
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

              // ============================================================
              // 第3行：预览提示
              // ============================================================
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
                      previewText,
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
                  '可选：按时长筛选视频资源。留空则展示全部资源供选择',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // 底部操作栏
  // ====================================================================

  Widget _buildBottomBar(ColorScheme colorScheme) {
    final taskCount = _tasks.length;
    final hasValidUrl = _tasks.any((t) {
      final url = t.urlController.text.trim();
      return url.isNotEmpty && _isValidUrl(url);
    });

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
            // 视频保存文件夹
            _buildFolderSelector(
              colorScheme: colorScheme,
              icon: Icons.videocam,
              label: '视频保存至',
              currentFolder: _videoFolder,
              onTap: () => _pickVideoFolder(),
            ),
            const SizedBox(height: 4),
            // 音频保存文件夹
            _buildFolderSelector(
              colorScheme: colorScheme,
              icon: Icons.audio_file,
              label: '音频保存至',
              currentFolder: _audioFolder,
              onTap: () => _pickAudioFolder(),
            ),
            const SizedBox(height: 4),
            // 任务计数
            if (taskCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.task_alt,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '已添加 $taskCount 个任务',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            // 开始按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: hasValidUrl ? _startTask : null,
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
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
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
