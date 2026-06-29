import 'package:flutter/material.dart';
import '../providers/provider_config.dart';
import 'voice_batch_add_shared.dart';

// ============================================================================
// 批量添加音色页面
// ============================================================================

class VoiceBatchAddPage extends StatefulWidget {
  final List<VoiceEntry> existingVoices;

  const VoiceBatchAddPage({super.key, required this.existingVoices});

  @override
  State<VoiceBatchAddPage> createState() => _VoiceBatchAddPageState();
}

class _VoiceBatchAddPageState extends State<VoiceBatchAddPage> {
  static const List<String> _separatorOptions = [
    'Tab',
    '逗号 (,)',
    '分号 (;)',
    '竖线 (|)',
    '自定义...',
  ];

  String _selectedSeparator = 'Tab';
  String _customSeparator = '';
  bool _nameFirst = true; // true → 第1个=名称, 第2个=ID
  final TextEditingController _inputController = TextEditingController();
  List<ParsedLine> _parsedLines = [];

  /// 检测到的最大列数（多行取最大值）
  int _detectedColumns = 0;

  /// 每列的样本数据（从第一个非空行提取），用于多列选择提示
  List<String> _columnSamples = [];

  /// 多列模式下用户选择的起始列索引（从此列开始取两个连续字段作为名称和ID）
  int _selectedColumnStart = 0;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // 解析逻辑
  // --------------------------------------------------------------------------

  String get _separatorChar {
    switch (_selectedSeparator) {
      case 'Tab':
        return '\t';
      case '逗号 (,)':
        return ',';
      case '分号 (;)':
        return ';';
      case '竖线 (|)':
        return '|';
      case '自定义...':
        return _customSeparator;
      default:
        return '\t';
    }
  }

  // ============================================================
  // 辅助：从一行中提取有效字段（剥离首尾分隔符、trim、滤空）
  // ============================================================

