import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';

import '../providers/background_task_provider.dart';
import '../providers/task_provider.dart';
import '../utils/text_manifest.dart';
import 'asr_result_saver.dart';
import 'asr_retry_storage.dart';
import 'asr_service.dart';

/// Input captured from the ASR page before navigation starts.
class AsrTaskAudio {
  final Uint8List bytes;
  final String name;
  final String format;
  final AsrAudioReference? audioReference;
  final List<AsrChunkResult> priorChunks;
  final bool resetChunkCheckpoint;

  AsrTaskAudio({
    required Uint8List bytes,
    required this.name,
    this.format = 'wav',
    this.audioReference,
    List<AsrChunkResult> priorChunks = const [],
    this.resetChunkCheckpoint = false,
  })  : bytes = Uint8List.fromList(bytes),
        priorChunks = List.unmodifiable(priorChunks);

  bool get isUrl => format == 'url';
}

class _AsrTaskJob {
  final String taskId;
  final BackgroundTask taskGeneration;
  final AsrTaskAudio audio;
  final String title;
  final CancelToken cancelToken = CancelToken();
  Object? cancellationOwner;
  AsrAudioReference? audioReference;
  bool audioReferencePersisted = false;
  bool completed = false;
  List<AsrChunkResult> chunks;
  AsrService? service;

  _AsrTaskJob(this.taskId, this.taskGeneration, this.audio, this.title)
      : chunks = List.of(audio.priorChunks);
}

/// Owns one standalone ASR batch and runs its tasks serially after the page
/// has handed over a snapshot of all inputs and the save destination.
class AsrTaskScheduler {
  final BackgroundTaskNotifier notifier;
  final AsrConfig config;
  final List<AsrTaskAudio> audios;
  final String saveFolder;
  final Map<String, String> modelReference;
  final String? sourceTaskId;
  final AsrRetryAudioStore _retryStore;
  final AsrService Function(AsrConfig) _serviceFactory;
  final AsrTextWriter _writeText;
  final void Function() _onSaved;
  late final String _configSnapshotSha256 =
      AsrRetryConfigSnapshot.fingerprintFromConfig(config);

  List<_AsrTaskJob>? _jobs;
  Future<void>? _running;
  BackgroundTask? _sourceTaskGeneration;

  AsrTaskScheduler({
    required this.notifier,
    required AsrConfig config,
    required List<AsrTaskAudio> audios,
    required this.saveFolder,
    required Map<String, String> modelReference,
    this.sourceTaskId,
    AsrRetryAudioStore? retryStore,
    AsrService Function(AsrConfig)? serviceFactory,
    AsrTextWriter? writeText,
    void Function()? onSaved,
  })  : config = _snapshotConfig(config),
        audios = List.unmodifiable(
          audios.map(
            (audio) => AsrTaskAudio(
              bytes: audio.bytes,
              name: audio.name,
              format: audio.format,
              audioReference: audio.audioReference,
              priorChunks: audio.priorChunks,
              resetChunkCheckpoint: audio.resetChunkCheckpoint,
            ),
          ),
        ),
        modelReference = Map.unmodifiable(modelReference),
        _retryStore = retryStore ?? AsrRetryAudioStore(),
        _serviceFactory =
            serviceFactory ?? ((config) => AsrService(config: config)),
        _writeText = writeText ?? TextManifest.writeText,
        _onSaved = onSaved ?? _ignoreSaved;

  static AsrConfig _snapshotConfig(AsrConfig config) => config.copyWith(
        typeConfig: Map<String, dynamic>.from(
          jsonDecode(jsonEncode(config.typeConfig)) as Map,
        ),
        customParams: config.customParams.map((param) => param.copy()).toList(),
      );

  static void _ignoreSaved() {}

  List<String> get taskIds => List.unmodifiable(
        (_jobs ?? const <_AsrTaskJob>[]).map((job) => job.taskId),
      );

  /// Creates the waiting tasks once and returns the same execution future for
  /// every later start call.
  Future<void> start() {
    if (_running != null) return _running!;
    final jobs = _jobs ??= _createJobs();
    for (final job in jobs) {
      job.cancellationOwner = notifier.registerCancellationForGeneration(
        job.taskId,
        job.taskGeneration,
        () => _cancel(job),
      );
      notifier.registerTaskCleanup(
        job.taskId,
        () => _cleanupJobAudio(job),
        taskGeneration: job.taskGeneration,
      );
    }
    final sourceId = sourceTaskId;
    if (sourceId != null) {
      _sourceTaskGeneration = notifier.taskById(sourceId);
      final sourceGeneration = _sourceTaskGeneration;
      if (sourceGeneration != null) {
        notifier.registerTaskCleanup(
          sourceId,
          _cleanupAllJobAudio,
          taskGeneration: sourceGeneration,
        );
      }
    }
    _running = _runQueue(jobs);
    return _running!;
  }

