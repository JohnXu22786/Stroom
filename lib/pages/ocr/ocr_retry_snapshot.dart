import 'dart:convert';
import 'dart:typed_data';

/// One source image captured for a standalone OCR retry.
///
/// New snapshots keep a storage reference. [bytes] is populated only while
/// reading legacy inline snapshots or before the image is written to storage.
class OcrRetryImage {
  final Uint8List? bytes;
  final String? storageRef;
  final String format;
  final String? name;

  const OcrRetryImage({
    this.bytes,
    this.storageRef,
    required this.format,
    this.name,
  });

  const OcrRetryImage.reference({
    required this.storageRef,
    required this.format,
    this.name,
  }) : bytes = null;

  Map<String, dynamic> toMap() {
    final ref = storageRef;
    if (ref == null || bytes != null) {
      throw StateError('OCR retry images must be cached before serialization');
    }
    return {'storageRef': ref, 'format': format, 'name': name};
  }

  factory OcrRetryImage.fromMap(Map<String, dynamic> map) {
    final encoded = map['bytes'];
    final storageRef = map['storageRef'];
    if (encoded is String && storageRef == null) {
      return OcrRetryImage(
        bytes: base64Decode(encoded),
        format: map['format'] as String? ?? 'jpeg',
        name: map['name'] as String?,
      );
    }
    if (storageRef is String && storageRef.isNotEmpty && encoded == null) {
      return OcrRetryImage.reference(
        storageRef: storageRef,
        format: map['format'] as String? ?? 'jpeg',
        name: map['name'] as String?,
      );
    }
    throw const FormatException(
      'OCR retry image has no valid bytes or cache reference',
    );
  }
}

/// Versioned, OCR-only retry inputs.
///
/// Version 2 stores image references, never image bodies or provider
/// credentials. Version 1 and unversioned snapshots remain readable so
/// existing retry tasks can be opened and migrated after their images have
/// been copied to app storage.
class OcrRetrySnapshot {
  static const currentVersion = 2;

  final int? version;
  final String? configId;
  final String? modelId;
  final int? legacyModelIndex;
  final int? legacyInstructionIndex;
  final String? instructionContent;
  final String saveFolder;
  final List<OcrRetryImage> images;
  final bool isLegacy;
  final bool hasInvalidImages;
  final int imageEntryCount;

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
    required this.hasInvalidImages,
    required this.imageEntryCount,
  });

  factory OcrRetrySnapshot.capture({
    String? configId,
    String? modelId,
    required List<OcrRetryImage> images,
    String? instructionContent,
    String saveFolder = '',
    int? legacyModelIndex,
    int? legacyInstructionIndex,
  }) => OcrRetrySnapshot._(
    version: currentVersion,
    configId: configId,
    modelId: modelId,
    legacyModelIndex: legacyModelIndex,
    legacyInstructionIndex: legacyInstructionIndex,
    instructionContent: instructionContent,
    saveFolder: saveFolder,
    images: List.unmodifiable(images),
    isLegacy: false,
    hasInvalidImages: false,
    imageEntryCount: images.length,
  );

  factory OcrRetrySnapshot.fromMap(Map<String, dynamic> map) {
    final rawVersion = map['version'];
    final isLegacy = !map.containsKey('version');
    final version = rawVersion is int ? rawVersion : null;
    final rawModelRef = map['modelRef'];
    final modelRef = rawModelRef is Map
        ? Map<String, dynamic>.from(rawModelRef)
        : const <String, dynamic>{};
    final configId = _nonEmptyString(modelRef['configId']);
    final modelId = _nonEmptyString(modelRef['modelId']);
    final rawImages = map['images'];
    final images = <OcrRetryImage>[];
    var hasInvalidImages = false;
    final imageEntryCount = rawImages is List ? rawImages.length : 0;
    if (rawImages is List) {
      for (final rawImage in rawImages) {
        if (rawImage is! Map) {
          hasInvalidImages = true;
          continue;
        }
        try {
          images.add(
            OcrRetryImage.fromMap(Map<String, dynamic>.from(rawImage)),
          );
        } catch (_) {
          hasInvalidImages = true;
        }
      }
    } else if (map.containsKey('images')) {
      hasInvalidImages = true;
    }

    final supportedVersion = isLegacy || version == 1 || version == 2;
    if (!supportedVersion) hasInvalidImages = true;
    final hasStableModelRef = configId != null && modelId != null;

    return OcrRetrySnapshot._(
      version: version,
      configId: configId,
      modelId: modelId,
      legacyModelIndex: !hasStableModelRef && map['modelIndex'] is int
          ? map['modelIndex'] as int
          : null,
      legacyInstructionIndex: map['instructionIndex'] is int
          ? map['instructionIndex'] as int
          : null,
      instructionContent: map['instructionContent'] is String
          ? map['instructionContent'] as String
          : null,
      saveFolder: map['saveFolder'] is String
          ? map['saveFolder'] as String
          : '',
      images: List.unmodifiable(images),
      isLegacy: isLegacy,
      hasInvalidImages: hasInvalidImages,
      imageEntryCount: imageEntryCount,
    );
  }

  bool get needsMigration =>
      version != currentVersion ||
      images.any((image) => image.storageRef == null);

  Map<String, dynamic> toMap() {
    if (version != currentVersion || isLegacy || hasInvalidImages) {
      throw StateError(
        'Only a valid current OCR retry format can be serialized',
      );
    }
    return {
      'type': 'ocr',
      'version': currentVersion,
      'modelRef': {
        if (configId != null) 'configId': configId,
        if (modelId != null) 'modelId': modelId,
      },
      'images': images.map((image) => image.toMap()).toList(),
      if (legacyModelIndex != null) 'modelIndex': legacyModelIndex,
      if (instructionContent != null) 'instructionContent': instructionContent,
      if (legacyInstructionIndex != null)
        'instructionIndex': legacyInstructionIndex,
      'saveFolder': saveFolder,
    };
  }

  static String? _nonEmptyString(dynamic value) =>
      value is String && value.isNotEmpty ? value : null;
}
