import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../catcatch/engine/executor_save.dart';
import '../../../catcatch/models/catcatch_task.dart' as catcatch;

/// The native save normally registers the output first. This fallback shares
/// its content lock and rollback rules, so a canceled flow cannot publish a
/// late gallery record.
Future<CompletedMediaRegistration> registerFlowCatCatchOutput(
  String filePath,
  catcatch.CatCatchTask task, {
  bool Function()? isCurrent,
  @visibleForTesting Future<void> Function()? afterRecordAdded,
}) =>
    registerCompletedMedia(
      filePath,
      task,
      cancelled: () => !(isCurrent?.call() ?? true),
      skipIfRegistered: true,
      afterRecordAdded: afterRecordAdded,
    );
