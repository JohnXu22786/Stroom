import 'dart:convert';
import 'dart:typed_data';

import '../../../providers/background_task_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../utils/audio_utils.dart';
import '../../../utils/file_manifest.dart';
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

Future<String?> saveTextForFlow(String text,
    {String saveFolder = '', String? title}) async {
  if (text.isEmpty) return null;
  final bytes = Uint8List.fromList(utf8.encode(text));
  final hash = computeTextHash(bytes);
  final storageFileName = '$hash.txt';
  final filePath = await TextManifest.writeText(storageFileName, text);
  await TextManifest.addRecord(TextRecord(
    name: title ?? 'FLOW_${DateTime.now().millisecondsSinceEpoch}',
    hash: hash,
    format: 'txt',
    createdAt: DateTime.now(),
    size: bytes.length,
    folder: saveFolder,
    textLength: text.length,
  ));
  return filePath;
}

Future<String?> saveAudioForFlow(
  Uint8List audioBytes, {
  String saveFolder = '',
  String? title,
}) async {
  if (audioBytes.isEmpty) throw Exception('提取的音频数据为空');
  final hash = computeAudioHash(audioBytes);
  final format = normalizeAudioFormat(detectAudioFormat(audioBytes));

  await FileManifest.writeFile('$hash.$format', audioBytes);

  final record = AudioRecord(
    name: title ?? '音频分离_${DateTime.now().millisecondsSinceEpoch}',
    hash: hash,
    format: format,
    createdAt: DateTime.now(),
    size: audioBytes.length,
    folder: saveFolder,
  );
  await FileManifest.addRecord(record);

  return await FileManifest.readFilePath('$hash.$format');
}
