import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

class _LogViewerPageState extends State<LogViewerPage> {
  List<String> _logFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载日志文件列表失败: $e')),
        );
      }
    }
  }

  Future<void> _viewLogFile(String fileName) async {
    final content = await AppLogService.readLogFile(fileName);
    if (!mounted) return;

    if (content == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法读取日志文件')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LogContentPage(fileName: fileName, content: content),
      ),
    );
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
            onPressed: _loadLogFiles,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清理旧日志',
            onPressed: () async {
              await AppLogService.cleanupOldLogs();
              await _loadLogFiles();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('旧日志已清理')),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logFiles.isEmpty
              ? _buildEmptyState(theme)
              : _buildLogFileList(theme),
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
            '应用运行后将自动生成日志',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
            _getFileDate(fileName),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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

  String _getFileDate(String fileName) {
    // app_2024-01-01.log -> 2024-01-01
    final match = RegExp(r'app_(\d{4}-\d{2}-\d{2})').firstMatch(fileName);
    if (match != null) return match.group(1)!;
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
// 日志内容查看子页面
// ====================================================================

class _LogContentPage extends StatefulWidget {
  final String fileName;
  final String content;

  const _LogContentPage({
    required this.fileName,
    required this.content,
  });

  @override
  State<_LogContentPage> createState() => _LogContentPageState();
}

class _LogContentPageState extends State<_LogContentPage> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = widget.content.split('\n');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showRaw ? Icons.format_list_bulleted : Icons.code),
            tooltip: _showRaw ? '结构化视图' : '原始视图',
            onPressed: () => setState(() => _showRaw = !_showRaw),
          ),
        ],
      ),
      body: _showRaw ? _buildRawView(theme) : _buildStructuredView(theme, lines),
    );
  }

  Widget _buildRawView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
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

  Widget _buildStructuredView(ThemeData theme, List<String> lines) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        if (line.trim().isEmpty) return const SizedBox.shrink();

        // 解析日志行格式: [timestamp] [LEVEL] [Source] message
        final levelMatch = RegExp(r'\[(DEBUG|INFO|WARN|ERROR)\]').firstMatch(line);
        Color? levelColor;
        IconData? levelIcon;
        if (levelMatch != null) {
          switch (levelMatch.group(1)!) {
            case 'ERROR':
              levelColor = Colors.red;
              levelIcon = Icons.error_outline;
              break;
            case 'WARN':
              levelColor = Colors.orange;
              levelIcon = Icons.warning_amber_rounded;
              break;
            case 'INFO':
              levelColor = Colors.blue;
              levelIcon = Icons.info_outline;
              break;
            case 'DEBUG':
              levelColor = Colors.grey;
              levelIcon = Icons.bug_report_outlined;
              break;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (levelIcon != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Icon(levelIcon, size: 16, color: levelColor),
                ),
              Expanded(
                child: SelectableText(
                  line,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: levelColor ?? theme.colorScheme.onSurface,
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
