import 'dart:convert';
import 'dart:typed_data';

import '../../models/ocr_batch_execution.dart';

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
/// Version 3 retains batch execution settings. Image references, never image
/// bodies or provider credentials, are stored from version 2 onward. Version 1
/// and unversioned snapshots remain readable for migration.
class OcrRetrySnapshot {
  static const currentVersion = 3;
  static const _snapshotFields = {
    'type',
    'version',
    'modelRef',
    'images',
    'modelIndex',
    'instructionContent',
    'instructionIndex',
    'saveFolder',
    'batchMode',
    'perImageConcurrency',
    'requestSizeBudgetBytes',
  };
  static const _modelRefFields = {'configId', 'modelId'};
  static const _imageFields = {'storageRef', 'format', 'name', 'bytes'};

  final int? version;
  final String? configId;
  final String? modelId;
  final int? legacyModelIndex;
  final int? legacyInstructionIndex;
  final String? instructionContent;
  final String saveFolder;
  final OcrBatchMode batchMode;
  final int perImageConcurrency;
  final int requestSizeBudgetBytes;
  final List<OcrRetryImage> images;
  final List<int> imageEntryIndices;
  final bool isLegacy;
  final bool hasInvalidImages;
  final bool hasInvalidImageMetadata;
  final bool hasInlineImageData;
  final bool hasUnknownFields;
  final int imageEntryCount;

  const OcrRetrySnapshot._({
    required this.version,
    required this.configId,
    required this.modelId,
    required this.legacyModelIndex,
    required this.legacyInstructionIndex,
    required this.instructionContent,
    required this.saveFolder,
    required this.batchMode,
    required this.perImageConcurrency,
    required this.requestSizeBudgetBytes,
    required this.images,
    required this.imageEntryIndices,
    required this.isLegacy,
    required this.hasInvalidImages,
    required this.hasInvalidImageMetadata,
    required this.hasInlineImageData,
    required this.hasUnknownFields,
    required this.imageEntryCount,
  });

