import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// 代码编辑辅助（自定义参数 JSON 值编辑器共享组件）
// ============================================================================
//
// 模型页 / 供应商面板 / 助手页面等多处存在完全相同的「行号 + 等宽字体
// 多行输入」编辑器与全屏 JSON 编辑器对话框。本文件将其收敛为共享实现，
// 并补上此前缺失的编辑辅助：
//   - 括号/引号自动补全（()[]{}""''），输入闭合符时自动跳过；
//   - 回车自动缩进（行首空白继承，{ [ ( : 后加一级；换行前是闭合符时对齐父级）；
//   - 在仅含空白的行上输入闭合符时自动减缩进；
//   - 退格删除成对的括号/引号；
//   - 选中文本后输入括号时包裹选区；
//   - 行号随输入实时更新（此前全屏编辑器行号不刷新）；
//   - JSON 实时校验（此前全屏编辑器输入时不更新错误与保存按钮状态）；
//   - JSON 一键格式化按钮。
// 所有智能行为在 IME 组合输入（中文输入法）期间自动停用。

/// 参数名点号分段是否为合法嵌套路径（不能有空段、分段内不能有首尾
/// 空白）：
/// `provider.only` 合法；`provider..only`、`.only`、`provider.`、
/// `provider .only`（分段带空白，请求键会与展示不一致）不合法。
bool isValidParamName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return false;
  return trimmed
      .split('.')
      .every((part) => part.isNotEmpty && part == part.trim());
}

/// 把 JSON 解析异常格式化为「第 X 行第 Y 列」的人类可读信息。
String formatJsonError(String source, dynamic error) {
  if (error is FormatException) {
    final offset = error.offset;
    final msg = error.message;
    if (offset != null && offset >= 0 && offset <= source.length) {
      final before = source.substring(0, offset);
      final lines = before.split('\n');
      final line = lines.length;
      final col = lines.last.length + 1;
      return '第 $line 行第 $col 列: $msg';
    }
    return 'JSON 格式错误: $msg';
  }
  return 'JSON 格式不正确';
}

/// 智能输入格式化器：括号/引号自动补全、闭合符跳过、选区包裹、
/// 回车自动缩进、闭合符自动减缩进、成对退格删除。
///
/// 通过 [TextInputFormatter] 接入任意 TextField/TextFormField，
/// 不依赖具体编辑控件；修改文本的同时返回新的光标位置。
class CodeSmartInputFormatter extends TextInputFormatter {
  const CodeSmartInputFormatter();

  static const String _indentUnit = '  ';
  static const Map<String, String> _openers = {
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    "'": "'",
  };
  static const Set<String> _bracketClosers = {')', ']', '}'};
  static const Set<String> _allClosers = {')', ']', '}', '"', "'"};
  static const Set<String> _indentOpeners = {'{', '[', '(', ':'};
  static const Set<String> _quoteStarters = {'(', '[', '{', ',', ':', '='};

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // IME 组合输入（中文等输入法上屏中）期间不做任何智能改写，
    // 避免破坏候选词与拼音输入。
    if (newValue.composing.isValid) return newValue;

    final oldText = oldValue.text;
    final newText = newValue.text;
    final oldSel = oldValue.selection;
    final newSel = newValue.selection;

    // ---------------- 选区被单字符替换：开括号包裹选区 ----------------
    if (oldSel.isValid && !oldSel.isCollapsed) {
      final selLen = oldSel.end - oldSel.start;
      if (newText.length == oldText.length - selLen + 1 &&
          newSel.isValid &&
          newSel.isCollapsed &&
          newText.substring(0, oldSel.start) ==
              oldText.substring(0, oldSel.start) &&
          newText.substring(oldSel.start + 1) ==
              oldText.substring(oldSel.end)) {
        final inserted = newText[oldSel.start];
        final closing = _openers[inserted];
        if (closing != null) {
          // `ab` + 选中 `b` + `{` → `a{b}`，保持选区包裹内容。
          final inner = oldText.substring(oldSel.start, oldSel.end);
          final text = newText.substring(0, oldSel.start + 1) +
              inner +
              closing +
              newText.substring(oldSel.start + 1);
          final start = oldSel.start + 1;
          return TextEditingValue(
            text: text,
            selection: TextSelection(
              baseOffset: start,
              extentOffset: start + inner.length,
            ),
          );
        }
      }
      return newValue;
    }

