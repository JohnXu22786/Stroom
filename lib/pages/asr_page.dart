import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/provider_config.dart';
import '../providers/tts_state_provider.dart';
import '../providers/background_task_provider.dart';
import '../providers/text_provider.dart';
import '../services/asr_service.dart';
import '../utils/data_sanitizer.dart';
import '../utils/file_manifest.dart';
import '../utils/text_manifest.dart';
import '../widgets/app_media_picker_dialog.dart';
import '../widgets/folder_picker_dialog.dart';
import 'ocr/ocr_shared.dart';

// ============================================================================
// Provider: Get the first configured ASR config from provider entries
// ============================================================================

/// Reads the first valid ASR provider config from the provider entries.
/// Iterates through all configs in an entry, not just the first one.
/// Returns null if none is configured.
AsrConfig? _resolveAsrConfig(WidgetRef ref) {
  final state = ref.read(providerEntriesProvider);
  for (final entry in state.entries) {
    if (entry.type == 'asr') {
      for (final config in entry.configs) {
        if (config.host.isNotEmpty && config.key.isNotEmpty) {
          final model = config.models.isNotEmpty
              ? config.models.first.modelId
              : 'whisper-1';
          return AsrConfig(host: config.host, apiKey: config.key, model: model);
        }
      }
    }
  }
  return null;
}

/// Collect all available model names from the first valid ASR provider config.
/// Iterates through all configs in the entry to find the first valid one.
List<ModelConfig> _getAsrModels(WidgetRef ref) {
  final state = ref.read(providerEntriesProvider);
  for (final entry in state.entries) {
    if (entry.type == 'asr') {
      for (final config in entry.configs) {
        if (config.host.isNotEmpty && config.key.isNotEmpty) {
          return config.models;
        }
      }
    }
  }
  return [];
}

/// Get the provider name from the first valid ASR provider config.
/// Iterates through all configs in the entry to find the first valid one.
String _getAsrProviderName(WidgetRef ref) {
  final state = ref.read(providerEntriesProvider);
  for (final entry in state.entries) {
    if (entry.type == 'asr') {
      for (final config in entry.configs) {
        if (config.host.isNotEmpty && config.key.isNotEmpty) {
          return config.providerName;
        }
      }
    }
  }
  return '';
}

/// Build display text for a model: "ModelName | ProviderName"
/// Falls back to model name only if provider name is empty.
String _buildAsrModelDisplayText(ModelConfig model, String providerName) {
  final modelName = model.name.isNotEmpty ? model.name : model.modelId;
  if (providerName.isNotEmpty) {
    return '$modelName | $providerName';
  }
  return modelName;
}

// ============================================================================
// Selected Audio Model
// ============================================================================

/// Represents a single selected audio file for ASR transcription.
class SelectedAudio {
  final Uint8List bytes;
  final String name;
  final String format;

  SelectedAudio({required this.bytes, required this.name, this.format = 'wav'});
}

// ============================================================================
// ASR Page
// ============================================================================

/// Main ASR page — allows selecting audio files from device storage or
/// in-app recordings (multi-select), then performing speech-to-text
/// transcription and saving results to text storage.
class AsrPage extends ConsumerStatefulWidget {
  const AsrPage({super.key, this.retryData});

  /// Retry data to pre-populate the form (audio files, model, etc.).
  final Map<String, dynamic>? retryData;

  @override
  ConsumerState<AsrPage> createState() => _AsrPageState();
}

class _AsrPageState extends ConsumerState<AsrPage> {
  final List<SelectedAudio> _selectedAudios = [];
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
  void initState() {
    super.initState();
    _applyRetryData();
  }

