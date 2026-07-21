enum ToolCallStatus { pending, running, completed, error }

class ToolCallData {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final ToolCallStatus status;
  final String? result;

  const ToolCallData({
    required this.id,
    required this.name,
    required this.arguments,
    this.status = ToolCallStatus.pending,
    this.result,
  });

  ToolCallData copyWith({
    ToolCallStatus? status,
    String? result,
  }) =>
      ToolCallData(
        id: id,
        name: name,
        arguments: arguments,
        status: status ?? this.status,
        result: result ?? this.result,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'arguments': arguments,
        'status': status.name,
        if (result != null) 'result': result,
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

    return ToolCallData(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      arguments: parsedArgs,
      status: status,
      result: map['result'] as String?,
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
