import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../catcatch/providers/catcatch_provider.dart';
import '../../providers/background_task_provider.dart';
import '../../providers/provider_config.dart';
import '../../providers/task_provider.dart';
import '../../providers/task_provider_shared.dart';
import '../../utils/audio_separation.dart';
import '../../utils/audio_utils.dart';
import '../../utils/file_manifest.dart';
import '../models/block_type_definition.dart';
import '../models/task_flow_definition.dart';
import '../models/task_flow_execution.dart';
import '../providers/task_flow_execution_provider.dart';
import '../providers/task_flow_provider.dart';

// =============================================================================
// Provider — Ref lives in ProviderContainer, NEVER disposed by widget lifecycle
// =============================================================================

final taskFlowExecutionServiceProvider = Provider<TaskFlowExecutionService>(
  (ref) => TaskFlowExecutionService._(ref),
);

// =============================================================================
// Top-level isolate helper (runs audio extraction off main thread)
// =============================================================================

Future<Uint8List> _extractAudioIsolate(
    Uint8List videoBytes, String videoFormat) {
  return Isolate.run(
      () => extractAudioSync(videoBytes: videoBytes, videoFormat: videoFormat));
}

// =============================================================================
// Service
// =============================================================================

class TaskFlowExecutionService {
  final Ref _ref;

  TaskFlowExecutionService._(this._ref);

  // ===========================================================================
  // Public entry point
  // ===========================================================================