  List<_AsrTaskJob> _createJobs() {
    final currentConfigSnapshotJson = jsonEncode(
      AsrRetryConfigSnapshot.fromConfig(config).toMap(),
    );

    bool hasSameConfigSnapshot(BackgroundTask task) {
      final savedSnapshot = task.retryData?['configSnapshot'];
      if (savedSnapshot is! Map) return false;
      try {
        return jsonEncode(savedSnapshot) == currentConfigSnapshotJson;
      } on Object {
        return false;
      }
    }

    // A successful child can remain in the durable source snapshot if the
    // source update failed. Its completed task still owns the same reference.
    bool hasSameModelReference(BackgroundTask task) {
      final savedReference = task.retryData?['modelReference'];
      final configId = modelReference['configId'];
      final modelId = modelReference['modelId'];
      return configId != null &&
          configId.isNotEmpty &&
          modelId != null &&
          modelId.isNotEmpty &&
          savedReference is Map &&
          savedReference['configId'] == configId &&
          savedReference['modelId'] == modelId &&
          hasSameConfigSnapshot(task);
    }

    final completedAudioIds = sourceTaskId == null
        ? <String>{}
        : {
            for (final task in notifier.tasks)
              if (task.type == BackgroundTaskType.asr &&
                  task.status == TaskStatus.completed &&
                  hasSameModelReference(task))
                ...AsrRetryAudioStore.referencedIds(task.retryData),
          };
    return [
      for (final audio in audios)
        if (audio.audioReference == null ||
            !completedAudioIds.contains(audio.audioReference!.id))
          () {
            final title = audio.isUrl
                ? 'ASR_${_urlDisplayName(audio.name, config.apiKey)}'
                : 'ASR_${AsrRetryAudioStore.sanitizeAudioName(audio.name, format: audio.format, configuredApiKey: config.apiKey)}';
            final taskId = notifier.addTask(
              type: BackgroundTaskType.asr,
              title: title,
              startImmediately: false,
            );
            return _AsrTaskJob(
              taskId,
              notifier.taskById(taskId)!,
              audio,
              title,
            );
          }(),
    ];
  }

  static String _urlDisplayName(String url, String configuredApiKey) {
    final safeUrl = AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(
      url,
      configuredApiKey: configuredApiKey,
    );
    try {
      final uri = Uri.parse(safeUrl);
      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
      final name = segments.isEmpty ? uri.host : segments.last;
      return name.length <= 40 ? name : name.substring(0, 40);
    } catch (_) {
      return safeUrl;
    }
  }

  Map<String, dynamic> _buildRetryData(_AsrTaskJob job) => {
        'type': 'asr',
        'version': 2,
        'audioReference': job.audioReference!.toMap(
          configuredApiKey: config.apiKey,
        ),
        'modelReference': modelReference,
        'configSnapshot': AsrRetryConfigSnapshot.fromConfig(config).toMap(),
        'chunks': job.chunks.map((chunk) => chunk.toMap()).toList(),
        'saveFolder': saveFolder,
      };

  Map<String, dynamic> _sanitizeRetryDataForPersistence(
    Map<String, dynamic> retryData,
  ) {
    final sanitized = AsrRetryAudioStore.sanitizeVersionedRetryData(
      retryData,
      configuredApiKey: config.apiKey,
    );
    if (sanitized == null) {
      throw StateError('Invalid ASR retry snapshot');
    }
    return sanitized;
  }

