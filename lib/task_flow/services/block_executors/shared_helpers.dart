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

Future<String?> saveTextForFlow(
  String text, {
  String saveFolder = '',
  String? title,
}) async {
  if (text.isEmpty) return null;
  final bytes = Uint8List.fromList(utf8.encode(text));
  final hash = computeTextHash(bytes);
  final storageFileName = '$hash.txt';
  final filePath = await TextManifest.writeText(storageFileName, text);

  String baseName = title ?? 'FLOW_${DateTime.now().millisecondsSinceEpoch}';
  String recordName = baseName;
  final records = await TextManifest.loadRecords();
  int dedupIdx = 2;
  while (records.any((r) => r.name == recordName && r.folder == saveFolder)) {
    recordName = '$baseName ($dedupIdx)';
    dedupIdx++;
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
