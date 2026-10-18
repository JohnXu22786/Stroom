import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:extended_image/extended_image.dart';
import 'package:uuid/uuid.dart';

import '../models/ocr_batch_execution.dart';
import '../models/ocr_output_template.dart';
import '../providers/provider_config.dart';
import '../utils/provider_models.dart';
import '../providers/background_task_provider.dart';
import '../providers/ocr_instructions_provider.dart';
import '../providers/text_provider.dart';
import '../services/ocr_service.dart';
import '../services/ocr_retry_storage.dart';
import '../services/ocr_task_runner.dart';
import '../utils/data_sanitizer.dart';
import '../utils/ocr_image_payload.dart';
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
  const _ModelOption(
    this.model,
    this.configId,
    this.modelRecordId,
    this.providerName,
    this.host,
    this.apiKey,
  );
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

/// Resolves the selected built-in template or generic instruction without
/// changing its content. Retry snapshots use this value verbatim; request
/// configuration trims only user-managed instructions.
///
/// Default (-1), saved retry snapshot (-2), and out-of-range selections
/// remove any 'userInstruction' from the request copy. The default request
/// therefore stays images-only even when the copied typeConfig still carries
/// a legacy per-model instruction.
@visibleForTesting
String? selectedOcrInstructionContent(
  List<OcrInstruction> instructions,
  int selectionValue,
) {
  final template = ocrOutputTemplateForSelection(selectionValue);
  if (template != null) return template.content;
  if (selectionValue >= 0 && selectionValue < instructions.length) {
    return instructions[selectionValue].content;
  }
  return null;
}

