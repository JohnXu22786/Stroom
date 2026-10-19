import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/services/asr_retry_storage.dart';
import 'package:stroom/services/asr_service.dart';

class _MemoryRetryAdapter implements AsrRetryStorageAdapter {
  final Map<String, Uint8List> files = {};
  Completer<void>? deleteEntered;
  Completer<void>? releaseDelete;
  Completer<void>? keysEntered;
  Completer<void>? releaseKeys;
  Object? deleteFailure;
  Object? writeFailure;

  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (writeFailure != null) throw writeFailure!;
    files[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> read(String key) async {
    final bytes = files[key];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<void> delete(String key) async {
    if (deleteEntered != null && !deleteEntered!.isCompleted) {
      deleteEntered!.complete();
    }
    await releaseDelete?.future;
    if (deleteFailure != null) {
      final failure = deleteFailure!;
      deleteFailure = null;
      throw failure;
    }
    files.remove(key);
  }

  @override
  Future<List<String>> keysWithPrefix(String prefix) async {
    if (keysEntered != null && !keysEntered!.isCompleted) {
      keysEntered!.complete();
    }
    await releaseKeys?.future;
    return files.keys.where((key) => key.startsWith(prefix)).toList();
  }
}

class _GatedCheckpointRetryAdapter extends _MemoryRetryAdapter {
  final Completer<void> firstCheckpointWriteEntered = Completer<void>();
  final Completer<void> releaseFirstCheckpointWrite = Completer<void>();
  int checkpointWriteCount = 0;

  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (key.endsWith('.chunks')) {
      checkpointWriteCount++;
      if (checkpointWriteCount == 1) {
        firstCheckpointWriteEntered.complete();
        await releaseFirstCheckpointWrite.future;
      }
    }
    await super.write(key, bytes);
  }
}

class _GatedAtomicRetryAdapter extends _MemoryRetryAdapter {
  _GatedAtomicRetryAdapter(this.gatedSuffix);

  static const _prefix = 'background/asr_retry/';
  final String gatedSuffix;
  final Completer<void> writeEntered = Completer<void>();
  final Completer<void> releaseWrite = Completer<void>();
  String? temporaryKey;

  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (!key.endsWith(gatedSuffix) || writeEntered.isCompleted) {
      await super.write(key, bytes);
      return;
    }

    final name = key.substring(_prefix.length);
    temporaryKey = '$_prefix.$name.tmp-in-progress';
    files[temporaryKey!] = Uint8List.fromList(bytes);
    writeEntered.complete();
    await releaseWrite.future;
    if (!files.containsKey(temporaryKey)) {
      throw StateError('Atomic temporary entry was removed during its write');
    }
    files[key] = Uint8List.fromList(bytes);
    files.remove(temporaryKey);
  }
}

class _GatedEnsureStoredRetryAdapter extends _MemoryRetryAdapter {
  final Completer<void> audioWriteEntered = Completer<void>();
  final Completer<void> releaseAudioWrite = Completer<void>();
  bool gateAudioWrites = false;

  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (gateAudioWrites && key.endsWith('.audio')) {
      audioWriteEntered.complete();
      await releaseAudioWrite.future;
    }
    await super.write(key, bytes);
  }
}

Future<AsrAudioReference> _saveAndRelease(
  AsrRetryAudioStore store,
  Uint8List bytes, {
  required String name,
  required String format,
}) async {
  final reference = await store.save(bytes, name: name, format: format);
  await store.releaseProtection(reference);
  return reference;
}

