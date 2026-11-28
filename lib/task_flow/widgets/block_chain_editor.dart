import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';
import 'package:stroom/widgets/modal_bottom_sheet_constraints.dart';

import '../models/block_type_definition.dart';
import '../models/io_type.dart';
import '../models/task_flow_definition.dart';
import '../models/task_flow_chain_editor.dart';
import '../models/flow_temporary_output.dart';
import '../utils/task_flow_localization.dart';
import 'flow_block_card.dart';
import 'io_type_indicator.dart';
import '../../l10n/app_localizations.dart';

import '../../widgets/constrained_text.dart';

class BlockChainEditor extends StatelessWidget {
  final List<TaskFlowBlock> blocks;
  final IOType inputType;
  final void Function(IOType type) onInputTypeChanged;
  final void Function(BlockType typeKey) onAddBlock;
  final void Function(int index) onEditBlock;
  final void Function(int index) onDeleteBlock;
  final void Function(int index, BlockType typeKey) onReplaceBlock;
  final void Function(int index, BlockType typeKey)? onInsertBlock;
  final void Function(int index)? onDuplicateBlock;
  final void Function(int index, int destination)? onMoveBlock;
  final String? selectedBlockId;
  final ValueChanged<bool>? onTemporaryOutputsChanged;
  final void Function(int index, bool enabled)? onTemporaryOutputChanged;

  const BlockChainEditor({
    super.key,
    required this.blocks,
    required this.inputType,
    required this.onInputTypeChanged,
    required this.onAddBlock,
    required this.onEditBlock,
    required this.onDeleteBlock,
    required this.onReplaceBlock,
    this.onInsertBlock,
    this.onDuplicateBlock,
    this.onMoveBlock,
    this.selectedBlockId,
    this.onTemporaryOutputsChanged,
    this.onTemporaryOutputChanged,
  });

