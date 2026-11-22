import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/utils/web_file_store.dart';

class _BackupPathProviderMock extends PathProviderPlatform {
  _BackupPathProviderMock(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('task-flow backup rejects attachment symlinks outside storage',
      () async {
    expect(WebFileStore.isTestMode, isFalse);
    SharedPreferences.setMockInitialValues({});

    final originalPathProvider = PathProviderPlatform.instance;
    final tempRoot = await Directory.systemTemp.createTemp('backup_task_link_');
    final appDir = Directory(p.join(tempRoot.path, 'app'));
    final attachmentsDir = Directory(p.join(appDir.path, 'attachments'));
    final outsideDir = Directory(p.join(tempRoot.path, 'outside'));
    final taskFlowsDir = Directory(p.join(appDir.path, 'task_flows'));
    await attachmentsDir.create(recursive: true);
    await outsideDir.create();
    await taskFlowsDir.create();
    await File(p.join(outsideDir.path, 'private.txt')).writeAsString('private');
    await Link(p.join(attachmentsDir.path, 'external-link'))
        .create(outsideDir.path);
    await File(p.join(taskFlowsDir.path, 'executions.json')).writeAsString(
      jsonEncode([
        {'attachment': 'attachments/external-link/private.txt'},
      ]),
    );
    PathProviderPlatform.instance = _BackupPathProviderMock(appDir.path);
    AppStorage.resetCache();
    addTearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      AppStorage.resetCache();
      await tempRoot.delete(recursive: true);
    });

    expect(await AppStorage.directory, appDir.path);
    expect(
      await BackupService.collectTaskFlowAttachmentKeysForSafety(),
      contains('attachments/external-link/private.txt'),
    );

    Object? backupError;
    try {
      await BackupService.buildBackupBytesForTest(
        selection: const BackupSelection(
          chatRecordsAndAttachments: false,
          settings: false,
          pictures: false,
          audio: false,
          videos: false,
          texts: false,
          tasks: true,
          ankiData: false,
          browserCookies: false,
          includeMediaFiles: true,
        ),
      );
    } catch (error) {
      backupError = error;
    }
    expect(backupError, isA<DataManagementPreflightException>());
  });
}
