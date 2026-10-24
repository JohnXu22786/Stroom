import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/startup/startup_sequence_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('streams the version-safety block before later startup checks',
      () async {
    SharedPreferences.setMockInitialValues({
      'data_format_versions': jsonEncode({
        for (final part in DataParts.all)
          part: part == 'chat'
              ? DataParts.currentVersions[part]! + 1
              : DataParts.currentVersions[part],
      }),
    });

    final controller = StartupSequenceController();
    final progress = <StartupCheckProgress>[];
    final subscription = controller.progress.listen(progress.add);
    addTearDown(subscription.cancel);
    addTearDown(controller.dispose);

    final outcome = await controller.run();

    expect(outcome.blockedMessage, contains('数据由更新版本的应用创建'));
    expect(progress.map((event) => event.message), contains('正在检查数据安全...'));
    expect(progress.last.isWorking, isFalse);
    expect(progress.last.blockedMessage, outcome.blockedMessage);
    expect(
      progress.map((event) => event.message),
      isNot(contains('正在检查数据格式版本...')),
      reason:
          'a newer data version must stop the sequence before repair/migration',
    );
    await expectLater(controller.run(), throwsStateError);
  });
}
