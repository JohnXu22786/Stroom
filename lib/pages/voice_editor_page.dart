import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/provider_config.dart';
import 'voice_batch_add_page.dart';

class VoiceEditorPage extends StatefulWidget {
  final List<VoiceEntry> initialVoices;
  const VoiceEditorPage({super.key, required this.initialVoices});

  @override
  State<VoiceEditorPage> createState() => _VoiceEditorPageState();
}

class _VoiceEditorPageState extends State<VoiceEditorPage> {
  late List<VoiceEntry> _voices;
  late List<TextEditingController> _nameCtrls;
  late List<TextEditingController> _idCtrls;
  late List<FocusNode> _idFocusNodes;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _voices = widget.initialVoices.map((v) => v.copy()).toList();
    _nameCtrls = _voices.map((v) => TextEditingController(text: v.name)).toList();
    _idCtrls = _voices.map((v) => TextEditingController(text: v.id)).toList();
    _idFocusNodes = _voices.map((_) => FocusNode()).toList();
    for (var i = 0; i < _idFocusNodes.length; i++) {
      _idFocusNodes[i].addListener(() => _onIdFocusChange(i));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final c in _nameCtrls) {
      c.dispose();
    }
    for (final c in _idCtrls) {
      c.dispose();
    }
    for (final f in _idFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _isUnchanged {
    if (_voices.length != widget.initialVoices.length) return false;
    for (var i = 0; i < _voices.length; i++) {
      if (_nameCtrls[i].text != widget.initialVoices[i].name ||
          _idCtrls[i].text != widget.initialVoices[i].id) {
        return false;
      }
    }
    return true;
  }

  void _syncVoices() {
    for (var i = 0; i < _voices.length; i++) {
      _voices[i].name = _nameCtrls[i].text;
      _voices[i].id = _idCtrls[i].text;
    }
  }

  /// 找到与指定索引相同 ID 的其他行（排除自身）
  List<int> _findDuplicateIndices(int index) {
    final id = _idCtrls[index].text.trim();
    if (id.isEmpty) return [];
    final dupes = <int>[];
    for (var i = 0; i < _idCtrls.length; i++) {
      if (i != index && _idCtrls[i].text.trim() == id) {
        dupes.add(i);
      }
    }
    return dupes;
  }

  void _onIdFocusChange(int index) {
    if (!_idFocusNodes[index].hasFocus) {
      // 只刷新 UI 显示警告图标，重复检测交由保存时 _DuplicateResolveDialog 处理
      setState(() {});
    }
  }

  void _addRow() {
    setState(() {
      final newIndex = _voices.length;
      _voices.add(VoiceEntry(name: '', id: ''));
      _nameCtrls.add(TextEditingController());
      final newIdCtrl = TextEditingController();
      _idCtrls.add(newIdCtrl);
      final fn = FocusNode();
      fn.addListener(() => _onIdFocusChange(newIndex));
      _idFocusNodes.add(fn);
    });
    // 滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _batchAdd() async {
    final result = await Navigator.push<List<VoiceEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceBatchAddPage(existingVoices: _voices),
      ),
    );
    if (result == null || !mounted) return;
    // 直接追加所有条目（含重复），重复检测由失焦检查和保存逻辑处理
    setState(() {
      for (final v in result) {
        final newIndex = _voices.length;
        _voices.add(VoiceEntry(name: v.name, id: v.id));
        _nameCtrls.add(TextEditingController(text: v.name));
        _idCtrls.add(TextEditingController(text: v.id));
        final fn = FocusNode();
        fn.addListener(() => _onIdFocusChange(newIndex));
        _idFocusNodes.add(fn);
      }
    });
  }

  void _deleteRow(int index) {
    setState(() {
      _nameCtrls[index].dispose();
      _idCtrls[index].dispose();
      _idFocusNodes[index].dispose();
      _nameCtrls.removeAt(index);
      _idCtrls.removeAt(index);
      _idFocusNodes.removeAt(index);
      _voices.removeAt(index);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final v = _voices.removeAt(oldIndex);
      _voices.insert(newIndex, v);
      final nc = _nameCtrls.removeAt(oldIndex);
      _nameCtrls.insert(newIndex, nc);
      final ic = _idCtrls.removeAt(oldIndex);
      _idCtrls.insert(newIndex, ic);
      final fn = _idFocusNodes.removeAt(oldIndex);
      _idFocusNodes.insert(newIndex, fn);
    });
  }

  Future<void> _save() async {
    _syncVoices();

    // 过滤空 ID 行
    final nonEmpty = <VoiceEntry>[];
    for (final v in _voices) {
      if (v.id.trim().isNotEmpty) {
        nonEmpty.add(v);
      }
    }

    // 找出重复条目（第二次及以后出现的为重复）
    final seen = <String>{};
    final duplicateList = <int>[]; // 在 nonEmpty 中的索引
    final idToFirstIdx = <String, int>{};
    for (int i = 0; i < nonEmpty.length; i++) {
      final id = nonEmpty[i].id.trim();
      if (!seen.add(id)) {
        duplicateList.add(i);
      } else {
        idToFirstIdx[id] = i;
      }
    }

    if (duplicateList.isNotEmpty) {
      final result = await _showDuplicateResolveDialog(
        nonEmpty, duplicateList, idToFirstIdx,
      );
      if (result == null) return; // 用户取消
      nonEmpty.clear();
      nonEmpty.addAll(result);
    }

    if (mounted) {
      Navigator.pop(context, nonEmpty);
    }
  }

  /// 逐条处理重复的对话框
  /// 返回处理后的列表，null 表示取消保存
  Future<List<VoiceEntry>?> _showDuplicateResolveDialog(
    List<VoiceEntry> all,
    List<int> dupIndices,
    Map<String, int> idToFirstIdx,
  ) async {
    // 做一个可变的副本
    final working = all.map((v) => v.copy()).toList();
    final pending = List<int>.from(dupIndices); // 待处理的重复索引

    final completer = Completer<List<VoiceEntry>?>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DuplicateResolveDialog(
        working: working,
        idToFirstIdx: Map.from(idToFirstIdx),
        pending: pending,
        onComplete: (result) {
          Navigator.pop(ctx);
          completer.complete(result);
        },
      ),
    );

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音色编辑'),
        actions: [
          TextButton(
            onPressed: () {
              if (_isUnchanged) {
                Navigator.pop(context, _voices);
              } else {
                _save();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部操作栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加一行'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _batchAdd,
                  icon: const Text('📋', style: TextStyle(fontSize: 16)),
                  label: const Text('批量添加'),
                ),
              ],
            ),
          ),
          // 列表
          if (_voices.isNotEmpty)
            // 表头
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 40), // 拖拽柄宽度
                  const SizedBox(
                    width: 24,
                    child: Text(
                      '#',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '音色名称',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '音色ID',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 36), // 删除按钮宽度
                ],
              ),
            ),
          Expanded(
            child: _voices.isEmpty
                ? const Center(
                    child: Text(
                      '暂无音色，请添加',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ReorderableListView(
                    onReorder: _onReorder,
                    buildDefaultDragHandles: false,
                    scrollController: _scrollController,
                    children: [
                      for (var i = 0; i < _voices.length; i++) _buildRow(i),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int index) {
    final isDuplicate = _findDuplicateIndices(index).isNotEmpty;

    return Card(
      key: ValueKey('voice_row_$index'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // 左侧拖拽柄
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_indicator, color: Colors.grey),
              ),
            ),
            // 序号
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            // 音色名称
            Expanded(
              child: TextField(
                controller: _nameCtrls[index],
                decoration: const InputDecoration(
                  hintText: '音色名称',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 音色ID
            Expanded(
              child: TextField(
                controller: _idCtrls[index],
                focusNode: _idFocusNodes[index],
                decoration: InputDecoration(
                  hintText: '音色ID',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: isDuplicate
                      ? const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                        )
                      : null,
                ),
              ),
            ),
            // 右侧删除按钮
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteRow(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 保存时重复处理对话框
// ============================================================================

class _DuplicateResolveDialog extends StatefulWidget {
  final List<VoiceEntry> working;
  final Map<String, int> idToFirstIdx;
  final List<int> pending;
  final ValueChanged<List<VoiceEntry>?> onComplete;

  const _DuplicateResolveDialog({
    required this.working,
    required this.idToFirstIdx,
    required this.pending,
    required this.onComplete,
  });

  @override
  State<_DuplicateResolveDialog> createState() => _DuplicateResolveDialogState();
}

class _DuplicateResolveDialogState extends State<_DuplicateResolveDialog> {
  late List<VoiceEntry> _working;
  late Map<String, int> _idToFirstIdx;
  late List<int> _pending;

  @override
  void initState() {
    super.initState();
    _working = widget.working.map((v) => v.copy()).toList();
    _idToFirstIdx = Map.from(widget.idToFirstIdx);
    _pending = List.from(widget.pending);
  }

  void _handleUpdate(int pendingIdx) {
    final dupIdx = _pending[pendingIdx];
    final dup = _working[dupIdx];
    final firstIdx = _idToFirstIdx[dup.id.trim()]!;

    // 用重复行的数据覆盖首次出现的行
    _working[firstIdx].name = dup.name;
    _working[firstIdx].id = dup.id;

    // 移除该重复行
    _working.removeAt(dupIdx);
    // 更新索引映射
    final newIdToFirst = <String, int>{};
    for (int i = 0; i < _working.length; i++) {
      newIdToFirst[_working[i].id.trim()] = i;
    }
    _idToFirstIdx = newIdToFirst;

    // 重新计算 pending 列表
    final newPending = <int>[];
    final seen = <String>{};
    for (int i = 0; i < _working.length; i++) {
      if (!seen.add(_working[i].id.trim())) {
        newPending.add(i);
      }
    }
    _pending = newPending;

    if (_pending.isEmpty) {
      widget.onComplete(_working);
    } else {
      setState(() {});
    }
  }

  void _handleSkip(int pendingIdx) {
    final dupIdx = _pending[pendingIdx];
    _working.removeAt(dupIdx);

    // 更新索引映射
    final newIdToFirst = <String, int>{};
    for (int i = 0; i < _working.length; i++) {
      newIdToFirst[_working[i].id.trim()] = i;
    }
    _idToFirstIdx = newIdToFirst;

    // 重新计算 pending 列表
    final newPending = <int>[];
    final seen = <String>{};
    for (int i = 0; i < _working.length; i++) {
      if (!seen.add(_working[i].id.trim())) {
        newPending.add(i);
      }
    }
    _pending = newPending;

    if (_pending.isEmpty) {
      widget.onComplete(_working);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('发现以下重复音色ID，逐条选择处理方式：'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _pending.length,
                itemBuilder: (context, i) {
                  final dupIdx = _pending[i];
                  final entry = _working[dupIdx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _handleUpdate(i),
                          child: const Text('更新'),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () => _handleSkip(i),
                          child: const Text('跳过'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '还有 ${_pending.length} 个重复未处理',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => widget.onComplete(null),
                child: const Text('继续编辑'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
