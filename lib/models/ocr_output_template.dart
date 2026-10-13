/// A built-in, opt-in output-format instruction for standalone OCR.
///
/// [selectionValue] is stable because non-negative selector values are
/// reserved for the user's persisted custom instructions. The default
/// images-only choice is -1 and a saved retry snapshot uses -2.
class OcrOutputTemplate {
  final String id;
  final String label;
  final String content;
  final int selectionValue;

  const OcrOutputTemplate({
    required this.id,
    required this.label,
    required this.content,
    required this.selectionValue,
  });
}

/// Built-in formats remain separate from the user's persisted instructions.
const ocrOutputTemplates = <OcrOutputTemplate>[
  OcrOutputTemplate(
    id: 'plain_text',
    label: '纯文本模板',
    selectionValue: -3,
    content:
        '请按页面的自然阅读顺序转录所有可见文字，保留换行与段落。'
        '只返回纯文本，不添加说明或推断。',
  ),
  OcrOutputTemplate(
    id: 'markdown',
    label: 'Markdown 模板',
    selectionValue: -4,
    content:
        '请按页面的自然阅读顺序转录所有可见文字，并用 Markdown 保留'
        '页面中的标题、列表和表格结构。数学公式使用 LaTeX 表示。'
        '只返回转录结果，不添加说明或推断。',
  ),
  OcrOutputTemplate(
    id: 'table',
    label: '表格模板',
    selectionValue: -5,
    content:
        '请按页面的自然阅读顺序转录所有可见文字。遇到表格时完整保留'
        '表头、行列关系及空单元格，并以 Markdown 表格输出；其他内容按'
        '普通文本保留。只返回转录结果，不添加说明或推断。',
  ),
  OcrOutputTemplate(
    id: 'latex',
    label: 'LaTeX 模板',
    selectionValue: -6,
    content:
        '请按页面的自然阅读顺序转录所有可见文字。保留非公式文字，'
        '并将数学公式用 LaTeX 表示；行内公式使用 \$...\$，独立公式'
        '使用 \$\$...\$\$。只返回转录结果，不添加说明或推断。',
  ),
];

OcrOutputTemplate? ocrOutputTemplateForSelection(int selectionValue) {
  for (final template in ocrOutputTemplates) {
    if (template.selectionValue == selectionValue) return template;
  }
  return null;
}
