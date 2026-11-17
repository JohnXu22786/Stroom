import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/batch_rename.dart';

import 'constrained_text.dart';

String localizedBatchRenameOperationLabel(
  BatchRenameOp operation,
  AppLocalizations strings,
) =>
    switch (operation) {
      BatchNumberOp() => strings.batchRuleTypeNumber,
      BatchReplaceOp() => strings.batchRuleTypeReplace,
      BatchInsertOp() => strings.batchRuleTypeInsert,
      BatchDeleteOp() => strings.batchRuleTypeDelete,
      BatchCaseOp() => strings.batchRuleTypeCase,
      BatchTemplateOp() => strings.batchRuleTypeTemplate,
      BatchCleanupOp() => strings.batchRuleTypeCleanup,
    };

String _localizedBatchRuleValidation(String error, AppLocalizations strings) =>
    switch (error) {
      '最多支持 50 条规则' => strings.batchRuleValidationMaxRules,
      '编号位数应为 1–12' => strings.batchRuleValidationDigits,
      '编号起始值和步长须在 ±999999999 以内' => strings.batchRuleValidationNumberRange,
      '替换规则过长' => strings.batchRuleValidationReplacementLength,
      '正则表达式无效' => strings.batchRuleValidationRegex,
      '删除位置必须从 1 开始' => strings.batchRuleValidationDeleteIndex,
      '插入文本过长' => strings.batchRuleValidationInsertLength,
      '模板编号设置无效：位数 1–12，起始和步长在 ±999999999 以内' =>
        strings.batchRuleValidationTemplateNumber,
      '模板过长' => strings.batchRuleValidationTemplateLength,
      '未知模板变量或未闭合的大括号' => strings.batchRuleValidationTemplateVariable,
      _ => error,
    };

/// One independent editor per rule; raw numeric text survives toggling the rule.
class BatchRenameRuleEditor extends StatefulWidget {
  final BatchRenameOp rule;
  final bool primary;
  final int slotId;
  final ValueChanged<BatchRenameOp> onChanged;
  final ValueChanged<bool> onValidityChanged;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  const BatchRenameRuleEditor({
    super.key,
    required this.rule,
    required this.primary,
    required this.slotId,
    required this.onChanged,
    required this.onValidityChanged,
    this.onUp,
    this.onDown,
    required this.onDuplicate,
    required this.onRemove,
  });
  @override
  State<BatchRenameRuleEditor> createState() => _BatchRenameRuleEditorState();
}

class _BatchRenameRuleEditorState extends State<BatchRenameRuleEditor> {
  final _controllers = <String, TextEditingController>{};
  bool? _lastValid;
  late AppLocalizations _strings;
  Key _key(String key) => Key(widget.primary ? key : '${widget.slotId}:$key');
  TextEditingController _controller(String field, String initial) =>
      _controllers.putIfAbsent(
        field,
        () => TextEditingController(text: initial),
      );

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _numberError(String text, {int? min, int? max}) {
    if (text.trim().isEmpty) return _strings.batchRuleEmpty;
    final value = int.tryParse(text.trim());
    if (value == null) return _strings.batchRuleNumber;
    if (min != null && value < min)
      return min == 1
          ? _strings.batchRulePositive
          : _strings.batchRuleMin(min.toString());
    if (max != null && value > max) {
      return _strings.batchRuleMax(max.toString());
    }
    return null;
  }

  bool _valid(BatchRenameOp op) {
    if (!op.enabled) return true;
    bool number(String field, int value, {int? min, int? max}) =>
        _numberError(
          _controllers[field]?.text ?? '$value',
          min: min,
          max: max,
        ) ==
        null;
    return switch (op) {
      BatchNumberOp r =>
        number('start', r.start, min: -999999999, max: 999999999) &&
            number('step', r.step, min: -999999999, max: 999999999) &&
            number('digits', r.digits, min: 1, max: 12),
      BatchTemplateOp r => !r.pattern.contains('{n}') ||
          (number('start', r.start, min: -999999999, max: 999999999) &&
              number('step', r.step, min: -999999999, max: 999999999) &&
              number('digits', r.digits, min: 1, max: 12)),
      BatchInsertOp r => r.position != BatchRenameInsertPos.atIndex ||
          number('index', r.index, min: 1),
      BatchDeleteOp r => number('count', r.count, min: 1) &&
          (r.position != BatchRenameDeletePos.atIndex ||
              number('index', r.index, min: 1)),
      _ => true,
    };
  }

