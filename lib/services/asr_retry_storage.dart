import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/tts_models.dart';
import '../utils/atomic_file.dart';
import '../utils/web_file_store.dart';
import 'storage_service.dart';
import 'asr_service.dart';

const _asrRetryAudioPrefix = 'background/asr_retry/';
const _staleAsrAtomicWriteTempAge = Duration(days: 1);
final _asrRetryFileNamePattern = RegExp(r'^[a-f0-9]{32}\.(?:audio|chunks)$');
final _asrRetryAtomicTempNamePattern = RegExp(
  r'^\.[a-f0-9]{32}\.(?:audio|chunks)\.tmp-[a-zA-Z0-9_-]+$',
);
const _credentialNamePattern = r'(?:'
    r'(?:^|[-_.])api[-_.]?key(?:$|[-_.])|'
    r'(?:^|[-_.])app[-_.]?key(?:$|[-_.])|'
    r'(?:^|[-_.])access[-_.]?key(?:$|[-_.])|'
    r'(?:^|[-_.])key(?:$|[-_.])|'
    r'(?:^|[-_.])auth(?:orization)?(?:$|[-_.])|'
    r'(?:^|[-_.])sig(?:nature)?(?:$|[-_.])|'
    r'(?:^|[-_.])(?:set[-_.]?)?cookie(?:s)?(?:$|[-_.])|'
    r'(?:^|[-_.])session(?:[-_.]?(?:id|key|token))?(?:$|[-_.])|'
    r'(?:^|[-_.])(?:secret|token|password|passwd|credential|bearer)(?:$|[-_.])|'
    r'(?:^|[-_.])private[-_.]?key(?:$|[-_.])|'
    r'(?:^|[-_.])client[-_.]?secret(?:$|[-_.]))';
final _credentialValuePatterns = [
  RegExp(r'\b(?:bearer|basic)\s+\S+', caseSensitive: false),
  RegExp(r'\bsk-[A-Za-z0-9_-]{12,}\b'),
  RegExp(r'\bgh[pousr]_[A-Za-z0-9_]{16,}\b'),
  RegExp(r'\bxox[baprs]-[A-Za-z0-9-]{12,}\b'),
  RegExp(r'\bAIza[A-Za-z0-9_-]{20,}\b'),
  RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
  RegExp(
    r'(?:api[-_]?key|access[-_]?token|client[-_]?secret|password|token)\s*[:=]\s*\S+',
    caseSensitive: false,
  ),
];
final _credentialKeyValuePattern = RegExp(
  r'''(?:^|[\s,{&?;])['"]?([\w.-]+)['"]?\s*[:=]\s*['"]?[^\s,"'}&;]+''',
  caseSensitive: false,
);
final _embeddedHttpUrlPattern = RegExp(
  r'''https?://[^\s<>"']+''',
  caseSensitive: false,
);
final _encodedHttpUrlPattern = RegExp(r'https?%3a%2f%2f', caseSensitive: false);
final _knownIdentifierPathSegmentPattern = RegExp(
  r'^(?:[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}|[a-f0-9]{32}|[a-f0-9]{40}|[a-f0-9]{64}|[a-f0-9]{128})$',
  caseSensitive: false,
);

/// A narrow binary storage seam so retry records can be verified without a
/// platform filesystem or browser database.
abstract interface class AsrRetryStorageAdapter {
  Future<void> write(String key, Uint8List bytes);
  Future<Uint8List?> read(String key);
  Future<void> delete(String key);

  /// Returns stored keys plus stale native atomic-temp cleanup keys. The
  /// latter use the exact temporary directory basename as the key suffix.
  Future<List<String>> keysWithPrefix(String prefix);
}

class _WebAsrRetryStorageAdapter implements AsrRetryStorageAdapter {
  @override
  Future<void> write(String key, Uint8List bytes) =>
      WebFileStore.write(key, bytes);

  @override
  Future<Uint8List?> read(String key) => WebFileStore.read(key);

  @override
  Future<void> delete(String key) => WebFileStore.delete(key);

  @override
  Future<List<String>> keysWithPrefix(String prefix) =>
      WebFileStore.keysWithPrefix(prefix);
}

class _NativeAsrRetryStorageAdapter implements AsrRetryStorageAdapter {
  Future<String> _root() async =>
      p.join(await AppStorage.directory, 'background', 'asr_retry');

  File _file(String key, String root) {
    if (!key.startsWith(_asrRetryAudioPrefix)) {
      throw ArgumentError.value(key, 'key', 'Outside ASR retry storage');
    }
    final name = key.substring(_asrRetryAudioPrefix.length);
    if (!_asrRetryFileNamePattern.hasMatch(name)) {
      throw ArgumentError.value(key, 'key', 'Invalid ASR retry file name');
    }
    return File(p.join(root, name));
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final root = await _root();
    await Directory(root).create(recursive: true);
    await AtomicFile.writeBytes(_file(key, root), bytes);
  }

