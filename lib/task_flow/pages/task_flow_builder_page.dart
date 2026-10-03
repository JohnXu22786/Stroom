import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../services/attachment_storage.dart';
import '../../services/chat_protocol.dart' show maxAttachmentBytes;
import '../../utils/duration_parser.dart';
import '../../utils/file_manifest.dart';
import '../../utils/image_manifest.dart';
import '../../utils/video_manifest.dart';
import '../../widgets/app_media_picker_dialog.dart';
import '../models/block_type_definition.dart';
import '../models/flow_payload.dart'
    show flowFileMimeType, flowMimeType, maxFlowImageInputBytes;
import '../models/io_type.dart';
import '../models/task_flow_definition.dart';
import '../models/task_flow_chain_editor.dart';
import '../models/task_flow_execution.dart';
import '../providers/task_flow_provider.dart';
import '../providers/task_flow_execution_provider.dart';
import '../services/task_flow_execution_service.dart';
import '../services/task_flow_validator.dart';
import '../utils/block_param_display.dart';
import '../widgets/block_chain_editor.dart';
import '../widgets/block_editor_dialog.dart';
import '../widgets/flow_block_card.dart';
import 'task_flow_run_page.dart';

/// Unified page for editing AND launching a task flow.
///
/// When [startInRunMode] is true, the page opens in "run" mode showing the
/// execution UI (overview, input, step list, start button) with an edit
/// button in the top-right corner. Tapping edit switches to edit mode.
///
/// When [startInRunMode] is false (default), the page opens in edit mode
/// for building / modifying the block chain. If [flowId] is null the page
/// acts as "create new flow".
class TaskFlowBuilderPage extends ConsumerStatefulWidget {
  final String? flowId;
  final bool startInRunMode;
  final TaskFlowDefinition? initialDraft;
  final TaskFlowValidationException? validationError;
  final FlowRunInput? initialInput;

  const TaskFlowBuilderPage({
    super.key,
    this.flowId,
    this.startInRunMode = false,
    this.initialDraft,
    this.validationError,
    this.initialInput,
  });

  @override
  ConsumerState<TaskFlowBuilderPage> createState() =>
      _TaskFlowBuilderPageState();
}

/// One CatCatch-style run input entry: a URL plus optional 时/分/秒 duration
/// fields — mirrors the CatCatch page's task card.
class _CatCatchInputEntry {
  final TextEditingController urlController;
  final TextEditingController hourController;
  final TextEditingController minuteController;
  final TextEditingController secondController;

  _CatCatchInputEntry()
      : urlController = TextEditingController(),
        hourController = TextEditingController(),
        minuteController = TextEditingController(),
        secondController = TextEditingController();

  void dispose() {
    urlController.dispose();
    hourController.dispose();
    minuteController.dispose();
    secondController.dispose();
  }
}

/// Media manifests store the display name and format separately. Keep the
/// format in the attachment name so chat previews can recognize the file.
@visibleForTesting
String flowMediaRecordFileName(String name, String format) {
  final suffix = format.trim().replaceFirst(RegExp(r'^\.'), '').toLowerCase();
  if (suffix.isEmpty || name.toLowerCase().endsWith('.$suffix')) return name;
  return '$name.$suffix';
}

