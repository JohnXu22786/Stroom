import 'package:flutter/material.dart';
import 'io_type.dart';

// ============================================================================
// Block type enum
// ============================================================================

enum BlockType { catcatch, audioSeparation, asr, ocr, tts, chat, custom }

BlockType parseBlockType(String name) {
  return BlockType.values.firstWhere(
    (e) => e.name == name,
    orElse: () => BlockType.custom,
  );
}

// ============================================================================
// Parameter type for block configuration
// ============================================================================

/// The data type of a block parameter.
enum BlockParamType {
  /// Plain text string
  string,

  /// Numeric value
  number,

  /// Boolean toggle
  boolean,

  /// File/folder path selector
  filePath,

  /// Model selector (references a configured model of [configType],
  /// e.g. 'asr' — the executor indexes the same flattened list).
  modelSelector,

  /// Voice selector (dropdown of the voices of the configured TTS model).
  voiceSelector,

  /// Assistant selector (dropdown of user-defined assistants from
  /// [assistantProvider]; empty = the currently selected assistant).
  assistantSelector,

  /// API key / secret
  secret,
}

// ============================================================================
// Parameter definition
// ============================================================================

/// Defines a single configurable parameter for a block type.
///
/// This is the *schema* — the definition of what parameters a block
/// accepts. Actual values are stored in [TaskFlowBlock.params].
class BlockParamDefinition {
  final String key;
  final String label;
  final BlockParamType type;
  final bool required;
  final dynamic defaultValue;
  final String? hintText;

  /// Provider type ('asr', 'ocr', 'tts', 'llm', ...) whose configs the
  /// [modelSelector] dropdown lists. Only used by modelSelector.
  final String configType;

  const BlockParamDefinition({
    required this.key,
    required this.label,
    this.type = BlockParamType.string,
    this.required = false,
    this.defaultValue,
    this.hintText,
    this.configType = 'asr',
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'type': type.name,
        'required': required,
        if (defaultValue != null) 'defaultValue': defaultValue,
        if (hintText != null) 'hintText': hintText,
        if (configType != 'asr') 'configType': configType,
      };

  factory BlockParamDefinition.fromMap(Map<String, dynamic> map) =>
      BlockParamDefinition(
        key: map['key'] as String,
        label: map['label'] as String,
        type: BlockParamType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => BlockParamType.string,
        ),
        required: map['required'] as bool? ?? false,
        defaultValue: map['defaultValue'],
        hintText: map['hintText'] as String?,
        configType: map['configType'] as String? ?? 'asr',
      );
}

// ============================================================================
// Block type definition
// ============================================================================

/// Describes a type of functional block that can be used in a task flow.
///
/// Each block type has:
/// - An [inputType] (what data it consumes)
/// - An [outputType] (what data it produces)
/// - A list of [params] that can be configured per-instance
///
/// The [typeKey] must match the [BackgroundTaskType] name for blocks
/// that wrap existing background tasks.
class BlockTypeDefinition {
  final BlockType typeKey;
  final String label;
  final IOType inputType;
  final IOType outputType;
  final IconData icon;
  final Color color;
  final List<BlockParamDefinition> params;

  const BlockTypeDefinition({
    required this.typeKey,
    required this.label,
    required this.inputType,
    required this.outputType,
    required this.icon,
    required this.color,
    this.params = const [],
  });

  // ========================================================================
  // Built-in block types
  // ========================================================================

  /// OCR: image → text
  static const ocr = BlockTypeDefinition(
    typeKey: BlockType.ocr,
    label: '文字识别',
    inputType: IOType.image,
    outputType: IOType.text,
    icon: Icons.text_snippet,
    color: Color(0xFF009688),
    params: [
      BlockParamDefinition(
        key: 'saveFolder',
        label: '保存文件夹',
        type: BlockParamType.filePath,
      ),
    ],
  );

  /// ASR (Speech Recognition): audio → text
  static const asr = BlockTypeDefinition(
    typeKey: BlockType.asr,
    label: '语音识别',
    inputType: IOType.audio,
    outputType: IOType.text,
    icon: Icons.multitrack_audio,
    color: Color(0xFF673AB7),
    params: [
      BlockParamDefinition(
        key: 'modelIndex',
        label: '识别模型',
        type: BlockParamType.modelSelector,
        defaultValue: 0,
      ),
      BlockParamDefinition(
        key: 'saveFolder',
        label: '保存文件夹',
        type: BlockParamType.filePath,
      ),
    ],
  );

  /// AudioSeparation: video → audio
  static const audioSeparation = BlockTypeDefinition(
    typeKey: BlockType.audioSeparation,
    label: '音频分离',
    inputType: IOType.video,
    outputType: IOType.audio,
    icon: Icons.music_note,
    color: Color(0xFF3F51B5),
    params: [
      BlockParamDefinition(
        key: 'saveFolder',
        label: '保存文件夹',
        type: BlockParamType.filePath,
      ),
    ],
  );

  /// CatCatch (Web Resource Download): text → video
  static const catcatch = BlockTypeDefinition(
    typeKey: BlockType.catcatch,
    label: '下载网页资源',
    inputType: IOType.text,
    outputType: IOType.video,
    icon: Icons.language,
    color: Color(0xFF9C27B0),
    params: [
      BlockParamDefinition(
        key: 'videoFolder',
        label: '视频保存文件夹',
        type: BlockParamType.filePath,
      ),
      BlockParamDefinition(
        key: 'audioFolder',
        label: '音频保存文件夹',
        type: BlockParamType.filePath,
      ),
      BlockParamDefinition(
        key: 'durationSec',
        label: '预期时长(秒)',
        type: BlockParamType.number,
        defaultValue: 0,
        hintText: '0 表示不筛选时长',
      ),
    ],
  );

