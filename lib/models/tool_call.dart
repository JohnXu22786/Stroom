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