  /// Start executing a task flow.
  ///
  /// Creates an execution entry, runs blocks sequentially, and keeps the
  /// execution state updated via [taskFlowExecutionsProvider].
  ///
  /// This runs asynchronously and independently of any widget lifecycle
  /// because [_ref] comes from a global [Provider], not from a widget.
  Future<void> startFlow(String flowId, String inputText) async {
    // ── Read flow definition ──
    final flow = _ref.read(taskFlowListProvider).firstWhere(
          (f) => f.id == flowId,
          orElse: () => TaskFlowDefinition(name: ''),
        );
    if (flow.blocks.isEmpty) return;

    // ── Get notifiers from global Ref ──
    final execNotifier = _ref.read(taskFlowExecutionsProvider.notifier);
    final catcatchNotifier = _ref.read(catcatchTasksProvider.notifier);
    final bgNotifier = _ref.read(backgroundTasksProvider.notifier);
    final taskListNotifier = _ref.read(taskListProvider.notifier);

    // ── Create execution with placeholders ──
    final execId = execNotifier.addExecution(
      flowId: flow.id,
      flowName: flow.name,
    );

    final placeholders = <int, FlowSubTask>{};
    for (int i = 0; i < flow.blocks.length; i++) {
      final block = flow.blocks[i];
      final def = block.getDefinition();
      final subTask = FlowSubTask(
        blockTypeKey: def?.typeKey ?? block.typeKey,
        blockLabel: def?.label ?? block.typeKey,
        subTaskId: 'pending_${block.typeKey}_$i',
        subTaskType: _subTaskType(def?.typeKey),
        status: TaskStatus.waiting,
      );
      execNotifier.addSubTask(execId, subTask);
      placeholders[i] = subTask;
    }

    // ── Run blocks sequentially ──
    String currentData = inputText;

    for (int i = 0; i < flow.blocks.length; i++) {
      final block = flow.blocks[i];
      final def = block.getDefinition();

      if (def == null) {
        execNotifier.failExecution(execId, error: '未知功能块类型');
        return;
      }

      try {
        final providerState = _ref.read(providerEntriesProvider);
        final result = await _executeBlock(
          def,
          block,
          currentData,
          execId,
          execNotifier,
          flowSubTask: placeholders[i]!,
          catcatchNotifier: catcatchNotifier,
          bgNotifier: bgNotifier,
          taskListNotifier: taskListNotifier,
          providerEntries: providerState,
        );
        currentData = result;
      } catch (e) {
        execNotifier.failExecution(execId, error: '步骤 ${i + 1} 失败: $e');
        return;
      }
    }

    execNotifier.completeExecution(execId);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  String _subTaskType(String? typeKey) {
    switch (typeKey) {
      case 'catcatch':
        return 'catcatch';
      case 'tts':
        return 'synthesis';
      default:
        return 'background';
    }
  }

  void _failSubTask(
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

  Future<String?> _saveTextForFlow(String text) async {
    if (text.isEmpty) return null;
    final hash = computeAudioHash(Uint8List.fromList(text.codeUnits));
    final path = '$hash.txt';
    await FileManifest.writeFile(path, Uint8List.fromList(text.codeUnits));
    return await FileManifest.readFilePath(path);
  }

  Future<String?> _saveAudioForFlow(
      Uint8List audioBytes, String inputFilePath) async {
    if (audioBytes.isEmpty) throw Exception('提取的音频数据为空');
    final format = normalizeAudioFormat(detectAudioFormat(audioBytes));

    // Save to the same directory as the input video so the user can find
    // the file.  Use a readable name derived from the video filename.
    final inputDir = p.dirname(inputFilePath);
    final inputBaseName = p.basenameWithoutExtension(inputFilePath);
    final outputFileName = '${inputBaseName}_audio.$format';
    final outputPath = p.join(inputDir, outputFileName);

    await File(outputPath).writeAsBytes(audioBytes);
    return outputPath;
  }

  // ===========================================================================
  // Block dispatcher
  // ===========================================================================

  Future<String> _executeBlock(
    BlockTypeDefinition def,
    TaskFlowBlock block,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
    required CatCatchNotifier catcatchNotifier,
    required BackgroundTaskNotifier bgNotifier,
    required TaskListNotifier taskListNotifier,
    required ProviderEntriesState providerEntries,
  }) async {
    switch (def.typeKey) {
      case 'catcatch':
        return await _executeCatCatchBlock(def, input, execId, execNotifier,
            flowSubTask: flowSubTask,
            catcatchNotifier: catcatchNotifier,
            videoFolder: block.params['videoFolder'] ?? '',
            audioFolder: block.params['audioFolder'] ?? '');
      case 'audioSeparation':
        return await _executeAudioSeparationBlock(
            def, input, execId, execNotifier,
            flowSubTask: flowSubTask, bgNotifier: bgNotifier);
      case 'asr':
        return await _executeAsrBlock(block, def, input, execId, execNotifier,
            flowSubTask: flowSubTask,
            bgNotifier: bgNotifier,
            providerEntries: providerEntries);
      case 'ocr':
        return await _executeOcrBlock(block, def, input, execId, execNotifier,
            flowSubTask: flowSubTask,
            bgNotifier: bgNotifier,
            providerEntries: providerEntries);
      case 'tts':
        return await _executeTtsBlock(block, def, input, execId, execNotifier,
            flowSubTask: flowSubTask,
            taskListNotifier: taskListNotifier,
            providerEntries: providerEntries);
      default:
        execNotifier.failExecution(execId, error: '不支持的功能块: ${def.typeKey}');
        throw '不支持的功能块: ${def.typeKey}';
    }
  }

  // ===========================================================================
  // CatCatch
  // ===========================================================================

  Future<String> _executeCatCatchBlock(
    BlockTypeDefinition def,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
    required CatCatchNotifier catcatchNotifier,
    String videoFolder = '',
    String audioFolder = '',
  }) async {
    // Generate ID first, update execution, THEN add task to provider.
    // This ensures the card sees the real task ID when it rebuilds from
    // the provider notification.
    final taskId = const Uuid().v4();
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
    execNotifier.updateSubTaskStatus(
        execId, flowSubTask.id, TaskStatus.running);
    catcatchNotifier.addTask(input, 0,
        taskId: taskId, videoFolder: videoFolder, audioFolder: audioFolder);

    final startTime = DateTime.now();
    const maxWait = Duration(minutes: 10);
    bool autoSelected = false;
    bool autoConfirmed = false;

    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      final task =
          catcatchNotifier.state.where((t) => t.id == taskId).firstOrNull;

      if (task == null) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.failed);
        throw 'CatCatch: 任务丢失';
      }

      if (task.status == catcatch.TaskStatus.completed) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.completed);
        if (task.downloadedFilePath != null) return task.downloadedFilePath!;
        throw 'CatCatch: 下载完成但无文件路径';
      }
      if (task.status == catcatch.TaskStatus.failed) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.failed);
        throw 'CatCatch: ${task.error ?? '任务失败'}';
      }
      if (task.status == catcatch.TaskStatus.paused) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.paused);
        throw 'CatCatch: 任务已暂停';
      }

      // Auto-select media
      if (!autoSelected) {
        final us =
            task.steps.where((s) => s.type == catcatch.StepType.userSelecting);
        if (us.isNotEmpty && !us.first.completed && !us.first.skipped) {
          // Wait until detectedMedia is populated by the executor before
          // attempting auto-select.  The userSelecting step may become
          // active before the page analysis finishes populating
          // detectedMedia.  Throwing here would terminate the flow
          // prematurely — instead, keep polling.
          if (task.detectedMedia.isNotEmpty) {
            try {
              catcatchNotifier.selectMedia(taskId, task.detectedMedia.first);
              autoSelected = true; // only latch after success
              execNotifier.updateSubTaskStatus(
                  execId, flowSubTask.id, TaskStatus.running);
            } catch (e) {
              execNotifier.updateSubTaskStatus(
                  execId, flowSubTask.id, TaskStatus.failed);
              throw 'CatCatch: 自动选择媒体失败: $e';
            }
          }
        }
      }

      // Auto-confirm special format
      if (!autoConfirmed &&
          task.metadata['pendingConfirm'] == 'special_format') {
        autoConfirmed = true;
        try {
          catcatchNotifier.confirmAndContinue(taskId);
          execNotifier.updateSubTaskStatus(
              execId, flowSubTask.id, TaskStatus.running);
        } catch (e) {
          execNotifier.updateSubTaskStatus(
              execId, flowSubTask.id, TaskStatus.failed);
          throw 'CatCatch: 自动处理特殊格式失败: $e';
        }
      }

      if (DateTime.now().difference(startTime) > maxWait) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.failed);
        throw 'CatCatch: 下载超时';
      }
    }
  }

  // ===========================================================================
  // AudioSeparation
  // ===========================================================================

  Future<String> _executeAudioSeparationBlock(
    BlockTypeDefinition def,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
    required BackgroundTaskNotifier bgNotifier,
  }) async {
    final inputBasename = p.basename(input);
    final inputFormat = p.extension(input).replaceFirst('.', '').toLowerCase();
    final title = '音频分离_${p.basenameWithoutExtension(inputBasename)}';

    // Generate ID first, update execution, THEN add task to provider.
    final taskId = const Uuid().v4();
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
    execNotifier.updateSubTaskStatus(
        execId, flowSubTask.id, TaskStatus.running);
    bgNotifier.addTask(
        type: BackgroundTaskType.audioSeparation, title: title, taskId: taskId);

    Uint8List videoBytes;
    try {
      final file = File(input);
      if (!await file.exists()) {
        _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
            '输入文件不存在: $input');
        throw 'AudioSeparation: 输入文件不存在';
      }
      videoBytes = await file.readAsBytes();
      if (videoBytes.isEmpty) {
        _failSubTask(
            bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '输入文件为空');
        throw 'AudioSeparation: 输入文件为空';
      }
    } catch (e) {
      if (e is String && e.startsWith('AudioSeparation:')) rethrow;
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '无法读取输入文件: $e');
      throw 'AudioSeparation: 无法读取输入文件';
    }

    try {
      bgNotifier.updateStep(taskId, 0, running: true);
      final audioBytes = await _extractAudioIsolate(videoBytes, inputFormat);
      bgNotifier.updateStep(taskId, 0, completed: true);

      bgNotifier.updateStep(taskId, 1, running: true);
      final filePath = await _saveAudioForFlow(audioBytes, input);
      bgNotifier.updateStep(taskId, 1, completed: true);

      if (filePath == null) {
        _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
            '无法保存提取的音频文件');
        throw 'AudioSeparation: 无法保存提取的音频文件';
      }

      bgNotifier.completeTask(taskId, downloadedFilePath: filePath);
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.completed);
      return filePath;
    } catch (e) {
      if (e is String && e.startsWith('AudioSeparation:')) rethrow;
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '音频提取失败: $e');
      throw 'AudioSeparation: $e';
    }
  }

  // ===========================================================================
  // ASR
  // ===========================================================================

  Future<String> _executeAsrBlock(
    TaskFlowBlock block,
    BlockTypeDefinition def,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
    required BackgroundTaskNotifier bgNotifier,
    required ProviderEntriesState providerEntries,
  }) async {
    final inputBasename = p.basename(input);
    final title = '语音识别_${p.basenameWithoutExtension(inputBasename)}';

    // Generate ID first, update execution, THEN add task to provider.
    final taskId = const Uuid().v4();
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
    execNotifier.updateSubTaskStatus(
        execId, flowSubTask.id, TaskStatus.running);
    bgNotifier.addTask(
        type: BackgroundTaskType.asr, title: title, taskId: taskId);

    Uint8List audioBytes;
    String audioFormat;
    try {
      final file = File(input);
      if (!await file.exists()) {
        _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
            '输入文件不存在: $input');
        throw 'ASR: 输入文件不存在';
      }
      audioBytes = await file.readAsBytes();
      audioFormat = p.extension(input).replaceFirst('.', '').toLowerCase();
      if (audioBytes.isEmpty) {
        _failSubTask(
            bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '输入文件为空');
        throw 'ASR: 输入文件为空';
      }
    } catch (e) {
      if (e is String && e.startsWith('ASR:')) rethrow;
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '读取文件失败: $e');
      throw 'ASR: 读取文件失败';
    }

    final modelIndex = int.tryParse(block.params['modelIndex'] ?? '0') ?? 0;
    final configs = providerEntries.entries
        .where((e) => e.type == 'asr')
        .expand((e) => e.configs)
        .toList();

    if (configs.isEmpty || modelIndex >= configs.length) {
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '未配置ASR模型或索引越界');
      throw 'ASR: 未配置ASR模型';
    }

    final config = configs[modelIndex];
    final model = config.models.isNotEmpty ? config.models.first : null;
    if (model == null) {
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          'ASR模型配置为空');
      throw 'ASR: 模型配置为空';
    }

    try {
      bgNotifier.updateStep(taskId, 0, running: true);
      final result = await _callAsrApi(
        audioBytes: audioBytes,
        audioFormat: audioFormat,
        host: config.host,
        apiKey: config.key,
        modelId: model.modelId,
        typeConfig: model.typeConfig,
      );
      bgNotifier.updateStep(taskId, 0, completed: true);
      bgNotifier.setResult(taskId, result);

      final textPath = await _saveTextForFlow(result);
      bgNotifier.completeTask(taskId, downloadedFilePath: textPath);
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.completed);
      return result;
    } catch (e) {
      if (e is String && e.startsWith('ASR:')) rethrow;
      _failSubTask(
          bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '识别失败: $e');
      throw 'ASR: $e';
    }
  }

  Future<String> _callAsrApi({
    required Uint8List audioBytes,
    required String audioFormat,
    required String host,
    required String apiKey,
    required String modelId,
    Map<String, dynamic> typeConfig = const {},
  }) async {
    final dio = Dio();
    final mimeStr = audioFormat == 'wav' ? 'audio/wav' : 'audio/$audioFormat';
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(audioBytes,
          filename: 'audio.$audioFormat',
          contentType: DioMediaType.parse(mimeStr)),
      'model': modelId,
      'response_format': 'json',
      ...typeConfig,
    });
    final response = await dio.post(host,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}));
    if (response.data is Map) return (response.data['text'] as String?) ?? '';
    return response.data.toString();
  }

  // ===========================================================================
  // OCR
  // ===========================================================================

  Future<String> _executeOcrBlock(
    TaskFlowBlock block,
    BlockTypeDefinition def,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
    required BackgroundTaskNotifier bgNotifier,
    required ProviderEntriesState providerEntries,
  }) async {
    final inputBasename = p.basename(input);
    final title = '文字识别_${p.basenameWithoutExtension(inputBasename)}';

    // Generate ID first, update execution, THEN add task to provider.
    final taskId = const Uuid().v4();
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
    execNotifier.updateSubTaskStatus(
        execId, flowSubTask.id, TaskStatus.running);
    bgNotifier.addTask(
        type: BackgroundTaskType.ocr, title: title, taskId: taskId);

    Uint8List imageBytes;
    String imageFormat;
    try {
      final file = File(input);
      if (!await file.exists()) {
        _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
            '输入文件不存在: $input');
        throw 'OCR: 输入文件不存在';
      }
      imageBytes = await file.readAsBytes();
      imageFormat = p.extension(input).replaceFirst('.', '').toLowerCase();
      if (imageBytes.isEmpty) {
        _failSubTask(
            bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '输入文件为空');
        throw 'OCR: 输入文件为空';
      }
    } catch (e) {
      if (e is String && e.startsWith('OCR:')) rethrow;
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '读取文件失败: $e');
      throw 'OCR: 读取文件失败';
    }

    final configs = providerEntries.entries
        .where((e) => e.type == 'ocr')
        .expand((e) => e.configs)
        .toList();
    if (configs.isEmpty) {
      _failSubTask(
          bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '未配置OCR模型');
      throw 'OCR: 未配置OCR模型';
    }

    final config = configs.first;
    final model = config.models.isNotEmpty ? config.models.first : null;
    if (model == null) {
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          'OCR模型配置为空');
      throw 'OCR: 模型配置为空';
    }

    try {
      bgNotifier.updateStep(taskId, 0, running: true);
      final result = await _callOcrApi(
        imageBytes: imageBytes,
        imageFormat: imageFormat,
        host: config.host,
        apiKey: config.key,
        modelId: model.modelId,
      );
      bgNotifier.updateStep(taskId, 0, completed: true);
      bgNotifier.setResult(taskId, result);

      final textPath = await _saveTextForFlow(result);
      bgNotifier.completeTask(taskId, downloadedFilePath: textPath);
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.completed);
      return result;
    } catch (e) {
      if (e is String && e.startsWith('OCR:')) rethrow;
      _failSubTask(
          bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '识别失败: $e');
      throw 'OCR: $e';
    }
  }

  Future<String> _callOcrApi({
    required Uint8List imageBytes,
    required String imageFormat,
    required String host,
    required String apiKey,
    required String modelId,
  }) async {
    final dio = Dio();
    final dataUri =
        'data:image/$imageFormat;base64,${base64Encode(imageBytes)}';
    final body = {
      'model': modelId,
      'max_tokens': 4096,
      'temperature': 0.0,
      'messages': [
        {'role': 'system', 'content': '请提取图片中的所有文字内容。只返回文字，不要添加任何解释。'},
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': dataUri, 'detail': 'high'}
            }
          ]
        }
      ]
    };
    final response = await dio.post(host,
        data: body,
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }));
    if (response.data is Map) {
      final choices = response.data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final msg = choices.first['message'] as Map<String, dynamic>?;
        return msg?['content'] as String? ?? '';
      }
    }
    return '';
  }

  // ===========================================================================
  // TTS
  // ===========================================================================

  Future<String> _executeTtsBlock(
    TaskFlowBlock block,
    BlockTypeDefinition def,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
    required TaskListNotifier taskListNotifier,
    required ProviderEntriesState providerEntries,
  }) async {
    final configs = providerEntries.entries
        .where((e) => e.type == 'tts')
        .expand((e) => e.configs)
        .toList();
    if (configs.isEmpty) {
      execNotifier.failExecution(execId, error: '未配置TTS模型');
      throw 'TTS: 未配置TTS模型';
    }

    final config = configs.first;
    final model = config.models.isNotEmpty ? config.models.first : null;
    if (model == null) {
      execNotifier.failExecution(execId, error: 'TTS模型配置为空');
      throw 'TTS: 模型配置为空';
    }

    final title = input.length > 20 ? input.substring(0, 20) : input;
    final voice = block.params['voice'] ?? '';
    final speed = block.params['speed'] ?? '1.0';

    try {
      // Generate ID first, update execution, THEN add task to provider.
      final taskId = const Uuid().v4();
      execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.running);
      taskListNotifier.addTask(
        title: title,
        text: input,
        providerConfig: config,
        modelConfig: model,
        customParams: {
          if (voice.isNotEmpty) 'voice': voice,
          'speed': speed,
        },
        taskId: taskId,
      );

      final startTime = DateTime.now();
      const maxWait = Duration(minutes: 5);

      while (true) {
        await Future.delayed(const Duration(milliseconds: 500));
        final task =
            taskListNotifier.state.where((t) => t.id == taskId).firstOrNull;

        if (task == null) {
          execNotifier.updateSubTaskStatus(
              execId, flowSubTask.id, TaskStatus.failed);
          throw 'TTS: 任务丢失';
        }
        if (task.status == TaskStatus.completed) {
          execNotifier.updateSubTaskStatus(
              execId, flowSubTask.id, TaskStatus.completed);
          if (task.downloadedFilePath != null) return task.downloadedFilePath!;
          throw 'TTS: 合成完成但无文件路径';
        }
        if (task.status == TaskStatus.failed) {
          execNotifier.updateSubTaskStatus(
              execId, flowSubTask.id, TaskStatus.failed);
          throw 'TTS: ${task.error ?? '任务失败'}';
        }
        if (DateTime.now().difference(startTime) > maxWait) {
          execNotifier.updateSubTaskStatus(
              execId, flowSubTask.id, TaskStatus.failed);
          throw 'TTS: 合成超时';
        }
      }
    } catch (e) {
      if (e is String && e.startsWith('TTS:')) rethrow;
      execNotifier.failExecution(execId, error: 'TTS失败: $e');
      throw 'TTS: $e';
    }
  }
}
