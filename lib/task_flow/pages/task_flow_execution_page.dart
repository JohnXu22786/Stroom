import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../catcatch/providers/catcatch_provider.dart';
import '../../providers/background_task_provider.dart';
import '../../providers/provider_config.dart';
import '../../providers/task_provider_shared.dart';
import '../../providers/task_provider.dart';
import '../../utils/audio_separation.dart';
import '../../utils/audio_utils.dart';
import '../../utils/file_manifest.dart';
import '../models/block_type_definition.dart';
import '../models/io_type.dart';
import '../models/task_flow_definition.dart';
import '../models/task_flow_execution.dart';
import '../providers/task_flow_execution_provider.dart';
import '../providers/task_flow_provider.dart';

/// Top-level helper: runs extractAudioSync inside Isolate.run.
Future<Uint8List> _extractAudioIsolate(
    Uint8List videoBytes, String videoFormat) {
  return Isolate.run(
      () => extractAudioSync(videoBytes: videoBytes, videoFormat: videoFormat));
}

/// Page for executing a task flow.
///
/// Shows the flow overview and input field. When the user starts the flow,
/// the page pops back to the main page immediately and the flow runs in the
/// background — just like individual CatCatch / ASR / OCR tasks.
class TaskFlowExecutionPage extends ConsumerStatefulWidget {
  final String flowId;

  const TaskFlowExecutionPage({super.key, required this.flowId});

  @override
  ConsumerState<TaskFlowExecutionPage> createState() =>
      _TaskFlowExecutionPageState();
}

class _TaskFlowExecutionPageState extends ConsumerState<TaskFlowExecutionPage> {
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final flow = ref
        .watch(taskFlowListProvider)
        .where((f) => f.id == widget.flowId)
        .firstOrNull;

