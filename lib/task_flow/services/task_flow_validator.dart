import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/assistant.dart';
import '../../providers/provider_config.dart';
import '../../utils/provider_models.dart';
import '../../utils/web_file_store.dart';
import '../models/block_type_definition.dart';
import '../models/io_type.dart';
import '../models/task_flow_definition.dart';
import '../models/task_flow_execution.dart';

/// User-actionable failure, shared by launch, batch launch and history retry.
class TaskFlowValidationException implements Exception {
  final String message;
  final String flowId;
  final String? blockId;
  final int? blockIndex;
  final int? inputIndex;
  final bool isInputError;

  const TaskFlowValidationException(
    this.message, {
    required this.flowId,
    this.blockId,
    this.blockIndex,
    this.inputIndex,
    this.isInputError = false,
  });

  @override
  String toString() =>
      blockIndex == null ? message : '步骤 ${blockIndex! + 1}：$message';
}

/// Validate the entire chain and every input before creating execution records.
Future<void> validateTaskFlow(
  TaskFlowDefinition flow,
  List<FlowRunInput> inputs, {
  required ProviderEntriesState providers,
  required List<Assistant> assistants,
}) async {
  if (flow.blocks.isEmpty) {
    throw TaskFlowValidationException('任务流没有步骤，请先添加功能块', flowId: flow.id);
  }
  var previousOutput = flow.inputType;
  for (var i = 0; i < flow.blocks.length; i++) {
    final block = flow.blocks[i];
    final def = block.getDefinition();
    Never fail(String message) => throw TaskFlowValidationException(
          message,
          flowId: flow.id,
          blockId: block.id,
          blockIndex: i,
        );
    if (def == null) fail('功能块已不受支持，请替换此步骤');
    if (!previousOutput.isCompatibleWith(def.inputType)) {
      fail('${i == 0 ? '初始输入' : '上一步输出'}为${previousOutput.label}，'
          '「${def.label}」需要${def.inputType.label}，请修改输入类型或替换此步骤');
    }
    for (final param in def.params) {
      if (param.type == BlockParamType.modelSelector) {
        final selected = resolveProviderModel(
            providers, param.configType, block.params['modelRef']);
        if (selected == null || selected.model.modelId.trim().isEmpty) {
          fail(block.params['modelSelectionRequired'] == true ||
                  block.params.containsKey('modelIndex')
              ? '旧版模型选择需要确认，请在「${def.label}」设置中重新选择模型'
              : '模型未选择、已删除或供应商配置不可用，请在「${def.label}」设置中重新选择模型并检查供应商地址和密钥');
        }
      } else if (param.type == BlockParamType.assistantSelector) {
        final id = block.params[param.key];
        if (id is! String ||
            id.isEmpty ||
            !assistants.any((a) => a.id == id) ||
            id.startsWith('builtin:')) {
          fail('助手未选择或已删除，请在「${def.label}」设置中重新选择助手');
        }
      } else if (param.required &&
          (block.params[param.key]?.toString().trim().isEmpty ?? true)) {
        fail('「${param.label}」为必填项，请在「${def.label}」设置中配置');
      }
    }
    if (block.typeKey == BlockType.catcatch &&
        block.params.containsKey('audioOutput') &&
        block.params['audioOutput'] is! bool) {
      fail('输出类型无效，请在「${def.label}」设置中重新选择');
    }
    previousOutput = def.outputType;
  }
  if (inputs.isEmpty) {
    throw TaskFlowValidationException('请添加运行输入',
        flowId: flow.id, isInputError: true);
  }
  final firstType = flow.blocks.first.getDefinition()!.inputType;
  final inputType = firstType == IOType.any ? flow.inputType : firstType;
  for (var i = 0; i < inputs.length; i++) {
    final text = inputs[i].text;
    String? error;
    if (text.trim().isEmpty) {
      error = '输入为空，请重新输入或选择文件';
    } else if ([IOType.audio, IOType.image, IOType.video, IOType.file]
        .contains(inputType)) {
      try {
        if (kIsWeb) {
          if ((await WebFileStore.read(text))?.isNotEmpty != true)
            throw const FileSystemException();
        } else {
          final file = await File(text).open();
          try {
            if ((await file.read(1)).isEmpty) throw const FileSystemException();
          } finally {
            await file.close();
          }
        }
      } catch (_) {
        error = '文件不存在、为空或无法读取，请重新选择文件';
      }
    } else if (flow.blocks.first.typeKey == BlockType.catcatch) {
      final uri = Uri.tryParse(text.trim());
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        error = '请输入有效的 HTTP 或 HTTPS 链接';
      }
    }
    if (error != null) {
      throw TaskFlowValidationException('第 ${i + 1} 个输入：$error',
          flowId: flow.id,
          blockId: flow.blocks.first.id,
          blockIndex: 0,
          inputIndex: i,
          isInputError: true);
    }
  }
}
