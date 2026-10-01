import 'package:flutter/material.dart';
import '../utils/batch_rename.dart';

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
  const BatchRenameRuleEditor(
      {super.key,
      required this.rule,
      required this.primary,
      required this.slotId,
      required this.onChanged,
      required this.onValidityChanged,
      this.onUp,
      this.onDown,
      required this.onDuplicate,
      required this.onRemove});
  @override
  State<BatchRenameRuleEditor> createState() => _BatchRenameRuleEditorState();
}

class _BatchRenameRuleEditorState extends State<BatchRenameRuleEditor> {
  final _controllers = <String, TextEditingController>{};
  bool? _lastValid;
  Key _key(String key) => Key(widget.primary ? key : '${widget.slotId}:$key');
  TextEditingController _controller(String field, String initial) =>
      _controllers.putIfAbsent(
          field, () => TextEditingController(text: initial));

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _numberError(String text, {int? min, int? max}) {
    if (text.trim().isEmpty) return '不能为空';
    final value = int.tryParse(text.trim());
    if (value == null) return '请输入数字';
    if (min != null && value < min)
      return min == 1 ? '请输入大于 0 的数字' : '不能小于 $min';
    if (max != null && value > max) return '不能大于 $max';
    return null;
  }

  bool _valid(BatchRenameOp op) {
    if (!op.enabled) return true;
    bool number(String field, int value, {int? min, int? max}) =>
        _numberError(_controllers[field]?.text ?? '$value',
            min: min, max: max) ==
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

  Widget _text(String label, String field, String initial,
          ValueChanged<String> onChanged,
          {String? hint, String? keyName, String? help}) =>
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
                  isDense: true),
              onChanged: onChanged));

  Widget _number(
      String label, String field, int initial, ValueChanged<int> onChanged,
      {int? min, int? max, String? keyName}) {
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
                errorText: _numberError(controller.text, min: min, max: max)),
            onChanged: (text) {
              if (_numberError(text, min: min, max: max) == null)
                onChanged(int.parse(text.trim()));
              setState(() {});
              _report(widget.rule);
            },
          ),
        ));
  }

  Widget _choices<T>(T value, Map<T, String> choices, ValueChanged<T> onChanged,
          {String? keyName}) =>
      Wrap(
          key: keyName == null ? null : _key(keyName),
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final e in choices.entries)
              ChoiceChip(
                  label: Text(e.value),
                  selected: value == e.key,
                  showCheckmark: false,
                  onSelected: (_) => onChanged(e.key))
          ]);

  Widget _check(String text, bool checked, ValueChanged<bool> changed,
          {String? keyName}) =>
      CheckboxListTile(
          key: keyName == null ? null : _key(keyName),
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(text),
          value: checked,
          onChanged: (v) => changed(v ?? false));

  List<Widget> _fields(BatchRenameOp op) => switch (op) {
        BatchNumberOp r => [
            _choices(
                r.position,
                {
                  BatchRenameNumberPos.prefix: '前缀',
                  BatchRenameNumberPos.suffix: '后缀'
                },
                (v) => _change(r.copyWith(position: v)),
                keyName: 'batch_num_pos_selector'),
            Wrap(spacing: 8, children: [
              _number(
                  '起始', 'start', r.start, (v) => _change(r.copyWith(start: v)),
                  min: -999999999,
                  max: 999999999,
                  keyName: 'batch_num_start_field'),
              _number('步长', 'step', r.step, (v) => _change(r.copyWith(step: v)),
                  min: -999999999,
                  max: 999999999,
                  keyName: 'batch_num_step_field'),
              _number('位数', 'digits', r.digits,
                  (v) => _change(r.copyWith(digits: v)),
                  min: 1, max: 12, keyName: 'batch_num_digits_field'),
            ]),
            _text('分隔符', 'separator', r.separator,
                (v) => _change(r.copyWith(separator: v)),
                keyName: 'batch_num_separator_field'),
            _check('每个目录重新编号', r.restartPerFolder,
                (v) => _change(r.copyWith(restartPerFolder: v))),
            const Text('编号按预览顺序分配；排除项不占序号。步长可为负数或 0。',
                style: TextStyle(fontSize: 12)),
          ],
        BatchReplaceOp r => [
            _text('查找内容', 'find', r.find, (v) => _change(r.copyWith(find: v)),
                keyName: 'batch_replace_find_field'),
            _text('替换为（留空删除）', 'replace', r.replace,
                (v) => _change(r.copyWith(replace: v)),
                keyName: 'batch_replace_to_field'),
            _check('区分大小写', r.caseSensitive,
                (v) => _change(r.copyWith(caseSensitive: v)),
                keyName: 'batch_replace_case_checkbox'),
            _check('正则表达式', r.useRegex, (v) => _change(r.copyWith(useRegex: v)),
                keyName: 'batch_replace_regex_checkbox'),
            _check('仅替换首次匹配', r.firstOnly,
                (v) => _change(r.copyWith(firstOnly: v))),
            if (r.useRegex)
              const SelectableText(
                  r'捕获组：$1、$2；完整匹配：$0；字面 $：$$。例如 ^IMG_(\d+)$ → 照片_$1',
                  style: TextStyle(fontSize: 12)),
            if (r.find.isEmpty)
              const Text('填写查找内容后生效。', style: TextStyle(fontSize: 12)),
          ],
        BatchInsertOp r => [
            _choices(
                r.position,
                {
                  BatchRenameInsertPos.start: '开头',
                  BatchRenameInsertPos.end: '结尾',
                  BatchRenameInsertPos.atIndex: '指定位置'
                },
                (v) => _change(r.copyWith(position: v)),
                keyName: 'batch_insert_pos_selector'),
            _text('插入文本', 'text', r.text, (v) => _change(r.copyWith(text: v)),
                keyName: 'batch_insert_text_field'),
            if (r.position == BatchRenameInsertPos.atIndex)
              _number('第 N 个字符前', 'index', r.index,
                  (v) => _change(r.copyWith(index: v)),
                  min: 1, keyName: 'batch_insert_index_field'),
            const Text('位置从 1 开始；超过末尾时追加。组合 emoji 按一个字符计算。',
                style: TextStyle(fontSize: 12)),
          ],
        BatchDeleteOp r => [
            _choices(
                r.position,
                {
                  BatchRenameDeletePos.start: '从开头',
                  BatchRenameDeletePos.end: '从结尾',
                  BatchRenameDeletePos.atIndex: '指定位置'
                },
                (v) => _change(r.copyWith(position: v)),
                keyName: 'batch_delete_pos_selector'),
            Wrap(spacing: 8, children: [
              if (r.position == BatchRenameDeletePos.atIndex)
                _number('从第 N 个字符起', 'index', r.index,
                    (v) => _change(r.copyWith(index: v)),
                    min: 1, keyName: 'batch_delete_index_field'),
              _number(
                  '数量', 'count', r.count, (v) => _change(r.copyWith(count: v)),
                  min: 1, keyName: 'batch_delete_count_field'),
            ]),
            const Text('名称删空后需由后续插入规则补充，才能执行。', style: TextStyle(fontSize: 12)),
          ],
        BatchCaseOp r => [
            _choices(
                r.mode,
                {
                  BatchRenameCaseMode.upper: '全大写',
                  BatchRenameCaseMode.lower: '全小写',
                  BatchRenameCaseMode.firstUpper: '首字母大写',
                  BatchRenameCaseMode.title: '每词首字母大写'
                },
                (v) => _change(r.copyWith(mode: v)),
                keyName: 'batch_case_mode_selector'),
          ],
        BatchTemplateOp r => [
            _text('新名称模板', 'pattern', r.pattern,
                (v) => _change(r.copyWith(pattern: v)),
                keyName: 'batch_template_field', hint: '课程_{n}_{name}'),
            const SizedBox(height: 8),
            const SelectableText(
                '{name} 原名 · {n} 序号 · {folder} 所在目录名\n{created} 创建日期 · {modified} 修改日期 · {ext} 原扩展名\n日期格式 YYYY-MM-DD；缺少日期时会提示。模板替换整个基础名，扩展名仍自动保留。',
                style: TextStyle(fontSize: 12)),
            if (r.pattern.contains('{n}')) ...[
              Wrap(spacing: 8, children: [
                _number('起始', 'start', r.start,
                    (v) => _change(r.copyWith(start: v)),
                    min: -999999999, max: 999999999),
                _number(
                    '步长', 'step', r.step, (v) => _change(r.copyWith(step: v)),
                    min: -999999999, max: 999999999),
                _number('位数', 'digits', r.digits,
                    (v) => _change(r.copyWith(digits: v)),
                    min: 1, max: 12),
              ]),
              _check('每个目录重新编号', r.restartPerFolder,
                  (v) => _change(r.copyWith(restartPerFolder: v))),
            ],
          ],
        BatchCleanupOp r => [
            _check('去掉首尾空白', r.trim, (v) => _change(r.copyWith(trim: v))),
            _check('连续空白合并为一个空格', r.collapseWhitespace,
                (v) => _change(r.copyWith(collapseWhitespace: v))),
          ],
      };

  @override
  Widget build(BuildContext context) {
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
                  Row(children: [
                    Expanded(
                        child: Text(r.label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                    Switch(
                        key: _key(switchName),
                        value: r.enabled,
                        onChanged: (v) => _change(r.withEnabled(v))),
                    PopupMenuButton<String>(
                        tooltip: '规则操作',
                        itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'duplicate', child: Text('复制规则')),
                              const PopupMenuItem(
                                  value: 'remove', child: Text('删除规则')),
                            ],
                        onSelected: (v) => v == 'duplicate'
                            ? widget.onDuplicate()
                            : widget.onRemove()),
                  ]),
                  if (r.enabled) ...[
                    ..._fields(r),
                    if (validateBatchRenameConfig(BatchRenameConfig(rules: [r]))
                        case final String error)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(error,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    Wrap(alignment: WrapAlignment.end, children: [
                      IconButton(
                          key: Key('batch_rule_up_${widget.slotId}'),
                          tooltip: '上移规则',
                          onPressed: widget.onUp,
                          icon: const Icon(Icons.arrow_upward, size: 18)),
                      IconButton(
                          key: Key('batch_rule_down_${widget.slotId}'),
                          tooltip: '下移规则',
                          onPressed: widget.onDown,
                          icon: const Icon(Icons.arrow_downward, size: 18)),
                      IconButton(
                          key: Key('batch_rule_duplicate_${widget.slotId}'),
                          tooltip: '复制规则',
                          onPressed: widget.onDuplicate,
                          icon: const Icon(Icons.copy, size: 18)),
                    ]),
                  ],
                ])));
  }
}
