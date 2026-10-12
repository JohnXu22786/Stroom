import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;

import '../models/ocr_batch_execution.dart';
import '../pages/ocr/ocr_retry_snapshot.dart';
import '../utils/atomic_file.dart';
import '../utils/web_file_store.dart';
import 'storage_service.dart';

class OcrRetryRestoreResult {
  final List<OcrRetryImage> images;
  final int missingImageCount;

  const OcrRetryRestoreResult({
    required this.images,
    required this.missingImageCount,
  });

  bool get isComplete => missingImageCount == 0 && images.isNotEmpty;
}

/// Stores OCR retry inputs outside the task JSON and resolves old inline data.
class OcrRetryStorage {
  OcrRetryStorage._();

  static const _cacheDirectoryName = 'ocr_retry_cache';
  static final Map<String, Future<void>> _taskWrites = {};
  static Future<void>? _cacheMaintenanceTail;

  @visibleForTesting
  static Future<void> Function(String reference, Uint8List bytes)?
      debugBeforeCacheWrite;

  /// Serializes cache writes through task publication against orphan cleanup.
  static Future<T> withCacheMaintenanceLock<T>(Future<T> Function() operation) {
    final previous = _cacheMaintenanceTail;
    final release = Completer<void>();
    _cacheMaintenanceTail = release.future;
    return () async {
      if (previous != null) await previous;
      try {
        return await operation();
      } finally {
        release.complete();
        if (identical(_cacheMaintenanceTail, release.future)) {
          _cacheMaintenanceTail = null;
        }
      }
    }();
  }

  static Future<Map<String, dynamic>> cacheSnapshot({
    required String taskId,
    required OcrRetrySnapshot snapshot,
    bool allowIncompleteImages = false,
  }) async {
    final missingImageCount = snapshot.imageEntryCount - snapshot.images.length;
    final hasIncompleteImages =
        snapshot.hasInvalidImages || missingImageCount != 0;
    if (taskId.isEmpty ||
        missingImageCount < 0 ||
        (hasIncompleteImages && !allowIncompleteImages)) {
      throw const FormatException('OCR retry snapshot is incomplete');
    }

    return _withTaskWrite(taskId, () async {
      final cachedImages = List<OcrRetryImage?>.filled(
        snapshot.imageEntryCount,
        null,
      );
      final previousBytes = <String, Uint8List?>{};
      try {
        final invalidCountWithoutImageEntries =
            snapshot.hasInvalidImages && missingImageCount == 0;
        final imagesToCache = invalidCountWithoutImageEntries
            ? const <OcrRetryImage>[]
            : snapshot.images;
        for (var index = 0; index < imagesToCache.length; index++) {
          final image = imagesToCache[index];
          final imageEntryIndex = snapshot.imageEntryIndices[index];
          final bytes = image.bytes ??
              (image.storageRef == null ? null : await read(image.storageRef!));
          if (bytes == null || bytes.isEmpty) {
            throw const FormatException(
              'An OCR retry image is missing; select the images again',
            );
          }
          final imageReference = image.storageRef;
          final preferredReference =
              imageReference != null && _isCacheReference(imageReference)
                  ? imageReference
                  : _referenceFor(taskId, imageEntryIndex);
          final existingBytes = await read(preferredReference);
          final reference =
              existingBytes != null && !_sameBytes(existingBytes, bytes)
                  ? _versionedReferenceFor(taskId, imageEntryIndex, bytes)
                  : preferredReference;
          previousBytes[reference] = await _writeIfChanged(reference, bytes);
          cachedImages[imageEntryIndex] = OcrRetryImage.reference(
            storageRef: reference,
            format: OcrRetryImage.inferFormatFromBytes(bytes) ?? image.format,
            name: image.name,
          );
        }

        if (hasIncompleteImages) {
          for (var index = 0; index < cachedImages.length; index++) {
            cachedImages[index] ??= OcrRetryImage.reference(
              storageRef: _missingReferenceFor(taskId, index),
              format: 'jpeg',
            );
          }
        }

        return OcrRetrySnapshot.capture(
          configId: snapshot.configId,
          modelId: snapshot.modelId,
          images: [
            for (final image in cachedImages)
              if (image != null) image,
          ],
          instructionContent: snapshot.instructionContent,
          saveFolder: snapshot.saveFolder,
          batchMode: snapshot.batchMode,
          perImageConcurrency: snapshot.perImageConcurrency,
          requestSizeBudgetBytes: snapshot.requestSizeBudgetBytes,
          legacyModelIndex: snapshot.legacyModelIndex,
          legacyInstructionIndex: snapshot.legacyInstructionIndex,
        ).toMap();
      } catch (_) {
        for (final entry in previousBytes.entries.toList().reversed) {
          try {
            final oldBytes = entry.value;
            if (oldBytes == null) {
              await deleteUnreferenced(
                candidates: {entry.key},
                referenced: const {},
              );
            } else {
              await _writeIfChanged(entry.key, oldBytes);
            }
          } catch (_) {}
        }
        rethrow;
      }
    });
  }

