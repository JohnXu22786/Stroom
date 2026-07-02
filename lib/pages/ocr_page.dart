import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:extended_image/extended_image.dart';

import '../providers/provider_config.dart';
import '../providers/background_task_provider.dart';
import '../providers/text_provider.dart';
import '../services/ocr_service.dart';
import '../services/storage_service.dart';
import '../utils/data_sanitizer.dart';
import '../utils/image_manifest.dart';
import '../utils/text_manifest.dart';
import '../widgets/folder_picker_dialog.dart';
import 'chat/composer/chat_album_picker_dialog.dart';
import 'ocr/ocr_shared.dart';
export 'ocr/ocr_shared.dart';

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
        final model =
            config.models.isNotEmpty ? config.models.first.modelId : 'gpt-4o';
        return OcrConfig(host: config.host, apiKey: config.key, model: model);
      }
    }
  }
  return null;
}

/// Collect all available model names from the first OCR provider config.
List<ModelConfig> _getOcrModels(WidgetRef ref) {
  final state = ref.read(providerEntriesProvider);
  for (final entry in state.entries) {
    if (entry.type == 'ocr' && entry.configs.isNotEmpty) {
      final config = entry.configs.first;
      if (config.host.isNotEmpty && config.key.isNotEmpty) {
        return config.models;
      }
    }
  }
  return [];
}

// ============================================================================
// OCR Page
// ============================================================================

/// Main OCR page — allows taking photos or selecting from gallery,
/// then performing OCR and saving results to text storage.
class OcrPage extends ConsumerStatefulWidget {
  const OcrPage({super.key, this.testImages});

  /// Test-only: pre-populate images for widget testing.
  @visibleForTesting
  final List<SelectedImage>? testImages;