  Future<void> _prepareRetryData(_AsrTaskJob job) async {
    try {
      if (!_isCurrentGeneration(job)) return;
      if (job.audio.isUrl) {
        final existingReference = job.audio.audioReference;
        final sourceUrl = existingReference?.url ?? job.audio.name;
        if (existingReference?.requiresSourceReselection == true) {
          throw const AsrRetrySourceReselectionException();
        }
        final safeUrl = AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(
          sourceUrl,
          configuredApiKey: config.apiKey,
        );
        final requiresReselection =
            AsrRetryConfigSnapshot.urlContainsCredentials(
                  sourceUrl,
                  configuredApiKey: config.apiKey,
                ) ||
                safeUrl != sourceUrl;
        job.audioReference = AsrAudioReference(
          id: existingReference?.id ??
              const Uuid().v4().replaceAll('-', '').toLowerCase(),
          name: safeUrl,
          format: 'url',
          byteLength: existingReference?.byteLength ?? 0,
          sha256: existingReference?.sha256 ?? List.filled(64, '0').join(),
          url: safeUrl,
          requiresSourceReselection: requiresReselection,
        );
      } else if (job.audio.audioReference != null) {
        final reference = job.audio.audioReference!;
        job.audioReference = AsrAudioReference(
          version: reference.version,
          id: reference.id,
          name: AsrRetryAudioStore.sanitizeAudioName(
            reference.name,
            format: reference.format,
            configuredApiKey: config.apiKey,
          ),
          format: reference.format,
          byteLength: reference.byteLength,
          sha256: reference.sha256,
          url: reference.url,
          requiresSourceReselection: reference.requiresSourceReselection,
        );
        await _retryStore.protectUntilReferenced(job.audioReference!);
        if (!_isCurrentGeneration(job)) return;
        await _retryStore.ensureStored(
          job.audioReference!,
          job.audio.bytes,
          configuredApiKey: config.apiKey,
        );
      } else {
        job.audioReference = await _retryStore.save(
          job.audio.bytes,
          name: job.audio.name,
          format: job.audio.format,
          configuredApiKey: config.apiKey,
          onReferenceCreated: (reference) {
            job.audioReference = reference;
          },
        );
      }
      if (!_isCurrentGeneration(job)) return;
      await _restoreChunkCheckpoint(job);
      if (!_isCurrentGeneration(job)) return;
      await _writeRetryData(job);
    } catch (_) {
      if (_isCurrentGeneration(job) &&
          !job.audioReferencePersisted &&
          job.audioReference != null &&
          notifier.taskById(job.taskId)?.retryData != null) {
        await notifier.clearRetryDataForGeneration(
          job.taskId,
          job.taskGeneration,
        );
      }
      rethrow;
    } finally {
      final reference = job.audioReference;
      if (reference != null) await _retryStore.releaseProtection(reference);
      if (reference != null &&
          notifier.retryAudioCleanupSafe &&
          (!_isCurrentGeneration(job) || !job.audioReferencePersisted)) {
        await _retryStore.deleteIfUnreferenced(
          reference,
          _referencedAudioIds(),
        );
      }
    }
  }

  Future<void> _writeRetryData(_AsrTaskJob job) async {
    if (job.audioReference == null) return;
    if (!_isCurrentGeneration(job)) return;
    final retryData = _sanitizeRetryDataForPersistence(_buildRetryData(job));
    final saved = await notifier.setRetryDataAndWaitForGeneration(
      job.taskId,
      job.taskGeneration,
      retryData,
    );
    if (!saved && _isCurrentGeneration(job)) {
      throw StateError('ASR retry state could not be saved');
    }
    if (!saved) return;
    job.audioReferencePersisted = true;
    if (!_isCurrentGeneration(job)) return;
    await _writeSourceRetryData();
  }

  Future<void> _writeSourceRetryData() async {
    final sourceId = sourceTaskId;
    final sourceGeneration = _sourceTaskGeneration;
    final jobs = _jobs;
    if (sourceId == null ||
        sourceGeneration == null ||
        jobs == null ||
        notifier.taskById(sourceId)?.hasSameGenerationAs(sourceGeneration) !=
            true ||
        jobs.any(
          (job) =>
              _isCurrentGeneration(job) &&
              (job.audioReference == null || !job.audioReferencePersisted),
        )) {
      return;
    }
    final pendingJobs = jobs
        .where((job) => !job.completed && _isCurrentGeneration(job))
        .toList();
    if (pendingJobs.isEmpty) {
      if (!await notifier.clearRetryDataForGeneration(
        sourceId,
        sourceGeneration,
      )) {
        throw StateError('ASR source retry state could not be saved');
      }
      return;
    }
    final retryData = jobs.length == 1
        ? _buildRetryData(pendingJobs.single)
        : {
            'type': 'asr',
            'version': 2,
            'audioReferences': [
              for (final job in pendingJobs)
                {
                  'audioReference': job.audioReference!.toMap(
                    configuredApiKey: config.apiKey,
                  ),
                  'chunks': job.chunks.map((chunk) => chunk.toMap()).toList(),
                },
            ],
            'modelReference': modelReference,
            'configSnapshot': AsrRetryConfigSnapshot.fromConfig(config).toMap(),
            'saveFolder': saveFolder,
          };
    final sanitizedRetryData = _sanitizeRetryDataForPersistence(retryData);
    if (!await notifier.setRetryDataAndWaitForGeneration(
      sourceId,
      sourceGeneration,
      sanitizedRetryData,
    )) {
      if (notifier.taskById(sourceId)?.hasSameGenerationAs(sourceGeneration) !=
          true) {
        return;
      }
      throw StateError('ASR source retry state could not be saved');
    }
  }