  /// Preserves safe retry context and existing cache references while
  /// replacing unavailable image bodies with references that require reselection.
  static Map<String, dynamic> unavailableSnapshot({
    required String taskId,
    required OcrRetrySnapshot snapshot,
  }) {
    final supportedVersion = snapshot.isLegacy ||
        snapshot.version == 1 ||
        snapshot.version == 2 ||
        snapshot.version == OcrRetrySnapshot.currentVersion;
    return _unavailableSnapshot(
      taskId: taskId,
      imageCount: snapshot.imageEntryCount,
      preservedImagesByIndex: {
        if (supportedVersion)
          for (var index = 0; index < snapshot.images.length; index++)
            if (snapshot.images[index].storageRef != null)
              snapshot.imageEntryIndices[index]: snapshot.images[index],
      },
      configId: snapshot.configId,
      modelId: snapshot.modelId,
      instructionContent: snapshot.instructionContent,
      saveFolder: snapshot.saveFolder,
      batchMode: snapshot.batchMode,
      perImageConcurrency: snapshot.perImageConcurrency,
      requestSizeBudgetBytes: snapshot.requestSizeBudgetBytes,
      legacyModelIndex: snapshot.legacyModelIndex,
      legacyInstructionIndex: snapshot.legacyInstructionIndex,
    );
  }

  /// Creates a retry snapshot from legacy request metadata. Image references
  /// deliberately lack backing files, so the user must reselect them.
  static Map<String, dynamic> unavailableSnapshotForCount({
    required String taskId,
    required int imageCount,
    String? modelId,
    String? instructionContent,
  }) =>
      _unavailableSnapshot(
        taskId: taskId,
        imageCount: imageCount,
        modelId: modelId,
        instructionContent: instructionContent,
      );

  static Map<String, dynamic> _unavailableSnapshot({
    required String taskId,
    required int imageCount,
    Map<int, OcrRetryImage> preservedImagesByIndex = const {},
    String? configId,
    String? modelId,
    String? instructionContent,
    String saveFolder = '',
    OcrBatchMode batchMode = OcrBatchMode.joint,
    int perImageConcurrency = 1,
    int requestSizeBudgetBytes = defaultOcrRequestSizeBudgetBytes,
    int? legacyModelIndex,
    int? legacyInstructionIndex,
  }) {
    final images = <OcrRetryImage>[];
    for (var index = 0; index < imageCount; index++) {
      final preserved = preservedImagesByIndex[index];
      final storageRef = preserved?.storageRef;
      images.add(
        storageRef == null
            ? OcrRetryImage.reference(
                storageRef: _missingReferenceFor(taskId, index),
                format: 'jpeg',
              )
            : OcrRetryImage.reference(
                storageRef: storageRef,
                format: preserved!.format,
                name: preserved.name,
              ),
      );
    }
    return OcrRetrySnapshot.capture(
      configId: configId,
      modelId: modelId,
      images: images,
      instructionContent: instructionContent,
      saveFolder: saveFolder,
      batchMode: batchMode,
      perImageConcurrency: perImageConcurrency,
      requestSizeBudgetBytes: requestSizeBudgetBytes,
      legacyModelIndex: legacyModelIndex,
      legacyInstructionIndex: legacyInstructionIndex,
    ).toMap();
  }

  static Future<OcrRetryRestoreResult> restoreImages(
    OcrRetrySnapshot snapshot,
  ) async {
    final restored = <OcrRetryImage>[];
    var missing = snapshot.imageEntryCount - snapshot.images.length;
    for (final image in snapshot.images) {
      final bytes = image.bytes ??
          (image.storageRef == null ? null : await read(image.storageRef!));
      if (bytes == null || bytes.isEmpty) {
        missing++;
        continue;
      }
      restored.add(
        OcrRetryImage(
          bytes: bytes,
          format: OcrRetryImage.inferFormatFromBytes(bytes) ?? image.format,
          name: image.name,
        ),
      );
    }
    return OcrRetryRestoreResult(
      images: List.unmodifiable(restored),
      missingImageCount: missing,
    );
  }

