import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/provider_config.dart';
import '../providers/tts_state_provider.dart';
import '../providers/background_task_provider.dart';
import '../services/asr_service.dart';
import '../utils/data_sanitizer.dart';
import '../utils/file_manifest.dart';
import '../utils/text_manifest.dart';
import '../widgets/folder_picker_dialog.dart';

// ============================================================================
// Provider: Get the first configured ASR config from provider entries
// ============================================================================

/// Reads the first ASR provider config from the provider entries.
/// Returns null if none is configured.
AsrConfig? _resolveAsrConfig(WidgetRef ref) {
  final state = ref.read(providerEntriesProvider);
  for (final entry in state.entries) {
    if (entry.type == 'asr' && entry.configs.isNotEmpty) {
      final config = entry.configs.first;
      if (config.host.isNotEmpty && config.key.isNotEmpty) {
        final model = config.models.isNotEmpty
            ? config.models.first.modelId
            : 'whisper-1';
        return AsrConfig(
          host: config.host,
          apiKey: config.key,
          model: model,
        );
      }
    }
  }
  return null;
}

/// Collect all available model names from the first ASR provider config.
List<ModelConfig> _getAsrModels(WidgetRef ref) {
  final state = ref.read(providerEntriesProvider);
  for (final entry in state.entries) {
    if (entry.type == 'asr' && entry.configs.isNotEmpty) {
      final config = entry.configs.first;
      if (config.host.isNotEmpty && config.key.isNotEmpty) {
        return config.models;
      }
    }
  }
  return [];
}

// ============================================================================
// Selected Audio Model
// ============================================================================

/// Represents a single selected audio file for ASR transcription.
class SelectedAudio {
  final Uint8List bytes;
  final String name;
  final String format;

  SelectedAudio({
    required this.bytes,
    required this.name,
    this.format = 'wav',
  });
}

// ============================================================================
// ASR Page
// ============================================================================

/// Main ASR page — allows selecting audio files from device storage,
/// then performing speech-to-text transcription and saving results to text storage.
class AsrPage extends ConsumerStatefulWidget {
  const AsrPage({super.key});

  @override
  ConsumerState<AsrPage> createState() => _AsrPageState();
}

class _AsrPageState extends ConsumerState<AsrPage> {
  SelectedAudio? _selectedAudio;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _transcriptionResult;
  int _selectedModelIndex = 0;

  /// Save-to folder selection
  String _saveFolder = '';

  /// Captured raw request data from the last failed ASR call.
  Map<String, dynamic>? _lastRawRequest;