  Future<void> _recordChunk(_AsrTaskJob job, AsrChunkResult chunk) async {
    _checkActive(job);
    job.chunks = _replaceChunk(job.chunks, chunk);
    try {
      await _retryStore.writeChunkCheckpoint(
        job.audioReference!,
        job.chunks,
        modelReference: modelReference,
        configSnapshotSha256: _configSnapshotSha256,
        configuredApiKey: config.apiKey,
        // This callback records the service's definitive post-request outcome.
        // Pre-request checkpoints and restore merges leave this disabled so a
        // stale failed snapshot cannot downgrade an uncertain POST.
        allowUncertainToBeResolved: chunk.status == AsrChunkStatus.failed,
      );
    } catch (error) {
      throw StateError('ASR 分段恢复记录写入失败；当前请求结果可能不确定，任务已停止: $error');
    }
    await _writeRetryData(job);
  }

  Future<void> _restoreChunkCheckpoint(_AsrTaskJob job) async {
    if (!_isCurrentGeneration(job)) return;
    final reference = job.audioReference;
    if (reference == null) return;
    if (job.audio.resetChunkCheckpoint) {
      await _retryStore.clearChunkCheckpoint(
        reference,
        configuredApiKey: config.apiKey,
      );
      if (!_isCurrentGeneration(job)) return;
      job.chunks = [];
      return;
    }
    final checkpoint = await _retryStore.readChunkCheckpoint(
      reference,
      modelReference: modelReference,
      configSnapshotSha256: _configSnapshotSha256,
      configuredApiKey: config.apiKey,
    );
    if (!_isCurrentGeneration(job)) return;
    final merged = _mergeChunks(job.chunks, checkpoint?.chunks ?? const []);
    final oldCheckpoint = checkpoint?.chunks ?? const <AsrChunkResult>[];
    if (jsonEncode(merged.map((chunk) => chunk.toMap()).toList()) !=
        jsonEncode(oldCheckpoint.map((chunk) => chunk.toMap()).toList())) {
      if (merged.isNotEmpty) {
        if (!_isCurrentGeneration(job)) return;
        await _retryStore.writeChunkCheckpoint(
          reference,
          merged,
          modelReference: modelReference,
          configSnapshotSha256: _configSnapshotSha256,
          configuredApiKey: config.apiKey,
        );
      }
    }
    job.chunks = merged;
  }

  List<AsrChunkResult> _mergeChunks(
    Iterable<AsrChunkResult> taskChunks,
    Iterable<AsrChunkResult> checkpointChunks,
  ) {
    final taskChunkList = taskChunks.toList();
    final checkpointChunkList = checkpointChunks.toList();
    final taskPlanFingerprint = _singlePlanFingerprint(taskChunkList);
    final checkpointPlanFingerprint = _singlePlanFingerprint(
      checkpointChunkList,
    );
    if (checkpointPlanFingerprint != null &&
        checkpointPlanFingerprint != taskPlanFingerprint) {
      // A durable attempt marker is written before each POST. Its plan
      // identity supersedes stale task rows from an earlier chunk layout.
      return checkpointChunkList;
    }
    if (taskPlanFingerprint != null && checkpointPlanFingerprint == null) {
      // Task rows carry a plan identity but no model/config binding. Without a
      // matching sidecar, do not reuse successful output under an unknown
      // configuration. Keep it only as partial text when an uncertain row
      // forces this retry to fail closed before sending another request.
      final hasUncertainTaskChunk = taskChunkList.any(
        (chunk) => chunk.status == AsrChunkStatus.uncertain,
      );
      return taskChunkList
          .where(
            (chunk) =>
                hasUncertainTaskChunk ||
                chunk.status != AsrChunkStatus.succeeded,
          )
          .toList();
    }
    final merged = <int, AsrChunkResult>{
      for (final chunk in taskChunkList) chunk.index: chunk,
    };
    for (final checkpoint in checkpointChunkList) {
      final taskChunk = merged[checkpoint.index];
      if (checkpoint.status == AsrChunkStatus.succeeded &&
          taskChunk != null &&
          _sameChunkPlan(checkpoint, taskChunk)) {
        // A durable sidecar success survives stale task-level failure markers.
        if (taskChunk.status != AsrChunkStatus.succeeded) {
          merged[checkpoint.index] = checkpoint;
        }
        continue;
      }
      if (taskChunk?.status == AsrChunkStatus.succeeded &&
          checkpoint.status != AsrChunkStatus.succeeded &&
          _sameChunkPlan(taskChunk!, checkpoint)) {
        // A task snapshot can recover a successful response if the sidecar
        // result write failed after the provider returned it.
        continue;
      }
      merged[checkpoint.index] = checkpoint;
    }
    final chunks = merged.values.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    return chunks;
  }