  static Future<Uint8List?> read(String reference) async {
    if (!_isCacheReference(reference)) return null;
    if (_usesWebStore) return WebFileStore.read(reference);
    final file = await _nativeFile(reference);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Set<String> referencesFromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null || snapshot['type'] != 'ocr') return <String>{};
    final rawImages = snapshot['images'];
    if (rawImages is! List) return <String>{};
    return {
      for (final image in rawImages)
        if (image is Map &&
            image['storageRef'] is String &&
            _isCacheReference(image['storageRef'] as String))
          image['storageRef'] as String,
    };
  }

  /// Deletes only validated OCR references that no remaining task owns.
  static Future<void> deleteUnreferenced({
    required Set<String> candidates,
    required Set<String> referenced,
  }) async {
    final deletable = candidates
        .where(
          (reference) =>
              _isCacheReference(reference) && !referenced.contains(reference),
        )
        .toSet();
    for (final reference in deletable) {
      if (_usesWebStore) {
        await WebFileStore.delete(reference);
      } else {
        final file = await _nativeFile(reference);
        if (await file.exists()) await file.delete();
      }
    }
  }

  /// Removes exact OCR cache blobs that are no longer referenced by tasks.
  static Future<void> cleanupUnreferencedCache({
    required Set<String> referenced,
  }) async {
    final candidates = <String>{};
    if (_usesWebStore) {
      candidates.addAll(
        await WebFileStore.keysWithPrefix('$_cacheDirectoryName/'),
      );
    } else {
      final directory = Directory(
        p.join(await AppStorage.directory, _cacheDirectoryName),
      );
      if (!await directory.exists()) return;
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is File) {
          candidates.add('$_cacheDirectoryName/${p.basename(entry.path)}');
        }
      }
    }
    await deleteUnreferenced(candidates: candidates, referenced: referenced);
  }

  static String _referenceFor(String taskId, int index) {
    final hash = sha256.convert(utf8.encode('$taskId:$index')).toString();
    return '$_cacheDirectoryName/$hash.bin';
  }

  static String _versionedReferenceFor(
    String taskId,
    int index,
    Uint8List bytes,
  ) {
    final contentHash = sha256.convert(bytes);
    final hash =
        sha256.convert(utf8.encode('$taskId:$index:$contentHash')).toString();
    return '$_cacheDirectoryName/$hash.bin';
  }

  static String _missingReferenceFor(String taskId, int index) {
    final hash =
        sha256.convert(utf8.encode('missing:$taskId:$index')).toString();
    return '$_cacheDirectoryName/$hash.bin';
  }

  static bool _isCacheReference(String reference) =>
      OcrRetryImage.isValidStorageReference(reference);

  static bool get _usesWebStore => kIsWeb || WebFileStore.isTestMode;

  static Future<T> _withTaskWrite<T>(
    String taskId,
    Future<T> Function() write,
  ) async {
    final previous = _taskWrites[taskId] ?? Future<void>.value();
    final release = Completer<void>();
    final queuedWrite = release.future;
    _taskWrites[taskId] = queuedWrite;
    await previous;
    try {
      return await write();
    } finally {
      release.complete();
      if (identical(_taskWrites[taskId], queuedWrite)) {
        _taskWrites.remove(taskId);
      }
    }
  }

  static Future<Uint8List?> _writeIfChanged(
    String reference,
    Uint8List bytes,
  ) async {
    final existing = await read(reference);
    if (existing != null && _sameBytes(existing, bytes)) return existing;
    await debugBeforeCacheWrite?.call(reference, bytes);
    if (_usesWebStore) {
      await WebFileStore.write(reference, bytes);
      return existing;
    }
    final file = await _nativeFile(reference, createDirectory: true);
    await AtomicFile.writeBytes(file, bytes);
    return existing;
  }

  static bool _sameBytes(Uint8List left, Uint8List right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static Future<File> _nativeFile(
    String reference, {
    bool createDirectory = false,
  }) async {
    if (!_isCacheReference(reference)) {
      throw const FormatException('Invalid OCR cache reference');
    }
    final directory = Directory(
      p.join(await AppStorage.directory, _cacheDirectoryName),
    );
    if (createDirectory && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File(p.join(directory.path, p.basename(reference)));
  }
}
