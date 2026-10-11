import 'block_type_definition.dart';
import 'io_type.dart';
import 'task_flow_definition.dart';

/// Templates open as unsaved drafts; users choose their own models and assistant.
class TaskFlowTemplate {
  final String name;
  final String description;
  final String requirements;
  final IOType inputType;
  final List<BlockType> blockTypes;

  const TaskFlowTemplate({
    required this.name,
    required this.description,
    required this.requirements,
    required this.inputType,
    required this.blockTypes,
  });

  TaskFlowDefinition createDraft() => TaskFlowDefinition(
        name: name,
        description: description,
        inputType: inputType,
        blocks: blockTypes.map((type) => TaskFlowBlock(typeKey: type)).toList(),
      );
}

const taskFlowTemplates = [
  TaskFlowTemplate(
    name: '录音转写与总结',
    description: '选择录音 → 语音识别 → 助手总结',
    requirements: '需要配置 ASR 模型，并选择用于总结的助手',
    inputType: IOType.audio,
    blockTypes: [BlockType.asr, BlockType.chat],
  ),
  TaskFlowTemplate(
    name: '图片文字识别与整理',
    description: '选择图片 → 文字识别 → 助手整理',
    requirements: '需要配置 OCR 模型，并选择用于整理的助手',
    inputType: IOType.image,
    blockTypes: [BlockType.ocr, BlockType.chat],
  ),
  TaskFlowTemplate(
    name: '帮我读出图片文字',
    description: '选择图片 → 识别文字 → 语音朗读',
    requirements: '需要配置 OCR 和语音合成模型，并选择音色',
    inputType: IOType.image,
    blockTypes: [BlockType.ocr, BlockType.tts],
  ),
];
