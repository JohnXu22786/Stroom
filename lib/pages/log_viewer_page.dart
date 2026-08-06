import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../services/app_log_service.dart';

// ====================================================================
// LogViewerPage — 应用日志查看器
// ====================================================================
//
// 在应用内直接查看自动备份目录中的日志文件。
// 列出所有日志文件，点击查看内容。
// ====================================================================

/// 应用日志查看页面。
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage>
    with WidgetsBindingObserver {
  List<String> _logFiles = [];
  bool _isLoading = true;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const Duration _maxRetryDelay = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLogFiles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLogFiles();
    }
  }

  /// Schedule a retry to load log files after a delay.
  ///
  /// Uses exponential backoff capped at [_maxRetryDelay] (60s).
  /// Retries continue indefinitely so that the page auto-refreshes
  /// when logs are eventually generated.
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryCount++;
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s, 60s, 60s, ...
    final delay = Duration(
      seconds: _retryCount <= 6
          ? (1 << (_retryCount - 1)) // 1, 2, 4, 8, 16, 32
          : _maxRetryDelay.inSeconds, // cap at 60s
    );
    _retryTimer = Timer(delay, () {
      if (mounted) {
        _loadLogFiles();
      }
    });
  }

  Future<void> _loadLogFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await AppLogService.listLogFiles();
      if (mounted) {
        setState(() {
          _logFiles = files.reversed.toList(); // 最新的在前
          _isLoading = false;
        });
      }
      // If no files found, schedule a retry (auto-refresh)
      if (files.isEmpty && mounted) {
        _scheduleRetry();
      } else {
        _retryCount = 0; // Reset retry count on success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _scheduleRetry(); // Retry on error too
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载日志文件列表失败: $e')),
        );
      }
    }
  }

  Future<void> _viewLogFile(String fileName) async {
    try {
      final content = await AppLogService.readLogFile(fileName);
      if (!mounted) return;

      if (content == null) {
        final logDir = await AppLogService.getLogDir();
        if (!mounted) return;
        final filePath = p.join(logDir.path, fileName);
        final file = File(filePath);
        final fileExists = await file.exists();

        String errorMsg;
        if (fileExists) {
          errorMsg = '日志文件 "$fileName" 存在但无法读取，可能文件已损坏';
          debugPrint('[LogViewer] 文件存在但无法读取: $filePath');
        } else {
          errorMsg = '日志文件 "$fileName" 不存在，可能已被清理';
          debugPrint('[LogViewer] 文件不存在: $filePath');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: '刷新',
                onPressed: () {
                  _retryCount = 0;
                  _loadLogFiles();
                },
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LogContentPage(fileName: fileName, content: content),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('读取日志文件失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteLogFile(String fileName) async {
    try {
      final logDir = await AppLogService.getLogDir();
      final file = File(p.join(logDir.path, fileName));
      if (await file.exists()) {
        await file.delete();
        await _loadLogFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除: $fileName')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  /// 导出日志文件：复制文件路径到剪贴板，方便用户用系统资源管理器打开。
  /// 这是最简单、最通用的"导出"方式——文件本身就在用户机器上，
  /// 无需另存为。
  Future<void> _exportLogFile(String fileName) async {
    try {
      final logDir = await AppLogService.getLogDir();
      final filePath = p.join(logDir.path, fileName);
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('日志文件 "$fileName" 不存在')),
          );
        }
        return;
      }

      await Clipboard.setData(ClipboardData(text: filePath));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已复制路径: $filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('应用日志'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              _retryCount = 0; // Reset retry count on manual refresh
              _loadLogFiles();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清理旧日志',
            onPressed: () async {
              await AppLogService.cleanupOldLogs();
              await _loadLogFiles();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('旧日志已清理')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logFiles.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: () async {
                    _retryCount = 0;
                    await _loadLogFiles();
                  },
                  child: _buildLogFileList(theme),
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            kIsWeb ? 'Web 平台不支持本地日志' : '暂无日志文件',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _retryCount > 0 ? '自动刷新中 (第 $_retryCount 次)...' : '应用运行后将自动生成日志',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_retryCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogFileList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logFiles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final fileName = _logFiles[index];
        return ListTile(
          leading: Icon(
            Icons.article,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            fileName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            _getFileDateLabel(fileName),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.ios_share,
                    color: theme.colorScheme.primary, size: 20),
                tooltip: '导出',
                onPressed: () => _exportLogFile(fileName),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: theme.colorScheme.error, size: 20),
                tooltip: '删除',
                onPressed: () => _confirmDelete(fileName),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => _viewLogFile(fileName),
        );
      },
    );
  }

  /// 解析文件名的时间戳，返回人类友好的展示标签。
  ///
  /// 新格式：app_YYYY-MM-DD-HH.log → 2024-01-01 14:00
  /// 兼容旧格式：app_YYYY-MM-DD.log → 2024-01-01
  String _getFileDateLabel(String fileName) {
    final hourMatch =
        RegExp(r'app_(\d{4}-\d{2}-\d{2})-(\d{2})\.log').firstMatch(fileName);
    if (hourMatch != null) {
      return '${hourMatch.group(1)} ${hourMatch.group(2)}:00';
    }
    final dayMatch =
        RegExp(r'app_(\d{4}-\d{2}-\d{2})\.log').firstMatch(fileName);
    if (dayMatch != null) {
      return dayMatch.group(1)!;
    }
    return '';
  }

  void _confirmDelete(String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除日志文件 "$fileName" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteLogFile(fileName);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 日志内容查看页面
// ====================================================================

/// 日志内容查看页面，提供两种阅读模式：
/// - 结构化视图（渲染）：按行解析级别并着色、加图标。
/// - 原始视图（纯文本）：整份日志的纯文本，边缘留白更大。
///
/// 进入页面时自动滚动到底部一次（最新日志位于文件末尾）；
/// 切换两种模式时保持当前阅读位置，不会再次滚动到底部。
class LogContentPage extends StatefulWidget {
  final String fileName;
  final String content;

  const LogContentPage({
    super.key,
    required this.fileName,
    required this.content,
  });

  @override
  State<LogContentPage> createState() => _LogContentPageState();
}

/// 解析后的单行日志，样式信息只解析一次，滚动重建时直接复用。
class _ParsedLogLine {
  final String text;
  final bool isEmpty;
  final Color? color;
  final IconData? icon;

  const _ParsedLogLine({
    required this.text,
    required this.isEmpty,
    this.color,
    this.icon,
  });
}

/// 匹配日志行中的级别标记，如 `[ERROR]`。
final RegExp _levelPattern = RegExp(r'\[(DEBUG|INFO|WARN|ERROR)\]');

class _LogContentPageState extends State<LogContentPage> {
  bool _showRaw = false;
  final ScrollController _rawScrollController = ScrollController();
  final ScrollController _structuredScrollController = ScrollController();

  /// 各视图离开时保存的滚动位置，切换回来时恢复（而不是滚到底部）。
  /// null 表示该视图还没有显示过。
  double? _rawSavedOffset;
  double? _structuredSavedOffset;

  /// 预解析的日志行（样式/图标只计算一次，避免滚动时重复正则匹配）。
  late final List<_ParsedLogLine> _lines;
  late final int _lineCount;

  @override
  void initState() {
    super.initState();
    _lines = _parseLines(widget.content);
    _lineCount = _countLines();
    // 只在刚进入页面时自动滚动到底部一次。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _rawScrollController.dispose();
    _structuredScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!mounted) return;
    final controller =
        _showRaw ? _rawScrollController : _structuredScrollController;
    if (!controller.hasClients) return;
    controller.jumpTo(controller.position.maxScrollExtent);
  }

  /// 切换渲染/纯文本视图。
  ///
  /// 只保存当前视图的滚动位置并恢复另一个视图上次的位置，不会滚动到底部，
  /// 避免打断阅读。第一次显示的视图按比例映射当前位置，保证切换后
  /// 停留在同一段日志上（而不是跳到文件头或文件尾）。
  void _toggleView() {
    final wasRaw = _showRaw;
    final current = wasRaw ? _rawScrollController : _structuredScrollController;

    // 当前视图的阅读比例，用于另一个视图首次显示时映射位置。
    double? leavingFraction;
    if (current.hasClients) {
      if (wasRaw) {
        _rawSavedOffset = current.offset;
      } else {
        _structuredSavedOffset = current.offset;
      }
      final maxExtent = current.position.maxScrollExtent;
      if (maxExtent > 0) {
        leavingFraction = current.offset / maxExtent;
      }
    }

    setState(() => _showRaw = !wasRaw);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nowRaw = _showRaw;
      final target =
          nowRaw ? _rawScrollController : _structuredScrollController;
      if (!target.hasClients) return;

      final double? saved = nowRaw ? _rawSavedOffset : _structuredSavedOffset;
      final double offset = saved != null
          ? saved.clamp(0.0, target.position.maxScrollExtent)
          : (leavingFraction ?? 1.0) * target.position.maxScrollExtent;
      target.jumpTo(offset);
    });
  }

  Future<void> _copyAllContent() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.content));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('复制失败: $e')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制全部日志内容'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 统计日志总行数（文件末尾的换行符不算额外一行）。
  int _countLines() {
    if (widget.content.isEmpty) return 0;
    var count = _lines.length;
    if (widget.content.endsWith('\n')) count--;
    return count;
  }

  static List<_ParsedLogLine> _parseLines(String content) {
    return content.split('\n').map((line) {
      if (line.trim().isEmpty) {
        return _ParsedLogLine(text: line, isEmpty: true);
      }
      final match = _levelPattern.firstMatch(line);
      if (match == null) {
        return _ParsedLogLine(text: line, isEmpty: false);
      }
      final (Color?, IconData?) levelStyle = switch (match.group(1)!) {
        'ERROR' => (Colors.red, Icons.error_outline),
        'WARN' => (Colors.orange, Icons.warning_amber_rounded),
        'INFO' => (Colors.blue, Icons.info_outline),
        'DEBUG' => (Colors.grey, Icons.bug_report_outlined),
        _ => (null, null),
      };
      return _ParsedLogLine(
        text: line,
        isEmpty: false,
        color: levelStyle.$1,
        icon: levelStyle.$2,
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // FittedBox 防止大字体缩放下两行标题超出固定高度的工具栏。
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.fileName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '共 $_lineCount 行',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: '复制全文',
            onPressed: _copyAllContent,
          ),
          IconButton(
            icon: Icon(_showRaw ? Icons.format_list_bulleted : Icons.code),
            tooltip: _showRaw ? '结构化视图' : '原始视图',
            onPressed: _toggleView,
          ),
        ],
      ),
      body: _showRaw ? _buildRawView(theme) : _buildStructuredView(theme),
    );
  }

  Widget _buildRawView(ThemeData theme) {
    return SingleChildScrollView(
      controller: _rawScrollController,
      // 纯文本模式边缘留白更大，阅读更舒适。
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SelectableText(
        widget.content,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildStructuredView(ThemeData theme) {
    return ListView.builder(
      controller: _structuredScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _lines.length,
      itemBuilder: (context, index) {
        final line = _lines[index];
        if (line.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 固定图标位宽，保证有/无级别标记的行文本列对齐。
              if (line.icon != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Icon(line.icon, size: 16, color: line.color),
                )
              else
                const SizedBox(width: 22),
              Expanded(
                child: SelectableText(
                  line.text,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: line.color ?? theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
