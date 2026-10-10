import 'dart:convert';
import 'dart:typed_data';

/// One source image captured for a standalone OCR retry.
class OcrRetryImage {
  final Uint8List bytes;
  final String format;
  final String? name;

  const OcrRetryImage({required this.bytes, required this.format, this.name});

  Map<String, dynamic> toMap() => {
        'bytes': base64Encode(bytes),
        'format': format,
        'name': name,
      };

  factory OcrRetryImage.fromMap(Map<String, dynamic> map) {
    final encoded = map['bytes'];
    if (encoded is! String) {
      throw const FormatException('OCR retry image is missing its bytes');
    }
    return OcrRetryImage(
      bytes: base64Decode(encoded),
      format: map['format'] as String? ?? 'jpeg',
      name: map['name'] as String?,
    );
  }
}

/// Versioned, OCR-only retry inputs.
///
/// The versioned format stores local model references and page inputs, never
/// provider credentials. Maps without a version are the legacy index-based
/// shape and remain readable so the page can ask for model confirmation.
class OcrRetrySnapshot {
  static const currentVersion = 1;

  final int? version;
  final String? configId;
  final String? modelId;
  final int? legacyModelIndex;
  final int? legacyInstructionIndex;
  final String? instructionContent;
  final String saveFolder;
  final List<OcrRetryImage> images;
  final bool isLegacy;

  const OcrRetrySnapshot._({
    required this.version,
    required this.configId,
    required this.modelId,
    required this.legacyModelIndex,
    required this.legacyInstructionIndex,
    required this.instructionContent,
    required this.saveFolder,
    required this.images,
    required this.isLegacy,
  });

  factory OcrRetrySnapshot.capture({
    required String configId,
    required String modelId,
    required List<OcrRetryImage> images,
    String? instructionContent,
    String saveFolder = '',
  }) =>
      OcrRetrySnapshot._(
        version: currentVersion,
        configId: configId,
        modelId: modelId,
        legacyModelIndex: null,
        legacyInstructionIndex: null,
        instructionContent: instructionContent,
        saveFolder: saveFolder,
        images: List.unmodifiable(images),
        isLegacy: false,
      );

  factory OcrRetrySnapshot.fromMap(Map<String, dynamic> map) {
    final rawVersion = map['version'];
    final isLegacy = !map.containsKey('version');
    final version = rawVersion is int ? rawVersion : null;
    final rawModelRef = map['modelRef'];
    final modelRef = rawModelRef is Map
        ? Map<String, dynamic>.from(rawModelRef)
        : const <String, dynamic>{};
    final rawImages = map['images'];
    final images = <OcrRetryImage>[];
    if (rawImages is List) {
      for (final rawImage in rawImages) {
        if (rawImage is! Map) continue;
        try {
          images.add(
            OcrRetryImage.fromMap(Map<String, dynamic>.from(rawImage)),
          );
        } catch (_) {
          // Keep valid images in their original order when one old entry is
          // damaged or incomplete, matching the previous retry behavior.
        }
      }
    }

    return OcrRetrySnapshot._(
      version: version,
      configId: _nonEmptyString(modelRef['configId']),
      modelId: _nonEmptyString(modelRef['modelId']),
      legacyModelIndex: isLegacy && map['modelIndex'] is int
          ? map['modelIndex'] as int
          : null,
      legacyInstructionIndex: isLegacy && map['instructionIndex'] is int
          ? map['instructionIndex'] as int
          : null,
      instructionContent: map['instructionContent'] is String
          ? map['instructionContent'] as String
          : null,
      saveFolder:
          map['saveFolder'] is String ? map['saveFolder'] as String : '',
      images: List.unmodifiable(images),
      isLegacy: isLegacy,
    );
  }

  Map<String, dynamic> toMap() {
    if (version != currentVersion || isLegacy) {
      throw StateError('Only the current OCR retry format can be serialized');
    }
    return {
      'type': 'ocr',
      'version': currentVersion,
      'modelRef': {'configId': configId, 'modelId': modelId},
      'images': images.map((image) => image.toMap()).toList(),
      if (instructionContent != null) 'instructionContent': instructionContent,
      'saveFolder': saveFolder,
    };
  }

  static String? _nonEmptyString(dynamic value) =>
      value is String && value.isNotEmpty ? value : null;
}
