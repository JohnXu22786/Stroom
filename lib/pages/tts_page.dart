import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../providers/tts_state_provider.dart';
import '../providers/tts_config.dart';
import 'tts_create_page.dart';

class TtsPage extends ConsumerStatefulWidget {
  const TtsPage({super.key});

  @override
  ConsumerState<TtsPage> createState() => _TtsPageState();
}

class _TtsPageState extends ConsumerState<TtsPage> {
  final TextEditingController _folderNameController = TextEditingController();
  final TextEditingController _renameController = TextEditingController();
  String? _selectedFileId;

  @override
  void initState() {
    super.initState();
    // 初始化时加载音频文件列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioFilesProvider.notifier).loadAudioFiles();
    });
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  /// 创建文件夹
  Future<void> _createFolder() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建文件夹'),
        content: TextField(
          controller: _folderNameController,
          decoration: const InputDecoration(
            hintText: '输入文件夹名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_folderNameController.text.trim().isNotEmpty) {
                Navigator.pop(context, _folderNameController.text.trim());
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await ref.read(audioFilesProvider.notifier).createFolder(result);
      _folderNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('文件夹 "$result" 创建成功'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 重命名文件
  Future<void> _renameFile(String fileId, String currentName) async {
    _renameController.text = currentName;
    _selectedFileId = fileId;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名文件'),
        content: TextField(
          controller: _renameController,
          decoration: const InputDecoration(
            hintText: '输入新名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_renameController.text.trim().isNotEmpty) {
                Navigator.pop(context, _renameController.text.trim());
              }
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && _selectedFileId != null) {
      await ref.read(audioFilesProvider.notifier).renameAudioFile(_selectedFileId!, result);
      _renameController.clear();
      _selectedFileId = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件重命名成功'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 移动文件到文件夹
  Future<void> _moveFile(String fileId) async {
    // TODO: 实现文件夹选择对话框
    // 暂时移动到根目录
    await ref.read(audioFilesProvider.notifier).moveAudioFile(fileId, '');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('文件移动成功'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 复制文件
  Future<void> _copyFile(String fileId) async {
    await ref.read(audioFilesProvider.notifier).copyAudioFile(fileId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('文件复制成功'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 删除文件
  Future<void> _deleteFile(String fileId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除此文件吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(audioFilesProvider.notifier).deleteAudioFile(fileId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件删除成功'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 播放音频文件
  Future<void> _playAudio(String filePath) async {
    // TODO: 实现音频播放功能
    // 使用just_audio或audioplayers包
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('播放: ${path.basename(filePath)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 分享音频文件
  Future<void> _shareAudio(String filePath) async {
    // TODO: 实现文件分享功能
    // 使用share_plus包
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('分享: ${path.basename(filePath)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 刷新文件列表
  Future<void> _refreshFileList() async {
    await ref.read(audioFilesProvider.notifier).loadAudioFiles();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('文件列表已刷新'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioFiles = ref.watch(audioFilesProvider);
    final ttsState = ref.watch(ttsStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('录音'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: '创建文件夹',
            onPressed: _createFolder,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新列表',
            onPressed: _refreshFileList,
          ),
        ],
      ),
      body: Column(
        children: [
          // 制作录音按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TTSCreatePage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 24),
                    SizedBox(width: 12),
                    Text(
                      '制作录音',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 状态显示
          if (ttsState.isSynthesizing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                value: ttsState.progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),

          // 文件列表标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '音频文件 (${audioFiles.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (audioFiles.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      // TODO: 实现排序功能
                    },
                    child: const Text('排序'),
                  ),
              ],
            ),
          ),

          // 文件列表
          Expanded(
            child: audioFiles.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.audio_file_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '暂无录音文件',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '点击上方按钮创建您的第一个录音',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: audioFiles.length,
                    itemBuilder: (context, index) {
                      final file = audioFiles[index];
                      final fileExtension = path.extension(file.path).replaceAll('.', '');
                      final fileSize = _formatFileSize(file.size);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                fileExtension.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            file.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${_formatDate(file.createdAt)} • $fileSize',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              switch (value) {
                                case 'play':
                                  _playAudio(file.path);
                                  break;
                                case 'rename':
                                  _renameFile(file.id, file.name);
                                  break;
                                case 'move':
                                  _moveFile(file.id);
                                  break;
                                case 'copy':
                                  _copyFile(file.id);
                                  break;
                                case 'share':
                                  _shareAudio(file.path);
                                  break;
                                case 'delete':
                                  _deleteFile(file.id);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'play',
                                child: Row(
                                  children: [
                                    Icon(Icons.play_arrow, size: 20),
                                    SizedBox(width: 8),
                                    Text('播放'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 8),
                                    Text('重命名'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'move',
                                child: Row(
                                  children: [
                                    Icon(Icons.drive_file_move, size: 20),
                                    SizedBox(width: 8),
                                    Text('移动'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'copy',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy, size: 20),
                                    SizedBox(width: 8),
                                    Text('复制'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share, size: 20),
                                    SizedBox(width: 8),
                                    Text('分享'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 20, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('删除', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _playAudio(file.path),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今天 ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return '昨天 ${_formatTime(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// 格式化时间
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
