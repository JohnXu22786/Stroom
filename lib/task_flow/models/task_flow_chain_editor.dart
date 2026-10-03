import 'block_type_definition.dart';
import 'io_type.dart';
import 'task_flow_definition.dart';

/// A connection that must be repaired before the chain can be saved or run.
class TaskFlowChainIssue {
  final String blockId;
  final int blockIndex;
  final String message;

  const TaskFlowChainIssue(this.blockId, this.blockIndex, this.message);
}

class _ChainSnapshot {
  final List<TaskFlowBlock> blocks;
  final IOType inputType;
  final String? selectedBlockId;

  _ChainSnapshot(this.blocks, this.inputType, this.selectedBlockId);
}

/// Edits an entire chain without dropping configured downstream steps.
///
/// Connection-breaking edits remain reversible and report every bad link.
/// Blocks keep their IDs while moving; duplicates receive fresh IDs. History
/// owns deep parameter snapshots, including nested model references and lists.
class TaskFlowChainEditor {
  List<TaskFlowBlock> _blocks = [];
  IOType _inputType = IOType.text;
  String? _selectedBlockId;
  List<TaskFlowChainIssue> _issues = [];
  final List<_ChainSnapshot> _history = [];

  TaskFlowChainEditor({
    List<TaskFlowBlock> blocks = const [],
    IOType inputType = IOType.text,
  }) {
    reset(blocks: blocks, inputType: inputType);
  }

  List<TaskFlowBlock> get blocks => List.unmodifiable(_blocks);
  IOType get inputType => _inputType;
  String? get selectedBlockId => _selectedBlockId;
  List<TaskFlowChainIssue> get issues => List.unmodifiable(_issues);
  bool get canUndo => _history.isNotEmpty;

  void reset({required List<TaskFlowBlock> blocks, required IOType inputType}) {
    _blocks = copyBlocks(blocks);
    _inputType = inputType;
    _selectedBlockId = null;
    _history.clear();
    _validate();
  }

  void clearHistory() => _history.clear();

  void select(String blockId) {
    if (_blocks.any((block) => block.id == blockId)) {
      _selectedBlockId = blockId;
    }
  }

  List<BlockTypeDefinition> insertionCandidates(int index) {
    if (index < 0 || index > _blocks.length) return const [];
    final previous = index == 0
        ? _inputType
        : _blocks[index - 1].getDefinition()?.outputType;
    final next = index == _blocks.length
        ? null
        : _blocks[index].getDefinition()?.inputType;
    if (previous == null || (index < _blocks.length && next == null)) {
      return const [];
    }
    return BlockTypeDefinition.getReplacementCandidates(
      prevOutput: previous,
      nextInput: next,
    );
  }

  bool insert(int index, BlockType type) {
    if (index < 0 || index > _blocks.length) return false;
    _remember();
    final block = TaskFlowBlock(typeKey: type);
    _blocks = [..._blocks]..insert(index, block);
    _selectedBlockId = block.id;
    _validate();
    return true;
  }

  bool remove(int index) {
    if (!_contains(index)) return false;
    _remember();
    final removed = _blocks[index];
    _blocks = [..._blocks]..removeAt(index);
    if (_selectedBlockId == removed.id) {
      _selectedBlockId = _blocks.isEmpty
          ? null
          : _blocks[index.clamp(0, _blocks.length - 1)].id;
    }
    _validate();
    return true;
  }

  bool duplicate(int index) {
    if (!_contains(index)) return false;
    _remember();
    final duplicate = copyBlock(_blocks[index], newId: true);
    _blocks = [..._blocks]..insert(index + 1, duplicate);
    _selectedBlockId = duplicate.id;
    _validate();
    return true;
  }

  /// Move to the final [destination] index in the resulting list.
  bool move(int index, int destination) {
    if (!_contains(index) || !_contains(destination) || index == destination) {
      return false;
    }
    _remember();
    final next = [..._blocks];
    final block = next.removeAt(index);
    next.insert(destination, block);
    _blocks = next;
    _selectedBlockId ??= block.id;
    _validate();
    return true;
  }