    if (flow == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务流')),
        body: const Center(child: Text('任务流未找到')),
      );
    }

    final inputType = flow.inputType;

    return Scaffold(
      appBar: AppBar(
        title: Text(flow.name),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFlowOverviewCard(flow, cs),
            const SizedBox(height: 20),
            _buildInputSection(inputType, flow, cs),
            const SizedBox(height: 16),
            ...flow.blocks.asMap().entries.map((entry) {
              return _buildStepCard(
                block: entry.value,
                index: entry.key,
                cs: cs,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowOverviewCard(TaskFlowDefinition flow, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(flow.name,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
            ],
          ),
          if (flow.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(flow.description,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: flow.blocks.asMap().entries.map((entry) {
                final def = entry.value.getDefinition();
                return Row(children: [
                  if (entry.key > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward,
                          size: 14, color: cs.onSurfaceVariant),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: def?.color.withValues(alpha: 0.12) ??
                          Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      def?.label ?? entry.value.typeKey,
                      style: TextStyle(
                          fontSize: 11,
                          color: def?.color ?? Colors.grey,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(
      IOType inputType, TaskFlowDefinition flow, ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.input, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('输入（${inputType.label}）',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
            ]),
            const SizedBox(height: 8),
            if (inputType == IOType.url)
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: '输入网页链接',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.link, size: 18),
                  filled: true,
                  fillColor: cs.surface,
                ),
                style: const TextStyle(fontSize: 14),
                keyboardType: TextInputType.url,
              )
            else if (inputType == IOType.text)
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: '输入文本',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.text_fields, size: 18),
                  filled: true,
                  fillColor: cs.surface,
                ),
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
              )
            else
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: '输入 ${inputType.label} 路径或标识',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: cs.surface,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: _inputController.text.trim().isNotEmpty
                      ? _startFlow
                      : null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('开始任务流'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required TaskFlowBlock block,
    required int index,
    required ColorScheme cs,
  }) {
    final def = block.getDefinition();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (index > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Icon(Icons.arrow_downward,
                size: 18, color: cs.onSurfaceVariant),
          ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(def?.icon ?? Icons.extension,
                    size: 16, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${index + 1}. ${def?.label ?? block.typeKey}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ========================================================================
  // Flow Execution — pop immediately, all sub-tasks pre-created
  // ========================================================================

  Future<void> _startFlow() async {
    final flow = ref.read(taskFlowListProvider).firstWhere(
          (f) => f.id == widget.flowId,
          orElse: () => TaskFlowDefinition(name: ''),
        );
    if (flow.blocks.isEmpty) return;

    final execNotifier = ref.read(taskFlowExecutionsProvider.notifier);
    final execId = execNotifier.addExecution(
      flowId: flow.id,
      flowName: flow.name,
    );

    // Pre-create placeholder sub-tasks for ALL blocks so the task list
    // card shows the correct count immediately — even before blocks execute.
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

    final inputText = _inputController.text.trim();

    if (mounted) {
      Navigator.pop(context);
    }
    await Future<void>.delayed(Duration.zero);

    String currentData = inputText;

    for (int i = 0; i < flow.blocks.length; i++) {
      final block = flow.blocks[i];
      final def = block.getDefinition();
      if (def == null) {
        execNotifier.failExecution(execId, error: '未知功能块类型');
        return;
      }

      final result = await _executeBlock(
          def, block, currentData, execId, execNotifier,
          flowSubTask: placeholders[i]!);

      if (result.startsWith('[')) {
        execNotifier.failExecution(execId, error: result);
        return;
      }
      currentData = result;
    }

    execNotifier.completeExecution(execId);
  }

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

  Future<String> _executeBlock(
    BlockTypeDefinition def,
    TaskFlowBlock block,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
  }) async {
    switch (def.typeKey) {
      case 'catcatch':
        return await _executeCatCatchBlock(def, input, execId, execNotifier,
            flowSubTask: flowSubTask);
      case 'audioSeparation':
        return await _executeAudioSeparationBlock(
            def, input, execId, execNotifier,
            flowSubTask: flowSubTask);
      case 'asr':
        return await _executeAsrBlock(block, def, input, execId, execNotifier,
            flowSubTask: flowSubTask);
      case 'ocr':
        return await _executeOcrBlock(block, def, input, execId, execNotifier,
            flowSubTask: flowSubTask);
      case 'tts':
        return await _executeTtsBlock(block, def, input, execId, execNotifier,
            flowSubTask: flowSubTask);
      default:
        execNotifier.failExecution(execId, error: '不支持的功能块: ${def.typeKey}');
        return '[${def.typeKey}] 不支持的功能块';
    }
  }

  // ========================================================================
  // CatCatch
  // ========================================================================

  Future<String> _executeCatCatchBlock(
    BlockTypeDefinition def,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
  }) async {
    final catcatchNotifier = ref.read(catcatchTasksProvider.notifier);
    final taskId = catcatchNotifier.addTask(input, 0);
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
    execNotifier.updateSubTaskStatus(
        execId, flowSubTask.id, TaskStatus.running);

    final startTime = DateTime.now();
    const maxWait = Duration(minutes: 10);
    bool autoSelected = false;

    // ignore: literal_only_boolean_expressions
    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      final task = ref
          .read(catcatchTasksProvider)
          .where((t) => t.id == taskId)
          .firstOrNull;

      if (task == null) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.failed);
        return '[CatCatch] 任务丢失';
      }
      if (task.status == TaskStatus.completed) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.completed);
        return task.downloadedFilePath ?? '下载完成（无文件路径）';
      }
      if (task.status == TaskStatus.failed) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.failed);
        return '[CatCatch] ${task.error ?? '任务失败'}';
      }

      if (!autoSelected) {
        final us =
            task.steps.where((s) => s.type == catcatch.StepType.userSelecting);
        if (us.isNotEmpty && !us.first.completed && !us.first.skipped) {
          autoSelected = true;
          if (task.detectedMedia.isNotEmpty) {
            catcatchNotifier.selectMedia(taskId, task.detectedMedia.first);
            execNotifier.updateSubTaskStatus(
                execId, flowSubTask.id, TaskStatus.running);
          } else {
            execNotifier.updateSubTaskStatus(
                execId, flowSubTask.id, TaskStatus.failed);
            return '[CatCatch] 未检测到可用媒体资源';
          }
        }
      }

      if (task.status == TaskStatus.paused) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.paused);
        return '[CatCatch] 任务已暂停';
      }
      if (DateTime.now().difference(startTime) > maxWait) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.failed);
        return '[CatCatch] 下载超时';
      }
    }
  }

  // ========================================================================
  // AudioSeparation
  // ========================================================================

  Future<String> _executeAudioSeparationBlock(
    BlockTypeDefinition def,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
  }) async {
    final bgNotifier = ref.read(backgroundTasksProvider.notifier);
    final inputBasename = p.basename(input);
    final inputFormat = p.extension(input).replaceFirst('.', '').toLowerCase();
    final title = '音频分离_${p.basenameWithoutExtension(inputBasename)}';

    final taskId = bgNotifier.addTask(
        type: BackgroundTaskType.audioSeparation, title: title);
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);

    Uint8List videoBytes;
    try {
      final file = File(input);
      if (!await file.exists()) {
        _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
            '输入文件不存在: $input');
        return '[AudioSeparation] 输入文件不存在';
      }
      videoBytes = await file.readAsBytes();
      if (videoBytes.isEmpty) {
        _failSubTask(
            bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '输入文件为空');
        return '[AudioSeparation] 输入文件为空';
      }
    } catch (e) {
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '无法读取输入文件: $e');
      return '[AudioSeparation] 无法读取输入文件';
    }

    try {
      bgNotifier.updateStep(taskId, 0, running: true);
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.running);

      final audioBytes = await _extractAudioIsolate(videoBytes, inputFormat);
      bgNotifier.updateStep(taskId, 0, completed: true);

      bgNotifier.updateStep(taskId, 1, running: true);
      final filePath = await _saveAudioForFlow(audioBytes);
      bgNotifier.updateStep(taskId, 1, completed: true);

      bgNotifier.completeTask(taskId, downloadedFilePath: filePath);
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.completed);
      return filePath ?? title;
    } catch (e) {
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '音频提取失败: $e');
      return '[AudioSeparation] $e';
    }
  }

  Future<String?> _saveAudioForFlow(Uint8List audioBytes) async {
    if (audioBytes.isEmpty) throw Exception('提取的音频数据为空');
    final hash = computeAudioHash(audioBytes);
    final detectedFormat = detectAudioFormat(audioBytes);
    final format = normalizeAudioFormat(detectedFormat);
    await FileManifest.writeFile('$hash.$format', audioBytes);
    return await FileManifest.readFilePath('$hash.$format');
  }

  // ========================================================================
  // ASR
  // ========================================================================

  Future<String> _executeAsrBlock(
    TaskFlowBlock block,
    BlockTypeDefinition def,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
  }) async {
    final bgNotifier = ref.read(backgroundTasksProvider.notifier);
    final inputBasename = p.basename(input);
    final title = '语音识别_${p.basenameWithoutExtension(inputBasename)}';

    final taskId =
        bgNotifier.addTask(type: BackgroundTaskType.asr, title: title);
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);

    Uint8List audioBytes;
    String audioFormat;
    try {
      final file = File(input);
      if (!await file.exists()) {
        _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
            '输入文件不存在: $input');
        return '[ASR] 输入文件不存在';
      }
      audioBytes = await file.readAsBytes();
      audioFormat = p.extension(input).replaceFirst('.', '').toLowerCase();
      if (audioBytes.isEmpty) {
        _failSubTask(
            bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '输入文件为空');
        return '[ASR] 输入文件为空';
      }
    } catch (e) {
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '读取文件失败: $e');
      return '[ASR] 读取文件失败';
    }

    final modelIndex = int.tryParse(block.params['modelIndex'] ?? '0') ?? 0;
    final entries = ref.read(providerEntriesProvider).entries;
    final configs =
        entries.where((e) => e.type == 'asr').expand((e) => e.configs).toList();

    if (configs.isEmpty || modelIndex >= configs.length) {
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '未配置ASR模型或索引越界');
      return '[ASR] 未配置ASR模型';
    }

    final config = configs[modelIndex];
    final model = config.models.isNotEmpty ? config.models.first : null;
    if (model == null) {
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          'ASR模型配置为空');
      return '[ASR] 模型配置为空';
    }

    try {
      bgNotifier.updateStep(taskId, 0, running: true);
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.running);

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

      final textPath = await _saveTextForFlow(result, title);
      bgNotifier.completeTask(taskId, downloadedFilePath: textPath);
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.completed);
      return result;
    } catch (e) {
      _failSubTask(
          bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '识别失败: $e');
      return '[ASR] $e';
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

  // ========================================================================
  // OCR
  // ========================================================================

  Future<String> _executeOcrBlock(
    TaskFlowBlock block,
    BlockTypeDefinition def,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
  }) async {
    final bgNotifier = ref.read(backgroundTasksProvider.notifier);
    final inputBasename = p.basename(input);
    final title = '文字识别_${p.basenameWithoutExtension(inputBasename)}';

    final taskId =
        bgNotifier.addTask(type: BackgroundTaskType.ocr, title: title);
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);

    Uint8List imageBytes;
    String imageFormat;
    try {
      final file = File(input);
      if (!await file.exists()) {
        _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
            '输入文件不存在: $input');
        return '[OCR] 输入文件不存在';
      }
      imageBytes = await file.readAsBytes();
      imageFormat = p.extension(input).replaceFirst('.', '').toLowerCase();
      if (imageBytes.isEmpty) {
        _failSubTask(
            bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '输入文件为空');
        return '[OCR] 输入文件为空';
      }
    } catch (e) {
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '读取文件失败: $e');
      return '[OCR] 读取文件失败';
    }

    final entries = ref.read(providerEntriesProvider).entries;
    final configs =
        entries.where((e) => e.type == 'ocr').expand((e) => e.configs).toList();

    if (configs.isEmpty) {
      _failSubTask(
          bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '未配置OCR模型');
      return '[OCR] 未配置OCR模型';
    }

    final config = configs.first;
    final model = config.models.isNotEmpty ? config.models.first : null;
    if (model == null) {
      _failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          'OCR模型配置为空');
      return '[OCR] 模型配置为空';
    }

    try {
      bgNotifier.updateStep(taskId, 0, running: true);
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.running);

      final result = await _callOcrApi(
        imageBytes: imageBytes,
        imageFormat: imageFormat,
        host: config.host,
        apiKey: config.key,
        modelId: model.modelId,
      );

      bgNotifier.updateStep(taskId, 0, completed: true);
      bgNotifier.setResult(taskId, result);

      final textPath = await _saveTextForFlow(result, title);
      bgNotifier.completeTask(taskId, downloadedFilePath: textPath);
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.completed);
      return result;
    } catch (e) {
      _failSubTask(
          bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '识别失败: $e');
      return '[OCR] $e';
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
    final base64Image = base64Encode(imageBytes);
    final dataUri = 'data:image/$imageFormat;base64,$base64Image';

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

  // ========================================================================
  // TTS
  // ========================================================================

  Future<String> _executeTtsBlock(
    TaskFlowBlock block,
    BlockTypeDefinition def,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
  }) async {
    final taskListNotifier = ref.read(taskListProvider.notifier);

    final entries = ref.read(providerEntriesProvider).entries;
    final configs =
        entries.where((e) => e.type == 'tts').expand((e) => e.configs).toList();

    if (configs.isEmpty) {
      execNotifier.failExecution(execId, error: '未配置TTS模型');
      return '[TTS] 未配置TTS模型';
    }

    final config = configs.first;
    final model = config.models.isNotEmpty ? config.models.first : null;
    if (model == null) {
      execNotifier.failExecution(execId, error: 'TTS模型配置为空');
      return '[TTS] 模型配置为空';
    }

    final title = input.length > 20 ? input.substring(0, 20) : input;
    final voice = block.params['voice'] ?? '';
    final speed = block.params['speed'] ?? '1.0';

    try {
      final taskId = taskListNotifier.addTask(
        title: title,
        text: input,
        providerConfig: config,
        modelConfig: model,
        customParams: {
          if (voice.isNotEmpty) 'voice': voice,
          'speed': speed,
        },
      );
      execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);

      final startTime = DateTime.now();
      const maxWait = Duration(minutes: 5);

      // ignore: literal_only_boolean_expressions
      while (true) {
        await Future.delayed(const Duration(milliseconds: 500));
        final task =
            ref.read(taskListProvider).where((t) => t.id == taskId).firstOrNull;

        if (task == null) {
          execNotifier.updateSubTaskStatus(
              execId, flowSubTask.id, TaskStatus.failed);
          return '[TTS] 任务丢失';
        }
        if (task.status == TaskStatus.completed) {
          execNotifier.updateSubTaskStatus(
              execId, flowSubTask.id, TaskStatus.completed);
          return task.downloadedFilePath ?? 'tts_${task.id}.wav';
        }
        if (task.status == TaskStatus.failed) {
          execNotifier.updateSubTaskStatus(
              execId, flowSubTask.id, TaskStatus.failed);
          return '[TTS] ${task.error ?? '任务失败'}';
        }
        if (DateTime.now().difference(startTime) > maxWait) {
          execNotifier.updateSubTaskStatus(
              execId, flowSubTask.id, TaskStatus.failed);
          return '[TTS] 合成超时';
        }
      }
    } catch (e) {
      execNotifier.failExecution(execId, error: 'TTS失败: $e');
      return '[TTS] $e';
    }
  }

  // ========================================================================
  // Helpers
  // ========================================================================

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

  Future<String?> _saveTextForFlow(String text, String title) async {
    if (text.isEmpty) return null;
    final hash = computeAudioHash(Uint8List.fromList(text.codeUnits));
    final path = '$hash.txt';
    await FileManifest.writeFile(path, Uint8List.fromList(text.codeUnits));
    return await FileManifest.readFilePath(path);
  }
}
