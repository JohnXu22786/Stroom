/// Defines the input/output data types for task flow blocks.
///
/// Each [BlockTypeDefinition] declares what type of data it accepts
/// and what type it produces. This enables compile-time-like validation
/// when users connect blocks in a custom flow — incompatible types
/// cannot be connected.
enum IOType {
  /// Plain text (e.g., OCR output, ASR output, TTS input)
  text,

  /// Audio file/data (e.g., ASR input, TTS output, AudioSeparation output)
  audio,

  /// Video file/data (e.g., AudioSeparation input, CatCatch output)
  video,

  /// Image file/data (e.g., OCR input)
  image,

  /// Web URL (e.g., CatCatch input)
  url,

  /// Generic file
  file,

  /// Compatible with any type (used for flexible blocks or passthrough)
  any;

  /// Returns true if [other] can be used as input when this type is output.
  ///
  /// The rule: `this` is an output type, [other] is the next block's input type.
  /// They are compatible if they are the same type, or either is [any].
  /// URL is treated as text (can feed into text-input blocks, and vice versa).
  bool isCompatibleWith(IOType other) {
    if (this == any || other == any) return true;
    if (this == url && other == text) return true;
    if (this == text && other == url) return true;
    return this == other;
  }

  /// Human-readable Chinese label for this type.
  String get label {
    switch (this) {
      case IOType.text:
        return '文本';
      case IOType.audio:
        return '音频';
      case IOType.video:
        return '视频';
      case IOType.image:
        return '图片';
      case IOType.url:
        return '链接';
      case IOType.file:
        return '文件';
      case IOType.any:
        return '任意';
    }
  }

  /// Serialize to string for JSON storage.
  String toJson() => name;

  /// Deserialize from string.
  static IOType fromJson(String value) =>
      IOType.values.firstWhere((e) => e.name == value, orElse: () => IOType.any);
}
