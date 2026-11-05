import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/services/chat_task_flow_tool_service.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart'
    show FlowRunInput, FlowExecutionStatus, TaskFlowExecution;

void main() {
  group('ChatTaskFlowToolService', () {
    test('lists stable flow metadata without local file paths', () async {
      final flow = TaskFlowDefinition(
        id: 'flow-1',
        name: 'Study notes',
        description: 'Summarize supplied notes',
        inputType: IOType.text,
      );

      final result = await ChatTaskFlowToolService.handleList(
        const {},
        loadFlows: () async => [flow],
      );

      final decoded = jsonDecode(result) as List<dynamic>;
      expect(decoded.single['id'], 'flow-1');
      expect(decoded.single['input_type'], 'text');
      expect(result, isNot(contains('storagePath')));
    });

    test('launches text flows', () async {
      final textFlow = TaskFlowDefinition(
        id: 'text-flow',
        name: 'Text flow',
        inputType: IOType.text,
      );
      var launched = false;
      final started = await ChatTaskFlowToolService.handleRun(
        const {'flow_id': 'text-flow', 'input_text': 'chapter notes'},
        findFlow: (id) async => id == textFlow.id ? textFlow : null,
        copyAttachment: (_) async => null,
        launch: (id, input) async {
          launched = id == textFlow.id && input.text == 'chapter notes';
          return ['execution-1'];
        },
      );
      expect(launched, isTrue);
      expect(started, contains('execution-1'));
    });

    test(
      'launches a media flow from a copied conversation attachment',
      () async {
        final image = Attachment(
          fileName: 'diagram.png',
          mimeType: 'image/png',
          fileType: 'image',
          hash: 'hash',
          storagePath: 'attachments/original.png',
          fileSize: 4,
        );
        final flow = TaskFlowDefinition(
          id: 'image-flow',
          name: 'Read diagram',
          inputType: IOType.image,
        );
        FlowRunInput? launchedInput;
        final result = await ChatTaskFlowToolService.handleRun(
          const {'flow_id': 'image-flow', 'attachment_index': 0},
          attachments: [image],
          findFlow: (_) async => flow,
          copyAttachment: (attachment) async => FlowRunInput(
            text: 'attachments/task-flow-copy.png',
            fileName: attachment.fileName,
            mimeType: attachment.mimeType,
            ownedStoragePath: 'attachments/task-flow-copy.png',
          ),
          launch: (id, input) async {
            launchedInput = input;
            return ['$id-execution'];
          },
        );

        expect(result, contains('image-flow-execution'));
        expect(result, isNot(contains(image.storagePath)));
        expect(launchedInput?.text, 'attachments/task-flow-copy.png');
        expect(
          launchedInput?.ownedStoragePath,
          'attachments/task-flow-copy.png',
        );
        expect(launchedInput?.text, isNot(image.storagePath));
      },
    );

    test(
      'media flow rejects missing or mismatched conversation attachments',
      () async {
        final flow = TaskFlowDefinition(
          id: 'audio-flow',
          inputType: IOType.audio,
        );
        var copied = false;
        Future<FlowRunInput?> copy(Attachment _) async {
          copied = true;
          return const FlowRunInput(text: 'attachments/copy.wav');
        }

        final missing = await ChatTaskFlowToolService.handleRun(
          const {'flow_id': 'audio-flow', 'attachment_index': 0},
          findFlow: (_) async => flow,
          copyAttachment: copy,
          launch: (_, _) async => const [],
        );
        expect(missing, contains('no matching audio attachment'));
        expect(copied, isFalse);

        final wrongType = Attachment(
          fileName: 'photo.png',
          mimeType: 'image/png',
          fileType: 'image',
          hash: 'hash',
          storagePath: 'attachments/photo.png',
          fileSize: 4,
        );
        final mismatched = await ChatTaskFlowToolService.handleRun(
          const {'flow_id': 'audio-flow', 'attachment_index': 0},
          attachments: [wrongType],
          findFlow: (_) async => flow,
          copyAttachment: copy,
          launch: (_, _) async => const [],
        );
        expect(mismatched, contains('no matching audio attachment'));
        expect(copied, isFalse);
      },
    );

    test(
      'status only returns the requested execution and hides paths',
      () async {
        final first = TaskFlowExecution(
          id: 'execution-1',
          flowId: 'flow-1',
          flowName: 'Read notes',
          status: FlowExecutionStatus.running,
          inputType: IOType.text,
          inputStoragePath: '/private/task-flow/input',
        );
        final second = TaskFlowExecution(
          id: 'execution-2',
          flowId: 'flow-2',
          flowName: 'Other flow',
          status: FlowExecutionStatus.completed,
          inputType: IOType.text,
        );

        final result = await ChatTaskFlowToolService.handleStatus(
          const {'execution_id': 'execution-1'},
          executions: [first, second],
        );

        expect(result, contains('execution-1'));
        expect(result, isNot(contains('execution-2')));
        expect(result, isNot(contains('/private/task-flow/input')));
      },
    );

    test('validates the control action before delegating', () async {
      var called = false;
      final invalid = await ChatTaskFlowToolService.handleControl(
        const {'execution_id': 'execution-1', 'action': 'delete'},
        exists: (_) => true,
        control: (_, _) async => called = true,
      );
      expect(called, isFalse);
      expect(invalid, contains('action must be'));

      final valid = await ChatTaskFlowToolService.handleControl(
        const {'execution_id': 'execution-1', 'action': 'pause'},
        exists: (id) => id == 'execution-1',
        control: (action, id) async =>
            called = action == 'pause' && id == 'execution-1',
      );
      expect(called, isTrue);
      expect(valid, contains('asked to pause'));

      final missing = await ChatTaskFlowToolService.handleControl(
        const {'execution_id': 'missing', 'action': 'cancel'},
        exists: (_) => false,
        control: (_, _) async => called = false,
      );
      expect(missing, contains('execution was not found'));
    });
  });
}
