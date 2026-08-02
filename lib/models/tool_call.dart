enum ToolCallStatus { pending, running, completed, error }

class ToolCallData {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final ToolCallStatus status;
  final String? result;

  /// 工具结果被 prune 的时间戳（软删除标记，opencode compacted 语义）。
  /// 非 null 时 [result] 已被替换为占位文本，UI 显示"已压缩"，
  /// 序列化体积保持最小。v3 原位演进：旧数据缺省 null。
  final DateTime? compactedAt;

  const ToolCallData({
    required this.id,
    required this.name,
    required this.arguments,
    this.status = ToolCallStatus.pending,
    this.result,
    this.compactedAt,
  });

  ToolCallData copyWith({
    ToolCallStatus? status,
    String? result,
    DateTime? compactedAt,
  }) =>
      ToolCallData(
        id: id,
        name: name,
        arguments: arguments,
        status: status ?? this.status,
        result: result ?? this.result,
        compactedAt: compactedAt ?? this.compactedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'arguments': arguments,
        'status': status.name,
        if (result != null) 'result': result,
        if (compactedAt != null) 'compactedAt': compactedAt!.toIso8601String(),
      };

  factory ToolCallData.fromMap(Map<String, dynamic> map) {
    // Parse arguments defensively: handle null, non-Map, or Map types.
    Map<String, dynamic> parsedArgs;
    final rawArgs = map['arguments'];
    if (rawArgs is Map) {
      try {
        parsedArgs = Map<String, dynamic>.from(rawArgs);
      } catch (_) {
        parsedArgs = <String, dynamic>{};
      }
    } else {
      parsedArgs = <String, dynamic>{};
    }

    // Parse status defensively: fall back to pending on unknown/null values.
    final statusStr = map['status'] as String?;
    final status = ToolCallStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => ToolCallStatus.pending,
    );

    // Defensive compactedAt parsing
    DateTime? compactedAt;
    final compactedRaw = map['compactedAt'];
    if (compactedRaw is String) {
      try {
        compactedAt = DateTime.parse(compactedRaw);
      } catch (_) {
        compactedAt = null;
      }
    }

    return ToolCallData(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      arguments: parsedArgs,
      status: status,
      result: map['result'] as String?,
      compactedAt: compactedAt,
    );
  }
}

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}
