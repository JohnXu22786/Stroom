import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:extended_image/extended_image.dart';

import '../providers/provider_config.dart';
import '../utils/provider_models.dart';
import '../providers/background_task_provider.dart';
import '../providers/ocr_instructions_provider.dart';
import '../providers/text_provider.dart';
import '../services/ocr_service.dart';
import '../services/ocr_task_runner.dart';
import '../utils/data_sanitizer.dart';
import '../utils/system_pick_utils.dart';
import '../utils/text_manifest.dart';
import '../widgets/folder_picker_dialog.dart';
import 'chat/composer/chat_album_picker_dialog.dart';
import 'extended_image_editor_page.dart';
import 'image_editor_page.dart';
import 'ocr/ocr_instruction_dialog.dart';
import 'ocr/ocr_shared.dart';
import 'ocr/ocr_retry_snapshot.dart';
import 'provider_config_page.dart';
export 'ocr/ocr_shared.dart';

// ============================================================================
// Helper: Pair model config with its source provider info
// ============================================================================

/// Pair of model config with its source provider info for display and
/// request building.
class _ModelOption {
  final ModelConfig model;
  final String configId;
  final String modelRecordId;
  final String providerName;
  final String host;
  final String apiKey;
  const _ModelOption(this.model, this.configId, this.modelRecordId,
      this.providerName, this.host, this.apiKey);
}

/// Collect all available models with their source provider info from ALL
/// configured OCR provider configs (not just the first one).
/// Only includes configs with valid host and API key.
List<_ModelOption> _getOcrModelOptions(WidgetRef ref) {
  final state = ref.read(providerEntriesProvider);
  return [
    for (final e in flattenProviderModels(state, 'ocr'))
      _ModelOption(
        e.model,
        e.config.id,
        e.model.id,
        e.config.providerName,
        e.config.host,
        e.config.key,
      ),
  ];
}

/// Get the first OCR entry ID for navigation to its config page.
String? _getFirstOcrEntryId(WidgetRef ref) {
  final state = ref.read(providerEntriesProvider);
  for (final entry in state.entries) {
    if (entry.type == 'ocr') {
      return entry.id;
    }
  }
  return null;
}

Map<String, dynamic> _buildOcrRetryData({
  required List<Uint8List> imageBytesList,
  required List<String> imageFormatList,
  required List<String?> imageNameList,
  required String configId,
  required String modelId,
  required String? instructionContent,
  required String saveFolder,
}) {
  return OcrRetrySnapshot.capture(
    configId: configId,
    modelId: modelId,
    images: [
      for (var i = 0; i < imageBytesList.length; i++)
        OcrRetryImage(
          bytes: imageBytesList[i],
          format: imageFormatList[i],
          name: imageNameList[i],
        ),
    ],
    instructionContent: instructionContent,
    saveFolder: saveFolder,
  ).toMap();
}

/// Writes the content of the generic instruction at [instructionIndex] into
/// [typeConfig]['userInstruction'] — the key the OCR service sends as the
/// user-message text part. Returns the (possibly changed) typeConfig.
///
/// Out-of-range or default (-1) selections remove any 'userInstruction'
/// from the request copy: the request must stay images-only even when the
/// copied typeConfig still carries a legacy per-model instruction (kept in
/// storage for the one-shot generic-store migration).
@visibleForTesting
Map<String, dynamic> applySelectedOcrInstruction(
  Map<String, dynamic> typeConfig,
  List<OcrInstruction> instructions,
  int instructionIndex,
) {
  if (instructionIndex >= 0 && instructionIndex < instructions.length) {
    final content = instructions[instructionIndex].content.trim();
    if (content.isNotEmpty) {
      typeConfig['userInstruction'] = content;
    }
  } else {
    typeConfig.remove('userInstruction');
  }
  return typeConfig;
}

// ============================================================================
// OCR Page
// ============================================================================

/// Main OCR page — allows taking photos or selecting from gallery,
/// then performing OCR and saving results to text storage.
class OcrPage extends ConsumerStatefulWidget {
  const OcrPage(
      {super.key,
      this.testImages,
      this.retryData,
      this.testCameraPicker,
      this.testGalleryPicker});

  @visibleForTesting
  final Future<XFile?> Function()? testCameraPicker;
  @visibleForTesting
  final Future<List<XFile>> Function()? testGalleryPicker;

  /// Test-only: pre-populate images for widget testing.
  @visibleForTesting
  final List<SelectedImage>? testImages;

