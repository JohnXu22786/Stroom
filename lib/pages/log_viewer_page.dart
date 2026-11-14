import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../services/app_log_service.dart';

import '../widgets/constrained_text.dart';

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
  AppLogPolicy? _policy;
  AppLogStorageUsage _storageUsage = const AppLogStorageUsage(
    fileCount: 0,
    bytes: 0,
  );
  Timer? _retryTimer;
  int _retryCount = 0;
  static const Duration _maxRetryDelay = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPolicyAndUsage();
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
      _loadPolicyAndUsage();
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
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.appLogLoadFilesError(e),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadPolicyAndUsage() async {
    try {
      final policy = await AppLogService.getPolicy();
      final usage = await AppLogService.getStorageUsage();
      if (!mounted) return;
      setState(() {
        _policy = policy;
        _storageUsage = usage;
      });
    } catch (e) {
      debugPrint('[LogViewer] Failed to load logging settings: $e');
    }
  }

  Future<void> _openSettings() async {
    try {
      final policy = _policy ?? await AppLogService.getPolicy();
      final storageUsage = await AppLogService.getStorageUsage();
      if (!mounted) return;
      final updatedPolicy = await showDialog<AppLogPolicy>(
        context: context,
        builder: (_) =>
            _AppLogSettingsDialog(policy: policy, storageUsage: storageUsage),
      );
      if (updatedPolicy == null || !mounted) return;
      await AppLogService.updatePolicy(updatedPolicy);
      await _loadPolicyAndUsage();
      await _loadLogFiles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.appLogSettingsSaved),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.appLogSettingsError(e)),
        ),
      );
    }
  }

  Future<void> _viewLogFile(String fileName) async {
    final l10n = AppLocalizations.of(context)!;
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
          errorMsg = l10n.appLogReadFileUnreadable(fileName);
          debugPrint('[LogViewer] 文件存在但无法读取: $filePath');
        } else {
          errorMsg = l10n.appLogReadFileMissing(fileName);
          debugPrint('[LogViewer] 文件不存在: $filePath');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: l10n.appLogRefresh,
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.appLogReadFileError(e)),
          ),
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
        await _loadPolicyAndUsage();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.appLogDeleteDone(fileName),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.appLogDeleteError(e)),
          ),
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
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.appLogExportMissing(fileName),
              ),
            ),
          );
        }
        return;
      }

      await Clipboard.setData(ClipboardData(text: filePath));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.appLogPathCopied(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.appLogExportError(e)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: ConstrainedText(
          l10n.appLogPageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l10n.appLogSettings,
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.appLogRefresh,
            onPressed: () {
              _retryCount = 0; // Reset retry count on manual refresh
              _loadLogFiles();
              _loadPolicyAndUsage();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: l10n.appLogCleanupOldLogs,
            onPressed: () async {
              await AppLogService.cleanupOldLogs();
              await _loadLogFiles();
              await _loadPolicyAndUsage();
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.appLogCleanupDone)));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appLogRetentionNotice(
                      _policy?.retentionDays ?? AppLogService.retentionDays,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.appLogStorageUsage(
                      _storageUsage.fileCount,
                      _formatLogBytes(_storageUsage.bytes),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
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
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            kIsWeb ? l10n.appLogWebUnsupported : l10n.appLogNoFiles,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _retryCount > 0
                ? l10n.appLogAutoRefresh(_retryCount)
                : l10n.appLogWillBeCreated,
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
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logFiles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final fileName = _logFiles[index];
        return ListTile(
          leading: Icon(Icons.article, color: theme.colorScheme.primary),
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
                icon: Icon(
                  Icons.ios_share,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                tooltip: l10n.appLogExport,
                onPressed: () => _exportLogFile(fileName),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                tooltip: l10n.appLogDelete,
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
    final hourMatch = RegExp(r'app_(\d{4}-\d{2}-\d{2})-(\d{2})\.log')
        .firstMatch(fileName);
    if (hourMatch != null) {
      return '${hourMatch.group(1)} ${hourMatch.group(2)}:00';
    }
    final dayMatch = RegExp(r'app_(\d{4}-\d{2}-\d{2})\.log')
        .firstMatch(fileName);
    if (dayMatch != null) {
      return dayMatch.group(1)!;
    }
    return '';
  }

  void _confirmDelete(String fileName) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: ConstrainedText(
          l10n.appLogConfirmDeleteTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(l10n.appLogConfirmDeleteMessage(fileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: ConstrainedText(
              l10n.appLogCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteLogFile(fileName);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: ConstrainedText(
              l10n.appLogDelete,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatLogBytes(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class _AppLogSettingsDialog extends StatefulWidget {
  const _AppLogSettingsDialog({
    required this.policy,
    required this.storageUsage,
  });

  final AppLogPolicy policy;
  final AppLogStorageUsage storageUsage;

  @override
  State<_AppLogSettingsDialog> createState() => _AppLogSettingsDialogState();
}

class _AppLogSettingsDialogState extends State<_AppLogSettingsDialog> {
  late int _retentionDays;
  late LogLevel _minimumLevel;
  late int _maxStorageBytes;

  @override
  void initState() {
    super.initState();
    _retentionDays = widget.policy.retentionDays;
    _minimumLevel = widget.policy.minimumLevel;
    _maxStorageBytes = widget.policy.maxStorageBytes ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final retentionOptions = <int>{1, 3, 7, 15, 30, 60, 90, 180, 365}
      ..add(_retentionDays);
    const megabyte = 1024 * 1024;
    final sizeOptions = <int>{
      0,
      10 * megabyte,
      50 * megabyte,
      100 * megabyte,
      500 * megabyte,
    }..add(_maxStorageBytes);

    return AlertDialog(
      title: ConstrainedText(
        l10n.appLogSettingsTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.appLogStorageUsage(
                widget.storageUsage.fileCount,
                _formatLogBytes(widget.storageUsage.bytes),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _retentionDays,
              decoration: InputDecoration(labelText: l10n.appLogRetentionDays),
              items: (retentionOptions.toList()..sort())
                  .map(
                    (days) => DropdownMenuItem(
                      value: days,
                      child: ConstrainedText(
                        l10n.appLogDays(days),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _retentionDays = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<LogLevel>(
              isExpanded: true,
              initialValue: _minimumLevel,
              decoration: InputDecoration(labelText: l10n.appLogMinimumLevel),
              items: LogLevel.values
                  .map(
                    (level) => DropdownMenuItem(
                      value: level,
                      child: ConstrainedText(
                        _logLevelLabel(l10n, level),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _minimumLevel = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _maxStorageBytes,
              decoration: InputDecoration(labelText: l10n.appLogStorageLimit),
              items: (sizeOptions.toList()..sort()).map((sizeBytes) {
                return DropdownMenuItem(
                  value: sizeBytes,
                  child: ConstrainedText(
                    sizeBytes == 0
                        ? l10n.appLogUnlimited
                        : _formatLogBytes(sizeBytes),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _maxStorageBytes = value);
              },
            ),
            const SizedBox(height: 12),
            Text(
              l10n.appLogSettingsHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: ConstrainedText(
            l10n.appLogCancel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            AppLogPolicy(
              retentionDays: _retentionDays,
              minimumLevel: _minimumLevel,
              maxStorageBytes: _maxStorageBytes == 0 ? null : _maxStorageBytes,
            ),
          ),
          child: ConstrainedText(
            l10n.appLogSave,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

String _logLevelLabel(AppLocalizations l10n, LogLevel level) => switch (level) {
  LogLevel.debug => l10n.appLogLevelDebug,
  LogLevel.info => l10n.appLogLevelInfo,
  LogLevel.warning => l10n.appLogLevelWarning,
  LogLevel.error => l10n.appLogLevelError,
};

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
  final DateTime? timestamp;
  final String? level;
  final String? source;

  const _ParsedLogLine({
    required this.text,
    required this.isEmpty,
    this.color,
    this.icon,
    this.timestamp,
    this.level,
    this.source,
  });
}

/// 匹配日志行中的级别标记，如 `[ERROR]`。
final RegExp _levelPattern = RegExp(r'\[(DEBUG|INFO|WARN|ERROR)\]');
final RegExp _logEntryPattern = RegExp(
  r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] '
  r'\[(DEBUG|INFO|WARN|ERROR)\] \[([^\]]+)\]',
);

class _LogContentPageState extends State<LogContentPage> {
  bool _showRaw = false;
  bool _showFilters = false;
  String _keyword = '';
  String _sourceFilter = '';
  String? _levelFilter;
  TimeOfDay? _fromTime;
  TimeOfDay? _untilTime;
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
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
    _keywordController.dispose();
    _sourceController.dispose();
    _rawScrollController.dispose();
    _structuredScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!mounted) return;
    final controller = _showRaw
        ? _rawScrollController
        : _structuredScrollController;
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
      final target = nowRaw
          ? _rawScrollController
          : _structuredScrollController;
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
        SnackBar(
          content: Text(AppLocalizations.of(context)!.appLogCopyError(e)),
        ),
      );
      return;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.appLogCopyDone),
        duration: const Duration(seconds: 2),
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

  bool get _hasActiveFilters =>
      _keyword.trim().isNotEmpty ||
      _sourceFilter.trim().isNotEmpty ||
      _levelFilter != null ||
      _fromTime != null ||
      _untilTime != null;

  List<_ParsedLogLine> get _visibleLines {
    final blocks = <List<_ParsedLogLine>>[];
    for (final line in _lines) {
      if (line.timestamp != null || blocks.isEmpty) {
        blocks.add([line]);
      } else {
        blocks.last.add(line);
      }
    }

    return blocks
        .where((block) {
          final entry = block.firstWhere(
            (line) => line.timestamp != null,
            orElse: () => block.first,
          );
          if (_levelFilter != null && entry.level != _levelFilter) return false;
          if (_sourceFilter.trim().isNotEmpty &&
              !(entry.source ?? '').toLowerCase().contains(
                _sourceFilter.trim().toLowerCase(),
              )) {
            return false;
          }
          if ((_fromTime != null || _untilTime != null) &&
              entry.timestamp == null) {
            return false;
          }
          final timestamp = entry.timestamp;
          if (timestamp != null) {
            final minute = timestamp.hour * 60 + timestamp.minute;
            final from = _fromTime == null
                ? null
                : _fromTime!.hour * 60 + _fromTime!.minute;
            final until = _untilTime == null
                ? null
                : _untilTime!.hour * 60 + _untilTime!.minute;
            if (from != null && until != null) {
              final matches = from <= until
                  ? minute >= from && minute <= until
                  : minute >= from || minute <= until;
              if (!matches) return false;
            } else if (from != null && minute < from) {
              return false;
            } else if (until != null && minute > until) {
              return false;
            }
          }
          if (_keyword.trim().isNotEmpty &&
              !block
                  .map((line) => line.text)
                  .join('\n')
                  .toLowerCase()
                  .contains(_keyword.trim().toLowerCase())) {
            return false;
          }
          return true;
        })
        .expand((block) => block)
        .toList(growable: false);
  }

  static List<_ParsedLogLine> _parseLines(String content) {
    return content
        .split('\n')
        .map((line) {
          if (line.trim().isEmpty) {
            return _ParsedLogLine(text: line, isEmpty: true);
          }
          final match = _levelPattern.firstMatch(line);
          final entryMatch = _logEntryPattern.firstMatch(line);
          final timestamp = entryMatch == null
              ? null
              : DateTime.tryParse(entryMatch.group(1)!);
          if (match == null) {
            return _ParsedLogLine(
              text: line,
              isEmpty: false,
              timestamp: timestamp,
              level: entryMatch?.group(2),
              source: entryMatch?.group(3),
            );
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
            timestamp: timestamp,
            level: entryMatch?.group(2) ?? match.group(1),
            source: entryMatch?.group(3),
          );
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        // FittedBox 防止大字体缩放下两行标题超出固定高度的工具栏。
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedText(
                widget.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _hasActiveFilters
                    ? l10n.appLogFilteredLineCount(
                        _visibleLines.length,
                        _lineCount,
                      )
                    : l10n.appLogLineCount(_lineCount),
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
            icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt),
            tooltip: l10n.appLogFilter,
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: l10n.appLogCopyAll,
            onPressed: _copyAllContent,
          ),
          IconButton(
            icon: Icon(_showRaw ? Icons.format_list_bulleted : Icons.code),
            tooltip: _showRaw ? l10n.appLogStructuredView : l10n.appLogRawView,
            onPressed: _toggleView,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters) _buildFilterPanel(l10n),
          Expanded(
            child: _showRaw
                ? _buildRawView(theme)
                : _buildStructuredView(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _keywordController,
            decoration: InputDecoration(
              labelText: l10n.appLogSearch,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _keyword = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sourceController,
                  decoration: InputDecoration(
                    labelText: l10n.appLogSource,
                    prefixIcon: const Icon(Icons.source_outlined),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _sourceFilter = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  key: ValueKey(_levelFilter),
                  isExpanded: true,
                  initialValue: _levelFilter,
                  decoration: InputDecoration(
                    labelText: l10n.appLogLevel,
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: ConstrainedText(
                        l10n.appLogAnyLevel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...LogLevel.values.map(
                      (level) => DropdownMenuItem<String?>(
                        value: level.label,
                        child: ConstrainedText(
                          _logLevelLabel(l10n, level),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _levelFilter = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _chooseTime(fromTime: true),
                  icon: const Icon(Icons.schedule),
                  label: ConstrainedText(
                    _fromTime == null
                        ? l10n.appLogFromTime
                        : '${l10n.appLogFromTime}: ${_fromTime!.format(context)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _chooseTime(fromTime: false),
                  icon: const Icon(Icons.schedule),
                  label: ConstrainedText(
                    _untilTime == null
                        ? l10n.appLogUntilTime
                        : '${l10n.appLogUntilTime}: ${_untilTime!.format(context)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.appLogClearFilters,
                onPressed: _hasActiveFilters
                    ? () => setState(() {
                        _keyword = '';
                        _sourceFilter = '';
                        _keywordController.clear();
                        _sourceController.clear();
                        _levelFilter = null;
                        _fromTime = null;
                        _untilTime = null;
                      })
                    : null,
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _chooseTime({required bool fromTime}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: fromTime
          ? _fromTime ?? const TimeOfDay(hour: 0, minute: 0)
          : _untilTime ?? const TimeOfDay(hour: 23, minute: 59),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (fromTime) {
        _fromTime = selected;
      } else {
        _untilTime = selected;
      }
    });
  }

  Widget _buildRawView(ThemeData theme) {
    if (_hasActiveFilters && _visibleLines.every((line) => line.isEmpty)) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.appLogNoMatches,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    final visibleContent = _hasActiveFilters
        ? _visibleLines.map((line) => line.text).join('\n')
        : widget.content;
    return SingleChildScrollView(
      controller: _rawScrollController,
      // 纯文本模式边缘留白更大，阅读更舒适。
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SelectableText(
        visibleContent,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildStructuredView(ThemeData theme) {
    final lines = _visibleLines;
    if (lines.isEmpty || lines.every((line) => line.isEmpty)) {
      return Center(
        child: Text(
          _hasActiveFilters
              ? AppLocalizations.of(context)!.appLogNoMatches
              : AppLocalizations.of(context)!.appLogNoFiles,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      controller: _structuredScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
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