  bool replace(int index, BlockType type) {
    if (!_contains(index) || _blocks[index].typeKey == type) return false;
    _remember();
    final previous = _blocks[index];
    final replacement = TaskFlowBlock(typeKey: type);
    _blocks = [..._blocks]..[index] = replacement;
    if (_selectedBlockId == previous.id) {
      _selectedBlockId = replacement.id;
    }
    _validate();
    return true;
  }

  bool updateParams(String blockId, Map<String, dynamic> params) {
    final index = _blocks.indexWhere((block) => block.id == blockId);
    if (index < 0 || _valuesEqual(_blocks[index].params, params)) return false;
    _remember();
    final block = _blocks[index];
    _blocks = [..._blocks]..[index] = TaskFlowBlock(
        id: block.id,
        typeKey: block.typeKey,
        params: _copyValue(params) as Map<String, dynamic>,
      );
    _validate();
    return true;
  }

  bool changeInputType(IOType type) {
    if (type == _inputType) return false;
    _remember();
    _inputType = type;
    _validate();
    return true;
  }

  bool undo() {
    if (_history.isEmpty) return false;
    final snapshot = _history.removeLast();
    _blocks = copyBlocks(snapshot.blocks);
    _inputType = snapshot.inputType;
    _selectedBlockId = snapshot.selectedBlockId;
    _validate();
    return true;
  }

  bool _contains(int index) => index >= 0 && index < _blocks.length;

  void _remember() {
    _history
        .add(_ChainSnapshot(copyBlocks(_blocks), _inputType, _selectedBlockId));
  }

  void _validate() {
    _issues = validateConnections(_blocks, _inputType);
  }

  static List<TaskFlowChainIssue> validateConnections(
      List<TaskFlowBlock> blocks, IOType inputType) {
    final issues = <TaskFlowChainIssue>[];
    IOType? previous = inputType;
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final definition = block.getDefinition();
      if (definition == null) {
        issues.add(TaskFlowChainIssue(block.id, index, '功能块已不受支持，请替换或删除此步骤'));
      } else if (previous != null && !definition.acceptsInput(previous)) {
        issues.add(TaskFlowChainIssue(
            block.id,
            index,
            block.typeKey == BlockType.chat && previous == IOType.any
                ? '${index == 0 ? '初始输入' : '上一步输出'}为任意类型，'
                    '「${definition.label}」需要明确的文本、链接、图片、音频、视频或文件类型。'
                    '请修改输入类型、移动或替换功能块，或撤销更改'
                : '${index == 0 ? '初始输入' : '上一步输出'}为${previous.label}，'
                    '「${definition.label}」需要${definition.inputType.label}。'
                    '请修改输入类型、移动或替换功能块，或撤销更改'));
      }
      previous = definition?.outputType;
    }
    return issues;
  }

  static List<TaskFlowBlock> copyBlocks(List<TaskFlowBlock> blocks) =>
      blocks.map((block) => copyBlock(block)).toList();

  static TaskFlowBlock copyBlock(TaskFlowBlock block, {bool newId = false}) =>
      TaskFlowBlock(
        id: newId ? null : block.id,
        typeKey: block.typeKey,
        params: _copyValue(block.params) as Map<String, dynamic>,
      );

  static bool sameBlocks(List<TaskFlowBlock> a, List<TaskFlowBlock> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index].id != b[index].id ||
          a[index].typeKey != b[index].typeKey ||
          !_valuesEqual(a[index].params, b[index].params)) {
        return false;
      }
    }
    return true;
  }

  static dynamic _copyValue(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>(
          (key, entry) => MapEntry(key as String, _copyValue(entry)));
    }
    if (value is List) return value.map(_copyValue).toList();
    return value;
  }

  static bool _valuesEqual(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every(
              (key) => b.containsKey(key) && _valuesEqual(a[key], b[key]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          Iterable<int>.generate(a.length)
              .every((index) => _valuesEqual(a[index], b[index]));
    }
    return a == b;
  }
}