  /// Retry data to pre-populate the form (images, model, etc.).
  final Map<String, dynamic>? retryData;

  @override
  ConsumerState<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends ConsumerState<OcrPage> {
  final List<SelectedImage> _selectedImages = [];
  bool _isProcessing = false;
  String? _errorMessage;
  int _selectedModelIndex = 0;
  String? _selectedConfigId;
  String? _selectedModelRecordId;
  bool _modelSelectionNeedsReselection = false;
  bool _legacyModelConfirmationPending = false;

  /// Index into the generic user instructions, or -1 for the default
  /// behavior (images only, no instruction).
  int _selectedInstructionIndex = -1;

  /// Instruction index restored from retry data, pending until the generic
  /// instruction list finishes loading. The provider's initial state is
  /// empty until its async load completes, so without this a restored
  /// index would be clamped to the default before the list arrives.
  int? _pendingRetryInstructionIndex;

  /// Exact instruction captured for this retry. It stays authoritative even
  /// when the generic list is later edited or the entry is deleted.
  String? _retryInstructionSnapshot;

  /// Whether [_startOcr] is inside its retry-instruction resolve await —
  /// blocks a second tap from starting a duplicate OCR during that gap.
  bool _ocrStarting = false;

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
    _applyRetryData();
  }

  /// Pre-populate form from retry data if available.
  void _applyRetryData() {
    final data = widget.retryData;
    if (data == null) return;
    final snapshot = OcrRetrySnapshot.fromMap(data);
    _selectedImages.addAll(snapshot.images.map((image) => SelectedImage(
          bytes: image.bytes,
          format: image.format,
          sourceName: image.name,
        )));
    _saveFolder = snapshot.saveFolder;

    if (snapshot.version == OcrRetrySnapshot.currentVersion) {
      _selectedConfigId = snapshot.configId;
      _selectedModelRecordId = snapshot.modelId;
      _modelSelectionNeedsReselection =
          snapshot.configId == null || snapshot.modelId == null;
      if (_modelSelectionNeedsReselection) _selectedModelIndex = -1;
    } else if (snapshot.isLegacy) {
      _selectedModelIndex = snapshot.legacyModelIndex ?? -1;
      _modelSelectionNeedsReselection = snapshot.legacyModelIndex == null;
      _legacyModelConfirmationPending = snapshot.legacyModelIndex != null;
    } else {
      // Unknown future versions are never interpreted as an old index.
      _selectedModelIndex = -1;
      _modelSelectionNeedsReselection = true;
    }

    if (snapshot.instructionContent != null) {
      _retryInstructionSnapshot = snapshot.instructionContent;
    } else if (snapshot.legacyInstructionIndex != null) {
      _pendingRetryInstructionIndex = snapshot.legacyInstructionIndex;
      unawaited(_resolvePendingRetryInstruction());
    }
  }

