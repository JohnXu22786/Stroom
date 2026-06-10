import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/provider_config.dart';
import '../services/ocr_service.dart';
import '../utils/data_sanitizer.dart';
import '../utils/text_manifest.dart';

// ============================================================================
// Provider: Get the first configured OCR config from provider entries
// ============================================================================

/// Reads the first OCR provider config from the provider entries.
/// Returns null if none is configured.
OcrConfig? _resolveOcrConfig(WidgetRef ref) {
  final state = ref.read(providerEntriesProvider);
  for (final entry in state.entries) {
    if (entry.type == 'ocr' && entry.configs.isNotEmpty) {
      final config = entry.configs.first;
      if (config.host.isNotEmpty && config.key.isNotEmpty) {
        final model = config.models.isNotEmpty
            ? config.models.first.modelId
            : 'gpt-4o';
        return OcrConfig(
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
// OCR Page
// ============================================================================

/// Main OCR page — allows taking photos or selecting from gallery,
/// then performing OCR and saving results to text storage.
class OcrPage extends ConsumerStatefulWidget {
  const OcrPage({super.key});

  @override
  ConsumerState<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends ConsumerState<OcrPage> {
  final List<SelectedImage> _selectedImages = [];
  bool _isProcessing = false;
  String? _errorMessage;

  /// Captured raw request data from the last failed OCR call.
  Map<String, dynamic>? _lastRawRequest;

  /// Captured raw response data from the last failed OCR call.
  Map<String, dynamic>? _lastRawResponse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文字识别'),
        centerTitle: true,
        actions: [
          if (_selectedImages.isNotEmpty && !_isProcessing)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('清空'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Photo source buttons
          _buildPhotoSourceBar(cs),

          // Image preview area
          Expanded(
            child: _selectedImages.isEmpty
                ? _buildEmptyState(cs)
                : _buildImageGrid(cs),
          ),

          // Error message
          if (_errorMessage != null) _buildErrorBanner(cs),

          // Processing indicator or action button
          _buildBottomBar(cs),
        ],
      ),
    );
  }

  Widget _buildPhotoSourceBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _takePhoto,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text('拍照识别',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickFromGallery,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('相册选择',
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
          Icon(Icons.text_snippet_outlined,
              size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            '暂无选中图片',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持拍照或从相册批量选择图片进行识别',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          final image = _selectedImages[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: image.provider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: cs.surfaceContainerHigh,
                    child:
                        const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              // Remove button
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
              // Image index badge
              if (_selectedImages.length > 1)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          );
        },
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
            if (_selectedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '已选 ${_selectedImages.length} 张图片',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed:
                    _selectedImages.isEmpty || _isProcessing ? null : _startOcr,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.text_snippet, size: 20),
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
  // Photo Source Methods
  // ==================================================================

  /// Take a photo using the system camera.
  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _selectedImages.add(SelectedImage(
          bytes: bytes,
          provider: _createProvider(bytes),
          format: _detectFormat(file.path),
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  /// Pick images from the system gallery (supports batch selection).
  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (files.isEmpty) return;

      final newImages = <SelectedImage>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        newImages.add(SelectedImage(
          bytes: bytes,
          provider: _createProvider(bytes),
          format: _detectFormat(file.path),
        ));
      }

      setState(() {
        _selectedImages.addAll(newImages);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _clearAll() {
    setState(() {
      _selectedImages.clear();
      _errorMessage = null;
    });
  }

  // ==================================================================
  // OCR Processing
  // ==================================================================

  Future<void> _startOcr() async {
    if (_selectedImages.isEmpty) return;

    final ocrConfig = _resolveOcrConfig(ref);
    if (ocrConfig == null) {
      setState(() {
        _errorMessage = '请先在设置中配置 OCR 供应商';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    late final OcrService service;
    try {
      service = OcrService(config: ocrConfig);
      OcrResult result;

      if (_selectedImages.length == 1) {
        final img = _selectedImages.first;
        result = await service.recognize(
          imageBytes: img.bytes,
          imageFormat: img.format,
        );
      } else {
        final batchInput = _selectedImages
            .map((img) => (img.bytes, img.format))
            .toList();
        result = await service.recognizeBatch(
          imageBytesList: batchInput,
        );
      }

      // Save the OCR result as a text file using TextManifest
      await _saveOcrResult(result.text);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _selectedImages.clear();
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

  /// Save the OCR result as a text record, named by current datetime.
  Future<void> _saveOcrResult(String text) async {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final title = 'OCR_$timestamp';

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
  // Error Detail Dialog
  // ==================================================================

  /// Show a dialog with full request/response details for the last error.
  /// Mirrors the chat page's _showErrorDetailDialog pattern.
  void _showErrorDetailDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

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

  String _detectFormat(String? path) {
    if (path == null) return 'jpeg';
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.gif')) return 'gif';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }

  ImageProvider _createProvider(Uint8List bytes) {
    return MemoryImage(bytes);
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ============================================================================
// SelectedImage Model
// ============================================================================

/// Represents a single selected image for OCR processing.
class SelectedImage {
  final Uint8List bytes;
  final ImageProvider provider;
  final String format;

  SelectedImage({
    required this.bytes,
    required this.provider,
    this.format = 'jpeg',
  });
}