@visibleForTesting
Map<String, dynamic> applySelectedOcrInstruction(
  Map<String, dynamic> typeConfig,
  List<OcrInstruction> instructions,
  int selectionValue,
) {
  final selectedContent = selectedOcrInstructionContent(
    instructions,
    selectionValue,
  );
  final content = ocrOutputTemplateForSelection(selectionValue) == null
      ? selectedContent?.trim()
      : selectedContent;
  if (content != null && content.isNotEmpty) {
    typeConfig['userInstruction'] = content;
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
  const OcrPage({
    super.key,
    this.testImages,
    this.retryData,
    this.retryTaskId,
    this.testCameraPicker,
    this.testGalleryPicker,
    this.testImagePayloadPreparer,
    this.testOcrServiceFactory,
    this.testRetryImageRestorer,
    this.testRetrySnapshotCacher,
    this.retryPageOutcomes = const [],
  });

  @visibleForTesting
  final Future<XFile?> Function({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  })? testCameraPicker;
  @visibleForTesting
  final Future<List<XFile>> Function({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  })? testGalleryPicker;
  @visibleForTesting
  final Future<OcrImagePayload> Function(Uint8List bytes)?
      testImagePayloadPreparer;
  @visibleForTesting
  final OcrService Function(OcrConfig config)? testOcrServiceFactory;
  @visibleForTesting
  final Future<OcrRetryRestoreResult> Function(OcrRetrySnapshot snapshot)?
      testRetryImageRestorer;
  @visibleForTesting
  final Future<Map<String, dynamic>?> Function({
    required String taskId,
    required OcrRetrySnapshot snapshot,
  })? testRetrySnapshotCacher;

  /// Test-only: pre-populate images for widget testing.
  @visibleForTesting
  final List<SelectedImage>? testImages;

  /// Retry data to pre-populate the form (images, model, etc.).
  final Map<String, dynamic>? retryData;

  /// Source task ID, used to migrate legacy inline retry images in place.
  final String? retryTaskId;
  final List<OcrPageOutcome> retryPageOutcomes;

  @override
  ConsumerState<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends ConsumerState<OcrPage> {
  static const _retryImagesUnavailableMessage =
      '原始 OCR 图片缓存不可用，请清空并重新选择全部图片后重试';
  static const _retryImageCountUnknownMessage =
      '原始 OCR 图片缓存不可用，且无法确认图片数量。请重置后重新选择本次全部图片';
  static const _retryImageResetMessage = '已重置原重试输入，请重新选择本次 OCR 的全部图片';

  String get _retryUnavailableMessage => _retryImageCountUnknown
      ? _retryImageCountUnknownMessage
      : _retryImagesUnavailableMessage;

  final List<SelectedImage> _selectedImages = [];
  late List<OcrPageOutcome> _retryPageOutcomes;
  final TextEditingController _requestSizeBudgetMiBController =
      TextEditingController(text: '20');
  OcrBatchMode _batchMode = OcrBatchMode.joint;
  int _perImageConcurrency = 1;
  bool _isProcessing = false;
  bool _isPreparingRetryData = false;
  bool _isRetryImagesLoading = false;
  int _pendingImageImports = 0;
  bool get _isImageImportPending => _pendingImageImports > 0;
  bool get _hasReusablePageResults =>
      _retryPageOutcomes.any((outcome) => outcome.canReuseResult);
  bool get _isImageSelectionLocked =>
      _isProcessing || _isRetryImagesLoading || _hasReusablePageResults;

  bool _retryImagesUnavailable = false;
  bool _retryImageCountUnknown = false;
  int? _requiredRetryImageCount;
  bool _isRetryImageReselectionPending = false;
  bool get _retryImageCountMismatch =>
      _requiredRetryImageCount != null &&
      _selectedImages.length != _requiredRetryImageCount;

  bool _useOriginalImageQuality = false;
  String? _errorMessage;
  int _selectedModelIndex = 0;
  String? _selectedConfigId;
  String? _selectedModelRecordId;
  String? _retryModelIdHint;
  bool _modelSelectionNeedsReselection = false;
  bool _legacyModelConfirmationPending = false;

  /// Non-negative values index custom instructions; built-in formats use
  /// stable negative values, while -1 keeps the default images-only request.
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

  Future<OcrImagePayload> _prepareImagePayload(Uint8List bytes) =>
      widget.testImagePayloadPreparer?.call(bytes) ??
      prepareOcrImagePayload(bytes);

  void _beginImageImport() {
    if (!mounted) return;
    setState(() => _pendingImageImports++);
  }

  void _finishImageImport() {
    if (!mounted) return;
    setState(() => _pendingImageImports--);
  }

  OcrImageImportMode get _imageImportMode => _useOriginalImageQuality
      ? OcrImageImportMode.original
      : OcrImageImportMode.standard;

  /// Whether reorder mode is active
  bool _reorderMode = false;

  /// Invalidates pending image imports after a clear or a newer import.
  int _imageImportGeneration = 0;

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
    _retryPageOutcomes = List.of(widget.retryPageOutcomes);
    if (widget.testImages != null) {
      _selectedImages.addAll(widget.testImages!);
    }
    _isRetryImagesLoading = widget.retryData != null;
    if (widget.retryTaskId != null && widget.retryData == null) {
      _retryImageCountUnknown = true;
      _retryImagesUnavailable = true;
      _errorMessage = _retryImageCountUnknownMessage;
    }
    unawaited(_applyRetryData());
  }

  @override
  void dispose() {
    _requestSizeBudgetMiBController.dispose();
    super.dispose();
  }

  /// Pre-populate form from retry data if available.
  Future<void> _applyRetryData() async {
    final data = widget.retryData;
    if (data == null) return;
    final snapshot = OcrRetrySnapshot.fromMap(data);
    _retryImageCountUnknown = snapshot.imageEntryCount == 0;
    _saveFolder = snapshot.saveFolder;

    if (snapshot.version != null &&
        snapshot.version! > OcrRetrySnapshot.currentVersion) {
      _selectedModelIndex = -1;
      _modelSelectionNeedsReselection = true;
    } else if (snapshot.configId != null && snapshot.modelId != null) {
      _selectedConfigId = snapshot.configId;
      _selectedModelRecordId = snapshot.modelId;
    } else if (snapshot.legacyModelIndex != null) {
      _selectedModelIndex = snapshot.legacyModelIndex ?? -1;
      _legacyModelConfirmationPending = true;
    } else if (snapshot.modelId != null &&
        _isSafeRetryModelHint(snapshot.modelId!)) {
      _retryModelIdHint = snapshot.modelId;
      _modelSelectionNeedsReselection = true;
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

    OcrRetryRestoreResult restored;
    try {
      restored = await (widget.testRetryImageRestorer?.call(snapshot) ??
          OcrRetryStorage.restoreImages(snapshot));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRetryImagesLoading = false;
        _retryImagesUnavailable = true;
        _retryImageCountUnknown = snapshot.imageEntryCount == 0;
        if (snapshot.imageEntryCount > 0) {
          _requiredRetryImageCount = snapshot.imageEntryCount;
        }
        _errorMessage = _retryImageCountUnknown
            ? _retryImageCountUnknownMessage
            : '原始 OCR 图片缓存无法读取，请清空并重新选择全部图片后重试';
      });
      debugPrint('[OCR] Retry image restore failed: $error');
      return;
    }
    if (!mounted) return;
    final canUseRestoredImages = restored.isComplete &&
        !snapshot.hasInvalidImages &&
        snapshot.imageEntryCount > 0;
    setState(() {
      _selectedImages.addAll(
        restored.images.map(
          (image) => SelectedImage(
            bytes: image.bytes!,
            format: image.format,
            sourceName: image.name,
          ),
        ),
      );
      _batchMode =
          _hasReusablePageResults ? OcrBatchMode.perImage : snapshot.batchMode;
      _perImageConcurrency = snapshot.perImageConcurrency;
      _requestSizeBudgetMiBController.text =
          (snapshot.requestSizeBudgetBytes / (1024 * 1024))
              .toString()
              .replaceFirst(RegExp(r'\.0$'), '');
      _isRetryImagesLoading = false;
      _retryImagesUnavailable = !canUseRestoredImages;
      _retryImageCountUnknown =
          !canUseRestoredImages && snapshot.imageEntryCount == 0;
      if (!canUseRestoredImages && snapshot.imageEntryCount > 0) {
        _requiredRetryImageCount = snapshot.imageEntryCount;
      }
      if (_retryImagesUnavailable) {
        _errorMessage = _retryImageCountUnknown
            ? _retryImageCountUnknownMessage
            : '原始 OCR 图片缓存已丢失或损坏，请清空并重新选择全部图片后重试';
      }
    });

    if (canUseRestoredImages &&
        widget.retryTaskId != null &&
        snapshot.needsMigration) {
      unawaited(
        _migrateRetrySnapshot(
          widget.retryTaskId!,
          snapshot,
          ref.read(backgroundTasksProvider.notifier),
        ),
      );
    }
  }

  Future<void> _migrateRetrySnapshot(
    String taskId,
    OcrRetrySnapshot snapshot,
    BackgroundTaskNotifier notifier,
  ) async {
    try {
      await OcrRetryStorage.withCacheMaintenanceLock(() async {
        final retryData = await (widget.testRetrySnapshotCacher?.call(
              taskId: taskId,
              snapshot: snapshot,
            ) ??
            OcrRetryStorage.cacheSnapshot(
              taskId: taskId,
              snapshot: snapshot,
            ));
        if (!notifier.mounted) return;
        if (!notifier.state.any((task) => task.id == taskId)) {
          await OcrRetryStorage.deleteUnreferenced(
            candidates: OcrRetryStorage.referencesFromSnapshot(retryData),
            referenced: {
              for (final task in notifier.state)
                if (task.type == BackgroundTaskType.ocr)
                  ...OcrRetryStorage.referencesFromSnapshot(task.retryData),
            },
          );
          return;
        }
        notifier.setRetryData(taskId, retryData);
      });
    } catch (error) {
      debugPrint('[OCR] Legacy retry image migration failed: $error');
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
          IconButton(
            key: const Key('ocr_request_budget_mib'),
            tooltip: '请求 JSON 上限：${_requestSizeBudgetMiBController.text} MiB',
            onPressed: _isProcessing ? null : _editRequestSizeBudget,
            icon: const Icon(Icons.data_usage_outlined),
          ),
          if (_selectedImages.length > 1 &&
              !_isProcessing &&
              !_isRetryImagesLoading &&
              !_hasReusablePageResults)
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
          if ((_selectedImages.isNotEmpty || _retryImagesUnavailable) &&
              !_isProcessing &&
              !_isRetryImagesLoading &&
              (!_hasReusablePageResults || _retryImagesUnavailable) &&
              !_reorderMode)
            IconButton(
              key: const Key('ocr_clear_button'),
              tooltip: '清空',
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          // Model selector (nicely styled)
          _buildModelSelector(cs),

          // Instruction selector (below the model selector)
          _buildInstructionSelector(cs),

          // Batch mode and encoded request size limit
          _buildBatchOptions(cs),

          // Photo source buttons
          _buildPhotoSourceBar(cs),

          // Image preview area
          Expanded(
            child: _selectedImages.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: _buildEmptyState(cs),
                      ),
                    ),
                  )
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

  bool _isSafeRetryModelHint(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:/-]{0,127}$').hasMatch(value) &&
      !RegExp(
        r'^(?:sk-(?:proj-|ant-api\d{2}-|or-v1-)?[a-z0-9]{8,}|gsk_[a-z0-9]{8,}|gh[pousr]_[a-z0-9]{8,}|AIza[a-z0-9_-]{20,})$',
        caseSensitive: false,
      ).hasMatch(value);

  String? _modelSelectionMessage(int? selectedIndex) {
    if (_retryModelIdHint != null && _modelSelectionNeedsReselection) {
      return '旧任务使用模型 $_retryModelIdHint，请重新选择供应商和模型';
    }
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
    _retryModelIdHint = null;
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
            border: Border.all(color: cs.error.withValues(alpha: 0.3)),
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
                child: const Text('去配置', style: TextStyle(fontSize: 12)),
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
              child: Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: cs.primary,
              ),
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
                    onChanged: _hasReusablePageResults
                        ? null
                        : (idx) {
                            if (idx == null || idx >= modelOptions.length)
                              return;
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
    final clamped =
        rawIndex == -2 || ocrOutputTemplateForSelection(rawIndex) != null
            ? rawIndex
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
                    onChanged: _hasReusablePageResults
                        ? null
                        : (idx) {
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
                      ...ocrOutputTemplates.map((template) {
                        return DropdownMenuItem<int>(
                          value: template.selectionValue,
                          child: Text(
                            template.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
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
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => OcrInstructionManageDialog(
                    onInstructionDeleted: (deletedIndex) {
                      if (mounted &&
                          deletedIndex == _selectedInstructionIndex) {
                        setState(() => _selectedInstructionIndex = -1);
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchOptions(ColorScheme cs) {
    if (_selectedImages.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '批量方式',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SegmentedButton<OcrBatchMode>(
                    key: const Key('ocr_batch_mode'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: OcrBatchMode.joint,
                        label: Text('合并识别'),
                      ),
                      ButtonSegment(
                        value: OcrBatchMode.perImage,
                        label: Text('逐张识别'),
                      ),
                    ],
                    selected: {_batchMode},
                    onSelectionChanged: _isProcessing || _hasReusablePageResults
                        ? null
                        : (selection) {
                            if (selection.isEmpty) return;
                            setState(() {
                              _batchMode = selection.first;
                              _errorMessage = null;
                            });
                          },
                  ),
                ),
                if (_batchMode == OcrBatchMode.perImage)
                  PopupMenuButton<int>(
                    key: const Key('ocr_per_image_concurrency'),
                    enabled: !_isProcessing,
                    tooltip: '最多 2 张同时请求',
                    onSelected: (concurrency) =>
                        setState(() => _perImageConcurrency = concurrency),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 1, child: Text('1 张同时请求')),
                      PopupMenuItem(value: 2, child: Text('2 张同时请求')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('并发 $_perImageConcurrency'),
                    ),
                  ),
              ],
            ),
            if (_hasReusablePageResults) ...[
              const SizedBox(height: 6),
              Text(
                '已完成的页面会保留，重试时只会提交未完成的页面。',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSourceBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isImageSelectionLocked ? null : _showCameraChoicePanel,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text(
                      '拍照识别',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing || _isRetryImagesLoading
                        ? null
                        : _showAlbumChoicePanel,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: const Text(
                      '相册选择',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: '开启后，系统相机会和相册不限制图片尺寸或 JPEG 质量；应用相册使用原始文件。',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _useOriginalImageQuality ? '原图 / 高细节' : '标准画质',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                  Switch(
                    key: const Key('ocr_high_detail_switch'),
                    value: _useOriginalImageQuality,
                    onChanged: _isProcessing
                        ? null
                        : (value) =>
                            setState(() => _useOriginalImageQuality = value),
                  ),
                ],
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
                          maxSimultaneousDrags: _isImageSelectionLocked ? 0 : 1,
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
                          child: IgnorePointer(
                            ignoring: _isImageSelectionLocked,
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
    if (_isImageSelectionLocked) return;
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

  String _retryReselectAllMessage(int requiredCount) =>
      '请重新选择全部 $requiredCount 张图片后重试';

  void _updateRetryImageReselectionState() {
    final requiredCount = _requiredRetryImageCount;
    if (requiredCount == null) return;
    if (_isRetryImageReselectionPending) {
      if (_selectedImages.length == requiredCount) {
        _isRetryImageReselectionPending = false;
        _retryImagesUnavailable = false;
        _errorMessage = null;
      } else {
        _retryImagesUnavailable = true;
        _errorMessage = _retryReselectAllMessage(requiredCount);
      }
    } else if (!_retryImagesUnavailable) {
      _errorMessage = _retryImageCountMismatch
          ? _retryReselectAllMessage(requiredCount)
          : null;
    }
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
                    enabled: !_isImageSelectionLocked,
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
                    onPressed: _isImageSelectionLocked
                        ? null
                        : () => _removeImage(index),
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
          if (!_retryImagesUnavailable && !_retryImageCountMismatch)
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
                onPressed: _selectedImages.isEmpty ||
                        _isProcessing ||
                        _isImageImportPending ||
                        _isRetryImagesLoading ||
                        _retryImagesUnavailable ||
                        _retryImageCountMismatch
                    ? null
                    : _startOcr,
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
                  _isProcessing
                      ? _isPreparingRetryData
                          ? '保存重试图片...'
                          : '识别中...'
                      : _isRetryImagesLoading
                          ? '读取重试图片...'
                          : _isImageImportPending
                              ? '正在导入图片...'
                              : '开始识别',
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
    final importGeneration = ++_imageImportGeneration;
    var importPending = false;
    try {
      final picker = ImagePicker();
      final mode = _imageImportMode;
      final file = await (widget.testCameraPicker?.call(
            maxWidth: mode.maxWidth,
            maxHeight: mode.maxHeight,
            imageQuality: mode.imageQuality,
          ) ??
          picker.pickImage(
            source: ImageSource.camera,
            maxWidth: mode.maxWidth,
            maxHeight: mode.maxHeight,
            imageQuality: mode.imageQuality,
          ));
      if (!mounted ||
          importGeneration != _imageImportGeneration ||
          file == null) {
        return;
      }

      _beginImageImport();
      importPending = true;
      final bytes = await file.readAsBytes();
      if (!mounted || importGeneration != _imageImportGeneration) return;
      final payload = await _prepareImagePayload(bytes);
      if (!mounted || importGeneration != _imageImportGeneration) return;

      setState(() {
        _selectedImages.add(
          SelectedImage.fromPayload(
            payload: payload,
            // Camera: temp file, no source name
          ),
        );
        _updateRetryImageReselectionState();
      });
    } catch (e) {
      if (mounted && importGeneration == _imageImportGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is FormatException ? e.message : '拍照失败: $e'),
          ),
        );
      }
    } finally {
      if (importPending) _finishImageImport();
    }
  }

  /// Pick images from the device gallery (supports batch selection).
  Future<void> _pickFromSystemGallery() async {
    final importGeneration = ++_imageImportGeneration;
    var importPending = false;
    try {
      final mode = _imageImportMode;
      // 原生移动端打开应用内相册选择器，
      // 桌面端打开文件选择器并定位到系统"图片"目录
      final files = await (widget.testGalleryPicker?.call(
            maxWidth: mode.maxWidth,
            maxHeight: mode.maxHeight,
            imageQuality: mode.imageQuality,
          ) ??
          pickGalleryMedia(
            GalleryMediaKind.image,
            context: context,
            imageQuality: mode.imageQuality,
            maxWidth: mode.maxWidth,
            maxHeight: mode.maxHeight,
          ));
      if (!mounted ||
          importGeneration != _imageImportGeneration ||
          files.isEmpty) {
        return;
      }

      _beginImageImport();
      importPending = true;
      final newImages = <SelectedImage>[];
      String? firstError;
      for (final file in files) {
        if (!mounted || importGeneration != _imageImportGeneration) return;
        try {
          final bytes = await file.readAsBytes();
          if (!mounted || importGeneration != _imageImportGeneration) return;
          var payload = await _prepareImagePayload(bytes);
          if (!mounted || importGeneration != _imageImportGeneration) return;
          if (!SystemPickDirectories.isMobile &&
              mode == OcrImageImportMode.standard) {
            payload = await applyOcrImageImportQuality(
              payload,
              maxWidth: mode.maxWidth,
              maxHeight: mode.maxHeight,
              imageQuality: mode.imageQuality,
            );
            if (!mounted || importGeneration != _imageImportGeneration) {
              return;
            }
          }
          newImages.add(
            SelectedImage.fromPayload(payload: payload, sourceName: file.name),
          );
        } on FormatException catch (error) {
          firstError ??= error.message;
        }
        if (!mounted || importGeneration != _imageImportGeneration) return;
      }

      if (!mounted || importGeneration != _imageImportGeneration) return;
      setState(() {
        _selectedImages.addAll(newImages);
        _errorMessage = firstError ??
            (_retryImagesUnavailable
                ? (_requiredRetryImageCount == null
                    ? _retryUnavailableMessage
                    : _retryReselectAllMessage(_requiredRetryImageCount!))
                : null);
        _updateRetryImageReselectionState();
      });
      if (firstError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(firstError)));
      }
    } catch (e) {
      if (mounted && importGeneration == _imageImportGeneration) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    } finally {
      if (importPending) _finishImageImport();
    }
  }

  /// Pick images from the app's album.
  Future<void> _pickFromAppAlbum() async {
    final importGeneration = ++_imageImportGeneration;
    var importPending = false;
    try {
      final result = await showAppAlbumPickerDialog(context);
      if (!mounted ||
          result == null ||
          result.isEmpty ||
          importGeneration != _imageImportGeneration) {
        return;
      }
      _beginImageImport();
      importPending = true;
      var loadedCount = 0;
      for (final entry in result) {
        if (!mounted || importGeneration != _imageImportGeneration) return;
        if (await _handleSelectedImage(
          entry.key,
          entry.value,
          importGeneration: importGeneration,
        )) {
          loadedCount++;
        }
      }
      if (mounted &&
          importGeneration == _imageImportGeneration &&
          loadedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已加载 $loadedCount 张图片'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted && importGeneration == _imageImportGeneration) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    } finally {
      if (importPending) _finishImageImport();
    }
  }

  /// Handle a selected image from the album picker.
  Future<bool> _handleSelectedImage(
    String fileName,
    Uint8List data, {
    required int importGeneration,
  }) async {
    if (!mounted || importGeneration != _imageImportGeneration) return false;
    try {
      final payload = await _prepareImagePayload(data);
      if (!mounted || importGeneration != _imageImportGeneration) {
        return false;
      }
      setState(() {
        _selectedImages.add(
          SelectedImage.fromPayload(
            payload: payload,
            sourceName: fileName, // App album file has original name
          ),
        );
        _updateRetryImageReselectionState();
      });
      return true;
    } catch (e) {
      if (mounted && importGeneration == _imageImportGeneration) {
        final message = e is FormatException ? e.message : '处理图片失败: $e';
        setState(() => _errorMessage = message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    }
  }

  // ==================================================================
  // Image Reorder & Preview
  // ==================================================================

  void _onReorder(int oldIndex, int newIndex) {
    if (_isImageSelectionLocked) return;
    setState(() {
      // onReorderItem 的 newIndex 已是移除后的索引，直接使用
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  Future<void> _previewImage(int index) async {
    if (_isImageSelectionLocked ||
        index < 0 ||
        index >= _selectedImages.length) {
      return;
    }

    // Full-screen preview with left/right swipe paging — the same
    // interaction as the file page's gallery viewer. Pops with the
    // tapped action and the index of the image that was being viewed
    // (which may differ from [index] after swiping).
    final result = await showDialog<({String action, int index})>(
      context: context,
      builder: (_) =>
          _OcrPreviewDialog(images: _selectedImages, initialIndex: index),
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
    await _applyEditedImage(currentImage, editedBytes);
  }

  /// Applies [editedBytes] to the same selected image, even if it was moved
  /// while the edited payload was being validated.
  Future<void> _applyEditedImage(
    SelectedImage currentImage,
    Uint8List editedBytes,
  ) async {
    if (!mounted ||
        _isImageSelectionLocked ||
        !_selectedImages.any((image) => identical(image, currentImage))) {
      return;
    }

    try {
      final payload = await _prepareImagePayload(editedBytes);
      if (!mounted) return;
      final currentIndex = _selectedImages.indexWhere(
        (image) => identical(image, currentImage),
      );
      if (currentIndex < 0) return;
      setState(() {
        _selectedImages[currentIndex] = currentImage.withEditedPayload(payload);
      });
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _removeImage(int index) {
    if (_isImageSelectionLocked ||
        index < 0 ||
        index >= _selectedImages.length) {
      return;
    }
    setState(() {
      _selectedImages.removeAt(index);
      _updateRetryImageReselectionState();
    });
  }

  Future<void> _clearAll() async {
    if (_isProcessing ||
        _isRetryImagesLoading ||
        (_hasReusablePageResults && !_retryImagesUnavailable)) {
      return;
    }
    final imageCountUnknown = _retryImageCountUnknown;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('ocr_clear_confirmation_dialog'),
        title: Text(imageCountUnknown ? '无法确认原图片数量' : '确认清空'),
        content: Text(
          imageCountUnknown
              ? '原始 OCR 图片缓存不可用，且图片数量无法恢复。确认后会清空旧重试状态，请重新选择本次 OCR 的全部图片。'
              : '确定清空已选择的 OCR 图片吗？',
        ),
        actions: [
          TextButton(
            key: const Key('ocr_cancel_clear'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('ocr_confirm_clear'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(imageCountUnknown ? '确认重置并重新选择' : '确认清空'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (_isProcessing ||
        _isRetryImagesLoading ||
        (_hasReusablePageResults && !_retryImagesUnavailable)) {
      return;
    }
    final resetReusableResults =
        _retryImagesUnavailable && _hasReusablePageResults;
    _imageImportGeneration++;
    setState(() {
      _selectedImages.clear();
      if (resetReusableResults) _retryPageOutcomes.clear();
      _retryImageCountUnknown = false;
      _isRetryImageReselectionPending = _requiredRetryImageCount != null;
      _retryImagesUnavailable = _isRetryImageReselectionPending;
      _errorMessage = imageCountUnknown
          ? _retryImageResetMessage
          : _requiredRetryImageCount == null
              ? null
              : _retryReselectAllMessage(_requiredRetryImageCount!);
    });
  }

  // ==================================================================
  // OCR Processing
  // ==================================================================

  int? _requestSizeBudgetBytes(String value) {
    final mebibytes = double.tryParse(value.trim());
    if (mebibytes == null || !mebibytes.isFinite || mebibytes <= 0) {
      return null;
    }
    final byteValue = mebibytes * 1024 * 1024;
    if (!byteValue.isFinite || byteValue > 9007199254740991) return null;
    final bytes = byteValue.round();
    return bytes > 0 ? bytes : null;
  }

  String _formatRequestSizeMib(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(2);

  Future<void> _editRequestSizeBudget() async {
    final previousValue = _requestSizeBudgetMiBController.text;
    var invalidInput = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('请求大小上限'),
          content: TextField(
            key: const Key('ocr_request_budget_editor_mib'),
            controller: _requestSizeBudgetMiBController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'JSON 请求上限',
              suffixText: 'MiB',
              border: const OutlineInputBorder(),
              errorText: invalidInput ? '请输入大于 0 的 MiB 数值' : null,
            ),
            onChanged: (_) {
              if (invalidInput) setDialogState(() => invalidInput = false);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              key: const Key('ocr_save_request_budget'),
              onPressed: () {
                if (_requestSizeBudgetBytes(
                      _requestSizeBudgetMiBController.text,
                    ) ==
                    null) {
                  setDialogState(() => invalidInput = true);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (accepted != true) {
      _requestSizeBudgetMiBController.text = previousValue;
      return;
    }
    setState(() => _errorMessage = null);
  }

  Future<int?> _preflightRequestSize(
    OcrConfig config,
    List<SelectedImage> images,
  ) async {
    final initialBudgetBytes = _requestSizeBudgetBytes(
      _requestSizeBudgetMiBController.text,
    );
    if (initialBudgetBytes == null) {
      if (mounted) {
        setState(() => _errorMessage = '请求上限必须是大于 0 的 MiB 数值');
      }
      return null;
    }
    var budgetBytes = initialBudgetBytes;

    final imageBytesList =
        images.map((image) => (image.bytes, image.format)).toList();
    final reusablePageIndices = _retryPageOutcomes
        .where((outcome) => outcome.canReuseResult)
        .map((outcome) => outcome.imageIndex)
        .toSet();
    while (mounted) {
      final service = OcrService(
        config: config.copyWith(requestSizeBudgetBytes: budgetBytes),
      );
      late final int encodedBytes;
      try {
        final requestSizes = _batchMode == OcrBatchMode.joint
            ? [service.encodedRequestSizeBytes(imageBytesList: imageBytesList)]
            : [
                for (var index = 0; index < imageBytesList.length; index++)
                  if (!reusablePageIndices.contains(index))
                    service.encodedRequestSizeBytes(
                      imageBytesList: [imageBytesList[index]],
                    ),
              ];
        encodedBytes = requestSizes.fold<int>(
          0,
          (largest, size) => size > largest ? size : largest,
        );
      } catch (error) {
        if (mounted) {
          setState(() => _errorMessage = '无法检查 OCR 请求，请检查模型参数');
        }
        debugPrint(
          '[OCR] Request size check failed: ' + error.runtimeType.toString(),
        );
        return null;
      } finally {
        service.close();
      }

      if (encodedBytes <= budgetBytes) return budgetBytes;
      final choice = await _showRequestSizeLimitDialog(
        encodedBytes: encodedBytes,
        budgetBytes: budgetBytes,
        canSwitchToPerImage: _batchMode == OcrBatchMode.joint &&
            images.length > 1 &&
            !_hasReusablePageResults,
      );
      if (!mounted) return null;
      if (choice == null) {
        setState(() => _errorMessage = '本次识别已取消；可切换识别方式或提高请求上限后重试。');
        return null;
      }
      if (choice.$1) {
        final updatedBudget = _requestSizeBudgetBytes(choice.$2 ?? '');
        if (updatedBudget == null) {
          setState(() => _errorMessage = '请求上限必须是大于 0 的 MiB 数值');
          return null;
        }
        _requestSizeBudgetMiBController.text = choice.$2!.trim();
        budgetBytes = updatedBudget;
        setState(() {
          _batchMode = OcrBatchMode.perImage;
          _errorMessage = null;
        });
        continue;
      }

      final updatedBudget = _requestSizeBudgetBytes(choice.$2 ?? '');
      if (updatedBudget == null) {
        setState(() => _errorMessage = '请求上限必须是大于 0 的 MiB 数值');
        return null;
      }
      _requestSizeBudgetMiBController.text = choice.$2!.trim();
      budgetBytes = updatedBudget;
    }
    return null;
  }

  Future<(bool, String?)?> _showRequestSizeLimitDialog({
    required int encodedBytes,
    required int budgetBytes,
    required bool canSwitchToPerImage,
  }) async {
    var invalidInput = false;
    return await showDialog<(bool, String?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('OCR 请求超过大小上限'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前 JSON 请求约为 ' +
                    _formatRequestSizeMib(encodedBytes) +
                    ' MiB，超过 ' +
                    _formatRequestSizeMib(budgetBytes) +
                    ' MiB 上限。',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ocr_request_budget_dialog_mib'),
                controller: _requestSizeBudgetMiBController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '新上限',
                  suffixText: 'MiB',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (invalidInput) {
                    setDialogState(() => invalidInput = false);
                  }
                },
              ),
              if (invalidInput)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '请输入大于 0 的 MiB 数值',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            if (canSwitchToPerImage)
              TextButton(
                key: const Key('ocr_switch_to_per_image'),
                onPressed: () {
                  if (_requestSizeBudgetBytes(
                        _requestSizeBudgetMiBController.text,
                      ) ==
                      null) {
                    setDialogState(() => invalidInput = true);
                    return;
                  }
                  Navigator.pop(dialogContext, (
                    true,
                    _requestSizeBudgetMiBController.text.trim(),
                  ));
                },
                child: const Text('改用逐张识别'),
              ),
            TextButton(
              key: const Key('ocr_change_request_budget'),
              onPressed: () {
                if (_requestSizeBudgetBytes(
                      _requestSizeBudgetMiBController.text,
                    ) ==
                    null) {
                  setDialogState(() => invalidInput = true);
                  return;
                }
                Navigator.pop(dialogContext, (
                  false,
                  _requestSizeBudgetMiBController.text.trim(),
                ));
              },
              child: const Text('更改上限'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startOcr() async {
    if (_ocrStarting || _isProcessing) return;
    if (_isImageImportPending) {
      setState(() => _errorMessage = '请等待图片导入完成后再开始识别');
      return;
    }
    if (_isRetryImagesLoading) {
      setState(() => _errorMessage = '正在读取重试图片，请稍候');
      return;
    }
    if (_retryImageCountMismatch) {
      setState(() {
        _errorMessage = _retryReselectAllMessage(_requiredRetryImageCount!);
      });
      return;
    }
    if (_retryImagesUnavailable) {
      setState(() => _errorMessage = _retryUnavailableMessage);
      return;
    }
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
    final sourceImages = List<SelectedImage>.of(_selectedImages);
    final images = <SelectedImage>[];
    try {
      for (final image in sourceImages) {
        if (image.isPrepared) {
          images.add(image);
        } else {
          images.add(
            SelectedImage.fromPayload(
              payload: await _prepareImagePayload(image.bytes),
              sourceName: image.sourceName,
            ),
          );
        }
      }
    } on FormatException catch (error) {
      _ocrStarting = false;
      if (mounted) {
        final retryImageCount = widget.retryData == null
            ? 0
            : OcrRetrySnapshot.fromMap(widget.retryData!).imageEntryCount;
        if (widget.retryData == null && widget.retryTaskId == null) {
          setState(() => _errorMessage = error.message);
        } else {
          setState(() {
            _retryImagesUnavailable = true;
            _retryImageCountUnknown = retryImageCount == 0;
            _requiredRetryImageCount =
                retryImageCount == 0 ? null : retryImageCount;
            _isRetryImageReselectionPending = false;
            _errorMessage = retryImageCount == 0
                ? _retryImageCountUnknownMessage
                : '原始 OCR 图片缓存已丢失或损坏，请清空并重新选择全部图片后重试';
          });
        }
      }
      return;
    } catch (error) {
      _ocrStarting = false;
      if (mounted) {
        setState(() => _errorMessage = '处理 OCR 图片失败，请重试');
      }
      debugPrint('[OCR] Image preparation failed: ${error.runtimeType}');
      return;
    }
    if (!mounted) return;
    var selectionChanged = _selectedImages.length != sourceImages.length;
    if (!selectionChanged) {
      for (var index = 0; index < sourceImages.length; index++) {
        if (!identical(_selectedImages[index], sourceImages[index])) {
          selectionChanged = true;
          break;
        }
      }
    }
    if (selectionChanged) {
      _ocrStarting = false;
      setState(() => _errorMessage = '图片列表已变化，请重新开始识别。');
      return;
    }
    setState(() {
      _selectedImages
        ..clear()
        ..addAll(images);
      _errorMessage = null;
      _isProcessing = true;
      _isPreparingRetryData = true;
    });
    final folder = _saveFolder;

    // Build config from the selected model's own source config,
    // ensuring host/API key match the model's provider.
    // Also passes through the model's typeConfig and customParams
    // for built-in OCR parameters and custom parameters.
    final selectedOption = modelOptions[modelIndex];
    _selectedModelIndex = modelIndex;
    _selectedConfigId = selectedOption.configId;
    _selectedModelRecordId = selectedOption.modelRecordId;
    final requestSizeBudgetBytes = _requestSizeBudgetBytes(
      _requestSizeBudgetMiBController.text,
    );
    if (requestSizeBudgetBytes == null) {
      _ocrStarting = false;
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isPreparingRetryData = false;
          _errorMessage = '请求上限必须是大于 0 的 MiB 数值';
        });
      }
      return;
    }
    var effectiveConfig = OcrConfig(
      host: selectedOption.host,
      apiKey: selectedOption.apiKey,
      model: selectedOption.model.modelId,
      requestSizeBudgetBytes: requestSizeBudgetBytes,
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
      } catch (error) {
        _ocrStarting = false;
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _isPreparingRetryData = false;
            _errorMessage = '读取识别指令失败，请重试';
          });
        }
        debugPrint('[OCR] Failed to restore retry instruction: $error');
        return;
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

    final effectiveBudgetBytes = await _preflightRequestSize(
      effectiveConfig,
      images,
    );
    if (!mounted) return;
    if (effectiveBudgetBytes == null) {
      _ocrStarting = false;
      setState(() {
        _isProcessing = false;
        _isPreparingRetryData = false;
      });
      return;
    }
    effectiveConfig = effectiveConfig.copyWith(
      requestSizeBudgetBytes: effectiveBudgetBytes,
    );

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
    // Save the exact instruction and destination along with the stable model
    // reference so later list edits cannot change this retry's request.
    final instructionContent = _retryInstructionSnapshot ??
        selectedOcrInstructionContent(instructions, _selectedInstructionIndex);
    // Store the retry images before publishing the task or starting its
    // request. A failed request can then never expose a retry action while its
    // snapshot is still being written.
    final taskId = const Uuid().v4();
    final taskPublished = await OcrRetryStorage.withCacheMaintenanceLock(
      () async {
        final retryData = await _computeOcrRetryData(
          taskId,
          imageBytesList,
          imageFormatList,
          imageNameList,
          selectedOption.configId,
          selectedOption.modelRecordId,
          instructionContent,
          folder,
          _batchMode,
          _perImageConcurrency,
          effectiveConfig.requestSizeBudgetBytes,
        );
        if (!mounted || !bgNotifier.mounted) {
          final remainingTasks =
              bgNotifier.mounted ? bgNotifier.state : const <BackgroundTask>[];
          try {
            await OcrRetryStorage.deleteUnreferenced(
              candidates: OcrRetryStorage.referencesFromSnapshot(retryData),
              referenced: {
                for (final task in remainingTasks)
                  if (task.type == BackgroundTaskType.ocr)
                    ...OcrRetryStorage.referencesFromSnapshot(task.retryData),
              },
            );
          } catch (error) {
            debugPrint(
              '[OCR] Failed to clean an unused retry snapshot: $error',
            );
          }
          return false;
        }
        setState(() => _isPreparingRetryData = false);

        bgNotifier.addTask(
          type: BackgroundTaskType.ocr,
          title: title,
          retryData: retryData,
          taskId: taskId,
        );
        return true;
      },
    );
    if (!taskPublished) return;

    final runner = OcrTaskRunner(
      taskId: taskId,
      notifier: bgNotifier,
      config: effectiveConfig,
      images: images.map((img) => (img.bytes, img.format)).toList(),
      imageNames: imageNameList,
      executionMode: _batchMode,
      perImageConcurrency: _perImageConcurrency,
      initialPageOutcomes: _retryPageOutcomes,
      title: title,
      folder: folder,
      onSaved: () => unawaited(textNotifier.loadRecords()),
      serviceFactory: widget.testOcrServiceFactory,
    );

    unawaited(runner.run());
    Navigator.pop(context);
  }

  /// Cache task-owned images before starting OCR so a failed request cannot
  /// be retried while its image snapshot is still being written.
  Future<Map<String, dynamic>> _computeOcrRetryData(
    String taskId,
    List<Uint8List> imageBytesList,
    List<String> imageFormatList,
    List<String?> imageNameList,
    String configId,
    String modelId,
    String? instructionContent,
    String saveFolder,
    OcrBatchMode batchMode,
    int perImageConcurrency,
    int requestSizeBudgetBytes,
  ) async {
    final snapshot = OcrRetrySnapshot.capture(
      configId: configId,
      modelId: modelId,
      images: [
        for (var index = 0; index < imageBytesList.length; index++)
          OcrRetryImage(
            bytes: imageBytesList[index],
            format: imageFormatList[index],
            name: imageNameList[index],
          ),
      ],
      instructionContent: instructionContent,
      saveFolder: saveFolder,
      batchMode: batchMode,
      perImageConcurrency: perImageConcurrency,
      requestSizeBudgetBytes: requestSizeBudgetBytes,
    );
    try {
      final retryData = await (widget.testRetrySnapshotCacher?.call(
            taskId: taskId,
            snapshot: snapshot,
          ) ??
          OcrRetryStorage.cacheSnapshot(
            taskId: taskId,
            snapshot: snapshot,
          ));
      return retryData ??
          OcrRetryStorage.unavailableSnapshot(
            taskId: taskId,
            snapshot: snapshot,
          );
    } catch (error) {
      debugPrint('[OCR] Failed to cache retry images: $error');
      return OcrRetryStorage.unavailableSnapshot(
        taskId: taskId,
        snapshot: snapshot,
      );
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

  const _OcrPreviewDialog({required this.images, required this.initialIndex});

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
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '无法加载图片',
                                style: TextStyle(color: Colors.white54),
                              ),
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
