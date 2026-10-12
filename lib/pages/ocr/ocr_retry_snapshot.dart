import 'dart:convert';
import 'dart:typed_data';

/// One source image captured for a standalone OCR retry.
///
/// New snapshots keep a storage reference. [bytes] is populated only while
/// reading legacy inline snapshots or before the image is written to storage.
class OcrRetryImage {
  static final RegExp _storageReferencePattern = RegExp(
    r'^ocr_retry_cache/[0-9a-f]{64}\.bin$',
  );

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
    if (ref == null || !isValidStorageReference(ref) || bytes != null) {
      throw StateError('OCR retry images must be cached before serialization');
    }
    return {'storageRef': ref, 'format': format, 'name': name};
  }

  static bool isValidStorageReference(String reference) =>
      _storageReferencePattern.hasMatch(reference);

  /// Infers a format hint from encoded bytes; OCR preparation still validates.
  static String? inferFormatFromBytes(Uint8List bytes) {
    bool startsWith(List<int> signature) {
      if (bytes.length < signature.length) return false;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[index] != signature[index]) return false;
      }
      return true;
    }

    if (startsWith(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
      return 'png';
    }
    if (startsWith(const [0xff, 0xd8, 0xff])) return 'jpeg';
    if (startsWith(ascii.encode('GIF87a')) ||
        startsWith(ascii.encode('GIF89a'))) {
      return 'gif';
    }
    if (bytes.length >= 12 &&
        startsWith(ascii.encode('RIFF')) &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return null;
  }

  factory OcrRetryImage.fromMap(Map<String, dynamic> map) {
    final encoded = map['bytes'];
    final storageRef = map['storageRef'];
    final format = map['format'];
    final name = map['name'];
    // Unknown metadata stays unknown instead of mislabeling image bytes.
    final safeFormat = format is String ? format : '';
    final safeName = name is String ? name : null;
    final hasValidStorageRef =
        storageRef is String && isValidStorageReference(storageRef);
    if (encoded is String) {
      try {
        final bytes = base64Decode(encoded);
        if (bytes.isNotEmpty) {
          return OcrRetryImage(
            bytes: bytes,
            format: inferFormatFromBytes(bytes) ?? safeFormat,
            name: safeName,
          );
        }
        if (!hasValidStorageRef) {
          throw const FormatException('OCR retry image body is empty');
        }
      } on FormatException {
        if (!hasValidStorageRef) rethrow;
      }
    }
    if (hasValidStorageRef) {
      return OcrRetryImage.reference(
        storageRef: storageRef,
        format: safeFormat,
        name: safeName,
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
  final bool hasInvalidImageMetadata;
  final bool hasInlineImageData;
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
    required this.hasInvalidImageMetadata,
    required this.hasInlineImageData,
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
  }) =>
      OcrRetrySnapshot._(
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
        hasInvalidImageMetadata: false,
        hasInlineImageData: images.any((image) => image.bytes != null),
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
    var hasInvalidImageMetadata = false;
    var hasInlineImageData = false;
    final imageEntryCount = rawImages is List ? rawImages.length : 0;
    if (rawImages is List) {
      for (final rawImage in rawImages) {
        if (rawImage is! Map) {
          hasInvalidImages = true;
          continue;
        }
        try {
          final imageMap = Map<String, dynamic>.from(rawImage);
          hasInlineImageData |= imageMap.containsKey('bytes');
          hasInvalidImageMetadata |= imageMap['format'] is! String ||
              (imageMap['name'] != null && imageMap['name'] is! String);
          images.add(OcrRetryImage.fromMap(imageMap));
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
      legacyModelIndex:
          supportedVersion && !hasStableModelRef && map['modelIndex'] is int
              ? map['modelIndex'] as int
              : null,
      legacyInstructionIndex: supportedVersion && map['instructionIndex'] is int
          ? map['instructionIndex'] as int
          : null,
      instructionContent: map['instructionContent'] is String
          ? map['instructionContent'] as String
          : null,
      saveFolder:
          map['saveFolder'] is String ? map['saveFolder'] as String : '',
      images: List.unmodifiable(images),
      isLegacy: isLegacy,
      hasInvalidImages: hasInvalidImages,
      hasInvalidImageMetadata: hasInvalidImageMetadata,
      hasInlineImageData: hasInlineImageData,
      imageEntryCount: imageEntryCount,
    );
  }

  bool get needsMigration =>
      version != currentVersion ||
      hasInvalidImages ||
      hasInvalidImageMetadata ||
      hasInlineImageData ||
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