    // ---------------- 单字符插入（以光标位置为准） ----------------
    if (newText.length == oldText.length + 1 &&
        newSel.isValid &&
        newSel.isCollapsed) {
      final insertPos = newSel.baseOffset - 1;
      if (insertPos < 0 || insertPos >= newText.length) return newValue;
      // 确认插入确实发生在光标处（防御程序化的非光标文本变化）。
      if (oldText.substring(0, insertPos) != newText.substring(0, insertPos)) {
        return newValue;
      }
      final inserted = newText[insertPos];

      // 回车自动缩进。
      if (inserted == '\n' || inserted == '\r') {
        return _handleNewline(oldText, newText, insertPos);
      }

      final closing = _openers[inserted];
      if (closing != null) {
        final next =
            insertPos + 1 < newText.length ? newText[insertPos + 1] : null;
        final isQuote = inserted == '"' || inserted == "'";
        if (isQuote) {
          // 下一个字符已是引号：视为输入闭合引号 → 跳过（不重复插入）。
          if (next == inserted) {
            return TextEditingValue(
              text: oldText,
              selection: TextSelection.collapsed(offset: insertPos + 1),
            );
          }
          // 引号只在「起始符/空白/行首」后自动补全，避免在单词中间
          // 输入闭合引号时意外多出一个引号。
          if (!_isQuoteStarter(oldText, insertPos)) {
            return newValue;
          }
        } else if (next == closing) {
          // 下一个字符已是本开括号的闭合符：只插入开括号，不再补一个。
          return newValue;
        }
        final text = newText.substring(0, insertPos + 1) +
            closing +
            newText.substring(insertPos + 1);
        return TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: insertPos + 1),
        );
      }

      if (_allClosers.contains(inserted)) {
        // 输入闭合符且下一个字符就是它 → 跳过不重复插入。
        if (insertPos + 1 < newText.length &&
            newText[insertPos + 1] == inserted) {
          return TextEditingValue(
            text: oldText,
            selection: TextSelection.collapsed(offset: insertPos + 1),
          );
        }
        // 在仅含空白的行上输入闭合符 → 自动减一级缩进。
        if (_bracketClosers.contains(inserted)) {
          final unindented = _handleCloserOnWhitespaceLine(
            oldText,
            insertPos,
            inserted,
          );
          if (unindented != null) return unindented;
        }
      }
      return newValue;
    }

    // ---------------- 单字符删除（退格删除光标前一字符） ----------------
    if (newText.length == oldText.length - 1 &&
        oldSel.isValid &&
        oldSel.isCollapsed &&
        newSel.isValid &&
        newSel.isCollapsed) {
      final deletePos = oldSel.baseOffset - 1;
      if (deletePos < 0 || deletePos >= oldText.length) return newValue;
      // 仅退格触发成对删除：退格后光标停在删除位置（deletePos），
      // Del 键（向前删除）光标停在 deletePos + 1，不应触发。
      if (newSel.baseOffset != deletePos) return newValue;
      if (newText.substring(0, deletePos) != oldText.substring(0, deletePos)) {
        return newValue;
      }
      final deleted = oldText[deletePos];
      final next =
          deletePos + 1 < oldText.length ? oldText[deletePos + 1] : null;
      if (next != null && _openers[deleted] == next) {
        // 光标在成对括号中间退格 → 成对删除。
        return TextEditingValue(
          text: oldText.substring(0, deletePos) +
              oldText.substring(deletePos + 2),
          selection: TextSelection.collapsed(offset: deletePos),
        );
      }
    }

    return newValue;
  }

  /// 插入位置 [diff] 之前（跳过空白）是否属于适合补全引号的位置。
  /// 行首/文本开头、或前一个有效字符为起始符（`( [ { , : =`）时补全。
  static bool _isQuoteStarter(String text, int diff) {
    var i = diff - 1;
    while (i >= 0 && (text[i] == ' ' || text[i] == '\t')) {
      i--;
    }
    if (i < 0) return true; // 行首/文本开头
    return _quoteStarters.contains(text[i]) ||
        text[i] == '\n' ||
        text[i] == '\r';
  }

  /// 回车缩进：新行继承当前行缩进；当前行以 `{ [ ( :` 结尾则加一级；
  /// 换行后紧跟闭合符（`} ] )`）则对齐父级缩进。
  static TextEditingValue _handleNewline(
    String oldText,
    String newText,
    int diff,
  ) {
    final lineStart = oldText.lastIndexOf('\n', diff - 1) + 1;
    final lineText = oldText.substring(lineStart, diff);
    var indent = _leadingWhitespace(lineText);
    final trimmed = lineText.trimRight();
    if (trimmed.isNotEmpty &&
        _indentOpeners.contains(trimmed[trimmed.length - 1])) {
      indent += _indentUnit;
    }
    var j = diff + 1;
    while (j < newText.length && (newText[j] == ' ' || newText[j] == '\t')) {
      j++;
    }
    if (j < newText.length && _bracketClosers.contains(newText[j])) {
      indent = indent.length >= _indentUnit.length
          ? indent.substring(0, indent.length - _indentUnit.length)
          : '';
    }
    final text =
        '${newText.substring(0, diff)}\n$indent${newText.substring(diff + 1)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: diff + 1 + indent.length),
    );
  }

  static String _leadingWhitespace(String line) {
    var i = 0;
    while (i < line.length && (line[i] == ' ' || line[i] == '\t')) {
      i++;
    }
    return line.substring(0, i);
  }

  /// 在仅含空白（且缩进至少一级）的行上输入闭合符 → 整行减一级缩进。
  /// 非空白行返回 null（调用方保持普通插入）。
  static TextEditingValue? _handleCloserOnWhitespaceLine(
    String oldText,
    int diff,
    String closer,
  ) {
    final lineStart = oldText.lastIndexOf('\n', diff - 1) + 1;
    final lineBefore = oldText.substring(lineStart, diff);
    if (lineBefore.trim().isEmpty && lineBefore.length >= _indentUnit.length) {
      final newIndent =
          lineBefore.substring(0, lineBefore.length - _indentUnit.length);
      final text = oldText.substring(0, lineStart) +
          newIndent +
          closer +
          oldText.substring(diff);
      return TextEditingValue(
        text: text,
        selection:
            TextSelection.collapsed(offset: lineStart + newIndent.length + 1),
      );
    }
    return null;
  }
}

