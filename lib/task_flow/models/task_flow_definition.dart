import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'block_type_definition.dart';
import 'io_type.dart';

// ============================================================================
// TaskFlowBlock — a single block instance within a flow
// ============================================================================

/// An instance of a [BlockTypeDefinition] within a [TaskFlowDefinition].
///
/// Each block has:
/// - A unique [id] within the flow
/// - A reference [typeKey] to its [BlockTypeDefinition]
/// - Per-instance [params] that override the block type's defaults
///
/// The [params] map stores user-configured values for this specific
/// block instance. Different flows can have different parameter values
/// for the same block type.
@immutable
class TaskFlowBlock {
  final String id;
  final BlockType typeKey;
  final Map<String, dynamic> params;

  TaskFlowBlock({
    String? id,
    required this.typeKey,
    Map<String, dynamic>? params,
  })  : id = id ?? const Uuid().v4(),
        params = params != null
            ? Map<String, dynamic>.from(params)
            : _defaultParamsFor(typeKey);

  /// Get the default params for a given type key.
  static Map<String, dynamic> _defaultParamsFor(BlockType typeKey) {
    final def = BlockTypeDefinition.findBlockType(typeKey);
    if (def != null) return Map<String, dynamic>.from(def.defaultParams);
    return {};
  }

  /// Get the [BlockTypeDefinition] for this block's type.
  BlockTypeDefinition? getDefinition() =>
      BlockTypeDefinition.findBlockType(typeKey);

  /// Create a copy with overridden params. Other params from the definition
  /// are preserved unless explicitly overridden.
  TaskFlowBlock copyWithParams(Map<String, dynamic> newParams) {
    final merged = Map<String, dynamic>.from(params);
    merged.addAll(newParams);
    return TaskFlowBlock(id: id, typeKey: typeKey, params: merged);
  }

  /// Create a copy with a specific param changed.
  TaskFlowBlock copyWithParam(String key, dynamic value) {
    final merged = Map<String, dynamic>.from(params);
    merged[key] = value;
    return TaskFlowBlock(id: id, typeKey: typeKey, params: merged);
  }

  // ========================================================================
  // Serialization
  // ========================================================================

  Map<String, dynamic> toMap() => {
        'id': id,
        'typeKey': typeKey.name,
        'params': params,
      };

  factory TaskFlowBlock.fromMap(Map<String, dynamic> map) => TaskFlowBlock(
        id: map['id'] as String?,
        typeKey: parseBlockType(map['typeKey'] as String),
        params: map['params'] != null
            ? Map<String, dynamic>.from(map['params'] as Map)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskFlowBlock &&
          id == other.id &&
          typeKey == other.typeKey &&
          mapEquals(params, other.params);

  @override
  int get hashCode =>
      Object.hash(id, typeKey, Object.hashAllUnordered(params.entries));
}

// ============================================================================
// Validation result for a flow
// ============================================================================

// ============================================================================
// TaskFlowDefinition — the complete flow model
// ============================================================================

/// A complete task flow definition containing an ordered list of blocks.
///
/// A flow has:
/// - An [inputType] specifying the type of initial input (position 0).
/// - An ordered list of [blocks] (positions 1..N).
///
/// The initial input at position 0 feeds into the first block.
/// Block I/O compatibility is advisory — the flow will run regardless.
///
/// Flows are persisted as JSON and can be duplicated, renamed, etc.
@immutable
class TaskFlowDefinition {
  final String id;
  final String name;
  final String description;
  final IOType inputType;
  final List<TaskFlowBlock> blocks;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskFlowDefinition({
    String? id,
    this.name = '',
    this.description = '',
    this.inputType = IOType.text,
    List<TaskFlowBlock>? blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        blocks = blocks != null ? List<TaskFlowBlock>.from(blocks) : const [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Add a block at the end of the flow.
  TaskFlowDefinition addBlock(TaskFlowBlock block) =>
      copyWith(blocks: [...blocks, block], updatedAt: DateTime.now());

  /// Insert a block at [index].
  TaskFlowDefinition insertBlock(int index, TaskFlowBlock block) {
    final newBlocks = [...blocks];
    newBlocks.insert(index.clamp(0, blocks.length), block);
    return copyWith(blocks: newBlocks, updatedAt: DateTime.now());
  }

  /// Update a block's parameters by its id.
  TaskFlowDefinition updateBlockParams(
    String blockId,
    Map<String, dynamic> newParams,
  ) {
    final index = blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return this;
    final updatedBlocks = [...blocks];
    updatedBlocks[index] = blocks[index].copyWithParams(newParams);
    return copyWith(blocks: updatedBlocks, updatedAt: DateTime.now());
  }

  /// Create a copy of this flow with a new ID (for duplication).
  TaskFlowDefinition copyWithNewId() => TaskFlowDefinition(
        name: name,
        description: description,
        inputType: inputType,
        blocks: blocks
            .map(
              (b) => TaskFlowBlock(
                typeKey: b.typeKey,
                params: Map<String, dynamic>.from(b.params),
              ),
            )
            .toList(),
      );

  /// Create a modified copy.
  TaskFlowDefinition copyWith({
    String? name,
    String? description,
    IOType? inputType,
    List<TaskFlowBlock>? blocks,
    DateTime? updatedAt,
  }) =>
      TaskFlowDefinition(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        inputType: inputType ?? this.inputType,
        blocks: blocks != null ? List<TaskFlowBlock>.from(blocks) : this.blocks,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  // ========================================================================
  // Serialization
  // ========================================================================

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'inputType': inputType.toJson(),
        'blocks': blocks.map((b) => b.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TaskFlowDefinition.fromMap(Map<String, dynamic> map) =>
      TaskFlowDefinition(
        id: map['id'] as String?,
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        inputType: map['inputType'] != null
            ? IOType.fromJson(map['inputType'] as String)
            : IOType.text,
        blocks: (map['blocks'] as List?)
                ?.map(
                  (b) => TaskFlowBlock.fromMap(
                    Map<String, dynamic>.from(b as Map),
                  ),
                )
                .toList() ??
            [],
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : null,
        updatedAt: map['updatedAt'] != null
            ? DateTime.parse(map['updatedAt'] as String)
            : null,
      );
}
