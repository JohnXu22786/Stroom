import '../../l10n/app_localizations.dart';
import '../models/block_type_definition.dart';
import '../models/io_type.dart';
import '../models/task_flow_chain_editor.dart';
import '../models/task_flow_definition.dart';

String localizedIoTypeLabel(IOType type, AppLocalizations strings) =>
    switch (type) {
      IOType.text => strings.taskFlowIoTypeText,
      IOType.audio => strings.taskFlowIoTypeAudio,
      IOType.video => strings.taskFlowIoTypeVideo,
      IOType.image => strings.taskFlowIoTypeImage,
      IOType.url => strings.taskFlowIoTypeLink,
      IOType.file => strings.taskFlowIoTypeFile,
      IOType.any => strings.taskFlowIoTypeAny,
    };

String localizedIoTypeDisplayLabel(String label, AppLocalizations strings) =>
    switch (label) {
      '文本' => strings.taskFlowIoTypeText,
      '音频' => strings.taskFlowIoTypeAudio,
      '视频' => strings.taskFlowIoTypeVideo,
      '图片' => strings.taskFlowIoTypeImage,
      '链接' => strings.taskFlowIoTypeLink,
      '文件' => strings.taskFlowIoTypeFile,
      '任意' => strings.taskFlowIoTypeAny,
      '未知' => strings.taskFlowOutputUnknown,
      _ => label,
    };

String localizedBlockTypeLabel(
  BlockTypeDefinition definition,
  AppLocalizations strings,
) => definition.typeKey == BlockType.custom
    ? definition.label
    : localizedBlockTypeName(definition.typeKey, strings);

String localizedBlockTypeName(BlockType type, AppLocalizations strings) =>
    switch (type) {
      BlockType.ocr => strings.taskFlowBlockOcr,
      BlockType.asr => strings.taskFlowBlockAsr,
      BlockType.audioSeparation => strings.taskFlowBlockAudioSeparation,
      BlockType.catcatch => strings.taskFlowBlockCatCatch,
      BlockType.tts => strings.taskFlowBlockTts,
      BlockType.chat => strings.taskFlowBlockChat,
      BlockType.custom => strings.taskFlowBlockCustom,
    };

String localizedBlockParamLabel(
  BlockTypeDefinition definition,
  BlockParamDefinition parameter,
  AppLocalizations strings,
) {
  if (definition.typeKey == BlockType.custom) return parameter.label;
  return switch (parameter.key) {
    'modelRef' =>
      definition.typeKey == BlockType.tts
          ? strings.taskFlowParamSynthesisModel
          : strings.taskFlowParamRecognitionModel,
    'saveFolder' => strings.taskFlowParamSaveFolder,
    'resourceSelectionPolicy' => strings.taskFlowParamResourceSelection,
    'outputPolicy' => strings.taskFlowParamOutputType,
    'videoFolder' => strings.taskFlowParamVideoFolder,
    'audioFolder' => strings.taskFlowParamAudioFolder,
    'durationSec' => strings.taskFlowParamExpectedDuration,
    'voice' => strings.taskFlowParamVoice,
    'speed' => strings.taskFlowParamSpeechRate,
    'assistantId' => strings.taskFlowParamAssistant,
    _ => parameter.label,
  };
}

String? localizedBlockParamHint(
  BlockTypeDefinition definition,
  BlockParamDefinition parameter,
  AppLocalizations strings,
) {
  if (definition.typeKey == BlockType.custom) return parameter.hintText;
  return switch (parameter.key) {
    'resourceSelectionPolicy' => strings.taskFlowHintResourceSelection,
    'outputPolicy' => strings.taskFlowHintOutputType,
    'durationSec' => strings.taskFlowHintExpectedDuration,
    'voice' => strings.taskFlowHintVoice,
    _ => parameter.hintText,
  };
}

String localizedChainIssueMessage(
  TaskFlowChainIssue issue,
  List<TaskFlowBlock> blocks,
  IOType inputType,
  AppLocalizations strings,
) {
  if (issue.blockIndex < 0 || issue.blockIndex >= blocks.length) {
    return strings.taskFlowUiUnsupportedBlockStep;
  }
  final block = blocks[issue.blockIndex];
  final definition = block.getDefinition();
  if (definition == null) return strings.taskFlowUiUnsupportedBlockStep;

  final previous = issue.blockIndex == 0 ? null : blocks[issue.blockIndex - 1];
  final requiredType = localizedIoTypeLabel(definition.inputType, strings);
  if (issue.message.startsWith('下游需要')) {
    return strings.taskFlowUiDownstreamTypeMismatch(requiredType);
  }

  final outputs = previous?.possibleOutputTypes ?? [inputType];
  final source = issue.blockIndex == 0
      ? strings.taskFlowUiInitialInput
      : strings.taskFlowUiPreviousOutput;
  final blockLabel = localizedBlockTypeLabel(definition, strings);
  final anyOutput = outputs.length == 1 && outputs.single == IOType.any;
  if (block.typeKey == BlockType.chat && anyOutput) {
    return strings.taskFlowUiAnyTypeMismatch(source, blockLabel);
  }
  return strings.taskFlowUiTypeMismatch(
    source,
    outputs.map((type) => localizedIoTypeLabel(type, strings)).join(', '),
    blockLabel,
    requiredType,
  );
}