  void _report(BatchRenameOp rule) {
    final valid = _valid(rule);
    if (_lastValid == valid) return;
    _lastValid = valid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onValidityChanged(valid);
    });
  }

  void _change(BatchRenameOp rule) {
    _report(rule);
    widget.onChanged(rule);
  }

  Widget _text(
    String label,
    String field,
    String initial,
    ValueChanged<String> onChanged, {
    String? hint,
    String? keyName,
    String? help,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          key: keyName == null ? null : _key(keyName),
          controller: _controller(field, initial),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: help,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onChanged,
        ),
      );

  Widget _number(
    String label,
    String field,
    int initial,
    ValueChanged<int> onChanged, {
    int? min,
    int? max,
    String? keyName,
  }) {
    final controller = _controller(field, '$initial');
    return SizedBox(
      width: 140,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          key: keyName == null ? null : _key(keyName),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            errorMaxLines: 2,
            errorText: _numberError(controller.text, min: min, max: max),
          ),
          onChanged: (text) {
            if (_numberError(text, min: min, max: max) == null)
              onChanged(int.parse(text.trim()));
            setState(() {});
            _report(widget.rule);
          },
        ),
      ),
    );
  }

  Widget _choices<T>(
    T value,
    Map<T, String> choices,
    ValueChanged<T> onChanged, {
    String? keyName,
  }) =>
      Wrap(
        key: keyName == null ? null : _key(keyName),
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final e in choices.entries)
            ChoiceChip(
              label: ConstrainedText(
                e.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: value == e.key,
              showCheckmark: false,
              onSelected: (_) => onChanged(e.key),
            ),
        ],
      );

  Widget _check(
    String text,
    bool checked,
    ValueChanged<bool> changed, {
    String? keyName,
  }) =>
      CheckboxListTile(
        key: keyName == null ? null : _key(keyName),
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(text),
        value: checked,
        onChanged: (v) => changed(v ?? false),
      );

  List<Widget> _fields(BatchRenameOp op) => switch (op) {
        BatchNumberOp r => [
            _choices(
              r.position,
              {
                BatchRenameNumberPos.prefix: _strings.batchRulePrefix,
                BatchRenameNumberPos.suffix: _strings.batchRuleSuffix,
              },
              (v) => _change(r.copyWith(position: v)),
              keyName: 'batch_num_pos_selector',
            ),
            Wrap(
              spacing: 8,
              children: [
                _number(
                  _strings.batchRuleStart,
                  'start',
                  r.start,
                  (v) => _change(r.copyWith(start: v)),
                  min: -999999999,
                  max: 999999999,
                  keyName: 'batch_num_start_field',
                ),
                _number(
                  _strings.batchRuleStep,
                  'step',
                  r.step,
                  (v) => _change(r.copyWith(step: v)),
                  min: -999999999,
                  max: 999999999,
                  keyName: 'batch_num_step_field',
                ),
                _number(
                  _strings.batchRuleDigits,
                  'digits',
                  r.digits,
                  (v) => _change(r.copyWith(digits: v)),
                  min: 1,
                  max: 12,
                  keyName: 'batch_num_digits_field',
                ),
              ],
            ),
            _text(
              _strings.batchRuleSeparator,
              'separator',
              r.separator,
              (v) => _change(r.copyWith(separator: v)),
              keyName: 'batch_num_separator_field',
            ),
            _check(
              _strings.batchRuleRestartFolder,
              r.restartPerFolder,
              (v) => _change(r.copyWith(restartPerFolder: v)),
            ),
            Text(_strings.batchRuleNumberHelp, style: TextStyle(fontSize: 12)),
          ],
        BatchReplaceOp r => [
            _text(
              _strings.batchRuleFind,
              'find',
              r.find,
              (v) => _change(r.copyWith(find: v)),
              keyName: 'batch_replace_find_field',
            ),
            _text(
              _strings.batchRuleReplace,
              'replace',
              r.replace,
              (v) => _change(r.copyWith(replace: v)),
              keyName: 'batch_replace_to_field',
            ),
            _check(
              _strings.batchRuleCaseSensitive,
              r.caseSensitive,
              (v) => _change(r.copyWith(caseSensitive: v)),
              keyName: 'batch_replace_case_checkbox',
            ),
            _check(
              _strings.batchRuleRegex,
              r.useRegex,
              (v) => _change(r.copyWith(useRegex: v)),
              keyName: 'batch_replace_regex_checkbox',
            ),
            _check(
              _strings.batchRuleFirstOnly,
              r.firstOnly,
              (v) => _change(r.copyWith(firstOnly: v)),
            ),
            if (r.useRegex)
              SelectableText(
                _strings.batchRuleRegexHelp,
                style: TextStyle(fontSize: 12),
              ),
            if (r.find.isEmpty)
              Text(_strings.batchRuleFindRequired,
                  style: TextStyle(fontSize: 12)),
          ],
        BatchInsertOp r => [
            _choices(
              r.position,
              {
                BatchRenameInsertPos.start: _strings.batchRuleBeginning,
                BatchRenameInsertPos.end: _strings.batchRuleEnd,
                BatchRenameInsertPos.atIndex: _strings.batchRulePosition,
              },
              (v) => _change(r.copyWith(position: v)),
              keyName: 'batch_insert_pos_selector',
            ),
            _text(
              _strings.batchRuleInsertText,
              'text',
              r.text,
              (v) => _change(r.copyWith(text: v)),
              keyName: 'batch_insert_text_field',
            ),
            if (r.position == BatchRenameInsertPos.atIndex)
              _number(
                _strings.batchRuleBeforeChar,
                'index',
                r.index,
                (v) => _change(r.copyWith(index: v)),
                min: 1,
                keyName: 'batch_insert_index_field',
              ),
            Text(_strings.batchRulePositionHelp,
                style: TextStyle(fontSize: 12)),
          ],
        BatchDeleteOp r => [
            _choices(
              r.position,
              {
                BatchRenameDeletePos.start: _strings.batchRuleFromBeginning,
                BatchRenameDeletePos.end: _strings.batchRuleFromEnd,
                BatchRenameDeletePos.atIndex: _strings.batchRulePosition,
              },
              (v) => _change(r.copyWith(position: v)),
              keyName: 'batch_delete_pos_selector',
            ),
            Wrap(
              spacing: 8,
              children: [
                if (r.position == BatchRenameDeletePos.atIndex)
                  _number(
                    _strings.batchRuleFromChar,
                    'index',
                    r.index,
                    (v) => _change(r.copyWith(index: v)),
                    min: 1,
                    keyName: 'batch_delete_index_field',
                  ),
                _number(
                  _strings.batchRuleCount,
                  'count',
                  r.count,
                  (v) => _change(r.copyWith(count: v)),
                  min: 1,
                  keyName: 'batch_delete_count_field',
                ),
              ],
            ),
            Text(_strings.batchRuleDeleteHelp, style: TextStyle(fontSize: 12)),
          ],
        BatchCaseOp r => [
            _choices(
              r.mode,
              {
                BatchRenameCaseMode.upper: _strings.batchRuleUpper,
                BatchRenameCaseMode.lower: _strings.batchRuleLower,
                BatchRenameCaseMode.firstUpper: _strings.batchRuleFirstUpper,
                BatchRenameCaseMode.title: _strings.batchRuleTitleCase,
              },
              (v) => _change(r.copyWith(mode: v)),
              keyName: 'batch_case_mode_selector',
            ),
          ],
        BatchTemplateOp r => [
            _text(
              _strings.batchRuleTemplate,
              'pattern',
              r.pattern,
              (v) => _change(r.copyWith(pattern: v)),
              keyName: 'batch_template_field',
              hint: _strings.batchRuleTemplateHint('{n}', '{name}'),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _strings.batchRuleTemplateHelp(
                '{name}',
                '{n}',
                '{folder}',
                '{created}',
                '{modified}',
                '{ext}',
              ),
              style: TextStyle(fontSize: 12),
            ),
            if (r.pattern.contains('{n}')) ...[
              Wrap(
                spacing: 8,
                children: [
                  _number(
                    _strings.batchRuleStart,
                    'start',
                    r.start,
                    (v) => _change(r.copyWith(start: v)),
                    min: -999999999,
                    max: 999999999,
                  ),
                  _number(
                    _strings.batchRuleStep,
                    'step',
                    r.step,
                    (v) => _change(r.copyWith(step: v)),
                    min: -999999999,
                    max: 999999999,
                  ),
                  _number(
                    _strings.batchRuleDigits,
                    'digits',
                    r.digits,
                    (v) => _change(r.copyWith(digits: v)),
                    min: 1,
                    max: 12,
                  ),
                ],
              ),
              _check(
                _strings.batchRuleRestartFolder,
                r.restartPerFolder,
                (v) => _change(r.copyWith(restartPerFolder: v)),
              ),
            ],
          ],
        BatchCleanupOp r => [
            _check(
              _strings.batchRuleTrim,
              r.trim,
              (v) => _change(r.copyWith(trim: v)),
            ),
            _check(
              _strings.batchRuleCollapseSpaces,
              r.collapseWhitespace,
              (v) => _change(r.copyWith(collapseWhitespace: v)),
            ),
          ],
      };

  @override
  Widget build(BuildContext context) {
    _strings = AppLocalizations.of(context)!;
    final r = widget.rule;
    _report(r);
    final switchName = switch (r) {
      BatchNumberOp() => 'batch_num_switch',
      BatchReplaceOp() => 'batch_replace_switch',
      BatchInsertOp() => 'batch_insert_switch',
      BatchDeleteOp() => 'batch_delete_switch',
      BatchCaseOp() => 'batch_case_switch',
      BatchTemplateOp() => 'batch_template_switch',
      BatchCleanupOp() => 'batch_cleanup_switch',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    localizedBatchRenameOperationLabel(r, _strings),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  key: _key(switchName),
                  value: r.enabled,
                  onChanged: (v) => _change(r.withEnabled(v)),
                ),
                PopupMenuButton<String>(
                  tooltip: _strings.batchRuleActions,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'duplicate',
                      child: ConstrainedText(
                        _strings.batchRuleDuplicate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'remove',
                      child: ConstrainedText(
                        _strings.batchRuleRemove,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onSelected: (v) => v == 'duplicate'
                      ? widget.onDuplicate()
                      : widget.onRemove(),
                ),
              ],
            ),
            if (r.enabled) ...[
              ..._fields(r),
              if (validateBatchRenameConfig(BatchRenameConfig(rules: [r]))
                  case final String error)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _localizedBatchRuleValidation(error, _strings),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  IconButton(
                    key: Key('batch_rule_up_${widget.slotId}'),
                    tooltip: _strings.batchRuleMoveUp,
                    onPressed: widget.onUp,
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                  IconButton(
                    key: Key('batch_rule_down_${widget.slotId}'),
                    tooltip: _strings.batchRuleMoveDown,
                    onPressed: widget.onDown,
                    icon: const Icon(Icons.arrow_downward, size: 18),
                  ),
                  IconButton(
                    key: Key('batch_rule_duplicate_${widget.slotId}'),
                    tooltip: _strings.batchRuleDuplicate,
                    onPressed: widget.onDuplicate,
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