  bool _sameChunkPlan(AsrChunkResult left, AsrChunkResult right) =>
      left.index == right.index &&
      left.totalChunks == right.totalChunks &&
      left.planFingerprint == right.planFingerprint &&
      (left.startSeconds - right.startSeconds).abs() < 0.001 &&
      (left.endSeconds - right.endSeconds).abs() < 0.001;

  String? _singlePlanFingerprint(Iterable<AsrChunkResult> chunks) {
    final fingerprints = {
      for (final chunk in chunks)
        if (chunk.planFingerprint != null) chunk.planFingerprint,
    };
    if (fingerprints.length != 1 ||
        chunks.any((chunk) => chunk.planFingerprint == null)) {
      return null;
    }
    return fingerprints.single;
  }

  List<AsrChunkResult> _replaceChunk(
    Iterable<AsrChunkResult> chunks,
    AsrChunkResult chunk,
  ) {
    final updated = [
      for (final candidate in chunks)
        if (candidate.planFingerprint == chunk.planFingerprint &&
            candidate.totalChunks == chunk.totalChunks &&
            candidate.index != chunk.index)
          candidate,
      chunk,
    ]..sort((left, right) => left.index.compareTo(right.index));
    return updated;
  }

  List<AsrChunkResult> _bindCompleteLegacyChunksToPlan(
    Iterable<AsrChunkResult> chunks,
    AsrChunkResult attempt,
  ) {
    final candidates = chunks.toList();
    final totalChunks = attempt.totalChunks;
    final planFingerprint = attempt.planFingerprint;
    if (totalChunks == null ||
        planFingerprint == null ||
        candidates.length != totalChunks ||
        candidates.any(
          (candidate) =>
              candidate.planFingerprint != null ||
              candidate.totalChunks != totalChunks ||
              candidate.status == AsrChunkStatus.uncertain,
        )) {
      return candidates;
    }

    candidates.sort((left, right) => left.index.compareTo(right.index));
    for (var index = 0; index < totalChunks; index++) {
      if (candidates[index].index != index) return candidates;
    }
    final legacyFingerprint = fingerprintAsrChunkPlan([
      for (final candidate in candidates)
        (
          startSeconds: candidate.startSeconds,
          endSeconds: candidate.endSeconds,
        ),
    ]);
    if (legacyFingerprint != planFingerprint) return candidates;

    return [
      for (final candidate in candidates)
        AsrChunkResult(
          index: candidate.index,
          startSeconds: candidate.startSeconds,
          endSeconds: candidate.endSeconds,
          totalChunks: candidate.totalChunks,
          planFingerprint: planFingerprint,
          status: candidate.status,
          text: candidate.text,
          subtitle: candidate.subtitle,
          error: candidate.error,
          segments: candidate.segments,
          words: candidate.words,
        ),
    ];
  }

