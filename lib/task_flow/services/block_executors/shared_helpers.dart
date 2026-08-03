import 'dart:convert';
import 'dart:typed_data';

import '../../../providers/background_task_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../utils/text_manifest.dart';
import '../../providers/task_flow_execution_provider.dart';

void failSubTask(
  BackgroundTaskNotifier bgNotifier,
  String taskId,
  TaskFlowExecutionNotifier execNotifier,
  String execId,
  String flowSubTaskId,
  String error,
) {
  bgNotifier.failTask(taskId, error: error);
  execNotifier.updateSubTaskStatus(execId, flowSubTaskId, TaskStatus.failed);
}

/// Reads an int-typed block param safely.
///
/// Block params are `dynamic`: the editor stores `int` for dropdowns,
/// `num` for number fields, and JSON persistence round-trips numbers as
/// `num` and strings as `String`. `int.tryParse` on a `num` throws a
/// runtime `TypeError`, so values must be coerced before parsing.
int asIntParam(Map<String, dynamic> params, String key, int fallback) {
  final raw = params[key];
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

/// Reads a String-typed block param safely.
///
/// Number fields store `num`; passing those directly into a
/// `Map<String, String>` throws a runtime `TypeError`. Values are
/// stringified (or the fallback returned) instead.
String asStringParam(
  Map<String, dynamic> params,
  String key,
  String fallback,
) {
  final raw = params[key];
  if (raw == null) return fallback;
  return raw is String ? raw : raw.toString();
}

Future<String?> saveTextForFlow(
  String text, {
  String saveFolder = '',
  String? title,

  /// Optional guard checked right before the gallery record is committed.
  /// Flow executors pass a check that the execution still exists, so a
  /// flow deleted mid-save does not leave an orphaned text record.
  bool Function()? shouldCommit,
}) async {
  if (text.isEmpty) return null;
  final bytes = Uint8List.fromList(utf8.encode(text));
  final hash = computeTextHash(bytes);
  final storageFileName = '$hash.txt';
  final filePath = await TextManifest.writeText(storageFileName, text);

  if (shouldCommit != null && !shouldCommit()) return null;

  String baseName = title ?? 'FLOW_${DateTime.now().millisecondsSinceEpoch}';
  String recordName = baseName;
  final records = await TextManifest.loadRecords();
  int dedupIdx = 2;
  while (records.any((r) => r.name == recordName && r.folder == saveFolder) &&
      dedupIdx <= 10000) {
    recordName = '$baseName ($dedupIdx)';
    dedupIdx++;
  }
  if (dedupIdx > 10000) {
    recordName = '$baseName _${DateTime.now().millisecondsSinceEpoch}';
  }

  await TextManifest.addRecord(
    TextRecord(
      name: recordName,
      hash: hash,
      format: 'txt',
      createdAt: DateTime.now(),
      size: bytes.length,
      folder: saveFolder,
      textLength: text.length,
    ),
  );
  return filePath;
}
