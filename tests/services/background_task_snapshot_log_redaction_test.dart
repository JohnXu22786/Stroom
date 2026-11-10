import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/background_task_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('malformed task snapshots fail closed without logging source text',
      () async {
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
      ).writeAsString(
        '[{"apiKey":"OCR-SECRET-DO-NOT-LOG","prompt":"private prompt"',
      );

      expect(await notifier.restoreFromPersistence(), isFalse);
      expect(notifier.state, isEmpty);
      expect(loggedMessages, hasLength(1));
      expect(
        loggedMessages.single,
        '[BackgroundTaskNotifier] Failed to decode task list.',
      );
      expect(loggedMessages.join('\n'), isNot(contains('OCR-SECRET-DO-NOT-LOG')));
      expect(loggedMessages.join('\n'), isNot(contains('private prompt')));
    } finally {
      debugPrint = originalDebugPrint;
      BackgroundTaskNotifier.debugStorageDirectoryOverride =
          originalStorageOverride;
      if (notifier.mounted) notifier.dispose();
      await notifier.pendingPersistence;
      await directory.delete(recursive: true);
    }
  });
}