void main() {
  test(
    'versioned retry snapshots redact configured keys from single and multi audio chunks',
    () {
      const configuredApiKey = 'earth-blue-7';
      Map<String, dynamic> audioReference(String id) => {
            'version': AsrAudioReference.currentVersion,
            'id': id,
            'name': 'capture.wav',
            'format': 'wav',
            'byteLength': 4,
            'sha256': List.filled(64, 'b').join(),
          };
      final chunk = const AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        status: AsrChunkStatus.succeeded,
        text: 'recognized earth-blue-7',
        segments: [AsrTranscriptSegment(text: 'earth-blue-7')],
      ).toMap();

      final single = AsrRetryAudioStore.sanitizeVersionedRetryData({
        'version': 2,
        'audioReference': audioReference(List.filled(32, 'a').join()),
        'chunks': [chunk],
      }, configuredApiKey: configuredApiKey)!;
      final multiple = AsrRetryAudioStore.sanitizeVersionedRetryData({
        'version': 2,
        'audioReferences': [
          {
            'audioReference': {
              ...audioReference(List.filled(32, 'c').join()),
              'name': '$configuredApiKey.wav',
            },
            'chunks': [chunk],
          },
        ],
      }, configuredApiKey: configuredApiKey)!;

      expect(jsonEncode(single), isNot(contains(configuredApiKey)));
      expect(jsonEncode(multiple), isNot(contains(configuredApiKey)));
    },
  );

  test(
    'versioned checkpoints never retain a configured key embedded in a token',
    () {
      const configuredApiKey = 'secret-token';
      final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData({
        'version': 2,
        'audioReference': {
          'version': AsrAudioReference.currentVersion,
          'id': List.filled(32, 'a').join(),
          'name': 'capture.wav',
          'format': 'wav',
          'byteLength': 4,
          'sha256': List.filled(64, 'b').join(),
        },
        'chunks': [
          const AsrChunkResult(
            index: 0,
            startSeconds: 0,
            endSeconds: 1,
            totalChunks: 1,
            status: AsrChunkStatus.succeeded,
            text: 'recognized xsecret-tokenx',
          ).toMap(),
        ],
      }, configuredApiKey: configuredApiKey);

      expect(
        sanitized == null || !jsonEncode(sanitized).contains(configuredApiKey),
        isTrue,
      );
    },
  );

  test('versioned retry snapshots redact configured keys from every field', () {
    const configuredApiKey = 'earth-blue-7';
    final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData({
      'version': 2,
      'audioReference': {
        'version': AsrAudioReference.currentVersion,
        'id': List.filled(32, 'd').join(),
        'name': '$configuredApiKey.wav',
        'format': 'wav',
        'byteLength': 4,
        'sha256': List.filled(64, 'e').join(),
      },
      'chunks': [
        const AsrChunkResult(
          index: 0,
          startSeconds: 0,
          endSeconds: 1,
          totalChunks: 1,
          status: AsrChunkStatus.succeeded,
          text: 'recognized text',
        ).toMap(),
      ],
      'modelReference': {
        'configId': '$configuredApiKey-provider',
        'modelId': 'stable-model',
      },
      'configSnapshot': {
        'host': 'https://asr.example.test/transcribe',
        'model': configuredApiKey,
        'language': configuredApiKey,
        'typeConfig': {'customLabel': configuredApiKey},
        'customParams': [
          {
            'paramName': 'customLabel',
            'defaultValue': configuredApiKey,
            'type': 'string',
          },
        ],
        'uploadMethod': 'multipart',
      },
      'saveFolder': '/exports/$configuredApiKey',
    }, configuredApiKey: configuredApiKey)!;

    expect(jsonEncode(sanitized), isNot(contains(configuredApiKey)));
  });

  test('retry config snapshots redact acronym-form API token fields', () {
    const opaqueApiToken = 'opaque-acronym-api-token-value';
    final snapshot = AsrRetryConfigSnapshot.fromMap({
      'host': 'https://asr.example.test/transcribe',
      'model': 'whisper-small',
      'typeConfig': {'APIToken': opaqueApiToken, 'mode': 'fast'},
    });

    final serialized = jsonEncode(snapshot.toMap());

    expect(serialized, isNot(contains(opaqueApiToken)));
    expect(snapshot.typeConfig, {'mode': 'fast'});
  });

  test('versioned audio references fail closed on keys in ID or digest', () {
    const idApiKey = '0123456789abcdef0123456789abcdef';
    const digestApiKey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const safeId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const safeDigest =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    Map<String, dynamic> referenceMap({
      required String id,
      required String digest,
    }) =>
        {
          'version': AsrAudioReference.currentVersion,
          'id': id,
          'name': 'capture.wav',
          'format': 'wav',
          'byteLength': 4,
          'sha256': digest,
        };

    final idKeyReference = AsrAudioReference(
      id: idApiKey,
      name: 'capture.wav',
      format: 'wav',
      byteLength: 4,
      sha256: safeDigest,
    );
    expect(
      () => idKeyReference.toMap(configuredApiKey: idApiKey),
      throwsFormatException,
    );
    expect(
      () => AsrAudioReference.fromMap(
        referenceMap(id: idApiKey, digest: safeDigest),
        configuredApiKey: idApiKey,
      ),
      throwsFormatException,
    );
    expect(
      AsrRetryAudioStore.sanitizeVersionedRetryData({
        'version': 2,
        'audioReference': referenceMap(id: idApiKey, digest: safeDigest),
      }, configuredApiKey: idApiKey),
      isNull,
    );

    final digestKeyReference = AsrAudioReference(
      id: safeId,
      name: 'capture.wav',
      format: 'wav',
      byteLength: 4,
      sha256: digestApiKey,
    );
    expect(
      () => digestKeyReference.toMap(configuredApiKey: digestApiKey),
      throwsFormatException,
    );
    expect(
      () => AsrAudioReference.fromMap(
        referenceMap(id: safeId, digest: digestApiKey),
        configuredApiKey: digestApiKey,
      ),
      throwsFormatException,
    );
    expect(
      AsrRetryAudioStore.sanitizeVersionedRetryData({
        'version': 2,
        'audioReference': referenceMap(id: safeId, digest: digestApiKey),
      }, configuredApiKey: digestApiKey),
      isNull,
    );
  });

  test(
    'short API keys do not invalidate generated structural references',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final reference = await store.save(
        Uint8List.fromList([1, 2, 3, 4]),
        name: 'capture.wav',
        format: 'wav',
        configuredApiKey: '4',
      );

      final serialized = reference.toMap(configuredApiKey: '4');
      final restored = AsrAudioReference.fromMap(
        serialized,
        configuredApiKey: '4',
      );

      expect(restored.id, reference.id);
      expect(restored.sha256, reference.sha256);
      expect(await store.load(restored), Uint8List.fromList([1, 2, 3, 4]));
      await store.releaseProtection(reference);
    },
  );

  test('unknown retry-data versions fail closed for audio ownership', () {
    final retryData = <String, dynamic>{
      'version': 3,
      'audioReference': {
        'version': AsrAudioReference.currentVersion,
        'id': List.filled(32, 'e').join(),
        'name': 'retry.wav',
        'format': 'wav',
        'byteLength': 3,
        'sha256': List.filled(64, 'a').join(),
      },
      // Future formats may add another ownership field the current reader
      // cannot understand.
      'futureAudioReferences': [List.filled(32, 'f').join()],
    };

    expect(AsrRetryAudioStore.hasValidVersionedReferences(retryData), isFalse);
    expect(AsrRetryAudioStore.recoverableReferencedIds(retryData), isNull);
  });

  test('unversioned legacy retry data remains safe to migrate', () {
    const retryData = <String, dynamic>{
      'audios': [
        {'bytes': 'AQID', 'name': 'legacy.wav', 'format': 'wav'},
      ],
      'modelIndex': 0,
    };

    expect(AsrRetryAudioStore.hasValidVersionedReferences(retryData), isTrue);
    expect(AsrRetryAudioStore.recoverableReferencedIds(retryData), isEmpty);
  });

  test(
    'chunk checkpoints are versioned, sanitized, and reference-owned',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      const chunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 2,
        status: AsrChunkStatus.succeeded,
        text: 'recognized text',
        error: 'Bearer sk-checkpoint-secret',
      );
      final key = 'background/asr_retry/${reference.id}.chunks';

      await store.writeChunkCheckpoint(
        reference,
        [chunk],
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
      );

      final encoded = utf8.decode(adapter.files[key]!);
      expect(encoded, contains('"version":3'));
      expect(encoded, contains('"version":2'));
      expect(encoded, contains('"configId":"provider"'));
      expect(encoded, contains('"modelId":"model"'));
      expect(encoded, isNot(contains('sk-checkpoint-secret')));
      expect(encoded, isNot(contains('apiKey')));
      expect(encoded, isNot(contains('bytes')));
      final restored =
          await AsrRetryAudioStore(adapter: adapter).readChunkCheckpoint(
        reference,
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
      );
      expect(restored!.chunks.single.status, AsrChunkStatus.succeeded);
      expect(restored.chunks.single.text, 'recognized text');
      expect(
        await store.readChunkCheckpoint(
          reference,
          modelReference: const {
            'configId': 'other-provider',
            'modelId': 'model',
          },
        ),
        isNull,
      );

      await store.prune(() => {reference.id});
      expect(adapter.files, contains(key));
      await store.prune(() => const {});
      expect(adapter.files, isNot(contains(key)));
    },
  );

  test('checkpoint sanitizer preserves spoken Base64-alphabet identifiers',
      () async {
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    const reference = AsrAudioReference(
      id: 'abababababababababababababababab',
      name: 'spoken-identifier.wav',
      format: 'wav',
      byteLength: 4,
      sha256:
          'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
    );
    const transcript =
        'The spoken identifier is ABCDEFGHIJKLMNOPQRSTUVWX for this recording '
        'Please keep that clear code available when replaying the clip for the next step';

    await store.writeChunkCheckpoint(
      reference,
      const [
        AsrChunkResult(
          index: 0,
          startSeconds: 0,
          endSeconds: 1,
          totalChunks: 1,
          status: AsrChunkStatus.succeeded,
          text: transcript,
        ),
      ],
      modelReference: const {'configId': 'provider', 'modelId': 'model'},
    );

    final restored = await store.readChunkCheckpoint(
      reference,
      modelReference: const {'configId': 'provider', 'modelId': 'model'},
    );
    expect(restored?.chunks.single.text, transcript);
  });

  test('versioned retry snapshots preserve generated model UUID identifiers',
      () {
    const configId = 'config_550e8400-e29b-41d4-a716-446655440000';
    const modelId = 'model_7c9e6679-7425-40de-944b-e07fc1f90ae7';
    final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData({
      'version': 2,
      'audioReference': {
        'version': AsrAudioReference.currentVersion,
        'id': 'abababababababababababababababab',
        'name': 'capture.wav',
        'format': 'wav',
        'byteLength': 4,
        'sha256':
            'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
      },
      'chunks': const [],
      'modelReference': {'configId': configId, 'modelId': modelId},
    });

    expect(
      sanitized?['modelReference'],
      {'configId': configId, 'modelId': modelId},
    );
  });

  test('chunk checkpoints accept generated model UUID identifiers', () async {
    const configId = 'config_550e8400-e29b-41d4-a716-446655440000';
    const modelId = 'model_7c9e6679-7425-40de-944b-e07fc1f90ae7';
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    const reference = AsrAudioReference(
      id: 'abababababababababababababababab',
      name: 'capture.wav',
      format: 'wav',
      byteLength: 4,
      sha256:
          'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
    );
    const modelReference = {'configId': configId, 'modelId': modelId};

    await store.writeChunkCheckpoint(
      reference,
      const [
        AsrChunkResult(
          index: 0,
          startSeconds: 0,
          endSeconds: 1,
          totalChunks: 1,
          status: AsrChunkStatus.succeeded,
          text: 'recognized text',
        ),
      ],
      modelReference: modelReference,
    );
    final restored = await store.readChunkCheckpoint(
      reference,
      modelReference: modelReference,
    );

    expect(restored?.configId, configId);
    expect(restored?.modelId, modelId);
    expect(restored?.chunks.single.text, 'recognized text');
  });

  test(
    'checkpoint sanitation preserves long plain transcripts with line breaks',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final transcript = List<String>.filled(
        10,
        'ordinary speech transcript remains checkpointed',
      ).join('\n');
      expect(transcript.length, greaterThan(256));

      await store.writeChunkCheckpoint(
        reference,
        [
          AsrChunkResult(
            index: 0,
            startSeconds: 0,
            endSeconds: 1,
            totalChunks: 1,
            status: AsrChunkStatus.succeeded,
            text: transcript,
          ),
        ],
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
      );

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
      );
      expect(restored!.chunks.single.text, transcript);
    },
  );

  test(
    'URL checkpoints cannot be reused after the source URL changes',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const originalReference = AsrAudioReference(
        id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        name: 'https://media.example.test/original.wav',
        format: 'url',
        byteLength: 0,
        sha256:
            '0000000000000000000000000000000000000000000000000000000000000000',
        url: 'https://media.example.test/original.wav',
      );
      const changedReference = AsrAudioReference(
        id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        name: 'https://media.example.test/replacement.wav',
        format: 'url',
        byteLength: 0,
        sha256:
            '0000000000000000000000000000000000000000000000000000000000000000',
        url: 'https://media.example.test/replacement.wav',
      );
      const chunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        status: AsrChunkStatus.succeeded,
        text: 'transcript for original source',
      );

      await store.writeChunkCheckpoint(
        originalReference,
        const [chunk],
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
      );
      expect(
        utf8.decode(
          adapter.files['background/asr_retry/${originalReference.id}.chunks']!,
        ),
        isNot(contains('media.example.test')),
      );

      await expectLater(
        store.readChunkCheckpoint(
          changedReference,
          modelReference: const {'configId': 'provider', 'modelId': 'model'},
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );
    },
  );

  test('URL checkpoints survive safe URL normalization', () async {
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    const encodedUrl = 'https%3A%2F%2Fmedia.example.test%2Faudio';
    const normalizedUrl = 'https://media.example.test/audio';
    const encodedReference = AsrAudioReference(
      id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      name: encodedUrl,
      format: 'url',
      byteLength: 0,
      sha256:
          '0000000000000000000000000000000000000000000000000000000000000000',
      url: encodedUrl,
    );
    final restoredReference = AsrAudioReference.fromMap({
      ...encodedReference.toMap(),
      'url': normalizedUrl,
      'name': normalizedUrl,
    });
    const chunk = AsrChunkResult(
      index: 0,
      startSeconds: 0,
      endSeconds: 1,
      totalChunks: 1,
      status: AsrChunkStatus.succeeded,
      text: 'normalized URL transcript',
    );

    await store.writeChunkCheckpoint(
      encodedReference,
      const [chunk],
      modelReference: const {'configId': 'provider', 'modelId': 'model'},
    );

    expect(
      (await store.readChunkCheckpoint(
        restoredReference,
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
      ))
          ?.chunks
          .single
          .text,
      'normalized URL transcript',
    );
  });

  test('chunk checkpoints preserve each model for a shared source', () async {
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    const reference = AsrAudioReference(
      id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      name: 'capture.wav',
      format: 'wav',
      byteLength: 4,
      sha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    const providerChunk = AsrChunkResult(
      index: 0,
      startSeconds: 0,
      endSeconds: 1,
      totalChunks: 2,
      status: AsrChunkStatus.succeeded,
      text: 'provider transcript',
    );
    const replacementModelChunk = AsrChunkResult(
      index: 0,
      startSeconds: 0,
      endSeconds: 1,
      totalChunks: 2,
      status: AsrChunkStatus.succeeded,
      text: 'replacement model transcript',
    );

    await store.writeChunkCheckpoint(
      reference,
      const [providerChunk],
      modelReference: const {'configId': 'provider-a', 'modelId': 'model-a'},
    );
    await store.writeChunkCheckpoint(
      reference,
      const [replacementModelChunk],
      modelReference: const {'configId': 'provider-b', 'modelId': 'model-b'},
    );

    final providerCheckpoint = await store.readChunkCheckpoint(
      reference,
      modelReference: const {'configId': 'provider-a', 'modelId': 'model-a'},
    );
    final replacementModelCheckpoint = await store.readChunkCheckpoint(
      reference,
      modelReference: const {'configId': 'provider-b', 'modelId': 'model-b'},
    );
    expect(providerCheckpoint?.chunks.single.text, 'provider transcript');
    expect(
      replacementModelCheckpoint?.chunks.single.text,
      'replacement model transcript',
    );
  });

  test(
    'checkpoint restore rejects one fingerprint with conflicting chunk totals',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'abababababababababababababababab',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      final planFingerprint = fingerprintAsrChunkPlan([
        (startSeconds: 0, endSeconds: 1),
        (startSeconds: 1, endSeconds: 2),
      ]);
      final storedCheckpoint = {
        'version': AsrRetryChunkCheckpoint.currentVersion,
        'audioReferenceId': reference.id,
        'audioSha256': reference.sha256,
        'modelReference': modelReference,
        'chunks': [
          AsrChunkResult(
            index: 0,
            startSeconds: 0,
            endSeconds: 1,
            totalChunks: 2,
            planFingerprint: planFingerprint,
            status: AsrChunkStatus.succeeded,
            text: 'durable first chunk',
          ).toMap(),
          AsrChunkResult(
            index: 1,
            startSeconds: 1,
            endSeconds: 2,
            totalChunks: 3,
            planFingerprint: planFingerprint,
            status: AsrChunkStatus.uncertain,
          ).toMap(),
        ],
      };
      adapter.files['background/asr_retry/${reference.id}.chunks'] =
          Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': 3,
            'audioReferenceId': reference.id,
            'audioSha256': reference.sha256,
            'checkpoints': [storedCheckpoint],
          }),
        ),
      );

      await expectLater(
        store.readChunkCheckpoint(
          reference,
          modelReference: modelReference,
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );
    },
  );

  test(
    'chunk checkpoint writes retain durable successes for shared source',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'cccccccccccccccccccccccccccccccc',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      );
      const firstChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 2,
        status: AsrChunkStatus.succeeded,
        text: 'first durable result',
      );
      const laterChunk = AsrChunkResult(
        index: 1,
        startSeconds: 1,
        endSeconds: 2,
        totalChunks: 2,
        status: AsrChunkStatus.succeeded,
        text: 'later durable result',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};

      await store.writeChunkCheckpoint(
          reference,
          const [
            firstChunk,
          ],
          modelReference: modelReference);
      await store.writeChunkCheckpoint(
          reference,
          const [
            laterChunk,
          ],
          modelReference: modelReference);

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(
        restored?.chunks.map((chunk) => chunk.index),
        orderedEquals([0, 1]),
      );
      expect(
        restored?.chunks.map((chunk) => chunk.status),
        everyElement(AsrChunkStatus.succeeded),
      );
    },
  );

  test(
    'chunk checkpoint writes discard successes from a changed chunk plan',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'cccccccccccccccccccccccccccccccc',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const firstOldChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 2,
        status: AsrChunkStatus.succeeded,
        text: 'old first chunk',
      );
      const secondOldChunk = AsrChunkResult(
        index: 1,
        startSeconds: 1,
        endSeconds: 2,
        totalChunks: 2,
        status: AsrChunkStatus.succeeded,
        text: 'old second chunk',
      );
      const replacementChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 2,
        totalChunks: 1,
        status: AsrChunkStatus.succeeded,
        text: 'new single chunk',
      );

      await store.writeChunkCheckpoint(
          reference,
          const [
            firstOldChunk,
          ],
          modelReference: modelReference);
      await store.writeChunkCheckpoint(
          reference,
          const [
            secondOldChunk,
          ],
          modelReference: modelReference);
      await store.writeChunkCheckpoint(
          reference,
          const [
            replacementChunk,
          ],
          modelReference: modelReference);

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored!.chunks.map((chunk) => chunk.index), orderedEquals([0]));
      expect(restored.chunks.single.text, 'new single chunk');
      expect(restored.chunks.single.totalChunks, 1);
    },
  );

  test(
    'chunk checkpoint writes discard sparse successes from an old plan',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const oldSparseSuccess = AsrChunkResult(
        index: 1,
        startSeconds: 1,
        endSeconds: 2,
        totalChunks: 2,
        status: AsrChunkStatus.succeeded,
        text: 'old second chunk',
      );
      const newSingleChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 2,
        totalChunks: 1,
        status: AsrChunkStatus.succeeded,
        text: 'new single chunk',
      );

      await store.writeChunkCheckpoint(
          reference,
          const [
            oldSparseSuccess,
          ],
          modelReference: modelReference);
      await store.writeChunkCheckpoint(
          reference,
          const [
            newSingleChunk,
          ],
          modelReference: modelReference);

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored!.chunks.map((chunk) => chunk.index), orderedEquals([0]));
      expect(restored.chunks.single.text, 'new single chunk');
    },
  );

  test(
    'sparse un-fingerprinted checkpoints reject incompatible chunk boundaries',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'abababababababababababababababab',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const oldSparseSuccess = AsrChunkResult(
        index: 1,
        startSeconds: 1,
        endSeconds: 2,
        totalChunks: 2,
        status: AsrChunkStatus.succeeded,
        text: 'old second chunk',
      );
      const newSparseSuccess = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1.5,
        totalChunks: 2,
        status: AsrChunkStatus.succeeded,
        text: 'new first chunk',
      );

      await store.writeChunkCheckpoint(reference, const [oldSparseSuccess],
          modelReference: modelReference);
      await store.writeChunkCheckpoint(reference, const [newSparseSuccess],
          modelReference: modelReference);

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored!.chunks.map((chunk) => chunk.index), orderedEquals([0]));
      expect(restored.chunks.single.text, 'new first chunk');
    },
  );

  test(
    'sub-millisecond gaps between un-fingerprinted chunks reject plan reuse',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: '12121212121212121212121212121212',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            '3434343434343434343434343434343434343434343434343434343434343434',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const unresolvedFirstChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 2,
        status: AsrChunkStatus.uncertain,
      );
      const changedSecondChunk = AsrChunkResult(
        index: 1,
        startSeconds: 1.0005,
        endSeconds: 2,
        totalChunks: 2,
        status: AsrChunkStatus.succeeded,
        text: 'success from changed plan',
      );

      await store.writeChunkCheckpoint(
        reference,
        const [unresolvedFirstChunk],
        modelReference: modelReference,
      );
      await expectLater(
        store.writeChunkCheckpoint(
          reference,
          const [changedSecondChunk],
          modelReference: modelReference,
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored?.chunks.map((chunk) => chunk.index), [0]);
      expect(restored?.chunks.single.status, AsrChunkStatus.uncertain);
      expect(restored?.chunks.single.endSeconds, 1);
    },
  );

  test(
    'chunk checkpoint writes discard sparse successes when same-count boundaries change',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'dededededededededededededededede',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'abababababababababababababababababababababababababababababababab',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const oldSparseSuccess = AsrChunkResult(
        index: 1,
        startSeconds: 1,
        endSeconds: 2,
        totalChunks: 2,
        planFingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        status: AsrChunkStatus.succeeded,
        text: 'old second chunk',
      );
      const newFirstChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1.5,
        totalChunks: 2,
        planFingerprint:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        status: AsrChunkStatus.succeeded,
        text: 'new first chunk',
      );

      await store.writeChunkCheckpoint(
          reference,
          const [
            oldSparseSuccess,
          ],
          modelReference: modelReference);
      await store.writeChunkCheckpoint(
          reference,
          const [
            newFirstChunk,
          ],
          modelReference: modelReference);

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored!.chunks.map((chunk) => chunk.index), orderedEquals([0]));
      expect(restored.chunks.single.text, 'new first chunk');
      expect(
        restored.chunks.single.planFingerprint,
        newFirstChunk.planFingerprint,
      );
    },
  );

  test(
    'chunk checkpoints retain uncertainty unless a definitive outcome resolves it',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'cccccccccccccccccccccccccccccccc',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      );
      const uncertainChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        status: AsrChunkStatus.uncertain,
        text: 'request outcome unknown',
      );
      const failedChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        status: AsrChunkStatus.failed,
        text: 'later task snapshot says failed',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};

      await store.writeChunkCheckpoint(
          reference,
          const [
            uncertainChunk,
          ],
          modelReference: modelReference);
      await store.writeChunkCheckpoint(
          reference,
          const [
            failedChunk,
          ],
          modelReference: modelReference);

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored?.chunks.single.status, AsrChunkStatus.uncertain);

      await store.writeChunkCheckpoint(
        reference,
        const [failedChunk],
        modelReference: modelReference,
        allowUncertainToBeResolved: true,
      );
      final resolved = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(resolved?.chunks.single.status, AsrChunkStatus.failed);
    },
  );

  test(
    'changed chunk plans cannot clear an unresolved uncertain checkpoint',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'cfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcf',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const uncertainChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        planFingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        status: AsrChunkStatus.uncertain,
      );
      const changedPlanChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        planFingerprint:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        status: AsrChunkStatus.succeeded,
        text: 'new plan result',
      );

      await store.writeChunkCheckpoint(
        reference,
        const [uncertainChunk],
        modelReference: modelReference,
      );

      await expectLater(
        store.writeChunkCheckpoint(
          reference,
          const [changedPlanChunk],
          modelReference: modelReference,
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored?.chunks.single.status, AsrChunkStatus.uncertain);
      expect(restored?.chunks.single.planFingerprint,
          uncertainChunk.planFingerprint);
    },
  );

  test(
    'sub-millisecond plan changes cannot replace an un-fingerprinted uncertain checkpoint',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'efefefefefefefefefefefefefefefef',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'abababababababababababababababababababababababababababababababab',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const uncertainChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        status: AsrChunkStatus.uncertain,
      );
      const changedPlanChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1.0005,
        totalChunks: 1,
        status: AsrChunkStatus.succeeded,
        text: 'replacement from changed plan',
      );

      await store.writeChunkCheckpoint(
        reference,
        const [uncertainChunk],
        modelReference: modelReference,
      );

      await expectLater(
        store.writeChunkCheckpoint(
          reference,
          const [changedPlanChunk],
          modelReference: modelReference,
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored?.chunks.single.status, AsrChunkStatus.uncertain);
      expect(restored?.chunks.single.endSeconds, uncertainChunk.endSeconds);
    },
  );

  test(
    'retry sanitizer rejects malformed uncertain chunks instead of dropping the ambiguity marker',
    () {
      final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData({
        'version': 2,
        'audioReference': {
          'version': AsrAudioReference.currentVersion,
          'id': List.filled(32, 'a').join(),
          'name': 'capture.wav',
          'format': 'wav',
          'byteLength': 4,
          'sha256': List.filled(64, 'b').join(),
        },
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'chunks': [
          {
            'index': 'corrupt-index',
            'startSeconds': 0,
            'endSeconds': 1,
            'totalChunks': 1,
            'status': AsrChunkStatus.uncertain.name,
            'text': 'provider may have accepted this request',
          },
        ],
      });

      expect(
        sanitized,
        isNull,
        reason:
            'dropping an uncertain checkpoint would make a possibly accepted POST look retryable',
      );
    },
  );

  test(
    'checkpoint restore drops malformed failed rows but keeps successful chunks',
    () async {
      const reference = AsrAudioReference(
        id: 'abababababababababababababababab',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
      );
      final adapter = _MemoryRetryAdapter();
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      adapter.files['background/asr_retry/${reference.id}.chunks'] =
          Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': AsrRetryChunkCheckpoint.currentVersion,
            'audioReferenceId': reference.id,
            'audioSha256': reference.sha256,
            'modelReference': modelReference,
            'chunks': [
              {
                'index': 0,
                'startSeconds': 0,
                'endSeconds': 1,
                'totalChunks': 2,
                'status': AsrChunkStatus.succeeded.name,
                'text': 'durable success',
              },
              {
                'index': 1,
                'startSeconds': -1,
                'endSeconds': 0,
                'totalChunks': 2,
                'status': AsrChunkStatus.failed.name,
              },
            ],
          }),
        ),
      );

      final restored = await AsrRetryAudioStore(adapter: adapter)
          .readChunkCheckpoint(reference, modelReference: modelReference);

      expect(restored?.chunks, hasLength(1));
      expect(restored?.chunks.single.index, 0);
      expect(restored?.chunks.single.status, AsrChunkStatus.succeeded);
      expect(restored?.chunks.single.text, 'durable success');
    },
  );

  test(
    'retry sanitizer rejects duplicate indexes that hide an uncertain chunk',
    () {
      final audioReference = {
        'version': AsrAudioReference.currentVersion,
        'id': List.filled(32, 'a').join(),
        'name': 'capture.wav',
        'format': 'wav',
        'byteLength': 4,
        'sha256': List.filled(64, 'b').join(),
      };
      Map<String, dynamic> chunk(AsrChunkStatus status) => {
            'index': 0,
            'startSeconds': 0,
            'endSeconds': 1,
            'totalChunks': 1,
            'status': status.name,
          };

      final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData({
        'version': 2,
        'audioReference': audioReference,
        'chunks': [
          chunk(AsrChunkStatus.uncertain),
          chunk(AsrChunkStatus.failed),
        ],
      });

      expect(
        sanitized,
        isNull,
        reason:
            'a failed duplicate must not mask the uncertain outcome for this chunk index',
      );
    },
  );

  test('concurrent chunk checkpoint writes serialize and merge', () async {
    final adapter = _GatedCheckpointRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    const reference = AsrAudioReference(
      id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      name: 'capture.wav',
      format: 'wav',
      byteLength: 4,
      sha256:
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    );
    const firstChunk = AsrChunkResult(
      index: 0,
      startSeconds: 0,
      endSeconds: 1,
      totalChunks: 2,
      status: AsrChunkStatus.succeeded,
      text: 'first concurrent result',
    );
    const laterChunk = AsrChunkResult(
      index: 1,
      startSeconds: 1,
      endSeconds: 2,
      totalChunks: 2,
      status: AsrChunkStatus.succeeded,
      text: 'later concurrent result',
    );
    const modelReference = {'configId': 'provider', 'modelId': 'model'};

    final firstWrite = store.writeChunkCheckpoint(
        reference,
        const [
          firstChunk,
        ],
        modelReference: modelReference);
    await adapter.firstCheckpointWriteEntered.future;
    final laterWrite = store.writeChunkCheckpoint(
        reference,
        const [
          laterChunk,
        ],
        modelReference: modelReference);
    await Future<void>.delayed(Duration.zero);
    final writesWhileFirstIsBlocked = adapter.checkpointWriteCount;

    adapter.releaseFirstCheckpointWrite.complete();
    await Future.wait([firstWrite, laterWrite]);
    expect(writesWhileFirstIsBlocked, 1);

    final restored = await store.readChunkCheckpoint(
      reference,
      modelReference: modelReference,
    );
    expect(restored?.chunks.map((chunk) => chunk.index), orderedEquals([0, 1]));
  });

  test(
    'task-owned cleanup removes a checkpoint written while deletion is pending',
    () async {
      final adapter = _GatedCheckpointRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final reference = await _saveAndRelease(
        store,
        Uint8List.fromList([1, 2, 3, 4]),
        name: 'capture.wav',
        format: 'wav',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const chunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        status: AsrChunkStatus.succeeded,
        text: 'durable result',
      );

      final write = store.writeChunkCheckpoint(
          reference,
          const [
            chunk,
          ],
          modelReference: modelReference);
      await adapter.firstCheckpointWriteEntered.future;
      final queuedWrite = store.writeChunkCheckpoint(
          reference,
          const [
            chunk,
          ],
          modelReference: modelReference);
      await Future<void>.delayed(Duration.zero);
      final deletion = store.deleteIfUnreferenced(reference, const {});
      await Future<void>.delayed(Duration.zero);
      adapter.releaseFirstCheckpointWrite.complete();

      Object? writeError;
      try {
        await write;
      } catch (error) {
        writeError = error;
      }
      Object? queuedWriteError;
      try {
        await queuedWrite;
      } catch (error) {
        queuedWriteError = error;
      }
      await deletion;

      expect(
        writeError,
        anyOf(isNull, isA<AsrRetryChunkCheckpointUnavailableException>()),
      );
      expect(
        queuedWriteError,
        isA<AsrRetryChunkCheckpointUnavailableException>(),
      );
      expect(
        adapter.files.keys.where((key) => key.endsWith('.chunks')),
        isEmpty,
      );
    },
  );

  test('concurrent cleanup reports a failed pending deletion', () async {
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    final reference = await _saveAndRelease(
      store,
      Uint8List.fromList([1, 2, 3, 4]),
      name: 'capture.wav',
      format: 'wav',
    );
    final deletionFailure = StateError('simulated storage delete failure');
    adapter.deleteEntered = Completer<void>();
    adapter.releaseDelete = Completer<void>();
    adapter.deleteFailure = deletionFailure;

    final firstDeletion = store.delete(reference);
    await adapter.deleteEntered!.future;
    final concurrentDeletion = store.delete(reference);
    final concurrentPruning = store.prune(() => const {});
    await Future<void>.delayed(Duration.zero);

    adapter.releaseDelete!.complete();

    Object? firstError;
    try {
      await firstDeletion;
    } catch (error) {
      firstError = error;
    }
    Object? concurrentError;
    try {
      await concurrentDeletion;
    } catch (error) {
      concurrentError = error;
    }
    Object? pruningError;
    try {
      await concurrentPruning;
    } catch (error) {
      pruningError = error;
    }

    expect(firstError, same(deletionFailure));
    expect(concurrentError, same(deletionFailure));
    expect(pruningError, same(deletionFailure));

    await store.delete(reference);
    expect(adapter.files, isEmpty);
  });

  test(
    'full cleanup after a checkpoint-only clear also deletes audio',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: '11111111111111111111111111111111',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            '2222222222222222222222222222222222222222222222222222222222222222',
      );
      adapter.files['background/asr_retry/${reference.id}.audio'] =
          Uint8List.fromList([1, 2, 3, 4]);
      adapter.files['background/asr_retry/${reference.id}.chunks'] =
          Uint8List.fromList([1]);
      adapter.deleteEntered = Completer<void>();
      adapter.releaseDelete = Completer<void>();

      final checkpointClear = store.clearChunkCheckpoint(reference);
      await adapter.deleteEntered!.future;
      final fullDelete = store.delete(reference);
      final prune = store.prune(() => const {});
      await Future<void>.delayed(Duration.zero);

      adapter.releaseDelete!.complete();
      await Future.wait([checkpointClear, fullDelete, prune]);

      expect(adapter.files, isEmpty);
    },
  );

  test('legacy single checkpoints fail closed after a schema change', () async {
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    const reference = AsrAudioReference(
      id: '11111111111111111111111111111111',
      name: 'capture.wav',
      format: 'wav',
      byteLength: 4,
      sha256:
          '2222222222222222222222222222222222222222222222222222222222222222',
    );
    const oldChunk = AsrChunkResult(
      index: 0,
      startSeconds: 0,
      endSeconds: 1,
      totalChunks: 1,
      status: AsrChunkStatus.succeeded,
      text: 'legacy durable result',
    );
    adapter.files['background/asr_retry/${reference.id}.chunks'] =
        Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'audioReferenceId': reference.id,
          'audioSha256': reference.sha256,
          'modelReference': {'configId': 'provider', 'modelId': 'model'},
          'chunks': [oldChunk.toMap()],
        }),
      ),
    );

    await expectLater(
      store.readChunkCheckpoint(
        reference,
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
      ),
      throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
    );
  });

  test(
    'chunk checkpoints reject configured keys in model identities',
    () async {
      const configuredApiKey = 'earth-blue-7';
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      );
      const chunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        status: AsrChunkStatus.succeeded,
        text: 'recognized text',
      );

      await expectLater(
        store.writeChunkCheckpoint(
          reference,
          [chunk],
          modelReference: {
            'configId': 'provider',
            'modelId': '$configuredApiKey-model',
          },
          configuredApiKey: configuredApiKey,
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );
      expect(adapter.files, isEmpty);
    },
  );

  test(
    'short API keys in model identities are rejected for checkpoints',
    () async {
      const configuredApiKey = 'secret1';
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      );
      const chunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        status: AsrChunkStatus.succeeded,
        text: 'recognized text',
      );

      await expectLater(
        store.writeChunkCheckpoint(
          reference,
          [chunk],
          modelReference: const {
            'configId': 'provider-secret1',
            'modelId': 'stable-model',
          },
          configuredApiKey: configuredApiKey,
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );
      expect(adapter.files, isEmpty);
    },
  );

  test(
    'short API keys in model identities are omitted from retry snapshots',
    () {
      const configuredApiKey = 'secret1';
      final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData({
        'type': 'asr',
        'version': 2,
        'audioReference': {
          'version': AsrAudioReference.currentVersion,
          'id': 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          'name': 'capture.wav',
          'format': 'wav',
          'byteLength': 4,
          'sha256':
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        },
        'modelReference': {'configId': 'provider', 'modelId': 'model-secret1'},
      }, configuredApiKey: configuredApiKey);

      expect(sanitized, isNotNull);
      expect(sanitized, isNot(contains('modelReference')));
      expect(jsonEncode(sanitized), isNot(contains(configuredApiKey)));
    },
  );

  test(
    'short API keys preserve stable model identities in retry data',
    () async {
      const configuredApiKey = '4';
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      const reference = AsrAudioReference(
        id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      );
      const modelReference = {'configId': 'provider-4', 'modelId': 'whisper-4'};
      const chunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        status: AsrChunkStatus.succeeded,
        text: 'recognized text',
      );

      await store.writeChunkCheckpoint(
        reference,
        [chunk],
        modelReference: modelReference,
        configuredApiKey: configuredApiKey,
      );
      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
        configuredApiKey: configuredApiKey,
      );
      final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData({
        'type': 'asr',
        'version': 2,
        'audioReference': reference.toMap(),
        'modelReference': modelReference,
      }, configuredApiKey: configuredApiKey);

      expect(restored?.configId, modelReference['configId']);
      expect(restored?.modelId, modelReference['modelId']);
      expect(sanitized?['modelReference'], modelReference);
    },
  );

  test(
    'chunk checkpoint restore redacts configured keys from transcript text',
    () async {
      const configuredApiKey = 'earth-blue-7';
      const reference = AsrAudioReference(
        id: 'dddddddddddddddddddddddddddddddd',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      );
      final adapter = _MemoryRetryAdapter();
      adapter.files['background/asr_retry/${reference.id}.chunks'] =
          Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': AsrRetryChunkCheckpoint.currentVersion,
            'audioReferenceId': reference.id,
            'audioSha256': reference.sha256,
            'modelReference': {'configId': 'provider', 'modelId': 'model'},
            'chunks': [
              const AsrChunkResult(
                index: 0,
                startSeconds: 0,
                endSeconds: 1,
                totalChunks: 1,
                status: AsrChunkStatus.succeeded,
                text: 'transcript earth-blue-7',
                segments: [
                  AsrTranscriptSegment(text: 'segment earth-blue-7'),
                ],
                words: [AsrTranscriptSegment(text: 'word earth-blue-7')],
              ).toMap(),
            ],
          }),
        ),
      );

      final restored =
          await AsrRetryAudioStore(adapter: adapter).readChunkCheckpoint(
        reference,
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
        configuredApiKey: configuredApiKey,
      );

      expect(restored, isNotNull);
      final restoredChunk = restored!.chunks.single;
      expect(restoredChunk.text, isNot(contains(configuredApiKey)));
      expect(
        restoredChunk.segments!.single.text,
        isNot(contains(configuredApiKey)),
      );
      expect(
        restoredChunk.words!.single.text,
        isNot(contains(configuredApiKey)),
      );
    },
  );

  test(
    'chunk checkpoint writes preserve long ordinary transcript text',
    () async {
      const reference = AsrAudioReference(
        id: 'ababababababababababababababacac',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'dededededededededededededededededededededededededededededededede',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const sentence =
          'The forest remained quiet after rain and the narrow road dried slowly while the morning train moved across the valley';
      final transcript = List.filled(3, sentence).join(' ');
      final store = AsrRetryAudioStore(adapter: _MemoryRetryAdapter());

      await store.writeChunkCheckpoint(
          reference,
          [
            AsrChunkResult(
              index: 0,
              startSeconds: 0,
              endSeconds: 1,
              totalChunks: 1,
              status: AsrChunkStatus.succeeded,
              text: transcript,
            ),
          ],
          modelReference: modelReference);

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored!.chunks.single.status, AsrChunkStatus.succeeded);
      expect(restored.chunks.single.text, transcript);
    },
  );

  test(
    'chunk checkpoint preserves long unpunctuated technical transcripts',
    () async {
      const reference = AsrAudioReference(
        id: 'ababababababababababababababacac',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'dededededededededededededededededededededededededededededededede',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const technicalTerms =
          'Kubernetes PostgreSQL Prometheus OpenTelemetry protobuf '
          'vectorization interoperability';
      final transcript = List.filled(6, technicalTerms).join(' ');
      final store = AsrRetryAudioStore(adapter: _MemoryRetryAdapter());

      await store.writeChunkCheckpoint(
        reference,
        [
          AsrChunkResult(
            index: 0,
            startSeconds: 0,
            endSeconds: 1,
            totalChunks: 1,
            status: AsrChunkStatus.succeeded,
            text: transcript,
          ),
        ],
        modelReference: modelReference,
      );

      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored!.chunks.single.status, AsrChunkStatus.succeeded);
      expect(restored.chunks.single.text, transcript);
    },
  );

  test('chunk checkpoint rejects Base64-like transcript payloads', () async {
    const reference = AsrAudioReference(
      id: 'ababababababababababababababacac',
      name: 'capture.wav',
      format: 'wav',
      byteLength: 4,
      sha256:
          'dededededededededededededededededededededededededededededededede',
    );
    final adapter = _MemoryRetryAdapter();
    final key = 'background/asr_retry/${reference.id}.chunks';
    final store = AsrRetryAudioStore(adapter: adapter);
    final encodedPayload = List.filled(16, 'QmFzZTY0QXVkaW9QYXlsb2Fk').join();
    final spacedEncodedPayload = encodedPayload
        .replaceAllMapped(RegExp(r'.{1,4}'), (match) => '${match[0]} ')
        .trim();
    String withIrregularGroups(String payload) {
      const groupLengths = [7, 11, 13, 17, 19];
      final groups = <String>[];
      var payloadOffset = 0;
      var groupIndex = 0;
      while (payloadOffset < payload.length) {
        final proposedEnd =
            payloadOffset + groupLengths[groupIndex % groupLengths.length];
        final end = proposedEnd < payload.length ? proposedEnd : payload.length;
        groups.add(payload.substring(payloadOffset, end));
        payloadOffset = end;
        groupIndex++;
      }
      return groups.join(' ');
    }

    final irregularlySpacedPayload = withIrregularGroups(encodedPayload);
    final irregularlySpacedAudioPayload = withIrregularGroups(
      base64Encode(
        List<int>.generate(384, (index) => (index * 73 + index ~/ 3) & 0xff),
      ),
    );
    final irregularlySpacedLowEntropyPayload = withIrregularGroups(
      List.filled(384, 'A').join(),
    );

    for (final payload in [
      encodedPayload,
      spacedEncodedPayload,
      irregularlySpacedPayload,
      irregularlySpacedAudioPayload,
      irregularlySpacedLowEntropyPayload,
    ]) {
      await expectLater(
        store.writeChunkCheckpoint(
          reference,
          [
            AsrChunkResult(
              index: 0,
              startSeconds: 0,
              endSeconds: 1,
              totalChunks: 1,
              status: AsrChunkStatus.succeeded,
              text: payload,
            ),
          ],
          modelReference: const {'configId': 'provider', 'modelId': 'model'},
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );
    }
    expect(adapter.files.containsKey(key), isFalse);
  });

  test(
    'unsafe text on a failed checkpoint remains safely retryable',
    () async {
      const reference = AsrAudioReference(
        id: 'abababababababababababababababab',
        name: 'failed-chunk.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      );
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      final failedChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 1,
        status: AsrChunkStatus.failed,
        text: List.filled(384, 'A').join(),
      );
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final key = 'background/asr_retry/${reference.id}.chunks';

      await store.writeChunkCheckpoint(
        reference,
        [failedChunk],
        modelReference: modelReference,
      );
      final written = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(written, isNotNull);
      expect(written!.chunks, isEmpty);

      adapter.files[key] = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': AsrRetryChunkCheckpoint.currentVersion,
            'audioReferenceId': reference.id,
            'audioSha256': reference.sha256,
            'modelReference': modelReference,
            'chunks': [failedChunk.toMap()],
          }),
        ),
      );
      final restored = await store.readChunkCheckpoint(
        reference,
        modelReference: modelReference,
      );
      expect(restored, isNotNull);
      expect(restored!.chunks, isEmpty);
    },
  );

  test(
    'chunk checkpoint restore rejects malformed transcript segments',
    () async {
      const reference = AsrAudioReference(
        id: 'ffffffffffffffffffffffffffffffff',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final adapter = _MemoryRetryAdapter();
      final key = 'background/asr_retry/${reference.id}.chunks';
      final store = AsrRetryAudioStore(adapter: adapter);

      for (final field in ['segments', 'words']) {
        adapter.files[key] = Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'version': AsrRetryChunkCheckpoint.currentVersion,
              'audioReferenceId': reference.id,
              'audioSha256': reference.sha256,
              'modelReference': {'configId': 'provider', 'modelId': 'model'},
              'chunks': [
                {
                  'index': 0,
                  'startSeconds': 0,
                  'endSeconds': 1,
                  'totalChunks': 1,
                  'status': AsrChunkStatus.succeeded.name,
                  'text': 'valid transcript without subtitle cues',
                  field: [1],
                },
              ],
            }),
          ),
        );

        await expectLater(
          store.readChunkCheckpoint(
            reference,
            modelReference: const {'configId': 'provider', 'modelId': 'model'},
          ),
          throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
          reason: 'Malformed $field must not preserve a successful chunk state',
        );
      }
    },
  );

  test(
    'chunk checkpoint writes reject invalid transcript segment timing',
    () async {
      const reference = AsrAudioReference(
        id: '99999999999999999999999999999999',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final invalidSegments = <AsrTranscriptSegment>[
        const AsrTranscriptSegment(
          startSeconds: 7,
          endSeconds: 3,
          text: 'reversed segment',
        ),
        const AsrTranscriptSegment(
          startSeconds: -1,
          endSeconds: 2,
          text: 'negative segment',
        ),
        const AsrTranscriptSegment(
          startSeconds: 0,
          endSeconds: double.infinity,
          text: 'non-finite segment',
        ),
      ];

      for (final segment in invalidSegments) {
        await expectLater(
          store.writeChunkCheckpoint(
            reference,
            [
              AsrChunkResult(
                index: 0,
                startSeconds: 0,
                endSeconds: 10,
                status: AsrChunkStatus.succeeded,
                segments: [segment],
              ),
            ],
            modelReference: const {'configId': 'provider', 'modelId': 'model'},
          ),
          throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
        );
        expect(adapter.files, isEmpty);
      }
    },
  );

  test(
    'chunk checkpoint restore rejects invalid transcript segment timing',
    () async {
      const reference = AsrAudioReference(
        id: '99999999999999999999999999999998',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final invalidChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 10,
        status: AsrChunkStatus.succeeded,
        segments: const [
          AsrTranscriptSegment(
            startSeconds: 7,
            endSeconds: 3,
            text: 'reversed segment',
          ),
        ],
      );
      adapter.files['background/asr_retry/${reference.id}.chunks'] =
          Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': 3,
            'audioReferenceId': reference.id,
            'audioSha256': reference.sha256,
            'checkpoints': [
              AsrRetryChunkCheckpoint(
                audioReferenceId: reference.id,
                audioSha256: reference.sha256,
                audioUrlSha256: null,
                configId: 'provider',
                modelId: 'model',
                chunks: [invalidChunk],
              ).toMap(),
            ],
          }),
        ),
      );

      await expectLater(
        store.readChunkCheckpoint(
          reference,
          modelReference: const {'configId': 'provider', 'modelId': 'model'},
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );
    },
  );

  test(
    'chunk checkpoint restore rejects successful chunks without timing',
    () async {
      const reference = AsrAudioReference(
        id: 'ffffffffffffffffffffffffffffffff',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final adapter = _MemoryRetryAdapter();
      adapter.files['background/asr_retry/${reference.id}.chunks'] =
          Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': AsrRetryChunkCheckpoint.currentVersion,
            'audioReferenceId': reference.id,
            'audioSha256': reference.sha256,
            'modelReference': {'configId': 'provider', 'modelId': 'model'},
            'chunks': [
              {
                'index': 0,
                'totalChunks': 1,
                'status': AsrChunkStatus.succeeded.name,
                'text': 'malformed successful result',
              },
            ],
          }),
        ),
      );

      await expectLater(
        AsrRetryAudioStore(adapter: adapter).readChunkCheckpoint(
          reference,
          modelReference: const {'configId': 'provider', 'modelId': 'model'},
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );
    },
  );

  test(
    'chunk checkpoint restore rejects successful chunks without reusable text',
    () async {
      const reference = AsrAudioReference(
        id: '12121212121212121212121212121212',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final adapter = _MemoryRetryAdapter();
      adapter.files['background/asr_retry/${reference.id}.chunks'] =
          Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': AsrRetryChunkCheckpoint.currentVersion,
            'audioReferenceId': reference.id,
            'audioSha256': reference.sha256,
            'modelReference': {'configId': 'provider', 'modelId': 'model'},
            'chunks': [
              {
                'index': 0,
                'startSeconds': 0,
                'endSeconds': 1,
                'totalChunks': 1,
                'status': AsrChunkStatus.succeeded.name,
              },
            ],
          }),
        ),
      );

      await expectLater(
        AsrRetryAudioStore(adapter: adapter).readChunkCheckpoint(
          reference,
          modelReference: const {'configId': 'provider', 'modelId': 'model'},
        ),
        throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
      );
    },
  );

  test(
    'chunk checkpoint restore rejects missing or unknown statuses',
    () async {
      const reference = AsrAudioReference(
        id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      );
      final adapter = _MemoryRetryAdapter();
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      final store = AsrRetryAudioStore(adapter: adapter);

      for (final status in <String?>[null, 'processing']) {
        final chunk = <String, dynamic>{
          'index': 0,
          'startSeconds': 0,
          'endSeconds': 1,
          'totalChunks': 1,
          if (status != null) 'status': status,
          'text': 'must not be replayed',
        };
        adapter.files['background/asr_retry/${reference.id}.chunks'] =
            Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'version': 3,
              'audioReferenceId': reference.id,
              'audioSha256': reference.sha256,
              'checkpoints': [
                {
                  'version': AsrRetryChunkCheckpoint.currentVersion,
                  'audioReferenceId': reference.id,
                  'audioSha256': reference.sha256,
                  'modelReference': modelReference,
                  'chunks': [chunk],
                },
              ],
            }),
          ),
        );

        expect(
          AsrRetryAudioStore.sanitizeVersionedRetryData({
            'version': 2,
            'audioReference': reference.toMap(),
            'modelReference': modelReference,
            'chunks': [chunk],
          }),
          isNull,
          reason: 'Invalid task retry status $status must fail closed',
        );

        await expectLater(
          store.readChunkCheckpoint(
            reference,
            modelReference: modelReference,
          ),
          throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
          reason: 'Invalid stored status $status must fail closed',
        );
      }
    },
  );

  test(
    'task retry sanitization rejects unknown chunk status when preserving rows',
    () {
      final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData(
        {
          'version': 2,
          'audioReference': {
            'version': AsrAudioReference.currentVersion,
            'id': '34343434343434343434343434343434',
            'name': 'capture.wav',
            'format': 'wav',
            'byteLength': 4,
            'sha256': List.filled(64, 'c').join(),
          },
          'chunks': [
            {
              'index': 0,
              'startSeconds': 0,
              'endSeconds': 1,
              'totalChunks': 1,
              'status': 'future-provider-state',
            },
          ],
        },
        allowUnknownChunkStatuses: true,
      );

      expect(sanitized, isNotNull);
      expect(
        ((sanitized!['chunks'] as List).single as Map)['status'],
        AsrChunkStatus.uncertain.name,
        reason:
            'an unknown provider outcome must not be normalized to a retryable failure',
      );
    },
  );

  test(
    'task retry sanitization rejects malformed checkpoints when preserving rows',
    () {
      final audioReference = {
        'version': AsrAudioReference.currentVersion,
        'id': List.filled(32, 'a').join(),
        'name': 'capture.wav',
        'format': 'wav',
        'byteLength': 4,
        'sha256': List.filled(64, 'c').join(),
      };

      for (final malformedChunks in <Object?>[
        'not-a-checkpoint-list',
        ['not-a-checkpoint-map'],
      ]) {
        final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData(
          {
            'version': 2,
            'audioReference': audioReference,
            'chunks': malformedChunks,
          },
          allowUnknownChunkStatuses: true,
        );

        expect(
          sanitized,
          isNull,
          reason: 'present malformed checkpoints cannot be dropped safely',
        );
      }
    },
  );

  test(
    'chunk checkpoint restore rejects fractional chunk identity fields',
    () async {
      const reference = AsrAudioReference(
        id: 'abababababababababababababababab',
        name: 'capture.wav',
        format: 'wav',
        byteLength: 4,
        sha256:
            'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
      );
      final adapter = _MemoryRetryAdapter();
      const modelReference = {'configId': 'provider', 'modelId': 'model'};
      const malformedChunkFields = [
        {'index': 0.9, 'totalChunks': 1},
        {'index': 0, 'totalChunks': 1.9},
      ];

      for (final fields in malformedChunkFields) {
        adapter.files['background/asr_retry/${reference.id}.chunks'] =
            Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'version': AsrRetryChunkCheckpoint.currentVersion,
              'audioReferenceId': reference.id,
              'audioSha256': reference.sha256,
              'modelReference': modelReference,
              'chunks': [
                {
                  ...fields,
                  'startSeconds': 0,
                  'endSeconds': 1,
                  'status': AsrChunkStatus.succeeded.name,
                  'text': 'must not be reused',
                },
              ],
            }),
          ),
        );

        await expectLater(
          AsrRetryAudioStore(
            adapter: adapter,
          ).readChunkCheckpoint(reference, modelReference: modelReference),
          throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
        );
      }
    },
  );

  test('unsupported chunk checkpoint versions fail closed', () async {
    final adapter = _MemoryRetryAdapter();
    const reference = AsrAudioReference(
      id: 'cccccccccccccccccccccccccccccccc',
      name: 'capture.wav',
      format: 'wav',
      byteLength: 4,
      sha256:
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
    );
    adapter.files['background/asr_retry/${reference.id}.chunks'] =
        Uint8List.fromList(
      utf8.encode(jsonEncode({'version': 3, 'checkpoints': const []})),
    );

    await expectLater(
      AsrRetryAudioStore(adapter: adapter).readChunkCheckpoint(
        reference,
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
      ),
      throwsA(isA<AsrRetryChunkCheckpointUnavailableException>()),
    );
  });

  test(
    'versioned audio references survive a fresh store and detect loss',
    () async {
      final adapter = _MemoryRetryAdapter();
      final firstStore = AsrRetryAudioStore(adapter: adapter);
      final reference = await _saveAndRelease(
        firstStore,
        Uint8List.fromList([1, 2, 3, 4]),
        name: 'capture.wav',
        format: 'wav',
      );

      final restoredReference = AsrAudioReference.fromMap(
        jsonDecode(jsonEncode(reference.toMap())) as Map<String, dynamic>,
      );
      expect(restoredReference.version, 1);
      expect(
        await AsrRetryAudioStore(adapter: adapter).load(restoredReference),
        [1, 2, 3, 4],
      );

      adapter.files['background/asr_retry/${restoredReference.id}.audio'] =
          Uint8List.fromList([4, 3, 2, 1]);
      await expectLater(
        firstStore.load(restoredReference),
        throwsA(
          isA<AsrRetryAudioUnavailableException>().having(
            (error) => error.corrupt,
            'corrupt',
            isTrue,
          ),
        ),
      );

      await firstStore.delete(restoredReference);
      await expectLater(
        firstStore.load(restoredReference),
        throwsA(isA<AsrRetryAudioUnavailableException>()),
      );
    },
  );

  test(
    'retry audio references omit credential-shaped local file names',
    () async {
      final store = AsrRetryAudioStore(adapter: _MemoryRetryAdapter());
      final reference = await _saveAndRelease(
        store,
        Uint8List.fromList([1, 2, 3]),
        name: 'sk-abcdefghijklmnop.wav',
        format: 'wav',
      );

      final retryJson = jsonEncode({
        'version': 2,
        'audioReference': reference.toMap(),
      });

      expect(reference.name, 'audio.wav');
      expect(retryJson, isNot(contains('sk-abcdefghijklmnop')));
    },
  );

  test('retry audio names omit credential path suffixes', () async {
    const secret = 'opaque-path-secret.wav';
    final store = AsrRetryAudioStore(adapter: _MemoryRetryAdapter());

    for (final name in [
      'api_key/$secret',
      'https://media.example.test/api_key/$secret',
    ]) {
      final reference = await _saveAndRelease(
        store,
        Uint8List.fromList([1, 2, 3]),
        name: name,
        format: 'wav',
      );

      expect(reference.name, 'audio.wav');
      expect(jsonEncode(reference.toMap()), isNot(contains(secret)));
    }
  });

  test('retry audio names omit credentials in Windows paths', () async {
    const secret = 'opaque-windows-path-secret.wav';
    final store = AsrRetryAudioStore(adapter: _MemoryRetryAdapter());
    final reference = await _saveAndRelease(
      store,
      Uint8List.fromList([1, 2, 3]),
      name: r'C:\work\api_key\opaque-windows-path-secret.wav',
      format: 'wav',
    );

    expect(reference.name, 'audio.wav');
    expect(jsonEncode(reference.toMap()), isNot(contains(secret)));
  });

  test('sanitizer fallbacks never reintroduce configured API keys', () async {
    const audioApiKey = 'audio';
    final store = AsrRetryAudioStore(adapter: _MemoryRetryAdapter());
    final reference = await store.save(
      Uint8List.fromList([1, 2, 3]),
      name: 'audio-private.wav',
      format: 'wav',
      configuredApiKey: audioApiKey,
    );
    await store.releaseProtection(reference);
    const diagnosticApiKey = 'ASR';
    final diagnostic = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
      'data:audio/wav;base64,AAAA',
      configuredApiKey: diagnosticApiKey,
    );

    expect(reference.name, isNot(contains(audioApiKey)));
    expect(jsonEncode(reference.toMap()), isNot(contains(audioApiKey)));
    expect(diagnostic, isNot(contains(diagnosticApiKey)));
  });

  test(
    'audio reference formats are sanitized when restored and serialized',
    () {
      const secretFormat = 'sk-abcdefghijklmnop';
      final map = {
        'version': AsrAudioReference.currentVersion,
        'id': List.filled(32, 'a').join(),
        'name': 'capture.wav',
        'format': secretFormat,
        'byteLength': 1,
        'sha256': List.filled(64, '0').join(),
      };

      final restored = AsrAudioReference.fromMap(map);
      final restoredJson = jsonEncode(restored.toMap());
      final directJson = jsonEncode(
        AsrAudioReference(
          id: List.filled(32, 'a').join(),
          name: 'capture.wav',
          format: secretFormat,
          byteLength: 1,
          sha256: List.filled(64, '0').join(),
        ).toMap(),
      );

      expect(restored.format, 'bin');
      expect(restored.toMap()['format'], 'bin');
      expect(restoredJson, isNot(contains(secretFormat)));
      expect(directJson, isNot(contains(secretFormat)));
    },
  );

  test('audio references reject invalid identifiers before serialization', () {
    const idSecret = 'opaque-reference-id-secret';
    const shaSecret = 'opaque-reference-digest-secret';
    final invalidId = AsrAudioReference(
      id: idSecret,
      name: 'capture.wav',
      format: 'wav',
      byteLength: 1,
      sha256: List.filled(64, '0').join(),
    );
    final invalidSha = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: 'capture.wav',
      format: 'wav',
      byteLength: 1,
      sha256: shaSecret,
    );

    expect(() => invalidId.toMap(), throwsFormatException);
    expect(() => invalidSha.toMap(), throwsFormatException);
  });

  test(
    'empty local retry references are rejected while URLs may be empty',
    () async {
      const localReference = AsrAudioReference(
        id: '0123456789abcdef0123456789abcdef',
        name: 'empty.wav',
        format: 'wav',
        byteLength: 0,
        sha256:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      final adapter = _MemoryRetryAdapter()
        ..files['background/asr_retry/${localReference.id}.audio'] = Uint8List(
          0,
        );

      await expectLater(
        AsrRetryAudioStore(adapter: adapter).load(localReference),
        throwsA(
          isA<AsrRetryAudioUnavailableException>().having(
            (error) => error.corrupt,
            'corrupt',
            isTrue,
          ),
        ),
      );
      await expectLater(
        AsrRetryAudioStore(
          adapter: adapter,
        ).save(Uint8List(0), name: 'empty.wav', format: 'wav'),
        throwsFormatException,
      );
      await expectLater(
        AsrRetryAudioStore(adapter: adapter).writeChunkCheckpoint(
          localReference,
          const [],
          modelReference: const {'configId': 'provider', 'modelId': 'model'},
        ),
        throwsA(isA<AsrRetryAudioUnavailableException>()),
      );
      expect(() => localReference.toMap(), throwsFormatException);
      expect(
        () => AsrAudioReference.fromMap({
          'version': AsrAudioReference.currentVersion,
          'id': localReference.id,
          'name': localReference.name,
          'format': localReference.format,
          'byteLength': 0,
          'sha256': localReference.sha256,
        }),
        throwsFormatException,
      );

      final urlReference = AsrAudioReference(
        id: 'fedcba9876543210fedcba9876543210',
        name: 'https://media.example.test/audio',
        format: 'url',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: 'https://media.example.test/audio',
      );
      final serializedUrl = urlReference.toMap();
      expect(serializedUrl['byteLength'], 0);
      expect(AsrAudioReference.fromMap(serializedUrl).isUrl, isTrue);
    },
  );

  test('retry audio URLs only accept HTTP or HTTPS sources', () {
    AsrAudioReference referenceFor(String url) => AsrAudioReference.fromMap({
          'version': AsrAudioReference.currentVersion,
          'id': '0123456789abcdef0123456789abcdef',
          'name': url,
          'format': 'url',
          'byteLength': 0,
          'sha256': List.filled(64, '0').join(),
          'url': url,
        });

    for (final scheme in ['http', 'https']) {
      final url = '$scheme://media.example.test/audio';
      final reference = referenceFor(url);
      expect(reference.requiresSourceReselection, isFalse);
      expect(reference.url, url);
      expect(reference.toMap()['url'], url);
    }

    final unsupported = referenceFor('ftp://media.example.test/audio');
    expect(unsupported.requiresSourceReselection, isTrue);
    expect(unsupported.url, isEmpty);
    expect(unsupported.toMap()['requiresSourceReselection'], isTrue);
  });

  test('fully encoded safe HTTP URL references restore as usable URLs', () {
    const encodedUrl = 'https%3A%2F%2Fmedia.example.test%2Faudio';
    const normalizedUrl = 'https://media.example.test/audio';
    final reference = AsrAudioReference.fromMap({
      'version': AsrAudioReference.currentVersion,
      'id': '0123456789abcdef0123456789abcdef',
      'name': encodedUrl,
      'format': 'url',
      'byteLength': 0,
      'sha256': List.filled(64, '0').join(),
      'url': encodedUrl,
    });

    expect(reference.requiresSourceReselection, isFalse);
    expect(reference.url, normalizedUrl);
    expect(reference.toMap()['url'], normalizedUrl);
  });

  test('UUID URL path segments remain valid retry sources', () {
    const url =
        'https://media.example.test/audio/550e8400-e29b-41d4-a716-446655440000';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    expect(AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(url), url);
    final serialized = reference.toMap();
    expect(serialized['url'], url);
    expect(serialized.containsKey('requiresSourceReselection'), isFalse);
  });

  test('UUID query identifiers remain valid retry sources', () {
    const url =
        'https://media.example.test/audio?id=550e8400-e29b-41d4-a716-446655440000';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    final serialized = reference.toMap();
    expect(serialized['url'], url);
    expect(serialized.containsKey('requiresSourceReselection'), isFalse);
    final restored = AsrAudioReference.fromMap(serialized);
    expect(restored.url, url);
    expect(restored.requiresSourceReselection, isFalse);
  });

  test('retry URLs redact credentials encoded in the authority', () {
    const secret = 'opaque-encoded-authority-secret-90817';
    final urls = [
      'https://user%3A$secret%40media.example.test/audio',
      'https://user%253A$secret%2540media.example.test/audio',
    ];

    for (final url in urls) {
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
      );
      final reference = AsrAudioReference(
        id: List.filled(32, 'a').join(),
        name: url,
        format: 'url',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: url,
      );
      final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'url': url,
      });
      final serialized = jsonEncode({
        'snapshot': snapshot.toMap(),
        'reference': reference.toMap(),
        'diagnostics': diagnostics,
      });

      expect(serialized, isNot(contains(secret)));
      expect(
        AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(url),
        isNot(contains(secret)),
      );
      expect(AsrRetryConfigSnapshot.urlContainsCredentials(url), isTrue);
      expect(reference.toMap()['requiresSourceReselection'], isTrue);
    }
  });

  test('UUID URL path followed by a route label remains valid', () {
    const url =
        'https://media.example.test/audio/550e8400-e29b-41d4-a716-446655440000/download';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    expect(AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(url), url);
    final serialized = reference.toMap();
    expect(serialized['url'], url);
    expect(serialized.containsKey('requiresSourceReselection'), isFalse);
  });

  test('SHA-256 URL path identifiers remain valid retry sources', () {
    const digest =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const url = 'https://media.example.test/audio/$digest';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    expect(AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(url), url);
    final serialized = reference.toMap();
    expect(serialized['url'], url);
    expect(serialized.containsKey('requiresSourceReselection'), isFalse);
  });

  test('compact UUID URL path identifiers remain valid retry sources', () {
    const identifier = '550e8400e29b41d4a716446655440000';
    const url = 'https://media.example.test/audio/$identifier';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    expect(AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(url), url);
    final serialized = reference.toMap();
    expect(serialized['url'], url);
    expect(serialized.containsKey('requiresSourceReselection'), isFalse);
  });

  test('URL references redact credentials while restoring and serializing', () {
    const secret = 'opaque-url-secret';
    const url = 'https://media.example.test/audio?api_key=$secret';
    final directReference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final directMap = directReference.toMap();
    expect(jsonEncode(directMap), isNot(contains(secret)));
    expect(directMap['requiresSourceReselection'], isTrue);

    final reference = AsrAudioReference.fromMap({
      'version': AsrAudioReference.currentVersion,
      'id': List.filled(32, 'a').join(),
      'name': url,
      'format': 'url',
      'byteLength': 0,
      'sha256': List.filled(64, '0').join(),
      'url': url,
    });

    expect(reference.requiresSourceReselection, isTrue);
    expect(reference.url, isNot(contains(secret)));
    expect(jsonEncode(reference.toMap()), isNot(contains(secret)));
  });

  test('URL references omit configured 32-character hex API keys', () {
    const apiKey = 'abcdef0123456789abcdef0123456789';
    const url = 'https://media.example.test/audio/$apiKey/download';
    final directReference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final map = {
      'version': AsrAudioReference.currentVersion,
      'id': List.filled(32, 'a').join(),
      'name': url,
      'format': 'url',
      'byteLength': 0,
      'sha256': List.filled(64, '0').join(),
      'url': url,
    };
    final reference = AsrAudioReference.fromMap(map, configuredApiKey: apiKey);

    final serialized = reference.toMap(configuredApiKey: apiKey);
    final directSerialized = directReference.toMap(configuredApiKey: apiKey);
    expect(reference.requiresSourceReselection, isTrue);
    expect(reference.url, isNot(contains(apiKey)));
    expect(jsonEncode(serialized), isNot(contains(apiKey)));
    expect(jsonEncode(directSerialized), isNot(contains(apiKey)));
    expect(serialized['requiresSourceReselection'], isTrue);
    expect(serialized['url'], isNot(contains(apiKey)));
    expect(serialized['name'], isNot(contains(apiKey)));
  });

  test('URL references redact userinfo in fully percent-encoded URLs', () {
    const secret = 'opaque-encoded-reference-userinfo-secret';
    const url = 'https%3A%2F%2Fuser%3A$secret%40media.example.test%2Faudio';
    final directReference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    expect(AsrRetryConfigSnapshot.urlContainsCredentials(url), isTrue);
    final directMap = directReference.toMap();
    expect(jsonEncode(directMap), isNot(contains(secret)));
    expect(directMap['url'], 'https://media.example.test/audio');
    expect(directMap['requiresSourceReselection'], isTrue);

    final restored = AsrAudioReference.fromMap({
      'version': AsrAudioReference.currentVersion,
      'id': List.filled(32, 'a').join(),
      'name': url,
      'format': 'url',
      'byteLength': 0,
      'sha256': List.filled(64, '0').join(),
      'url': url,
    });
    expect(restored.requiresSourceReselection, isTrue);
    expect(jsonEncode(restored.toMap()), isNot(contains(secret)));
  });

  test('URL references omit short Base64 embedded in query text', () {
    final payload = List.filled(64, 'Z').join();
    final url = 'https://media.example.test/audio?source=audio:$payload';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    final serialized = reference.toMap();
    expect(jsonEncode(serialized), isNot(contains(payload)));
    expect(serialized['requiresSourceReselection'], isTrue);
  });

  test('all-zero audio Base64 is not mistaken for URL identifiers', () {
    final payload = List.filled(64, 'A').join();
    final url = 'https://media.example.test/audio?source=$payload';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    expect(jsonEncode(reference.toMap()), isNot(contains(payload)));
    expect(
      AsrRetryConfigSnapshot.sanitizeDiagnosticText('request failed: $payload'),
      isNot(contains(payload)),
    );
  });

  test('retry URLs redact credential-shaped hostname labels', () {
    const secret = 'sk-abcdefghijklmnop';
    const host = 'https://$secret.asr.example.test/transcribe';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      const AsrConfig(
        apiKey: 'live-api-key',
        host: host,
        model: 'whisper-small',
      ),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: host,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: host,
    );
    final referenceMap = reference.toMap();
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': host,
      'message': 'request failed at $host',
    });

    expect(snapshot.host, '');
    expect(jsonEncode(snapshot.toMap()), isNot(contains(secret)));
    expect(jsonEncode(referenceMap), isNot(contains(secret)));
    expect(referenceMap['requiresSourceReselection'], isTrue);
    expect(referenceMap['url'], '');
    expect(jsonEncode(diagnostics), isNot(contains(secret)));
    expect(AsrRetryConfigSnapshot.urlContainsCredentials(host), isTrue);
    expect(AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(host), '');
    expect(
      () => snapshot.toConfig(
        apiKey: 'live-api-key',
        liveHost: host,
        liveModel: 'whisper-small',
      ),
      throwsStateError,
    );
  });

  test('retry URLs redact Base64 payloads in hostname labels', () {
    final payload = List.filled(60, 'Z').join();
    final url = 'https://$payload.example.test/audio';
    final reference = AsrAudioReference(
      id: List.filled(32, 'b').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    final serialized = reference.toMap();
    expect(jsonEncode(serialized), isNot(contains(payload)));
    expect(serialized['url'], isEmpty);
    expect(serialized['requiresSourceReselection'], isTrue);
  });

  test('retry URLs preserve repeated benign query parameters', () {
    const url = 'https://media.example.test/audio?part=1&part=2';
    const credentialedUrl =
        'https://media.example.test/audio?part=1&api_key=query-secret&part=2';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    final serializedUrl = reference.toMap()['url'] as String;
    final sanitizedCredentialedUrl =
        AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(credentialedUrl);

    expect(serializedUrl, url);
    expect(Uri.parse(serializedUrl).queryParametersAll['part'], ['1', '2']);
    expect(
      sanitizedCredentialedUrl,
      'https://media.example.test/audio?part=1&part=2',
    );
    expect(sanitizedCredentialedUrl, isNot(contains('query-secret')));
  });

  test('retry URLs redact bracketed credential query names', () {
    const cases = [
      (
        url:
            'https://asr.example.test/transcribe?api_key[]=opaque-array-secret',
        secret: 'opaque-array-secret',
      ),
      (
        url:
            'https://asr.example.test/transcribe?api_key[0]=opaque-index-secret',
        secret: 'opaque-index-secret',
      ),
      (
        url:
            'https://asr.example.test/transcribe?options[api_key]=opaque-nested-name-secret',
        secret: 'opaque-nested-name-secret',
      ),
      (
        url:
            'https://asr.example.test/transcribe?options%5Bapi_key%5D=opaque-encoded-nested-name-secret',
        secret: 'opaque-encoded-nested-name-secret',
      ),
    ];

    for (final testCase in cases) {
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(
          apiKey: 'different-live-key',
          host: testCase.url,
          model: 'whisper-small',
        ),
      );
      final reference = AsrAudioReference(
        id: List.filled(32, 'a').join(),
        name: testCase.url,
        format: 'url',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: testCase.url,
      );
      final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'url': testCase.url,
        'message': 'request failed at ${testCase.url}',
      });
      final serialized = jsonEncode({
        'snapshot': snapshot.toMap(),
        'reference': reference.toMap(),
        'diagnostics': diagnostics,
      });

      expect(serialized, isNot(contains(testCase.secret)));
      expect(reference.toMap()['requiresSourceReselection'], isTrue);
      expect(
        AsrRetryConfigSnapshot.urlContainsCredentials(testCase.url),
        isTrue,
      );
    }
  });

  test('retry URLs remove userinfo from nested URL query values', () {
    const secret = 'opaque-nested-query-password';
    const urls = [
      'https://asr.example.test/transcribe?source=https://user:$secret@media.example.test/audio&mode=verbose',
      'https://asr.example.test/transcribe?source=https%3A%2F%2Fuser%3A$secret%40media.example.test%2Faudio&mode=verbose',
      'https://asr.example.test/transcribe?source=https%253A%252F%252Fuser%253A$secret%2540media.example.test%252Faudio&mode=verbose',
    ];

    for (final url in urls) {
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
      );
      final reference = AsrAudioReference(
        id: List.filled(32, 'a').join(),
        name: url,
        format: 'url',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: url,
      );
      final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'url': url,
        'message': 'request failed at $url',
      });
      final sanitizedDiagnosticUrl =
          AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(url);

      expect(jsonEncode(snapshot.toMap()), isNot(contains(secret)));
      expect(jsonEncode(reference.toMap()), isNot(contains(secret)));
      expect(jsonEncode(diagnostics), isNot(contains(secret)));
      expect(sanitizedDiagnosticUrl, isNot(contains(secret)));
      expect(reference.toMap()['requiresSourceReselection'], isTrue);
      expect(AsrRetryConfigSnapshot.urlContainsCredentials(url), isTrue);
      expect(sanitizedDiagnosticUrl, contains('mode=verbose'));
    }
  });

  test('retry URLs omit multi-encoded audio query payloads', () {
    final payload = base64Encode(Uint8List(300));
    final onceEncodedPayload = payload.codeUnits
        .map((unit) => '%${unit.toRadixString(16).padLeft(2, '0')}')
        .join();
    final twiceEncodedPayload = onceEncodedPayload.replaceAll('%', '%25');
    final url =
        'https://asr.example.test/transcribe?audio=$twiceEncodedPayload&mode=verbose';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': url,
    });

    final serialized = jsonEncode({
      'snapshot': snapshot.toMap(),
      'reference': reference.toMap(),
      'diagnostics': diagnostics,
    });

    expect(serialized, isNot(contains(twiceEncodedPayload)));
    expect(reference.toMap()['requiresSourceReselection'], isTrue);
    expect(AsrRetryConfigSnapshot.urlContainsCredentials(url), isTrue);
  });

  test('retry URLs strip credential paths nested in query values', () {
    const secret = 'opaque-query-path-secret';
    const url =
        'https://asr.example.test/transcribe?source=%2Fv1%2Fapi_key%2F$secret&mode=verbose';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      const AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final sanitizedDiagnosticUrl = AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(
      url,
    );

    expect(jsonEncode(snapshot.toMap()), isNot(contains(secret)));
    expect(jsonEncode(reference.toMap()), isNot(contains(secret)));
    expect(reference.toMap()['requiresSourceReselection'], isTrue);
    expect(AsrRetryConfigSnapshot.urlContainsCredentials(url), isTrue);
    expect(sanitizedDiagnosticUrl, isNot(contains(secret)));
    expect(sanitizedDiagnosticUrl, contains('mode=verbose'));
  });

  test(
    'retry URLs strip credential paths separated by encoded backslashes',
    () {
      const secret = 'opaque-backslash-path-secret';
      const url = 'https://media.example.test/v1/api_key%5C$secret';
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        const AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
      );
      final reference = AsrAudioReference(
        id: List.filled(32, 'a').join(),
        name: url,
        format: 'url',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: url,
      );
      final referenceMap = reference.toMap();
      final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'url': url,
      });
      final sanitizedDiagnosticUrl =
          AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(url);
      final restoredReference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(referenceMap),
      );

      expect(jsonEncode(snapshot.toMap()), isNot(contains(secret)));
      expect(jsonEncode(referenceMap), isNot(contains(secret)));
      expect(referenceMap['requiresSourceReselection'], isTrue);
      expect(jsonEncode(restoredReference.toMap()), isNot(contains(secret)));
      expect(jsonEncode(diagnostics), isNot(contains(secret)));
      expect(sanitizedDiagnosticUrl, isNot(contains(secret)));
      expect(AsrRetryConfigSnapshot.urlContainsCredentials(url), isTrue);
    },
  );

  test('audio URL references omit inline Base64 payloads', () {
    final payload = base64Encode(Uint8List(512));
    final urls = [
      'https://media.example.test/audio/$payload',
      'https://media.example.test/audio?source=$payload',
      'data:audio/wav;base64,$payload',
    ];

    for (final url in urls) {
      final reference = AsrAudioReference(
        id: List.filled(32, 'a').join(),
        name: url,
        format: 'wav',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: url,
      );
      final serializedReference = reference.toMap();
      final encodedReference = jsonEncode(serializedReference);
      final configSnapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
      ).toMap();
      final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'url': url,
      });
      final restoredReference = AsrAudioReference.fromMap({
        'version': AsrAudioReference.currentVersion,
        'id': List.filled(32, 'a').join(),
        'name': url,
        'format': 'wav',
        'byteLength': 0,
        'sha256': List.filled(64, '0').join(),
        'url': url,
      });

      expect(encodedReference, isNot(contains(payload)));
      expect(serializedReference['url'], '');
      expect(serializedReference['name'], 'audio.wav');
      expect(serializedReference['requiresSourceReselection'], isTrue);
      expect(restoredReference.isUrl, isTrue);
      expect(restoredReference.url, '');
      expect(restoredReference.requiresSourceReselection, isTrue);
      expect(jsonEncode(restoredReference.toMap()), isNot(contains(payload)));
      expect(AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(url), '');
      expect(jsonEncode(configSnapshot), isNot(contains(payload)));
      expect(configSnapshot['host'], '');
      expect(jsonEncode(diagnostics), isNot(contains(payload)));
    }
  });

  test('retry URLs omit short Base64 audio payloads in generic fields', () {
    final sourceBytes = Uint8List.fromList([
      for (var index = 0; index < 150; index++) (index * 73 + 41) % 256,
    ]);
    final payload = base64Encode(sourceBytes);
    expect(payload, hasLength(200));
    final encodedPayload = Uri.encodeQueryComponent(payload);
    final url = 'https://media.example.test/audio?source=$encodedPayload';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'wav',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final serializedReference = reference.toMap();
    final configSnapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
    ).toMap();
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': url,
    });

    expect(jsonEncode(serializedReference), isNot(contains(encodedPayload)));
    expect(serializedReference['url'], '');
    expect(serializedReference['requiresSourceReselection'], isTrue);
    expect(jsonEncode(configSnapshot), isNot(contains(encodedPayload)));
    expect(jsonEncode(diagnostics), isNot(contains(encodedPayload)));
  });

  test('retry URLs omit short Base64 under unknown query keys', () {
    final payload = base64Encode(
      Uint8List.fromList(List<int>.filled(150, 255)),
    );
    expect(payload, hasLength(200));
    final encodedPayload = Uri.encodeQueryComponent(payload);
    final url = 'https://media.example.test/audio?payload=$encodedPayload';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'wav',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final serializedReference = reference.toMap();
    final configSnapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
    ).toMap();
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': url,
    });

    expect(jsonEncode(serializedReference), isNot(contains(encodedPayload)));
    expect(serializedReference['url'], '');
    expect(serializedReference['requiresSourceReselection'], isTrue);
    expect(jsonEncode(configSnapshot), isNot(contains(encodedPayload)));
    expect(jsonEncode(diagnostics), isNot(contains(encodedPayload)));
  });

  test('retry URLs omit short Base64 audio payloads in fragments', () {
    final payload = List.filled(64, 'Z').join();
    final url = 'https://media.example.test/audio#source=$payload&mode=verbose';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    final serialized = reference.toMap();
    expect(jsonEncode(serialized), isNot(contains(payload)));
    expect(serialized['url'], '');
    expect(serialized['requiresSourceReselection'], isTrue);
  });

  test('retry URLs omit short Base64 audio payloads in path segments', () {
    final sourceBytes = Uint8List.fromList([
      for (var index = 0; index < 150; index++) (index * 73 + 41) % 256,
    ]);
    final payload = base64Url.encode(sourceBytes);
    expect(payload, hasLength(200));
    final url = 'https://media.example.test/audio/$payload';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'wav',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final serializedReference = reference.toMap();
    final configSnapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
    ).toMap();
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': url,
    });

    expect(jsonEncode(serializedReference), isNot(contains(payload)));
    expect(serializedReference['url'], '');
    expect(serializedReference['requiresSourceReselection'], isTrue);
    expect(jsonEncode(configSnapshot), isNot(contains(payload)));
    expect(jsonEncode(diagnostics), isNot(contains(payload)));
  });

  test(
    'retry URLs omit Base64 that also matches a SHA-256 path identifier',
    () {
      final payload = base64Encode(Uint8List(48));
      expect(payload, List.filled(64, 'A').join());
      final url = 'https://media.example.test/audio/$payload';
      final reference = AsrAudioReference(
        id: List.filled(32, 'a').join(),
        name: url,
        format: 'wav',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: url,
      );
      final serializedReference = reference.toMap();
      final configSnapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
      ).toMap();
      final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'url': url,
      });

      expect(jsonEncode(serializedReference), isNot(contains(payload)));
      expect(serializedReference['url'], '');
      expect(serializedReference['requiresSourceReselection'], isTrue);
      expect(jsonEncode(configSnapshot), isNot(contains(payload)));
      expect(jsonEncode(diagnostics), isNot(contains(payload)));
    },
  );

  test('retry URLs omit repeated Base64 under identifier query keys', () {
    final payload = base64Encode(Uint8List(48));
    final url = 'https://media.example.test/audio?id=$payload';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'wav',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );

    final serialized = reference.toMap();
    expect(jsonEncode(serialized), isNot(contains(payload)));
    expect(serialized['url'], '');
    expect(serialized['requiresSourceReselection'], isTrue);
  });

  test('retry URLs omit Base64 paths split by slash separators', () {
    final payload = base64Encode(
      Uint8List.fromList(List<int>.filled(150, 255)),
    );
    expect(payload, hasLength(200));
    final url = 'https://media.example.test/audio/$payload';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'wav',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final serializedReference = reference.toMap();
    final configSnapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
    ).toMap();
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': url,
    });

    expect(jsonEncode(serializedReference), isNot(contains(payload)));
    expect(serializedReference['url'], '');
    expect(serializedReference['requiresSourceReselection'], isTrue);
    expect(jsonEncode(configSnapshot), isNot(contains(payload)));
    expect(jsonEncode(diagnostics), isNot(contains(payload)));
  });

  test('retry URLs omit slash-split Base64 in arbitrary path segments', () {
    final payload = base64Encode(
      Uint8List.fromList(List<int>.filled(150, 255)),
    );
    expect(payload, hasLength(200));
    final url = 'https://media.example.test/media/$payload';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'wav',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final serializedReference = reference.toMap();
    final configSnapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
    ).toMap();
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': url,
    });

    expect(jsonEncode(serializedReference), isNot(contains(payload)));
    expect(serializedReference['url'], '');
    expect(serializedReference['requiresSourceReselection'], isTrue);
    expect(jsonEncode(configSnapshot), isNot(contains(payload)));
    expect(jsonEncode(diagnostics), isNot(contains(payload)));
  });

  test('retry URLs omit slash-split Base64 after a credential path marker', () {
    final payload = base64Encode(
      Uint8List.fromList(List<int>.filled(150, 255)),
    );
    expect(payload, hasLength(200));
    final url = 'https://media.example.test/api_key/$payload';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'wav',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final serializedReference = reference.toMap();
    final configSnapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
    ).toMap();
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': url,
    });

    expect(jsonEncode(serializedReference), isNot(contains(payload)));
    expect(serializedReference['requiresSourceReselection'], isTrue);
    expect(jsonEncode(configSnapshot), isNot(contains(payload)));
    expect(jsonEncode(diagnostics), isNot(contains(payload)));
  });

  test('malformed retry URLs never serialize credential values', () {
    const secret = 'opaque-malformed-url-secret';
    const malformedUrl = 'https://[not-an-ipv6-address]?api_key=$secret';
    expect(Uri.tryParse(malformedUrl), isNull);
    final reference = AsrAudioReference(
      id: List.filled(32, 'c').join(),
      name: malformedUrl,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: malformedUrl,
    );
    final referenceMap = reference.toMap();
    final restoredReference = AsrAudioReference.fromMap({
      ...referenceMap,
      'name': malformedUrl,
      'url': malformedUrl,
    });
    final configSnapshot = AsrRetryConfigSnapshot.fromConfig(
      const AsrConfig(
        apiKey: 'live-api-key',
        host: malformedUrl,
        model: 'whisper-small',
      ),
    );
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': malformedUrl,
    });

    expect(jsonEncode(referenceMap), isNot(contains(secret)));
    expect(referenceMap['requiresSourceReselection'], isTrue);
    expect(jsonEncode(restoredReference.toMap()), isNot(contains(secret)));
    expect(jsonEncode(configSnapshot.toMap()), isNot(contains(secret)));
    expect(jsonEncode(diagnostics), isNot(contains(secret)));
  });

  test('reference callback runs only after audio bytes are verified', () async {
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    final bytes = Uint8List.fromList([1, 2, 3]);
    AsrAudioReference? callbackReference;
    Uint8List? callbackBytes;

    final reference = await store.save(
      bytes,
      name: 'capture.wav',
      format: 'wav',
      onReferenceCreated: (created) {
        callbackReference = created;
        callbackBytes =
            adapter.files['background/asr_retry/${created.id}.audio'];
      },
    );

    expect(callbackReference, reference);
    expect(callbackBytes, bytes);
    await store.releaseProtection(reference);
  });

  test('save waits for asynchronous reference persistence', () async {
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    final callbackStarted = Completer<void>();
    final finishCallback = Completer<void>();
    var saveFinished = false;

    final saveFuture = store.save(
      Uint8List.fromList([1, 2, 3]),
      name: 'capture.wav',
      format: 'wav',
      onReferenceCreated: (_) async {
        callbackStarted.complete();
        await finishCallback.future;
      },
    ).then((reference) {
      saveFinished = true;
      return reference;
    });
    await callbackStarted.future;
    await Future<void>.delayed(Duration.zero);
    final completedBeforeCallback = saveFinished;
    finishCallback.complete();
    final reference = await saveFuture;

    expect(completedBeforeCallback, isFalse);
    await store.releaseProtection(reference);
  });

  test(
    'asynchronous reference persistence failure removes retry audio',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final callbackStarted = Completer<void>();
      final failCallback = Completer<void>();

      Future<void> publishReference(AsrAudioReference _) async {
        callbackStarted.complete();
        await failCallback.future;
        throw StateError('retry state failed');
      }

      Future<void> onReferenceCreated(AsrAudioReference reference) {
        final publication = publishReference(reference);
        unawaited(publication.catchError((Object _) {}));
        return publication;
      }

      final saveFuture = store.save(
        Uint8List.fromList([1, 2, 3]),
        name: 'capture.wav',
        format: 'wav',
        onReferenceCreated: onReferenceCreated,
      );
      await callbackStarted.future;
      failCallback.complete();

      await expectLater(saveFuture, throwsStateError);
      expect(adapter.files, isEmpty);
    },
  );

  test('failed audio writes do not publish a retry reference', () async {
    final adapter = _MemoryRetryAdapter()..writeFailure = StateError('disk');
    final store = AsrRetryAudioStore(adapter: adapter);
    var callbackCalled = false;

    await expectLater(
      store.save(
        Uint8List.fromList([1, 2, 3]),
        name: 'capture.wav',
        format: 'wav',
        onReferenceCreated: (_) => callbackCalled = true,
      ),
      throwsStateError,
    );

    expect(callbackCalled, isFalse);
    expect(adapter.files, isEmpty);
  });

  test(
    'deletion waits for an in-flight ensureStored audio write',
    () async {
      final adapter = _GatedEnsureStoredRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final reference = await store.save(
        bytes,
        name: 'restore-race.wav',
        format: 'wav',
      );
      await store.releaseProtection(reference);
      adapter.files.remove('background/asr_retry/${reference.id}.audio');
      adapter.gateAudioWrites = true;

      final restoring = store.ensureStored(reference, bytes);
      await adapter.audioWriteEntered.future;
      final deletionCompleted = Completer<void>();
      final deleting = store.delete(reference).whenComplete(() {
        deletionCompleted.complete();
      });
      await Future<void>.delayed(Duration.zero);
      expect(deletionCompleted.isCompleted, isFalse);
      adapter.releaseAudioWrite.complete();
      await Future.wait([restoring, deleting]);

      expect(
        adapter.files,
        isEmpty,
        reason: 'a completed deletion must not be followed by an orphaned blob',
      );
    },
  );

  test('failed reference publication removes stored retry audio', () async {
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);

    await expectLater(
      store.save(
        Uint8List.fromList([1, 2, 3]),
        name: 'capture.wav',
        format: 'wav',
        onReferenceCreated: (_) => throw StateError('retry state failed'),
      ),
      throwsStateError,
    );

    expect(adapter.files, isEmpty);
  });

  test(
    'save protects retry audio even when no reference callback is used',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final reference = await store.save(
        bytes,
        name: 'capture.wav',
        format: 'wav',
      );

      await store.prune(() => <String>{});

      expect(await store.load(reference), bytes);
      await store.releaseProtection(reference);
      await store.prune(() => <String>{});
      expect(adapter.files, isEmpty);
    },
  );

  test(
    'cleanup removes only unreferenced files in its own namespace',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final retained = await _saveAndRelease(
        store,
        Uint8List.fromList([1]),
        name: 'retained.wav',
        format: 'wav',
      );
      await _saveAndRelease(
        store,
        Uint8List.fromList([2]),
        name: 'orphan.wav',
        format: 'wav',
      );
      await adapter.write(
        'background/user_audio/shared.wav',
        Uint8List.fromList([3]),
      );

      await store.prune(() => {retained.id});

      expect(adapter.files.keys, hasLength(2));
      expect(
        adapter.files.keys.singleWhere((key) => key.contains(retained.id)),
        startsWith('background/asr_retry/'),
      );
      expect(adapter.files['background/user_audio/shared.wav'], [3]);
    },
  );

  test('prune removes orphaned atomic-write temp entries', () async {
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    // The native adapter surfaces only stale AtomicFile temp directories as
    // exact-name cleanup keys.
    adapter.files[
            'background/asr_retry/.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.audio.tmp-crashed'] =
        Uint8List.fromList([1]);
    adapter.files[
            'background/asr_retry/.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.chunks.tmp-crashed'] =
        Uint8List.fromList([2]);
    const unrelated = 'background/asr_retry/.not-an-id.audio.tmp-crashed';
    adapter.files[unrelated] = Uint8List.fromList([3]);

    await store.prune(() => const {});

    expect(adapter.files, hasLength(1));
    expect(adapter.files.keys.single, unrelated);
  });

  test('prune preserves a protected active audio atomic-write temp', () async {
    final adapter = _GatedAtomicRetryAdapter('.audio');
    final store = AsrRetryAudioStore(adapter: adapter);
    final saving = store.save(
      Uint8List.fromList([1, 2, 3]),
      name: 'active-write.wav',
      format: 'wav',
    );
    await adapter.writeEntered.future;

    await store.prune(() => const <String>{});
    final tempPreserved = adapter.files.containsKey(adapter.temporaryKey);
    adapter.releaseWrite.complete();
    Object? saveError;
    AsrAudioReference? reference;
    try {
      reference = await saving;
    } catch (error) {
      saveError = error;
    }
    if (reference != null) await store.releaseProtection(reference);

    expect(tempPreserved, isTrue);
    expect(saveError, isNull);
  });

  test('prune preserves an active checkpoint atomic-write temp', () async {
    final adapter = _GatedAtomicRetryAdapter('.chunks');
    final store = AsrRetryAudioStore(adapter: adapter);
    final reference = await store.save(
      Uint8List.fromList([1, 2, 3]),
      name: 'active-checkpoint.wav',
      format: 'wav',
    );
    await store.releaseProtection(reference);
    final checkpointWrite = store.writeChunkCheckpoint(
      reference,
      const [
        AsrChunkResult(
          index: 0,
          startSeconds: 0,
          endSeconds: 1,
          totalChunks: 1,
          status: AsrChunkStatus.succeeded,
          text: 'recognized text',
        ),
      ],
      modelReference: const {'configId': 'provider', 'modelId': 'model'},
    );
    await adapter.writeEntered.future;

    await store.prune(() => {reference.id});
    final tempPreserved = adapter.files.containsKey(adapter.temporaryKey);
    adapter.releaseWrite.complete();
    Object? writeError;
    try {
      await checkpointWrite;
    } catch (error) {
      writeError = error;
    }

    expect(tempPreserved, isTrue);
    expect(writeError, isNull);
    expect(
      await store.readChunkCheckpoint(
        reference,
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
      ),
      isNotNull,
    );
    await store.delete(reference);
  });

  test(
    'prune cannot delete a reference protected after its snapshot',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final reference = await _saveAndRelease(
        store,
        bytes,
        name: 'overlap.wav',
        format: 'wav',
      );
      adapter.deleteEntered = Completer<void>();
      adapter.releaseDelete = Completer<void>();

      final pruning = store.prune(() => <String>{});
      await adapter.deleteEntered!.future;
      final saving = store
          .protectUntilReferenced(reference)
          .then((_) => store.ensureStored(reference, bytes));
      adapter.releaseDelete!.complete();
      await pruning;
      await saving;
      final loaded = await store.load(reference);
      await store.releaseProtection(reference);

      expect(loaded, bytes);
    },
  );

  test(
    'prune rechecks references published during key enumeration',
    () async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final reference = await _saveAndRelease(
        store,
        bytes,
        name: 'concurrent-save.wav',
        format: 'wav',
      );
      final liveReferences = <String>{};
      adapter.keysEntered = Completer<void>();
      adapter.releaseKeys = Completer<void>();

      final pruning = store.prune(() => liveReferences);
      await adapter.keysEntered!.future;
      await store.protectUntilReferenced(reference);
      await store.ensureStored(reference, bytes);
      liveReferences.add(reference.id);
      await store.releaseProtection(reference);
      adapter.releaseKeys!.complete();
      await pruning;

      expect(await store.load(reference), bytes);
    },
  );

  test('retry config snapshots omit credentials and preserve ASR options', () {
    const apiKey = 'sk-secret-test-key';
    final config = AsrConfig(
      apiKey: apiKey,
      host: 'https://user:$apiKey@asr.example.test/transcribe?api_key=$apiKey',
      model: 'whisper-small',
      typeConfig: {
        'enableTemperature': true,
        'temperature': 0.2,
        'apiKey': apiKey,
      },
      customParams: [
        CustomParam(paramName: 'language', defaultValue: 'zh', type: 'string'),
        CustomParam(paramName: 'api_token', defaultValue: apiKey),
        CustomParam(paramName: 'metadata', defaultValue: 'Bearer $apiKey'),
      ],
      chunking: 'fixedSize',
      fallbackMethod: 'generic',
    );

    final encoded = jsonEncode(
      AsrRetryConfigSnapshot.fromConfig(config).toMap(),
    );

    expect(encoded, isNot(contains(apiKey)));
    expect(encoded, contains('whisper-small'));
    expect(encoded, contains('fixedSize'));
    expect(encoded, contains('zh'));
    expect(encoded, isNot(contains('api_token')));
    expect(encoded, isNot(contains('metadata')));
  });

  test('retry config snapshots omit credentials with whitespace in names', () {
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(
        apiKey: 'live-api-key',
        host:
            'https://asr.example.test/transcribe?API%20Key=query-secret-value',
        model: 'whisper-small',
        typeConfig: {'API Key': 'config-secret-value', 'mode': 'fast'},
      ),
    );

    final encoded = jsonEncode(snapshot.toMap());

    expect(encoded, isNot(contains('query-secret-value')));
    expect(encoded, isNot(contains('config-secret-value')));
    expect(encoded, contains('mode'));
    expect(encoded, contains('fast'));
  });

  test('retry snapshots redact encoded credential field names', () {
    const opaqueSecret = 'opaque-encoded-field-secret';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(
        apiKey: 'live-api-key',
        host: 'https://asr.example.test/transcribe',
        model: 'whisper-small',
        typeConfig: {'api%5Fkey': opaqueSecret, 'mode': 'fast'},
      ),
    );

    final encoded = jsonEncode(snapshot.toMap());

    expect(encoded, isNot(contains('api_key')));
    expect(encoded, isNot(contains(opaqueSecret)));
    expect(snapshot.typeConfig, {'mode': 'fast'});
  });

  test('retry snapshots strip credentials after whitespace path markers', () {
    const secret = 'opaque-path-secret';
    const host = 'https://asr.example.test/transcribe/API%20Key/$secret';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      const AsrConfig(
        apiKey: 'live-api-key',
        host: host,
        model: 'whisper-small',
      ),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: host,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: host,
    );

    final encoded = jsonEncode({
      'snapshot': snapshot.toMap(),
      'reference': reference.toMap(),
      'diagnostics': AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'url': host,
      }),
    });

    expect(encoded, isNot(contains(secret)));
    expect(
      AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(host),
      isNot(contains(secret)),
    );
  });

  test('retry config snapshots preserve ordinary author custom parameters', () {
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(
        apiKey: 'live-api-key',
        host: 'https://asr.example.test/transcribe',
        model: 'whisper-small',
        customParams: [
          CustomParam(
            paramName: 'author',
            defaultValue: 'Ada Lovelace',
            type: 'string',
          ),
        ],
      ),
    );
    final retryConfig = snapshot.toConfig(
      apiKey: 'current-api-key',
      liveHost: 'https://asr.example.test/transcribe',
      liveModel: 'whisper-small',
    );

    expect(jsonEncode(snapshot.toMap()), contains('author'));
    expect(retryConfig.customParams.map((param) => param.paramName), [
      'author',
    ]);
    expect(retryConfig.customParams.single.defaultValue, 'Ada Lovelace');
  });

  test('retry snapshots omit cookie and session credential material', () {
    const cookieValue = 'JSESSIONID=opaque-cookie-secret';
    const sessionValue = 'opaque-session-secret';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(
        apiKey: 'live-api-key',
        host: 'https://asr.example.test/transcribe',
        model: 'whisper-small',
        customParams: [
          CustomParam(paramName: 'Cookie', defaultValue: cookieValue),
          CustomParam(paramName: 'session', defaultValue: sessionValue),
          CustomParam(paramName: 'language', defaultValue: 'zh'),
        ],
      ),
    );
    final serializedSnapshot = jsonEncode(snapshot.toMap());
    final sanitizedDiagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'headers': {'Cookie': cookieValue},
      'session': sessionValue,
      'message': 'request failed with Cookie: $cookieValue',
    });
    final diagnostics = jsonEncode(sanitizedDiagnostics);

    expect(serializedSnapshot, isNot(contains('Cookie')));
    expect(serializedSnapshot, isNot(contains('session')));
    expect(serializedSnapshot, isNot(contains(cookieValue)));
    expect(serializedSnapshot, isNot(contains(sessionValue)));
    expect(serializedSnapshot, contains('language'));
    expect((sanitizedDiagnostics['headers'] as Map), isNot(contains('Cookie')));
    expect(sanitizedDiagnostics, isNot(contains('session')));
    expect(diagnostics, isNot(contains(cookieValue)));
    expect(diagnostics, isNot(contains(sessionValue)));
  });

  test(
    'retry config snapshots remove the configured key from ordinary fields',
    () {
      const apiKey = 'c8r-f2m-v7q-k4n-p9x-3bh';
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(
          apiKey: apiKey,
          host: 'https://asr.example.test/transcribe/$apiKey',
          model: 'whisper-small',
          typeConfig: {'endpointAlias': apiKey, 'mode': 'fast'},
          customParams: [
            CustomParam(paramName: 'tenantLabel', defaultValue: apiKey),
          ],
        ),
      );

      final encoded = jsonEncode(snapshot.toMap());
      final retryConfig = snapshot.toConfig(
        apiKey: apiKey,
        liveHost: 'https://asr.example.test/transcribe/$apiKey',
        liveModel: 'whisper-small',
      );

      expect(encoded, isNot(contains(apiKey)));
      expect(encoded, contains('mode'));
      expect(encoded, contains('fast'));
      expect(retryConfig.host, 'https://asr.example.test/transcribe/$apiKey');
      expect(retryConfig.apiKey, apiKey);
      expect(retryConfig.typeConfig, {'mode': 'fast'});
      expect(retryConfig.customParams, isEmpty);
    },
  );

  test('retry config snapshots remove the configured key from ASR options', () {
    const apiKey = 'opaque-asr-option-secret';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(
        apiKey: apiKey,
        host: 'https://asr.example.test/transcribe',
        preprocessing: apiKey,
        chunking: apiKey,
        compression: apiKey,
        fallbackMethod: apiKey,
      ),
    );

    final encoded = jsonEncode(snapshot.toMap());

    expect(encoded, isNot(contains(apiKey)));
    expect(snapshot.preprocessing, isNot(contains(apiKey)));
    expect(snapshot.chunking, isNot(contains(apiKey)));
    expect(snapshot.compression, isNot(contains(apiKey)));
    expect(snapshot.fallbackMethod, isNot(contains(apiKey)));
  });

  test('retry audio format omits a matching configured API key', () {
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: 'capture',
      format: 'wav',
      byteLength: 1,
      sha256: List.filled(64, '0').join(),
    );
    final referenceMap = reference.toMap(configuredApiKey: 'wav');

    expect(referenceMap['format'], isNot('wav'));
    expect(referenceMap['requiresSourceReselection'], isTrue);
    final restored = AsrAudioReference.fromMap(
      Map<String, dynamic>.from(referenceMap),
      configuredApiKey: 'wav',
    );
    expect(restored.requiresSourceReselection, isTrue);
  });

  test('retry snapshots omit a configured key matching the upload method', () {
    final uploadMethodSnapshot = AsrRetryConfigSnapshot.fromConfig(
      const AsrConfig(
        apiKey: 'multipart',
        host: 'https://asr.example.test/transcribe',
        model: 'whisper-small',
      ),
    );

    final encoded = jsonEncode(uploadMethodSnapshot.toMap());

    expect(encoded, isNot(contains('multipart')));
    expect(uploadMethodSnapshot.uploadMethod, isEmpty);
    expect(
      () => uploadMethodSnapshot.toConfig(
        apiKey: 'multipart',
        liveHost: 'https://asr.example.test/transcribe',
        liveModel: 'whisper-small',
      ),
      throwsStateError,
    );
  });

  test('retry snapshots omit a configured key matching default options', () {
    final fallbackSnapshot = AsrRetryConfigSnapshot.fromConfig(
      const AsrConfig(
        apiKey: 'none',
        host: 'https://asr.example.test/transcribe',
        model: 'whisper-small',
        preprocessing: 'unsupported',
      ),
    );

    final serialized = fallbackSnapshot.toMap();

    for (final field in [
      'preprocessing',
      'chunking',
      'compression',
      'fallbackMethod',
    ]) {
      expect(serialized[field], isNot('none'));
    }
    final restored = AsrRetryConfigSnapshot.fromMap(serialized).toConfig(
      apiKey: 'none',
      liveHost: 'https://asr.example.test/transcribe',
      liveModel: 'whisper-small',
    );
    expect(restored.preprocessing, 'none');
    expect(restored.chunking, 'none');
    expect(restored.compression, 'none');
    expect(restored.fallbackMethod, 'none');
  });

  test('retry config snapshots remove percent-encoded copies of the key', () {
    const apiKey = 'c8r-f2m-v7q-k4n-p9x-3bh/4jr';
    final encodedApiKeys = [
      Uri.encodeComponent(apiKey),
      Uri.encodeComponent(Uri.encodeComponent(apiKey)),
    ];

    for (final encodedApiKey in encodedApiKeys) {
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(
          apiKey: apiKey,
          host: 'https://asr.example.test/transcribe/$encodedApiKey',
          model: 'whisper-small',
          typeConfig: {'endpointAlias': encodedApiKey, 'mode': 'fast'},
        ),
      );

      final encoded = jsonEncode(snapshot.toMap());

      expect(encoded, isNot(contains(apiKey)));
      expect(encoded, isNot(contains(encodedApiKey)));
      expect(encoded, contains('mode'));
      expect(encoded, contains('fast'));
    }
  });

  test(
    'malformed escapes cannot hide encoded configured keys in snapshots',
    () {
      const apiKey = 'opaque/key credential';
      final encodedApiKey = Uri.encodeComponent(apiKey);
      final value =
          'https://asr.example.test/endpoint/opaque/key%20credential/%ZZ';
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(
          apiKey: apiKey,
          host: 'https://asr.example.test/transcribe',
          model: 'whisper-small',
          typeConfig: {'endpointAlias': value},
        ),
      );

      final encoded = jsonEncode(snapshot.toMap());

      expect(encoded, isNot(contains(encodedApiKey)));
      expect(encoded, isNot(contains(apiKey)));
      expect(encoded, isNot(contains('opaque/key%20credential')));
    },
  );

  test('retry snapshot serialization sanitizes public fields again', () {
    const directLanguageSecret = 'opaque-language-snapshot-secret';
    const directConfigSecret = 'opaque-type-config-snapshot-secret';
    const mutatedConfigSecret = 'opaque-mutated-type-config-secret';
    const directUploadMethodSecret = 'opaque-upload-method-snapshot-secret';
    final snapshot = AsrRetryConfigSnapshot(
      host: 'https://asr.example.test/transcribe',
      model: 'whisper-small',
      language: 'api_key=$directLanguageSecret',
      typeConfig: {'apiKey': directConfigSecret, 'mode': 'fast'},
      customParams: [],
      uploadMethod: directUploadMethodSecret,
      maxFileSizeBytes: 1024,
      preprocessing: 'none',
      chunking: 'none',
      compression: 'none',
      fallbackMethod: 'none',
    );
    snapshot.typeConfig['accessToken'] = mutatedConfigSecret;

    final serialized =
        jsonDecode(jsonEncode(snapshot.toMap())) as Map<String, dynamic>;
    final retryConfig = snapshot.toConfig(
      apiKey: 'current-api-key',
      liveHost: 'https://asr.example.test/transcribe',
      liveModel: 'whisper-small',
    );

    expect(jsonEncode(serialized), isNot(contains(directLanguageSecret)));
    expect(jsonEncode(serialized), isNot(contains(directConfigSecret)));
    expect(jsonEncode(serialized), isNot(contains(mutatedConfigSecret)));
    expect(jsonEncode(serialized), isNot(contains(directUploadMethodSecret)));
    expect(serialized['uploadMethod'], 'multipart');
    expect(serialized['typeConfig'], {'mode': 'fast'});
    expect(retryConfig.typeConfig, {'mode': 'fast'});
    expect(
      retryConfig.language?.contains(directLanguageSecret) ?? false,
      isFalse,
    );
  });

  test(
    'retry snapshots redact credential-shaped models and use the live model',
    () {
      const privateModel = 'sk-abcdefghijklmnop';
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        const AsrConfig(
          apiKey: 'live-api-key',
          host: 'https://asr.example.test/transcribe',
          model: privateModel,
        ),
      );

      final encoded = jsonEncode(snapshot.toMap());
      final restored = AsrRetryConfigSnapshot.fromMap(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      final config = restored.toConfig(
        apiKey: 'current-key',
        liveHost: 'https://asr.example.test/transcribe',
        liveModel: 'whisper-safe',
      );

      expect(encoded, isNot(contains(privateModel)));
      expect(restored.model, isEmpty);
      expect(config.model, 'whisper-safe');
    },
  );

  test('retry snapshots with a missing model use the resolved live model', () {
    final restored = AsrRetryConfigSnapshot.fromMap({
      'host': 'https://asr.example.test/transcribe',
      'uploadMethod': 'multipart',
    });

    final config = restored.toConfig(
      apiKey: 'current-key',
      liveHost: 'https://asr.example.test/transcribe',
      liveModel: 'whisper-large',
    );

    expect(restored.model, isEmpty);
    expect(config.model, 'whisper-large');
  });

  test('restored retry snapshots drop credential-named custom parameters', () {
    const opaqueSecret = 'opaque-custom-param-secret';
    final snapshot = AsrRetryConfigSnapshot.fromMap({
      'host': 'https://asr.example.test/transcribe',
      'model': 'whisper-small',
      'customParams': [
        {
          'paramName': 'api_token',
          'defaultValue': opaqueSecret,
          'type': 'string',
        },
        {
          'paramName': 'apiToken',
          'defaultValue': 'another-opaque-secret',
          'type': 'string',
        },
        {'paramName': 'language', 'defaultValue': 'zh', 'type': 'string'},
      ],
    });
    final encoded = jsonEncode(snapshot.toMap());
    final config = snapshot.toConfig(
      apiKey: 'current-key',
      liveHost: 'https://asr.example.test/transcribe',
      liveModel: 'whisper-small',
    );

    expect(encoded, isNot(contains(opaqueSecret)));
    expect(encoded, isNot(contains('api_token')));
    expect(encoded, isNot(contains('another-opaque-secret')));
    expect(encoded, isNot(contains('apiToken')));
    expect(config.customParams.map((param) => param.paramName), ['language']);
  });

  test('restored retry snapshots discard unsupported ASR option values', () {
    const apiKey = 'c8r-f2m-v7q-k4n-p9x-3bh';
    final restored = AsrRetryConfigSnapshot.fromMap({
      'host': 'https://asr.example.test/transcribe',
      'model': 'whisper-small',
      'preprocessing': apiKey,
      'chunking': apiKey,
      'compression': apiKey,
      'fallbackMethod': apiKey,
    });
    final encoded = jsonEncode(restored.toMap());
    final validOptions = AsrRetryConfigSnapshot.fromMap({
      'host': 'https://asr.example.test/transcribe',
      'model': 'whisper-small',
      'preprocessing': 'resampleMono',
      'chunking': 'fixedSize',
      'compression': 'flac',
      'fallbackMethod': 'generic',
    }).toMap();

    expect(encoded, isNot(contains(apiKey)));
    expect(restored.preprocessing, 'none');
    expect(restored.chunking, 'none');
    expect(restored.compression, 'none');
    expect(restored.fallbackMethod, 'none');
    expect(validOptions['preprocessing'], 'resampleMono');
    expect(validOptions['chunking'], 'fixedSize');
    expect(validOptions['compression'], 'flac');
    expect(validOptions['fallbackMethod'], 'generic');
  });

  test(
    'versioned retry sanitation redacts a key used by an option fallback',
    () {
      const configuredApiKey = 'none';
      final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData({
        'version': 2,
        'audioReference': {
          'version': AsrAudioReference.currentVersion,
          'id': 'abababababababababababababababab',
          'name': 'capture.wav',
          'format': 'wav',
          'byteLength': 4,
          'sha256': List.filled(64, 'c').join(),
        },
        'configSnapshot': {
          'host': 'https://asr.example.test/transcribe',
          'model': 'whisper-small',
          'uploadMethod': 'multipart',
          'preprocessing': 'unsupported-option',
          'chunking': 'unsupported-option',
          'compression': 'unsupported-option',
          'fallbackMethod': 'unsupported-option',
        },
      }, configuredApiKey: configuredApiKey);

      expect(sanitized, isNotNull);
      final snapshot = sanitized!['configSnapshot'] as Map<String, dynamic>;
      expect(
        snapshot['preprocessing'],
        isNot(configuredApiKey),
        reason: 'the fallback option must not serialize the configured key',
      );
    },
  );

  test('restored retry snapshots replace negative audio size limits', () {
    final restored = AsrRetryConfigSnapshot.fromMap({
      'host': 'https://asr.example.test/transcribe',
      'model': 'whisper-small',
      'uploadMethod': 'multipart',
      'maxFileSizeBytes': -1,
    });

    expect(restored.maxFileSizeBytes, AsrConfig.defaultMaxAudioFileSizeBytes);
    expect(
      restored.toMap()['maxFileSizeBytes'],
      AsrConfig.defaultMaxAudioFileSizeBytes,
    );
    expect(
      restored
          .toConfig(
            apiKey: 'current-key',
            liveHost: 'https://asr.example.test/transcribe',
            liveModel: 'whisper-small',
          )
          .maxFileSizeBytes,
      AsrConfig.defaultMaxAudioFileSizeBytes,
    );
  });

  test('retry snapshots strip opaque key, auth, and signature query values',
      () {
    const host =
        'https://asr.example.test/transcribe?key=opaque-key&auth=opaque-auth&sig=opaque-sig&signature=opaque-signature&appKey=opaque-app-key&appkey=opaque-lowercase-app-key&app-key=opaque-hyphen-app-key&app_key=opaque-underscore-app-key&app.key=opaque-dot-app-key&mode=verbose';
    final config = AsrConfig(
      apiKey: 'live-api-key',
      host: host,
      model: 'whisper-small',
      typeConfig: {
        'appKey': 'opaque-app-key',
        'appkey': 'opaque-lowercase-config-app-key',
      },
      customParams: [
        CustomParam(paramName: 'appKey', defaultValue: 'opaque-app-key'),
        CustomParam(
          paramName: 'appkey',
          defaultValue: 'opaque-lowercase-param-app-key',
        ),
      ],
    );

    final snapshot = jsonEncode(
      AsrRetryConfigSnapshot.fromConfig(config).toMap(),
    );
    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({'url': host}),
    );
    const audioUrl =
        'https://media.example.test/audio?appkey=opaque-audio-app-key';
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: audioUrl,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: audioUrl,
    );
    final serializedReference = jsonEncode(reference.toMap());

    for (final secret in [
      'opaque-key',
      'opaque-auth',
      'opaque-sig',
      'opaque-signature',
      'opaque-app-key',
      'opaque-lowercase-app-key',
      'opaque-hyphen-app-key',
      'opaque-underscore-app-key',
      'opaque-dot-app-key',
      'opaque-lowercase-config-app-key',
      'opaque-lowercase-param-app-key',
      'opaque-audio-app-key',
    ]) {
      expect(snapshot, isNot(contains(secret)));
      expect(diagnostics, isNot(contains(secret)));
      expect(serializedReference, isNot(contains(secret)));
    }
    expect(reference.toMap()['requiresSourceReselection'], isTrue);
    expect(AsrRetryConfigSnapshot.urlContainsCredentials(audioUrl), isTrue);
    expect(snapshot, contains('mode=verbose'));
    expect(diagnostics, contains('mode=verbose'));
  });

  test('retry snapshots strip deeply encoded configured API keys', () {
    const apiKey = 'opaque:Z7q-90817';
    var encodedApiKey = apiKey;
    for (var depth = 0; depth < 6; depth++) {
      encodedApiKey = Uri.encodeComponent(encodedApiKey);
    }
    final host =
        'https://asr.example.test/transcribe?mode=fast&state=$encodedApiKey';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: apiKey, host: host, model: 'whisper-small'),
    );
    final encodedSnapshot = jsonEncode(snapshot.toMap());

    expect(encodedSnapshot, isNot(contains(encodedApiKey)));
    expect(encodedSnapshot, isNot(contains('opaque')));
    expect(snapshot.host, contains('mode=fast'));
  });

  test('retry snapshots strip noncanonical percent-encoded configured keys',
      () {
    const apiKey = 'ordinarySecret98765';
    const host =
        'https://asr.example.test/transcribe?mode=fast&state=%6FrdinarySecret98765';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: apiKey, host: host, model: 'whisper-small'),
    );

    expect(snapshot.host, 'https://asr.example.test/transcribe?mode=fast');
    expect(jsonEncode(snapshot.toMap()), isNot(contains(apiKey)));
  });

  test(
    'retry data redact noncanonical percent-encoded keys across fields',
    () async {
      const apiKey = 'ordinarySecret98765';
      const encodedKey = '%6FrdinarySecret98765';
      const host = 'https://asr.example.test/transcribe/$encodedKey';
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(apiKey: apiKey, host: host, model: 'whisper-small'),
      );
      final store = AsrRetryAudioStore(adapter: _MemoryRetryAdapter());
      final reference = await store.save(
        Uint8List.fromList([1, 2, 3]),
        name: 'capture-$encodedKey.wav',
        format: 'wav',
        configuredApiKey: apiKey,
      );
      await store.releaseProtection(reference);
      final diagnostic = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
        'provider failed at $encodedKey',
        configuredApiKey: apiKey,
      );
      final serialized = jsonEncode({
        'snapshot': snapshot.toMap(),
        'reference': reference.toMap(),
        'diagnostic': diagnostic,
      });

      expect(serialized, isNot(contains(encodedKey)));
      expect(serialized, isNot(contains(apiKey)));
    },
  );

  test('retry URLs strip semicolon-delimited credential query values', () {
    const secret = 'opaque-secret';
    final hosts = [
      'https://asr.example.test/transcribe?mode=verbose;sig=$secret',
      'https://asr.example.test/transcribe?mode=verbose%3Bsig%3D$secret',
      'https://asr.example.test/transcribe?mode;sig=$secret',
      'https://asr.example.test/transcribe?mode%3Bsig=$secret',
    ];

    for (final host in hosts) {
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(apiKey: 'live-key', host: host, model: 'whisper-small'),
      );
      final reference = AsrAudioReference(
        id: List.filled(32, 'a').join(),
        name: host,
        format: 'url',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: host,
      );
      final diagnosticUrl = AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(host);
      final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'url': host,
      });
      final serialized = jsonEncode({
        'snapshot': snapshot.toMap(),
        'reference': reference.toMap(),
        'diagnostics': diagnostics,
      });

      expect(serialized, isNot(contains(secret)));
      expect(diagnosticUrl, isNot(contains(secret)));
      expect(reference.toMap()['requiresSourceReselection'], isTrue);
      expect(AsrRetryConfigSnapshot.urlContainsCredentials(host), isTrue);
    }
  });

  test(
    'retry URLs strip credentials with encoded query assignment delimiters',
    () {
      const secret = 'opaque-encoded-query-value-90817';
      final hosts = [
        'https://asr.example.test/transcribe?key%3D$secret&mode=verbose',
        'https://asr.example.test/transcribe?key%253D$secret&mode=verbose',
      ];

      for (final host in hosts) {
        final snapshot = AsrRetryConfigSnapshot.fromConfig(
          AsrConfig(apiKey: 'live-key', host: host, model: 'whisper-small'),
        );
        final reference = AsrAudioReference(
          id: List.filled(32, 'a').join(),
          name: host,
          format: 'url',
          byteLength: 0,
          sha256: List.filled(64, '0').join(),
          url: host,
        );
        final diagnosticUrl = AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(
          host,
        );
        final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
          'url': host,
        });
        final serialized = jsonEncode({
          'snapshot': snapshot.toMap(),
          'reference': reference.toMap(),
          'diagnostics': diagnostics,
        });

        expect(serialized, isNot(contains(secret)));
        expect(diagnosticUrl, isNot(contains(secret)));
        expect(reference.toMap()['requiresSourceReselection'], isTrue);
        expect(AsrRetryConfigSnapshot.urlContainsCredentials(host), isTrue);
        expect(diagnosticUrl, contains('mode=verbose'));
      }
    },
  );

  test('retry URLs strip credentials behind multiply encoded query names', () {
    const secret = 'opaque-double-encoded-name-value-90817';
    const url =
        'https://asr.example.test/transcribe?%2561uth=$secret&mode=verbose';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: url, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': url,
    });
    final sanitizedDiagnosticUrl = AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(
      url,
    );
    final serialized = jsonEncode({
      'snapshot': snapshot.toMap(),
      'reference': reference.toMap(),
      'diagnostics': diagnostics,
    });

    expect(serialized, isNot(contains(secret)));
    expect(sanitizedDiagnosticUrl, isNot(contains(secret)));
    expect(
      sanitizedDiagnosticUrl,
      'https://asr.example.test/transcribe?mode=verbose',
    );
    expect(sanitizedDiagnosticUrl, contains('mode=verbose'));
    expect(reference.toMap()['requiresSourceReselection'], isTrue);
    expect(AsrRetryConfigSnapshot.urlContainsCredentials(url), isTrue);
  });

  test('retry snapshots strip credentials embedded in endpoint paths', () {
    const host =
        'https://asr.example.test/transcribe/api_key/opaque-path-secret';
    final config = AsrConfig(
      apiKey: 'live-api-key',
      host: host,
      model: 'whisper-small',
    );

    final snapshot = jsonEncode(
      AsrRetryConfigSnapshot.fromConfig(config).toMap(),
    );
    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({'url': host}),
    );

    expect(snapshot, isNot(contains('opaque-path-secret')));
    expect(diagnostics, isNot(contains('opaque-path-secret')));
    expect(snapshot, contains('/transcribe/api_key'));
    expect(diagnostics, contains('/transcribe/api_key'));
  });

  test('retry snapshots strip the full credential path suffix', () {
    const credentialPrefix = 'opaque-prefix-segment';
    const credentialSuffix = 'opaque-secret.tail';
    const host =
        'https://asr.example.test/transcribe/api_key/$credentialPrefix/$credentialSuffix';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      const AsrConfig(apiKey: 'live-key', host: host, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: host,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: host,
    );
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': host,
    });
    final serialized = jsonEncode({
      'snapshot': snapshot.toMap(),
      'reference': reference.toMap(),
      'diagnostics': diagnostics,
    });

    expect(serialized, isNot(contains(credentialPrefix)));
    expect(serialized, isNot(contains(credentialSuffix)));
    expect(reference.toMap()['requiresSourceReselection'], isTrue);
    expect(AsrRetryConfigSnapshot.urlContainsCredentials(host), isTrue);
  });

  test('diagnostics strip the full suffix from relative credential paths', () {
    const credentialPrefix = 'opaque-relative-prefix';
    const credentialSuffix = 'opaque-relative-secret.tail';
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'error':
          'request failed at /transcribe/api_key/$credentialPrefix/$credentialSuffix',
    });
    final encoded = jsonEncode(diagnostics);

    expect(encoded, isNot(contains(credentialPrefix)));
    expect(encoded, isNot(contains(credentialSuffix)));
  });

  test('retry paths redact key credentials but preserve endpoint routes', () {
    for (final marker in ['key', 'appKey']) {
      final secret = 'opaque-$marker-path-secret';
      final host = 'https://asr.example.test/v1/$marker/$secret';
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(apiKey: 'live-api-key', host: host, model: 'whisper-small'),
      );
      final reference = AsrAudioReference(
        id: List.filled(32, 'b').join(),
        name: host,
        format: 'url',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: host,
      );
      final diagnostics = jsonEncode(
        AsrRetryConfigSnapshot.sanitizeDiagnosticMap({'url': host}),
      );

      expect(snapshot.host, isNot(contains(secret)), reason: marker);
      expect(
        jsonEncode(snapshot.toMap()),
        isNot(contains(secret)),
        reason: marker,
      );
      expect(
        jsonEncode(reference.toMap()),
        isNot(contains(secret)),
        reason: marker,
      );
      expect(
        reference.toMap()['requiresSourceReselection'],
        isTrue,
        reason: marker,
      );
      expect(diagnostics, isNot(contains(secret)), reason: marker);
      expect(
        AsrRetryConfigSnapshot.urlContainsCredentials(host),
        isTrue,
        reason: marker,
      );

      final endpoint = 'https://asr.example.test/v1/$marker/transcribe';
      final endpointSnapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(
          apiKey: 'live-api-key',
          host: endpoint,
          model: 'whisper-small',
        ),
      );
      expect(endpointSnapshot.host, endpoint, reason: marker);
      expect(
        AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(endpoint),
        endpoint,
        reason: marker,
      );
    }
  });

  test(
    'retry snapshots strip credentials after auth and token path markers',
    () {
      for (final marker in ['auth', 'authorization', 'token']) {
        final secret = 'opaque-$marker-path-secret';
        final host = 'https://asr.example.test/transcribe/$marker/$secret';
        final snapshot = AsrRetryConfigSnapshot.fromConfig(
          AsrConfig(apiKey: 'live-api-key', host: host, model: 'whisper-small'),
        );
        final reference = AsrAudioReference(
          id: List.filled(32, 'b').join(),
          name: host,
          format: 'url',
          byteLength: 0,
          sha256: List.filled(64, '0').join(),
          url: host,
        );
        final snapshotJson = jsonEncode(snapshot.toMap());
        final referenceMap = reference.toMap();
        final referenceJson = jsonEncode(referenceMap);
        final diagnosticUrl = AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(
          host,
        );

        expect(snapshot.host, isNot(contains(secret)), reason: marker);
        expect(snapshotJson, isNot(contains(secret)), reason: marker);
        expect(referenceJson, isNot(contains(secret)), reason: marker);
        expect(
          referenceMap['requiresSourceReselection'],
          isTrue,
          reason: marker,
        );
        expect(diagnosticUrl, isNot(contains(secret)), reason: marker);
        expect(
          AsrRetryConfigSnapshot.urlContainsCredentials(host),
          isTrue,
          reason: marker,
        );
      }
    },
  );

  test('retry URLs redact credentials hidden behind encoded path slashes', () {
    const secret = 'opaque-encoded-path-secret';
    const host = 'https://asr.example.test/v1%2Fapi_key%2F$secret';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: host, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'b').join(),
      name: host,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: host,
    );
    final snapshotJson = jsonEncode(snapshot.toMap());
    final referenceMap = reference.toMap();
    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({'url': host}),
    );

    expect(snapshotJson, isNot(contains(secret)));
    expect(referenceMap['url'], isNot(contains(secret)));
    expect(referenceMap['requiresSourceReselection'], isTrue);
    expect(diagnostics, isNot(contains(secret)));
    expect(AsrRetryConfigSnapshot.urlContainsCredentials(host), isTrue);
  });

  test('retry URLs redact 24-character base64 payloads in path segments', () {
    const secret = 'YWJjZGVmZ2hpamtsbW5vcA==';
    const host = 'https://asr.example.test/transcribe/$secret';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: host, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'b').join(),
      name: host,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: host,
    );
    final referenceMap = reference.toMap();

    expect(snapshot.host, isNot(contains(secret)));
    expect(referenceMap['url'], isNot(contains(secret)));
    expect(referenceMap['name'], isNot(contains(secret)));
    expect(referenceMap['requiresSourceReselection'], isTrue);
  });

  test(
    'retry URLs redact multiply encoded audio payloads in path segments',
    () {
      final payload =
          '${List.filled(160, 'A').join()}/${List.filled(157, 'B').join()}==';
      final encodedPayload = Uri.encodeComponent(Uri.encodeComponent(payload));
      final host = 'https://asr.example.test/transcribe/$encodedPayload';
      final snapshot = AsrRetryConfigSnapshot.fromConfig(
        AsrConfig(apiKey: 'live-key', host: host, model: 'whisper-small'),
      );
      final reference = AsrAudioReference(
        id: List.filled(32, 'b').join(),
        name: host,
        format: 'url',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: host,
      );
      final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'url': host,
      });
      final serialized = jsonEncode({
        'snapshot': snapshot.toMap(),
        'reference': reference.toMap(),
        'diagnostics': diagnostics,
      });

      expect(serialized, isNot(contains(payload)));
      expect(serialized, isNot(contains(encodedPayload)));
      expect(reference.toMap()['requiresSourceReselection'], isTrue);
    },
  );

  test('retry URLs redact credential assignments behind encoded delimiters',
      () {
    const value = 'opaque-double-encoded-path-assignment-value-90817';
    const host = 'https://asr.example.test/transcribe/api_key%253D$value';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: host, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'b').join(),
      name: host,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: host,
    );
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': host,
    });
    final diagnosticText = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
      'request failed at /transcribe/api_key%253D$value',
    );
    final serialized = jsonEncode({
      'snapshot': snapshot.toMap(),
      'reference': reference.toMap(),
      'diagnostics': diagnostics,
    });

    expect(serialized, isNot(contains(value)));
    expect(diagnosticText, isNot(contains(value)));
    expect(reference.toMap()['requiresSourceReselection'], isTrue);
    expect(AsrRetryConfigSnapshot.urlContainsCredentials(host), isTrue);

    const benignUrl =
        'https://asr.example.test/transcribe/literal%252Fsegment?mode=verbose';
    expect(AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(benignUrl), benignUrl);
    expect(AsrRetryConfigSnapshot.urlContainsCredentials(benignUrl), isFalse);
  });

  test('malformed encoded credential paths fail closed', () {
    const value = 'opaque-malformed-path-value-90817';
    const host = 'https://asr.example.test/transcribe/api_key%3D$value%ZZ';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: host, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'b').join(),
      name: host,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: host,
    );

    expect(jsonEncode(snapshot.toMap()), isNot(contains(value)));
    expect(jsonEncode(reference.toMap()), isNot(contains(value)));
    expect(reference.toMap()['requiresSourceReselection'], isTrue);
    expect(AsrRetryConfigSnapshot.urlContainsCredentials(host), isTrue);
  });

  test(
    'malformed escapes in credential path markers redact their suffixes',
    () {
      const suffix = 'opaque-secret.tail';
      const url = 'https://asr.example.test/transcribe/api_key%ZZ/$suffix';
      final reference = AsrAudioReference(
        id: List.filled(32, 'b').join(),
        name: url,
        format: 'url',
        byteLength: 0,
        sha256: List.filled(64, '0').join(),
        url: url,
      );
      final diagnostic = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
        'request failed at /transcribe/api_key%ZZ/$suffix',
      );
      final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'error': 'request failed at /transcribe/api_key%ZZ/$suffix',
      });

      expect(jsonEncode(reference.toMap()), isNot(contains(suffix)));
      expect(reference.toMap()['requiresSourceReselection'], isTrue);
      expect(diagnostic, isNot(contains(suffix)));
      expect(jsonEncode(diagnostics), isNot(contains(suffix)));
    },
  );

  test('credential assignments in encoded path segments remove their suffix',
      () {
    const suffix = 'opaque-path-assignment-suffix-90817';
    const host =
        'https://asr.example.test/transcribe/api_key%253Dopaque-prefix%252F$suffix';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: host, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'c').join(),
      name: host,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: host,
    );
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': host,
    });
    final serialized = jsonEncode({
      'snapshot': snapshot.toMap(),
      'reference': reference.toMap(),
      'diagnostics': diagnostics,
    });

    expect(serialized, isNot(contains(suffix)));
    expect(reference.toMap()['requiresSourceReselection'], isTrue);
  });

  test('credential assignments remove later path segments', () {
    const prefix = 'opaque.prefix';
    const suffix = 'opaque.tail';
    const host = 'https://asr.example.test/transcribe/api_key=$prefix/$suffix';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: host, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'c').join(),
      name: host,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: host,
    );
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': host,
    });
    final serialized = jsonEncode({
      'snapshot': snapshot.toMap(),
      'reference': reference.toMap(),
      'diagnostics': diagnostics,
    });

    expect(serialized, isNot(contains(prefix)));
    expect(serialized, isNot(contains(suffix)));
    expect(snapshot.host, contains('/transcribe/api_key'));
    expect(reference.toMap()['requiresSourceReselection'], isTrue);
  });

  test('retry snapshots and diagnostics strip credential URL fragments', () {
    const host =
        'https://asr.example.test/transcribe#access_token=opaque-fragment-secret';
    final config = AsrConfig(
      apiKey: 'live-api-key',
      host: host,
      model: 'whisper-small',
    );
    final snapshot = jsonEncode(
      AsrRetryConfigSnapshot.fromConfig(config).toMap(),
    );
    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({'url': host}),
    );

    expect(snapshot, isNot(contains('opaque-fragment-secret')));
    expect(diagnostics, isNot(contains('opaque-fragment-secret')));
    expect(snapshot, contains('/transcribe'));
    expect(diagnostics, contains('/transcribe'));
  });

  test('retry snapshots redact credential URLs embedded in URL fragments', () {
    const secret = 'opaque-nested-url-secret';
    const host =
        'https://asr.example.test/transcribe#next=https://user:$secret@media.example.test/audio';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-api-key', host: host, model: 'whisper-small'),
    );
    final reference = AsrAudioReference(
      id: List.filled(32, 'a').join(),
      name: 'audio.wav',
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: host,
    );
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': host,
    });
    final serialized = jsonEncode({
      'snapshot': snapshot.toMap(),
      'reference': reference.toMap(),
      'diagnostics': diagnostics,
    });

    expect(serialized, isNot(contains(secret)));
    expect(reference.toMap()['requiresSourceReselection'], isTrue);
    expect(
      reference.toMap()['url'],
      'https://asr.example.test/transcribe#next=https://media.example.test/audio',
    );
  });

  test('credential sanitization preserves ordinary auth endpoint paths', () {
    const endpoint = 'https://asr.example.test/v1/auth/transcribe';
    final snapshot = AsrRetryConfigSnapshot.fromConfig(
      AsrConfig(apiKey: 'live-key', host: endpoint, model: 'whisper-small'),
    );

    expect(snapshot.host, endpoint);
    expect(AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(endpoint), endpoint);
  });

  test('diagnostics redact credential suffixes in Windows paths', () {
    const secret = 'opaque-secret.wav';
    const error = r'request failed at C:\work\api_key\opaque-secret.wav';
    final diagnostic = AsrRetryConfigSnapshot.sanitizeDiagnosticText(error);
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'error': error,
    });
    const benignPath = r'request failed at C:\work\audio\capture.wav';

    expect(diagnostic, isNot(contains(secret)));
    expect(jsonEncode(diagnostics), isNot(contains(secret)));
    expect(
      AsrRetryConfigSnapshot.sanitizeDiagnosticText(benignPath),
      benignPath,
    );
  });

  test('diagnostics redact relative credential paths in nested strings', () {
    const relativePath = '/transcribe/api_key/opaque-relative-secret';
    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'error': 'provider failed at $relativePath',
        'paths': [relativePath],
      }),
    );

    expect(diagnostics, isNot(contains('opaque-relative-secret')));
    expect(diagnostics, contains('/transcribe/api_key'));

    final error = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
      'provider failed at $relativePath',
    );
    expect(error, isNot(contains('opaque-relative-secret')));
    expect(error, contains('/transcribe/api_key'));
  });

  test(
    'diagnostics redact path segments after inline credential assignments',
    () {
      const prefix = 'opaque.prefix';
      const suffix = 'opaque.tail';
      const error = 'request failed at /transcribe/api_key=$prefix/$suffix';
      final diagnostic = AsrRetryConfigSnapshot.sanitizeDiagnosticText(error);
      final diagnostics = jsonEncode(
        AsrRetryConfigSnapshot.sanitizeDiagnosticMap({'error': error}),
      );

      expect(diagnostic, isNot(contains(prefix)));
      expect(diagnostic, isNot(contains(suffix)));
      expect(diagnostics, isNot(contains(prefix)));
      expect(diagnostics, isNot(contains(suffix)));
      expect(diagnostic, contains('/transcribe/api_key'));
    },
  );

  test('diagnostics redact credential markers behind encoded slashes', () {
    const secret = 'opaque-encoded-relative-secret';
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
      'provider failed at /v1%2Fapi_key%2F$secret',
    );

    expect(diagnostics, isNot(contains(secret)));
  });

  test('diagnostics redact credentials in encoded relative query paths', () {
    const secret = 'opaque-relative-query-secret';
    const error = 'provider failed at /transcribe%3Fapi_key%3D$secret';
    final diagnostic = AsrRetryConfigSnapshot.sanitizeDiagnosticText(error);

    expect(diagnostic, isNot(contains(secret)));
  });

  test('diagnostics redact userinfo from embedded URLs', () {
    const secret = 'opaque-embedded-url-userinfo-secret';
    const error =
        'request-failed-at-https://user:$secret@example.test/transcribe';
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticText(error);

    expect(diagnostics, isNot(contains(secret)));
    expect(diagnostics, contains('https://example.test/transcribe'));
  });

  test('diagnostics redact credentials in fully percent-encoded URLs', () {
    const userInfo = 'opaque-encoded-url-userinfo-90817';
    const apiKey = 'opaque-encoded-url-key-90817';
    const encodedUrl =
        'https%3A%2F%2Fuser%3A$userInfo%40asr.example.test%2Ftranscribe%3Fapi_key%3D$apiKey';
    final diagnostic = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
      'request failed at $encodedUrl',
    );

    expect(diagnostic, isNot(contains(userInfo)));
    expect(diagnostic, isNot(contains(apiKey)));
    expect(diagnostic, contains('https://asr.example.test/transcribe'));
  });

  test('diagnostics decode inline credential markers before redaction', () {
    const relativePath = '/transcribe/api_key%3Dopaque-encoded-secret';
    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({'path': relativePath}),
    );
    final error = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
      'provider failed at $relativePath',
    );

    expect(diagnostics, isNot(contains('opaque-encoded-secret')));
    expect(error, isNot(contains('opaque-encoded-secret')));
    expect(diagnostics, contains('/transcribe/api_key'));
    expect(error, contains('/transcribe/api_key'));
  });

  test(
    'diagnostics redact configured credential names between underscores',
    () {
      const apiKey = 'api_key';
      final diagnostic = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
        'request(prefix_${apiKey}_suffix)!',
        configuredApiKey: apiKey,
      );

      expect(diagnostic, isNot(contains(apiKey)));
    },
  );

  test('request diagnostics omit encoded audio and URL credentials', () {
    final encodedAudio = base64Encode(Uint8List(2048));
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'url': 'https://user:private@asr.example.test/transcribe?token=private',
      'body': {'file': encodedAudio, 'model': 'whisper-small'},
      'raw': '{"appKey":"opaque-value","message":"request failed"}',
    });
    final encoded = jsonEncode(diagnostics);

    expect(encoded, isNot(contains(encodedAudio)));
    expect(encoded, isNot(contains('private')));
    expect(encoded, isNot(contains('opaque-value')));
    expect(encoded, contains('whisper-small'));
  });

  test('request diagnostics sanitize URL credentials from map keys', () {
    const secret = 'opaque-map-userinfo-value-90817';
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'https://user:$secret@asr.example.test/path': 'request failed',
      'safe-label': 'still useful',
    });
    final encoded = jsonEncode(diagnostics);

    expect(encoded, isNot(contains(secret)));
    expect(encoded, contains('request failed'));
    expect(encoded, contains('safe-label'));
    expect(encoded, contains('still useful'));
  });

  test('request diagnostics redact credentials and audio in nested lists', () {
    final encodedAudio = base64Encode(Uint8List(2048));
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'body': [
        [
          {
            'authorization': 'Bearer nested-secret',
            'payloads': [
              [
                {'file': encodedAudio, 'label': 'safe'},
              ],
            ],
          },
        ],
      ],
      'urls': [
        [
          'https://user:nested-secret@asr.example.test/path?appKey=query-secret',
        ],
      ],
    });
    final encoded = jsonEncode(diagnostics);

    expect(encoded, isNot(contains(encodedAudio)));
    expect(encoded, isNot(contains('nested-secret')));
    expect(encoded, isNot(contains('query-secret')));
    expect(encoded, contains('safe'));
  });

  test('request diagnostics omit URL-safe base64 under unknown fields', () {
    final sourceBytes = Uint8List.fromList([
      for (var index = 0; index < 2048; index++) (index * 73 + 41) % 256,
    ]);
    final encodedAudio = base64Url.encode(sourceBytes);
    expect(encodedAudio, matches(RegExp(r'[-_]')));

    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({'raw': encodedAudio}),
    );

    expect(diagnostics, isNot(contains(encodedAudio)));
  });

  test('request diagnostics omit short Base64 under unknown fields', () {
    final encodedAudio = base64Encode(
      Uint8List.fromList(List<int>.filled(150, 255)),
    );
    expect(encodedAudio.length, lessThan(256));

    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'raw': encodedAudio,
        'message': 'request failed',
      }),
    );

    expect(diagnostics, isNot(contains(encodedAudio)));
    expect(diagnostics, contains('request failed'));
  });

  test('request diagnostics omit 24-character Base64 under unknown fields', () {
    final encodedAudio = base64Encode(
      Uint8List.fromList(List<int>.filled(16, 0x5a)),
    );
    expect(encodedAudio, hasLength(24));
    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'raw': encodedAudio,
        'message': 'request failed',
      }),
    );

    expect(diagnostics, isNot(contains(encodedAudio)));
    expect(diagnostics, contains('request failed'));
  });

  test('transcript sanitization preserves ordinary Base64-alphabet prose', () {
    for (final text in [
      'transcript for original source',
      'provider transcript',
      'replacement model transcript',
    ]) {
      expect(AsrRetryConfigSnapshot.sanitizeTranscriptText(text), text);
    }
  });

  test('retry metadata and diagnostics omit short contiguous Base64', () {
    final encodedAudio =
        base64Encode(Uint8List.fromList(List<int>.filled(16, 0x5a)));
    expect(encodedAudio.length, lessThan(32));
    final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData({
      'type': 'asr',
      'version': 2,
      'audioReference': {
        'version': AsrAudioReference.currentVersion,
        'id': 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        'name': 'capture.wav',
        'format': 'wav',
        'byteLength': 4,
        'sha256':
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      },
      'chunks': [
        const AsrChunkResult(
          index: 0,
          startSeconds: 0,
          endSeconds: 1,
          totalChunks: 1,
          status: AsrChunkStatus.succeeded,
          text: 'recognized text',
        ).toMap(),
      ],
      'configSnapshot': {
        'host': 'https://asr.example.test/transcribe',
        'model': 'whisper-small',
        'typeConfig': {'metadata': encodedAudio},
      },
    });
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'raw': encodedAudio,
      'message': 'request failed',
    });

    expect(sanitized, isNotNull);
    expect(jsonEncode(sanitized), isNot(contains(encodedAudio)));
    expect(jsonEncode(diagnostics), isNot(contains(encodedAudio)));
    expect(jsonEncode(diagnostics), contains('request failed'));
  });

  test(
    'request diagnostics omit short line-wrapped Base64 under unknown fields',
    () {
      final encodedAudio = base64Encode(
        Uint8List.fromList(List<int>.filled(96, 0x5a)),
      );
      expect(encodedAudio.length, lessThan(256));
      final wrappedAudio = RegExp(
        '.{1,24}',
      ).allMatches(encodedAudio).map((match) => match.group(0)!).join('\n');

      final diagnostics = jsonEncode(
        AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
          'raw': 'request failed: $wrappedAudio',
          'message': 'request failed',
        }),
      );
      expect(diagnostics, isNot(contains(encodedAudio)));
      for (final chunk in RegExp(
        '.{1,24}',
      ).allMatches(encodedAudio).map((match) => match.group(0)!)) {
        expect(diagnostics, isNot(contains(chunk)));
      }
      expect(diagnostics, contains('request failed'));
    },
  );

  test(
    'request diagnostics omit short space-wrapped Base64 under unknown fields',
    () {
      List<String> wrap(String value) {
        const chunkSizes = [13, 19, 8, 21, 11];
        final chunks = <String>[];
        var offset = 0;
        while (offset < value.length) {
          final chunkSize = chunkSizes[chunks.length % chunkSizes.length];
          final end = offset + chunkSize < value.length
              ? offset + chunkSize
              : value.length;
          chunks.add(value.substring(offset, end));
          offset = end;
        }
        return chunks;
      }

      final encodedAudio = base64Encode(
        Uint8List.fromList(
          List<int>.generate(96, (index) => (index * 37 + 11) % 256),
        ),
      );
      expect(encodedAudio.length, lessThan(256));
      final chunks = wrap(encodedAudio);
      final wrappedAudio = chunks.join(' ');

      final diagnostics = jsonEncode(
        AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
          'raw': 'request failed: $wrappedAudio',
          'message': 'request failed',
        }),
      );
      final compactDiagnostics = diagnostics.replaceAll(RegExp(r'\s+'), '');

      expect(compactDiagnostics, isNot(contains(encodedAudio)));
      for (final chunk in chunks) {
        expect(diagnostics, isNot(contains(chunk)));
      }
      expect(diagnostics, contains('request failed'));

      final repeatedAudio = base64Encode(
        Uint8List.fromList(List<int>.filled(96, 0x5a)),
      );
      final repeatedDiagnostics = jsonEncode(
        AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
          'raw': 'request failed: ${wrap(repeatedAudio).join(' ')}',
        }),
      );
      expect(
        repeatedDiagnostics.replaceAll(RegExp(r'\s+'), ''),
        isNot(contains(repeatedAudio)),
      );
    },
  );

  test('request diagnostics redact short Base64 embedded in prose', () {
    final encodedAudio = base64Encode(
      Uint8List.fromList(List<int>.filled(48, 165)),
    );
    final diagnostic = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
      'request failed: $encodedAudio',
    );

    expect(encodedAudio.length, lessThan(256));
    expect(diagnostic, isNot(contains(encodedAudio)));
  });

  test('request diagnostics omit short Base64 inside raw JSON strings', () {
    final encodedAudio = base64Encode(
      Uint8List.fromList(List<int>.filled(48, 165)),
    );
    final rawResponse = jsonEncode({
      'file': encodedAudio,
      'message': 'request failed',
    });

    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({'raw': rawResponse}),
    );

    expect(encodedAudio.length, lessThan(256));
    expect(diagnostics, isNot(contains(encodedAudio)));
    expect(diagnostics, contains('request failed'));
  });

  test('request diagnostics redact Base64 in truncated raw JSON strings', () {
    final encodedAudio = base64Encode(
      Uint8List.fromList(List<int>.filled(48, 165)),
    );
    final truncatedResponse = '{"file":"$encodedAudio","message":';
    final diagnostic = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
      truncatedResponse,
    );
    final diagnostics = jsonEncode(
      AsrRetryConfigSnapshot.sanitizeDiagnosticMap({'raw': truncatedResponse}),
    );

    expect(encodedAudio.length, lessThan(256));
    expect(diagnostic, isNot(contains(encodedAudio)));
    expect(diagnostics, isNot(contains(encodedAudio)));
  });

  test(
    'request diagnostics omit typed binary payloads under unknown fields',
    () {
      final binaryAudio = Uint8List.fromList([
        for (var index = 0; index < 1024; index++) index % 256,
      ]);
      final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
        'payload': binaryAudio,
        'nested': [
          binaryAudio,
          {'bytes': binaryAudio},
        ],
        'label': 'safe',
      });
      final encoded = jsonEncode(diagnostics);

      expect(encoded, isNot(contains(jsonEncode(binaryAudio))));
      expect(encoded, contains('safe'));
    },
  );

  test('request diagnostics omit byte lists under unknown fields', () {
    final bytePayload = Uint8List.fromList([
      for (var index = 0; index < 300; index++) index % 256,
    ]).toList();
    final diagnostics = AsrRetryConfigSnapshot.sanitizeDiagnosticMap({
      'payload': bytePayload,
      'nested': [
        bytePayload,
        {'bytes': bytePayload},
      ],
      'label': 'safe',
    });
    final encoded = jsonEncode(diagnostics);

    expect(encoded, isNot(contains(jsonEncode(bytePayload))));
    expect(encoded, contains('safe'));
  });
}
