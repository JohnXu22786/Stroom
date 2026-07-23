import 'package:flutter/material.dart';
import 'io_type.dart';

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

  /// Model selector (references a configured model)
  modelSelector,

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

  const BlockParamDefinition({
    required this.key,
    required this.label,
    this.type = BlockParamType.string,
    this.required = false,
    this.defaultValue,
    this.hintText,
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'type': type.name,
        'required': required,
        if (defaultValue != null) 'defaultValue': defaultValue,
        if (hintText != null) 'hintText': hintText,
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
  final String typeKey;
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
    typeKey: 'ocr',
    label: '文字识别',
    inputType: IOType.image,
    outputType: IOType.text,
    icon: Icons.text_snippet,
    color: Color(0xFF009688),
    params: [
      BlockParamDefinition(
          key: 'saveFolder', label: '保存文件夹', type: BlockParamType.filePath),
    ],
  );

  /// ASR (Speech Recognition): audio → text
  static const asr = BlockTypeDefinition(
    typeKey: 'asr',
    label: '语音识别',
    inputType: IOType.audio,
    outputType: IOType.text,
    icon: Icons.multitrack_audio,
    color: Color(0xFF673AB7),
    params: [
      BlockParamDefinition(
        key: 'modelIndex',
        label: '识别模型',
        type: BlockParamType.number,
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
    typeKey: 'audioSeparation',
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
    typeKey: 'catcatch',
    label: '下载网页资源',
    inputType: IOType.text,
    outputType: IOType.video,
    icon: Icons.language,
    color: Color(0xFF9C27B0),
    params: [
      BlockParamDefinition(
          key: 'videoFolder', label: '视频保存文件夹', type: BlockParamType.filePath),
      BlockParamDefinition(
          key: 'audioFolder', label: '音频保存文件夹', type: BlockParamType.filePath),
    ],
  );

  /// TTS (Text-to-Speech): text → audio
  static const tts = BlockTypeDefinition(
    typeKey: 'tts',
    label: '语音合成',
    inputType: IOType.text,
    outputType: IOType.audio,
    icon: Icons.record_voice_over,
    color: Color(0xFF00BCD4),
    params: [
      BlockParamDefinition(
        key: 'voice',
        label: '语音',
        type: BlockParamType.string,
      ),
      BlockParamDefinition(
        key: 'speed',
        label: '语速',
        type: BlockParamType.number,
        defaultValue: 1.0,
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
  ];

  /// Find a block type by its key.
  static BlockTypeDefinition? findBlockType(String typeKey) {
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
        'typeKey': typeKey,
        'label': label,
        'inputType': inputType.toJson(),
        'outputType': outputType.toJson(),
        'params': params.map((p) => p.toMap()).toList(),
      };

  factory BlockTypeDefinition.fromMap(Map<String, dynamic> map) {
    // For built-in types, return the singleton to preserve icon/color.
    final typeKey = map['typeKey'] as String;
    final existing = findBlockType(typeKey);
    if (existing != null) return existing;

    // Fallback for unknown types (custom/user-defined).
    return BlockTypeDefinition(
      typeKey: typeKey,
      label: map['label'] as String? ?? typeKey,
      inputType: IOType.fromJson(map['inputType'] as String? ?? 'any'),
      outputType: IOType.fromJson(map['outputType'] as String? ?? 'any'),
      icon: Icons.extension,
      color: Colors.grey,
      params: (map['params'] as List?)
              ?.map((p) => BlockParamDefinition.fromMap(
                  Map<String, dynamic>.from(p as Map)))
              .toList() ??
          [],
    );
  }
}
