import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/assistant.dart';
import '../../providers/provider_config.dart';
import '../../services/chat_adapter.dart'
    show availableLlmModels, resolveModelRef;
import '../../services/chat_protocol.dart' show maxAttachmentBytes;
import '../../utils/provider_models.dart';
import '../../utils/web_file_store.dart';
import '../models/block_type_definition.dart';
import '../models/flow_payload.dart';
import '../models/io_type.dart';
import '../models/task_flow_definition.dart';
import '../models/task_flow_execution.dart';
import 'block_executors/chat_executor.dart'
    show flowChatEndpointType, flowChatInputError;

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
  String fallbackChatEndpointType = 'openai',
}) async {
  if (flow.blocks.isEmpty) {
    throw TaskFlowValidationException('任务流没有步骤，请先添加功能块', flowId: flow.id);
  }
  var previousOutput = flow.inputType;
  String? initialChatEndpointType;
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
    if (!def.acceptsInput(previousOutput)) {
      fail(
        '${i == 0 ? '初始输入' : '上一步输出'}为${previousOutput.label}，'
        '「${def.label}」需要${def.inputType.label}，请修改输入类型或替换此步骤',
      );
    }
    for (final param in def.params) {
      if (param.type == BlockParamType.modelSelector) {
        final selected = resolveProviderModel(
          providers,
          param.configType,
          block.params['modelRef'],
        );
        if (selected == null || selected.model.modelId.trim().isEmpty) {
          fail(
            block.params['modelSelectionRequired'] == true ||
                    block.params.containsKey('modelIndex')
                ? '旧版模型选择需要确认，请在「${def.label}」设置中重新选择模型'
                : '模型未选择、已删除或供应商配置不可用，请在「${def.label}」设置中重新选择模型并检查供应商地址和密钥',
          );
        }
      } else if (param.type == BlockParamType.assistantSelector) {
        final id = block.params[param.key];
        if (id is! String ||
            id.isEmpty ||
            !assistants.any((a) => a.id == id) ||
            id.startsWith('builtin:')) {
          fail('助手未选择或已删除，请在「${def.label}」设置中重新选择助手');
        }
        final assistant = assistants.firstWhere(
          (assistant) => assistant.id == id,
        );
        final reference = assistant.modelId ??
            assistant.defaultModelId ??
            assistant.defaultModelName;
        final selected = reference == null || reference.isEmpty
            ? null
            : resolveModelRef(
                models: availableLlmModels(providers),
                modelId: reference,
                providerName:
                    assistant.modelId == null || assistant.modelId!.isEmpty
                        ? assistant.defaultProviderName
                        : null,
                displayName: reference,
              );
        if (reference != null && reference.isNotEmpty && selected == null) {
          fail('助手绑定的模型已删除或供应商配置不可用，请在助手设置中重新选择模型');
        }
        final endpointType = flowChatEndpointType(
          assistant,
          providers,
          fallback: fallbackChatEndpointType,
        );
        final unsupported = flowChatInputError(previousOutput, endpointType);
        // For initial media, defer protocol checks until each input's MIME
        // and path are known so the error points to the exact batch item.
        if (unsupported != null &&
            (i != 0 || !FlowPayload.isFileType(previousOutput))) {
          fail(unsupported);
        }
        if (i == 0) initialChatEndpointType = endpointType;
      } else if (param.required &&
          (block.params[param.key]?.toString().trim().isEmpty ?? true)) {
        fail('「${param.label}」为必填项，请在「${def.label}」设置中配置');
      }
    }
    previousOutput = def.outputType;
  }
  if (inputs.isEmpty) {
    throw TaskFlowValidationException(
      '请添加运行输入',
      flowId: flow.id,
      isInputError: true,
    );
  }
  final firstType = flow.blocks.first.getDefinition()!.inputType;
  final inputType = firstType == IOType.any ? flow.inputType : firstType;
  for (var i = 0; i < inputs.length; i++) {
    final text = inputs[i].text;
    String? error;
    void checkFile(List<int> header, int length) {
      final mimeType = flowFileMimeType(
        text,
        headerBytes: header,
        mimeType: inputs[i].mimeType,
      );
      final actualType = flowMimeType(mimeType);
      if (initialChatEndpointType != null &&
          actualType == IOType.image &&
          length > maxFlowImageInputBytes) {
        error = '助手对话图片超过 20 MB，请选择较小图片';
        return;
      }
      if (initialChatEndpointType != null &&
          actualType != IOType.image &&
          length > maxAttachmentBytes) {
        error = '助手对话附件超过 10 MB，请选择较小文件';
        return;
      }
      if (inputType != IOType.file && actualType != inputType) {
        error = '文件实际类型为${actualType.label}，需要${inputType.label}，请重新选择文件';
      } else if (initialChatEndpointType != null) {
        // A generic file may contain audio/video. The attachment pipeline
        // checks the detected MIME and file signature, not only the declared
        // flow input type (which can be IOType.file) or filename.
        error = flowChatInputError(
          actualType,
          initialChatEndpointType,
          mimeType: mimeType,
          headerBytes: header,
        );
      }
    }

    if (text.trim().isEmpty) {
      error = '输入为空，请重新输入或选择文件';
    } else if ([
      IOType.audio,
      IOType.image,
      IOType.video,
      IOType.file,
    ].contains(inputType)) {
      try {
        if (kIsWeb) {
          final bytes = await WebFileStore.read(text);
          if (bytes?.isNotEmpty != true) throw const FileSystemException();
          checkFile(bytes!, bytes.length);
        } else {
          final file = await File(text).open();
          try {
            final header = await file.read(32);
            if (header.isEmpty) throw const FileSystemException();
            checkFile(header, await file.length());
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
      throw TaskFlowValidationException(
        '第 ${i + 1} 个输入：$error',
        flowId: flow.id,
        blockId: flow.blocks.first.id,
        blockIndex: 0,
        inputIndex: i,
        isInputError: true,
      );
    }
  }
}