  @override
  Future<Uint8List?> read(String key) async {
    final file = _file(key, await _root());
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> delete(String key) async {
    final root = await _root();
    if (!key.startsWith(_asrRetryAudioPrefix)) {
      throw ArgumentError.value(key, 'key', 'Outside ASR retry storage');
    }
    final name = key.substring(_asrRetryAudioPrefix.length);
    if (_asrRetryAtomicTempNamePattern.hasMatch(name)) {
      final directory = Directory(p.join(root, name));
      if (await directory.exists()) {
        try {
          await directory.delete(recursive: true);
        } on FileSystemException {
          if (await directory.exists()) rethrow;
        }
      }
      return;
    }
    final file = _file(key, root);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> keysWithPrefix(String prefix) async {
    if (prefix != _asrRetryAudioPrefix) {
      throw ArgumentError.value(prefix, 'prefix', 'Outside ASR retry storage');
    }
    final root = Directory(await _root());
    if (!await root.exists()) return const [];
    final staleBefore = DateTime.now().subtract(_staleAsrAtomicWriteTempAge);
    final keys = <String>[];
    for (final entity in await root.list().toList()) {
      final name = p.basename(entity.path);
      if (entity is File && _asrRetryFileNamePattern.hasMatch(name)) {
        keys.add('$_asrRetryAudioPrefix$name');
        continue;
      }
      if (entity is! Directory ||
          !_asrRetryAtomicTempNamePattern.hasMatch(name)) {
        continue;
      }
      final stat = await entity.stat();
      if (stat.type == FileSystemEntityType.directory &&
          stat.modified.isBefore(staleBefore)) {
        // AtomicFile creates these sibling directories and removes them after
        // commit. A process crash can skip its finally block; only old,
        // precisely named entries are surfaced for task-owned pruning.
        keys.add('$_asrRetryAudioPrefix$name');
      }
    }
    return keys;
  }
}

/// Stable pointer to retry audio. The bytes live under an app-owned namespace,
/// while task JSON stores this small versioned reference.
class AsrAudioReference {
  static const currentVersion = 1;

  final int version;
  final String id;
  final String name;
  final String format;
  final int byteLength;
  final String sha256;
  final String? url;
  final bool requiresSourceReselection;

  const AsrAudioReference({
    this.version = currentVersion,
    required this.id,
    required this.name,
    required this.format,
    required this.byteLength,
    required this.sha256,
    this.url,
    this.requiresSourceReselection = false,
  });

  bool get isUrl => url != null;

  Map<String, dynamic> toMap({String? configuredApiKey}) {
    final hasUnsupportedUrl = url != null && !_isSupportedAudioUrl(url!);
    _validateAudioReferenceFields(
      version: version,
      id: id,
      byteLength: byteLength,
      sha256: sha256,
      isUrl: url != null,
      allowMissingLocalSource: url == null && requiresSourceReselection,
      configuredApiKey: configuredApiKey,
    );
    final audioFormat = _safeAudioFormat(format);
    final safeFormat = _safeAudioReferenceFormat(audioFormat, configuredApiKey);
    final formatWasRedacted = safeFormat.isEmpty && audioFormat.isNotEmpty;
    final urlHasAudioPayload =
        url != null && _urlContainsEmbeddedAudioPayload(url!);
    final safeUrl = url == null
        ? null
        : hasUnsupportedUrl || urlHasAudioPayload
            ? ''
            : _sanitizeAudioReferenceUrl(url!,
                configuredApiKey: configuredApiKey);
    final safeEncodedUrlNormalization = url != null &&
        _isBenignEncodedHttpUrlNormalization(
          url!,
          safeUrl,
          configuredApiKey: configuredApiKey,
        );
    final urlHasCredentials = url != null &&
        (AsrRetryConfigSnapshot.urlContainsCredentials(
              url!,
              configuredApiKey: configuredApiKey,
            ) ||
            hasUnsupportedUrl ||
            (safeUrl != url && !safeEncodedUrlNormalization));
    final safeName = url != null && name == url
        ? safeUrl == null || safeUrl.isEmpty
            ? AsrRetryAudioStore.sanitizeAudioName(
                '',
                format: audioFormat,
                configuredApiKey: configuredApiKey,
              )
            : safeUrl
        : name.isEmpty
            ? ''
            : AsrRetryAudioStore.sanitizeAudioName(
                name,
                format: audioFormat,
                configuredApiKey: configuredApiKey,
              );
    final data = <String, dynamic>{
      'version': version,
      'id': id,
      'name': safeName,
      'format': safeFormat,
      'byteLength': byteLength,
      'sha256': sha256,
    };
    if (safeUrl != null) data['url'] = safeUrl;
    if (requiresSourceReselection ||
        urlHasCredentials ||
        urlHasAudioPayload ||
        formatWasRedacted) {
      data['requiresSourceReselection'] = true;
    }
    return data;
  }

  factory AsrAudioReference.fromMap(
    Map<String, dynamic> map, {
    String? configuredApiKey,
  }) {
    final version = map['version'];
    final id = map['id'];
    final name = map['name'];
    final format = map['format'];
    final byteLength = map['byteLength'];
    final sha = map['sha256'];
    final url = map['url'] as String?;
    final needsReselection = map['requiresSourceReselection'] as bool? ?? false;
    if (name is! String || format is! String) {
      throw const FormatException('无效或不支持的 ASR 音频引用');
    }
    final hasUnsupportedUrl = url != null && !_isSupportedAudioUrl(url);
    _validateAudioReferenceFields(
      version: version,
      id: id,
      byteLength: byteLength,
      sha256: sha,
      isUrl: url != null,
      allowMissingLocalSource: url == null && needsReselection,
      configuredApiKey: configuredApiKey,
    );
    final urlHasAudioPayload =
        url != null && _urlContainsEmbeddedAudioPayload(url);
    final safeUrl = url == null
        ? null
        : hasUnsupportedUrl || urlHasAudioPayload
            ? ''
            : _sanitizeAudioReferenceUrl(url,
                configuredApiKey: configuredApiKey);
    final safeEncodedUrlNormalization = url != null &&
        _isBenignEncodedHttpUrlNormalization(
          url,
          safeUrl,
          configuredApiKey: configuredApiKey,
        );
    final urlHasCredentials = url != null &&
        (AsrRetryConfigSnapshot.urlContainsCredentials(
              url,
              configuredApiKey: configuredApiKey,
            ) ||
            hasUnsupportedUrl ||
            (safeUrl != url && !safeEncodedUrlNormalization));
    final audioFormat = _safeAudioFormat(format);
    final formatWasRedacted = format.isEmpty ||
        _containsConfiguredApiKey(audioFormat, configuredApiKey);
    final safeFormat = formatWasRedacted ? 'bin' : audioFormat;
    final safeName = url != null && name == url
        ? safeUrl == null || safeUrl.isEmpty
            ? AsrRetryAudioStore.sanitizeAudioName(
                '',
                format: audioFormat,
                configuredApiKey: configuredApiKey,
              )
            : safeUrl
        : name.isEmpty
            ? ''
            : AsrRetryAudioStore.sanitizeAudioName(
                name,
                format: audioFormat,
                configuredApiKey: configuredApiKey,
              );
    return AsrAudioReference(
      version: version as int,
      id: id,
      name: safeName,
      format: safeFormat,
      byteLength: byteLength,
      sha256: sha,
      url: safeUrl,
      requiresSourceReselection: needsReselection ||
          hasUnsupportedUrl ||
          urlHasCredentials ||
          urlHasAudioPayload ||
          formatWasRedacted,
    );
  }
}

void _validateAudioReferenceFields({
  required Object? version,
  required Object? id,
  required Object? byteLength,
  required Object? sha256,
  required bool isUrl,
  bool allowMissingLocalSource = false,
  String? configuredApiKey,
}) {
  if (version is! int ||
      version != AsrAudioReference.currentVersion ||
      id is! String ||
      !RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
      byteLength is! int ||
      byteLength < 0 ||
      (!isUrl && byteLength == 0 && !allowMissingLocalSource) ||
      sha256 is! String ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
      _containsConfiguredApiKeyInStructuralToken(id, configuredApiKey) ||
      _containsConfiguredApiKeyInStructuralToken(sha256, configuredApiKey)) {
    throw const FormatException('无效或不支持的 ASR 音频引用');
  }
}

bool _containsConfiguredApiKeyInStructuralToken(
  String value,
  String? configuredApiKey,
) {
  if (configuredApiKey == null || configuredApiKey.isEmpty) return false;
  // IDs and digests are opaque random/derived hex tokens, not free-form text.
  // A short configured key will almost always occur by chance (and UUID v4
  // always includes "4"), so only treat substantial hex secrets as leaks in
  // these fields. Text-bearing fields continue to use full substring checks.
  return _configuredApiKeyVariants(configuredApiKey, value.length).any(
    (variant) =>
        variant.length >= 16 &&
        RegExp(r'^[a-f0-9]+$', caseSensitive: false).hasMatch(variant) &&
        value.contains(variant.toLowerCase()),
  );
}

bool _isSupportedAudioUrl(String value) =>
    _isAbsoluteHttpUri(_parseRetryUri(value));

String _sanitizeAudioReferenceUrl(String value, {String? configuredApiKey}) {
  final directUri = Uri.tryParse(value);
  final retryUri = _parseRetryUri(value);
  if (!_isAbsoluteHttpUri(directUri) && _isAbsoluteHttpUri(retryUri)) {
    return _sanitizeHost(
      retryUri!.toString(),
      configuredApiKey: configuredApiKey,
    );
  }
  return AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(
    value,
    configuredApiKey: configuredApiKey,
  );
}

String? _retryAudioUrlFingerprint(AsrAudioReference reference) {
  final url = reference.url;
  if (url == null) return null;
  final uri = _parseRetryUri(url);
  final source = uri != null && _isAbsoluteHttpUri(uri) ? uri.toString() : url;
  return sha256.convert(utf8.encode('asr-url\u0000$source')).toString();
}

bool _isBenignEncodedHttpUrlNormalization(
  String value,
  String? sanitized, {
  String? configuredApiKey,
}) {
  final directUri = Uri.tryParse(value);
  final retryUri = _parseRetryUri(value);
  return !_isAbsoluteHttpUri(directUri) &&
      _isAbsoluteHttpUri(retryUri) &&
      sanitized == retryUri!.toString() &&
      !AsrRetryConfigSnapshot.urlContainsCredentials(
        value,
        configuredApiKey: configuredApiKey,
      ) &&
      !_urlContainsEmbeddedAudioPayload(value);
}

class AsrRetryAudioUnavailableException implements Exception {
  final String audioName;
  final bool corrupt;

  const AsrRetryAudioUnavailableException(
    this.audioName, {
    this.corrupt = false,
  });

  @override
  String toString() => corrupt
      ? '原始音频文件已损坏，请重新选择音频后重试：$audioName'
      : '原始音频文件已丢失，请重新选择音频后重试：$audioName';
}

/// Durable per-source ASR chunk outcomes, separate from the task-list snapshot.
class AsrRetryChunkCheckpoint {
  static const currentVersion = 2;

  final String audioReferenceId;
  final String audioSha256;
  final String? audioUrlSha256;
  final String configId;
  final String modelId;
  final String? configSnapshotSha256;
  final List<AsrChunkResult> chunks;

  AsrRetryChunkCheckpoint({
    required this.audioReferenceId,
    required this.audioSha256,
    required this.audioUrlSha256,
    required this.configId,
    required this.modelId,
    this.configSnapshotSha256,
    required Iterable<AsrChunkResult> chunks,
  }) : chunks = List.unmodifiable(chunks);

  Map<String, dynamic> toMap() => {
        'version': currentVersion,
        'audioReferenceId': audioReferenceId,
        'audioSha256': audioSha256,
        if (audioUrlSha256 != null) 'audioUrlSha256': audioUrlSha256,
        'modelReference': {'configId': configId, 'modelId': modelId},
        if (configSnapshotSha256 != null)
          'configSnapshotSha256': configSnapshotSha256,
        'chunks': chunks.map((chunk) => chunk.toMap()).toList(),
      };

  factory AsrRetryChunkCheckpoint.fromMap(
    Map<String, dynamic> map, {
    required AsrAudioReference reference,
    String? configuredApiKey,
  }) {
    final storedModelReference = map['modelReference'];
    final configId = storedModelReference is Map
        ? _safeModelReferenceId(
            storedModelReference['configId'],
            configuredApiKey: configuredApiKey,
          )
        : null;
    final modelId = storedModelReference is Map
        ? _safeModelReferenceId(
            storedModelReference['modelId'],
            configuredApiKey: configuredApiKey,
          )
        : null;
    final rawConfigSnapshotSha256 = map['configSnapshotSha256'];
    final configSnapshotSha256 = rawConfigSnapshotSha256 == null
        ? null
        : _safeConfigSnapshotSha256(rawConfigSnapshotSha256);
    final audioUrlSha256 = _retryAudioUrlFingerprint(reference);
    if (map['version'] != currentVersion ||
        map['audioReferenceId'] != reference.id ||
        map['audioSha256'] != reference.sha256 ||
        map['audioUrlSha256'] != audioUrlSha256 ||
        (rawConfigSnapshotSha256 != null && configSnapshotSha256 == null) ||
        configId == null ||
        modelId == null ||
        map['chunks'] is! List) {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    final chunks = <AsrChunkResult>[];
    final indexes = <int>{};
    try {
      final storedChunks = map['chunks'] as List;
      final hasUnknownStatus = storedChunks.any((value) {
        if (value is! Map) return true;
        final status = value['status'];
        return !AsrChunkStatus.values.any(
          (candidate) => candidate.name == status,
        );
      });
      if (hasUnknownStatus) {
        throw const AsrRetryChunkCheckpointUnavailableException();
      }
      final hasMalformedSuccessfulTiming = storedChunks.any((value) {
        if (value is! Map || value['status'] != AsrChunkStatus.succeeded.name) {
          return false;
        }
        final startSeconds = value['startSeconds'];
        final endSeconds = value['endSeconds'];
        return startSeconds is! num ||
            endSeconds is! num ||
            !startSeconds.isFinite ||
            !endSeconds.isFinite ||
            startSeconds < 0 ||
            endSeconds < startSeconds;
      });
      if (hasMalformedSuccessfulTiming) {
        throw const AsrRetryChunkCheckpointUnavailableException();
      }
      final hasMalformedTranscriptParts = storedChunks.any((value) {
        if (value is! Map) return false;
        for (final field in ['segments', 'words']) {
          final parts = value[field];
          if (parts == null) continue;
          if (parts is! List || parts.any((part) => part is! Map)) {
            return true;
          }
        }
        return false;
      });
      if (hasMalformedTranscriptParts) {
        throw const AsrRetryChunkCheckpointUnavailableException();
      }
      final sanitizedChunks = AsrRetryAudioStore._sanitizeRetryChunks(
        storedChunks,
        configuredApiKey: configuredApiKey,
      );
      if (sanitizedChunks == null) {
        throw const AsrRetryChunkCheckpointUnavailableException();
      }
      for (final value in sanitizedChunks) {
        if (!AsrChunkStatus.values.any(
          (status) => status.name == value['status'],
        )) {
          throw const AsrRetryChunkCheckpointUnavailableException();
        }
        final chunk = AsrChunkResult.fromMap(Map<String, dynamic>.from(value));
        if (chunk.index < 0 ||
            !chunk.startSeconds.isFinite ||
            !chunk.endSeconds.isFinite ||
            chunk.startSeconds < 0 ||
            chunk.endSeconds < chunk.startSeconds ||
            (chunk.totalChunks != null &&
                (chunk.totalChunks! <= chunk.index ||
                    chunk.totalChunks! <= 0)) ||
            !indexes.add(chunk.index)) {
          throw const AsrRetryChunkCheckpointUnavailableException();
        }
        chunks.add(
          AsrChunkResult(
            index: chunk.index,
            startSeconds: chunk.startSeconds,
            endSeconds: chunk.endSeconds,
            totalChunks: chunk.totalChunks,
            planFingerprint: chunk.planFingerprint,
            status: chunk.status,
            text: chunk.text,
            subtitle: chunk.subtitle,
            segments: chunk.segments,
            words: chunk.words,
          ),
        );
      }
    } on AsrRetryChunkCheckpointUnavailableException {
      rethrow;
    } on Object {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    final planFingerprints = {
      for (final chunk in chunks)
        if (chunk.planFingerprint != null) chunk.planFingerprint,
    };
    if (planFingerprints.length > 1 ||
        (planFingerprints.isNotEmpty &&
            chunks.any((chunk) => chunk.planFingerprint == null))) {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    final declaredChunkCounts = {
      for (final chunk in chunks) chunk.totalChunks,
    };
    if (declaredChunkCounts.length > 1) {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    chunks.sort((left, right) => left.index.compareTo(right.index));
    return AsrRetryChunkCheckpoint(
      audioReferenceId: reference.id,
      audioSha256: reference.sha256,
      audioUrlSha256: audioUrlSha256,
      configId: configId,
      modelId: modelId,
      configSnapshotSha256: configSnapshotSha256,
      chunks: chunks,
    );
  }
}

class _AsrRetryChunkCheckpointCollection {
  static const currentVersion = 3;

  final String audioReferenceId;
  final String audioSha256;
  final List<AsrRetryChunkCheckpoint> checkpoints;

  _AsrRetryChunkCheckpointCollection({
    required this.audioReferenceId,
    required this.audioSha256,
    required Iterable<AsrRetryChunkCheckpoint> checkpoints,
  }) : checkpoints = List.unmodifiable(checkpoints);

  Map<String, dynamic> toMap() => {
        'version': currentVersion,
        'audioReferenceId': audioReferenceId,
        'audioSha256': audioSha256,
        'checkpoints':
            checkpoints.map((checkpoint) => checkpoint.toMap()).toList(),
      };

  factory _AsrRetryChunkCheckpointCollection.fromMap(
    Map<String, dynamic> map, {
    required AsrAudioReference reference,
    String? configuredApiKey,
  }) {
    final rawCheckpoints = map['checkpoints'];
    if (map['version'] != currentVersion ||
        map['audioReferenceId'] != reference.id ||
        map['audioSha256'] != reference.sha256 ||
        rawCheckpoints is! List ||
        rawCheckpoints.isEmpty) {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    final checkpoints = <AsrRetryChunkCheckpoint>[];
    final modelIdentities = <String>{};
    for (final value in rawCheckpoints) {
      if (value is! Map) {
        throw const AsrRetryChunkCheckpointUnavailableException();
      }
      final checkpoint = AsrRetryChunkCheckpoint.fromMap(
        Map<String, dynamic>.from(value),
        reference: reference,
        configuredApiKey: configuredApiKey,
      );
      final identity = jsonEncode([
        checkpoint.configId,
        checkpoint.modelId,
        checkpoint.configSnapshotSha256,
      ]);
      if (!modelIdentities.add(identity)) {
        throw const AsrRetryChunkCheckpointUnavailableException();
      }
      checkpoints.add(checkpoint);
    }
    return _AsrRetryChunkCheckpointCollection(
      audioReferenceId: reference.id,
      audioSha256: reference.sha256,
      checkpoints: checkpoints,
    );
  }
}

class AsrRetryChunkCheckpointUnavailableException implements Exception {
  const AsrRetryChunkCheckpointUnavailableException();

  @override
  String toString() => 'ASR 分段恢复记录无效，请重新选择音频后再试';
}

class AsrRetrySourceReselectionException implements Exception {
  const AsrRetrySourceReselectionException();

  @override
  String toString() => '音频来源包含敏感信息或内嵌音频数据，无法安全重试，请重新选择音频后重试';
}

class _AsrRetryDeletionOutcome {
  final Object? error;
  final StackTrace? stackTrace;

  const _AsrRetryDeletionOutcome({this.error, this.stackTrace});

  void throwIfFailed() {
    final failure = error;
    if (failure != null) {
      Error.throwWithStackTrace(failure, stackTrace ?? StackTrace.current);
    }
  }
}

class _AsrRetryDeletion {
  final bool deleteAudio;
  final Completer<_AsrRetryDeletionOutcome> completion = Completer();

  _AsrRetryDeletion({required this.deleteAudio});
}

/// Stores one copy of each source audio and prunes only unreferenced files in
/// the ASR retry namespace.
class AsrRetryAudioStore {
  static final Map<String, int> _temporaryProtectionCounts = {};
  static final Map<String, _AsrRetryDeletion> _deletionsInProgress = {};
  static final Map<String, Completer<void>> _checkpointWriteLocks = {};
  static final Map<String, int> _checkpointWriteEpochs = {};
  static final Map<String, int> _checkpointWriteCounts = {};
  static final Map<String, int> _audioWriteCounts = {};
  static final Map<String, Completer<void>> _audioWriteCompletions = {};
  static final Map<String, Completer<void>> _atomicTempCleanupInProgress = {};

  final AsrRetryStorageAdapter _adapter;

  AsrRetryAudioStore({AsrRetryStorageAdapter? adapter})
      : _adapter = adapter ??
            (kIsWeb || WebFileStore.isTestMode
                ? _WebAsrRetryStorageAdapter()
                : _NativeAsrRetryStorageAdapter());

  /// Returns a display-safe local audio name for task titles and retry refs.
  /// Credential-shaped names are replaced so filenames cannot leak into task
  /// JSON even when the provider treats the name as ordinary metadata.
  static String sanitizeAudioName(
    String name, {
    required String format,
    String? configuredApiKey,
  }) {
    final trimmedName = name.trim();
    final credentialPathName = trimmedName.replaceAll('\\', '/');
    final fallbackName = 'audio.${_safeAudioFormat(format)}';
    final safeFallbackName =
        _containsConfiguredApiKey(fallbackName, configuredApiKey)
            ? ''
            : fallbackName;
    if (_isCredentialName(trimmedName) ||
        _containsConfiguredApiKey(trimmedName, configuredApiKey) ||
        _sanitizeCredentialPathsInText(credentialPathName) !=
            credentialPathName ||
        _containsInlineAudioPayload(trimmedName)) {
      return safeFallbackName;
    }
    final basename = p.basename(trimmedName);
    if (_containsConfiguredApiKey(basename, configuredApiKey) ||
        _containsInlineAudioPayload(basename)) {
      return safeFallbackName;
    }
    final safeName = _sanitizeDiagnosticString(
      basename,
      configuredApiKey: configuredApiKey,
    );
    if (safeName != null && safeName.isNotEmpty) return safeName;
    return safeFallbackName;
  }

  static bool hasValidVersionedReferences(Map<String, dynamic>? retryData) {
    if (retryData == null || !retryData.containsKey('version')) return true;
    if (retryData['version'] != 2) return false;
    final singleReference = retryData['audioReference'];
    final multipleReferences = retryData['audioReferences'];
    try {
      if (singleReference is Map && multipleReferences == null) {
        AsrAudioReference.fromMap(Map<String, dynamic>.from(singleReference));
        return true;
      }
      if (singleReference == null &&
          multipleReferences is List &&
          multipleReferences.isNotEmpty) {
        for (final entry in multipleReferences) {
          if (entry is! Map || entry['audioReference'] is! Map) return false;
          AsrAudioReference.fromMap(
            Map<String, dynamic>.from(entry['audioReference'] as Map),
          );
        }
        return true;
      }
    } on Object {
      return false;
    }
    return false;
  }

  /// Rebuilds a supported versioned snapshot from its recognized fields.
  /// Persisted task rows are untrusted input: validating their audio pointers
  /// alone must not allow extra fields to carry credentials or inline audio
  /// back into tasks.json on the next write.
  static Map<String, dynamic>? sanitizeVersionedRetryData(
    Map<String, dynamic>? retryData, {
    String? configuredApiKey,
    bool allowUnknownChunkStatuses = false,
  }) {
    if (retryData == null ||
        retryData['version'] != 2 ||
        !hasValidVersionedReferences(retryData)) {
      return null;
    }
    final singleReference = retryData['audioReference'];
    final multipleReferences = retryData['audioReferences'];
    if (singleReference is Map &&
        retryData.containsKey('chunks') &&
        retryData['chunks'] is! List) {
      return null;
    }
    if (multipleReferences is List &&
        multipleReferences.any(
          (entry) =>
              entry is Map &&
              entry.containsKey('chunks') &&
              entry['chunks'] is! List,
        )) {
      return null;
    }
    if (!allowUnknownChunkStatuses &&
        singleReference is Map &&
        !_hasKnownRetryChunkStatuses(retryData['chunks'])) {
      return null;
    }
    if (!allowUnknownChunkStatuses &&
        multipleReferences is List &&
        multipleReferences.any(
          (entry) =>
              entry is Map && !_hasKnownRetryChunkStatuses(entry['chunks']),
        )) {
      return null;
    }

    final sanitized = <String, dynamic>{'type': 'asr', 'version': 2};
    try {
      final singleReference = retryData['audioReference'];
      final multipleReferences = retryData['audioReferences'];
      if (singleReference is Map) {
        sanitized['audioReference'] = AsrAudioReference.fromMap(
          Map<String, dynamic>.from(singleReference),
          configuredApiKey: configuredApiKey,
        ).toMap(configuredApiKey: configuredApiKey);
        final chunks = _sanitizeRetryChunks(
          retryData['chunks'],
          configuredApiKey: configuredApiKey,
        );
        if (chunks != null) sanitized['chunks'] = chunks;
      } else if (multipleReferences is List) {
        sanitized['audioReferences'] = [
          for (final entry in multipleReferences)
            if (entry is Map && entry['audioReference'] is Map)
              {
                'audioReference': AsrAudioReference.fromMap(
                  Map<String, dynamic>.from(entry['audioReference'] as Map),
                  configuredApiKey: configuredApiKey,
                ).toMap(configuredApiKey: configuredApiKey),
                'chunks': _sanitizeRetryChunks(
                      entry['chunks'],
                      configuredApiKey: configuredApiKey,
                    ) ??
                    const <dynamic>[],
              },
        ];
      }

      final modelReference = retryData['modelReference'];
      if (modelReference is Map) {
        final configId = _safeModelReferenceId(
          modelReference['configId'],
          configuredApiKey: configuredApiKey,
        );
        final modelId = _safeModelReferenceId(
          modelReference['modelId'],
          configuredApiKey: configuredApiKey,
        );
        if (configId != null && modelId != null) {
          sanitized['modelReference'] = {
            'configId': configId,
            'modelId': modelId,
          };
        }
      }

      final configSnapshot = retryData['configSnapshot'];
      if (configSnapshot is Map) {
        sanitized['configSnapshot'] = AsrRetryConfigSnapshot.fromMap(
          Map<String, dynamic>.from(configSnapshot),
          configuredApiKey: configuredApiKey,
        ).toMap(configuredApiKey: configuredApiKey);
      }

      final saveFolder = retryData['saveFolder'];
      if (saveFolder is String && saveFolder.trim().isNotEmpty) {
        final safeSaveFolder = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
          saveFolder,
          configuredApiKey: configuredApiKey,
        );
        if (safeSaveFolder == saveFolder.trim() &&
            safeSaveFolder.length <= 512) {
          sanitized['saveFolder'] = safeSaveFolder;
        }
      }
    } on Object {
      return null;
    }
    return sanitized;
  }

  static bool _hasKnownRetryChunkStatuses(Object? value) {
    if (value == null) return true;
    if (value is! List) return false;
    return value.every(
      (chunk) =>
          chunk is Map &&
          AsrChunkStatus.values.any(
            (status) => status.name == chunk['status'],
          ),
    );
  }

  static List<Map<String, dynamic>>? _sanitizeRetryChunks(
    Object? value, {
    String? configuredApiKey,
  }) {
    if (value is! List) return null;
    final indexes = <int>{};
    for (final chunk in value) {
      if (chunk is Map && _isIntegerNumber(chunk['index'])) {
        if (!indexes.add((chunk['index'] as num).toInt())) {
          throw const FormatException('Duplicate retry chunk indexes');
        }
      }
    }

    final chunks = <Map<String, dynamic>>[];
    for (final chunk in value) {
      if (chunk is! Map) {
        throw const AsrRetryChunkCheckpointUnavailableException();
      }
      try {
        final index = chunk['index'];
        final totalChunks = chunk['totalChunks'];
        final planFingerprint = chunk['planFingerprint'];
        if (!_isIntegerNumber(index) ||
            (totalChunks != null && !_isIntegerNumber(totalChunks)) ||
            (planFingerprint != null &&
                (planFingerprint is! String ||
                    !RegExp(r'^[a-f0-9]{64}$').hasMatch(planFingerprint)))) {
          throw const FormatException('Invalid chunk identity fields');
        }
        final result = AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk));
        if (result.index < 0 ||
            !result.startSeconds.isFinite ||
            !result.endSeconds.isFinite ||
            result.startSeconds < 0 ||
            result.endSeconds < result.startSeconds ||
            (result.totalChunks != null &&
                (result.totalChunks! <= result.index ||
                    result.totalChunks! <= 0))) {
          throw const FormatException('Invalid retry chunk identity or timing');
        }
        final safeText = result.text == null
            ? null
            : AsrRetryConfigSnapshot.sanitizeTranscriptText(
                result.text!,
                configuredApiKey: configuredApiKey,
              );
        if (result.text != null && safeText == null) {
          throw const FormatException('Unsafe checkpoint transcript');
        }
        if (result.status == AsrChunkStatus.succeeded && safeText == null) {
          throw const AsrRetryChunkCheckpointUnavailableException();
        }
        final safeSubtitle = result.subtitle == null
            ? null
            : AsrRetryConfigSnapshot.sanitizeTranscriptText(
                result.subtitle!,
                configuredApiKey: configuredApiKey,
              );
        if (result.subtitle != null && safeSubtitle == null) {
          throw const FormatException('Unsafe checkpoint subtitle');
        }
        chunks.add(
          AsrChunkResult(
            index: result.index,
            startSeconds: result.startSeconds,
            endSeconds: result.endSeconds,
            totalChunks: result.totalChunks,
            planFingerprint: result.planFingerprint,
            status: result.status,
            text: safeText,
            subtitle: safeSubtitle,
            segments: _sanitizeRetrySegments(
              result.segments,
              configuredApiKey: configuredApiKey,
            ),
            words: _sanitizeRetrySegments(
              result.words,
              configuredApiKey: configuredApiKey,
            ),
          ).toMap(),
        );
      } on Object catch (error) {
        if (chunk['status'] == AsrChunkStatus.uncertain.name ||
            chunk['status'] == AsrChunkStatus.succeeded.name ||
            !AsrChunkStatus.values.any(
              (status) => status.name == chunk['status'],
            )) {
          // Dropping an unresolved or successful outcome could make a restart
          // replay a POST whose result cannot be reconstructed.
          if (error is AsrRetryChunkCheckpointUnavailableException) {
            rethrow;
          }
          throw const AsrRetryChunkCheckpointUnavailableException();
        }
        // A malformed checkpoint is omitted so the source chunk is retried.
      }
    }
    return chunks;
  }

  static bool _isIntegerNumber(Object? value) =>
      value is num && value.isFinite && value == value.truncateToDouble();

  static List<AsrTranscriptSegment>? _sanitizeRetrySegments(
    List<AsrTranscriptSegment>? segments, {
    String? configuredApiKey,
  }) {
    if (segments == null) return null;
    return [
      for (final segment in segments)
        if (_hasValidRetrySegmentTiming(segment))
          AsrTranscriptSegment(
            startSeconds: segment.startSeconds,
            endSeconds: segment.endSeconds,
            text: AsrRetryConfigSnapshot.sanitizeTranscriptText(
                  segment.text,
                  configuredApiKey: configuredApiKey,
                ) ??
                (throw const FormatException('Unsafe transcript segment')),
          )
        else
          throw const FormatException('Invalid ASR transcript segment timing'),
    ];
  }

  static bool _hasValidRetrySegmentTiming(AsrTranscriptSegment segment) {
    final startSeconds = segment.startSeconds;
    final endSeconds = segment.endSeconds;
    return (startSeconds == null ||
            (startSeconds.isFinite && startSeconds >= 0)) &&
        (endSeconds == null || (endSeconds.isFinite && endSeconds >= 0)) &&
        (startSeconds == null ||
            endSeconds == null ||
            endSeconds >= startSeconds);
  }

  static Set<String> referencedIds(Map<String, dynamic>? retryData) {
    final ids = <String>{};
    final reference = retryData?['audioReference'];
    final id = reference is Map ? reference['id'] : null;
    if (id is String) ids.add(id);
    final references = retryData?['audioReferences'];
    if (references is List) {
      for (final entry in references) {
        final value = entry is Map ? entry['audioReference'] : null;
        final nestedId = value is Map ? value['id'] : null;
        if (nestedId is String) ids.add(nestedId);
      }
    }
    return ids;
  }

  /// Returns every retry audio ID that can be safely retained from a task
  /// record, or null when its versioned reference ownership is incomplete.
  /// This lets partial task restoration prune unrelated files without
  /// discarding audio still named by an unrestored task.
  static Set<String>? recoverableReferencedIds(
    Map<String, dynamic>? retryData,
  ) {
    if (retryData == null) return <String>{};
    if (retryData.containsKey('version') && retryData['version'] != 2) {
      return null;
    }
    final singleReference = retryData['audioReference'];
    final multipleReferences = retryData['audioReferences'];
    if (singleReference != null && multipleReferences != null) return null;
    if (retryData['version'] == 2 &&
        singleReference == null &&
        multipleReferences == null) {
      return null;
    }

    final ids = <String>{};
    try {
      if (singleReference != null) {
        if (singleReference is! Map) return null;
        final reference = AsrAudioReference.fromMap(
          Map<String, dynamic>.from(singleReference),
        );
        ids.add(reference.id);
      } else if (multipleReferences != null) {
        if (multipleReferences is! List || multipleReferences.isEmpty) {
          return null;
        }
        for (final entry in multipleReferences) {
          if (entry is! Map || entry['audioReference'] is! Map) return null;
          final reference = AsrAudioReference.fromMap(
            Map<String, dynamic>.from(entry['audioReference'] as Map),
          );
          ids.add(reference.id);
        }
      }
    } on Object {
      return null;
    }
    return ids;
  }

  Future<void> protectUntilReferenced(AsrAudioReference reference) async {
    if (reference.isUrl) return;
    _temporaryProtectionCounts.update(
      reference.id,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    // A prune may already be deleting this file. Wait for that exact delete
    // to finish; callers then recreate/verify the file before saving a task
    // reference to it.
    try {
      await _waitForAtomicTempCleanup(reference.id);
      await _deletionsInProgress[reference.id]?.completion.future;
    } catch (_) {
      // The caller's subsequent ensureStored/load verifies the actual bytes.
    }
  }

  Future<void> releaseProtection(AsrAudioReference reference) async {
    if (reference.isUrl) return;
    final count = _temporaryProtectionCounts[reference.id];
    if (count == null) return;
    if (count == 1) {
      _temporaryProtectionCounts.remove(reference.id);
    } else {
      _temporaryProtectionCounts[reference.id] = count - 1;
    }
  }

  /// Saves audio and protects it from pruning until the owning retry record is
  /// durable. Call [releaseProtection] only after that record has been saved.
  Future<AsrAudioReference> save(
    Uint8List bytes, {
    required String name,
    required String format,
    String? configuredApiKey,
    FutureOr<void> Function(AsrAudioReference reference)? onReferenceCreated,
  }) async {
    if (bytes.isEmpty) {
      throw const FormatException('音频数据为空');
    }
    final copy = Uint8List.fromList(bytes);
    final reference = AsrAudioReference(
      id: const Uuid().v4().replaceAll('-', '').toLowerCase(),
      name: sanitizeAudioName(
        name,
        format: format,
        configuredApiKey: configuredApiKey,
      ),
      format: _safeAudioFormat(format),
      byteLength: copy.length,
      sha256: sha256.convert(copy).toString(),
    );
    _validateReference(reference, configuredApiKey: configuredApiKey);
    await protectUntilReferenced(reference);
    try {
      await _adapter.write(_key(reference.id), copy);
      final persisted = await _adapter.read(_key(reference.id));
      if (persisted == null || !_matches(reference, persisted)) {
        throw StateError('无法确认 ASR 重试音频已保存');
      }
      // Keep the source protected until the caller persists its reference,
      // but publish that reference only after the bytes are durable.
      await onReferenceCreated?.call(reference);
      return reference;
    } catch (_) {
      try {
        await _adapter.delete(_key(reference.id));
      } catch (_) {
        // Preserve the storage or publication error; a future prune can
        // remove any unreferenced file if cleanup itself failed.
      }
      await releaseProtection(reference);
      rethrow;
    }
  }

  Future<Uint8List> load(
    AsrAudioReference reference, {
    String? configuredApiKey,
  }) async {
    _validateReference(reference, configuredApiKey: configuredApiKey);
    if (reference.isUrl) {
      throw const FormatException('公网音频链接没有本地音频文件');
    }
    final bytes = await _adapter.read(_key(reference.id));
    if (bytes == null) {
      throw AsrRetryAudioUnavailableException(reference.name);
    }
    if (!_matches(reference, bytes)) {
      throw AsrRetryAudioUnavailableException(reference.name, corrupt: true);
    }
    return Uint8List.fromList(bytes);
  }

  /// Ensures a loaded retry source still exists before associating it with a
  /// new task. It recreates only the exact content named by the reference.
  Future<void> ensureStored(
    AsrAudioReference reference,
    Uint8List bytes, {
    String? configuredApiKey,
  }) async {
    _validateReference(reference, configuredApiKey: configuredApiKey);
    if (reference.isUrl) return;
    if (!_matches(reference, bytes)) {
      throw AsrRetryAudioUnavailableException(reference.name, corrupt: true);
    }
    while (true) {
      final pendingDeletion = _deletionsInProgress[reference.id];
      if (pendingDeletion == null) {
        _audioWriteCounts.update(
          reference.id,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        _audioWriteCompletions.putIfAbsent(
          reference.id,
          Completer<void>.new,
        );
        break;
      }
      await pendingDeletion.completion.future;
    }
    try {
      await _waitForAtomicTempCleanup(reference.id);
      final current = await _adapter.read(_key(reference.id));
      if (current != null) {
        if (!_matches(reference, current)) {
          throw AsrRetryAudioUnavailableException(
            reference.name,
            corrupt: true,
          );
        }
        return;
      }
      await _adapter.write(_key(reference.id), bytes);
      final persisted = await _adapter.read(_key(reference.id));
      if (persisted == null || !_matches(reference, persisted)) {
        throw AsrRetryAudioUnavailableException(reference.name, corrupt: true);
      }
    } finally {
      _finishAudioWrite(reference.id);
    }
  }

  Future<AsrRetryChunkCheckpoint?> readChunkCheckpoint(
    AsrAudioReference reference, {
    required Map<String, String> modelReference,
    String? configSnapshotSha256,
    String? configuredApiKey,
  }) async {
    _validateReference(reference, configuredApiKey: configuredApiKey);
    final configId = _safeModelReferenceId(
      modelReference['configId'],
      configuredApiKey: configuredApiKey,
    );
    final modelId = _safeModelReferenceId(
      modelReference['modelId'],
      configuredApiKey: configuredApiKey,
    );
    if (configId == null || modelId == null) {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    final checkpoints = await _readChunkCheckpoints(
      reference,
      configuredApiKey: configuredApiKey,
    );
    final matchingModel = checkpoints.where(
      (checkpoint) =>
          checkpoint.configId == configId && checkpoint.modelId == modelId,
    );
    if (configSnapshotSha256 == null) {
      for (final checkpoint in matchingModel) {
        return checkpoint;
      }
      return null;
    }
    if (_safeConfigSnapshotSha256(configSnapshotSha256) == null) {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    for (final checkpoint in matchingModel) {
      if (checkpoint.configSnapshotSha256 == configSnapshotSha256) {
        return checkpoint;
      }
    }
    if (matchingModel.any(
      (checkpoint) => checkpoint.chunks.any(
        (chunk) => chunk.status == AsrChunkStatus.uncertain,
      ),
    )) {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    return null;
  }

  Future<void> writeChunkCheckpoint(
    AsrAudioReference reference,
    Iterable<AsrChunkResult> chunks, {
    required Map<String, String> modelReference,
    String? configSnapshotSha256,
    String? configuredApiKey,
    bool allowUncertainToBeResolved = false,
  }) async {
    _validateReference(reference, configuredApiKey: configuredApiKey);
    final configId = _safeModelReferenceId(
      modelReference['configId'],
      configuredApiKey: configuredApiKey,
    );
    final modelId = _safeModelReferenceId(
      modelReference['modelId'],
      configuredApiKey: configuredApiKey,
    );
    if (configId == null || modelId == null) {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    if (configSnapshotSha256 != null &&
        _safeConfigSnapshotSha256(configSnapshotSha256) == null) {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    final chunkMaps = [for (final chunk in chunks) chunk.toMap()];
    final sanitizedChunks = _sanitizeRetryChunks(
      chunkMaps,
      configuredApiKey: configuredApiKey,
    );
    if (sanitizedChunks == null) {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
    final incomingCheckpoint = AsrRetryChunkCheckpoint.fromMap(
      {
        'version': AsrRetryChunkCheckpoint.currentVersion,
        'audioReferenceId': reference.id,
        'audioSha256': reference.sha256,
        'audioUrlSha256': _retryAudioUrlFingerprint(reference),
        'modelReference': {'configId': configId, 'modelId': modelId},
        ...?(configSnapshotSha256 == null
            ? null
            : {'configSnapshotSha256': configSnapshotSha256}),
        'chunks': sanitizedChunks,
      },
      reference: reference,
      configuredApiKey: configuredApiKey,
    );
    final key = _checkpointKey(reference.id);
    final writeEpoch = _beginCheckpointWrite(reference.id);
    try {
      await _waitForAtomicTempCleanup(reference.id);
      await _withCheckpointWriteLock(reference.id, () async {
        if (_deletionsInProgress.containsKey(reference.id) ||
            (_checkpointWriteEpochs[reference.id] ?? 0) != writeEpoch) {
          throw const AsrRetryChunkCheckpointUnavailableException();
        }
        final existingCheckpoints = await _readChunkCheckpoints(
          reference,
          configuredApiKey: configuredApiKey,
        );
        final existingIndex = existingCheckpoints.indexWhere(
          (checkpoint) =>
              checkpoint.configId == configId &&
              checkpoint.modelId == modelId &&
              checkpoint.configSnapshotSha256 == configSnapshotSha256,
        );
        final checkpoint = existingIndex < 0
            ? incomingCheckpoint
            : AsrRetryChunkCheckpoint(
                audioReferenceId: reference.id,
                audioSha256: reference.sha256,
                audioUrlSha256: incomingCheckpoint.audioUrlSha256,
                configId: configId,
                modelId: modelId,
                configSnapshotSha256: configSnapshotSha256,
                chunks: _mergeChunkCheckpointChunks(
                  existingCheckpoints[existingIndex].chunks,
                  incomingCheckpoint.chunks,
                  allowUncertainToBeResolved: allowUncertainToBeResolved,
                ),
              );
        final checkpoints = [
          for (var index = 0; index < existingCheckpoints.length; index++)
            if (index == existingIndex)
              checkpoint
            else
              existingCheckpoints[index],
          if (existingIndex < 0) checkpoint,
        ];
        final collection = _AsrRetryChunkCheckpointCollection(
          audioReferenceId: reference.id,
          audioSha256: reference.sha256,
          checkpoints: checkpoints,
        );
        await _adapter.write(
          key,
          Uint8List.fromList(utf8.encode(jsonEncode(collection.toMap()))),
        );
        final persistedCheckpoints = await _readChunkCheckpoints(
          reference,
          configuredApiKey: configuredApiKey,
        );
        AsrRetryChunkCheckpoint? persisted;
        for (final candidate in persistedCheckpoints) {
          if (candidate.configId == configId &&
              candidate.modelId == modelId &&
              candidate.configSnapshotSha256 == configSnapshotSha256) {
            persisted = candidate;
            break;
          }
        }
        if (persisted == null ||
            jsonEncode(persisted.toMap()) != jsonEncode(checkpoint.toMap())) {
          throw const AsrRetryChunkCheckpointUnavailableException();
        }
      });
    } finally {
      _finishCheckpointWrite(reference.id);
    }
  }

  Future<List<AsrRetryChunkCheckpoint>> _readChunkCheckpoints(
    AsrAudioReference reference, {
    String? configuredApiKey,
  }) async {
    final bytes = await _adapter.read(_checkpointKey(reference.id));
    if (bytes == null) return const [];
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const AsrRetryChunkCheckpointUnavailableException();
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map.containsKey('modelReference') || map.containsKey('chunks')) {
        return [
          AsrRetryChunkCheckpoint.fromMap(
            map,
            reference: reference,
            configuredApiKey: configuredApiKey,
          ),
        ];
      }
      return _AsrRetryChunkCheckpointCollection.fromMap(
        map,
        reference: reference,
        configuredApiKey: configuredApiKey,
      ).checkpoints;
    } on AsrRetryChunkCheckpointUnavailableException {
      rethrow;
    } on Object {
      throw const AsrRetryChunkCheckpointUnavailableException();
    }
  }

  Future<T> _withCheckpointWriteLock<T>(
    String referenceId,
    Future<T> Function() action,
  ) async {
    while (true) {
      final activeLock = _checkpointWriteLocks[referenceId];
      if (activeLock != null) {
        await activeLock.future;
        continue;
      }
      final lock = Completer<void>();
      _checkpointWriteLocks[referenceId] = lock;
      try {
        return await action();
      } finally {
        if (identical(_checkpointWriteLocks[referenceId], lock)) {
          _checkpointWriteLocks.remove(referenceId);
        }
        lock.complete();
      }
    }
  }

  int _beginCheckpointWrite(String referenceId) {
    final epoch = _checkpointWriteEpochs[referenceId] ?? 0;
    _checkpointWriteCounts.update(
      referenceId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    return epoch;
  }

  void _finishCheckpointWrite(String referenceId) {
    final count = _checkpointWriteCounts[referenceId] ?? 0;
    if (count > 1) {
      _checkpointWriteCounts[referenceId] = count - 1;
      return;
    }
    _checkpointWriteCounts.remove(referenceId);
    if (!_deletionsInProgress.containsKey(referenceId)) {
      _checkpointWriteEpochs.remove(referenceId);
    }
  }

  void _advanceCheckpointWriteEpoch(String referenceId) {
    _checkpointWriteEpochs[referenceId] =
        (_checkpointWriteEpochs[referenceId] ?? 0) + 1;
  }

  Future<void> _waitForAtomicTempCleanup(String id) async {
    await _atomicTempCleanupInProgress[id]?.future;
  }

  void _finishAudioWrite(String id) {
    final count = _audioWriteCounts[id] ?? 0;
    if (count > 1) {
      _audioWriteCounts[id] = count - 1;
    } else {
      _audioWriteCounts.remove(id);
      final completion = _audioWriteCompletions.remove(id);
      if (completion != null && !completion.isCompleted) {
        completion.complete();
      }
    }
  }

  Future<void> _waitForAudioWrites(String id) async {
    while (_audioWriteCounts.containsKey(id)) {
      final completion = _audioWriteCompletions[id];
      if (completion == null) return;
      await completion.future;
    }
  }

  Future<void> delete(AsrAudioReference reference) async {
    _validateReference(reference, allowMissingLocalSource: true);
    await _deleteRetryFiles(reference.id, deleteAudio: !reference.isUrl);
  }

  Future<void> clearChunkCheckpoint(
    AsrAudioReference reference, {
    String? configuredApiKey,
  }) async {
    _validateReference(
      reference,
      allowMissingLocalSource: true,
      configuredApiKey: configuredApiKey,
    );
    await _deleteRetryFiles(reference.id, deleteAudio: false);
  }

  /// Deletes one retry file only when no durable or in-flight task refers to
  /// it. This is used when its owning task was removed during audio capture;
  /// pruning the whole namespace there could erase files owned by corrupt or
  /// partially restored task records.
  Future<void> deleteIfUnreferenced(
    AsrAudioReference reference,
    Set<String> referencedIds,
  ) async {
    _validateReference(reference, allowMissingLocalSource: true);
    await _deleteIfUnreferenced(reference.id, () => referencedIds);
  }

  Future<void> _deleteRetryFiles(String id, {required bool deleteAudio}) async {
    final pending = _deletionsInProgress[id];
    if (pending != null) {
      (await pending.completion.future).throwIfFailed();
      if (deleteAudio && !pending.deleteAudio) {
        await _deleteRetryFiles(id, deleteAudio: true);
      }
      return;
    }
    final deletion = _AsrRetryDeletion(deleteAudio: deleteAudio);
    _deletionsInProgress[id] = deletion;
    _advanceCheckpointWriteEpoch(id);
    Object? deletionError;
    StackTrace? deletionStackTrace;
    try {
      await _waitForAudioWrites(id);
      await _withCheckpointWriteLock(id, () async {
        if (deleteAudio) await _adapter.delete(_key(id));
        await _adapter.delete(_checkpointKey(id));
      });
    } catch (error, stackTrace) {
      deletionError = error;
      deletionStackTrace = stackTrace;
      rethrow;
    } finally {
      _advanceCheckpointWriteEpoch(id);
      if (identical(_deletionsInProgress[id], deletion)) {
        _deletionsInProgress.remove(id);
      }
      if (!_checkpointWriteCounts.containsKey(id)) {
        _checkpointWriteEpochs.remove(id);
      }
      deletion.completion.complete(
        _AsrRetryDeletionOutcome(
          error: deletionError,
          stackTrace: deletionStackTrace,
        ),
      );
    }
  }

  Future<void> prune(Set<String> Function() referencedIds) async {
    final keys = await _adapter.keysWithPrefix(_asrRetryAudioPrefix);
    final ids = <String>{};
    final atomicTempKeysById = <String, List<String>>{};
    for (final key in keys) {
      final name = key.startsWith(_asrRetryAudioPrefix)
          ? key.substring(_asrRetryAudioPrefix.length)
          : '';
      if (_asrRetryAtomicTempNamePattern.hasMatch(name)) {
        final id = name.substring(1).split('.').first;
        atomicTempKeysById.putIfAbsent(id, () => []).add(key);
        continue;
      }
      if (!_asrRetryFileNamePattern.hasMatch(name)) {
        continue;
      }
      final id = name.substring(0, name.lastIndexOf('.'));
      ids.add(id);
    }

    final tempCleanupReservations = <String, Completer<void>>{};
    for (final id in atomicTempKeysById.keys) {
      if (_temporaryProtectionCounts.containsKey(id) ||
          _audioWriteCounts.containsKey(id) ||
          _checkpointWriteCounts.containsKey(id) ||
          _atomicTempCleanupInProgress.containsKey(id)) {
        continue;
      }
      final reservation = Completer<void>();
      _atomicTempCleanupInProgress[id] = reservation;
      tempCleanupReservations[id] = reservation;
    }

    try {
      for (final entry in atomicTempKeysById.entries) {
        if (!tempCleanupReservations.containsKey(entry.key)) continue;
        for (final key in entry.value) {
          await _adapter.delete(key);
        }
      }
      for (final id in ids) {
        await _deleteIfUnreferenced(id, referencedIds);
      }
    } finally {
      for (final entry in tempCleanupReservations.entries) {
        if (identical(_atomicTempCleanupInProgress[entry.key], entry.value)) {
          _atomicTempCleanupInProgress.remove(entry.key);
        }
        if (!entry.value.isCompleted) entry.value.complete();
      }
    }
  }

  Future<void> _deleteIfUnreferenced(
    String id,
    Set<String> Function() referencedIds,
  ) async {
    if (referencedIds().contains(id) ||
        _temporaryProtectionCounts.containsKey(id)) {
      return;
    }
    final pending = _deletionsInProgress[id];
    if (pending != null) {
      (await pending.completion.future).throwIfFailed();
      if (pending.deleteAudio) return;
    }
    // Check and mark happen synchronously, so protection cannot be added
    // between the last reference check and the start of deletion.
    if (referencedIds().contains(id) ||
        _temporaryProtectionCounts.containsKey(id)) {
      return;
    }
    await _deleteRetryFiles(id, deleteAudio: true);
  }

  String _key(String id) => '$_asrRetryAudioPrefix$id.audio';
  String _checkpointKey(String id) => '$_asrRetryAudioPrefix$id.chunks';

  void _validateReference(
    AsrAudioReference reference, {
    bool allowMissingLocalSource = false,
    String? configuredApiKey,
  }) {
    final isMissingLocalSource = allowMissingLocalSource &&
        !reference.isUrl &&
        reference.byteLength == 0 &&
        reference.requiresSourceReselection;
    if (!reference.isUrl &&
        reference.byteLength == 0 &&
        !isMissingLocalSource) {
      throw AsrRetryAudioUnavailableException(reference.name, corrupt: true);
    }
    _validateAudioReferenceFields(
      version: reference.version,
      id: reference.id,
      byteLength: reference.byteLength,
      sha256: reference.sha256,
      isUrl: reference.isUrl,
      allowMissingLocalSource: isMissingLocalSource,
      configuredApiKey: configuredApiKey,
    );
  }

  bool _matches(AsrAudioReference reference, Uint8List bytes) =>
      bytes.length == reference.byteLength &&
      sha256.convert(bytes).toString() == reference.sha256;
}

String _safeAudioFormat(String format) =>
    RegExp(r'^[a-z0-9]{1,10}$', caseSensitive: false).hasMatch(format)
        ? format.toLowerCase()
        : 'bin';

List<AsrChunkResult> _mergeChunkCheckpointChunks(
  Iterable<AsrChunkResult> existing,
  Iterable<AsrChunkResult> incoming, {
  bool allowUncertainToBeResolved = false,
}) {
  final existingChunks = existing.toList();
  final incomingChunks = incoming.toList();
  final existingByIndex = {
    for (final chunk in existingChunks) chunk.index: chunk,
  };
  final existingTotalCounts = {
    for (final chunk in existingChunks)
      if (chunk.totalChunks != null) chunk.totalChunks,
  };
  final incomingTotalCounts = {
    for (final chunk in incomingChunks)
      if (chunk.totalChunks != null) chunk.totalChunks,
  };
  final declaredPlansConflict = existingTotalCounts.isNotEmpty &&
      incomingTotalCounts.isNotEmpty &&
      (existingTotalCounts.length != 1 ||
          incomingTotalCounts.length != 1 ||
          existingTotalCounts.single != incomingTotalCounts.single);
  final chunkPlanFingerprintChanged = existingChunks.isNotEmpty &&
      incomingChunks.isNotEmpty &&
      _chunkPlanFingerprintsConflict(existingChunks, incomingChunks);
  final chunkPlanChanged = declaredPlansConflict ||
      chunkPlanFingerprintChanged ||
      _unfingerprintedPlanCannotBeEstablished(existingChunks, incomingChunks) ||
      incomingChunks.any((chunk) {
        final previous = existingByIndex[chunk.index];
        return previous != null && !_sameCheckpointChunkPlan(previous, chunk);
      });
  if (chunkPlanChanged &&
      existingChunks.any((chunk) => chunk.status == AsrChunkStatus.uncertain)) {
    throw const AsrRetryChunkCheckpointUnavailableException();
  }
  final merged = <int, AsrChunkResult>{
    if (!chunkPlanChanged)
      for (final chunk in existingChunks) chunk.index: chunk,
  };
  for (final chunk in incomingChunks) {
    final previous = merged[chunk.index];
    if (previous != null &&
        _sameCheckpointChunkPlan(previous, chunk) &&
        ((previous.status == AsrChunkStatus.succeeded &&
                chunk.status != AsrChunkStatus.succeeded) ||
            (previous.status == AsrChunkStatus.uncertain &&
                chunk.status == AsrChunkStatus.failed &&
                !allowUncertainToBeResolved))) {
      continue;
    }
    merged[chunk.index] = chunk;
  }
  return merged.values.toList()
    ..sort((left, right) => left.index.compareTo(right.index));
}

bool _chunkPlanFingerprintsConflict(
  List<AsrChunkResult> existing,
  List<AsrChunkResult> incoming,
) {
  final existingFingerprints = {
    for (final chunk in existing)
      if (chunk.planFingerprint != null) chunk.planFingerprint,
  };
  final incomingFingerprints = {
    for (final chunk in incoming)
      if (chunk.planFingerprint != null) chunk.planFingerprint,
  };
  if (existingFingerprints.isEmpty && incomingFingerprints.isEmpty) {
    return false;
  }
  return existingFingerprints.length != 1 ||
      incomingFingerprints.length != 1 ||
      existing.any((chunk) => chunk.planFingerprint == null) ||
      incoming.any((chunk) => chunk.planFingerprint == null) ||
      existingFingerprints.single != incomingFingerprints.single;
}

bool _unfingerprintedPlanCannotBeEstablished(
  List<AsrChunkResult> existing,
  List<AsrChunkResult> incoming,
) {
  if (existing.isEmpty ||
      incoming.isEmpty ||
      existing.any((chunk) => chunk.planFingerprint != null) ||
      incoming.any((chunk) => chunk.planFingerprint != null) ||
      existing.any(
        (previous) => incoming.any((chunk) => chunk.index == previous.index),
      )) {
    return false;
  }
  final totalCounts = {
    for (final chunk in [...existing, ...incoming])
      if (chunk.totalChunks != null) chunk.totalChunks,
  };
  if (totalCounts.length != 1) return true;
  final total = totalCounts.single!;
  final chunksByIndex = <int, AsrChunkResult>{};
  for (final chunk in [...existing, ...incoming]) {
    final previous = chunksByIndex[chunk.index];
    if (previous != null && !_sameCheckpointChunkPlan(previous, chunk)) {
      return true;
    }
    chunksByIndex[chunk.index] = chunk;
  }
  if (chunksByIndex.length != total) return true;
  for (var index = 0; index < total; index++) {
    final chunk = chunksByIndex[index];
    if (chunk == null || chunk.totalChunks != total) return true;
    if (index > 0) {
      final previous = chunksByIndex[index - 1]!;
      if (previous.endSeconds != chunk.startSeconds) return true;
    }
  }
  return false;
}

bool _sameCheckpointChunkPlan(AsrChunkResult left, AsrChunkResult right) =>
    left.index == right.index &&
    left.totalChunks == right.totalChunks &&
    left.planFingerprint == right.planFingerprint &&
    (left.planFingerprint == null
        ? left.startSeconds == right.startSeconds &&
            left.endSeconds == right.endSeconds
        : (left.startSeconds - right.startSeconds).abs() < 0.001 &&
            (left.endSeconds - right.endSeconds).abs() < 0.001);

String? _safeModelReferenceId(Object? value, {String? configuredApiKey}) {
  if (value is! String || value.isEmpty || value.length > 512) return null;
  if (_containsConfiguredApiKeyInIdentifier(value, configuredApiKey)) {
    return null;
  }
  if (_isGeneratedModelReferenceId(value)) return value;
  return AsrRetryConfigSnapshot.sanitizeDiagnosticText(value) == value
      ? value
      : null;
}

bool _isGeneratedModelReferenceId(String value) => RegExp(
      r'^(?:config|model)_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);

String? _safeConfigSnapshotSha256(Object? value) =>
    value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value) ? value : null;

bool _containsConfiguredApiKeyInIdentifier(
  String value,
  String? configuredApiKey,
) {
  if (configuredApiKey == null || configuredApiKey.isEmpty) return false;
  // A one-character numeric key is too common in stable model suffixes (for
  // example, "whisper-4") to use as a substring match. For every longer key,
  // including short API keys, reject an identifier that contains the key.
  if (value == configuredApiKey) return true;
  final isSingleDigitKey = configuredApiKey.length == 1 &&
      RegExp(r'^\d$').hasMatch(configuredApiKey);
  return !isSingleDigitKey &&
      _containsConfiguredApiKey(value, configuredApiKey);
}

String _safeAudioReferenceFormat(String format, String? configuredApiKey) =>
    _containsConfiguredApiKey(format, configuredApiKey) ? '' : format;

/// Nonsecret request settings captured for a retry. API credentials always
/// come from the current live provider configuration.
class AsrRetryConfigSnapshot {
  final String host;
  final String model;
  final String? language;
  final Map<String, dynamic> typeConfig;
  final List<Map<String, dynamic>> customParams;
  final String uploadMethod;
  final int maxFileSizeBytes;
  final String preprocessing;
  final String chunking;
  final String compression;
  final String fallbackMethod;

  const AsrRetryConfigSnapshot({
    required this.host,
    required this.model,
    this.language,
    required this.typeConfig,
    required this.customParams,
    required this.uploadMethod,
    required this.maxFileSizeBytes,
    required this.preprocessing,
    required this.chunking,
    required this.compression,
    required this.fallbackMethod,
  });

  static Map<String, dynamic> sanitizeDiagnosticMap(
    Map values, {
    String? configuredApiKey,
  }) =>
      _sanitizeMap(values, configuredApiKey: configuredApiKey);

  static String sanitizeDiagnosticUrl(
    String value, {
    String? configuredApiKey,
  }) =>
      _sanitizeHost(value, configuredApiKey: configuredApiKey);

  static bool urlContainsCredentials(
    String value, {
    String? configuredApiKey,
  }) =>
      _urlContainsCredentials(value, configuredApiKey: configuredApiKey);

  static String fingerprintFromConfig(AsrConfig config) {
    final sanitizedSnapshot = AsrRetryConfigSnapshot.fromConfig(config).toMap();
    return sha256
        .convert(utf8.encode(jsonEncode(sanitizedSnapshot)))
        .toString();
  }

  static String sanitizeDiagnosticText(
    String value, {
    String? configuredApiKey,
  }) {
    final sanitized = _sanitizeDiagnosticString(
      value,
      configuredApiKey: configuredApiKey,
    );
    if (sanitized != null) return sanitized;
    const fallback = 'ASR error details were redacted';
    return _containsConfiguredApiKey(fallback, configuredApiKey)
        ? ''
        : fallback;
  }

  static String? sanitizeTranscriptText(
    String value, {
    String? configuredApiKey,
  }) {
    final sanitized = _sanitizeDiagnosticString(
      value,
      configuredApiKey: configuredApiKey,
    );
    if (sanitized != null) return sanitized;

    final canPreserveNaturalText = _looksLikeNaturalLanguageTranscript(value) &&
        !_containsConfiguredApiKey(value, configuredApiKey) &&
        !_containsEncodedConfiguredApiKey(value, configuredApiKey) &&
        !_looksCredentialLike(value) &&
        _sanitizeCredentialPathsInText(value) == value &&
        !_embeddedHttpUrlPattern.hasMatch(value) &&
        !RegExp(r'data:[^,]*;base64,', caseSensitive: false).hasMatch(value);
    return canPreserveNaturalText ? value : null;
  }

  factory AsrRetryConfigSnapshot.fromConfig(AsrConfig config) =>
      AsrRetryConfigSnapshot(
        host: _sanitizeHost(config.host, configuredApiKey: config.apiKey),
        model: _safeRetryModel(config.model, configuredApiKey: config.apiKey),
        language: _safeRetryLanguage(
          config.language,
          configuredApiKey: config.apiKey,
        ),
        typeConfig: _sanitizeMap(
          config.typeConfig,
          configuredApiKey: config.apiKey,
        ),
        customParams: _sanitizeCustomParams(
          config.customParams.map((param) => param.toMap()),
          configuredApiKey: config.apiKey,
        ),
        uploadMethod: _safeRetryUploadMethodForStorage(
          config.uploadMethod.name,
          configuredApiKey: config.apiKey,
        ),
        maxFileSizeBytes: _safeMaxFileSizeBytes(config.maxFileSizeBytes),
        preprocessing: _safeRetryOptionForStorage(
          config.preprocessing,
          allowedValues: _retryPreprocessingOptions,
          configuredApiKey: config.apiKey,
        ),
        chunking: _safeRetryOptionForStorage(
          config.chunking,
          allowedValues: _retryChunkingOptions,
          configuredApiKey: config.apiKey,
        ),
        compression: _safeRetryOptionForStorage(
          config.compression,
          allowedValues: _retryCompressionOptions,
          configuredApiKey: config.apiKey,
        ),
        fallbackMethod: _safeRetryOptionForStorage(
          config.fallbackMethod,
          allowedValues: _retryFallbackOptions,
          configuredApiKey: config.apiKey,
        ),
      );

  factory AsrRetryConfigSnapshot.fromMap(
    Map<String, dynamic> map, {
    String? configuredApiKey,
  }) {
    return AsrRetryConfigSnapshot(
      host: _sanitizeHost(
        map['host'] as String? ?? '',
        configuredApiKey: configuredApiKey,
      ),
      // The live model is supplied only after the stable provider reference
      // resolves, so a missing snapshot field must remain eligible for that
      // validated fallback instead of inventing a different model.
      model: _safeRetryModel(
        map['model'] as String? ?? '',
        configuredApiKey: configuredApiKey,
      ),
      language: _safeRetryLanguage(
        map['language'] as String?,
        configuredApiKey: configuredApiKey,
      ),
      typeConfig: _sanitizeMap(
        map['typeConfig'] as Map? ?? const {},
        configuredApiKey: configuredApiKey,
      ),
      customParams: _sanitizeCustomParams(
        map['customParams'] as List? ?? const [],
        configuredApiKey: configuredApiKey,
      ),
      uploadMethod: _safeRetryUploadMethodFromStorage(
        map['uploadMethod'],
        configuredApiKey: configuredApiKey,
      ),
      maxFileSizeBytes: _safeMaxFileSizeBytes(map['maxFileSizeBytes']),
      preprocessing: _safeRetryOptionFromStorage(
        map['preprocessing'] as String? ?? 'none',
        allowedValues: _retryPreprocessingOptions,
        configuredApiKey: configuredApiKey,
      ),
      chunking: _safeRetryOptionFromStorage(
        map['chunking'] as String? ?? 'none',
        allowedValues: _retryChunkingOptions,
        configuredApiKey: configuredApiKey,
      ),
      compression: _safeRetryOptionFromStorage(
        map['compression'] as String? ?? 'none',
        allowedValues: _retryCompressionOptions,
        configuredApiKey: configuredApiKey,
      ),
      fallbackMethod: _safeRetryOptionFromStorage(
        map['fallbackMethod'] as String? ?? 'none',
        allowedValues: _retryFallbackOptions,
        configuredApiKey: configuredApiKey,
      ),
    );
  }

  Map<String, dynamic> toMap({String? configuredApiKey}) {
    final safeLanguage = _safeRetryLanguage(
      language,
      configuredApiKey: configuredApiKey,
    );
    final data = <String, dynamic>{
      'host': _sanitizeHost(host, configuredApiKey: configuredApiKey),
      'model': _safeRetryModel(model, configuredApiKey: configuredApiKey),
      'typeConfig': _sanitizeMap(
        typeConfig,
        configuredApiKey: configuredApiKey,
      ),
      'customParams': _sanitizeCustomParams(
        customParams,
        configuredApiKey: configuredApiKey,
      ),
      'uploadMethod': _safeRetryUploadMethodFromStorage(
        uploadMethod,
        configuredApiKey: configuredApiKey,
      ),
      'maxFileSizeBytes': _safeMaxFileSizeBytes(maxFileSizeBytes),
      'preprocessing': _safeRetryOptionFromStorage(
        preprocessing,
        allowedValues: _retryPreprocessingOptions,
        configuredApiKey: configuredApiKey,
      ),
      'chunking': _safeRetryOptionFromStorage(
        chunking,
        allowedValues: _retryChunkingOptions,
        configuredApiKey: configuredApiKey,
      ),
      'compression': _safeRetryOptionFromStorage(
        compression,
        allowedValues: _retryCompressionOptions,
        configuredApiKey: configuredApiKey,
      ),
      'fallbackMethod': _safeRetryOptionFromStorage(
        fallbackMethod,
        allowedValues: _retryFallbackOptions,
        configuredApiKey: configuredApiKey,
      ),
    };
    if (safeLanguage != null) data['language'] = safeLanguage;
    return data;
  }

  AsrConfig toConfig({
    required String apiKey,
    required String liveHost,
    required String liveModel,
  }) {
    final safeLiveHost = _sanitizeHost(liveHost, configuredApiKey: apiKey);
    if (safeLiveHost.isEmpty || safeLiveHost != host) {
      throw StateError('供应商地址已变更，请重新选择识别模型');
    }
    final resolvedModel = _safeRetryModel(
      model.isEmpty ? liveModel : model,
      configuredApiKey: apiKey,
    );
    if (resolvedModel.isEmpty) {
      throw StateError('识别模型名称无效，请重新选择识别模型');
    }
    if (uploadMethod.isEmpty) {
      throw StateError('识别上传方式无法安全恢复，请重新选择识别模型');
    }
    return AsrConfig(
      host: liveHost,
      apiKey: apiKey,
      model: resolvedModel,
      language: _safeRetryLanguage(language, configuredApiKey: apiKey),
      typeConfig: _sanitizeMap(typeConfig, configuredApiKey: apiKey),
      customParams: [
        for (final value in _sanitizeCustomParams(
          customParams,
          configuredApiKey: apiKey,
        ))
          CustomParam.fromMap(value),
      ],
      uploadMethod: _safeRetryUploadMethod(uploadMethod),
      maxFileSizeBytes: _safeMaxFileSizeBytes(maxFileSizeBytes),
      preprocessing: _retryOptionForConfig(
        preprocessing,
        allowedValues: _retryPreprocessingOptions,
      ),
      chunking: _retryOptionForConfig(
        chunking,
        allowedValues: _retryChunkingOptions,
      ),
      compression: _retryOptionForConfig(
        compression,
        allowedValues: _retryCompressionOptions,
      ),
      fallbackMethod: _retryOptionForConfig(
        fallbackMethod,
        allowedValues: _retryFallbackOptions,
      ),
    );
  }
}

bool _containsConfiguredApiKey(String value, String? configuredApiKey) {
  if (configuredApiKey == null || configuredApiKey.isEmpty) return false;
  var candidate = value;
  while (true) {
    if (_configuredApiKeyVariants(
      configuredApiKey,
      candidate.length,
    ).any(candidate.contains)) {
      return true;
    }
    String decoded;
    try {
      decoded = Uri.decodeComponent(candidate);
    } on FormatException {
      return true;
    } on ArgumentError {
      return true;
    }
    if (decoded == candidate) return false;
    candidate = decoded;
  }
}

String _removeConfiguredApiKey(String value, String? configuredApiKey) {
  if (configuredApiKey == null || configuredApiKey.isEmpty) return value;
  final variants = _configuredApiKeyVariants(configuredApiKey, value.length)
      .toSet()
      .toList()
    ..sort((left, right) => right.length.compareTo(left.length));
  final boundaryCharacters = _isCredentialName(configuredApiKey) &&
          RegExp(r'[-_.\s]').hasMatch(configuredApiKey)
      ? 'a-z0-9'
      : 'a-z0-9_';
  var sanitized = value;
  for (final variant in variants) {
    if (_isCredentialName(configuredApiKey) &&
        RegExp(r'^[a-z0-9_-]+$', caseSensitive: false).hasMatch(variant)) {
      sanitized = sanitized.replaceAll(
        RegExp(
          '(?<![$boundaryCharacters])${RegExp.escape(variant)}(?![$boundaryCharacters])',
          caseSensitive: false,
        ),
        '',
      );
    } else {
      sanitized = sanitized.replaceAll(variant, '');
    }
  }
  return sanitized;
}

bool _containsEncodedConfiguredApiKey(String value, String? configuredApiKey) {
  if (configuredApiKey == null || configuredApiKey.isEmpty) return false;
  var candidate = value;
  while (true) {
    String decoded;
    try {
      decoded = Uri.decodeComponent(candidate);
    } on FormatException {
      return false;
    } on ArgumentError {
      return false;
    }
    if (decoded == candidate) return false;
    if (_removeConfiguredApiKey(decoded, configuredApiKey) != decoded ||
        _containsConfiguredApiKeyInAlphanumericToken(
          decoded,
          configuredApiKey,
        )) {
      return true;
    }
    candidate = decoded;
  }
}

bool _containsConfiguredApiKeyInAlphanumericToken(
  String value,
  String? configuredApiKey,
) {
  if (configuredApiKey == null ||
      configuredApiKey.isEmpty ||
      !_isCredentialName(configuredApiKey)) {
    return false;
  }
  final alphanumeric = RegExp(r'[a-z0-9]', caseSensitive: false);
  final lowerValue = value.toLowerCase();
  for (final variant in _configuredApiKeyVariants(
    configuredApiKey,
    value.length,
  )) {
    final lowerVariant = variant.toLowerCase();
    if (lowerVariant.isEmpty) continue;
    var offset = 0;
    while (true) {
      final start = lowerValue.indexOf(lowerVariant, offset);
      if (start < 0) break;
      final end = start + lowerVariant.length;
      final hasAlphanumericPrefix =
          start > 0 && alphanumeric.hasMatch(value[start - 1]);
      final hasAlphanumericSuffix =
          end < value.length && alphanumeric.hasMatch(value[end]);
      if (hasAlphanumericPrefix || hasAlphanumericSuffix) return true;
      offset = end;
    }
  }
  return false;
}

Iterable<String> _configuredApiKeyVariants(String apiKey, int maxLength) sync* {
  final percentEscape = RegExp(r'%[0-9a-f]{2}', caseSensitive: false);
  for (var encoded in {apiKey, Uri.encodeQueryComponent(apiKey)}) {
    while (encoded.length <= maxLength) {
      yield encoded;
      final lowercaseEscapes = encoded.replaceAllMapped(
        percentEscape,
        (match) => match[0]!.toLowerCase(),
      );
      if (lowercaseEscapes != encoded) yield lowercaseEscapes;
      final next = Uri.encodeComponent(encoded);
      if (next == encoded) break;
      encoded = next;
    }
  }
}

String? _safeRetryLanguage(String? language, {String? configuredApiKey}) =>
    language == null || _containsConfiguredApiKey(language, configuredApiKey)
        ? null
        : _sanitizeDiagnosticString(language,
            configuredApiKey: configuredApiKey);

String _safeRetryModel(String model, {String? configuredApiKey}) =>
    _containsConfiguredApiKey(model, configuredApiKey)
        ? ''
        : _sanitizeDiagnosticString(model,
                configuredApiKey: configuredApiKey) ??
            '';

const _retryPreprocessingOptions = {'none', 'resampleMono'};
const _retryChunkingOptions = {'none', 'silence', 'fixedDuration', 'fixedSize'};
const _retryCompressionOptions = {'none', 'adpcm', 'flac'};
const _retryFallbackOptions = {'none', 'specific', 'generic', 'all'};

AudioUploadMethod _safeRetryUploadMethod(Object? value) =>
    AudioUploadMethod.values.firstWhere(
      (method) => method.name == value,
      orElse: () => AudioUploadMethod.multipart,
    );

String _safeRetryUploadMethodForStorage(
  String value, {
  String? configuredApiKey,
}) =>
    _containsConfiguredApiKey(value, configuredApiKey) ? '' : value;

String _safeRetryUploadMethodFromStorage(
  Object? value, {
  String? configuredApiKey,
}) {
  if (value is String && _containsConfiguredApiKey(value, configuredApiKey)) {
    return '';
  }
  final safeValue = value == '' ? '' : _safeRetryUploadMethod(value).name;
  return _containsConfiguredApiKey(safeValue, configuredApiKey)
      ? ''
      : safeValue;
}

String _safeRetryOption(
  String value, {
  required Set<String> allowedValues,
  String? configuredApiKey,
}) =>
    !allowedValues.contains(value) ||
            _containsConfiguredApiKey(value, configuredApiKey)
        ? 'none'
        : value;

String _safeRetryOptionForStorage(
  String value, {
  required Set<String> allowedValues,
  String? configuredApiKey,
}) {
  final safeValue = _safeRetryOption(value, allowedValues: allowedValues);
  return _containsConfiguredApiKey(safeValue, configuredApiKey)
      ? ''
      : safeValue;
}

int _safeMaxFileSizeBytes(Object? value) {
  final parsed = value is num ? value.toInt() : null;
  return parsed != null && parsed > 0
      ? parsed
      : AsrConfig.defaultMaxAudioFileSizeBytes;
}

String _safeRetryOptionFromStorage(
  String value, {
  required Set<String> allowedValues,
  String? configuredApiKey,
}) {
  if (value.isEmpty) return '';
  final safeValue = _safeRetryOption(
    value,
    allowedValues: allowedValues,
    configuredApiKey: configuredApiKey,
  );
  return _containsConfiguredApiKey(safeValue, configuredApiKey)
      ? ''
      : safeValue;
}

String _retryOptionForConfig(
  String value, {
  required Set<String> allowedValues,
}) =>
    value.isEmpty
        ? 'none'
        : _safeRetryOption(value, allowedValues: allowedValues);

Uri? _parseRetryUri(String value) {
  final uri = Uri.tryParse(value);
  if (_isAbsoluteHttpUri(uri)) return uri;

  final decoded = _decodePathSegment(value);
  if (decoded == null || decoded == value) return uri;
  final decodedUri = Uri.tryParse(decoded);
  return _isAbsoluteHttpUri(decodedUri) ? decodedUri : uri;
}

bool _isAbsoluteHttpUri(Uri? uri) =>
    uri != null &&
    (uri.scheme.toLowerCase() == 'http' ||
        uri.scheme.toLowerCase() == 'https') &&
    uri.hasAuthority &&
    uri.host.isNotEmpty;

bool _authorityContainsEncodedUserInfo(Uri uri) {
  final authority = uri.authority;
  final decodedAuthority = _decodePathSegment(authority);
  if (decodedAuthority == null) return authority.contains('%');
  return '@'.allMatches(decodedAuthority).length >
      '@'.allMatches(authority).length;
}

String _sanitizeHost(String host, {String? configuredApiKey}) {
  final uri = _parseRetryUri(host);
  if (uri == null) return '';
  if (_authorityContainsEncodedUserInfo(uri) ||
      _uriContainsEmbeddedAudioPayload(uri)) {
    return '';
  }
  if (_looksCredentialLike(uri.host) ||
      _containsConfiguredApiKey(uri.host, configuredApiKey)) {
    return '';
  }
  final safePathSegments = _sanitizePathSegments(
    uri.pathSegments,
    configuredApiKey: configuredApiKey,
  );
  final pathChanged = _segmentsChanged(uri.pathSegments, safePathSegments);
  final safeQuery = _sanitizeUriQuery(
    uri.query,
    configuredApiKey: configuredApiKey,
  );
  final queryChanged = safeQuery != uri.query;
  final safeFragment = _sanitizeUriFragment(
    uri.fragment,
    configuredApiKey: configuredApiKey,
  );
  final fragmentChanged = safeFragment != uri.fragment;
  if (uri.userInfo.isEmpty &&
      !pathChanged &&
      !queryChanged &&
      !fragmentChanged) {
    return _removeConfiguredApiKey(host, configuredApiKey);
  }
  final sanitized = uri
      .replace(
        userInfo: uri.userInfo.isEmpty ? null : '',
        pathSegments: pathChanged ? safePathSegments : null,
        query: queryChanged ? safeQuery : null,
        fragment: fragmentChanged ? safeFragment : null,
      )
      .toString();
  return _removeConfiguredApiKey(sanitized, configuredApiKey);
}

bool _urlContainsCredentials(String value, {String? configuredApiKey}) {
  if (_containsConfiguredApiKey(value, configuredApiKey)) return true;
  final uri = _parseRetryUri(value);
  if (uri == null) return true;
  return _authorityContainsEncodedUserInfo(uri) ||
      uri.userInfo.isNotEmpty ||
      _looksCredentialLike(uri.host) ||
      _queryContainsCredentials(uri.query) ||
      _segmentsChanged(
        uri.pathSegments,
        _sanitizePathSegments(uri.pathSegments),
      ) ||
      _sanitizeUriFragment(uri.fragment) != uri.fragment;
}

String _sanitizeUriQuery(String query, {String? configuredApiKey}) {
  if (query.isEmpty) return query;
  final safeComponents = <String>[];
  for (final component in query.split('&')) {
    if (component.isEmpty) {
      safeComponents.add(component);
      continue;
    }
    final separator = component.indexOf('=');
    final rawName =
        separator < 0 ? component : component.substring(0, separator);
    final rawValue = separator < 0 ? '' : component.substring(separator + 1);
    String name;
    String value;
    try {
      name = Uri.decodeQueryComponent(rawName);
      while (true) {
        final decodedName = Uri.decodeComponent(name);
        if (decodedName == name) break;
        name = decodedName;
      }
      value = Uri.decodeQueryComponent(rawValue);
    } on FormatException {
      // Malformed query encoding cannot be inspected reliably for credentials.
      continue;
    }
    if (!_containsConfiguredApiKey(name, configuredApiKey) &&
        !_queryNameContainsCredentials(name) &&
        !_looksCredentialLike(name) &&
        !_containsUnsafeQueryValue(
          value,
          configuredApiKey: configuredApiKey,
          queryName: name,
        )) {
      safeComponents.add(component);
    }
  }
  return safeComponents.join('&');
}

bool _queryNameContainsCredentials(String name) {
  final bracketedNames = RegExp(r'\[([^\]]*)\]');
  return name.split(';').any((part) {
    var candidate = part.trim();
    while (true) {
      if (_isCredentialName(candidate) ||
          bracketedNames
              .allMatches(candidate)
              .any((match) => _isCredentialName(match[1]!))) {
        return true;
      }
      final withoutArraySuffix = candidate.replaceFirst(
        RegExp(r'(?:\[[^\]]*\])+$'),
        '',
      );
      if (withoutArraySuffix == candidate) return false;
      candidate = withoutArraySuffix;
    }
  });
}

bool _containsUnsafeQueryValue(
  String value, {
  String? configuredApiKey,
  String? queryName,
}) {
  var candidate = value;
  while (true) {
    if (_containsConfiguredApiKey(candidate, configuredApiKey) ||
        _looksCredentialLike(candidate) ||
        _sanitizeCredentialPathsInText(candidate) != candidate ||
        _containsInlineAudioPayload(candidate)) {
      return true;
    }
    for (final match in _embeddedHttpUrlPattern.allMatches(candidate)) {
      final url = match[0]!;
      if (_sanitizeHost(url) != url) return true;
    }

    String decoded;
    try {
      decoded = Uri.decodeComponent(candidate);
    } on FormatException {
      return _encodedHttpUrlPattern.hasMatch(candidate);
    }
    if (decoded == candidate) {
      return _containsShortBase64PayloadOutsideUrls(candidate) &&
          !_isKnownIdentifierQueryValue(queryName, candidate);
    }
    candidate = decoded;
  }
}

bool _queryContainsCredentials(String query) =>
    _sanitizeUriQuery(query) != query;

bool _segmentsChanged(List<String> original, List<String> sanitized) =>
    original.length != sanitized.length ||
    sanitized.asMap().entries.any(
          (entry) => entry.value != original[entry.key],
        );

bool _urlContainsEmbeddedAudioPayload(String value) {
  final uri = _parseRetryUri(value);
  return uri != null && _uriContainsEmbeddedAudioPayload(uri);
}

bool _uriContainsEmbeddedAudioPayload(Uri uri) {
  if (uri.scheme.toLowerCase() == 'data' ||
      uri.host.split('.').any(_looksLikeShortBase64PathPayload) ||
      _containsInlineAudioPayload(uri.path) ||
      _containsInlineAudioPayload(uri.fragment) ||
      _containsShortBase64PayloadOutsideUrls(uri.fragment)) {
    return true;
  }
  final pathSegments = uri.pathSegments;
  final decodedPathSegments = [
    for (final segment in pathSegments) _decodePathSegment(segment) ?? segment,
  ];
  for (var index = 0; index < pathSegments.length; index++) {
    final decodedSegment = _decodePathSegment(pathSegments[index]);
    if (decodedSegment == null || _containsInlineAudioPayload(decodedSegment)) {
      return true;
    }
    final followsCredentialMarker =
        index > 0 && _isCredentialPathMarkerAt(decodedPathSegments, index - 1);
    if (!followsCredentialMarker &&
        _looksLikeShortBase64PathPayload(decodedSegment)) {
      return true;
    }
  }
  for (var index = 0; index < pathSegments.length - 1; index++) {
    final suffixSegments = decodedPathSegments.skip(index + 1).toList();
    final identifierIndex = suffixSegments.indexWhere(
      _isKnownIdentifierPathSegment,
    );
    final payloadSegments = identifierIndex < 0
        ? suffixSegments
        : suffixSegments.take(identifierIndex).toList();
    if (payloadSegments.isNotEmpty &&
        _looksLikeShortBase64PathPayload(payloadSegments.join('/'))) {
      return true;
    }
  }
  for (final component in uri.query.split('&')) {
    if (component.isEmpty) continue;
    final separator = component.indexOf('=');
    final rawName =
        separator < 0 ? component : component.substring(0, separator);
    final rawValue = separator < 0 ? '' : component.substring(separator + 1);
    String name;
    String value;
    try {
      name = Uri.decodeQueryComponent(rawName);
      while (true) {
        final decodedName = Uri.decodeComponent(name);
        if (decodedName == name) break;
        name = decodedName;
      }
      value = Uri.decodeQueryComponent(rawValue);
    } on FormatException {
      return true;
    }
    if (_containsInlineAudioPayload(value) ||
        (!_isCredentialName(name) &&
            !_looksCredentialLike(name) &&
            _containsShortBase64PayloadOutsideUrls(value) &&
            !_isKnownIdentifierQueryValue(name, value))) {
      return true;
    }
  }
  return false;
}

bool _containsInlineAudioPayload(String value) {
  final trimmed = value.trim();
  return RegExp(
        r'data:[^,]*;base64,',
        caseSensitive: false,
      ).hasMatch(trimmed) ||
      RegExp(r'[A-Za-z0-9+/=_\s-]{256,}').hasMatch(trimmed);
}

bool _looksLikeContiguousBase64Payload(String value) {
  final trimmed = value.trim();
  // A 16-byte payload is only 24 characters in Base64. Keep this generic
  // detector whitespace-free so ordinary prose and URL path labels survive.
  return trimmed.length >= 24 &&
      RegExp(r'^[A-Za-z0-9+/=_-]+$').hasMatch(trimmed) &&
      _sanitizeCredentialPathsInText(value) == value;
}

bool _looksLikeShortBase64PathPayload(String value) {
  final trimmed = value.trim();
  return !_isKnownIdentifierPathSegment(trimmed) &&
      _looksLikeContiguousBase64Payload(trimmed);
}

bool _isKnownIdentifierPathSegment(String value) {
  final trimmed = value.trim();
  return _knownIdentifierPathSegmentPattern.hasMatch(trimmed) &&
      !_looksLikeRepeatedBase64Payload(trimmed);
}

bool _looksLikeRepeatedBase64Payload(String value) =>
    value.length >= 32 &&
    value.codeUnits.every((codeUnit) => codeUnit == value.codeUnitAt(0));

bool _isKnownIdentifierQueryValue(String? name, String value) {
  if (name == null ||
      _queryNameContainsCredentials(name) ||
      _looksCredentialLike(name)) {
    return false;
  }
  final normalizedName = name.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
  final isIdentifierName = normalizedName == 'id' ||
      normalizedName.endsWith('id') ||
      normalizedName.endsWith('uuid') ||
      normalizedName.endsWith('guid') ||
      normalizedName.endsWith('identifier') ||
      normalizedName.endsWith('hash') ||
      normalizedName.endsWith('digest');
  return isIdentifierName && _isKnownIdentifierPathSegment(value);
}

bool _containsShortBase64Payload(String value) {
  final payloadPattern = RegExp(
    r'(?<![A-Za-z0-9+/=_-])[A-Za-z0-9+/=_-]{24,}(?![A-Za-z0-9+/=_-])',
  );
  for (final match in payloadPattern.allMatches(value)) {
    if (_looksLikeContiguousBase64Payload(match[0]!)) return true;
  }
  final wrappedPayloadPattern = RegExp(
    r'(?<![A-Za-z0-9+/=_-])[A-Za-z0-9+/=_-]{1,31}(?:(?:[ \t]*\r?\n[ \t]*|[ \t]+)[A-Za-z0-9+/=_-]{1,31})+(?![A-Za-z0-9+/=_-])',
  );
  for (final match in wrappedPayloadPattern.allMatches(value)) {
    final chunks = match[0]!.trim().split(RegExp(r'[ \t\r\n]+'));
    if (_looksLikeWrappedBase64Payload(chunks)) return true;
  }
  return false;
}

bool _looksLikeWrappedBase64Payload(List<String> chunks) {
  if (chunks.length < 2 ||
      chunks.take(chunks.length - 1).any((chunk) => chunk.length < 8)) {
    return false;
  }
  final compact = chunks.join();
  if (!_looksLikeContiguousBase64Payload(compact)) return false;
  if (_hasRepeatedBase64Pattern(compact)) return true;

  final characterCounts = <int, int>{};
  for (final codeUnit in compact.codeUnits) {
    characterCounts.update(codeUnit, (count) => count + 1, ifAbsent: () => 1);
  }
  final length = compact.length;
  final entropy = characterCounts.values.fold<double>(
    0,
    (total, count) {
      final probability = count / length;
      return total - probability * (math.log(probability) / math.ln2);
    },
  );
  // Ordinary multiword text also uses the Base64 alphabet. Wrapped audio has
  // more varied characters; this avoids redacting prose while catching groups
  // that were split at uneven positions.
  return entropy >= 4.25;
}

bool _hasRepeatedBase64Pattern(String value) {
  final unpadded = value.replaceFirst(RegExp(r'=+$'), '');
  for (var patternLength = 1; patternLength <= 4; patternLength++) {
    if (unpadded.length % patternLength != 0) continue;
    var repeatsPattern = true;
    for (var index = patternLength; index < unpadded.length; index++) {
      if (unpadded.codeUnitAt(index) !=
          unpadded.codeUnitAt(index % patternLength)) {
        repeatsPattern = false;
        break;
      }
    }
    if (repeatsPattern) return true;
  }
  return false;
}

bool _containsShortBase64PayloadOutsideUrls(String value) {
  var decodedValue = value;
  while (true) {
    String decoded;
    try {
      decoded = Uri.decodeComponent(decodedValue);
    } on FormatException {
      break;
    } on ArgumentError {
      break;
    }
    if (decoded == decodedValue) break;
    decodedValue = decoded;
  }

  var previousEnd = 0;
  for (final match in _embeddedHttpUrlPattern.allMatches(decodedValue)) {
    if (_containsShortBase64Payload(
      decodedValue.substring(previousEnd, match.start),
    )) {
      return true;
    }
    previousEnd = match.end;
  }
  return _containsShortBase64Payload(decodedValue.substring(previousEnd));
}

String _sanitizeUriFragment(String fragment, {String? configuredApiKey}) {
  if (_containsConfiguredApiKey(fragment, configuredApiKey) ||
      _looksCredentialLike(fragment) ||
      _looksLikeBase64Payload(fragment)) {
    return '';
  }
  final pathSanitized = _sanitizeCredentialPathsInText(fragment);
  return pathSanitized.replaceAllMapped(
    _embeddedHttpUrlPattern,
    (match) => _sanitizeHost(match[0]!, configuredApiKey: configuredApiKey),
  );
}

String? _decodePathSegment(String value) {
  var decoded = value;
  final encodedByte = RegExp(r'%[0-9a-f]{2}', caseSensitive: false);
  final malformedEscape = RegExp(r'%(?![0-9a-f]{2})', caseSensitive: false);
  while (encodedByte.hasMatch(decoded)) {
    if (malformedEscape.hasMatch(decoded)) return null;
    try {
      final next = Uri.decodeComponent(decoded);
      if (next == decoded) break;
      decoded = next;
    } on FormatException {
      return null;
    }
  }
  if (malformedEscape.hasMatch(decoded)) return null;
  return decoded;
}

List<String> _sanitizePathSegments(
  List<String> pathSegments, {
  String? configuredApiKey,
}) {
  final expandedSegments = <String>[];
  final segmentOwners = <int>[];
  final expandedPartsBySegment = List.generate(
    pathSegments.length,
    (_) => <String>[],
  );
  final malformedSegments = List.filled(pathSegments.length, false);
  for (var index = 0; index < pathSegments.length; index++) {
    final decodedSegment = _decodePathSegment(pathSegments[index]);
    malformedSegments[index] = decodedSegment == null;
    final parts = (decodedSegment ?? pathSegments[index])
        .replaceAll('\\', '/')
        .split('/');
    expandedSegments.addAll(parts);
    expandedPartsBySegment[index].addAll(parts);
    segmentOwners.addAll(List.filled(parts.length, index));
  }

  final safePartsBySegment = List.generate(
    pathSegments.length,
    (_) => <String>[],
  );
  final removedPartsBySegment = List.generate(
    pathSegments.length,
    (index) => malformedSegments[index],
  );
  for (var index = 0; index < expandedSegments.length; index++) {
    final segment = expandedSegments[index];
    final owner = segmentOwners[index];
    if (malformedSegments[owner]) {
      for (var suffixIndex = index + 1;
          suffixIndex < expandedSegments.length;
          suffixIndex++) {
        removedPartsBySegment[segmentOwners[suffixIndex]] = true;
      }
      break;
    }
    if (removedPartsBySegment[owner]) continue;
    if (_containsConfiguredApiKey(segment, configuredApiKey)) {
      removedPartsBySegment[owner] = true;
      for (var suffixIndex = index + 1;
          suffixIndex < expandedSegments.length;
          suffixIndex++) {
        removedPartsBySegment[segmentOwners[suffixIndex]] = true;
      }
      break;
    }
    final embeddedCredential = RegExp(
      r'^([^:=/]+)(?:[:=/].*)$',
    ).firstMatch(segment);
    if (embeddedCredential != null &&
        _isCredentialName(embeddedCredential[1]!)) {
      safePartsBySegment[owner].add(embeddedCredential[1]!);
      removedPartsBySegment[owner] = true;
      for (var suffixIndex = index + 1;
          suffixIndex < expandedSegments.length;
          suffixIndex++) {
        removedPartsBySegment[segmentOwners[suffixIndex]] = true;
      }
      break;
    }
    if (_isCredentialPathMarkerAt(expandedSegments, index)) {
      safePartsBySegment[owner].add(segment);
      for (var suffixIndex = index + 1;
          suffixIndex < expandedSegments.length;
          suffixIndex++) {
        removedPartsBySegment[segmentOwners[suffixIndex]] = true;
      }
      break;
    }
    if (!_looksCredentialLike(segment)) {
      safePartsBySegment[owner].add(segment);
    } else {
      removedPartsBySegment[owner] = true;
    }
  }
  final safeSegments = <String>[];
  for (var index = 0; index < pathSegments.length; index++) {
    final safeSegment = safePartsBySegment[index].join('/');
    final analyzedSegment = expandedPartsBySegment[index].join('/');
    final changed =
        removedPartsBySegment[index] || safeSegment != analyzedSegment;
    if (!changed) {
      safeSegments.add(pathSegments[index]);
    } else if (safePartsBySegment[index].isNotEmpty) {
      safeSegments.add(safeSegment);
    }
  }
  return safeSegments;
}

Map<String, dynamic> _sanitizeMap(Map map, {String? configuredApiKey}) {
  final result = <String, dynamic>{};
  for (final entry in map.entries) {
    final key = entry.key.toString();
    final safeKey = _sanitizeDiagnosticString(
      key,
      configuredApiKey: configuredApiKey,
    );
    final value = entry.value;
    if (safeKey == null ||
        _containsConfiguredApiKey(key, configuredApiKey) ||
        _isCredentialName(key) ||
        _isCredentialName(safeKey)) {
      continue;
    }
    if (_isEncodedPayloadName(key)) continue;
    if (value is TypedData || (value is List && _looksLikeBytePayload(value))) {
      continue;
    }
    if (value is Map) {
      result[safeKey] = _sanitizeMap(value, configuredApiKey: configuredApiKey);
    } else if (value is List) {
      result[safeKey] = _sanitizeList(
        value,
        configuredApiKey: configuredApiKey,
      );
    } else if (value is String) {
      if (_containsConfiguredApiKey(value, configuredApiKey)) continue;
      final sanitized = _sanitizeDiagnosticString(
        value,
        configuredApiKey: configuredApiKey,
      );
      if (sanitized != null) result[safeKey] = sanitized;
    } else {
      result[safeKey] = value;
    }
  }
  return result;
}

List<Map<String, dynamic>> _sanitizeCustomParams(
  Iterable values, {
  String? configuredApiKey,
}) {
  final result = <Map<String, dynamic>>[];
  for (final value in values) {
    if (value is! Map) continue;
    final paramName = value['paramName'];
    final defaultValue = value['defaultValue'];
    if ((paramName is String && _isCredentialName(paramName)) ||
        (paramName is String &&
            _containsConfiguredApiKey(paramName, configuredApiKey)) ||
        (defaultValue is String &&
            _containsConfiguredApiKey(defaultValue, configuredApiKey)) ||
        (defaultValue is String && _looksCredentialLike(defaultValue))) {
      continue;
    }
    final sanitized = _sanitizeMap(value, configuredApiKey: configuredApiKey);
    if (sanitized.isNotEmpty) result.add(sanitized);
  }
  return result;
}

List<dynamic> _sanitizeList(List values, {String? configuredApiKey}) {
  final sanitized = <dynamic>[];
  for (final value in values) {
    if (value is TypedData || (value is List && _looksLikeBytePayload(value))) {
      continue;
    } else if (value is Map) {
      sanitized.add(_sanitizeMap(value, configuredApiKey: configuredApiKey));
    } else if (value is List) {
      sanitized.add(_sanitizeList(value, configuredApiKey: configuredApiKey));
    } else if (value is String) {
      if (_containsConfiguredApiKey(value, configuredApiKey)) continue;
      final safeValue = _sanitizeDiagnosticString(
        value,
        configuredApiKey: configuredApiKey,
      );
      if (safeValue != null) sanitized.add(safeValue);
    } else {
      sanitized.add(value);
    }
  }
  return sanitized;
}

String? _sanitizeDiagnosticString(String value, {String? configuredApiKey}) {
  final trimmed = value.trimLeft();
  final looksLikeJson = trimmed.startsWith('{') || trimmed.startsWith('[');
  final jsonSanitized = _sanitizeDiagnosticJson(
    value,
    configuredApiKey: configuredApiKey,
  );
  if (jsonSanitized != null) return jsonSanitized;
  if (looksLikeJson) return null;

  final pathSanitized = _sanitizeCredentialPathsInText(value);
  final keySanitized = _removeConfiguredApiKey(pathSanitized, configuredApiKey);
  if (_containsConfiguredApiKeyInAlphanumericToken(
        keySanitized,
        configuredApiKey,
      ) ||
      _containsEncodedConfiguredApiKey(keySanitized, configuredApiKey)) {
    return null;
  }
  final hasEmbeddedUrl = _embeddedHttpUrlPattern.hasMatch(keySanitized);
  final urlsSanitized = keySanitized.replaceAllMapped(
    _embeddedHttpUrlPattern,
    (match) => _sanitizeHost(match[0]!, configuredApiKey: configuredApiKey),
  );
  if (_urlContainsEmbeddedAudioPayload(urlsSanitized) ||
      _containsShortBase64PayloadOutsideUrls(urlsSanitized)) {
    return null;
  }
  final uri = Uri.tryParse(urlsSanitized);
  if (uri == null && urlsSanitized.contains('://') && !hasEmbeddedUrl) {
    return null;
  }
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.hasAuthority) {
    return _sanitizeHost(urlsSanitized, configuredApiKey: configuredApiKey);
  }
  if (_looksCredentialLike(urlsSanitized) ||
      _looksLikeBase64Payload(urlsSanitized)) {
    return null;
  }
  return urlsSanitized;
}

String? _sanitizeDiagnosticJson(String value, {String? configuredApiKey}) {
  final trimmed = value.trimLeft();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;

  dynamic decoded;
  try {
    decoded = jsonDecode(value);
  } on FormatException {
    return null;
  }
  if (decoded is Map) {
    return jsonEncode(
      _sanitizeMap(decoded, configuredApiKey: configuredApiKey),
    );
  }
  if (decoded is List) {
    return jsonEncode(
      _sanitizeList(decoded, configuredApiKey: configuredApiKey),
    );
  }
  return null;
}

String _sanitizeCredentialPathsInText(String value) {
  final normalizedValue = value.replaceAll('\\', '/');
  final segments = normalizedValue.split('/');
  final safeSegments = <String>[];
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    final decodedSegment = _decodePathSegment(segment);
    if (decodedSegment == null) {
      final malformedEscapeStart = segment.indexOf('%');
      if (malformedEscapeStart > 0) {
        safeSegments.add(segment.substring(0, malformedEscapeStart));
      }
      break;
    }
    if (segment != decodedSegment &&
        _embeddedHttpUrlPattern.hasMatch(decodedSegment)) {
      final sanitizedUrls = decodedSegment.replaceAllMapped(
        _embeddedHttpUrlPattern,
        (match) => _sanitizeHost(match[0]!),
      );
      if (sanitizedUrls != decodedSegment) {
        safeSegments.add(sanitizedUrls);
        continue;
      }
    }
    final normalizedDecodedSegment = decodedSegment.replaceAll('\\', '/');
    if (normalizedDecodedSegment.contains('/')) {
      final suffixStart = normalizedDecodedSegment.indexOf(RegExp(r'[?#]'));
      final path = suffixStart < 0
          ? normalizedDecodedSegment
          : normalizedDecodedSegment.substring(0, suffixStart);
      final suffix = suffixStart < 0
          ? ''
          : normalizedDecodedSegment.substring(suffixStart);
      final pathSegments = path.split('/');
      final safePathSegments = _sanitizePathSegments(pathSegments);
      if (_segmentsChanged(pathSegments, safePathSegments)) {
        safeSegments.add('${safePathSegments.join('/')}$suffix');
      } else {
        safeSegments.add(segment);
      }
      continue;
    }
    final inlineMarker = RegExp(
      r'^([^:=/]+)(?:[:=/].*)$',
    ).firstMatch(decodedSegment);
    if (inlineMarker != null && _isCredentialName(inlineMarker[1]!)) {
      safeSegments.add(inlineMarker[1]!);
      break;
    }
    if (_isCredentialPathMarkerAt(segments, index, marker: decodedSegment)) {
      safeSegments.add(decodedSegment);
      break;
    }
    safeSegments.add(segment);
  }
  final sanitized = safeSegments.join('/');
  return sanitized == normalizedValue ? value : sanitized;
}

bool _isCredentialName(String name) {
  final normalizedName = name
      .replaceAllMapped(
        RegExp(r'([A-Z])([A-Z][a-z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .replaceAll(RegExp(r'\s+'), '_');
  return RegExp(
    _credentialNamePattern,
    caseSensitive: false,
  ).hasMatch(normalizedName);
}

bool _isCredentialPathMarker(String name) {
  final normalizedName = name
      .replaceAllMapped(
        RegExp(r'([A-Z])([A-Z][a-z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .replaceAll(RegExp(r'\s+'), '_');
  return RegExp(
    r'^(?:key|app[-_.]?key|api[-_.]?key|access[-_.]?key|'
    r'api[-_.]?token|access[-_.]?token|'
    r'auth(?:orization)?|token|client[-_.]?secret|private[-_.]?key|'
    r'password|passwd|secret|(?:set[-_.]?)?cookies?|session(?:[-_.]?(?:id|key|token))?|'
    r'credential|sig(?:nature)?)$',
    caseSensitive: false,
  ).hasMatch(normalizedName);
}

bool _isCredentialPathMarkerAt(
  List<String> segments,
  int index, {
  String? marker,
}) {
  final name = marker ?? segments[index];
  if (!_isCredentialPathMarker(name)) return false;
  if ((_isAuthPathMarker(name) || _isAmbiguousApiKeyPathMarker(name)) &&
      index > 0 &&
      index + 1 < segments.length &&
      RegExp(
        r'^v[0-9]+$',
        caseSensitive: false,
      ).hasMatch(segments[index - 1]) &&
      const {
        'transcribe',
        'transcription',
        'transcriptions',
        'recognize',
        'recognition',
        'speech',
      }.contains(segments[index + 1].toLowerCase())) {
    return false;
  }
  return true;
}

bool _isAuthPathMarker(String name) =>
    RegExp(r'^auth(?:orization)?$', caseSensitive: false).hasMatch(name);

bool _isAmbiguousApiKeyPathMarker(String name) =>
    RegExp(r'^(?:key|app[-_.]?key)$', caseSensitive: false).hasMatch(name);

bool _isEncodedPayloadName(String name) => RegExp(
      r'^(?:file|source|audio|audio[_-]?(?:data|bytes|base64)|base64|data)$',
      caseSensitive: false,
    ).hasMatch(name);

bool _looksLikeBytePayload(List values) =>
    values.length >= 32 &&
    values.every((value) => value is int && value >= 0 && value <= 255);

bool _looksLikeBase64Payload(String value) {
  final trimmed = value.trim();
  final base64Characters = RegExp(r'^[A-Za-z0-9+/=_-]+$');
  return (trimmed.length >= 256 &&
          RegExp(r'^[A-Za-z0-9+/=_\s-]+$').hasMatch(trimmed)) ||
      (trimmed.length >= 32 &&
          !RegExp(r'\s').hasMatch(trimmed) &&
          base64Characters.hasMatch(trimmed));
}

bool _looksLikeNaturalLanguageTranscript(String value) {
  // A short multiword ASR chunk can still provide enough signal for the
  // word and character checks below to distinguish prose from payload text.
  if (value.length < 64) return false;
  final words = value.trim().split(RegExp(r'\s+'));
  final wordPattern = RegExp(r'^[A-Za-z0-9]+$');
  if (words.length < 8 ||
      words.any((word) => word.length > 24 || !wordPattern.hasMatch(word))) {
    return false;
  }

  final alphabeticCharacters =
      value.replaceAll(RegExp(r'[^A-Za-z]'), '').split('');
  final lowercaseCount = alphabeticCharacters
      .where((character) => character.toLowerCase() == character)
      .length;
  const vowels = 'aeiouy';
  final vowelCount = alphabeticCharacters
      .where((character) => vowels.contains(character.toLowerCase()))
      .length;
  final distinctLetters = alphabeticCharacters
      .map((character) => character.toLowerCase())
      .toSet()
      .length;
  final distinctWordLengths = words.map((word) => word.length).toSet().length;
  // Technical terms, names, and speech in other dialects may not contain
  // common English words. Vowel, case, and character diversity distinguish
  // ordinary word text from Base64 groups with irregular whitespace.
  return distinctWordLengths >= 4 &&
      distinctLetters >= 10 &&
      lowercaseCount * 5 >= alphabeticCharacters.length * 3 &&
      vowelCount * 4 >= alphabeticCharacters.length;
}

bool _looksCredentialLike(String value) =>
    _credentialValuePatterns.any((pattern) => pattern.hasMatch(value)) ||
    _credentialKeyValuePattern
        .allMatches(value)
        .any((match) => _isCredentialName(match[1]!));
