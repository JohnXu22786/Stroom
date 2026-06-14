import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/provider_config.dart';
import '../providers/background_task_provider.dart';
import '../services/ocr_service.dart';
import '../utils/data_sanitizer.dart';
import '../utils/image_manifest.dart';
import '../utils/text_manifest.dart';
import '../widgets/folder_picker_dialog.dart';

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
                onPressed: _isProcessing ? null : _showAlbumChoicePanel,
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
          final double totalHeight = rowCount > 0
              ? rowCount * itemSize + (rowCount - 1) * spacing
              : 0;

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
                                    Image(
                                      image: image.provider,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: cs.surfaceContainerHigh,
                                        child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey),
                                      ),
                                    ),
                                    if (_selectedImages.length > 1)
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color: cs.primary,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: _buildDimmedPlaceholder(
                            image, index, cs, isCandidate || isHoverTarget),
                          child: _ImageGridItem(
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
      SelectedImage image, int index, ColorScheme cs, bool isTarget) {
    return Opacity(
      opacity: 0.3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isTarget
              ? Border.all(color: cs.primary, width: 2)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image(
            image: image.provider,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: cs.surfaceContainerHigh,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
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
                      child: Icon(Icons.drag_handle,
                          color: cs.onSurfaceVariant, size: 20),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image(
                        image: image.provider,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: cs.surfaceContainerHigh,
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey, size: 20),
                        ),
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
            // Save-to folder selector (above start button)
            _buildSaveToSelector(cs),
            const SizedBox(height: 4),
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
  // Photo Source Methods
  // ==================================================================

  /// Show camera choice panel (app camera / system camera, no save-to, no edit toggle)
  void _showCameraChoicePanel() {
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
                '选择拍照方式',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceCard(
                      icon: Icons.camera_alt,
                      title: '应用相机',
                      subtitle: '使用应用内置相机，支持调整比例和压缩设置',
                      onTap: () {
                        Navigator.pop(ctx);
                        _takePhotoWithAppCamera();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ChoiceCard(
                      icon: Icons.phone_android,
                      title: '系统相机',
                      subtitle: '使用系统默认相机应用',
                      onTap: () {
                        Navigator.pop(ctx);
                        _takePhotoWithSystemCamera();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceCard(
                      icon: Icons.photo_library,
                      title: '从系统相册选择',
                      subtitle: '从设备系统相册中选择图片',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickFromSystemGallery();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ChoiceCard(
                      icon: Icons.collections_bookmark,
                      title: '从应用相册选择',
                      subtitle: '从应用内已保存的图片中选择',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickFromAppAlbum();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Take a photo using the app's built-in camera.
  Future<void> _takePhotoWithAppCamera() async {
    // For now, use system camera as fallback
    await _takePhotoWithSystemCamera();
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

  /// Pick images from the app's album.
  Future<void> _pickFromAppAlbum() async {
    try {
      final records = await ImageManifest.loadRecords();

      if (!mounted) return;

      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无可用的应用内图片')),
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
                      Icon(Icons.collections_bookmark,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        '选择应用内图片',
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
                    itemBuilder: (_, index) {
                      final record = records[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Icon(Icons.image,
                              color: cs.onPrimaryContainer, size: 20),
                        ),
                        title: Text(
                          record.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${record.format.toUpperCase()}  ${_formatFileSize(record.size)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _selectFromAppAlbum(record);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载图片列表失败: $e')),
        );
      }
    }
  }

  /// Select an in-app image record and read its bytes.
  Future<void> _selectFromAppAlbum(ImageRecord record) async {
    try {
      final bytes = await ImageManifest.readFile(record.storagePath);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法读取图片文件')),
          );
        }
        return;
      }

      setState(() {
        _selectedImages.add(SelectedImage(
          bytes: bytes,
          provider: MemoryImage(bytes),
          format: record.format,
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('读取图片失败: $e')),
        );
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
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Image(
                    key: const Key('preview_tap_to_close'),
                    image: image.provider,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
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
                    ),
                  ),
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

    // Create a background task for tracking
    final timestamp = _currentTimestamp();
    final title = 'OCR_$timestamp';
    final taskId = ref.read(backgroundTasksProvider.notifier).addTask(
      type: BackgroundTaskType.ocr,
      title: title,
    );

    // Pop back to home page immediately so user can see task progress
    if (mounted) {
      Navigator.pop(context);
    }

    // Use the selected model from dropdown
    final models = _getOcrModels(ref);
    if (_selectedModelIndex < models.length) {
      final selectedModel = models[_selectedModelIndex];
      final updatedConfig = ocrConfig.copyWith(model: selectedModel.modelId);
      await _performOcr(updatedConfig, taskId, title: title);
    } else {
      await _performOcr(ocrConfig, taskId, title: title);
    }
  }

  Future<void> _performOcr(OcrConfig ocrConfig, String taskId,
      {String? title}) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    OcrService? service;
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
      await _saveOcrResult(result.text, title: title);

      // Mark task as completed (widget may be gone, but notifier is independent)
      ref.read(backgroundTasksProvider.notifier).completeTask(taskId);
    } catch (e) {
      // Mark task as failed (widget may be gone, but notifier is independent)
      ref.read(backgroundTasksProvider.notifier).failTask(
        taskId,
        error: 'OCR识别失败: $e',
      );
    }
  }

  String _currentTimestamp() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
  }

  /// Save the OCR result as a text record, named by the task title.
  Future<void> _saveOcrResult(String text, {String? title}) async {
    final now = DateTime.now();

    final bytes = Uint8List.fromList(utf8.encode(text));
    final hash = computeTextHash(bytes);
    final storageFileName = '$hash.txt';

    await TextManifest.writeText(storageFileName, text);
    await TextManifest.addRecord(TextRecord(
      name: title ?? 'OCR_${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}',
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

// ============================================================================
// ChoiceCard Widget — reusable card with icon, title, subtitle
// ============================================================================

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: cs.shadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ImageGridItem Widget — individual image in grid with tap/remove
// ============================================================================

class _ImageGridItem extends StatelessWidget {
  final SelectedImage image;
  final int index;
  final int totalCount;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool isDimmed;
  final bool isHoverTarget;

  const _ImageGridItem({
    super.key,
    required this.image,
    required this.index,
    required this.totalCount,
    required this.onTap,
    required this.onRemove,
    this.isDimmed = false,
    this.isHoverTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDimmed ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isHoverTarget
                ? Border.all(color: cs.primary, width: 2.5)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: image.provider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: cs.surfaceContainerHigh,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
                // Remove button
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: onRemove,
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
                if (totalCount > 1)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
            ),
          ),
        ),
      ),
    );
  }
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