  Future<void> _markChunkAttempt(
    _AsrTaskJob job,
    AsrChunkResult attempt,
  ) async {
    _checkActive(job);
    job.chunks = _replaceChunk(
      _bindCompleteLegacyChunksToPlan(job.chunks, attempt),
      attempt,
    );
    try {
      await _retryStore.writeChunkCheckpoint(
        job.audioReference!,
        job.chunks,
        modelReference: modelReference,
        configSnapshotSha256: _configSnapshotSha256,
        configuredApiKey: config.apiKey,
      );
    } catch (error) {
      throw StateError('ASR 分段恢复记录写入失败；该片段尚未发送，可修复本地存储后重试: $error');
    }

    final task = notifier.taskById(job.taskId);
    final wasCancelledBeforeDispatch =
        job.cancelToken.isCancelled || task?.status != TaskStatus.running;
    if (wasCancelledBeforeDispatch && _isCurrentGeneration(job)) {
      final failedAttempt = AsrChunkResult(
        index: attempt.index,
        startSeconds: attempt.startSeconds,
        endSeconds: attempt.endSeconds,
        totalChunks: attempt.totalChunks,
        planFingerprint: attempt.planFingerprint,
        status: AsrChunkStatus.failed,
      );
      final resolvedChunks = _replaceChunk(job.chunks, failedAttempt);
      try {
        await _retryStore.writeChunkCheckpoint(
          job.audioReference!,
          resolvedChunks,
          modelReference: modelReference,
          configSnapshotSha256: _configSnapshotSha256,
          configuredApiKey: config.apiKey,
          // The service has not dispatched its request until this callback
          // returns, so cancellation during the durable marker write is known
          // to be a definite, retryable failure.
          allowUncertainToBeResolved: true,
        );
        job.chunks = resolvedChunks;
      } catch (error) {
        throw StateError('ASR 取消前的分段状态写入失败；该片段仍按结果不确定处理: $error');
      }
    }
    _checkActive(job);
  }

  Set<String> _referencedAudioIds() {
    final ids = notifier.retryAudioReferencedIds;
    return ids;
  }

  Future<void> _pruneUnusedAudio() => notifier.retryAudioCleanupSafe
      ? _retryStore.prune(_referencedAudioIds)
      : Future<void>.value();

  Future<void> _cleanupJobAudio(_AsrTaskJob job) async {
    final reference = job.audioReference;
    if (!notifier.retryAudioCleanupSafe || reference == null) return;
    await _retryStore.deleteIfUnreferenced(reference, _referencedAudioIds());
  }

  Future<void> _cleanupAllJobAudio() async {
    if (!notifier.retryAudioCleanupSafe) return;
    final references = <String, AsrAudioReference>{};
    for (final audio in audios) {
      final reference = audio.audioReference;
      if (reference != null) references[reference.id] = reference;
    }
    for (final job in _jobs ?? const <_AsrTaskJob>[]) {
      final reference = job.audioReference;
      if (reference != null) references[reference.id] = reference;
    }
    for (final reference in references.values) {
      await _retryStore.deleteIfUnreferenced(reference, _referencedAudioIds());
    }
  }

  Future<void> _releaseCompletedRetryData(_AsrTaskJob job) async {
    job.completed = true;
    await _writeSourceRetryData();
    if (!await notifier.clearRetryDataForGeneration(
      job.taskId,
      job.taskGeneration,
    )) {
      return;
    }
    await _pruneUnusedAudio();
    notifier.unregisterTaskCleanup(
      job.taskId,
      taskGeneration: job.taskGeneration,
    );
  }

  bool _isCurrentGeneration(_AsrTaskJob job) {
    final task = notifier.taskById(job.taskId);
    return task != null && task.hasSameGenerationAs(job.taskGeneration);
  }

  void _unregisterCancellation(_AsrTaskJob job) {
    final owner = job.cancellationOwner;
    if (owner == null) return;
    notifier.unregisterCancellationForGeneration(job.taskId, owner);
    job.cancellationOwner = null;
  }

  void _cancel(_AsrTaskJob job) {
    if (!job.cancelToken.isCancelled) job.cancelToken.cancel('已取消');
    job.service?.close(force: true);
  }

  void _checkActive(_AsrTaskJob job) {
    final task = notifier.taskById(job.taskId);
    if (task == null ||
        !task.hasSameGenerationAs(job.taskGeneration) ||
        task.status != TaskStatus.running) {
      _cancel(job);
    }
    if (job.cancelToken.isCancelled) throw job.cancelToken.cancelError!;
  }