  List<String> _extractFields(String rawLine, String sep) {
    var line = rawLine.trim();
    if (line.isEmpty) return [];
    // 剥离首尾分隔符
    if (sep.isNotEmpty) {
      while (line.startsWith(sep)) {
        line = line.substring(sep.length).trimLeft();
      }
      while (line.endsWith(sep)) {
        line = line.substring(0, line.length - sep.length).trimRight();
      }
    }
    if (line.isEmpty) return [];
    return line
        .split(sep)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  void _parseInput() {
    final text = _inputController.text;
    if (text.trim().isEmpty) {
      setState(() {
        _parsedLines = [];
        _detectedColumns = 0;
        _columnSamples = [];
      });
      return;
    }

    // 自动检测分隔符
    _autoDetectSeparator(text);

    final lines = text.split('\n');
    final separator = _separatorChar;
    final List<ParsedLine> parsed = [];
    final Set<String> seenIds = {};
    final existingIds = widget.existingVoices.map((v) => v.id).toSet();

    int maxColumns = 0;
    List<String>? firstRowFields;

    for (int i = 0; i < lines.length; i++) {
      final fields = _extractFields(lines[i], separator);
      if (fields.isEmpty) continue;

      if (fields.length > maxColumns) {
        maxColumns = fields.length;
      }
      firstRowFields ??= List.from(fields);

      // ── 根据不同列数解析 ──

      if (fields.length == 1) {
        // 单列 → 作为 ID 处理，名称也等于 ID
        final id = fields[0];
        final status = (existingIds.contains(id) || seenIds.contains(id))
            ? LineStatus.duplicate
            : LineStatus.newVoice;
        seenIds.add(id);
        parsed.add(ParsedLine(
          index: i,
          name: id,
          id: id,
          status: status,
        ));
      } else if (fields.length >= 2) {
        // 两列或更多列：取用户选择的起始列开始的两个字段
        final start = (_detectedColumns > 2) ? _selectedColumnStart : 0;
        final first = fields[start];
        final second = (start + 1 < fields.length) ? fields[start + 1] : '';

        if (second.isEmpty || first.isEmpty) {
          parsed.add(ParsedLine(
            index: i,
            name: '',
            id: '',
            status: LineStatus.formatError,
            errorMsg: '所选列数据不足',
          ));
          continue;
        }

        final name = _nameFirst ? first : second;
        final id = _nameFirst ? second : first;

        final status = (existingIds.contains(id) || seenIds.contains(id))
            ? LineStatus.duplicate
            : LineStatus.newVoice;
        seenIds.add(id);
        parsed.add(ParsedLine(
          index: i,
          name: name,
          id: id,
          status: status,
        ));
      }
    }

    final prevDetected = _detectedColumns;

    setState(() {
      _detectedColumns = maxColumns;
      _columnSamples = firstRowFields ?? [];
      // 如果是首次检测到多列，重置列选择
      if (prevDetected != maxColumns && maxColumns > 2) {
        _selectedColumnStart = 0;
      }
      _parsedLines = parsed;
    });
  }

  // --------------------------------------------------------------------------
  // 确认添加逻辑
  // --------------------------------------------------------------------------

  bool get _canConfirm =>
      _parsedLines.isNotEmpty &&
      _parsedLines.any((p) => p.status != LineStatus.formatError);

  void _onConfirm() {
    if (!_canConfirm) return;

    final result = <VoiceEntry>[];

    for (final line in _parsedLines) {
      if (line.status == LineStatus.formatError) continue;
      result.add(VoiceEntry(name: line.name, id: line.id));
    }

    Navigator.pop(context, result);
  }

  // --------------------------------------------------------------------------
  // 重复相关
  // --------------------------------------------------------------------------

  bool get _hasDuplicates =>
      _parsedLines.any((p) => p.status == LineStatus.duplicate);

  Set<String> get _duplicateIds => _parsedLines
      .where((p) => p.status == LineStatus.duplicate)
      .map((p) => p.id)
      .toSet();

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('批量添加音色'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _canConfirm ? _onConfirm : null,
            child: Text(
              '确认添加',
              style: TextStyle(
                color: _canConfirm ? null : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildParseSettingsCard(),
            const SizedBox(height: 12),
            _buildInputArea(),
            if (_hasDuplicates) const SizedBox(height: 8),
            _buildDuplicateBar(),
            const SizedBox(height: 12),
            _buildPreviewCard(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 自动检测分隔符：在预设中选能使最多行解析出 ≥2 列的
  // ============================================================

  void _autoDetectSeparator(String text) {
    const candidates = [
      ('Tab', '\t'),
      ('逗号 (,)', ','),
      ('分号 (;)', ';'),
      ('竖线 (|)', '|'),
    ];

    String bestLabel = _selectedSeparator;
    int bestScore = -1;

    for (final (label, sep) in candidates) {
      if (sep.isEmpty) continue;
      final rawLines = text.split('\n');
      int score = 0;
      for (final raw in rawLines) {
        final fields = _extractFields(raw, sep);
        if (fields.length >= 2) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestLabel = label;
      }
    }

    // 只有当检测到的分隔符与当前不同且有一定置信度时才切换
    if (bestScore >= 1 && bestLabel != _selectedSeparator) {
      _selectedSeparator = bestLabel;
    }
  }

  // --------------------------------------------------------------------------
  // 辅助：顺序选择按钮
  // --------------------------------------------------------------------------

  Widget _buildOrderChip(bool value, String label) {
    final selected = _nameFirst == value;
    return GestureDetector(
      onTap: () {
        setState(() => _nameFirst = value);
        _parseInput();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 一、解析设置
  // --------------------------------------------------------------------------

  Widget _buildParseSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分隔符选择行
            Row(
              children: [
                const Text('分隔符：'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedSeparator,
                  isDense: true,
                  items: _separatorOptions
                      .map((opt) => DropdownMenuItem(
                            value: opt,
                            child: Text(opt),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSeparator = val);
                      _parseInput();
                    }
                  },
                ),
              ],
            ),
            // 自定义分隔符输入
            if (_selectedSeparator == '自定义...') ...[
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: '请输入自定义分隔符',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (val) {
                  _customSeparator = val;
                  _parseInput();
                },
              ),
            ],
            const SizedBox(height: 16),
            // 名称/ID 顺序
            const Text('字段顺序：'),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildOrderChip(true, '第1个=名称, 第2个=ID'),
                const SizedBox(width: 8),
                _buildOrderChip(false, '第1个=ID, 第2个=名称'),
              ],
            ),
            // 多列选择器
            if (_detectedColumns > 2) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              Text(
                '检测到 $_detectedColumns 列，请选择作为名称/ID的起始列：',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    _detectedColumns - 1,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildColumnChip(
                        i,
                        '第${i + 1}列：${_columnSamples.length > i ? _columnSamples[i] : ""}',
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // 单列提示
            if (_detectedColumns == 1) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '识别到单列数据，将全部作为ID处理（名称 = ID）',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColumnChip(int index, String label) {
    final selected = _selectedColumnStart == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedColumnStart = index);
        _parseInput();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 二、输入区域
  // --------------------------------------------------------------------------

  Widget _buildInputArea() {
    return TextField(
      controller: _inputController,
      maxLines: 12,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      decoration: const InputDecoration(
        hintText: '支持 Tab / 逗号 / 分号 / 竖线 作为分隔符，每行两个内容',
        hintStyle: TextStyle(color: Colors.grey),
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => _parseInput(),
    );
  }

  // --------------------------------------------------------------------------
  // 三、预览区域
  // --------------------------------------------------------------------------

  Widget _buildPreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: _parsedLines.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '暂无解析结果',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : Table(
                border: TableBorder(
                  horizontalInside: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(3),
                },
                children: [
                  // 表头
                  TableRow(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    children: const [
                      VbTableCell('音色名称', isHeader: true),
                      VbTableCell('音色ID', isHeader: true),
                      VbTableCell('状态', isHeader: true),
                    ],
                  ),
                  // 数据行
                  ..._parsedLines.map(_buildPreviewRow),
                ],
              ),
      ),
    );
  }

  TableRow _buildPreviewRow(ParsedLine line) {
    return TableRow(
      children: [
        VbTableCell(line.name),
        VbTableCell(line.id),
        _buildStatusCell(line),
      ],
    );
  }

  Widget _buildStatusCell(ParsedLine line) {
    final (String text, Color color) = switch (line.status) {
      LineStatus.newVoice => ('✅ 新增', Colors.green.shade700),
      LineStatus.duplicate => ('⚠️ ID已存在', Colors.orange.shade700),
      LineStatus.formatError => (
          '❌ 格式错误${line.errorMsg != null ? ': ${line.errorMsg}' : ''}',
          Colors.red.shade700,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(text, style: TextStyle(color: color)),
    );
  }

  // --------------------------------------------------------------------------
  // 四、底部重复处理栏
  // --------------------------------------------------------------------------

  Widget _buildDuplicateBar() {
    final ids = _duplicateIds;
    if (ids.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 18,
              color: Theme.of(context).colorScheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '发现 ${ids.length} 个重复ID: ${ids.join(", ")}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// (VbTableCell moved to voice_batch_add_shared.dart)
