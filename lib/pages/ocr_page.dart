import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:extended_image/extended_image.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_localizations.dart';
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
import '../utils/ocr_diagnostics.dart';
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
  final int requestSizeBudgetBytes;
  const _ModelOption(
    this.model,
    this.configId,
    this.modelRecordId,
    this.providerName,
    this.host,
    this.apiKey,
    this.requestSizeBudgetBytes,
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
        effectiveOcrRequestSizeBudgetBytes(
          modelValue: e.model.typeConfig['requestSizeBudgetBytes'],
          providerValue: e.config.typeConfig['requestSizeBudgetBytes'],
        ),
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
    List<OcrInstruction> instructions, int selectionValue,
    {AppLocalizations? strings}) {
  final template =
      ocrOutputTemplateForSelection(selectionValue, strings: strings);
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
    {AppLocalizations? strings}) {
  final selectedContent = selectedOcrInstructionContent(
    instructions,
    selectionValue,
    strings: strings,
  );
  final content =
      ocrOutputTemplateForSelection(selectionValue, strings: strings) == null
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
    this.retryTaskGeneration,
    this.testCameraPicker,
    this.testGalleryPicker,
    this.testImagePayloadPreparer,
    this.testRequestSizePreflight,
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
  final Future<int?> Function(OcrConfig config, List<SelectedImage> images)?
      testRequestSizePreflight;
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

  /// Source task generation captured by the caller that supplied [retryData].
  final BackgroundTask? retryTaskGeneration;
  final List<OcrPageOutcome> retryPageOutcomes;

  @override
  ConsumerState<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends ConsumerState<OcrPage> {
  String get _retryImagesUnavailableMessage =>
      AppLocalizations.of(context)!.ocrRetryImagesUnavailable;
  String get _retryImageCountUnknownMessage =>
      AppLocalizations.of(context)!.ocrRetryImageCountUnknown;
  String get _retryImageResetMessage =>
      AppLocalizations.of(context)!.ocrRetryImageReset;

  String get _retryUnavailableMessage => _retryImageCountUnknown
      ? _retryImageCountUnknownMessage
      : _retryImagesUnavailableMessage;

  final List<SelectedImage> _selectedImages = [];
  late List<OcrPageOutcome> _retryPageOutcomes;
  int? _retryRequestSizeBudgetBytes;
  bool _retryRequestSizeBudgetHasStableModelReference = false;
  OcrBatchMode _batchMode = OcrBatchMode.joint;
  int _perImageConcurrency = 1;
  bool _isProcessing = false;
  bool _isPreparingRetryData = false;
  bool _isRetryImagesLoading = false;
  int _pendingImageImports = 0;
  bool get _isImageImportPending => _pendingImageImports > 0;
  // File reads may overlap, but imports are committed in selection order.
  Future<void> _imageImportCommitTail = Future<void>.value();
  bool get _hasReusablePageResults =>
      _retryPageOutcomes.any((outcome) => outcome.canReuseResult);
  bool get _isImageSelectionLocked =>
      _ocrStarting ||
      _isProcessing ||
      _isRetryImagesLoading ||
      _hasReusablePageResults;

  bool _retryImagesUnavailable = false;
  bool _retryImageCountUnknown = false;
  int? _requiredRetryImageCount;
  bool _isRetryImageReselectionPending = false;
  bool get _retryImageCountMismatch =>
      _requiredRetryImageCount != null &&
      _selectedImages.length != _requiredRetryImageCount;

  bool _useOriginalImageQuality = false;
  String? _errorMessageValue;
  String? _lastImageImportErrorMessage;
  bool _isRetryImageResetWarning = false;
  int? _retryImageResetWarningRequiredCount;
  String? get _errorMessage {
    if (!_isRetryImageResetWarning) return _errorMessageValue;
    final requiredCount = _retryImageResetWarningRequiredCount;
    return requiredCount == null
        ? _retryImageResetMessage
        : _retryReselectAllMessage(requiredCount);
  }

  set _errorMessage(String? message) {
    _errorMessageValue = message;
    _isRetryImageResetWarning = false;
    _retryImageResetWarningRequiredCount = null;
    _lastImageImportErrorMessage = null;
  }

  int _selectedModelIndex = 0;
  String? _selectedConfigId;
  String? _selectedModelRecordId;
  String? _retryModelIdHint;
  bool _modelSelectionNeedsReselection = false;
  bool _legacyModelConfirmationPending = false;

  /// Non-negative values index custom instructions; built-in formats use
  /// stable negative values, while -1 keeps the default images-only request.
  int _selectedInstructionIndex = -1;

  /// Keeps a live custom selection stable if async loading prepends entries.
  OcrInstruction? _selectedInstruction;

  /// Instruction index restored from retry data, pending until the generic
  /// instruction list finishes loading. The provider's initial state is
  /// empty until its async load completes, so without this a restored
  /// index would be clamped to the default before the list arrives.
  int? _pendingRetryInstructionIndex;

  /// Exact instruction captured for this retry. It stays authoritative even
  /// when the generic list is later edited or the entry is deleted.
  String? _retryInstructionSnapshot;

  int _instructionIdentityIndex(
    List<OcrInstruction> instructions,
    OcrInstruction selected,
  ) =>
      instructions.indexWhere(
        (instruction) => identical(instruction, selected),
      );

  int _instructionSelectionValue(List<OcrInstruction> instructions) {
    final selected = _selectedInstruction;
    if (selected == null) return _selectedInstructionIndex;
    final index = _instructionIdentityIndex(instructions, selected);
    return index >= 0 ? index : _selectedInstructionIndex;
  }

  /// Whether [_startOcr] is waiting on image preparation or retry-instruction
  /// restoration, blocking a second tap from starting duplicate OCR work.
  bool _ocrStarting = false;

  Future<OcrImagePayload> _prepareImagePayload(Uint8List bytes) =>
      widget.testImagePayloadPreparer?.call(bytes) ??
      prepareOcrImagePayload(bytes);

  String _localizedImagePreparationError(FormatException error) {
    final strings = AppLocalizations.of(context)!;
    switch (error.message) {
      case '图片为空，请重新选择。':
        return strings.ocrImageEmpty;
      case '不支持此图片格式，请先转换为 PNG、JPEG 或 WebP 后重试。':
        return strings.ocrImageUnsupportedFormat;
      case '暂不支持 HEIC、SVG 或 TIFF 图片，请先转换为 PNG、JPEG 或 WebP 后重试。':
        return strings.ocrImageUnsupportedSpecialFormat;
      case '图片内容损坏或无法解码，请重新选择，或转换为 PNG、JPEG、WebP 后重试。':
        return strings.ocrImageDecodeFailed;
      case '图片分辨率过大，OCR 每张图片最多支持 5000 万像素，请缩小图片后重试。':
        return strings.ocrImageDimensionsTooLarge;
      case '校正图片方向后的 PNG 会超过 OCR 请求大小上限，请先缩小图片后重试。':
        return strings.ocrImageOrientationPngTooLarge;
      case '无法校正图片方向，请转换为 PNG、JPEG 或 WebP 后重试。':
        return strings.ocrImageOrientationFailed;
      case '无法处理图片，请重新选择后重试。':
        return strings.ocrImagePreparationFailed;
      default:
        return error.message;
    }
  }

  void _beginImageImport() {
    if (!mounted) return;
    setState(() => _pendingImageImports++);
  }

  void _finishImageImport() {
    if (!mounted) return;
    setState(() => _pendingImageImports--);
  }

  int _invalidateImageImports() {
    _imageImportCommitTail = Future<void>.value();
    return ++_imageImportGeneration;
  }

  OcrImageImportMode get _imageImportMode => _useOriginalImageQuality
      ? OcrImageImportMode.original
      : OcrImageImportMode.standard;

  /// Whether reorder mode is active
  bool _reorderMode = false;

  /// Invalidates pending image imports after the current selection is cleared.
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
    }
    unawaited(_applyRetryData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.retryTaskId != null &&
        widget.retryData == null &&
        _retryImageCountUnknown &&
        !_isRetryImageResetWarning) {
      _errorMessage = _retryImageCountUnknownMessage;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Pre-populate form from retry data if available.
  Future<void> _applyRetryData() async {
    final data = widget.retryData;
    if (data == null) return;
    final retryTaskId = widget.retryTaskId;
    final retryTaskGeneration = widget.retryTaskGeneration;
    final snapshot = OcrRetrySnapshot.fromMap(data);
    _retryRequestSizeBudgetBytes = snapshot.requestSizeBudgetBytes;
    _retryRequestSizeBudgetHasStableModelReference =
        (snapshot.version == null ||
                snapshot.version! <= OcrRetrySnapshot.currentVersion) &&
            snapshot.configId != null &&
            snapshot.modelId != null;
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
      unawaited(
        _resolvePendingRetryInstruction().catchError((Object error) {
          _handleRetryInstructionLoadFailure(error);
        }),
      );
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
            : AppLocalizations.of(context)!.ocrRetryImagesUnreadable;
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
            : AppLocalizations.of(context)!.ocrRetryImagesMissing;
      }
    });

    if (canUseRestoredImages &&
        widget.retryTaskId != null &&
        snapshot.needsMigration) {
      unawaited(
        _migrateRetrySnapshot(
          retryTaskId!,
          retryTaskGeneration,
          snapshot,
          ref.read(backgroundTasksProvider.notifier),
        ),
      );
    }
  }

  Future<void> _migrateRetrySnapshot(
    String taskId,
    BackgroundTask? taskGeneration,
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
        if (notifier.mounted &&
            taskGeneration != null &&
            notifier.state.any(
              (task) =>
                  task.id == taskId && task.hasSameGenerationAs(taskGeneration),
            )) {
          await notifier.setRetryDataAndWaitForGeneration(
            taskId,
            taskGeneration,
            retryData,
          );
          return;
        }
        final referenced =
            notifier.ocrCacheReferencesFromLoadedSnapshotForCleanup();
        if (referenced == null) return;
        await OcrRetryStorage.deleteUnreferenced(
          candidates: OcrRetryStorage.referencesFromSnapshot(retryData),
          referenced: referenced,
        );
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

  void _handleRetryInstructionLoadFailure(Object error) {
    if (!mounted) return;
    final message = AppLocalizations.of(context)!.ocrReadInstructionFailed;
    final alreadyReported = _errorMessage == message;
    setState(() {
      _ocrStarting = false;
      _isProcessing = false;
      _isPreparingRetryData = false;
      if (!alreadyReported) _errorMessage = message;
    });
    if (!alreadyReported) {
      debugPrint('[OCR] Failed to restore retry instruction: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(providerEntriesProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.ocrPageTitle),
        centerTitle: true,
        actions: [
          PopupMenuButton<bool>(
            key: const Key('ocr_page_settings'),
            tooltip: AppLocalizations.of(context)!.ocrImageQualitySettings,
            enabled: !_isProcessing,
            onSelected: (useOriginal) =>
                setState(() => _useOriginalImageQuality = useOriginal),
            itemBuilder: (context) => [
              CheckedPopupMenuItem<bool>(
                value: false,
                checked: !_useOriginalImageQuality,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context)!.ocrImageQualityStandard),
                    Text(
                        AppLocalizations.of(context)!
                            .ocrImageQualityStandardHint,
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              CheckedPopupMenuItem<bool>(
                value: true,
                checked: _useOriginalImageQuality,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context)!.ocrImageQualityOriginal),
                    Text(
                        AppLocalizations.of(context)!
                            .ocrImageQualityOriginalHint,
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.settings_outlined),
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
              label: Text(_reorderMode
                  ? AppLocalizations.of(context)!.ocrReorderDone
                  : AppLocalizations.of(context)!.ocrReorderAction),
            ),
          if ((_selectedImages.isNotEmpty || _retryImagesUnavailable) &&
              !_isProcessing &&
              !_isRetryImagesLoading &&
              (!_hasReusablePageResults || _retryImagesUnavailable) &&
              !_reorderMode)
            IconButton(
              key: const Key('ocr_clear_button'),
              tooltip: AppLocalizations.of(context)!.ocrClearAction,
              onPressed: _ocrStarting ? null : _clearAll,
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

          // Batch mode
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
    if (!_legacyModelConfirmationPending) {
      // Give the default first-option selection a stable reference before
      // provider updates can reorder or remove its position.
      final initiallySelectedOption = modelOptions[_selectedModelIndex];
      _selectedConfigId = initiallySelectedOption.configId;
      _selectedModelRecordId = initiallySelectedOption.modelRecordId;
      return _selectedModelOptionIndex(modelOptions);
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
      return AppLocalizations.of(context)!
          .ocrLegacyModelHint(_retryModelIdHint!);
    }
    if (_legacyModelConfirmationPending) {
      return selectedIndex == null
          ? AppLocalizations.of(context)!.ocrLegacyModelPositionInvalid
          : AppLocalizations.of(context)!.ocrLegacyModelPositionConfirm;
    }
    if (_modelSelectionNeedsReselection ||
        (_selectedConfigId != null && selectedIndex == null) ||
        (_selectedModelRecordId != null && selectedIndex == null)) {
      return AppLocalizations.of(context)!.ocrModelUnavailable;
    }
    return null;
  }

  void _selectModelOption(_ModelOption option, int index) {
    final retryModelChanged = _retryRequestSizeBudgetBytes != null &&
        (!_retryRequestSizeBudgetHasStableModelReference ||
            option.configId != _selectedConfigId ||
            option.modelRecordId != _selectedModelRecordId);
    if (retryModelChanged) {
      _retryRequestSizeBudgetBytes = null;
      _retryRequestSizeBudgetHasStableModelReference = false;
    }
    _selectedModelIndex = index;
    _selectedConfigId = option.configId;
    _selectedModelRecordId = option.modelRecordId;
    _retryModelIdHint = null;
    _modelSelectionNeedsReselection = false;
    _legacyModelConfirmationPending = false;
  }

  void _clearOcrErrorDetails() {
    _lastRawRequest = null;
    _lastRawResponse = null;
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
                  AppLocalizations.of(context)!.ocrModelLabel,
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
                child: Text(
                  AppLocalizations.of(context)!.ocrConfigure,
                  style: const TextStyle(fontSize: 12),
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
        // Keep the 34dp model row the same outer height as the 40dp
        // instruction row and its settings tap target.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
              AppLocalizations.of(context)!.ocrModelLabel,
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
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    dropdownColor: StroomMenuStyle.surface(context),
                    borderRadius: StroomMenuStyle.borderRadius,
                    value: selectedIndex,
                    hint: selectedIndex == null
                        ? Text(_modelSelectionMessage(selectedIndex) ??
                            AppLocalizations.of(context)!.ocrSelectModel)
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
                    onChanged:
                        _ocrStarting || _isProcessing || _hasReusablePageResults
                            ? null
                            : (idx) {
                                if (idx == null || idx >= modelOptions.length)
                                  return;
                                setState(() {
                                  _selectModelOption(modelOptions[idx], idx);
                                  _errorMessage = null;
                                  _clearOcrErrorDetails();
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
    final selectedModelIndex = _selectedModelOptionIndex(modelOptions);
    if (selectedModelIndex == null || modelOptions.isEmpty) {
      return const SizedBox.shrink();
    }
    final instructions = ref.watch(ocrInstructionsProvider);
    ref.listen(ocrInstructionsProvider, (previous, next) {
      final selected = _selectedInstruction;
      if (selected == null ||
          previous == null ||
          _instructionIdentityIndex(next, selected) >= 0) {
        return;
      }
      final selectedIndex = _instructionIdentityIndex(previous, selected);
      if (selectedIndex >= 0 &&
          previous.length == next.length &&
          selectedIndex < next.length) {
        // Editing replaces the value in place. Carry the live selection over
        // that replacement so a later async prepend can still resolve it.
        setState(() {
          _selectedInstruction = next[selectedIndex];
          _selectedInstructionIndex = selectedIndex;
        });
      }
    });

    // A captured instruction stays selected even when it no longer exists in
    // the editable generic list. Legacy index-only restore waits for the list
    // to load before resolving its position.
    final pending = _pendingRetryInstructionIndex;
    final rawIndex = _retryInstructionSnapshot != null
        ? -2
        : (pending ?? _instructionSelectionValue(instructions));
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
              AppLocalizations.of(context)!.ocrInstructionLabel,
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
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    dropdownColor: StroomMenuStyle.surface(context),
                    borderRadius: StroomMenuStyle.borderRadius,
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
                    onChanged: _ocrStarting ||
                            _isProcessing ||
                            _hasReusablePageResults
                        ? null
                        : (idx) {
                            if (idx == null) return;
                            setState(() {
                              _selectedInstructionIndex = idx;
                              _selectedInstruction =
                                  idx >= 0 ? instructions[idx] : null;
                              if (idx != -2) _retryInstructionSnapshot = null;
                              // An explicit user choice wins over a pending
                              // retry restore.
                              _pendingRetryInstructionIndex = null;
                            });
                          },
                    items: [
                      DropdownMenuItem<int>(
                        value: -1,
                        child: Text(
                          AppLocalizations.of(context)!.ocrDefaultImagesOnly,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_retryInstructionSnapshot != null)
                        DropdownMenuItem<int>(
                          value: -2,
                          child: Text(
                            AppLocalizations.of(context)!
                                .ocrSavedInstructionSnapshot,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ...localizedOcrOutputTemplates(
                        AppLocalizations.of(context)!,
                      ).map((template) {
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
            Transform.translate(
              // Balance the icon's visible inset against the leading icon
              // while keeping the 40px touch target inside the card edge.
              offset: const Offset(6, 0),
              child: IconButton(
                key: const Key('ocr_instruction_manage_btn'),
                icon: Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                tooltip: AppLocalizations.of(context)!.ocrManageInstructions,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                onPressed: _ocrStarting ||
                        _isProcessing ||
                        _hasReusablePageResults
                    ? null
                    : () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => OcrInstructionManageDialog(
                            onInstructionDeleted: (deletedIndex) {
                              if (!mounted) return;
                              final selected = _selectedInstruction;
                              if (selected != null) {
                                final currentInstructions = ref.read(
                                  ocrInstructionsProvider,
                                );
                                final selectedIndex = _instructionIdentityIndex(
                                  currentInstructions,
                                  selected,
                                );
                                if (selectedIndex < 0) {
                                  setState(() {
                                    _selectedInstruction = null;
                                    _selectedInstructionIndex = -1;
                                  });
                                } else {
                                  setState(() {
                                    _selectedInstructionIndex = selectedIndex;
                                  });
                                }
                                return;
                              }
                              if (deletedIndex == _selectedInstructionIndex) {
                                setState(
                                  () => _selectedInstructionIndex = -1,
                                );
                              } else if (deletedIndex <
                                  _selectedInstructionIndex) {
                                setState(() => _selectedInstructionIndex--);
                              }
                            },
                          ),
                        );
                      },
              ),
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
                  AppLocalizations.of(context)!.ocrBatchMode,
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
                    segments: [
                      ButtonSegment(
                        value: OcrBatchMode.joint,
                        label: Text(
                            AppLocalizations.of(context)!.ocrMergeRecognition),
                      ),
                      ButtonSegment(
                        value: OcrBatchMode.perImage,
                        label: Text(AppLocalizations.of(context)!
                            .ocrRecognizeEachImage),
                      ),
                    ],
                    selected: {_batchMode},
                    onSelectionChanged:
                        _ocrStarting || _isProcessing || _hasReusablePageResults
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
                    enabled: !_ocrStarting && !_isProcessing,
                    tooltip: AppLocalizations.of(context)!.ocrMaxConcurrency,
                    onSelected: (concurrency) =>
                        setState(() => _perImageConcurrency = concurrency),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                          value: 1,
                          child: Text(AppLocalizations.of(context)!
                              .ocrConcurrencyOption(1))),
                      PopupMenuItem(
                          value: 2,
                          child: Text(AppLocalizations.of(context)!
                              .ocrConcurrencyOption(2))),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(AppLocalizations.of(context)!
                          .ocrConcurrencyStatus(_perImageConcurrency)),
                    ),
                  ),
              ],
            ),
            if (_hasReusablePageResults) ...[
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context)!.ocrRetryCompletedHint,
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: Text(
                      AppLocalizations.of(context)!.ocrTakePhoto,
                      style: const TextStyle(
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
                    onPressed:
                        _isImageSelectionLocked ? null : _showAlbumChoicePanel,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: Text(
                      AppLocalizations.of(context)!.ocrChooseFromAlbum,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
            AppLocalizations.of(context)!.ocrNoImagesSelected,
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.ocrSelectImagesHint,
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
      _clearOcrErrorDetails();
      _dragIndex = null;
      _dragTargetIndex = null;
    });
  }

  String _retryReselectAllMessage(int requiredCount) =>
      AppLocalizations.of(context)!.ocrRechooseRequiredImages(requiredCount);

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
        _isRetryImageResetWarning = true;
        _retryImageResetWarningRequiredCount = requiredCount;
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
          borderRadius: BorderRadius.circular(16),
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
                    borderRadius: BorderRadius.circular(8),
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
                      AppLocalizations.of(context)!.ocrImageLabel(index + 1),
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
                      label: Text(
                        AppLocalizations.of(context)!.ocrViewErrorDetails,
                        style: const TextStyle(fontSize: 12),
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
                _clearOcrErrorDetails();
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
                        AppLocalizations.of(context)!
                            .ocrLegacyModelPositionConfirm,
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
                      child:
                          Text(AppLocalizations.of(context)!.ocrConfirmModel),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            if (_selectedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  AppLocalizations.of(context)!
                      .ocrSelectedImagesCount(_selectedImages.length),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _selectedImages.isEmpty ||
                        _ocrStarting ||
                        _isProcessing ||
                        _isImageImportPending ||
                        _isRetryImagesLoading ||
                        _retryImagesUnavailable ||
                        _retryImageCountMismatch ||
                        _legacyModelConfirmationPending
                    ? null
                    : _startOcr,
                icon: _ocrStarting || _isProcessing
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
                  _ocrStarting
                      ? AppLocalizations.of(context)!.ocrPreparingImages
                      : _isProcessing
                          ? _isPreparingRetryData
                              ? AppLocalizations.of(context)!
                                  .ocrSavingRetryImages
                              : AppLocalizations.of(context)!.ocrRecognizing
                          : _isRetryImagesLoading
                              ? AppLocalizations.of(context)!
                                  .ocrReadingRetryImages
                              : _isImageImportPending
                                  ? AppLocalizations.of(context)!
                                      .ocrImportingImages
                                  : AppLocalizations.of(context)!
                                      .ocrStartRecognition,
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _ocrStarting || _isProcessing ? null : _pickSaveFolder,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.ocrSaveTo,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              Text(
                _saveFolder.isEmpty
                    ? AppLocalizations.of(context)!.ocrRootDirectory
                    : _saveFolder,
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
    if (_ocrStarting || _isProcessing) return;
    final folders = await TextManifest.getAllFolders();
    if (!mounted || _ocrStarting || _isProcessing) return;
    final result = await FolderPickerDialog.show(
      context,
      currentFolder: _saveFolder,
      availableFolders: folders,
      title: AppLocalizations.of(context)!.ocrChooseSaveFolder,
      onCreateFolder: (name) async {
        await TextManifest.addFolder(name);
        return null;
      },
      onRefreshFolders: () async => TextManifest.getAllFolders(),
    );
    if (result != null && mounted && !_ocrStarting && !_isProcessing) {
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                AppLocalizations.of(context)!.ocrChooseImageSource,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  ChoiceCard(
                    icon: Icons.collections_bookmark,
                    title: AppLocalizations.of(context)!.ocrChooseAppAlbum,
                    subtitle:
                        AppLocalizations.of(context)!.ocrAppAlbumDescription,
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickFromAppAlbum();
                    },
                  ),
                  const SizedBox(height: 8),
                  ChoiceCard(
                    icon: Icons.photo_library,
                    title: AppLocalizations.of(context)!.ocrChooseSystemAlbum,
                    subtitle:
                        AppLocalizations.of(context)!.ocrSystemAlbumDescription,
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
    var importGeneration = _imageImportGeneration;
    var importPending = false;
    final previousImportCommit = _imageImportCommitTail;
    final cameraCommit = Completer<void>();
    _imageImportCommitTail = cameraCommit.future;
    try {
      final picker = ImagePicker();
      final mode = _imageImportMode;
      _beginImageImport();
      importPending = true;
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

      final bytes = await file.readAsBytes();
      if (!mounted || importGeneration != _imageImportGeneration) return;
      final payload = await _prepareImagePayload(bytes);
      if (!mounted || importGeneration != _imageImportGeneration) return;

      await previousImportCommit;
      if (!mounted || importGeneration != _imageImportGeneration) return;
      setState(() {
        _selectedImages.add(
          SelectedImage.fromPayload(
            payload: payload,
            // Camera: temp file, no source name
          ),
        );
        _clearOcrErrorDetails();
        if (_isRetryImageResetWarning ||
            _errorMessage == _lastImageImportErrorMessage) {
          _errorMessage = null;
        }
        _lastImageImportErrorMessage = null;
        _updateRetryImageReselectionState();
      });
    } catch (e) {
      if (mounted && importGeneration == _imageImportGeneration) {
        setState(_clearOcrErrorDetails);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is FormatException
                ? _localizedImagePreparationError(e)
                : AppLocalizations.of(context)!.ocrTakePhotoFailed(e)),
          ),
        );
      }
    } finally {
      if (!cameraCommit.isCompleted) cameraCommit.complete();
      if (importPending) _finishImageImport();
    }
  }

  /// Pick images from the device gallery (supports batch selection).
  Future<void> _pickFromSystemGallery() async {
    var importGeneration = _imageImportGeneration;
    var importPending = false;
    final previousImportCommit = _imageImportCommitTail;
    final galleryCommit = Completer<void>();
    _imageImportCommitTail = galleryCommit.future;
    try {
      final mode = _imageImportMode;
      _beginImageImport();
      importPending = true;
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

      // Overlapping gallery selections share a generation so the later batch
      // cannot invalidate images still being read by the earlier batch.
      final newImages = <SelectedImage>[];
      String? firstError;
      Object? firstFileFailure;
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
          firstError ??= _localizedImagePreparationError(error);
        } catch (error) {
          firstFileFailure ??= error;
        }
        if (!mounted || importGeneration != _imageImportGeneration) return;
      }

      if (!mounted || importGeneration != _imageImportGeneration) return;
      await previousImportCommit;
      if (!mounted || importGeneration != _imageImportGeneration) return;
      setState(() {
        _selectedImages.addAll(newImages);
        _clearOcrErrorDetails();
        _errorMessage = firstError ??
            (_retryImagesUnavailable
                ? (_requiredRetryImageCount == null
                    ? _retryUnavailableMessage
                    : _retryReselectAllMessage(_requiredRetryImageCount!))
                : null);
        _lastImageImportErrorMessage = firstError;
        _updateRetryImageReselectionState();
      });
      if (firstError != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(firstError)));
      }
      if (firstFileFailure != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!
                .ocrChooseImageFailed(firstFileFailure))));
      }
    } catch (e) {
      if (mounted && importGeneration == _imageImportGeneration) {
        setState(_clearOcrErrorDetails);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!
                .ocrChooseImageFailed(e.toString()))));
      }
    } finally {
      if (!galleryCommit.isCompleted) {
        galleryCommit.complete();
      }
      if (importPending) _finishImageImport();
    }
  }

  /// Pick images from the app's album.
  Future<void> _pickFromAppAlbum() async {
    var importGeneration = _imageImportGeneration;
    var importPending = false;
    final previousImportCommit = _imageImportCommitTail;
    final albumCommit = Completer<void>();
    _imageImportCommitTail = albumCommit.future;
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
      await previousImportCommit;
      if (!mounted || importGeneration != _imageImportGeneration) return;
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
            content: Text(
                AppLocalizations.of(context)!.ocrImagesLoaded(loadedCount)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted && importGeneration == _imageImportGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!
                .ocrChooseImageFailed(e.toString()))));
      }
    } finally {
      if (!albumCommit.isCompleted) albumCommit.complete();
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
        _clearOcrErrorDetails();
        if (_isRetryImageResetWarning ||
            _errorMessage == _lastImageImportErrorMessage) {
          _errorMessage = null;
        }
        _lastImageImportErrorMessage = null;
        _updateRetryImageReselectionState();
      });
      return true;
    } catch (e) {
      if (mounted && importGeneration == _imageImportGeneration) {
        final message = e is FormatException
            ? _localizedImagePreparationError(e)
            : AppLocalizations.of(context)!.ocrProcessImageFailed(e.toString());
        setState(() {
          _clearOcrErrorDetails();
          _errorMessage = message;
          _lastImageImportErrorMessage = message;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
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
      _clearOcrErrorDetails();
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
            fileName: AppLocalizations.of(context)!
                .ocrImageFileName(currentImage.format, editedIndex + 1),
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
        !_selectedImages.any(
          (image) => image.hasSameSelectionAs(currentImage),
        )) {
      return;
    }

    try {
      final payload = await _prepareImagePayload(editedBytes);
      if (!mounted || _ocrStarting || _isImageSelectionLocked) return;
      final currentIndex = _selectedImages.indexWhere(
        (image) => image.hasSameSelectionAs(currentImage),
      );
      if (currentIndex < 0) return;
      setState(() {
        _selectedImages[currentIndex] =
            _selectedImages[currentIndex].withEditedPayload(payload);
        _clearOcrErrorDetails();
      });
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_localizedImagePreparationError(error))),
        );
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
      _clearOcrErrorDetails();
      _updateRetryImageReselectionState();
    });
  }

  Future<void> _clearAll() async {
    if (_ocrStarting ||
        _isProcessing ||
        _isRetryImagesLoading ||
        (_hasReusablePageResults && !_retryImagesUnavailable)) {
      return;
    }
    final imageCountUnknown = _retryImageCountUnknown;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('ocr_clear_confirmation_dialog'),
        title: Text(imageCountUnknown
            ? AppLocalizations.of(context)!.ocrUnknownSourceImageCount
            : AppLocalizations.of(context)!.ocrConfirmClear),
        content: Text(
          imageCountUnknown
              ? AppLocalizations.of(context)!.ocrRetryUnavailableConfirmClear
              : AppLocalizations.of(context)!.ocrConfirmClearSelected,
        ),
        actions: [
          TextButton(
            key: const Key('ocr_cancel_clear'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(context)!.ocrCancel),
          ),
          FilledButton(
            key: const Key('ocr_confirm_clear'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(imageCountUnknown
                ? AppLocalizations.of(context)!.ocrConfirmResetAndReselect
                : AppLocalizations.of(context)!.ocrConfirmClear),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (_ocrStarting ||
        _isProcessing ||
        _isRetryImagesLoading ||
        (_hasReusablePageResults && !_retryImagesUnavailable)) {
      return;
    }
    final resetReusableResults =
        _retryImagesUnavailable && _hasReusablePageResults;
    _invalidateImageImports();
    setState(() {
      _selectedImages.clear();
      _clearOcrErrorDetails();
      if (resetReusableResults) _retryPageOutcomes.clear();
      _retryImageCountUnknown = false;
      _isRetryImageReselectionPending = _requiredRetryImageCount != null;
      _retryImagesUnavailable = _isRetryImageReselectionPending;
      _errorMessage = imageCountUnknown
          ? _retryImageResetMessage
          : _requiredRetryImageCount == null
              ? null
              : _retryReselectAllMessage(_requiredRetryImageCount!);
      _isRetryImageResetWarning = true;
      _retryImageResetWarningRequiredCount =
          imageCountUnknown ? null : _requiredRetryImageCount;
    });
  }

  // ==================================================================
  // OCR Processing
  // ==================================================================

  Future<int?> _preflightRequestSize(
    OcrConfig config,
    List<SelectedImage> images,
  ) async {
    final budgetBytes = config.requestSizeBudgetBytes;
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
          setState(() => _errorMessage =
              AppLocalizations.of(context)!.ocrRequestCheckFailed);
        }
        debugPrint(
          '[OCR] Request size check failed: ' + error.runtimeType.toString(),
        );
        return null;
      } finally {
        service.close();
      }

      if (encodedBytes <= budgetBytes) return budgetBytes;
      final switchToPerImage = await _showRequestSizeLimitDialog(
        encodedBytes: encodedBytes,
        budgetBytes: budgetBytes,
        canSwitchToPerImage: _batchMode == OcrBatchMode.joint &&
            images.length > 1 &&
            !_hasReusablePageResults,
      );
      if (!mounted) return null;
      if (switchToPerImage != true) {
        setState(() => _errorMessage =
            AppLocalizations.of(context)!.ocrCancelledAdjustAndRetry);
        return null;
      }
      setState(() {
        _batchMode = OcrBatchMode.perImage;
        _errorMessage = null;
      });
    }
    return null;
  }

  void _captureImagePreparationErrorDetails({
    required _ModelOption option,
    required List<SelectedImage> images,
    required Object error,
  }) {
    final excludedValues = [option.apiKey];
    _lastRawRequest = OcrDiagnosticSnapshot.request(
      url: option.host,
      imageCount: images.length,
      imageBytes: images.fold<int>(
        0,
        (sum, image) => sum + image.bytes.length,
      ),
      durationMs: null,
      requestId: null,
      excludedValues: excludedValues,
    );
    _lastRawResponse = OcrDiagnosticSnapshot.response(
      statusCode: null,
      finishReason: null,
      durationMs: null,
      requestId: null,
      errorType: error.runtimeType.toString(),
      excludedValues: excludedValues,
    );
  }

  Future<bool?> _showRequestSizeLimitDialog({
    required int encodedBytes,
    required int budgetBytes,
    required bool canSwitchToPerImage,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.ocrRequestSizeExceededTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.ocrRequestSizeExceededBody(
              ocrRequestSizeBudgetMib(budgetBytes),
              ocrRequestSizeBudgetOverageMib(encodedBytes, budgetBytes),
            )),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.ocrRequestSizeHelp),
          ],
        ),
        actions: [
          if (canSwitchToPerImage)
            TextButton(
              key: const Key('ocr_switch_to_per_image'),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(AppLocalizations.of(context)!.ocrUsePerImageMode),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context)!.ocrGotIt),
          ),
        ],
      ),
    );
  }

  Future<void> _startOcr() async {
    if (_ocrStarting || _isProcessing) return;
    if (_isImageImportPending) {
      setState(
          () => _errorMessage = AppLocalizations.of(context)!.ocrWaitForImport);
      return;
    }
    if (_isRetryImagesLoading) {
      setState(() =>
          _errorMessage = AppLocalizations.of(context)!.ocrWaitForRetryImages);
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
        _errorMessage = AppLocalizations.of(context)!.ocrConfigureProviderModel;
        _clearOcrErrorDetails();
      });
      return;
    }
    final modelIndex = _selectedModelOptionIndex(modelOptions);
    if (modelIndex == null) {
      setState(() {
        _errorMessage = _modelSelectionMessage(modelIndex) ??
            AppLocalizations.of(context)!.ocrReselectProviderModel;
      });
      return;
    }
    if (_legacyModelConfirmationPending) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.ocrConfirmLegacyModel;
      });
      return;
    }

    setState(() {
      _ocrStarting = true;
      _errorMessage = null;
      _clearOcrErrorDetails();
    });
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
      if (mounted) {
        var retryImageCount = 0;
        try {
          if (widget.retryData != null) {
            retryImageCount =
                OcrRetrySnapshot.fromMap(widget.retryData!).imageEntryCount;
          }
        } catch (retryDataError) {
          debugPrint(
            '[OCR] Failed to read retry image count: ${retryDataError.runtimeType}',
          );
        }
        if (widget.retryData == null && widget.retryTaskId == null) {
          setState(() {
            _ocrStarting = false;
            _errorMessage = _localizedImagePreparationError(error);
            _captureImagePreparationErrorDetails(
              option: modelOptions[modelIndex],
              images: sourceImages,
              error: error,
            );
          });
        } else {
          setState(() {
            _ocrStarting = false;
            _retryImagesUnavailable = true;
            _retryImageCountUnknown = retryImageCount == 0;
            _requiredRetryImageCount =
                retryImageCount == 0 ? null : retryImageCount;
            _isRetryImageReselectionPending = false;
            _errorMessage = retryImageCount == 0
                ? _retryImageCountUnknownMessage
                : AppLocalizations.of(context)!.ocrRetryImagesMissing;
            _captureImagePreparationErrorDetails(
              option: modelOptions[modelIndex],
              images: sourceImages,
              error: error,
            );
          });
        }
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          _ocrStarting = false;
          _errorMessage = AppLocalizations.of(context)!.ocrProcessingOcrFailed;
          _captureImagePreparationErrorDetails(
            option: modelOptions[modelIndex],
            images: sourceImages,
            error: error,
          );
        });
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
      setState(() {
        _ocrStarting = false;
        _errorMessage = AppLocalizations.of(context)!.ocrImageListChanged;
      });
      return;
    }
    final requestModelOptions = _getOcrModelOptions(ref);
    final requestModelIndex = _selectedModelOptionIndex(requestModelOptions);
    if (requestModelOptions.isEmpty || requestModelIndex == null) {
      if (mounted) {
        setState(() {
          _ocrStarting = false;
          _errorMessage = requestModelOptions.isEmpty
              ? AppLocalizations.of(context)!.ocrConfigureProviderModel
              : _modelSelectionMessage(requestModelIndex) ??
                  AppLocalizations.of(context)!.ocrReselectProviderModel;
        });
      }
      return;
    }
    setState(() {
      _selectedImages
        ..clear()
        ..addAll(images);
      _errorMessage = null;
      _ocrStarting = false;
      _isProcessing = true;
      _isPreparingRetryData = true;
    });
    final folder = _saveFolder;

    // Build config from the selected model's own source config,
    // ensuring host/API key match the model's provider.
    // Also passes through the model's typeConfig and customParams
    // for built-in OCR parameters and custom parameters.
    final selectedOption = requestModelOptions[requestModelIndex];
    final strings = AppLocalizations.of(context)!;
    _selectedModelIndex = requestModelIndex;
    _selectedConfigId = selectedOption.configId;
    _selectedModelRecordId = selectedOption.modelRecordId;
    final requestSizeBudgetBytes =
        _retryRequestSizeBudgetBytes ?? selectedOption.requestSizeBudgetBytes;
    var effectiveConfig = OcrConfig(
      host: selectedOption.host,
      apiKey: selectedOption.apiKey,
      model: selectedOption.model.modelId,
      systemPrompt: strings.ocrDefaultSystemPrompt,
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
        _handleRetryInstructionLoadFailure(error);
        return;
      }
    }

    // The page may have been disposed while the restore load was in
    // flight (e.g. back-press) — stop rather than using a dead [ref].
    if (!mounted) return;

    // Inject the selected generic instruction into the request (service
    // reads typeConfig['userInstruction']); unselected = images-only.
    final instructions = ref.read(ocrInstructionsProvider);
    final selectedInstructionIndex = _instructionSelectionValue(instructions);
    final retryInstructionSnapshot = _retryInstructionSnapshot;
    final instructionContent = retryInstructionSnapshot ??
        selectedOcrInstructionContent(
          instructions,
          selectedInstructionIndex,
          strings: strings,
        );
    if (retryInstructionSnapshot != null) {
      final content = retryInstructionSnapshot.trim();
      if (content.isEmpty) {
        effectiveConfig.typeConfig.remove('userInstruction');
      } else {
        effectiveConfig.typeConfig['userInstruction'] = content;
      }
    } else {
      applySelectedOcrInstruction(
        effectiveConfig.typeConfig,
        instructions,
        selectedInstructionIndex,
        strings: strings,
      );
    }

    final effectiveBudgetBytes =
        await (widget.testRequestSizePreflight?.call(effectiveConfig, images) ??
            _preflightRequestSize(effectiveConfig, images));
    if (!mounted) return;
    if (effectiveBudgetBytes == null) {
      setState(() {
        _ocrStarting = false;
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
    if (!taskPublished) {
      if (mounted) {
        setState(() {
          _ocrStarting = false;
          _isProcessing = false;
          _isPreparingRetryData = false;
        });
      }
      return;
    }

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
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.ocrErrorDetails,
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
                              AppLocalizations.of(context)!.ocrRequestHeading,
                              _lastRawRequest,
                              isDark,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_lastRawResponse != null)
                            _buildJsonBlock(
                              AppLocalizations.of(context)!.ocrResponseHeading,
                              _lastRawResponse,
                              isDark,
                            ),
                        ],
                      )
                    : Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!.ocrNoDetails,
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
            borderRadius: BorderRadius.circular(8),
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
                return Center(
                  child: Text(
                      AppLocalizations.of(context)!.ocrPreviewInvalidIndex),
                );
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
                        return Center(
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
                                AppLocalizations.of(context)!
                                    .ocrImageLoadFailed,
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
                    tooltip: AppLocalizations.of(context)!.ocrCrop,
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
                    tooltip: AppLocalizations.of(context)!.ocrEdit,
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