  Future<void> _runQueue(List<_AsrTaskJob> jobs) async {
    if (jobs.isEmpty && audios.isNotEmpty) {
      final sourceId = sourceTaskId;
      final sourceGeneration = _sourceTaskGeneration;
      if (sourceId != null &&
          sourceGeneration != null &&
          await notifier.clearRetryDataForGeneration(
            sourceId,
            sourceGeneration,
          )) {
        await _pruneUnusedAudio();
      }
      return;
    }
    // Persist every queued input before starting any provider request. A
    // restart can therefore restore waiting tasks without retaining Base64
    // audio inside task JSON.
    final prepared = <String>{};
    for (final job in jobs) {
      if (!_isCurrentGeneration(job)) continue;
      try {
        await _prepareRetryData(job);
        if (_isCurrentGeneration(job)) prepared.add(job.taskId);
      } catch (error) {
        if (!_isCurrentGeneration(job)) continue;
        if (notifier.startTaskIfWaitingForGeneration(
          job.taskId,
          job.taskGeneration,
        )) {
          notifier.failTask(
            job.taskId,
            error:
                '无法保存 ASR 重试音频，任务未发送: ${AsrRetryConfigSnapshot.sanitizeDiagnosticText('$error', configuredApiKey: config.apiKey)}',
          );
        }
        _unregisterCancellation(job);
      }
    }
    final activeJobs = jobs.where(_isCurrentGeneration).toList();
    if (sourceTaskId != null && prepared.length != activeJobs.length) {
      for (final job in activeJobs) {
        if (!job.audioReferencePersisted) continue;
        final reference = job.audioReference;
        if (await notifier.clearRetryDataForGeneration(
          job.taskId,
          job.taskGeneration,
        )) {
          job.audioReferencePersisted = false;
          if (reference != null) await _cleanupJobAudio(job);
        }
        if (notifier.startTaskIfWaitingForGeneration(
          job.taskId,
          job.taskGeneration,
        )) {
          notifier.failTask(job.taskId, error: '批次中的其他音频无法保存，已取消发送');
        }
        _unregisterCancellation(job);
      }
      return;
    }
    for (final job in jobs) {
      if (!prepared.contains(job.taskId) || !_isCurrentGeneration(job)) {
        continue;
      }
      if (!notifier.startTaskIfWaitingForGeneration(
        job.taskId,
        job.taskGeneration,
      )) {
        _unregisterCancellation(job);
        notifier.unregisterTaskCleanup(
          job.taskId,
          taskGeneration: job.taskGeneration,
        );
        await _cleanupJobAudio(job);
        continue;
      }
      await _runTask(job);
    }
  }

