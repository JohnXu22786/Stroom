import 'dart:convert';

import '../models/chat_message.dart' show Attachment;
import '../models/tool_call.dart';
import '../task_flow/models/task_flow_definition.dart';
import '../task_flow/models/io_type.dart';
import '../task_flow/models/task_flow_execution.dart'
    show FlowRunInput, TaskFlowExecution;

class ChatTaskFlowToolService {
  static const listToolName = 'stroom_taskflow_list';
  static const runToolName = 'stroom_taskflow_run';
  static const statusToolName = 'stroom_taskflow_status';
  static const controlToolName = 'stroom_taskflow_control';

  static const List<ToolDefinition> toolDefinitions = [
    ToolDefinition(
      name: listToolName,
      description: 'List task flows saved in Stroom, including their IDs and '
          'input types. Use these IDs with stroom_taskflow_run.',
      parameters: {'type': 'object', 'properties': {}, 'required': <String>[]},
    ),
    ToolDefinition(
      name: runToolName,
      description:
          'Start a saved Stroom task flow with text or an attachment from '
          'this conversation. Use input_text for text and attachment_index '
          'for image, audio, video, or file flows. It returns execution IDs; '
          'use stroom_taskflow_status to check progress.',
      parameters: {
        'type': 'object',
        'properties': {
          'flow_id': {'type': 'string', 'description': 'Saved task flow ID.'},
          'input_text': {'type': 'string', 'description': 'Text to process.'},
          'attachment_index': {
            'type': 'integer',
            'minimum': 0,
            'description':
                'Zero-based index among matching attachments in this '
                    'conversation, ordered oldest to newest.',
          },
        },
        'required': ['flow_id'],
      },
    ),
    ToolDefinition(
      name: statusToolName,
      description: 'Show recent task flow executions, or one execution when '
          'execution_id is provided.',
      parameters: {
        'type': 'object',
        'properties': {
          'execution_id': {'type': 'string', 'description': 'Execution ID.'},
        },
        'required': <String>[],
      },
    ),
    ToolDefinition(
      name: controlToolName,
      description: 'Pause, resume, or cancel a task flow execution in Stroom.',
      parameters: {
        'type': 'object',
        'properties': {
          'execution_id': {'type': 'string', 'description': 'Execution ID.'},
          'action': {
            'type': 'string',
            'enum': ['pause', 'resume', 'cancel'],
          },
        },
        'required': ['execution_id', 'action'],
      },
    ),
  ];

  static Future<String> handleList(
    Map<String, dynamic> args, {
    required Future<List<TaskFlowDefinition>> Function() loadFlows,
  }) async {
    final flows = await loadFlows();
    return jsonEncode([
      for (final flow in flows)
        {
          'id': flow.id,
          'name': flow.name,
          'description': flow.description,
          'input_type': flow.inputType.name,
          'block_count': flow.blocks.length,
        },
    ]);
  }

  static Future<String> handleRun(
    Map<String, dynamic> args, {
    required Future<TaskFlowDefinition?> Function(String) findFlow,
    List<Attachment> attachments = const [],
    required Future<FlowRunInput?> Function(Attachment) copyAttachment,
    required Future<List<String>> Function(String, FlowRunInput) launch,
  }) async {
    final flowId = args['flow_id'];
    if (flowId is! String || flowId.trim().isEmpty) {
      return 'Error: flow_id is required.';
    }
    final flow = await findFlow(flowId.trim());
    if (flow == null) return 'Error: the requested task flow was not found.';

    final FlowRunInput input;
    if (flow.inputType == IOType.text ||
        flow.inputType == IOType.url ||
        flow.inputType == IOType.any) {
      final inputText = args['input_text'];
      if (inputText is! String || inputText.trim().isEmpty) {
        return 'Error: input_text must not be empty for this task flow.';
      }
      input = FlowRunInput(text: inputText.trim());
    } else if (const {
      IOType.image,
      IOType.audio,
      IOType.video,
      IOType.file,
    }.contains(flow.inputType)) {
      final index = args['attachment_index'];
      final expectedTypes = switch (flow.inputType) {
        IOType.image => const {'image'},
        IOType.audio => const {'audio'},
        IOType.video => const {'video'},
        IOType.file => const {'image', 'audio', 'video', 'document'},
        _ => const <String>{},
      };
      final matching = attachments
          .where((attachment) => expectedTypes.contains(attachment.fileType))
          .toList();
      if (matching.isEmpty) {
        return 'Error: this conversation has no matching '
            '${flow.inputType.name} attachment for the task flow.';
      }
      if (index is! int || index < 0 || index >= matching.length) {
        return 'Error: attachment_index must select a matching '
            '${flow.inputType.name} attachment in this conversation.';
      }
      final copied = await copyAttachment(matching[index]);
      if (copied == null || copied.ownedStoragePath == null) {
        return 'Error: the selected attachment could not be prepared for '
            'the task flow.';
      }
      input = copied;
    } else {
      return 'Error: task flows with ${flow.inputType.name} input cannot be '
          'started from chat.';
    }

    final List<String> ids;
    try {
      ids = await launch(flow.id, input);
    } catch (_) {
      return 'Error: the task flow could not be started. Check its input and '
          'configuration, then try again.';
    }
    return 'Started "${flow.name}". Execution IDs: ${ids.join(', ')}. '
        'Use stroom_taskflow_status to check progress.';
  }

  static Future<String> handleStatus(
    Map<String, dynamic> args, {
    required List<TaskFlowExecution> executions,
  }) async {
    final rawId = args['execution_id'];
    final selected = rawId is String && rawId.trim().isNotEmpty
        ? executions.where((entry) => entry.id == rawId.trim()).toList()
        : executions.take(10).toList();
    if (selected.isEmpty) return 'No matching task flow executions.';
    return jsonEncode([
      for (final execution in selected)
        {
          'execution_id': execution.id,
          'flow_id': execution.flowId,
          'flow_name': execution.flowName,
          'status': execution.status.name,
          'steps': [
            for (final step in execution.subTasks)
              {'name': step.blockLabel, 'status': step.outcome.name},
          ],
        },
    ]);
  }

  static Future<String> handleControl(
    Map<String, dynamic> args, {
    required bool Function(String executionId) exists,
    required Future<void> Function(String action, String executionId) control,
  }) async {
    final id = args['execution_id'];
    final action = args['action'];
    if (id is! String || id.trim().isEmpty) {
      return 'Error: execution_id is required.';
    }
    if (action is! String || !{'pause', 'resume', 'cancel'}.contains(action)) {
      return 'Error: action must be pause, resume, or cancel.';
    }
    if (!exists(id.trim())) return 'Error: the execution was not found.';
    await control(action, id.trim());
    return 'Task flow execution ${id.trim()} was asked to $action.';
  }
}