  /// TTS (Text-to-Speech): text → audio
  static const tts = BlockTypeDefinition(
    typeKey: BlockType.tts,
    label: '语音合成',
    inputType: IOType.text,
    outputType: IOType.audio,
    icon: Icons.record_voice_over,
    color: Color(0xFF00BCD4),
    params: [
      BlockParamDefinition(
        key: 'voice',
        label: '语音',
        type: BlockParamType.voiceSelector,
        hintText: '选择配置的TTS模型音色',
      ),
      BlockParamDefinition(
        key: 'speed',
        label: '语速',
        type: BlockParamType.number,
        defaultValue: 1.0,
      ),
      BlockParamDefinition(
        key: 'saveFolder',
        label: '保存文件夹',
        type: BlockParamType.filePath,
      ),
    ],
  );

  /// Chat (Assistant Conversation): any → text
  ///
  /// Sends the input text (the previous block's output) to the selected
  /// assistant and returns the response. Accepts any input type —
  /// whatever can be typed into the chat page (text, URLs, file
  /// references) can be the input.
  static const chat = BlockTypeDefinition(
    typeKey: BlockType.chat,
    label: '助手对话',
    inputType: IOType.any,
    outputType: IOType.text,
    icon: Icons.chat_bubble_outline,
    color: Color(0xFF2196F3),
    params: [
      BlockParamDefinition(
        key: 'assistantId',
        label: '助手',
        type: BlockParamType.assistantSelector,
        // Default: the first built-in assistant, so a new chat block
        // always has an explicit assistant.
        defaultValue: 'builtin:prompt_0',
      ),
      BlockParamDefinition(
        key: 'promptPrefix',
        label: '开头提示语',
        type: BlockParamType.string,
        hintText: '发送上一步的输出之前，先加上这段话（可选）',
      ),
    ],
  );

  /// All registered block types.
  static const List<BlockTypeDefinition> all = [
    ocr,
    asr,
    audioSeparation,
    catcatch,
    tts,
    chat,
  ];

  /// Find a block type by its key.
  static BlockTypeDefinition? findBlockType(BlockType typeKey) {
    for (final b in all) {
      if (b.typeKey == typeKey) return b;
    }
    return null;
  }

  /// Get block types whose input type is compatible with [outputType].
  /// This is used for showing compatible next blocks in the flow builder.
  static List<BlockTypeDefinition> getCompatibleNextBlocks(IOType outputType) {
    return all.where((b) => outputType.isCompatibleWith(b.inputType)).toList();
  }

  /// Get block types that can REPLACE a block at a chain position without
  /// breaking the chain.
  ///
  /// A candidate is valid when it accepts what the previous step produces
  /// ([prevOutput] — the flow's initial input type for the first block)
  /// and what it produces is accepted by the next block's input
  /// ([nextInput]; null for the last block). This subsumes same-I/O swaps
  /// (identical input/output pairs are trivially valid).
  ///
  /// [exclude] removes the current block type from the list — replacing a
  /// block with its own type would just reset its parameters.
  static List<BlockTypeDefinition> getReplacementCandidates({
    required IOType prevOutput,
    IOType? nextInput,
    BlockType? exclude,
  }) {
    return all.where((b) {
      if (b.typeKey == exclude) return false;
      if (!prevOutput.isCompatibleWith(b.inputType)) return false;
      if (nextInput != null && !b.outputType.isCompatibleWith(nextInput)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Get the default parameter values for this block type.
  Map<String, dynamic> get defaultParams {
    final map = <String, dynamic>{};
    for (final p in params) {
      if (p.defaultValue != null) {
        map[p.key] = p.defaultValue;
      } else if (p.type == BlockParamType.filePath) {
        map[p.key] = '';
      } else if (p.type == BlockParamType.number) {
        map[p.key] = 0;
      } else if (p.type == BlockParamType.boolean) {
        map[p.key] = false;
      } else {
        map[p.key] = '';
      }
    }
    return map;
  }

  // ========================================================================
  // Serialization
  // ========================================================================

  Map<String, dynamic> toMap() => {
        'typeKey': typeKey.name,
        'label': label,
        'inputType': inputType.toJson(),
        'outputType': outputType.toJson(),
        'params': params.map((p) => p.toMap()).toList(),
      };

  factory BlockTypeDefinition.fromMap(Map<String, dynamic> map) {
    final typeKey = parseBlockType(map['typeKey'] as String);
    final existing = findBlockType(typeKey);
    if (existing != null) return existing;

    return BlockTypeDefinition(
      typeKey: typeKey,
      label: map['label'] as String? ?? typeKey.name,
      inputType: IOType.fromJson(map['inputType'] as String? ?? 'any'),
      outputType: IOType.fromJson(map['outputType'] as String? ?? 'any'),
      icon: Icons.extension,
      color: Colors.grey,
      params: (map['params'] as List?)
              ?.map(
                (p) => BlockParamDefinition.fromMap(
                  Map<String, dynamic>.from(p as Map),
                ),
              )
              .toList() ??
          [],
    );
  }
}
