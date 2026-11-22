// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_launch_snapshot.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';

void main() {
  test('unavailable selected chat model launch error is localized', () async {
    final flow = TaskFlowDefinition(
      name: 'Chat flow',
      blocks: [TaskFlowBlock(typeKey: BlockType.chat)],
    );
    late Object launchError;
    try {
      FlowLaunchSnapshot.capture(
        flow,
        const ProviderEntriesState(),
        [],
        selectedChatModel: const {
          'configId': 'deleted-config',
          'modelId': 'deleted-model',
        },
      );
      fail('Expected capture to reject the unavailable selected model.');
    } on FlowLaunchModelUnavailableException catch (error) {
      launchError = error;
    }

    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final chinese = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(
      taskFlowLaunchErrorMessage(launchError, english),
      'No model is selected or the model is unavailable. Select another model.',
    );
    expect(taskFlowLaunchErrorMessage(launchError, chinese), '模型未选择或已失效，请重新选择');
    expect(
      taskFlowLaunchErrorMessage(StateError('network issue'), english),
      'Bad state: network issue',
    );
  });
}