  /// Applies the retry instruction once the generic instruction list has
  /// been loaded. Captured content remains the request input even when there
  /// is no matching generic entry; index-only legacy data keeps its old
  /// position-based behavior.
  Future<void> _resolvePendingRetryInstruction() async {
    final pending = _pendingRetryInstructionIndex;
    if (pending == null) return;
    await ref.read(ocrInstructionsProvider.notifier).load();
    if (!mounted || _pendingRetryInstructionIndex == null) return;
    _pendingRetryInstructionIndex = null;
    final instructions = ref.read(ocrInstructionsProvider);
    final idx = (pending >= 0 && pending < instructions.length) ? pending : -1;
    // Always rebuild: while the restore was pending, the dropdown may be
    // displaying the pending-derived value — it must reflect the resolved
    // index even when it equals the current selection.
    setState(() => _selectedInstructionIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(providerEntriesProvider);
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

          // Instruction selector (below the model selector)
          _buildInstructionSelector(cs),

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

  int? _selectedModelOptionIndex(List<_ModelOption> modelOptions) {
    if (_selectedConfigId != null || _selectedModelRecordId != null) {
      if (_selectedConfigId == null || _selectedModelRecordId == null) {
        return null;
      }
      final matches = <int>[];
      for (var index = 0; index < modelOptions.length; index++) {
        final option = modelOptions[index];
        if (option.configId == _selectedConfigId &&
            option.modelRecordId == _selectedModelRecordId) {
          matches.add(index);
        }
      }
      return matches.length == 1 ? matches.single : null;
    }
    if (_modelSelectionNeedsReselection ||
        _selectedModelIndex < 0 ||
        _selectedModelIndex >= modelOptions.length) {
      return null;
    }
    return _selectedModelIndex;
  }

  String? _modelSelectionMessage(int? selectedIndex) {
    if (_legacyModelConfirmationPending) {
      return selectedIndex == null
          ? '旧重试记录中的模型位置无效，请重新选择'
          : '旧重试记录只保存了模型位置，请确认当前模型后继续。';
    }
    if (_modelSelectionNeedsReselection ||
        (_selectedConfigId != null && selectedIndex == null) ||
        (_selectedModelRecordId != null && selectedIndex == null)) {
      return '原 OCR 供应商或模型已不存在，请重新选择';
    }
    return null;
  }

  void _selectModelOption(_ModelOption option, int index) {
    _selectedModelIndex = index;
    _selectedConfigId = option.configId;
    _selectedModelRecordId = option.modelRecordId;
    _modelSelectionNeedsReselection = false;
    _legacyModelConfirmationPending = false;
  }

  Widget _buildModelSelector(ColorScheme cs) {
    final modelOptions = _getOcrModelOptions(ref);

    // No models configured — show configure prompt (like TTS page)
    if (modelOptions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.error.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: cs.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '识别模型',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () {
                  final entryId = _getFirstOcrEntryId(ref);
                  if (entryId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderConfigPage(entryId: entryId),
                      ),
                    );
                  } else {
                    Navigator.pushNamed(context, '/settings');
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: cs.error,
                ),
                child: const Text(
                  '去配置',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selectedIndex = _selectedModelOptionIndex(modelOptions);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
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
              // 机器人图标，与对话页面输入框的模型标识一致
              child:
                  Icon(Icons.smart_toy_outlined, size: 16, color: cs.primary),
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
                    value: selectedIndex,
                    hint: selectedIndex == null
                        ? Text(_modelSelectionMessage(selectedIndex) ?? '请选择模型')
                        : null,
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
                      if (idx == null || idx >= modelOptions.length) return;
                      setState(() {
                        _selectModelOption(modelOptions[idx], idx);
                        _errorMessage = null;
                      });
                    },
                    items: List.generate(modelOptions.length, (i) {
                      final opt = modelOptions[i];
                      final modelName = opt.model.name.isNotEmpty
                          ? opt.model.name
                          : opt.model.modelId;
                      final displayText = opt.providerName.isNotEmpty
                          ? '$modelName | ${opt.providerName}'
                          : modelName;
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

  /// Instruction selector shown below the model selector. Always visible
  /// (regardless of whether any instruction is configured); managing the
  /// generic instruction list happens here, on the OCR page.
  Widget _buildInstructionSelector(ColorScheme cs) {
    final modelOptions = _getOcrModelOptions(ref);
    if (modelOptions.isEmpty || _selectedModelIndex >= modelOptions.length) {
      return const SizedBox.shrink();
    }
    final instructions = ref.watch(ocrInstructionsProvider);

    // A captured instruction stays selected even when it no longer exists in
    // the editable generic list. Legacy index-only restore waits for the list
    // to load before resolving its position.
    final pending = _pendingRetryInstructionIndex;
    final rawIndex = _retryInstructionSnapshot != null
        ? -2
        : (pending ?? _selectedInstructionIndex);
    final clamped = rawIndex == -2
        ? -2
        : (rawIndex >= 0 && rawIndex < instructions.length ? rawIndex : -1);
    if (pending == null &&
        _retryInstructionSnapshot == null &&
        clamped != _selectedInstructionIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedInstructionIndex = clamped);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
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
              child: Icon(Icons.edit_note, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Text(
              '识别指令',
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
                    value: clamped,
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
                      if (idx == null) return;
                      setState(() {
                        _selectedInstructionIndex = idx;
                        if (idx != -2) _retryInstructionSnapshot = null;
                        // An explicit user choice wins over a pending
                        // retry restore.
                        _pendingRetryInstructionIndex = null;
                      });
                    },
                    items: [
                      const DropdownMenuItem<int>(
                        value: -1,
                        child: Text(
                          '默认（仅发送图片）',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_retryInstructionSnapshot != null)
                        const DropdownMenuItem<int>(
                          value: -2,
                          child: Text(
                            '已保存的指令快照',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ...List.generate(instructions.length, (i) {
                        return DropdownMenuItem<int>(
                          value: i,
                          child: Text(
                            ocrInstructionLabel(instructions[i]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            // 在 OCR 页面管理通用识别指令
            IconButton(
              key: const Key('ocr_instruction_manage_btn'),
              icon: Icon(
                Icons.settings_outlined,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              tooltip: '管理识别指令',
              // Keep the row height aligned with the model card (the
              // default 48px tap target would inflate the card).
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => const OcrInstructionManageDialog(),
                );
              },
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
          onReorderItem: _onReorder,
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
    final modelOptions = _getOcrModelOptions(ref);
    final selectedModelIndex = _selectedModelOptionIndex(modelOptions);
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
            if (_legacyModelConfirmationPending && selectedModelIndex != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '旧重试记录只保存了模型位置，请确认当前模型后继续。',
                        style: TextStyle(fontSize: 12, color: cs.error),
                      ),
                    ),
                    TextButton(
                      key: const Key('ocr_confirm_legacy_model'),
                      onPressed: () {
                        setState(() {
                          _selectModelOption(
                            modelOptions[selectedModelIndex],
                            selectedModelIndex,
                          );
                          _errorMessage = null;
                        });
                      },
                      child: const Text('确认此模型'),
                    ),
                  ],
                ),
              ),
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
      onCreateFolder: (name) async {
        await TextManifest.addFolder(name);
        return null;
      },
      onRefreshFolders: () async => TextManifest.getAllFolders(),
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
                    subtitle: '浏览并选择设备中的图片',
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
      final file = await (widget.testCameraPicker?.call() ??
          picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 2048,
            maxHeight: 2048,
            imageQuality: 90,
          ));
      if (!mounted || file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedImages.add(
          SelectedImage(
            bytes: bytes,
            format: _detectFormat(file.path),
            // Camera: temp file, no source name
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

  /// Pick images from the device gallery (supports batch selection).
  Future<void> _pickFromSystemGallery() async {
    try {
      // 移动端直接通过 image_picker 打开系统相册，
      // 桌面端打开文件选择器并定位到系统"图片"目录
      final files = await (widget.testGalleryPicker?.call() ??
          pickGalleryMedia(
            GalleryMediaKind.image,
            imageQuality: 90,
            maxWidth: 2048,
            maxHeight: 2048,
          ));
      if (!mounted || files.isEmpty) return;

      final newImages = <SelectedImage>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        if (bytes.isEmpty) continue; // 读取失败的文件跳过（与相册路径一致）
        newImages.add(
          SelectedImage(
            bytes: bytes,
            format: _detectFormat(file.path),
            sourceName: file.name, // System file has original name
          ),
        );
      }

      if (!mounted) return;
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
      if (!mounted || result == null || result.isEmpty) return;
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
    if (!mounted) return;
    try {
      final format = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'png';
      setState(() {
        _selectedImages.add(
          SelectedImage(
            bytes: data,
            format: format,
            sourceName: fileName, // App album file has original name
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

  // ==================================================================
  // Image Reorder & Preview
  // ==================================================================

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      // onReorderItem 的 newIndex 已是移除后的索引，直接使用
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  Future<void> _previewImage(int index) async {
    if (index < 0 || index >= _selectedImages.length) return;

    // Full-screen preview with left/right swipe paging — the same
    // interaction as the file page's gallery viewer. Pops with the
    // tapped action and the index of the image that was being viewed
    // (which may differ from [index] after swiping).
    final result = await showDialog<({String action, int index})>(
      context: context,
      builder: (_) => _OcrPreviewDialog(
        images: _selectedImages,
        initialIndex: index,
      ),
    );

    if (result == null || !mounted) return;
    final editedIndex = result.index;
    if (editedIndex >= _selectedImages.length) return;

    final currentImage = _selectedImages[editedIndex];
    Uint8List? editedBytes;

    if (result.action == 'crop') {
      // Quick edit — directly opens crop editor, no choice dialog needed.
      // The editor processes the image in place (the page stays open with
      // a spinner until the pipeline finishes) and pops back with the
      // edited bytes.
      editedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => ExtendedImageEditorPage(
            imageBytes: currentImage.bytes,
            fileName: '图片_${editedIndex + 1}.${currentImage.format}',
          ),
        ),
      );
    } else {
      // Full editor — opens with showSaveDialog=false so it directly
      // overwrites the in-memory data without asking the user
      final editorResult = await Navigator.push<ImageEditorResult>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageEditorPage(
            imageBytes: currentImage.bytes,
            showSaveDialog: false,
          ),
        ),
      );
      if (editorResult != null) {
        editedBytes = editorResult.editedBytes;
      }
    }

    if (editedBytes == null || !mounted) return;
    _applyEditedImage(editedIndex, currentImage, editedBytes);
  }

  /// Applies [editedBytes] to the in-memory selected image, guarding
  /// against the image at [index] having changed since the editor opened.
  void _applyEditedImage(
    int index,
    SelectedImage currentImage,
    Uint8List editedBytes,
  ) {
    if (!mounted) return;
    if (index >= _selectedImages.length) return;
    // Verify the image at this index is still the same one
    if (_selectedImages[index].bytes != currentImage.bytes) return;

    // Update the selected image with edited bytes (in-memory only)
    setState(() {
      _selectedImages[index] = SelectedImage(
        bytes: editedBytes,
        format: currentImage.format,
      );
    });
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
    if (_ocrStarting || _isProcessing) return;
    if (_selectedImages.isEmpty) return;

    final modelOptions = _getOcrModelOptions(ref);
    if (modelOptions.isEmpty) {
      setState(() {
        _errorMessage = '请先在设置中配置 OCR 供应商和模型';
      });
      return;
    }
    final modelIndex = _selectedModelOptionIndex(modelOptions);
    if (modelIndex == null) {
      setState(() {
        _errorMessage =
            _modelSelectionMessage(modelIndex) ?? '请重新选择 OCR 供应商和模型';
      });
      return;
    }
    if (_legacyModelConfirmationPending) {
      setState(() {
        _errorMessage = '请先确认旧重试记录中的 OCR 模型';
      });
      return;
    }

    _ocrStarting = true;
    final images = _selectedImages
        .map((image) => SelectedImage(
              bytes: Uint8List.fromList(image.bytes),
              format: image.format,
              sourceName: image.sourceName,
            ))
        .toList();
    final folder = _saveFolder;

    // Build config from the selected model's own source config,
    // ensuring host/API key match the model's provider.
    // Also passes through the model's typeConfig and customParams
    // for built-in OCR parameters and custom parameters.
    final selectedOption = modelOptions[modelIndex];
    _selectedModelIndex = modelIndex;
    _selectedConfigId = selectedOption.configId;
    _selectedModelRecordId = selectedOption.modelRecordId;
    final effectiveConfig = OcrConfig(
      host: selectedOption.host,
      apiKey: selectedOption.apiKey,
      model: selectedOption.model.modelId,
      typeConfig: Map<String, dynamic>.from(selectedOption.model.typeConfig),
      customParams:
          selectedOption.model.customParams.map((p) => p.copy()).toList(),
    );

    // A retry instruction restore may still be pending (the generic list
    // was still loading) — resolve it so the request carries the restored
    // instruction instead of silently dropping it. Guarded so a second tap
    // during the async load cannot start a duplicate OCR.
    if (_pendingRetryInstructionIndex != null) {
      try {
        await _resolvePendingRetryInstruction();
      } catch (_) {
        _ocrStarting = false;
        rethrow;
      }
    }

    // The page may have been disposed while the restore load was in
    // flight (e.g. back-press) — stop rather than using a dead [ref].
    if (!mounted) return;

    // Inject the selected generic instruction into the request (service
    // reads typeConfig['userInstruction']); unselected = images-only.
    final instructions = ref.read(ocrInstructionsProvider);
    if (_retryInstructionSnapshot != null) {
      final content = _retryInstructionSnapshot!.trim();
      if (content.isEmpty) {
        effectiveConfig.typeConfig.remove('userInstruction');
      } else {
        effectiveConfig.typeConfig['userInstruction'] = content;
      }
    } else {
      applySelectedOcrInstruction(
        effectiveConfig.typeConfig,
        instructions,
        _selectedInstructionIndex,
      );
    }

    // Capture every provider and input before navigation. The runner owns
    // copies and never reads this page or WidgetRef after it is removed.
    final bgNotifier = ref.read(backgroundTasksProvider.notifier);
    final textNotifier = ref.read(textRecordsProvider.notifier);
    final timestamp = _currentTimestamp();
    final allHaveSourceNames = images.every((img) => img.sourceName != null);
    final title = allHaveSourceNames
        ? 'OCR_${images.first.sourceName!}'
        : 'OCR_$timestamp';
    final imageBytesList = images.map((img) => img.bytes).toList();
    final imageFormatList = images.map((img) => img.format).toList();
    final imageNameList = images.map((img) => img.sourceName).toList();
    final taskId = bgNotifier.addTask(
      type: BackgroundTaskType.ocr,
      title: title,
      retryData: null,
    );
    final runner = OcrTaskRunner(
      taskId: taskId,
      notifier: bgNotifier,
      config: effectiveConfig,
      images: images.map((img) => (img.bytes, img.format)).toList(),
      title: title,
      folder: folder,
      onSaved: () => unawaited(textNotifier.loadRecords()),
    );

    // Step 3: Fire-and-forget retryData computation (only needed for retry).
    // Save the exact instruction and destination along with the stable model
    // reference so later list edits cannot change this retry's request.
    final instructionContent = _retryInstructionSnapshot ??
        ((_selectedInstructionIndex >= 0 &&
                _selectedInstructionIndex < instructions.length)
            ? instructions[_selectedInstructionIndex].content
            : null);
    unawaited(_computeOcrRetryData(
        taskId,
        imageBytesList,
        imageFormatList,
        imageNameList,
        selectedOption.configId,
        selectedOption.modelRecordId,
        instructionContent,
        folder,
        bgNotifier));

    _isProcessing = true;
    unawaited(runner.run());
    Navigator.pop(context);
  }

  /// Compute retryData for an OCR task in the background.
  /// Fire-and-forget — the task can execute without retryData.
  static Future<void> _computeOcrRetryData(
    String taskId,
    List<Uint8List> imageBytesList,
    List<String> imageFormatList,
    List<String?> imageNameList,
    String configId,
    String modelId,
    String? instructionContent,
    String saveFolder,
    BackgroundTaskNotifier bgNotifier,
  ) async {
    try {
      final retryData = await Isolate.run(() => _buildOcrRetryData(
            imageBytesList: imageBytesList,
            imageFormatList: imageFormatList,
            imageNameList: imageNameList,
            configId: configId,
            modelId: modelId,
            instructionContent: instructionContent,
            saveFolder: saveFolder,
          ));
      if (bgNotifier.mounted &&
          bgNotifier.state.any((task) => task.id == taskId)) {
        bgNotifier.setRetryData(taskId, retryData);
      }
    } catch (e) {
      debugPrint('[OCR] Isolate.run failed, falling back to main thread: $e');
      try {
        final retryData = _buildOcrRetryData(
          imageBytesList: imageBytesList,
          imageFormatList: imageFormatList,
          imageNameList: imageNameList,
          configId: configId,
          modelId: modelId,
          instructionContent: instructionContent,
          saveFolder: saveFolder,
        );
        if (bgNotifier.mounted &&
            bgNotifier.state.any((task) => task.id == taskId)) {
          bgNotifier.setRetryData(taskId, retryData);
        }
      } catch (retryError) {
        debugPrint('[OCR] Failed to compute retryData: $retryError');
      }
    }
  }

  String _currentTimestamp() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
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

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ====================================================================
// OCR Image Preview Dialog (swipeable)
// ====================================================================

/// Full-screen preview of the selected OCR images with left/right swipe
/// paging — the same interaction as the file page's gallery viewer.
///
/// Pops with a record of the tapped action ('crop' or 'edit') and the
/// index of the image that was being viewed, so the caller edits the
/// right image after the user has swiped away from the originally
/// tapped one. A plain pop (close button / tap on the image) yields null.
class _OcrPreviewDialog extends StatefulWidget {
  final List<SelectedImage> images;
  final int initialIndex;

  const _OcrPreviewDialog({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_OcrPreviewDialog> createState() => _OcrPreviewDialogState();
}

class _OcrPreviewDialogState extends State<_OcrPreviewDialog> {
  late final ExtendedPageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = ExtendedPageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Pops with the tapped [action] plus the index of the image that was
  /// being viewed when the button was tapped.
  void _popWithAction(String action) {
    Navigator.pop(context, (action: action, index: _currentIndex));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          ExtendedImageGesturePageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              if (index < 0 || index >= widget.images.length) {
                return const Center(child: Text('Invalid index'));
              }
              final image = widget.images[index];
              return GestureDetector(
                key: const Key('preview_tap_to_close'),
                onTap: () => Navigator.pop(context),
                child: Center(
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
                      inPageView: true,
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
              );
            },
          ),
          // Close button (top left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0x66000000),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                key: const Key('preview_close_btn'),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // Edit buttons (top right) — same two-button design as gallery
          // viewer page: crop (quick edit) + edit (full editor)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.crop, color: Colors.white, size: 24),
                    tooltip: '裁剪',
                    onPressed: () => _popWithAction('crop'),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 24),
                    tooltip: '编辑',
                    onPressed: () => _popWithAction('edit'),
                  ),
                ),
              ],
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Text(
                '${_currentIndex + 1} / ${widget.images.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