/// 带行号与智能编辑辅助的代码输入框（等宽字体、多行、随输入实时刷新行号）。
class CodeEditorField extends StatefulWidget {
  const CodeEditorField({
    super.key,
    required this.controller,
    this.hintText,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  State<CodeEditorField> createState() => _CodeEditorFieldState();
}

class _CodeEditorFieldState extends State<CodeEditorField> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScrolled);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScrolled);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // 行号列随输入实时刷新（修复旧版全屏编辑器行号不更新的问题）。
    if (mounted) setState(() {});
  }

  void _onScrolled() {
    if (!mounted) return;
    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    if (offset != _scrollOffset) {
      setState(() => _scrollOffset = offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineCount = widget.controller.text.split('\n').length;
    final digitCount = lineCount.toString().length;
    final lineNumWidth = (digitCount * 8.0 + 20.0).clamp(36.0, 80.0);
    // 与文本区行高一致（fontSize 13 × height 1.3），行号与文本逐行对齐。
    const lineHeight = 16.9;
    const textTopPadding = 11.0; // 与 contentPadding 顶部一致

    return LayoutBuilder(
      builder: (context, constraints) {
        // 行号列与文本区同高，随滚动偏移平移，避免长内容滚动时行号
        // 溢出或与文本错位。
        final height = constraints.maxHeight;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 行号列
            SizedBox(
              width: lineNumWidth,
              height: height,
              child: ClipRect(
                child: Transform.translate(
                  offset: Offset(0, -_scrollOffset),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: textTopPadding,
                      right: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(lineCount, (i) {
                        return SizedBox(
                          height: lineHeight,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              height: 1.3,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: height,
              child: Container(width: 1, color: Colors.grey.shade300),
            ),
            // 可编辑文本区
            Expanded(
              child: TextField(
                controller: widget.controller,
                scrollController: _scrollController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                autofocus: widget.autofocus,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.3,
                ),
                inputFormatters: const [CodeSmartInputFormatter()],
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(8, 11, 8, 12),
                  isCollapsed: true,
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 全屏「编辑参数值」对话框：JSON 实时校验 + 格式化按钮 + 智能代码编辑。
/// 供模型页 / 供应商面板 / 助手页面 / ASR / OCR 共用（此前每个页面
/// 各有一份近似副本，且输入时行号与校验均不刷新）。
Future<void> showJsonValueEditorDialog(
  BuildContext context, {
  required String initialValue,
  required String hintText,
  required String type,
  required ValueChanged<String> onSave,
}) {
  final editingController = TextEditingController(text: initialValue);
  String? liveError;

  void validateLive() {
    if (type == 'json') {
      final trimmed = editingController.text.trim();
      if (trimmed.isNotEmpty) {
        try {
          jsonDecode(trimmed);
          liveError = null;
        } catch (e) {
          // 用与 jsonDecode 相同的（去首尾空白）源文本计算行列，
          // 否则前导空白会把错误位置整体偏移。
          liveError = formatJsonError(trimmed, e);
        }
      } else {
        liveError = null;
      }
    } else {
      liveError = null;
    }
  }

  validateLive();

  void formatPretty() {
    final text = editingController.text.trim();
    if (text.isEmpty) return;
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(
        jsonDecode(text),
      );
      editingController.text = pretty;
      editingController.selection =
          TextSelection.collapsed(offset: pretty.length);
      liveError = null;
    } catch (_) {
      // 无效 JSON 不格式化，由错误栏提示。
    }
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 标题栏
              Row(
                children: [
                  Icon(
                    type == 'json' ? Icons.data_object : Icons.edit_note,
                    size: 20,
                    color: type == 'json' ? Colors.amber.shade700 : null,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '编辑参数值',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  if (type == 'json') ...[
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'JSON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.format_align_left, size: 16),
                      label: const Text('格式化'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: (liveError == null &&
                              editingController.text.trim().isNotEmpty)
                          ? () => setDlgState(formatPretty)
                          : null,
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      editingController.dispose();
                      Navigator.pop(ctx);
                    },
                    tooltip: '取消',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 代码编辑区
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xfff5f5f5),
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CodeEditorField(
                    controller: editingController,
                    hintText: hintText,
                    autofocus: true,
                    onChanged: (_) => setDlgState(validateLive),
                  ),
                ),
              ),
              // 错误信息栏
              if (liveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            liveError!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // 操作按钮
              Row(
                children: [
                  if (liveError != null)
                    Text(
                      'JSON 格式有误，请修正后再保存',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade400,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      editingController.dispose();
                      Navigator.pop(ctx);
                    },
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('确定'),
                    onPressed: liveError != null
                        ? null
                        : () {
                            final text = editingController.text;
                            editingController.dispose();
                            Navigator.pop(ctx);
                            onSave(text);
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 参数名嵌套路径预览：`provider.only` 自动分行展示为
/// `provider` / `└ only`，提示请求时会展开为嵌套 JSON。
/// 仅对合法点号名显示（非法名由输入框错误提示负责）。
class ParamNamePathPreview extends StatelessWidget {
  const ParamNamePathPreview({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trimmedName = name.trim();
    final segments = isValidParamName(trimmedName)
        ? trimmedName.split('.')
        : const <String>[];
    if (segments.length < 2) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '参数名解析（请求时展开为嵌套 JSON）',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < segments.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i * 12.0),
              child: Text(
                '${i == 0 ? '' : '└ '}${segments[i]}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