  @override
  ConsumerState<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends ConsumerState<OcrPage> {
  final List<SelectedImage> _selectedImages = [];
  bool _isProcessing = false;
  String? _errorMessage;
  int _selectedModelIndex = 0;

  /// Whether reorder mode is active
  bool _reorderMode = false;

  /// Index of the image currently being long-press-dragged in grid, or null.
  int? _dragIndex;

  /// Index over which the dragged image is hovering, or null.
  int? _dragTargetIndex;

  /// Captured raw request data from the last failed OCR call.
  Map<String, dynamic>? _lastRawRequest;

  /// Captured raw response data from the last failed OCR call.
  Map<String, dynamic>? _lastRawResponse;

  /// Save-to folder selection
  String _saveFolder = '';

  @override
  void initState() {
    super.initState();
    if (widget.testImages != null) {
      _selectedImages.addAll(widget.testImages!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文字识别'),
        centerTitle: true,
        actions: [
          if (_selectedImages.length > 1 && !_isProcessing)
            TextButton.icon(
              key: const Key('ocr_sort_btn'),
              onPressed: () {
                setState(() {
                  _reorderMode = !_reorderMode;
                  // Reset any stale drag state when toggling modes
                  _dragIndex = null;
                  _dragTargetIndex = null;
                });
              },
              icon: Icon(
                _reorderMode ? Icons.check : Icons.swap_vert,
                size: 18,
              ),
              label: Text(_reorderMode ? '完成' : '排序'),
            ),
          if (_selectedImages.isNotEmpty && !_isProcessing && !_reorderMode)
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

  // ==================================================================
  // Model Selector — nicely styled, pill-shaped dropdown
  // ==================================================================

  Widget _buildModelSelector(ColorScheme cs) {
    final models = _getOcrModels(ref);
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

  Widget _buildPhotoSourceBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _showCameraChoicePanel,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text(
                  '拍照识别',
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
                onPressed: _isProcessing ? null : _showAlbumChoicePanel,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text(
                  '相册选择',
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
            Icons.text_snippet_outlined,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
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
    if (_reorderMode) {
      return _buildReorderableList(cs);
    }

    final isDragging = _dragIndex != null;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 8;
          const int crossAxisCount = 3;
          final double totalSpacing = spacing * (crossAxisCount - 1);
          final double itemSize =
              (constraints.maxWidth - totalSpacing) / crossAxisCount;
          final int itemCount = _selectedImages.length;
          final int rowCount = itemCount == 0
              ? 0
              : (itemCount + crossAxisCount - 1) ~/ crossAxisCount;
          final double totalHeight =
              rowCount > 0 ? rowCount * itemSize + (rowCount - 1) * spacing : 0;

          return SingleChildScrollView(
            child: SizedBox(
              height: totalHeight,
              child: Stack(
                children: List.generate(itemCount, (index) {
                  final image = _selectedImages[index];
                  final col = index % crossAxisCount;
                  final row = index ~/ crossAxisCount;
                  final left = col * (itemSize + spacing);
                  final top = row * (itemSize + spacing);

                  final isThisDragging = _dragIndex == index;
                  final isDimmed = isDragging && !isThisDragging;
                  final isHoverTarget =
                      _dragTargetIndex == index && !isThisDragging;

                  // Use identity-based key (image.hashCode) so AnimatedPositioned
                  // can track each item across reorders and animate position changes
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    key: ValueKey('grid_item_pos_${identityHashCode(image)}'),
                    left: left,
                    top: top,
                    width: itemSize,
                    height: itemSize,
                    child: DragTarget<int>(
                      key: ValueKey('drag_target_$index'),
                      onWillAcceptWithDetails: (details) {
                        if (details.data != index) {
                          setState(() => _dragTargetIndex = index);
                          return true;
                        }
                        return false;
                      },
                      onLeave: (_) {
                        setState(() {
                          if (_dragTargetIndex == index) {
                            _dragTargetIndex = null;
                          }
                        });
                      },
                      onAcceptWithDetails: (details) {
                        _onGridReorder(details.data, index);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isCandidate = candidateData.isNotEmpty;
                        return LongPressDraggable<int>(
                          data: index,
                          delay: const Duration(milliseconds: 300),
                          onDragStarted: () {
                            setState(() => _dragIndex = index);
                          },
                          onDraggableCanceled: (_, __) {
                            setState(() {
                              _dragIndex = null;
                              _dragTargetIndex = null;
                            });
                          },
                          onDragEnd: (_) {
                            setState(() {
                              _dragIndex = null;
                              _dragTargetIndex = null;
                            });
                          },
                          ignoringFeedbackSemantics: false,
                          feedback: SizedBox(
                            // Match grid item dimensions
                            width: itemSize,
                            height: itemSize,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ExtendedImage.memory(
                                      image.bytes,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      loadStateChanged: (state) {
                                        if (state.extendedImageLoadState ==
                                            LoadState.failed) {
                                          return Container(
                                            color: cs.surfaceContainerHigh,
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_selectedImages.length > 1)
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.primary,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: _buildDimmedPlaceholder(
                            image,
                            index,
                            cs,
                            isCandidate || isHoverTarget,
                          ),
                          child: ImageGridItem(
                            key: ValueKey('ocr_grid_item_$index'),
                            image: image,
                            index: index,
                            totalCount: _selectedImages.length,
                            isDimmed: isDimmed,
                            isHoverTarget: isCandidate || isHoverTarget,
                            onTap: () => _previewImage(index),
                            onRemove: () => _removeImage(index),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Placeholder shown at original position while item is being dragged.
  Widget _buildDimmedPlaceholder(
    SelectedImage image,
    int index,
    ColorScheme cs,
    bool isTarget,
  ) {
    return Opacity(
      opacity: 0.3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isTarget ? Border.all(color: cs.primary, width: 2) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ExtendedImage.memory(
            image.bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadStateChanged: (state) {
              if (state.extendedImageLoadState == LoadState.failed) {
                return Container(
                  color: cs.surfaceContainerHigh,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  void _onGridReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex == newIndex) {
        _dragIndex = null;
        _dragTargetIndex = null;
        return;
      }
      final item = _selectedImages.removeAt(oldIndex);
      // newIndex is the visual grid position from DragTarget;
      // after removeAt, the list shrinks, so insert directly at newIndex.
      _selectedImages.insert(newIndex, item);
      _dragIndex = null;
      _dragTargetIndex = null;
    });
  }

  Widget _buildReorderableList(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.primaryContainer.withValues(alpha: 0.5)),
        ),
        child: ReorderableListView.builder(
          padding: const EdgeInsets.all(8),
          buildDefaultDragHandles: false,
          itemCount: _selectedImages.length,
          onReorder: _onReorder,
          proxyDecorator: (child, index, animation) {
            return Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: cs.surface,
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final image = _selectedImages[index];
            return Padding(
              key: ValueKey('reorder_${image.hashCode}_$index'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      width: 36,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      child: Icon(
                        Icons.drag_handle,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: ExtendedImage.memory(
                        image.bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState ==
                              LoadState.failed) {
                            return Container(
                              color: cs.surfaceContainerHigh,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 20,
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '图片 ${index + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: cs.error),
                    onPressed: () => _removeImage(index),
                  ),
                ],
              ),
            );
          },
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
            if (_selectedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '已选 ${_selectedImages.length} 张图片',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
  // Photo Source Methods
  // ==================================================================

  /// Open system camera directly.
  void _showCameraChoicePanel() {
    _takePhotoWithSystemCamera();
  }

  /// Show album choice panel (system album / app album)
  void _showAlbumChoicePanel() {
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
                '选择图片来源',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  ChoiceCard(
                    icon: Icons.collections_bookmark,
                    title: '从应用相册选择',
                    subtitle: '从应用内已保存的图片中选择',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickFromAppAlbum();
                    },
                  ),
                  const SizedBox(height: 8),
                  ChoiceCard(
                    icon: Icons.photo_library,
                    title: '从系统相册选择',
                    subtitle: '从设备系统相册中选择图片',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickFromSystemGallery();
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

  /// Take a photo using the system camera.
  Future<void> _takePhotoWithSystemCamera() async {
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
        _selectedImages.add(
          SelectedImage(
            bytes: bytes,
            format: _detectFormat(file.path),
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('拍照失败: $e')));
      }
    }
  }

  /// Pick images from the system gallery (supports batch selection).
  Future<void> _pickFromSystemGallery() async {
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
        newImages.add(
          SelectedImage(
            bytes: bytes,
            format: _detectFormat(file.path),
          ),
        );
      }

      setState(() {
        _selectedImages.addAll(newImages);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    }
  }

  /// Pick images from the app's album.
  Future<void> _pickFromAppAlbum() async {
    try {
      final result = await showAppAlbumPickerDialog(context);
      if (result == null || result.isEmpty) return;
      for (final entry in result) {
        await _handleSelectedImage(entry.key, entry.value);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已加载 ${result.length} 张图片'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    }
  }

  /// Handle a selected image from the album picker.
  Future<void> _handleSelectedImage(String fileName, Uint8List data) async {
    try {
      final format = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'png';
      setState(() {
        _selectedImages.add(
          SelectedImage(
            bytes: data,
            format: format,
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('处理图片失败: $e')));
      }
    }
  }

  /// Select an in-app image record and read its bytes.
  Future<void> _selectFromAppAlbum(ImageRecord record) async {
    try {
      final bytes = await ImageManifest.readFile(record.storagePath);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('无法读取图片文件')));
        }
        return;
      }

      setState(() {
        _selectedImages.add(
          SelectedImage(
            bytes: bytes,
            format: record.format,
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('读取图片失败: $e')));
      }
    }
  }

  // ==================================================================
  // Image Reorder & Preview
  // ==================================================================

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  Future<void> _previewImage(int index) async {
    if (index < 0 || index >= _selectedImages.length) return;
    final image = _selectedImages[index];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: GestureDetector(
                key: const Key('preview_tap_to_close'),
                onTap: () => Navigator.pop(ctx),
                child: ExtendedImage.memory(
                  image.bytes,
                  fit: BoxFit.contain,
                  mode: ExtendedImageMode.gesture,
                  initGestureConfigHandler: (_) => GestureConfig(
                    minScale: 0.5,
                    maxScale: 4.0,
                    animationMinScale: 0.5,
                    animationMaxScale: 4.0,
                    initialScale: 1.0,
                    cacheGesture: false,
                  ),
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.failed) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image,
                                size: 48, color: Colors.white54),
                            SizedBox(height: 8),
                            Text('无法加载图片',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 8,
              left: 8,
              child: IconButton(
                key: const Key('preview_close_btn'),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            if (_selectedImages.length > 1)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Text(
                  '${index + 1} / ${_selectedImages.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
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

    // Capture notifier references BEFORE Navigator.pop — after the widget is
    // disposed, ConsumerState.ref becomes null and ref.read() would throw.
    final bgNotifier = ref.read(backgroundTasksProvider.notifier);
    final textNotifier = ref.read(textRecordsProvider.notifier);

    // Resolve model BEFORE pop — ref is still valid here
    bool useCustomModel;
    OcrConfig effectiveConfig;
    final models = _getOcrModels(ref);
    if (_selectedModelIndex < models.length) {
      final selectedModel = models[_selectedModelIndex];
      effectiveConfig = ocrConfig.copyWith(model: selectedModel.modelId);
      useCustomModel = true;
    } else {
      effectiveConfig = ocrConfig;
      useCustomModel = false;
    }

    // Create a background task for tracking
    final timestamp = _currentTimestamp();
    final title = 'OCR_$timestamp';
    final taskId =
        bgNotifier.addTask(type: BackgroundTaskType.ocr, title: title);

    // Pop back to home page immediately so user can see task progress
    if (mounted) {
      Navigator.pop(context);
    }

    try {
      await _performOcr(effectiveConfig, taskId, bgNotifier, textNotifier,
          title: title);
    } catch (e) {
      // If an unexpected error occurs before _performOcr's own catch,
      // mark the task as failed so it doesn't stay in limbo.
      bgNotifier.failTask(taskId, error: 'OCR启动失败: $e');
    }
  }

  Future<void> _performOcr(
    OcrConfig ocrConfig,
    String taskId,
    BackgroundTaskNotifier bgNotifier,
    TextRecordsNotifier textNotifier, {
    String? title,
  }) async {
    OcrService? service;
    try {
      if (mounted) {
        setState(() {
          _isProcessing = true;
          _errorMessage = null;
        });
      }

      // Step 1: Connecting (default: pending → running)
      bgNotifier.updateStep(taskId, 0, running: true);

      service = OcrService(config: ocrConfig);

      // Step 2: Uploading (step index 1)
      bgNotifier.updateStep(taskId, 0, completed: true);
      bgNotifier.updateStep(taskId, 1, running: true);

      OcrResult result;

      if (_selectedImages.length == 1) {
        final img = _selectedImages.first;
        result = await service.recognize(
          imageBytes: img.bytes,
          imageFormat: img.format,
        );
      } else {
        final batchInput =
            _selectedImages.map((img) => (img.bytes, img.format)).toList();
        result = await service.recognizeBatch(imageBytesList: batchInput);
      }

      // Step 3: Processing complete → Step 4: Receiving result
      bgNotifier.updateStep(taskId, 1, completed: true);
      bgNotifier.updateStep(taskId, 2, completed: true);
      bgNotifier.updateStep(taskId, 3, running: true);

      // Store the OCR result internally
      bgNotifier.setResult(taskId, result.text);

      // Step 5: Saving file — save to file and get the path
      bgNotifier.updateStep(taskId, 3, completed: true);
      bgNotifier.updateStep(taskId, 4, running: true);

      // Capture the actual file path from _saveOcrResult
      final filePath = await _saveOcrResult(result.text, title: title);
      bgNotifier.updateStep(taskId, 4, completed: true);
      bgNotifier.completeTask(taskId, downloadedFilePath: filePath);

      // Refresh text records so the files page shows the new OCR result
      unawaited(textNotifier.loadRecords());
    } catch (e) {
      // Mark the failed step
      final task = bgNotifier.state.where((t) => t.id == taskId).firstOrNull;
      if (task != null) {
        final runningIndex =
            task.steps.indexWhere((s) => s.running);
        if (runningIndex >= 0) {
          bgNotifier.updateStep(taskId, runningIndex,
              failed: true, error: 'OCR识别失败: $e');
        }
        // Mark remaining pending steps as skipped
        for (var i = 0; i < task.steps.length; i++) {
          if (task.steps[i].status == BgStepStatus.pending) {
            bgNotifier.updateStep(taskId, i, skipped: true);
          }
        }
      }
      bgNotifier.failTask(taskId, error: 'OCR识别失败: $e');
    }
  }

  String _currentTimestamp() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
  }

  /// Save the OCR result as a text record, named by the task title.
  /// Returns the file path of the saved text file, or null on failure.
  Future<String?> _saveOcrResult(String text, {String? title}) async {
    final now = DateTime.now();

    final bytes = Uint8List.fromList(utf8.encode(text));
    final hash = computeTextHash(bytes);
    final storageFileName = '$hash.txt';

    // Capture the file path returned by writeText
    final filePath = await TextManifest.writeText(storageFileName, text);
    await TextManifest.addRecord(
      TextRecord(
        name: title ??
            'OCR_${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}',
        hash: hash,
        format: 'txt',
        createdAt: now,
        size: bytes.length,
        folder: _saveFolder,
        textLength: text.length,
      ),
    );
    return filePath;
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

  String _detectFormat(String? path) {
    if (path == null) return 'jpeg';
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.gif')) return 'gif';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