  Future<void> _runTask(_AsrTaskJob job) async {
    AsrService? service;
    var hasResult = false;
    try {
      _checkActive(job);
      final uncertainChunk = job.chunks
          .where((chunk) => chunk.status == AsrChunkStatus.uncertain)
          .firstOrNull;
      if (uncertainChunk != null) {
        throw AsrChunkedTranscriptionException(job.chunks);
      }
      notifier.updateStep(job.taskId, 0, running: true);
      service = job.service = _serviceFactory(config);
      final result = job.audio.isUrl
          ? await service.transcribeFromUrl(
              job.audio.name,
              cancelToken: job.cancelToken,
              priorChunks: job.chunks,
              onChunkAttempt: (attempt) => _markChunkAttempt(job, attempt),
              onChunkResult: (chunk) => _recordChunk(job, chunk),
              onProgress: (event) => _reportProgress(job, event),
            )
          : await service.transcribe(
              audioBytes: job.audio.bytes,
              audioFormat: job.audio.format,
              cancelToken: job.cancelToken,
              priorChunks: job.chunks,
              onChunkAttempt: (attempt) => _markChunkAttempt(job, attempt),
              onChunkResult: (chunk) => _recordChunk(job, chunk),
              onProgress: (event) => _reportProgress(job, event),
            );
      _checkActive(job);
      hasResult = true;
      notifier.setResult(job.taskId, result.text, folder: saveFolder);
      _checkActive(job);
      for (var index = 0; index < 4; index++) {
        notifier.updateStep(job.taskId, index, completed: true);
      }
      notifier.updateStep(job.taskId, 4, running: true);
      await AsrResultSaver(
        taskId: job.taskId,
        notifier: notifier,
        title: job.title,
        folder: saveFolder,
        cancelToken: job.cancelToken,
        onSaved: _onSaved,
        writeText: _writeText,
      ).saveResult(result.subtitle ?? result.text, format: result.outputFormat);
      try {
        await _releaseCompletedRetryData(job);
      } catch (error) {
        debugPrint('[AsrTaskScheduler] Retry audio cleanup failed: $error');
      }
    } catch (error) {
      if (job.cancelToken.isCancelled || !_isCurrentGeneration(job)) return;
      final task = notifier.taskById(job.taskId);
      if (task == null) return;

      if (!hasResult &&
          error is AsrChunkedTranscriptionException &&
          error.partialText.isNotEmpty) {
        if (task.status != TaskStatus.running) {
          _cancel(job);
          return;
        }
        notifier.setResult(
          job.taskId,
          error.partialText,
          isComplete: false,
          folder: saveFolder,
        );
      }
      if (error is AsrChunkedTranscriptionException) {
        job.chunks = error.recoveryChunks;
        try {
          await _writeRetryData(job);
        } catch (_) {}
      }
      final safeError = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
        '$error',
        configuredApiKey: config.apiKey,
      );
      for (var index = 0; index < task.steps.length; index++) {
        if (task.steps[index].running) {
          notifier.updateStep(
            job.taskId,
            index,
            failed: true,
            error: safeError,
          );
        } else if (task.steps[index].status == BgStepStatus.pending) {
          notifier.updateStep(job.taskId, index, skipped: true);
        }
      }
      final rawRequest = <String, dynamic>{
        if (service?.lastRequestUrl != null)
          'url': AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(
            service!.lastRequestUrl!,
            configuredApiKey: config.apiKey,
          ),
        if (service?.lastRequestHeaders != null)
          'headers': AsrRetryConfigSnapshot.sanitizeDiagnosticMap(
            service!.lastRequestHeaders!,
            configuredApiKey: config.apiKey,
          ),
        if (service?.lastRequestBody != null)
          'body': AsrRetryConfigSnapshot.sanitizeDiagnosticMap(
            service!.lastRequestBody!,
            configuredApiKey: config.apiKey,
          ),
      };
      final rawResponse = <String, dynamic>{
        if (service?.lastResponseStatusCode != null)
          'statusCode': service!.lastResponseStatusCode,
        if (service?.lastResponseHeaders != null)
          'headers': AsrRetryConfigSnapshot.sanitizeDiagnosticMap(
            service!.lastResponseHeaders!,
            configuredApiKey: config.apiKey,
          ),
        if (service?.lastResponseData != null)
          'data': AsrRetryConfigSnapshot.sanitizeDiagnosticMap(
            service!.lastResponseData!,
            configuredApiKey: config.apiKey,
          ),
      };
      notifier.failTask(
        job.taskId,
        error: hasResult ? '音频转写结果保存失败: $safeError' : '音频转写失败: $safeError',
        rawRequest: rawRequest,
        rawResponse: rawResponse,
      );
    } finally {
      if (_isCurrentGeneration(job)) {
        _unregisterCancellation(job);
      }
      service?.close();
      job.service = null;
    }
  }

  void _reportProgress(_AsrTaskJob job, AsrRequestProgress event) {
    _checkActive(job);
    final chunk = event.chunkCount > 1
        ? '（片段 ${event.chunkIndex}/${event.chunkCount}）'
        : '';
    switch (event.phase) {
      case AsrRequestPhase.uploading:
        notifier.updateStep(job.taskId, 0, completed: true);
        final label = event.totalSendBytes > 0
            ? '上传音频$chunk ${((event.sentBytes * 100) ~/ event.totalSendBytes).clamp(0, 100)}%'
            : '上传音频$chunk';
        notifier.updateStep(job.taskId, 1, running: true, label: label);
      case AsrRequestPhase.waiting:
        notifier.updateStep(job.taskId, 0, completed: true);
        notifier.updateStep(job.taskId, 1, completed: true);
        final label = event.chunkCount > 1
            ? '转写中（片段 ${event.chunkIndex}/${event.chunkCount}）'
            : '转写中';
        notifier.updateStep(job.taskId, 2, running: true, label: label);
      case AsrRequestPhase.receiving:
        if (event.chunkIndex == event.chunkCount) {
          notifier.updateStep(job.taskId, 2, completed: true);
          final label = event.totalReceiveBytes > 0
              ? '接收结果 ${((event.receivedBytes * 100) ~/ event.totalReceiveBytes).clamp(0, 100)}%'
              : '接收结果';
          notifier.updateStep(job.taskId, 3, running: true, label: label);
        } else {
          notifier.updateStep(
            job.taskId,
            2,
            running: true,
            label: '转写中（接收片段 ${event.chunkIndex}/${event.chunkCount}）',
          );
        }
      case AsrRequestPhase.responseReceived:
      case AsrRequestPhase.chunkCompleted:
        if (event.chunkIndex == event.chunkCount) {
          notifier.updateStep(job.taskId, 2, completed: true);
          notifier.updateStep(job.taskId, 3, running: true, label: '接收结果');
        } else {
          final label = event.phase == AsrRequestPhase.chunkCompleted
              ? '转写中（已完成片段 ${event.chunkIndex}/${event.chunkCount}）'
              : '转写中（片段 ${event.chunkIndex}/${event.chunkCount} 已返回）';
          notifier.updateStep(job.taskId, 2, running: true, label: label);
        }
    }
  }
}
