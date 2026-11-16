// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/task_flow/services/task_flow_input_cleanup.dart';

class _FailingStringListStore extends InMemorySharedPreferencesStore {
  _FailingStringListStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AttachmentStorage.resetOverridesForTesting();
  });

  tearDown(AttachmentStorage.resetOverridesForTesting);

  test(
    'successful cleanup deletes the file and clears its retry marker',
    () async {
      final deleted = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deleted.add(path);
        return true;
      };

      await TaskFlowInputCleanup.enqueueAll(['attachments/input.pdf']);
      await TaskFlowInputCleanup.retryPending();

      expect(deleted, ['attachments/input.pdf']);
      expect(await TaskFlowInputCleanup.pendingReferencesForTesting(), isEmpty);
    },
  );

  test('failed cleanup remains queued for a later successful retry', () async {
    final deleted = <String>[];
    var failDelete = true;
    AttachmentStorage.deleteFileOverrideForTesting = (path) async {
      deleted.add(path);
      if (failDelete) throw StateError('temporary storage failure');
      return true;
    };

    await TaskFlowInputCleanup.enqueueAll(['attachments/input.pdf']);
    await TaskFlowInputCleanup.retryPending();

    expect(await TaskFlowInputCleanup.pendingReferencesForTesting(), [
      'attachments/input.pdf',
    ]);
    failDelete = false;
    await TaskFlowInputCleanup.retryPending();

    expect(deleted, ['attachments/input.pdf', 'attachments/input.pdf']);
    expect(await TaskFlowInputCleanup.pendingReferencesForTesting(), isEmpty);
  });

  test('failed queue persistence prevents deleting the input', () async {
    SharedPreferencesStorePlatform.instance = _FailingStringListStore();
    var deleteAttempted = false;
    AttachmentStorage.deleteFileOverrideForTesting = (path) async {
      deleteAttempted = true;
      return true;
    };

    await expectLater(
      TaskFlowInputCleanup.enqueueAll(['attachments/input.pdf']),
      throwsA(isA<StateError>()),
    );

    expect(deleteAttempted, isFalse);
  });
}