  /// Captured raw response data from the last failed ASR call.
  Map<String, dynamic>? _lastRawResponse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音识别'),
        centerTitle: true,
        actions: [
          if (_selectedAudio != null && !_isProcessing)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('清空'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Model selector (nicely styled)
          _buildModelSelector(cs),

          // Audio source buttons
          _buildAudioSourceBar(cs),

          // Audio info area
          Expanded(
            child: _selectedAudio == null
                ? _buildEmptyState(cs)
                : _buildAudioInfo(cs),
          ),

          // Error message
          if (_errorMessage != null) _buildErrorBanner(cs),

          // Transcription result
          if (_transcriptionResult != null) _buildResultBanner(cs),

          // Processing indicator or action button
          _buildBottomBar(cs),
        ],
      ),
    );
  }

  // ==================================================================
  // Model Selector — nicely styled, pill-shaped dropdown
  // ==================================================================

  Widget _buildModelSelector(ColorScheme cs) {
    final models = _getAsrModels(ref);
    if (models.isEmpty) return const SizedBox.shrink();

    final clampedIndex = _selectedModelIndex.clamp(0, models.length - 1);
    if (clampedIndex != _selectedModelIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedModelIndex = clampedIndex);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withValues(alpha: 0.6),
              cs.secondaryContainer.withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.tune, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Text(
              '识别模型',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: clampedIndex,
                    isDense: true,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: cs.primary,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    onChanged: (idx) {
                      if (idx == null || idx >= models.length) return;
                      setState(() => _selectedModelIndex = idx);
                    },
                    items: List.generate(models.length, (i) {
                      final model = models[i];
                      return DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          model.name.isNotEmpty ? model.name : model.modelId,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioSourceBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isProcessing ? null : _showAudioSourceSheet,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add_circle_outline, size: 20),
          label: const Text('选择音频来源',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.multitrack_audio_outlined,
              size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            '暂未选择音频文件',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持 wav、mp3、m4a、ogg 等常见音频格式',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioInfo(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.audiotrack, size: 48, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                _selectedAudio!.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '格式: ${_selectedAudio!.format.toUpperCase()}  |  大小: ${_formatFileSize(_selectedAudio!.bytes.length)}',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _showAudioSourceSheet,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新选择'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.errorContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorMessage!,
                  style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                ),
                if (_lastRawRequest != null || _lastRawResponse != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      icon: const Icon(Icons.preview, size: 14),
                      label: const Text(
                        '查看详细错误',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _showErrorDetailDialog(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: cs.onErrorContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: cs.onErrorContainer, size: 18),
            onPressed: () => setState(() {
              _errorMessage = null;
              _lastRawRequest = null;
              _lastRawResponse = null;
            }),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.primaryContainer.withValues(alpha: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: cs.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '识别结果已保存',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _transcriptionResult!.length > 200
                      ? '${_transcriptionResult!.substring(0, 200)}...'
                      : _transcriptionResult!,
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: cs.onPrimaryContainer, size: 18),
            onPressed: () => setState(() => _transcriptionResult = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Save-to folder selector (above start button)
            _buildSaveToSelector(cs),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _selectedAudio == null || _isProcessing
                    ? null
                    : _startTranscription,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.transcribe, size: 20),
                label: Text(
                  _isProcessing ? '识别中...' : '开始识别',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  // Save-to Folder Selector
  // ==================================================================

  Widget _buildSaveToSelector(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _pickSaveFolder,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '保存至',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _saveFolder.isEmpty ? '根目录' : _saveFolder,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSaveFolder() async {
    final folders = await TextManifest.getAllFolders();
    if (!mounted) return;
    final result = await FolderPickerDialog.show(
      context,
      currentFolder: _saveFolder,
      availableFolders: folders,
      title: '选择保存文件夹',
    );
    if (result != null && mounted) {
      setState(() => _saveFolder = result);
    }
  }

  // ==================================================================
  // Audio Source Methods
  // ==================================================================

  /// Show a bottom sheet with available audio source options.
  void _showAudioSourceSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '选择音频来源',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.library_music_outlined,
                      color: cs.onPrimaryContainer),
                ),
                title: const Text('应用内录音'),
                subtitle: const Text('从已生成的录音中选择'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _showInAppAudioPicker();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.audio_file_outlined,
                      color: cs.onPrimaryContainer),
                ),
                title: const Text('系统音频文件'),
                subtitle: const Text('从设备文件中选择'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAudioFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick an audio file from the device storage.
  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法读取音频文件')),
          );
        }
        return;
      }

      setState(() {
        _selectedAudio = SelectedAudio(
          bytes: bytes,
          name: file.name,
          format: _detectFormat(file.name),
        );
        _errorMessage = null;
        _transcriptionResult = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择音频文件失败: $e')),
        );
      }
    }
  }

  /// Show a dialog to pick from in-app audio recordings.
  Future<void> _showInAppAudioPicker() async {
    // Load latest records
    await ref.read(audioRecordsProvider.notifier).loadRecords();
    final records = ref.read(audioRecordsProvider);

    if (!mounted) return;

    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可用的应用内录音')),
      );
      return;
    }

    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.library_music_outlined,
                        size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      '选择应用内录音',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.audiotrack,
                            color: cs.onPrimaryContainer, size: 20),
                      ),
                      title: Text(
                        record.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '${record.format.toUpperCase()}  ${_formatFileSize(record.size)}  ${record.duration > 0 ? '${record.duration}秒' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _selectFromInAppAudio(record);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Select an in-app audio record and read its bytes.
  Future<void> _selectFromInAppAudio(AudioRecord record) async {
    try {
      final bytes = await FileManifest.readFile(record.storagePath);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法读取录音文件')),
          );
        }
        return;
      }

      setState(() {
        _selectedAudio = SelectedAudio(
          bytes: bytes,
          name: record.name,
          format: record.format,
        );
        _errorMessage = null;
        _transcriptionResult = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('读取录音失败: $e')),
        );
      }
    }
  }

  void _clearAll() {
    setState(() {
      _selectedAudio = null;
      _errorMessage = null;
      _transcriptionResult = null;
    });
  }

  // ==================================================================
  // ASR Processing
  // ==================================================================

  Future<void> _startTranscription() async {
    if (_selectedAudio == null) return;

    final asrConfig = _resolveAsrConfig(ref);
    if (asrConfig == null) {
      setState(() {
        _errorMessage = '请先在设置中配置语音识别供应商';
      });
      return;
    }

    // Create a background task for tracking
    final timestamp = _currentTimestamp();
    final taskId = ref.read(backgroundTasksProvider.notifier).addTask(
      type: BackgroundTaskType.asr,
      title: 'ASR_$timestamp',
    );

    // Pop back to home page immediately so user can see task progress
    if (mounted) {
      Navigator.pop(context);
    }

    // Use the selected model from dropdown
    final models = _getAsrModels(ref);
    AsrConfig effectiveConfig;
    if (_selectedModelIndex < models.length) {
      final selectedModel = models[_selectedModelIndex];
      effectiveConfig = asrConfig.copyWith(model: selectedModel.modelId);
    } else {
      effectiveConfig = asrConfig;
    }

    // Continue processing in the background
    late final AsrService service;
    try {
      service = AsrService(config: effectiveConfig);
      final result = await service.transcribe(
        audioBytes: _selectedAudio!.bytes,
        audioFormat: _selectedAudio!.format,
      );

      // Save the transcription result as a text file
      await _saveTranscriptionResult(result.text);

      // Mark task as completed
      ref.read(backgroundTasksProvider.notifier).completeTask(taskId);
    } catch (e) {
      // Mark task as failed (widget may be gone, but notifier is independent)
      ref.read(backgroundTasksProvider.notifier).failTask(
        taskId,
        error: 'ASR识别失败: $e',
      );
    }
  }

  String _currentTimestamp() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
  }

  /// Save the transcription result as a text record, named by current datetime.
  Future<void> _saveTranscriptionResult(String text) async {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final title = 'ASR_$timestamp';

    final bytes = Uint8List.fromList(utf8.encode(text));
    final hash = computeTextHash(bytes);
    final storageFileName = '$hash.txt';

    await TextManifest.writeText(storageFileName, text);
    await TextManifest.addRecord(TextRecord(
      name: title,
      hash: hash,
      format: 'txt',
      createdAt: now,
      size: bytes.length,
      folder: _saveFolder,
      textLength: text.length,
    ));
  }

  // ==================================================================
  // Error Detail Dialog
  // ==================================================================

  /// Show a dialog with full request/response details for the last error.
  void _showErrorDetailDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Text(
                      '错误详情',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Body with scrollable content
              Flexible(
                child: _lastRawRequest != null || _lastRawResponse != null
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        shrinkWrap: true,
                        children: [
                          if (_lastRawRequest != null) ...[
                            _buildJsonBlock('请求 (Request)', _lastRawRequest, isDark),
                            const SizedBox(height: 12),
                          ],
                          if (_lastRawResponse != null)
                            _buildJsonBlock('响应 (Response)', _lastRawResponse, isDark),
                        ],
                      )
                    : const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            '无详细数据',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Render a JSON data block with monospace text.
  Widget _buildJsonBlock(String label, dynamic data, bool isDark) {
    final encoder = const JsonEncoder.withIndent('  ');
    final sanitized = DataSanitizer.sanitizeForDisplay(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            encoder.convert(sanitized),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  // ==================================================================
  // Helpers
  // ==================================================================

  String _detectFormat(String? name) {
    if (name == null) return 'wav';
    final lower = name.toLowerCase();
    if (lower.endsWith('.mp3')) return 'mp3';
    if (lower.endsWith('.m4a')) return 'm4a';
    if (lower.endsWith('.ogg')) return 'ogg';
    if (lower.endsWith('.flac')) return 'flac';
    if (lower.endsWith('.aac')) return 'aac';
    if (lower.endsWith('.opus')) return 'opus';
    if (lower.endsWith('.wma')) return 'wma';
    if (lower.endsWith('.webm')) return 'webm';
    return 'wav';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