  factory OcrRetrySnapshot.capture({
    String? configId,
    String? modelId,
    required List<OcrRetryImage> images,
    String? instructionContent,
    String saveFolder = '',
    OcrBatchMode batchMode = OcrBatchMode.joint,
    int perImageConcurrency = 1,
    int requestSizeBudgetBytes = defaultOcrRequestSizeBudgetBytes,
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
        batchMode: batchMode,
        perImageConcurrency: perImageConcurrency.clamp(1, 2).toInt(),
        requestSizeBudgetBytes: requestSizeBudgetBytes > 0
            ? requestSizeBudgetBytes
            : defaultOcrRequestSizeBudgetBytes,
        images: List.unmodifiable(images),
        imageEntryIndices: List.unmodifiable(
          List<int>.generate(images.length, (index) => index),
        ),
        isLegacy: false,
        hasInvalidImages: false,
        hasInvalidImageMetadata: false,
        hasInlineImageData: images.any((image) => image.bytes != null),
        hasUnknownFields: false,
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
    var hasUnknownFields = map.keys.any(
      (key) => key is! String || !_snapshotFields.contains(key),
    );
    if ((version == currentVersion && !map.containsKey('type')) ||
        (map.containsKey('type') && map['type'] != 'ocr') ||
        (map.containsKey('modelRef') && rawModelRef is! Map) ||
        (map.containsKey('modelIndex') &&
            map['modelIndex'] != null &&
            map['modelIndex'] is! int) ||
        (map.containsKey('instructionIndex') &&
            map['instructionIndex'] != null &&
            map['instructionIndex'] is! int) ||
        (map.containsKey('instructionContent') &&
            map['instructionContent'] != null &&
            map['instructionContent'] is! String) ||
        (map.containsKey('saveFolder') &&
            map['saveFolder'] != null &&
            map['saveFolder'] is! String)) {
      hasUnknownFields = true;
    }
    final rawBatchMode = map['batchMode'];
    final batchMode = switch (rawBatchMode) {
      'perImage' => OcrBatchMode.perImage,
      'joint' || null => OcrBatchMode.joint,
      _ => OcrBatchMode.joint,
    };
    if (rawBatchMode != null &&
        rawBatchMode != OcrBatchMode.joint.name &&
        rawBatchMode != OcrBatchMode.perImage.name) {
      hasUnknownFields = true;
    }
    final rawPerImageConcurrency = map['perImageConcurrency'];
    final perImageConcurrency =
        rawPerImageConcurrency is int && rawPerImageConcurrency >= 1
        ? rawPerImageConcurrency.clamp(1, 2).toInt()
        : 1;
    if (rawPerImageConcurrency != null &&
        (rawPerImageConcurrency is! int ||
            rawPerImageConcurrency < 1 ||
            rawPerImageConcurrency > 2)) {
      hasUnknownFields = true;
    }
    final rawRequestSizeBudgetBytes = map['requestSizeBudgetBytes'];
    final requestSizeBudgetBytes =
        rawRequestSizeBudgetBytes is int && rawRequestSizeBudgetBytes > 0
        ? rawRequestSizeBudgetBytes
        : defaultOcrRequestSizeBudgetBytes;
    if (rawRequestSizeBudgetBytes != null &&
        (rawRequestSizeBudgetBytes is! int || rawRequestSizeBudgetBytes <= 0)) {
      hasUnknownFields = true;
    }
    if (version == currentVersion &&
        (!map.containsKey('batchMode') ||
            !map.containsKey('perImageConcurrency') ||
            !map.containsKey('requestSizeBudgetBytes'))) {
      hasUnknownFields = true;
    }
    if (rawModelRef is Map) {
      hasUnknownFields |= rawModelRef.keys.any(
        (key) => key is! String || !_modelRefFields.contains(key),
      );
      for (final field in _modelRefFields) {
        final value = rawModelRef[field];
        if (value != null && _nonEmptyString(value) == null) {
          hasUnknownFields = true;
        }
      }
    }
    final configId = _nonEmptyString(modelRef['configId']);
    final modelId = _nonEmptyString(modelRef['modelId']);
    final rawImages = map['images'];
    final images = <OcrRetryImage>[];
    final imageEntryIndices = <int>[];
    var hasInvalidImages = false;
    var hasInvalidImageMetadata = false;
    var hasInlineImageData = false;
    final imageEntryCount = rawImages is List ? rawImages.length : 0;
    if (rawImages is List) {
      for (var index = 0; index < rawImages.length; index++) {
        final rawImage = rawImages[index];
        if (rawImage is! Map) {
          hasInvalidImages = true;
          continue;
        }
        try {
          final imageMap = Map<String, dynamic>.from(rawImage);
          hasUnknownFields |= imageMap.keys.any(
            (key) => !_imageFields.contains(key),
          );
          hasInlineImageData |= imageMap.containsKey('bytes');
          hasInvalidImageMetadata |=
              imageMap['format'] is! String ||
              (imageMap['name'] != null && imageMap['name'] is! String);
          images.add(OcrRetryImage.fromMap(imageMap));
          imageEntryIndices.add(index);
        } catch (_) {
          hasInvalidImages = true;
        }
      }
    } else if (map.containsKey('images')) {
      hasInvalidImages = true;
    }

    final supportedVersion =
        isLegacy || version == 1 || version == 2 || version == 3;
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
      saveFolder: map['saveFolder'] is String
          ? map['saveFolder'] as String
          : '',
      batchMode: batchMode,
      perImageConcurrency: perImageConcurrency,
      requestSizeBudgetBytes: requestSizeBudgetBytes,
      images: List.unmodifiable(images),
      imageEntryIndices: List.unmodifiable(imageEntryIndices),
      isLegacy: isLegacy,
      hasInvalidImages: hasInvalidImages,
      hasInvalidImageMetadata: hasInvalidImageMetadata,
      hasInlineImageData: hasInlineImageData,
      hasUnknownFields: hasUnknownFields,
      imageEntryCount: imageEntryCount,
    );
  }

  bool get needsMigration =>
      version != currentVersion ||
      hasInvalidImages ||
      hasInvalidImageMetadata ||
      hasInlineImageData ||
      hasUnknownFields ||
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
      'batchMode': batchMode.name,
      'perImageConcurrency': perImageConcurrency,
      'requestSizeBudgetBytes': requestSizeBudgetBytes,
    };
  }

  static String? _nonEmptyString(dynamic value) =>
      value is String && value.isNotEmpty ? value : null;
}
