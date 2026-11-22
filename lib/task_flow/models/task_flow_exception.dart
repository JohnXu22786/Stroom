/// Exception thrown when a task flow block execution fails.
class BlockExecutionException implements Exception {
  final String message;
  final String? blockType;
  final String? blockTitle;

  BlockExecutionException(this.message, {this.blockType, this.blockTitle});

  @override
  String toString() => 'BlockExecutionException: $message';
}

/// The chat model selected for a new flow launch is no longer available.
class FlowLaunchModelUnavailableException implements Exception {
  const FlowLaunchModelUnavailableException();
}
