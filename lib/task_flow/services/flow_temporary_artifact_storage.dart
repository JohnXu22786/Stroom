import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;

import '../../services/storage_service.dart';
import '../../utils/web_file_store.dart';
import '../models/flow_payload.dart';

const String flowTemporaryExecutionIdKey = '_flowTemporaryExecutionId';
const String flowTemporaryBlockIdKey = '_flowTemporaryBlockId';

/// Durable storage for files owned by one task-flow execution. These files do
/// not enter the media manifests or galleries. Native references are files
/// under the app data directory; web references are private WebFileStore keys.
class FlowTemporaryArtifactStorage {
  FlowTemporaryArtifactStorage._();

  static const _storageRoot = 'task_flow_temporary';

  static bool get _useWebStore => kIsWeb || WebFileStore.isTestMode;

  static String _segment(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static String _webExecutionPrefix(String executionId) =>
      '$_storageRoot/${_segment(executionId)}/';

  static String _webBlockPrefix(String executionId, String blockId) =>
      '${_webExecutionPrefix(executionId)}${_segment(blockId)}/';

  static Future<String> _nativeExecutionDirectory(String executionId) async {
    return p.join(
        await AppStorage.directory, _storageRoot, _segment(executionId));
  }

  static Future<String> _nativeBlockDirectory(
      String executionId, String blockId) async {
    return p.join(
        await _nativeExecutionDirectory(executionId), _segment(blockId));
  }

  static String _safeFileName(String fileName) {
    final basename = p.basename(fileName);
    final safe = basename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty || safe == '.' || safe == '..' ? 'output.bin' : safe;
  }

  /// Saves bytes under the given execution/block owner and returns the
  /// platform reference consumed by later flow steps.
  static Future<String> writeBytes({
    required String executionId,
    required String blockId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeName = _safeFileName(fileName);
    if (_useWebStore) {
      final key = '${_webBlockPrefix(executionId, blockId)}$safeName';
      await WebFileStore.write(key, bytes);
      return key;
    }

    final directory =
        Directory(await _nativeBlockDirectory(executionId, blockId));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, safeName));
    try {
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  /// Copies a native producer file into execution-owned storage without
  /// buffering the file in memory. Cancellation removes only this partial
  /// copy; the source remains untouched.
  static Future<String> copyNativeFile({
    required String sourcePath,
    required String executionId,
    required String blockId,
    bool Function()? cancelled,
  }) async {
    if (_useWebStore) {
      throw UnsupportedError('Native file staging is unavailable on Web');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
          'Temporary output source is missing', sourcePath);
    }
    final directory =
        Directory(await _nativeBlockDirectory(executionId, blockId));
    await directory.create(recursive: true);
    final target = File(p.join(directory.path, _safeFileName(sourcePath)));
    final sink = target.openWrite();
    var closed = false;
    try {
      await for (final bytes in source.openRead()) {
        if (cancelled?.call() ?? false) {
          throw FileSystemException('Temporary output copy cancelled');
        }
        sink.add(bytes);
      }
      await sink.flush();
      await sink.close();
      closed = true;
      if (cancelled?.call() ?? false) {
        throw FileSystemException('Temporary output copy cancelled');
      }
      return target.path;
    } catch (_) {
      if (!closed) {
        try {
          await sink.close();
        } catch (_) {
          // Preserve the producer/cancellation error while still attempting
          // to remove a partially written artifact below.
        }
      }
      try {
        if (await target.exists()) await target.delete();
      } catch (_) {
        // The execution-scoped orphan sweep can remove a failed partial copy.
      }
      rethrow;
    }
  }

  /// Confirms that [reference] is a single file directly owned by the
  /// expected execution and block. Raw paths and shared manifest files fail.
  static Future<bool> ownsReference({
    required String executionId,
    required String blockId,
    required String reference,
  }) async {
    if (reference.isEmpty) return false;
    if (_useWebStore) {
      final prefix = _webBlockPrefix(executionId, blockId);
      final name = reference.startsWith(prefix)
          ? reference.substring(prefix.length)
          : '';
      return name.isNotEmpty &&
          !name.contains('/') &&
          name != '.' &&
          name != '..';
    }
    final directory = p.normalize(
        p.absolute(await _nativeBlockDirectory(executionId, blockId)));
    final absolute = p.normalize(p.absolute(reference));
    return p.isWithin(directory, absolute) && p.dirname(absolute) == directory;
  }

  /// Deletes a single verified temporary artifact. An invalid owner/reference
  /// pair is retained rather than risking deletion of an input or shared file.
  static Future<bool> deleteArtifact(FlowTemporaryArtifact artifact) async {
    if (!await ownsReference(
      executionId: artifact.executionId,
      blockId: artifact.blockId,
      reference: artifact.reference,
    )) {
      debugPrint('[TaskFlow] Refused unowned artifact cleanup');
      return false;
    }
    if (_useWebStore) {
      await WebFileStore.delete(artifact.reference);
      return true;
    }
    final file = File(artifact.reference);
    if (await file.exists()) await file.delete();
    return true;
  }

  /// Removes only the private storage namespace derived from an execution ID.
  /// Used after the execution record is durably deleted.
  static Future<void> deleteExecution(String executionId) async {
    if (_useWebStore) {
      final prefix = _webExecutionPrefix(executionId);
      final keys = await WebFileStore.keysWithPrefix(prefix);
      for (final key in keys) {
        await WebFileStore.delete(key);
      }
      return;
    }
    final directory = Directory(await _nativeExecutionDirectory(executionId));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// Repairs an interrupted execution deletion on the next app restore.
  /// Names are hashes, so this can remove only directories/keys in this
  /// private namespace that have no durable execution record.
  static Future<void> cleanupOrphanedExecutions(
      Iterable<String> retainedExecutionIds) async {
    final retained = retainedExecutionIds.map(_segment).toSet();
    if (_useWebStore) {
      final prefix = '$_storageRoot/';
      final keys = await WebFileStore.keysWithPrefix(prefix);
      final orphanPrefixes = <String>{};
      for (final key in keys) {
        final rest = key.substring(prefix.length);
        final separator = rest.indexOf('/');
        if (separator <= 0) continue;
        final executionSegment = rest.substring(0, separator);
        if (!retained.contains(executionSegment)) {
          orphanPrefixes.add('$prefix$executionSegment/');
        }
      }
      for (final orphanPrefix in orphanPrefixes) {
        final orphanKeys = await WebFileStore.keysWithPrefix(orphanPrefix);
        for (final key in orphanKeys) {
          await WebFileStore.delete(key);
        }
      }
      return;
    }

    final directory =
        Directory(p.join(await AppStorage.directory, _storageRoot));
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is Directory && !retained.contains(p.basename(entity.path))) {
        await entity.delete(recursive: true);
      }
    }
  }
}
