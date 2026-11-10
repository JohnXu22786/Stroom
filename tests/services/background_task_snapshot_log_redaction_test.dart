import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/background_task_provider.dart';

Future<
    ({
      bool restored,
      List<BackgroundTask> tasks,
      List<String> loggedMessages,
    })> _restoreSnapshot(String snapshot) async {
  SharedPreferences.setMockInitialValues({});
  final directory = await Directory.systemTemp
      .createTemp('background_task_snapshot_redaction_');
  final originalStorageOverride =
      BackgroundTaskNotifier.debugStorageDirectoryOverride;
  final originalDebugPrint = debugPrint;
  final loggedMessages = <String>[];
  BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) loggedMessages.add(message);
  };
  final notifier = BackgroundTaskNotifier();

  try {
    final taskDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}background',
    );
    await taskDirectory.create(recursive: true);
    await File(
      '${taskDirectory.path}${Platform.pathSeparator}tasks.json',
    ).writeAsString(snapshot);

    final restored = await notifier.restoreFromPersistence();
    return (
      restored: restored,
      tasks: List.of(notifier.state),
      loggedMessages: List.of(loggedMessages),
    );
  } finally {
    debugPrint = originalDebugPrint;
    BackgroundTaskNotifier.debugStorageDirectoryOverride =
        originalStorageOverride;
    if (notifier.mounted) notifier.dispose();
    await notifier.pendingPersistence;
    await directory.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('malformed task snapshots fail closed without logging source text',
      () async {
    final result = await _restoreSnapshot(
      '[{"apiKey":"OCR-SECRET-DO-NOT-LOG","prompt":"private prompt"',
    );

    expect(result.restored, isFalse);
    expect(result.tasks, isEmpty);
    expect(result.loggedMessages, hasLength(1));
    expect(
      result.loggedMessages.single,
      '[BackgroundTaskNotifier] Failed to decode task list.',
    );
    expect(
      result.loggedMessages.join('\n'),
      isNot(contains('OCR-SECRET-DO-NOT-LOG')),
    );
    expect(result.loggedMessages.join('\n'), isNot(contains('private prompt')));
  });

  test('corrupt task rows do not log invalid field values', () async {
    final result = await _restoreSnapshot(
      '[{"id":"task-1","type":"ocr","title":"safe",'
      '"status":"failed","createdAt":"ROW-SECRET-DO-NOT-LOG"}]',
    );

    expect(result.restored, isFalse);
    expect(result.tasks, isEmpty);
    expect(result.loggedMessages, hasLength(1));
    expect(
      result.loggedMessages.single,
      '[BackgroundTaskNotifier] Skipping corrupt task entry.',
    );
    expect(
      result.loggedMessages.join('\n'),
      isNot(contains('ROW-SECRET-DO-NOT-LOG')),
    );
  });
}