class _TaskFlowBuilderPageState extends ConsumerState<TaskFlowBuilderPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _inputController;

  /// Run-mode inputs collected in the FIRST block's style:
  /// - CatCatch-first: one entry per URL (+ optional duration fields).
  final List<_CatCatchInputEntry> _catcatchInputs = [];

  /// Run-mode file references: app media paths or persisted document paths
  /// selected through the system picker for a generic file input.
  final List<String> _mediaInputs = [];
  final Map<String, String> _inputDisplayNames = {};
  final Map<String, String> _inputMimeTypes = {};
  final Map<String, String> _ownedStoragePaths = {};
  final Set<String> _unsubmittedFileInputs = {};

  final _chain = TaskFlowChainEditor();
  List<TaskFlowBlock> get _blocks => _chain.blocks;
  IOType get _inputType => _chain.inputType;
  bool _isEditing = false;
  String? _editingFlowId;
  bool _isRunMode = false;
  bool _enteredFromRunMode = false;
  bool _isSaving = false;
  bool _isStarting = false;
  bool _isPickingFiles = false;
  TaskFlowDefinition? _failedSave;

  String _initialName = '';
  String _initialDesc = '';
  IOType _initialInputType = IOType.text;
  List<TaskFlowBlock> _initialBlocks = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _inputController = TextEditingController();

    _inputController.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.flowId != null) {
      _editingFlowId = widget.flowId;
      _isEditing = true;
      _isRunMode = widget.startInRunMode;
      _enteredFromRunMode = widget.startInRunMode;

      final flow = ref.read(taskFlowListProvider).firstWhere(
            (f) => f.id == widget.flowId,
            orElse: () => TaskFlowDefinition(name: ''),
          );
      _nameController.text = flow.name;
      _descController.text = flow.description;
      _chain.reset(blocks: flow.blocks, inputType: flow.inputType);
    } else if (widget.initialDraft != null) {
      final draft = widget.initialDraft!;
      _nameController.text = draft.name;
      _descController.text = draft.description;
      _chain.reset(blocks: draft.blocks, inputType: draft.inputType);
    }

    final initialInput = widget.initialInput;
    if (initialInput != null) {
      if (_isFileRunInput) {
        _mediaInputs.add(initialInput.text);
        if (initialInput.fileName != null)
          _inputDisplayNames[initialInput.text] = initialInput.fileName!;
        if (initialInput.mimeType != null)
          _inputMimeTypes[initialInput.text] = initialInput.mimeType!;
        if (initialInput.ownedStoragePath != null)
          _ownedStoragePaths[initialInput.text] =
              initialInput.ownedStoragePath!;
      } else if (_firstBlockDef?.typeKey == BlockType.catcatch) {
        final entry = _CatCatchInputEntry();
        entry.urlController.text = initialInput.text;
        entry.secondController.text = '${initialInput.durationSec}';
        _catcatchInputs.add(entry);
      } else {
        _inputController.text = initialInput.text;
      }
    }
    if (widget.validationError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showValidationError(widget.validationError!);
      });
    }

    _initialName = _nameController.text.trim();
    _initialDesc = _descController.text.trim();
    _initialInputType = _inputType;
    _initialBlocks = TaskFlowChainEditor.copyBlocks(_blocks);
  }

  @override
  void dispose() {
    // Copies made by the generic picker are only needed after submission.
    // Keep them if a launch is still settling: it may already have persisted
    // records that will read these files on a later retry.
    if (!_isStarting) {
      _discardAllUnsubmittedInputs();
    }
    _nameController.dispose();
    _descController.dispose();
    _inputController.dispose();
    for (final entry in _catcatchInputs) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _discardUnsubmittedInput(String reference) async {
    try {
      await AttachmentStorage.deleteFile(reference);
    } catch (error) {
      debugPrint('Failed to discard unsubmitted flow input: $error');
    }
  }

  void _discardAllUnsubmittedInputs() {
    final references = List<String>.of(_unsubmittedFileInputs);
    _unsubmittedFileInputs.clear();
    for (final reference in references) {
      unawaited(_discardUnsubmittedInput(reference));
    }
  }

  /// A successful launch releases copies only after an execution record owns
  /// them. Editing a file-input flow into a text-input flow can leave a
  /// previously picked copy in this builder without handing it to the run.
  Future<void> _releaseInputsAfterLaunch(
    TaskFlowExecutionNotifier execNotifier,
  ) async {
    if (!execNotifier.mounted) {
      // The saved owner cannot be inspected after app disposal. Retain copies.
      _unsubmittedFileInputs.clear();
      return;
    }
    for (final reference in List<String>.of(_unsubmittedFileInputs)) {
      final storagePath = _ownedStoragePaths[reference];
      if (storagePath != null &&
          execNotifier.referencesInputStoragePath(storagePath)) {
        _unsubmittedFileInputs.remove(reference);
        continue;
      }
      try {
        await AttachmentStorage.deleteFile(storagePath ?? reference);
        _unsubmittedFileInputs.remove(reference);
        _mediaInputs.remove(reference);
        _inputDisplayNames.remove(reference);
        _inputMimeTypes.remove(reference);
        _ownedStoragePaths.remove(reference);
      } catch (error) {
        debugPrint('Failed to discard unused flow input: $error');
        // Keep ownership so dispose can retry the cleanup.
      }
    }
  }

  // =========================================================================
  // Dirty check helpers
  // =========================================================================

  bool get _isDirty {
    if (!_isEditing) {
      return _nameController.text.trim().isNotEmpty ||
          _descController.text.trim().isNotEmpty ||
          _blocks.isNotEmpty ||
          _inputType != IOType.text;
    }
    return _nameController.text.trim() != _initialName ||
        _descController.text.trim() != _initialDesc ||
        _inputType != _initialInputType ||
        _blocksDiffer(_blocks, _initialBlocks);
  }

  bool _blocksDiffer(List<TaskFlowBlock> a, List<TaskFlowBlock> b) =>
      !TaskFlowChainEditor.sameBlocks(a, b);

  Future<bool> _showUnsavedChangesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃未保存的更改？'),
        content: const Text('返回后，所有未保存的更改将会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Returns to run mode if entered from there, otherwise pops.
  ///
  /// On discard the local edits must be dropped — otherwise run mode would
  /// render the edited chain while [_startFlow] executes the persisted flow.
  void _goBackFromEdit() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final failedSave = _failedSave;
    if (failedSave != null) {
      final notifier = ref.read(taskFlowListProvider.notifier);
      // Only undo this editor's failed draft, not a newer external update.
      if (identical(notifier.getFlow(failedSave.id), failedSave)) {
        if (_isEditing) {
          notifier.updateFlow(failedSave.id,
              name: _initialName,
              description: _initialDesc,
              inputType: _initialInputType,
              blocks: _initialBlocks);
        } else {
          notifier.removeFlow(failedSave.id);
        }
      }
      _failedSave = null;
    }
    if (_enteredFromRunMode) {
      setState(() {
        _isRunMode = true;
        _resetToInitial();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Restore the local state from the last saved snapshots.
  void _resetToInitial() {
    _chain.reset(blocks: _initialBlocks, inputType: _initialInputType);
    _nameController.text = _initialName;
    _descController.text = _initialDesc;
  }

  // =========================================================================
  // Build entry – mode dispatch
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isRunMode) return _buildRunMode();
    return _buildEditMode();
  }

  // ============================================================
  // EDIT MODE (existing builder UI)
  // ============================================================

  Widget _buildEditMode() {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!mounted || _isSaving) return;
        if (!_isDirty) {
          _goBackFromEdit();
          return;
        }
        final shouldDiscard = await _showUnsavedChangesDialog();
        if (shouldDiscard && context.mounted) {
          _goBackFromEdit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? '编辑任务流' : '新建任务流'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: '撤销',
              icon: const Icon(Icons.undo),
              onPressed: _isSaving || !_chain.canUndo ? null : _undoBlockEdit,
            ),
            TextButton.icon(
              onPressed: _isSaving ? null : _saveFlow,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('保存'),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _isSaving,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                _buildEditHeader(cs),
                Expanded(
                  child: BlockChainEditor(
                    blocks: _blocks,
                    inputType: _inputType,
                    selectedBlockId: _chain.selectedBlockId,
                    onInputTypeChanged: (type) =>
                        setState(() => _chain.changeInputType(type)),
                    onAddBlock: _addBlock,
                    onEditBlock: _editBlock,
                    onDeleteBlock: _removeBlock,
                    onReplaceBlock: _replaceBlock,
                    onInsertBlock: _insertBlock,
                    onDuplicateBlock: (index) =>
                        setState(() => _chain.duplicate(index)),
                    onMoveBlock: (index, destination) =>
                        setState(() => _chain.move(index, destination)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            enabled: !_isSaving,
            decoration: InputDecoration(
              hintText: '输入任务流名称',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            enabled: !_isSaving,
            decoration: InputDecoration(
              hintText: '添加描述（可选）',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            maxLines: 2,
            minLines: 1,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _undoBlockEdit() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _chain.undo());
  }

  void _addBlock(BlockType typeKey) => _insertBlock(_blocks.length, typeKey);

  void _insertBlock(int index, BlockType typeKey) {
    setState(() => _chain.insert(index, typeKey));
  }

  void _removeBlock(int index) {
    setState(() => _chain.remove(index));
  }

  void _replaceBlock(int index, BlockType typeKey) {
    setState(() => _chain.replace(index, typeKey));
  }

  Future<void> _editBlock(int index) async {
    if (index < 0 || index >= _blocks.length) return;
    final block = _blocks[index];
    setState(() => _chain.select(block.id));
    // Settings receive their own nested values so cancellation cannot mutate
    // the draft, the persisted flow, or an undo snapshot.
    final updated = await showBlockEditorDialog(context,
        block: TaskFlowChainEditor.copyBlock(block));
    if (updated != null && mounted) {
      setState(() => _chain.updateParams(block.id, updated.params));
    }
  }

  Future<void> _saveFlow() async {
    if (!mounted || _isSaving || _isRunMode) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入任务流名称')));
      return;
    }

    if (_chain.issues.isNotEmpty) {
      final issue = _chain.issues.first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('步骤 ${issue.blockIndex + 1}：${issue.message}')));
      return;
    }

    // Validate required params (e.g. the chat block's assistant) before
    // persisting — a flow that can never run should not be saveable.
    for (final block in _blocks) {
      final def = block.getDefinition();
      if (def == null) continue;
      for (final p in def.params) {
        if (!p.required) continue;
        final raw = block.params[p.key]?.toString() ?? '';
        if (raw.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「${def.label}」的「${p.label}」为必填项')),
          );
          return;
        }
      }
    }

    final notifier = ref.read(taskFlowListProvider.notifier);
    final current =
        _editingFlowId == null ? null : notifier.getFlow(_editingFlowId!);
    final flow = TaskFlowDefinition(
      id: _editingFlowId,
      name: name,
      description: _descController.text.trim(),
      inputType: _inputType,
      blocks: _blocks,
      createdAt: current?.createdAt,
    );
    // Keep the id on failure so retry replaces the same in-memory draft.
    _editingFlowId = flow.id;
    setState(() => _isSaving = true);
    final saved = await notifier.saveFlow(flow);
    if (!mounted) return;
    _failedSave = saved ? null : flow;
    setState(() => _isSaving = false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (!saved) {
      messenger.showSnackBar(SnackBar(
        content: const Text('保存失败，更改仍保留，请重试'),
        action: SnackBarAction(label: '重试', onPressed: _saveFlow),
      ));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(_isEditing ? '任务流已更新' : '任务流已创建'),
    ));
    _isEditing = true;

    _initialName = flow.name;
    _initialDesc = flow.description;
    _initialInputType = flow.inputType;
    _initialBlocks = TaskFlowChainEditor.copyBlocks(flow.blocks);
    _chain.clearHistory();

    if (_enteredFromRunMode) {
      // Return to run mode with fresh state snapshots
      setState(() => _isRunMode = true);
      return;
    }
    Navigator.of(context).pop();
  }

  // ============================================================
  // RUN MODE (merged from execution page)
  // ============================================================

  Widget _buildRunMode() {
    final cs = Theme.of(context).colorScheme;
    final flowName = _nameController.text.trim();

    if (flowName.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务流'), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('任务未找到', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(flowName),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isRunMode = false),
              tooltip: '编辑',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRunOverviewCard(flowName, cs),
          const SizedBox(height: 20),
          _buildRunInputSection(cs),
          const SizedBox(height: 16),
          // Read-only block chain (mirrors edit page layout)
          _buildRunInitialInput(cs),
          ..._blocks.asMap().entries.map((entry) {
            final idx = entry.key;
            final block = entry.value;
            final def = block.getDefinition();
            return FlowBlockCard(
              block: block,
              index: idx + 1,
              isFirst: idx == 0,
              readOnly: true,
              onTap: () => _showBlockInfo(def, block),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRunOverviewCard(String flowName, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                flowName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          if (_descController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _descController.text.trim(),
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  /// The flow's first block definition — the run input section adapts to
  /// THIS block's input style ("直接运行该功能块"), not the flow's generic
  /// input type: CatCatch gets its URL + 时/分/秒 box, media blocks get a
  /// multi-select picker, text blocks keep the plain text field.
  BlockTypeDefinition? get _firstBlockDef {
    if (_blocks.isEmpty) return null;
    return _blocks.first.getDefinition();
  }

  /// The effective input type for the run input section: the first block's
  /// declared input, falling back to the flow's initial input type.
  IOType get _runInputType => _firstBlockDef?.inputType == IOType.any
      ? _inputType.userFacing
      : _firstBlockDef?.inputType ?? _inputType.userFacing;

  bool get _isFileRunInput => const {
        IOType.image,
        IOType.audio,
        IOType.video,
        IOType.file,
      }.contains(_runInputType);

  Widget _buildRunInputSection(ColorScheme cs) {
    final firstDef = _firstBlockDef;
    final label = firstDef?.label ?? _inputType.userFacing.label;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.input, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  '输入（$label）',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (firstDef?.typeKey == BlockType.catcatch)
              _buildCatCatchRunInput(cs)
            else if (_isFileRunInput)
              _buildMediaRunInput(cs)
            else
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: '输入文本或链接',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.text_fields, size: 18),
                  filled: true,
                  fillColor: cs.surface,
                ),
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed:
                      !_isStarting && _canStartFlow() ? _startFlow : null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('开始任务流'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // Run input — CatCatch first block: the CatCatch page's main box
  // (URL + 时/分/秒 duration + preview). Multiple entries supported.
  // ====================================================================

  Widget _buildCatCatchRunInput(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _catcatchInputs.length; i++) ...[
          _buildCatCatchInputCard(cs, i),
          if (i < _catcatchInputs.length - 1) const SizedBox(height: 10),
        ],
        if (_catcatchInputs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                '暂无输入，点击下方按钮添加网页资源 URL',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('taskflow_add_catcatch_input'),
            onPressed: () =>
                setState(() => _catcatchInputs.add(_CatCatchInputEntry())),
            icon: const Icon(Icons.add_link, size: 18),
            label: const Text('添加网页资源'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCatCatchInputCard(ColorScheme cs, int index) {
    final entry = _catcatchInputs[index];
    final preview = _catcatchDurationPreview(entry);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: entry.urlController,
                    decoration: InputDecoration(
                      hintText: '请输入视频/音频网页URL',
                      prefixIcon: const Icon(Icons.link, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: cs.error,
                    ),
                    onPressed: () {
                      setState(() {
                        entry.dispose();
                        _catcatchInputs.removeAt(index);
                      });
                    },
                    tooltip: '删除此输入',
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: entry.hourController,
                    decoration: InputDecoration(
                      labelText: '时',
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: entry.minuteController,
                    decoration: InputDecoration(
                      labelText: '分',
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: entry.secondController,
                    decoration: InputDecoration(
                      labelText: '秒',
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '预览: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    preview,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '时:分:秒',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                '可选：按时长筛选视频资源。留空则展示全部资源供选择',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _catcatchEntrySeconds(_CatCatchInputEntry entry) {
    final h = int.tryParse(entry.hourController.text.trim()) ?? 0;
    final m = int.tryParse(entry.minuteController.text.trim()) ?? 0;
    final s = int.tryParse(entry.secondController.text.trim()) ?? 0;
    return totalSeconds(hours: h, minutes: m, seconds: s);
  }

  String _catcatchDurationPreview(_CatCatchInputEntry entry) {
    final total = _catcatchEntrySeconds(entry);
    return formatHms(
      DurationResult(
        hours: total ~/ 3600,
        minutes: (total % 3600) ~/ 60,
        seconds: total % 60,
      ),
    );
  }

  bool _isValidUrl(String trimmed) {
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  // ====================================================================
  // Run input — media first block (OCR/ASR/audioSeparation): the in-app
  // multi-select picker. "必须确切的选择" — no manual path/identifier
  // typing, the user picks real files from app storage.
  // ====================================================================

  Widget _buildMediaRunInput(ColorScheme cs) {
    final isImage = _runInputType == IOType.image;
    final isAudio = _runInputType == IOType.audio;
    final isFile = _runInputType == IOType.file;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('taskflow_pick_media_input'),
            onPressed: _isStarting || _isPickingFiles ? null : _pickMediaInputs,
            icon: Icon(
              isImage
                  ? Icons.image_outlined
                  : isAudio
                      ? Icons.audiotrack
                      : isFile
                          ? Icons.insert_drive_file_outlined
                          : Icons.videocam_outlined,
              size: 16,
            ),
            label: Text(
              isImage
                  ? '选择图片（可多选）'
                  : isAudio
                      ? '选择音频（可多选）'
                      : isFile
                          ? '选择文件（可多选）'
                          : '选择视频（可多选）',
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        if (_mediaInputs.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (int i = 0; i < _mediaInputs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    isImage
                        ? Icons.image
                        : isAudio
                            ? Icons.audiotrack
                            : isFile
                                ? Icons.insert_drive_file
                                : Icons.videocam,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _inputDisplayNames[_mediaInputs[i]] ??
                          _fileName(_mediaInputs[i]),
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: cs.error.withValues(alpha: 0.8),
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: '移除',
                    onPressed: _isStarting || _isPickingFiles
                        ? null
                        : () async {
                            if (_isStarting || _isPickingFiles) return;
                            final reference = _mediaInputs[i];
                            setState(() {
                              _inputDisplayNames.remove(reference);
                              _mediaInputs.removeAt(i);
                            });
                            if (_unsubmittedFileInputs.remove(reference)) {
                              try {
                                await AttachmentStorage.deleteFile(reference);
                              } catch (error) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('清理已移除文件失败：$error')),
                                  );
                                }
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  bool _canStartFlow() {
    if (_isPickingFiles) return false;
    if (_firstBlockDef?.typeKey == BlockType.catcatch) {
      return _catcatchInputs
          .any((e) => _isValidUrl(e.urlController.text.trim()));
    }
    if (_isFileRunInput) {
      return _mediaInputs.isNotEmpty;
    }
    return _inputController.text.trim().isNotEmpty;
  }

  String _fileName(String path) {
    final sep = path.contains('\\') ? '\\' : '/';
    final parts = path.split(sep);
    return parts.isNotEmpty ? parts.last : path;
  }

  Widget _buildRunInitialInput(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: cs.tertiary.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.input,
                        size: 18,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '0. 初始输入',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '输入类型: ${_runInputType.label}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '用户运行任务流时输入',
                    style: TextStyle(
                      fontSize: 9,
                      color: cs.tertiary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_blocks.isNotEmpty) ...[
          const SizedBox(height: 4),
          Icon(Icons.arrow_downward, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  void _showBlockInfo(BlockTypeDefinition? def, TaskFlowBlock block) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(def?.label ?? block.typeKey.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '输入: ${def?.inputType.label ?? '-'}',
                style: TextStyle(fontSize: 14, color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                '输出: ${def?.outputType.label ?? '-'}',
                style: TextStyle(fontSize: 14, color: cs.onSurface),
              ),
              if (block.params.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '参数:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ...block.params.entries.map((e) {
                  final paramDef =
                      def?.params.where((p) => p.key == e.key).firstOrNull;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${paramDef?.label ?? e.key}: ',
                          style: TextStyle(fontSize: 13, color: cs.primary),
                        ),
                        Expanded(
                          // Friendly display — raw ids (assistant uuids,
                          // voice ids, model indices) must never appear.
                          child: Text(
                            friendlyParamValue(
                              paramDef,
                              e.value,
                              ref,
                              params: block.params,
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Run mode – start execution
  // =========================================================================

  /// Opens the in-app media picker in MULTI-SELECT mode for the first
  /// block's input type (OCR → images, ASR → audio, audioSeparation →
  /// video, or a generic file for the assistant) and appends durable file
  /// references to [_mediaInputs].
  ///
  /// Path-only mode: no file bytes are buffered — the dialog resolves each
  /// record's storage path via [MediaPickerConfig.onRecordsPicked] before
  /// closing. Generic files are copied into attachment storage so queued and
  /// retried executions can still read them after the picker cache expires.
  Future<void> _pickMediaInputs() async {
    if (_isStarting || _isPickingFiles) return;
    setState(() => _isPickingFiles = true);
    final ioType = _runInputType;
    try {
      switch (ioType) {
        case IOType.image:
          await _pickMediaPaths<ImageRecord>(
            title: '选择应用内图片（可多选）',
            emptyIcon: Icons.image_outlined,
            emptyText: '暂无图片',
            fileIcon: Icons.image,
            fileIconColor: Colors.blue,
            loadRecords: ImageManifest.loadRecords,
            loadFolders: ImageManifest.getAllFolders,
            resolvePath: (r) => ImageManifest.readFilePath(r.storagePath),
          );
        case IOType.audio:
          await _pickMediaPaths<AudioRecord>(
            title: '选择应用内音频（可多选）',
            emptyIcon: Icons.multitrack_audio_outlined,
            emptyText: '暂无音频',
            fileIcon: Icons.audiotrack,
            fileIconColor: Colors.green,
            loadRecords: FileManifest.loadRecords,
            loadFolders: FileManifest.getAllFolders,
            resolvePath: (r) => FileManifest.readFilePath(r.storagePath),
          );
        case IOType.video:
          await _pickMediaPaths<VideoRecord>(
            title: '选择应用内视频（可多选）',
            emptyIcon: Icons.videocam_outlined,
            emptyText: '暂无视频',
            fileIcon: Icons.videocam,
            fileIconColor: Colors.orange,
            loadRecords: VideoManifest.loadRecords,
            loadFolders: VideoManifest.getAllFolders,
            resolvePath: (r) => VideoManifest.readFilePath(r.storagePath),
          );
        case IOType.file:
          await _pickGenericFileInputs();
        default:
          break; // text/url/any use the text input
      }
    } finally {
      if (mounted) setState(() => _isPickingFiles = false);
    }
  }

  Future<void> _pickGenericFileInputs() async {
    final savedPaths = <String>[];
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: false,
        withReadStream: true,
      );
      if (result == null) return;
      final selected = <String, String>{};
      final owned = <String, String>{};
      for (final file in result.files) {
        final bytes = await _readGenericFile(file);
        final storagePath = await AttachmentStorage.saveFile(file.name, bytes);
        savedPaths.add(storagePath);
        // The web reference is an IndexedDB key. Native validation and
        // execution use File(reference), so they need the absolute path.
        final reference = kIsWeb
            ? storagePath
            : p.join(await AttachmentStorage.getStorageDirPath(),
                p.basename(storagePath));
        selected[reference] = file.name;
        owned[reference] = storagePath;
      }
      if (!mounted || _isStarting) {
        for (final path in savedPaths) {
          await AttachmentStorage.deleteFile(path);
        }
        return;
      }
      setState(() {
        _mediaInputs.addAll(selected.keys
            .where((reference) => !_mediaInputs.contains(reference)));
        _inputDisplayNames.addAll(selected);
        _ownedStoragePaths.addAll(owned);
        _unsubmittedFileInputs.addAll(selected.keys);
      });
    } catch (error) {
      for (final path in savedPaths) {
        try {
          await AttachmentStorage.deleteFile(path);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败：$error')),
        );
      }
    }
  }

  Future<Uint8List> _readGenericFile(PlatformFile file) async {
    // Images can be compressed by the chat pipeline; other documents use its
    // ordinary attachment limit. Check both before accumulating file bytes.
    Never tooLarge(int limit) => throw FormatException(
        '「${file.name}」超过 ${limit ~/ (1024 * 1024)} MB，请选择较小文件');
    bool isImage(List<int> header) =>
        flowMimeType(flowFileMimeType(file.name, headerBytes: header)) ==
        IOType.image;
    int limitFor(List<int> header) =>
        isImage(header) ? maxFlowImageInputBytes : maxAttachmentBytes;

    Uint8List bytes;
    if (!kIsWeb && file.path != null) {
      final handle = await File(file.path!).open();
      try {
        final length = await handle.length();
        final header = await handle.read(32);
        if (header.isEmpty) throw StateError('「${file.name}」为空或无法读取');
        final limit = limitFor(header);
        if (file.size > limit || length > limit) {
          tooLarge(limit);
        }
        await handle.setPosition(0);
        // A file can grow after length(); the bounded read catches that race.
        bytes = await handle.read(limit + 1);
      } finally {
        await handle.close();
      }
    } else if (file.readStream != null) {
      final builder = BytesBuilder(copy: false);
      final header = <int>[];
      await for (final chunk in file.readStream!) {
        if (header.length < 32) {
          header.addAll(chunk.take(32 - header.length));
        }
        final limit = limitFor(header);
        if ((header.length == 32 && file.size > limit) ||
            builder.length + chunk.length > limit) {
          tooLarge(limit);
        }
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    } else if (file.bytes != null) {
      // Some picker implementations supply bytes without a stream.
      bytes = file.bytes!;
    } else {
      throw StateError('「${file.name}」为空或无法读取');
    }

    if (bytes.isEmpty) throw StateError('「${file.name}」为空或无法读取');
    final limit = limitFor(bytes.take(32).toList());
    if (file.size > limit || bytes.length > limit) {
      tooLarge(limit);
    }
    return bytes;
  }

  Future<void> _pickMediaPaths<T>({
    required String title,
    required IconData emptyIcon,
    required String emptyText,
    required IconData fileIcon,
    required Color fileIconColor,
    required Future<List<T>> Function() loadRecords,
    required Future<Set<String>> Function() loadFolders,
    required Future<String?> Function(T record) resolvePath,
  }) async {
    final paths = <String>[];
    final names = <String, String>{};
    // Multi-select path-only mode: no readFile — the dialog resolves each
    // record's path via onRecordsPicked without buffering the files.
    final result = await showMediaPickerDialog<T>(
      context,
      MediaPickerConfig<T>(
        title: title,
        emptyIcon: emptyIcon,
        emptyText: emptyText,
        fileIcon: fileIcon,
        fileIconColor: fileIconColor,
        multiSelect: true,
        loadRecords: loadRecords,
        loadFolders: loadFolders,
        displayName: (record) {
          final dynamic r = record;
          return (r.name as String?) ?? '';
        },
        subtitleBuilder: (record) {
          final dynamic r = record;
          final format = (r.format as String?) ?? '';
          final size = (r.size as int?) ?? 0;
          return Text(
            '$format · ${_formatBytes(size)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          );
        },
        onRecordsPicked: (records) async {
          // Resolved before the dialog pops; the paths land in [paths]
          // for the caller below.
          for (final record in records) {
            final path = await resolvePath(record);
            if (path != null && path.isNotEmpty) {
              paths.add(path);
              final dynamic named = record;
              final name = named.name as String?;
              final format = named.format as String?;
              if (name != null && name.isNotEmpty) {
                names[path] = flowMediaRecordFileName(name, format ?? '');
              }
            }
          }
        },
      ),
    );

    if (result == null || paths.isEmpty || !mounted || _isStarting) return;
    // On web readFilePath returns a WebFileStore key, not a filesystem
    // path — skip the existence check there (dart:io File throws).
    final valid = paths.where((p) {
      if (kIsWeb) return true;
      return File(p).existsSync();
    }).toList();
    if (valid.length != paths.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('部分文件不存在，已跳过')),
      );
    }
    // Skip paths already selected — re-picking the same file must not
    // fan out a duplicate execution.
    final fresh = valid.where((p) => !_mediaInputs.contains(p)).toList();
    setState(() {
      _mediaInputs.addAll(fresh);
      for (final path in fresh) {
        final name = names[path];
        if (name != null) _inputDisplayNames[path] = name;
      }
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Collects the run inputs in the first block's style and fans the flow
  /// out — one execution per input.
  List<FlowRunInput> _collectRunInputs() {
    if (_firstBlockDef?.typeKey == BlockType.catcatch) {
      return [
        for (final entry in _catcatchInputs)
          if (entry.urlController.text.trim().isNotEmpty)
            FlowRunInput(
              text: entry.urlController.text.trim(),
              durationSec: _catcatchEntrySeconds(entry),
            ),
      ];
    }
    if (_isFileRunInput) {
      return [
        for (final path in _mediaInputs)
          FlowRunInput(
              text: path,
              mimeType: _inputMimeTypes[path],
              fileName: _inputDisplayNames[path],
              ownedStoragePath: _ownedStoragePaths[path]),
      ];
    }
    final text = _inputController.text.trim();
    return text.isEmpty ? const [] : [FlowRunInput(text: text)];
  }

  Future<void> _showValidationError(TaskFlowValidationException error) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
    if (error.isInputError) return;
    setState(() => _isRunMode = false);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || error.blockId == null) return;
    final index = _blocks.indexWhere((b) => b.id == error.blockId);
    if (index >= 0) await _editBlock(index);
  }

  Future<void> _startFlow() async {
    if (_isStarting || _isPickingFiles) return;
    final inputs = _collectRunInputs();
    final execNotifier = ref.read(taskFlowExecutionsProvider.notifier);
    setState(() => _isStarting = true);
    late final List<String> executionIds;
    try {
      executionIds = await ref
          .read(taskFlowExecutionServiceProvider)
          .launchFlowMany(_editingFlowId!, inputs);
      await _releaseInputsAfterLaunch(execNotifier);
    } on TaskFlowValidationException catch (error) {
      if (mounted) {
        await _showValidationError(error);
      }
      return;
    } catch (error) {
      // Failed saves can retain retry records that already own picker copies.
      _unsubmittedFileInputs.removeWhere((reference) {
        if (!execNotifier.mounted) return true;
        final path = _ownedStoragePaths[reference];
        return path != null && execNotifier.referencesInputStoragePath(path);
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      } else {
        // A failed launch may settle after the page has already been closed.
        // Successful launches cleared this set before reaching this point.
        _discardAllUnsubmittedInputs();
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            inputs.length == 1 ? '任务流已加入队列' : '已将 ${inputs.length} 个任务流加入队列',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TaskFlowRunPage(executionIds: executionIds)));
    }
  }
}