  /// The types users can pick for the initial input — text/audio/image/
  /// video only (URLs are text; the internal file/any markers are not
  /// user-selectable).
  static const List<IOType> _inputTypeOptions = IOType.userSelectable;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final issues = TaskFlowChainEditor.validateConnections(blocks, inputType);
    final temporaryOutputIndices = [
      for (var index = 0; index < blocks.length; index++)
        if (isFlowTemporaryOutputEligible(blocks, index)) index,
    ];
    final temporaryOutputCount = temporaryOutputIndices
        .where((index) => isFlowTemporaryOutputEnabled(blocks[index]))
        .length;
    final bool? allTemporary = temporaryOutputIndices.isEmpty
        ? false
        : temporaryOutputCount == temporaryOutputIndices.length
            ? true
            : temporaryOutputCount == 0
                ? false
                : null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              _buildInitialInputCard(context),
              ...List.generate(blocks.length, (index) {
                final block = blocks[index];
                final displayIndex = index + 1;
                final isLast = index == blocks.length - 1;
                return Column(
                  key: ValueKey(block.id),
                  children: [
                    if (onInsertBlock != null)
                      _buildInsertControl(context, index),
                    FlowBlockCard(
                      block: block,
                      index: displayIndex,
                      isFirst: index == 0,
                      isLast: isLast,
                      onTemporaryOutputChanged:
                          isFlowTemporaryOutputEligible(blocks, index)
                              ? (enabled) =>
                                  onTemporaryOutputChanged?.call(index, enabled)
                              : null,
                      selected: selectedBlockId == block.id,
                      validationMessage: (() {
                        final issue = issues
                            .where((issue) => issue.blockId == block.id)
                            .firstOrNull;
                        return issue == null
                            ? null
                            : localizedChainIssueMessage(
                                issue,
                                blocks,
                                inputType,
                                strings,
                              );
                      })(),
                      onTap: () => onEditBlock(index),
                      onSettings: () => onEditBlock(index),
                      onReplace: () => _showReplaceBlockSheet(context, index),
                      onDelete: () => onDeleteBlock(index),
                      onDuplicate: onDuplicateBlock == null
                          ? null
                          : () => onDuplicateBlock!(index),
                      onMoveUp: index == 0 || onMoveBlock == null
                          ? null
                          : () => onMoveBlock!(index, index - 1),
                      onMoveDown: isLast || onMoveBlock == null
                          ? null
                          : () => onMoveBlock!(index, index + 1),
                      onInsertBefore: onInsertBlock == null
                          ? null
                          : () =>
                              _showAddBlockSheet(context, insertIndex: index),
                      onInsertAfter: onInsertBlock == null
                          ? null
                          : () => _showAddBlockSheet(
                                context,
                                insertIndex: index + 1,
                              ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        _buildBottomBar(
          context,
          allTemporary,
          showTemporaryOutputControl: temporaryOutputIndices.isNotEmpty,
        ),
      ],
    );
  }

  Widget _buildTemporaryOutputControl(
    BuildContext context,
    bool? value, {
    bool allowLabelWrap = false,
  }) {
    return Tooltip(
      message: AppLocalizations.of(context)!.taskFlowUiTemporaryCleanupTooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            tristate: true,
            value: value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onTemporaryOutputsChanged == null
                ? null
                : (_) =>
                    onTemporaryOutputsChanged!(value == true ? false : true),
          ),
          if (allowLabelWrap)
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.taskFlowUiTemporaryFiles,
                style: const TextStyle(fontSize: 11),
              ),
            )
          else
            Text(
              AppLocalizations.of(context)!.taskFlowUiTemporaryFiles,
              style: const TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildInitialInputCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context)!;
    const inputTypeDropdownIconSize = 18.0;
    const inputTypeDropdownHorizontalPadding = 8.0;
    final inputTypeStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      color: cs.primary,
    );
    final inputIcon = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: cs.tertiary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.input, size: 18, color: Colors.blueGrey),
    );
    final inputLabel = Text(
      strings.taskFlowUiInitialInput,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
    );
    final inputTypeDropdown = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: inputTypeDropdownHorizontalPadding,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<IOType>(
          dropdownColor: StroomMenuStyle.surface(context),
          borderRadius: StroomMenuStyle.borderRadius,
          // Stored url/any display as text; file remains selectable.
          // The value must exist in items.
          value: inputType.userFacing,
          isDense: true,
          iconSize: inputTypeDropdownIconSize,
          icon: Icon(
            Icons.arrow_drop_down,
            size: inputTypeDropdownIconSize,
            color: cs.primary,
          ),
          style: inputTypeStyle,
          onChanged: (type) {
            if (type != null) onInputTypeChanged(type);
          },
          items: _inputTypeOptions.map((type) {
            return DropdownMenuItem(
              value: type,
              child: ConstrainedText(
                localizedIoTypeLabel(type, strings),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final labelWidth = _measureTextWidth(
                      context,
                      strings.taskFlowUiInitialInput,
                      inputLabel.style!,
                    );
                    final widestTypeLabelWidth = _inputTypeOptions
                        .map(
                          (type) => _measureTextWidth(
                            context,
                            localizedIoTypeLabel(type, strings),
                            inputTypeStyle,
                          ),
                        )
                        .reduce((width, next) => width > next ? width : next);
                    final dropdownWidth = widestTypeLabelWidth +
                        inputTypeDropdownIconSize +
                        inputTypeDropdownHorizontalPadding * 2;
                    final rowWidth = 32 + 10 + labelWidth + dropdownWidth;
                    final textScale =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    if (textScale > 1 && constraints.maxWidth < rowWidth) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              inputIcon,
                              const SizedBox(width: 10),
                              Expanded(child: inputLabel),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: inputTypeDropdown,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        inputIcon,
                        const SizedBox(width: 10),
                        Expanded(child: inputLabel),
                        inputTypeDropdown,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: IOTypeIndicator(
                        type: inputType.userFacing,
                        isInput: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppLocalizations.of(context)!.taskFlowUiUserFlowInput,
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
        if (blocks.isNotEmpty) ...[
          const SizedBox(height: 4),
          Icon(Icons.arrow_downward, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    bool? allTemporary, {
    required bool showTemporaryOutputControl,
  }) {
    final cs = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final temporaryTextWidth = _measureTextWidth(
              context,
              strings.taskFlowUiTemporaryFiles,
              DefaultTextStyle.of(context).style.copyWith(fontSize: 11),
            );
            final addBlockTextWidth = _measureTextWidth(
              context,
              strings.taskFlowUiAddBlock,
              const TextStyle(fontSize: 14),
            );
            // Checkbox uses compact density and a shrink-wrapped tap target.
            // OutlinedButton.icon has 12/16 px horizontal padding and an 8 px
            // icon gap under Material 3; reserve its 64 px minimum as well.
            final temporaryControlWidth = 40 + temporaryTextWidth;
            final addButtonWidth = math.max(
              64,
              addBlockTextWidth + 18 + 8 + 12 + 16,
            );
            final stackControls = showTemporaryOutputControl &&
                constraints.maxWidth <
                    temporaryControlWidth + 4 + addButtonWidth;
            final addButton = OutlinedButton.icon(
              onPressed: () => _showAddBlockSheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: ConstrainedText(
                strings.taskFlowUiAddBlock,
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );

            if (stackControls) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTemporaryOutputControl(
                    context,
                    allTemporary,
                    allowLabelWrap: true,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(width: double.infinity, child: addButton),
                ],
              );
            }

            return Row(
              children: [
                if (showTemporaryOutputControl) ...[
                  _buildTemporaryOutputControl(context, allTemporary),
                  const SizedBox(width: 4),
                ],
                Expanded(child: addButton),
              ],
            );
          },
        ),
      ),
    );
  }

  double _measureTextWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _buildInsertControl(BuildContext context, int index) {
    final compatible = _insertionCandidates(index).isNotEmpty;
    return Tooltip(
      message: compatible
          ? AppLocalizations.of(context)!.taskFlowUiInsertBlockBefore(index + 1)
          : AppLocalizations.of(context)!.taskFlowUiIncompatibleAdjacentBlocks,
      child: TextButton.icon(
        key: ValueKey('insert-block-$index'),
        onPressed: compatible
            ? () => _showAddBlockSheet(context, insertIndex: index)
            : null,
        icon: const Icon(Icons.add, size: 16),
        label: ConstrainedText(
          AppLocalizations.of(context)!.taskFlowUiInsertBeforeStep(index + 1),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  List<BlockTypeDefinition> _insertionCandidates(int index) {
    final previousBlock = index == 0 ? null : blocks[index - 1];
    final previousTypes = previousBlock?.possibleOutputTypes ??
        (index == 0 ? [inputType] : const <IOType>[]);
    final next = index == blocks.length
        ? null
        : blocks[index].getDefinition()?.inputType;
    if (previousTypes.isEmpty || (index < blocks.length && next == null)) {
      return const [];
    }
    return BlockTypeDefinition.getReplacementCandidatesForOutputs(
      prevOutputs: previousTypes,
      nextInput: next,
    );
  }

  void _showAddBlockSheet(BuildContext context, {int? insertIndex}) {
    final cs = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context)!;

    final insertionIndex = insertIndex ?? blocks.length;
    final availableTypes = _insertionCandidates(insertionIndex);
    final previousBlock =
        insertionIndex == 0 ? null : blocks[insertionIndex - 1];
    final previousLabel = insertionIndex == 0
        ? localizedIoTypeLabel(inputType, strings)
        : localizedIoTypeDisplayLabel(
            previousBlock?.outputTypeLabel ?? strings.taskFlowUiUnknown,
            strings,
          );
    final next = insertionIndex == blocks.length
        ? null
        : blocks[insertionIndex].getDefinition()?.inputType;

    showModalBottomSheet(
      context: context,
      constraints: modalBottomSheetWidthConstraints(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (scrollCtx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                insertIndex == null
                    ? AppLocalizations.of(context)!.taskFlowUiChooseBlock
                    : AppLocalizations.of(context)!.taskFlowUiInsertBlock,
                style: Theme.of(scrollCtx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${insertionIndex == 0 ? strings.taskFlowUiInitialInput : strings.taskFlowUiPreviousOutput}: $previousLabel'
                '${next == null ? '' : strings.taskFlowUiNextStepNeeds(localizedIoTypeLabel(next, strings))}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (availableTypes.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.taskFlowUiNoCompatibleBlock,
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: availableTypes
                        .map(
                          (type) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildBlockTypeOption(
                              type,
                              cs,
                              ctx,
                              null,
                              insertIndex: insertIndex,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows the replace-block sheet for the block at [index].
  ///
  /// Only chain-compatible candidates are offered (same or compatible
  /// input/output types) — arbitrary reordering would break the chain.
  void _showReplaceBlockSheet(BuildContext context, int index) {
    final cs = Theme.of(context).colorScheme;
    final block = blocks[index];
    final previousBlock = index == 0 ? null : blocks[index - 1];
    final previousTypes = previousBlock?.possibleOutputTypes ??
        (index == 0 ? [inputType] : const [IOType.any]);
    final nextInput = index == blocks.length - 1
        ? null
        : (blocks[index + 1].getDefinition()?.inputType ?? IOType.any);
    final candidates = BlockTypeDefinition.getReplacementCandidatesForOutputs(
      prevOutputs: previousTypes,
      nextInput: nextInput,
      exclude: block.typeKey,
    );

    showModalBottomSheet(
      context: context,
      constraints: modalBottomSheetWidthConstraints(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (scrollCtx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.taskFlowUiReplaceBlock,
                style: Theme.of(scrollCtx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.taskFlowUiBlockCompatibility,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (candidates.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.taskFlowUiNoCompatibleBlock,
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: candidates
                        .map(
                          (type) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildBlockTypeOption(type, cs, ctx, index),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockTypeOption(
    BlockTypeDefinition type,
    ColorScheme cs,
    BuildContext ctx,
    int? replaceIndex, {
    int? insertIndex,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(ctx);
          if (replaceIndex != null) {
            onReplaceBlock(replaceIndex, type.typeKey);
          } else if (insertIndex != null && onInsertBlock != null) {
            onInsertBlock!(insertIndex, type.typeKey);
          } else {
            onAddBlock(type.typeKey);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(type.icon, size: 20, color: type.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedBlockTypeLabel(type, AppLocalizations.of(ctx)!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${localizedIoTypeLabel(type.inputType, AppLocalizations.of(ctx)!)} → ${type.possibleOutputTypes.map((output) => localizedIoTypeLabel(output, AppLocalizations.of(ctx)!)).join(', ')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                replaceIndex != null
                    ? Icons.swap_horiz
                    : Icons.add_circle_outline,
                size: 20,
                color: cs.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
