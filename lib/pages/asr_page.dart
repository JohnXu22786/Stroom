import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/provider_config.dart';
import '../services/asr_service.dart';
import '../utils/data_sanitizer.dart';
import '../utils/text_manifest.dart';

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

  Widget _buildAudioSourceBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickAudioFile,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.audio_file_outlined, size: 20),
                label: const Text('选择音频文件',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                  onPressed: _isProcessing ? null : _pickAudioFile,
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
        child: SizedBox(
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
      ),
    );
  }

  // ==================================================================
  // Audio Source Methods
  // ==================================================================

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

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _transcriptionResult = null;
    });

    late final AsrService service;
    try {
      service = AsrService(config: asrConfig);
      final result = await service.transcribe(
        audioBytes: _selectedAudio!.bytes,
        audioFormat: _selectedAudio!.format,
      );

      // Save the transcription result as a text file
      await _saveTranscriptionResult(result.text);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _transcriptionResult = result.text;
          _selectedAudio = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('识别完成，已保存到文本页'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Capture full request/response diagnostics from the service
        Map<String, dynamic>? rawReq;
        Map<String, dynamic>? rawResp;
        if (service.lastRequestBody != null ||
            service.lastRequestHeaders != null ||
            service.lastRequestUrl != null) {
          rawReq = {};
          if (service.lastRequestUrl != null) {
            rawReq['url'] = service.lastRequestUrl;
          }
          if (service.lastRequestHeaders != null) {
            rawReq['headers'] = service.lastRequestHeaders;
          }
          if (service.lastRequestBody != null) {
            rawReq['body'] = service.lastRequestBody;
          }
        }
        if (service.lastResponseData != null ||
            service.lastResponseStatusCode != null ||
            service.lastResponseHeaders != null) {
          rawResp = {};
          if (service.lastResponseStatusCode != null) {
            rawResp['statusCode'] = service.lastResponseStatusCode;
          }
          if (service.lastResponseHeaders != null) {
            rawResp['headers'] = service.lastResponseHeaders;
          }
          if (service.lastResponseData != null) {
            rawResp['data'] = service.lastResponseData;
          }
        } else {
          rawResp = {'error': e.toString()};
        }

        setState(() {
          _isProcessing = false;
          _errorMessage = '识别失败: $e';
          _lastRawRequest = rawReq;
          _lastRawResponse = rawResp;
        });
      }
    }
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
      folder: '',
      textLength: text.length,
    ));
  }

  // ==================================================================
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
                  color: Colors.red.withOpacity(0.1),
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