  /// Pre-populate form from retry data if available.
  void _applyRetryData() {
    final data = widget.retryData;
    if (data == null) return;

    final audiosData = data['audios'] as List<dynamic>?;
    if (audiosData != null) {
      for (final audioData in audiosData) {
        if (audioData is Map) {
          final bytesStr = audioData['bytes'] as String?;
          if (bytesStr != null) {
            try {
              final bytes = base64Decode(bytesStr);
              _selectedAudios.add(SelectedAudio(
                bytes: bytes,
                name: audioData['name'] as String? ?? 'audio',
                format: audioData['format'] as String? ?? 'wav',
              ));
            } catch (e) {
              debugPrint('Failed to decode retry audio: $e');
            }
          }
        }
      }
    }

    if (data['modelIndex'] is int) {
      _selectedModelIndex = data['modelIndex'] as int;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('音频转写'),
        centerTitle: true,
        actions: [
          if (_selectedAudios.isNotEmpty && !_isProcessing)
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
            child: _selectedAudios.isEmpty
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
    final providerName = _getAsrProviderName(ref);
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
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
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
                      final displayText =
                          _buildAsrModelDisplayText(model, providerName);
                      return DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          displayText,
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
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _showAudioSourceSheet,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.mic, size: 20),
                label: const Text(
                  '录音选择',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _showAudioSourceSheet,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.audio_file_outlined, size: 20),
                label: const Text(
                  '音频文件',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.multitrack_audio_outlined,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
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
      child: ListView(
        children: [
          Card(
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
                    '已选择 ${_selectedAudios.length} 个音频文件',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
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
          const SizedBox(height: 8),
          ...List.generate(_selectedAudios.length, (index) {
            final audio = _selectedAudios[index];
            return Card(
              key: ValueKey('audio_item_${audio.hashCode}_$index'),
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.audiotrack,
                        size: 18,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${audio.name}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${audio.format.toUpperCase()}  |  ${_formatFileSize(audio.bytes.length)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: cs.error),
                      onPressed:
                          _isProcessing ? null : () => _removeAudio(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _removeAudio(int index) {
    if (index < 0 || index >= _selectedAudios.length) return;
    setState(() {
      _selectedAudios.removeAt(index);
      _errorMessage = null;
      _transcriptionResult = null;
    });
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
            child: Icon(
              Icons.error_outline,
              color: cs.onErrorContainer,
              size: 18,
            ),
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
                  style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12),
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
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Save-to folder selector (above start button)
            _buildSaveToSelector(cs),
            const SizedBox(height: 4),
            if (_selectedAudios.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '已选 ${_selectedAudios.length} 个音频',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _selectedAudios.isEmpty || _isProcessing
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

  // ==================================================================
  // Save-to Folder Selector
  // ==================================================================

  Widget _buildSaveToSelector(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
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
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
              Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
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

  /// Show a bottom sheet with available audio source options as ChoiceCards.
  void _showAudioSourceSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '选择音频来源',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  ChoiceCard(
                    icon: Icons.library_music_outlined,
                    title: '应用内录音',
                    subtitle: '从已生成的录音中选择',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showInAppAudioPicker();
                    },
                  ),
                  const SizedBox(height: 8),
                  ChoiceCard(
                    icon: Icons.audio_file_outlined,
                    title: '系统音频文件',
                    subtitle: '从设备文件中选择',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAudioFile();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick audio files from the device storage (supports multi-select).
  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final newAudios = <SelectedAudio>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        newAudios.add(
          SelectedAudio(
            bytes: bytes,
            name: file.name,
            format: _detectFormat(file.name),
          ),
        );
      }

      if (newAudios.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('无法读取音频文件')));
        }
        return;
      }

      setState(() {
        _selectedAudios.addAll(newAudios);
        _errorMessage = null;
        _transcriptionResult = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择音频文件失败: $e')));
      }
    }
  }

  /// Show a dialog to pick from in-app audio recordings using the unified
  /// media picker (matching the OCR image picker pattern).
  Future<void> _showInAppAudioPicker() async {
    final result = await showMediaPickerDialog<AudioRecord>(
      context,
      MediaPickerConfig<AudioRecord>(
        title: '选择应用内录音',
        emptyIcon: Icons.multitrack_audio_outlined,
        emptyText: '暂无录音',
        fileIcon: Icons.audiotrack,
        fileIconColor: Colors.green,
        multiSelect: true,
        loadRecords: () async {
          await ref.read(audioRecordsProvider.notifier).loadRecords();
          return ref.read(audioRecordsProvider);
        },
        loadFolders: () => FileManifest.getAllFolders(),
        readFile: (record) => FileManifest.readFile(record.storagePath),
        displayName: (record) => record.name,
        subtitleBuilder: (record) => Row(
          children: [
            Text(
              record.format.toUpperCase(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 6),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey[400]!,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatFileSize(record.size),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (record.duration > 0) ...[
              const SizedBox(width: 6),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey[400]!,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${record.duration}秒',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;

    // Look up records to get correct formats
    final records = ref.read(audioRecordsProvider);
    final newAudios = <SelectedAudio>[];
    for (final entry in result) {
      String format = 'wav';
      for (final r in records) {
        if (r.name == entry.key) {
          format = r.format;
          break;
        }
      }
      newAudios.add(
        SelectedAudio(bytes: entry.value, name: entry.key, format: format),
      );
    }

    setState(() {
      _selectedAudios.addAll(newAudios);
      _errorMessage = null;
      _transcriptionResult = null;
    });
  }

  void _clearAll() {
    setState(() {
      _selectedAudios.clear();
      _errorMessage = null;
      _transcriptionResult = null;
    });
  }

  // ==================================================================
  // ASR Processing
  // ==================================================================

  Future<void> _startTranscription() async {
    if (_selectedAudios.isEmpty) return;

    final asrConfig = _resolveAsrConfig(ref);
    if (asrConfig == null) {
      setState(() {
        _errorMessage = '请先在设置中配置音频转写供应商';
      });
      return;
    }

    // Capture notifier references BEFORE Navigator.pop — after the widget is
    // disposed, ConsumerState.ref becomes null and ref.read() would throw.
    final bgNotifier = ref.read(backgroundTasksProvider.notifier);
    final textNotifier = ref.read(textRecordsProvider.notifier);

    // Use the selected model from dropdown
    final models = _getAsrModels(ref);
    AsrConfig effectiveConfig;
    if (_selectedModelIndex < models.length) {
      final selectedModel = models[_selectedModelIndex];
      effectiveConfig = asrConfig.copyWith(model: selectedModel.modelId);
    } else {
      effectiveConfig = asrConfig;
    }

    // Capture the list before pop
    final audiosToProcess = List<SelectedAudio>.from(_selectedAudios);

    // Pop back to home page immediately so user can see task progress
    if (mounted) {
      Navigator.pop(context);
    }

    // Create one task per audio file, each with its own 5-step chain
    for (final audio in audiosToProcess) {
      final title = 'ASR_${audio.name}';

      // Build retry data: encode only the current audio bytes as base64
      // so they can be restored on retry (each task handles one file)
      final retryData = <String, dynamic>{
        'type': 'asr',
        'audios': [
          <String, dynamic>{
            'bytes': base64Encode(audio.bytes),
            'name': audio.name,
            'format': audio.format,
          },
        ],
        'modelIndex': _selectedModelIndex,
      };

      final taskId = bgNotifier.addTask(
        type: BackgroundTaskType.asr,
        title: title,
        retryData: retryData,
      );

      final service = AsrService(config: effectiveConfig);

      try {
        // Step 0: 连接服务器
        bgNotifier.updateStep(taskId, 0, running: true);
        bgNotifier.updateStep(taskId, 0, completed: true);

        // Step 1: 上传音频
        bgNotifier.updateStep(taskId, 1, running: true);

        final result = await service.transcribe(
          audioBytes: audio.bytes,
          audioFormat: audio.format,
        );

        // Step 1 complete
        bgNotifier.updateStep(taskId, 1, completed: true);

        // Step 2: 转写中 (server processing response received)
        bgNotifier.setResult(taskId, result.text);
        bgNotifier.updateStep(taskId, 2, completed: true);

        // Step 3: 接收结果
        bgNotifier.updateStep(taskId, 3, running: true);

        // Step 4: 保存文件
        bgNotifier.updateStep(taskId, 3, completed: true);
        bgNotifier.updateStep(taskId, 4, running: true);

        await _saveTranscriptionResult(result.text, title: title);

        bgNotifier.updateStep(taskId, 4, completed: true);
        bgNotifier.completeTask(taskId);

        // Refresh text records
        unawaited(textNotifier.loadRecords());
      } catch (e) {
        // Capture raw request/response diagnostics from AsrService
        final rawRequest = <String, dynamic>{
          if (service.lastRequestUrl != null) 'url': service.lastRequestUrl,
          if (service.lastRequestHeaders != null)
            'headers': service.lastRequestHeaders,
          if (service.lastRequestBody != null) 'body': service.lastRequestBody,
        };
        final rawResponse = <String, dynamic>{
          if (service.lastResponseStatusCode != null)
            'statusCode': service.lastResponseStatusCode,
          if (service.lastResponseHeaders != null)
            'headers': service.lastResponseHeaders,
          if (service.lastResponseData != null)
            'data': service.lastResponseData,
        };
        bgNotifier.failTask(taskId,
            error: '音频转写失败: $e',
            rawRequest: rawRequest,
            rawResponse: rawResponse);
      }
    }
  }

  /// Save the transcription result as a text record, named by the task title.
  Future<void> _saveTranscriptionResult(String text, {String? title}) async {
    final now = DateTime.now();

    final bytes = Uint8List.fromList(utf8.encode(text));
    final hash = computeTextHash(bytes);
    final storageFileName = '$hash.txt';

    await TextManifest.writeText(storageFileName, text);
    await TextManifest.addRecord(
      TextRecord(
        name: title ??
            'ASR_${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}',
        hash: hash,
        format: 'txt',
        createdAt: now,
        size: bytes.length,
        folder: _saveFolder,
        textLength: text.length,
      ),
    );
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                            _buildJsonBlock(
                              '请求 (Request)',
                              _lastRawRequest,
                              isDark,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_lastRawResponse != null)
                            _buildJsonBlock(
                              '响应 (Response)',
                              _lastRawResponse,
                              isDark,
                            ),
                        ],
                      )
                    : const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            '无详细数据',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
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
