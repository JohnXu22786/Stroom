import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../models/ocr_batch_execution.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/ios_continued_task_service.dart';
import '../services/asr_retry_storage.dart';
import '../services/ocr_retry_storage.dart';
import '../pages/ocr/ocr_retry_snapshot.dart';
import '../utils/atomic_file.dart';
import '../utils/ocr_diagnostics.dart';
import 'locale_provider.dart';
import 'task_provider.dart';

const _unrestoredTaskRecordMarker = {'_unrestoredTaskRecord': true};

bool _isBackgroundTaskCancellationError(String? error) =>
    error == '已取消' || error == 'Canceled';

Map<String, dynamic> _unrestoredTaskRecord({
  required bool retryAudioOwnershipKnown,
  Set<String> retryAudioIds = const {},
  bool retireAfterSnapshot = false,
  bool ocrCacheOwnershipKnown = true,
  String? ocrCacheTaskId,
}) =>
    {
      '_unrestoredTaskRecord': true,
      'retryAudioOwnershipKnown': retryAudioOwnershipKnown,
      'ocrCacheOwnershipKnown': ocrCacheOwnershipKnown,
      if (ocrCacheTaskId != null) 'ocrCacheTaskId': ocrCacheTaskId,
      if (retryAudioIds.isNotEmpty)
        'retryAudioIds': retryAudioIds.toList()..sort(),
      if (retireAfterSnapshot) 'retireAfterSnapshot': true,
    };

bool _canRetireAsrOwnershipAfterSnapshot(Map? task, Object? retryData) {
  if (task?['type'] != BackgroundTaskType.asr.name) return false;
  if (_hasAudioOwnershipOutsideRetryData(task)) return false;
  if (retryData == null) return true;
  if (retryData is! Map) return false;
  final version = retryData['version'];
  return version == null || (version is int && version <= 2);
}

bool _hasAudioOwnershipOutsideRetryData(Object? record) {
  if (record is! Map) return false;

  final retryAudioPathPattern = RegExp(
    r'(?:^|[/\\])[a-f0-9]{32}\.audio(?:$|[?#])',
    caseSensitive: false,
  );

  bool containsAudioField(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is String &&
            RegExp(r'audio', caseSensitive: false).hasMatch(key)) {
          return true;
        }
        if (containsAudioField(entry.value)) return true;
      }
    } else if (value is List) {
      return value.any(containsAudioField);
    } else if (value is String) {
      return retryAudioPathPattern.hasMatch(value);
    }
    return false;
  }

  final fieldsOutsideRetryData = Map.fromEntries(
    record.entries.where((entry) => entry.key != 'retryData'),
  );
  return containsAudioField(fieldsOutsideRetryData);
}

bool _hasUntrackedSkippedAsrAudioOwnership(Iterable<dynamic> entries) =>
    entries.any(
      (entry) =>
          entry is Map &&
          entry['type'] == BackgroundTaskType.asr.name &&
          _recoverRetryAudioIds(entry) == null,
    );

Set<String>? _recoverRetryAudioIds(Object? record) {
  if (record == null || record is String || record is num || record is bool) {
    return <String>{};
  }
  if (record is! Map) return null;
  if (_hasAudioOwnershipOutsideRetryData(record)) return null;
  final retryData = record['retryData'];
  if (retryData == null) return <String>{};
  if (retryData is! Map) return null;
  final retryDataMap = Map<String, dynamic>.from(retryData);
  final recognizedIds =
      AsrRetryAudioStore.recoverableReferencedIds(retryDataMap);
  if (recognizedIds == null) return null;
  return {...recognizedIds, ..._unrecognizedRetryAudioIds(retryDataMap)};
}

Set<String> _unrecognizedRetryAudioIds(Map<String, dynamic>? retryData) {
  final ids = <String>{};
  void collectIds(Object? value) {
    if (value is String) {
      if (RegExp(r'^[a-f0-9]{32}$').hasMatch(value)) {
        ids.add(value);
      } else if (value.contains('/') || value.contains(r'\')) {
        ids.addAll(
          RegExp(r'[a-f0-9]{32}').allMatches(value).map((match) => match[0]!),
        );
      }
    } else if (value is Map) {
      for (final nested in value.values) {
        collectIds(nested);
      }
    } else if (value is List) {
      for (final nested in value) {
        collectIds(nested);
      }
    }
  }

  void scan(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is String &&
            RegExp(r'audio', caseSensitive: false).hasMatch(entry.key)) {
          collectIds(entry.value);
        } else if (entry.value is String &&
            RegExp(
              r'(?:^|[/\\])[a-f0-9]{32}\.audio(?:$|[?#])',
              caseSensitive: false,
            ).hasMatch(entry.value as String)) {
          // Unknown metadata can name a retry file without an audio-specific
          // key. Keep the referenced ID until that field is durably removed.
          collectIds(entry.value);
        } else {
          scan(entry.value);
        }
      }
    } else if (value is List) {
      for (final nested in value) {
        scan(nested);
      }
    }
  }

  scan(retryData);
  ids.removeAll(AsrRetryAudioStore.referencedIds(retryData));
  return ids;
}

bool _canSafelyPreserveLegacyAsrRetryData(Object? value, [String? field]) {
  final normalizedField = (field ?? '')
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}-${match[2]}',
      )
      .replaceAllMapped(
        RegExp(r'([A-Z])([A-Z][a-z])'),
        (match) => '${match[1]}-${match[2]}',
      )
      .replaceAll(RegExp(r'\s+'), '-')
      .toLowerCase();
  if (RegExp(
    r'(?:^|[-_.])(?:api[-_.]?keys?|private[-_.]?keys?|keys?|tokens?|bearers?|secrets?|passwords?|authorizations?|auth(?:entication)?s?|credentials?)(?:$|[-_.])',
  ).hasMatch(normalizedField)) {
    return false;
  }
  if (value == null || value is num || value is bool) return true;
  final isAudioReferenceContainer = normalizedField == 'audio-reference' ||
      normalizedField == 'audio-references';
  if ((!isAudioReferenceContainer && normalizedField.contains('audio')) ||
      normalizedField.contains('byte') ||
      normalizedField.contains('base64') ||
      normalizedField.contains('payload')) {
    return false;
  }
  if (value is String) {
    final trimmed = value.trim();
    if (OcrDiagnosticSnapshot.containsCredential(trimmed)) return false;
    if (RegExp(
      r'data:[^\s,]*;base64,',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    final looksLikeUrl = uri != null &&
        (uri.hasAuthority ||
            uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    if (looksLikeUrl &&
        AsrRetryConfigSnapshot.urlContainsCredentials(trimmed)) {
      return false;
    }
    if (RegExp(
          r'(?:api[_-]?key|token|secret|password|authorization|bearer)\s*[:=]',
          caseSensitive: false,
        ).hasMatch(trimmed) ||
        RegExp(
          r'(?:[?&]|^)(?:api[_-]?key|token|secret|password|authorization)=',
          caseSensitive: false,
        ).hasMatch(trimmed)) {
      return false;
    }
    final isTaskId = normalizedField == 'id' || normalizedField == 'uuid';
    final isHash = normalizedField == 'sha256' ||
        normalizedField == 'checksum' ||
        normalizedField == 'digest';
    final isKnownIdentifier = isTaskId &&
            RegExp(
              r'^(?:[a-f0-9]{32}|[a-f0-9-]{36})$',
              caseSensitive: false,
            ).hasMatch(trimmed) ||
        isHash &&
            RegExp(r'^[a-f0-9]{64}$', caseSensitive: false).hasMatch(trimmed);
    final isUserVisibleTitle = normalizedField == 'title';
    // A user-visible title may legitimately use only Base64url characters;
    // encoded-value detection applies to generic metadata fields instead.
    if (!isKnownIdentifier &&
        !isUserVisibleTitle &&
        trimmed.length >= 16 &&
        RegExp(r'^[A-Za-z0-9+/_=-]+$').hasMatch(trimmed)) {
      return false;
    }
    if (_looksLikeLineWrappedBase64(trimmed)) return false;
    return true;
  }
  if (value is List) {
    if (normalizedField.contains('byte') ||
        (!isAudioReferenceContainer && normalizedField.contains('audio')) ||
        normalizedField.contains('base64') ||
        normalizedField.contains('payload')) {
      return false;
    }
    return value.every((item) => _canSafelyPreserveLegacyAsrRetryData(item));
  }
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key is! String ||
          !_canSafelyPreserveLegacyAsrRetryData(
            entry.value,
            entry.key as String,
          )) {
        return false;
      }
    }
    return true;
  }
  return false;
}

bool _looksLikeLineWrappedBase64(String value) {
  final lines =
      value.split(RegExp(r'\r\n|\n|\r')).map((line) => line.trim()).toList();
  if (lines.length < 2 ||
      lines.any(
        (line) =>
            line.isEmpty || !RegExp(r'^[A-Za-z0-9+/_=-]+$').hasMatch(line),
      ) ||
      lines.take(lines.length - 1).any((line) => line.length % 4 != 0)) {
    return false;
  }
  final encoded = lines.join();
  if (encoded.length < 32 ||
      !RegExp(r'^[A-Za-z0-9+/_=-]+$').hasMatch(encoded)) {
    return false;
  }
  try {
    return base64.decode(base64.normalize(encoded)).length >= 24;
  } on FormatException {
    return false;
  }
}

bool _canSafelyPreserveSkippedAsrEntry(Map entry) {
  final retryData = entry['retryData'];
  if (retryData is Map &&
      (retryData.containsKey('version') ||
          retryData.containsKey('audioReference') ||
          retryData.containsKey('audioReferences'))) {
    return false;
  }
  return _canSafelyPreserveLegacyAsrRetryData(entry);
}

// ============================================================================
// Background Task Type
// ============================================================================

/// The type of background operation being tracked.
enum BackgroundTaskType {
  ocr,
  asr,
  audioSeparation,
  chat;

  String get label {
    switch (this) {
      case BackgroundTaskType.ocr:
        return '文字识别';
      case BackgroundTaskType.asr:
        return '音频转写';
      case BackgroundTaskType.audioSeparation:
        return '音频分离';
      case BackgroundTaskType.chat:
        return '助手对话';
    }
  }

  String localizedLabel(AppLocalizations strings) => switch (this) {
        BackgroundTaskType.ocr => strings.unifiedTaskTypeOcr,
        BackgroundTaskType.asr => strings.unifiedTaskTypeAsr,
        BackgroundTaskType.audioSeparation =>
          strings.unifiedTaskTypeAudioSeparation,
        BackgroundTaskType.chat => strings.unifiedTaskTypeChat,
      };

  List<String> localizedStepLabels(AppLocalizations strings) => switch (this) {
        BackgroundTaskType.ocr => [
            strings.bgStepConnectServer,
            strings.bgStepUploadImage,
            strings.bgStepWaitRecognition,
            strings.bgStepParseResult,
            strings.bgStepSaveFile,
          ],
        BackgroundTaskType.asr => [
            strings.bgStepConnectServer,
            strings.bgStepUploadAudio,
            strings.bgStepTranscribing,
            strings.bgStepReceiveResult,
            strings.bgStepSaveFile,
          ],
        BackgroundTaskType.audioSeparation => [
            strings.bgStepSeparateAudio,
            strings.bgStepSaveToFile,
          ],
        BackgroundTaskType.chat => [
            strings.bgStepSendRequest,
            strings.bgStepWaitReply,
            strings.bgStepReceiveResult,
          ],
      };

  /// Steps appropriate for each task type (used for step chain display).
  List<String> get stepLabels {
    switch (this) {
      case BackgroundTaskType.ocr:
        // OCR: single request with all images
        return ['连接服务器', '上传图片', '等待识别结果', '解析结果', '保存文件'];
      case BackgroundTaskType.asr:
        // ASR: one request per file, each file is a separate task
        return ['连接服务器', '上传音频', '转写中', '接收结果', '保存文件'];
      case BackgroundTaskType.audioSeparation:
        // Audio Separation: local processing only, no API
        return ['分离音频', '保存到文件'];
      case BackgroundTaskType.chat:
        // Chat/Assistant: API call
        return ['发送请求', '等待回复', '接收结果'];
    }
  }
}

// ============================================================================
// Step Status for Background Tasks
// ============================================================================

/// Simplified step status enum (without progress quantification).
enum BgStepStatus { pending, running, completed, failed, skipped }

String _localizeStoredBackgroundStep(String label, AppLocalizations strings) {
  final baseLabel = switch (label) {
    '连接服务器' || 'Connecting to server' => strings.bgStepConnectServer,
    '上传图片' || 'Uploading images' => strings.bgStepUploadImage,
    '等待识别结果' || 'Waiting for recognition' => strings.bgStepWaitRecognition,
    '解析结果' || 'Parsing result' => strings.bgStepParseResult,
    '保存文件' || 'Saving file' => strings.bgStepSaveFile,
    '上传音频' || 'Uploading audio' => strings.bgStepUploadAudio,
    '转写中' || 'Transcribing' => strings.bgStepTranscribing,
    '接收结果' || 'Receiving result' => strings.bgStepReceiveResult,
    '分离音频' || 'Separating audio' => strings.bgStepSeparateAudio,
    '保存到文件' || 'Saving to file' => strings.bgStepSaveToFile,
    '发送请求' || 'Sending request' => strings.bgStepSendRequest,
    '等待回复' || 'Waiting for reply' => strings.bgStepWaitReply,
    _ => null,
  };
  if (baseLabel != null) return baseLabel;

  final ocrPercent = RegExp(r'^上传图片 (\d+)%$').firstMatch(label);
  if (ocrPercent != null) {
    return strings.bgTaskOcrUploadProgress(ocrPercent.group(1)!);
  }
  final englishOcrPercent =
      RegExp(r'^Uploading images (\d+)%$').firstMatch(label);
  if (englishOcrPercent != null) {
    return strings.bgTaskOcrUploadProgress(englishOcrPercent.group(1)!);
  }
  final ocrPages = RegExp(
    r'第 (\d+)/(\d+) 张图片 (\d+)%|Image (\d+)/(\d+) (\d+)%',
  ).allMatches(label);
  if (ocrPages.isNotEmpty) {
    final details = ocrPages
        .map((match) => strings.bgTaskOcrUploadPageProgress(
              match.group(1) ?? match.group(4)!,
              match.group(2) ?? match.group(5)!,
              match.group(3) ?? match.group(6)!,
            ))
        .join(strings.localeName.startsWith('zh') ? '，' : ', ');
    return strings.bgTaskOcrUploadPagesProgress(details);
  }

  final metricMatch = RegExp(
    r' · 阶段 (\d+)ms · 请求 (\d+) · 已完成片段 (\d+)/(\d+)$|'
    r' · phase (\d+) ms · (\d+) requests · (\d+)/(\d+) chunks completed$',
  ).firstMatch(label);
  String metricValue(int localizedIndex, int englishIndex) =>
      metricMatch?.group(localizedIndex) ?? metricMatch!.group(englishIndex)!;
  final metrics = metricMatch == null
      ? ''
      : strings.bgTaskProgressMetrics(
          metricValue(1, 5),
          metricValue(2, 6),
          metricValue(3, 7),
          metricValue(4, 8),
        );
  final core =
      metricMatch == null ? label : label.substring(0, metricMatch.start);
  final upload = RegExp(
    r'^上传音频(?:（片段 (\d+)/(\d+)）)?(?: (\d+)% · (\d+) bytes)?$|'
    r'^Uploading audio(?: \(chunk (\d+)/(\d+)\))?(?: (\d+)% · (\d+) bytes)?$',
  ).firstMatch(core);
  if (upload != null) {
    final chunkIndex = upload.group(1) ?? upload.group(5);
    final chunkCount = upload.group(2) ?? upload.group(6);
    final percent = upload.group(3) ?? upload.group(7);
    final bytes = upload.group(4) ?? upload.group(8);
    final chunk = chunkIndex == null
        ? ''
        : strings.bgTaskAsrChunk(chunkIndex, chunkCount!);
    if (percent == null) {
      return strings.bgTaskAsrUploadChunk(chunk, metrics);
    }
    return strings.bgTaskAsrUploadProgress(
      chunk,
      percent,
      bytes!,
      metrics,
    );
  }
  final transcribing = RegExp(
    r'^转写中(?:（片段 (\d+)/(\d+)）)?$|'
    r'^Transcribing(?: \(chunk (\d+)/(\d+)\))?$',
  ).firstMatch(core);
  if (transcribing != null) {
    final chunkIndex = transcribing.group(1) ?? transcribing.group(3);
    final chunkCount = transcribing.group(2) ?? transcribing.group(4);
    if (chunkIndex == null) {
      return strings.bgTaskAsrTranscribing(metrics);
    }
    return strings.bgTaskAsrTranscribingChunk(
      chunkIndex,
      chunkCount!,
      metrics,
    );
  }
  final receivingChunk = RegExp(r'^转写中（接收片段 (\d+)/(\d+)）$|'
          r'^Transcribing \(receiving chunk (\d+)/(\d+)\)$')
      .firstMatch(core);
  if (receivingChunk != null) {
    return strings.bgTaskAsrReceivingChunk(
      receivingChunk.group(1) ?? receivingChunk.group(3)!,
      receivingChunk.group(2) ?? receivingChunk.group(4)!,
      metrics,
    );
  }
  final completedChunks = RegExp(r'^转写中（已完成片段 (\d+)/(\d+)）$|'
          r'^Transcribing \((\d+)/(\d+) chunks completed\)$')
      .firstMatch(core);
  if (completedChunks != null) {
    return strings.bgTaskAsrCompletedChunks(
      completedChunks.group(1) ?? completedChunks.group(3)!,
      completedChunks.group(2) ?? completedChunks.group(4)!,
      metrics,
    );
  }
  final returnedChunk = RegExp(r'^转写中（片段 (\d+)/(\d+) 已返回）$|'
          r'^Transcribing \(chunk (\d+)/(\d+) returned\)$')
      .firstMatch(core);
  if (returnedChunk != null) {
    return strings.bgTaskAsrChunkReturned(
      returnedChunk.group(1) ?? returnedChunk.group(3)!,
      returnedChunk.group(2) ?? returnedChunk.group(4)!,
      metrics,
    );
  }
  final received = RegExp(r'^接收结果(?: (\d+)%)?$|^Receiving result(?: (\d+)%)?$')
      .firstMatch(core);
  if (received != null) {
    final percent = received.group(1) ?? received.group(2);
    return percent == null
        ? '${strings.bgTaskAsrReceive}$metrics'
        : strings.bgTaskAsrReceiveProgress(percent, metrics);
  }
  return label;
}

String? _localizeStoredBackgroundError(
  String? error,
  AppLocalizations strings,
) {
  if (error == null) return null;
  if (error == '已取消' || error == 'Canceled') return strings.bgTaskCancelled;
  if (error == 'OCR 错误详情已隐藏' || error == 'OCR error details were hidden') {
    return strings.bgTaskOcrErrorDetailsHidden;
  }
  if (error == '错误详情已隐藏' || error == 'Error details were hidden') {
    return strings.bgTaskErrorDetailsHidden;
  }
  if (error == '应用重启，已中断' || error == 'Interrupted when the app restarted') {
    return strings.bgTaskInterruptedOnRestart;
  }
  if (error == '批次中的其他音频无法保存，已取消发送' ||
      error == 'Another audio file could not be saved; sending was canceled') {
    return strings.bgTaskAsrBatchAudioSaveError;
  }
  for (final wrapper in ['Bad state: ', 'Exception: ']) {
    if (!error.startsWith(wrapper)) continue;
    final nested = _localizeStoredBackgroundError(
      error.substring(wrapper.length),
      strings,
    );
    if (nested != error.substring(wrapper.length)) return '$wrapper$nested';
  }
  final incompleteDetail = _localizeStoredOcrIncompleteDetail(error, strings);
  if (incompleteDetail != error) return incompleteDetail;
  for (final (prefix, localize) in <(String, String Function(String))>[
    for (final prefix in [
      '音频转写失败: ',
      '音频转写失败：',
      'Speech transcription failed: ',
    ])
      (prefix, strings.bgTaskAsrError),
    for (final prefix in [
      '音频转写结果保存失败: ',
      '音频转写结果保存失败：',
      'Saving speech transcription failed: ',
    ])
      (prefix, strings.bgTaskAsrSaveError),
    for (final prefix in ['OCR识别失败: ', 'OCR识别失败：', 'OCR failed: '])
      (prefix, strings.bgTaskOcrError),
    for (final prefix in [
      'OCR结果保存失败: ',
      'OCR结果保存失败：',
      'Saving OCR results failed: ',
    ])
      (prefix, strings.bgTaskOcrSaveError),
    for (final prefix in [
      '无法保存 ASR 重试音频，任务未发送: ',
      '无法保存 ASR 重试音频，任务未发送：',
      'Could not save ASR retry audio; the task was not sent: ',
    ])
      (prefix, strings.bgTaskAsrRetryAudioSaveError),
    for (final prefix in [
      'ASR 分段恢复记录写入失败；当前请求结果可能不确定，任务已停止: ',
      'ASR 分段恢复记录写入失败；当前请求结果可能不确定，任务已停止：',
      'ASR recovery checkpoint could not be saved; the request outcome is uncertain and the task was stopped: ',
    ])
      (prefix, strings.bgTaskAsrCheckpointUncertain),
    for (final prefix in [
      'ASR 分段恢复记录写入失败；该片段尚未发送，可修复本地存储后重试: ',
      'ASR 分段恢复记录写入失败；该片段尚未发送，可修复本地存储后重试：',
      'ASR recovery checkpoint could not be saved; this chunk was not sent and can be retried after fixing local storage: ',
    ])
      (prefix, strings.bgTaskAsrCheckpointNotSent),
    for (final prefix in [
      'ASR 取消前的分段状态写入失败；该片段仍按结果不确定处理: ',
      'ASR 取消前的分段状态写入失败；该片段仍按结果不确定处理：',
      'ASR chunk state could not be saved before cancellation; this chunk outcome remains uncertain: ',
    ])
      (prefix, strings.bgTaskAsrCheckpointCancelled),
  ]) {
    if (error.startsWith(prefix)) {
      final detail = error.substring(prefix.length);
      return localize(
          _localizeStoredBackgroundError(detail, strings) ?? detail);
    }
  }
  for (final prefix in [
    'OCR结果不完整: ',
    'OCR结果不完整：',
    'OCR result is incomplete: ',
  ]) {
    if (!error.startsWith(prefix)) continue;
    final details = _localizeStoredOcrIncompleteDetail(
      error.substring(prefix.length),
      strings,
    );
    return strings.bgTaskOcrIncompleteError(details);
  }
  return error;
}

String _localizeStoredOcrIncompleteDetail(
  String detail,
  AppLocalizations strings,
) {
  final summary = _localizeStoredOcrPageFailureSummary(detail, strings);
  if (summary != null) return summary;
  const exceptionPrefix = 'Exception: ';
  if (detail.startsWith(exceptionPrefix)) {
    final nested = _localizeStoredOcrIncompleteDetail(
      detail.substring(exceptionPrefix.length),
      strings,
    );
    if (nested != detail.substring(exceptionPrefix.length)) {
      return '$exceptionPrefix$nested';
    }
  }
  for (final prefix in [
    'OCR 返回了不完整结果（finish_reason=',
    'OCR returned an incomplete result (finish_reason=',
  ]) {
    if (!detail.startsWith(prefix)) continue;
    final closing = prefix.startsWith('OCR 返回') ? '）' : ')';
    if (!detail.endsWith(closing)) return detail;
    final finishReason = detail.substring(prefix.length, detail.length - 1);
    return strings.bgTaskOcrResultIncomplete(finishReason);
  }
  return detail;
}

String? _localizeStoredOcrPageFailureSummary(
  String error,
  AppLocalizations strings,
) {
  for (final prefix in [
    '部分图片 OCR 未完成：',
    'Some images were not fully recognized: ',
  ]) {
    if (!error.startsWith(prefix)) continue;
    final details = error.substring(prefix.length);
    final pageFailures = RegExp(
      r'第 (\d+) 张图片(结果不完整|识别失败)|'
      r'Image (\d+): (incomplete result|recognition failed)',
    );
    final matches = pageFailures.allMatches(details).toList();
    final unmatched = details
        .replaceAll(pageFailures, '')
        .replaceAll(RegExp(r'[；，;, ]+'), '');
    if (matches.isEmpty || unmatched.isNotEmpty) return error;
    final localizedDetails = matches.map((match) {
      final index = match.group(1) ?? match.group(3)!;
      final incomplete =
          match.group(2) == '结果不完整' || match.group(4) == 'incomplete result';
      return incomplete
          ? strings.bgTaskOcrPageIncomplete(index)
          : strings.bgTaskOcrPageFailed(index);
    }).join(strings.bgTaskOcrPageFailureSeparator);
    return strings.bgTaskOcrPagesIncomplete(localizedDetails);
  }
  return null;
}

BackgroundTask _localizeRestoredBackgroundTask(
  BackgroundTask task,
  AppLocalizations strings,
) {
  final error = _localizeStoredBackgroundError(task.error, strings);
  var changed = error != task.error;
  final steps = task.steps.map((step) {
    final label = _localizeStoredBackgroundStep(step.label, strings);
    final stepError = _localizeStoredBackgroundError(step.error, strings);
    if (label != step.label || stepError != step.error) changed = true;
    return step.copyWith(label: label, error: stepError);
  }).toList(growable: false);
  final outcomes = task.ocrPageOutcomes.map((outcome) {
    final outcomeError = _localizeStoredBackgroundError(outcome.error, strings);
    if (outcomeError != outcome.error) changed = true;
    return OcrPageOutcome(
      imageIndex: outcome.imageIndex,
      status: outcome.status,
      text: outcome.text,
      error: outcomeError,
    );
  }).toList(growable: false);
  if (!changed) {
    return task;
  }
  return task.copyWith(error: error, steps: steps, ocrPageOutcomes: outcomes);
}

/// A single step in a background task's step chain.
/// No progress bar — just shows status: pending, running, completed, failed, or skipped.
class BgTaskStep {
  final String label;
  final BgStepStatus status;
  final String? error;

  const BgTaskStep({
    required this.label,
    this.status = BgStepStatus.pending,
    this.error,
  });

  bool get completed => status == BgStepStatus.completed;
  bool get running => status == BgStepStatus.running;
  bool get failed => status == BgStepStatus.failed;
  bool get skipped => status == BgStepStatus.skipped;

  BgTaskStep copyWith({
    BgStepStatus? status,
    String? error,
    bool clearError = false,
    String? label,
  }) =>
      BgTaskStep(
        label: label ?? this.label,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'status': status.name,
        if (error != null) 'error': error,
      };

  factory BgTaskStep.fromMap(Map<String, dynamic> map) => BgTaskStep(
        label: map['label'] as String,
        status:
            BgStepStatus.values.byName(map['status'] as String? ?? 'pending'),
        error: map['error'] as String?,
      );
}

// ============================================================================
// Background Task Model
// ============================================================================

Map<String, dynamic>? _sanitizeOcrTaskRequest(
  Map<String, dynamic>? rawRequest, {
  Iterable<String> additionalCredentialValues = const [],
}) {
  final credentialValues = <String>{
    ..._legacyOcrCredentialValues(rawRequest),
    ...additionalCredentialValues,
  }.toList();
  Map<String, dynamic>? safeSource = _removeMaskedOcrDiagnosticValues(
    rawRequest,
    credentialValues,
  );
  final endpoint = safeSource?['host'] ?? safeSource?['url'];
  if (endpoint is String &&
      _legacyOcrTextContainsCredential(endpoint, credentialValues)) {
    safeSource = Map<String, dynamic>.from(safeSource!)
      ..remove('host')
      ..remove('url');
  }
  return OcrDiagnosticSnapshot.sanitizeRequest(
    safeSource,
    excludedValues: credentialValues,
  );
}

Map<String, dynamic>? _sanitizeOcrTaskResponse(
  Map<String, dynamic>? rawResponse,
  Map<String, dynamic>? rawRequest, {
  Iterable<String> additionalCredentialValues = const [],
}) {
  final credentialValues = <String>{
    ..._legacyOcrCredentialValues(rawRequest),
    ...additionalCredentialValues,
  }.toList();
  final safeSource = _removeMaskedOcrDiagnosticValues(
    rawResponse,
    credentialValues,
    includeResponseData: true,
  );
  return OcrDiagnosticSnapshot.sanitizeResponse(
    safeSource,
    excludedValues: credentialValues,
  );
}

Map<String, dynamic>? _removeMaskedOcrDiagnosticValues(
  Map<String, dynamic>? source,
  Iterable<String> credentialValues, {
  bool includeResponseData = false,
}) {
  if (source == null) return null;
  final safeSource = Map<String, dynamic>.from(source);
  bool matchesMaskedCredential(dynamic value) =>
      value is String &&
      _legacyOcrTextContainsMaskedCredential(value, credentialValues);

  for (final field in ['requestId', 'finishReason', 'finish_reason']) {
    if (matchesMaskedCredential(safeSource[field])) safeSource.remove(field);
  }

  final headers = safeSource['headers'];
  if (headers is Map) {
    final safeHeaders = Map<dynamic, dynamic>.from(headers);
    for (final entry in headers.entries) {
      if (entry.key is! String) continue;
      final requestId = OcrDiagnosticSnapshot.requestIdFromHeaders({
        entry.key: entry.value,
      });
      if (requestId != null && matchesMaskedCredential(requestId)) {
        safeHeaders.remove(entry.key);
      }
    }
    safeSource['headers'] = safeHeaders;
  }

  final data = safeSource['data'];
  if (includeResponseData && data is Map) {
    final safeData = Map<dynamic, dynamic>.from(data);
    for (final field in ['request_id', 'requestId', 'id']) {
      if (matchesMaskedCredential(safeData[field])) safeData.remove(field);
    }
    final choices = safeData['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final firstChoice = Map<dynamic, dynamic>.from(choices.first as Map);
      if (matchesMaskedCredential(firstChoice['finish_reason'])) {
        firstChoice.remove('finish_reason');
        final safeChoices = List<dynamic>.from(choices)..[0] = firstChoice;
        safeData['choices'] = safeChoices;
      }
    }
    safeSource['data'] = safeData;
  }
  return safeSource;
}

String? _sanitizeOcrTaskError(
  String? error,
  Map<String, dynamic>? rawRequest, {
  Iterable<String> additionalCredentialValues = const [],
}) {
  final credentialValues = <String>{
    ..._legacyOcrCredentialValues(rawRequest),
    ...additionalCredentialValues,
  }.toList();
  if (error != null) {
    for (final locale in [const Locale('en', 'US'), const Locale('zh', 'CN')]) {
      final strings = lookupAppLocalizations(locale);
      for (final prefix in [
        strings.bgTaskOcrError(''),
        strings.bgTaskOcrSaveError(''),
        strings.bgTaskOcrIncompleteError(''),
      ]) {
        if (!error.startsWith(prefix)) continue;
        if (_legacyOcrTextContainsCredential(prefix, credentialValues)) {
          return _localizedOcrHiddenTaskError(strings, credentialValues);
        }
        final details = error.substring(prefix.length);
        final sanitizedDetails = OcrDiagnosticSnapshot.sanitizeStoredTaskError(
          details,
          excludedValues: credentialValues,
        );
        const hiddenDetailsPrefix = 'OCR 错误详情已隐藏';
        final localizedHiddenDetails =
            _localizedOcrHiddenTaskError(strings, credentialValues);
        final safeDetails =
            sanitizedDetails?.startsWith(hiddenDetailsPrefix) == true
                ? sanitizedDetails!.replaceFirst(
                    hiddenDetailsPrefix,
                    localizedHiddenDetails,
                  )
                : sanitizedDetails;
        return '$prefix${safeDetails ?? ''}';
      }
    }
  }
  if (error != null &&
      _legacyOcrTextContainsMaskedCredential(error, credentialValues)) {
    return 'OCR 错误详情已隐藏';
  }
  return OcrDiagnosticSnapshot.sanitizeStoredTaskError(
    error,
    excludedValues: credentialValues,
  );
}

String _localizedOcrHiddenTaskError(
  AppLocalizations strings,
  Iterable<String> credentialValues,
) {
  for (final candidate in [
    strings.bgTaskOcrErrorDetailsHidden,
    strings.bgTaskErrorDetailsHidden,
    '…',
  ]) {
    if (!_legacyOcrTextContainsCredential(candidate, credentialValues)) {
      return candidate;
    }
  }
  return '';
}

Iterable<String> _combinedOcrCredentialValues(
  Iterable<String> diagnosticValues,
  Iterable<String> sanitizationValues,
) sync* {
  yield* diagnosticValues;
  yield* sanitizationValues;
}

Map<String, dynamic> _unavailableOcrRetryData(
  String taskId,
  OcrRetrySnapshot snapshot,
) =>
    OcrRetryStorage.unavailableSnapshot(taskId: taskId, snapshot: snapshot);

const _maxRecoverableLegacyOcrImageCount = 1000;

int? _legacyOcrImageCount(Map<String, dynamic>? rawRequest) {
  if (rawRequest == null) return null;
  final storedCount = rawRequest['imageCount'];
  if (storedCount is int &&
      storedCount > 0 &&
      storedCount <= _maxRecoverableLegacyOcrImageCount) {
    return storedCount;
  }

  final body = rawRequest['body'];
  if (body is! Map || body['messages'] is! List) return null;
  var imageCount = 0;
  for (final message in body['messages'] as List) {
    if (message is! Map || message['content'] is! List) continue;
    for (final part in message['content'] as List) {
      if (part is Map &&
          (part['type'] == 'image_url' ||
              part['type'] == 'image' ||
              part.containsKey('image_url'))) {
        imageCount++;
      }
    }
  }
  return imageCount > 0 && imageCount <= _maxRecoverableLegacyOcrImageCount
      ? imageCount
      : null;
}

String? _legacyOcrModelId(Map<String, dynamic>? rawRequest) {
  final body = rawRequest?['body'];
  final modelId = body is Map ? body['model'] : null;
  if (modelId is! String) return null;
  final value = modelId.trim();
  final credentialValues = _legacyOcrCredentialValues(rawRequest).toList();
  return _isSafeOcrModelId(value, credentialValues) ? value : null;
}

bool _isSafeOcrModelId(String value, Iterable<String> credentialValues) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:/-]{0,127}$').hasMatch(value) &&
    !RegExp(
      r'^(?:sk-(?:proj-|ant-api\d{2}-|or-v1-)?[a-z0-9]{8,}|gsk_[a-z0-9]{8,}|gh[pousr]_[a-z0-9]{8,}|AIza[a-z0-9_-]{20,})$',
      caseSensitive: false,
    ).hasMatch(value) &&
    !_legacyOcrTextContainsCredential(value, credentialValues);

Iterable<String> _legacyOcrCredentialValues(Map<String, dynamic>? rawRequest) =>
    OcrDiagnosticSnapshot.credentialValuesFromRequest(rawRequest);

bool _legacyOcrIsOrdinaryTerminalReadCarefullyPrompt(
  String text,
  Iterable<String> credentialValues,
) {
  if (!RegExp(
    r'^\s*please\s+read[\r\n]+\s*carefully[.!?]?\s*$',
    caseSensitive: false,
  ).hasMatch(text)) {
    return false;
  }
  return credentialValues.any((value) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis == null || value.substring(ellipsis.end).isNotEmpty) {
      return false;
    }
    final prefix =
        value.substring(0, ellipsis.start).trim().split(RegExp(r'\s+')).last;
    return prefix.toLowerCase() == 'read';
  });
}

bool _legacyOcrTextContainsCredential(
  String text,
  Iterable<String> credentialValues,
) {
  if (OcrDiagnosticSnapshot.containsCredential(
    text,
    excludedValues: credentialValues.where(
      (value) => !value.trimRight().endsWith('...'),
    ),
  )) {
    return true;
  }
  if (_legacyOcrHasWhitespaceSplitMaskedDocumentationEcho(
    text,
    credentialValues,
  )) {
    return true;
  }
  return _legacyOcrTextContainsMaskedCredential(text, credentialValues);
}

bool _legacyOcrHasWhitespaceSplitMaskedDocumentationEcho(
  String text,
  Iterable<String> credentialValues,
) {
  for (final value in credentialValues) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis == null || value.substring(ellipsis.end).isNotEmpty) continue;
    final prefix =
        value.substring(0, ellipsis.start).trim().split(RegExp(r'\s+')).last;
    if (prefix.toLowerCase() != 'documentation') continue;
    final pattern = RegExp(
      r'(^|[^a-zA-Z0-9])'
      r'[dD][oO][cC][uU][mM][eE][nN][tT][aA][tT][iI][oO][nN]'
      r'[ \t\r\n]+'
      r'([a-zA-Z0-9_./+=~-]+(?:[ \t\r\n]+[a-zA-Z0-9_./+=~-]+)*)'
      r'(?=$|[^a-zA-Z0-9_])',
      caseSensitive: true,
    );
    for (final match in pattern.allMatches(text)) {
      final naturalPromptLength =
          _legacyOcrNaturalReadDocumentationBlueprintPromptLength(
        text.substring(0, match.start),
        match.group(2)!,
      );
      final echoSuffix = naturalPromptLength == null
          ? match.group(2)!
          : match.group(2)!.substring(naturalPromptLength);
      if (_legacyOcrMaskedDocumentationCredentialEchoLength(
            echoSuffix,
            value,
          ) >
          0) {
        return true;
      }
    }
  }
  return false;
}

int? _legacyOcrNaturalReadDocumentationBlueprintPromptLength(
  String before,
  String suffix,
) {
  if (!RegExp(r'\bread\s+the\s*$', caseSensitive: false).hasMatch(before)) {
    return null;
  }
  return RegExp(r'^\s*blueprints\b', caseSensitive: false)
      .firstMatch(suffix)
      ?.end;
}

int _legacyOcrMaskedDocumentationCredentialEchoLength(
  String suffix,
  String maskedValue,
) {
  final chunks = RegExp(r'\S+').allMatches(suffix).toList();
  var compactSuffix = '';
  var credentialEnd = 0;
  for (var chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
    final chunk = chunks[chunkIndex];
    final token = chunk.group(0)!.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
    if (token.isEmpty) break;
    final alphaCount = RegExp(r'[a-zA-Z]').allMatches(token).length;
    final hasExplicitMarker = alphaCount >= 4 &&
        (RegExp(r'[-_./+=~]').hasMatch(token) ||
            (token.length >= 8 && RegExp(r'[0-9]').hasMatch(token)));
    final normalizedToken = token.toLowerCase();
    final isNaturalContinuation = RegExp(
          r'(?:ly|ing|ed|er|est|able|ary|aries|ation|ize|ise|ization|istic|based)$',
        ).hasMatch(normalizedToken) ||
        RegExp(
          r'^(?:and|but|or|then|while|because|although|please|print|read|review|'
          r'the|a|an|in|to|for|with|instructions?|ocr)$',
          caseSensitive: false,
        ).hasMatch(token);
    if (isNaturalContinuation) break;
    if (credentialEnd > 0) {
      final hasNumericCredentialContinuation =
          RegExp(r'^\d{3,}$').hasMatch(token) &&
              RegExp(r'[0-9]').hasMatch(compactSuffix);
      final hasStrongContinuationShape = hasExplicitMarker ||
          hasNumericCredentialContinuation ||
          (RegExp(r'^[A-Z]{5,}$').hasMatch(token) &&
              _legacyOcrHasHighAlphabeticEntropy(
                token.toLowerCase(),
                minimumLength: 5,
                minimumEntropy: 2,
                maximumVowelRatio: 0.2,
              )) ||
          (RegExp(r'^[a-z]{7,}$').hasMatch(token) &&
              _legacyOcrHasHighAlphabeticEntropy(
                token,
                minimumLength: 7,
                minimumEntropy: 2.8,
                maximumVowelRatio: 0.3,
              ));
      if (!hasStrongContinuationShape) break;
      final extendedSuffix = '$compactSuffix$token';
      if (!_legacyOcrTextContainsMaskedCredential(
        'documentation$extendedSuffix',
        [maskedValue],
      )) {
        break;
      }
      compactSuffix = extendedSuffix;
      credentialEnd = chunk.start + token.length;
      continue;
    }
    final hasStrongInitialCredentialShape = hasExplicitMarker ||
        (RegExp(r'^[a-z]{8,}$').hasMatch(token) &&
            _legacyOcrHasHighAlphabeticEntropy(
              token,
              minimumLength: 8,
              minimumEntropy: 3,
              maximumVowelRatio: 0.34,
            )) ||
        RegExp(r'^[a-z]{6,}xyz$').hasMatch(token) ||
        (RegExp(r'^[A-Z]{6,}$').hasMatch(token) &&
            _legacyOcrHasHighAlphabeticEntropy(
              token.toLowerCase(),
              minimumLength: 6,
              minimumEntropy: 2,
              maximumVowelRatio: 0.4,
            ));
    if (!hasStrongInitialCredentialShape) {
      if (chunkIndex + 1 < chunks.length) {
        final nextChunk = chunks[chunkIndex + 1];
        final nextToken =
            nextChunk.group(0)!.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
        final combinedToken = '$token$nextToken';
        if (RegExp(r'^[a-z]{6,}xyz$').hasMatch(combinedToken) &&
            _legacyOcrTextContainsMaskedCredential(
              'documentation$combinedToken',
              [maskedValue],
            )) {
          compactSuffix = combinedToken;
          credentialEnd = nextChunk.start + nextToken.length;
          chunkIndex++;
          continue;
        }
      }
      break;
    }
    compactSuffix += token;
    if (_legacyOcrTextContainsMaskedCredential(
      'documentation$compactSuffix',
      [maskedValue],
    )) {
      credentialEnd = chunk.start + token.length;
    }
  }
  return credentialEnd;
}

bool _legacyOcrHasAscendingAlphabetRun(String value) {
  final normalized = value.toLowerCase();
  var runLength = 1;
  for (var index = 1; index < normalized.length; index++) {
    final previous = normalized.codeUnitAt(index - 1);
    final current = normalized.codeUnitAt(index);
    if (previous >= 97 && previous <= 121 && current == previous + 1) {
      runLength++;
      if (runLength >= 5) return true;
    } else {
      runLength = 1;
    }
  }
  return false;
}

bool _legacyOcrHasHighAlphabeticEntropy(
  String value, {
  int minimumLength = 9,
  double minimumEntropy = 3.3,
  double maximumVowelRatio = 1,
  bool allowUnicodeLetterMarks = false,
}) {
  final normalized = value.toLowerCase();
  final letters = allowUnicodeLetterMarks
      ? normalized.runes.toList()
      : normalized.codeUnits;
  final isAlphabetic = allowUnicodeLetterMarks
      ? RegExp(r'^[\p{L}\p{M}]+$', unicode: true).hasMatch(normalized) &&
          RegExp(r'\p{L}', unicode: true).hasMatch(normalized)
      : RegExp(r'^[a-z]+$').hasMatch(normalized);
  if (letters.length < minimumLength || !isAlphabetic) {
    return false;
  }

  final frequencies = <int, int>{};
  for (final letter in letters) {
    frequencies.update(letter, (count) => count + 1, ifAbsent: () => 1);
  }

  var entropy = 0.0;
  for (final count in frequencies.values) {
    final probability = count / letters.length;
    entropy -= probability * math.log(probability) / math.ln2;
  }
  final vowelCount = RegExp(r'[aeiou]').allMatches(normalized).length;
  final vowelRatio = vowelCount / letters.length;
  return (letters.length == 9 && entropy >= 3.1 && vowelRatio <= 0.25) ||
      (entropy >= minimumEntropy && vowelRatio <= maximumVowelRatio) ||
      (entropy >= 3.0 && vowelRatio <= 0.15);
}

bool _legacyOcrHasShortOpaqueAlphaKey(String value) =>
    _legacyOcrHasHighAlphabeticEntropy(
      value,
      minimumLength: 8,
      minimumEntropy: 2.7,
      maximumVowelRatio: 0.1,
    );

bool _legacyOcrHasLongConsonantRun(String value) =>
    RegExp(r'[bcdfghjklmnpqrstvwxz]{6,}', caseSensitive: false).hasMatch(value);

bool _legacyOcrHasShortOpaqueUnicodeContinuation(
  String prefix,
  String suffix,
) =>
    prefix.length >= 2 &&
    RegExp(r'^\p{L}+$', unicode: true).hasMatch(suffix) &&
    (suffix.runes.where((rune) => rune > 0x7F).length >= 2 ||
        (suffix.runes.where((rune) => rune > 0x7F).length == 1 &&
            RegExp(r'[-_0-9]').hasMatch(prefix)));

bool _legacyOcrHasOpaqueUnicodeContinuation(String prefix, String suffix) =>
    !_legacyOcrHasNaturalWordContinuation(prefix, suffix) &&
    RegExp(r'[^\x00-\x7F]').hasMatch(suffix) &&
    RegExp(r'^\p{L}', unicode: true).hasMatch(suffix) &&
    (_legacyOcrHasShortOpaqueUnicodeContinuation(prefix, suffix) ||
        _legacyOcrHasShortOpaqueAlphaKey(prefix) ||
        _legacyOcrHasHighAlphabeticEntropy(
          prefix,
          minimumLength: 6,
          minimumEntropy: 2.5,
          maximumVowelRatio: 0.1,
        ) ||
        (_legacyOcrHasHighAlphabeticEntropy(
              prefix,
              minimumLength: 8,
              minimumEntropy: 3.0,
              maximumVowelRatio: 0.6,
            ) &&
            !_legacyOcrHasNaturalWordContinuation(prefix, suffix)) ||
        RegExp(r'[0-9_]').hasMatch(prefix) ||
        prefix.toLowerCase() == 'auth' ||
        (_legacyOcrHasCredentialWord(prefix) &&
            !_legacyOcrHasNaturalWordContinuation(prefix, suffix)));

bool _legacyOcrHasRepeatedAlphabeticSequence(String value) =>
    RegExp(r'([a-z]{2,3})\1{2,}', caseSensitive: false).hasMatch(value);

bool _legacyOcrHasRepeatedCharacterRun(String value) =>
    RegExp(r'([a-z])\1{3,}', caseSensitive: false).hasMatch(value);

bool _legacyOcrHasCredentialWord(String value) => RegExp(
      r'^[^a-zA-Z0-9]*(?:secret|token|credential|password|passwd|api[-_]?key|access[-_]?token|private[-_]?key)',
      caseSensitive: false,
    ).hasMatch(value);

bool _legacyOcrIsCredentialWord(String value) => RegExp(
      r'^(?:secrets?|secretar(?:y|ies)|tokens?|tokenizings?|tokenizations?|credentials?|credentialings?|passwords?|passwds?|authorizations?|authenticates?|authentications?|api[-_]?keys?|access[-_]?tokens?|private[-_]?keys?)$',
      caseSensitive: false,
    ).hasMatch(value);

bool _legacyOcrHasCredentialCompound(String value) => RegExp(
      r'^[^a-zA-Z0-9]*(?:secret|access|private|api)[_-]?(?:key|token|credential|password|passwd)(?:$|[^a-zA-Z0-9])',
      caseSensitive: false,
    ).hasMatch(value);

bool _legacyOcrHasNaturalAlphaContinuation(String value) => RegExp(
      r'^(?:s|es|ed|ing|er|est|ly|able|ary|aries|ation|ization|istic|based)$',
      caseSensitive: false,
    ).hasMatch(value);

bool _legacyOcrHasNaturalWordContinuation(String prefix, String suffix) {
  if (RegExp(r'[\p{N}_]', unicode: true).hasMatch(suffix)) return false;

  final unicodeWord = '$prefix$suffix'
      .replaceAll(RegExp(r'[^\p{L}\p{M}]', unicode: true), '')
      .toLowerCase();
  if (const {
    'authenticité',
    'authenticite\u0301',
    'cañón',
    'secretaría',
    'secretária',
  }.contains(unicodeWord)) {
    return true;
  }
  final word =
      '$prefix$suffix'.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
  const naturalWords = {
    'abstraction',
    'abstractionism',
    'accommodate',
    'application',
    'apiculture',
    'architecture',
    'authbased',
    'author',
    'authoring',
    'authorship',
    'authorships',
    'authoritative',
    'authorities',
    'authoritarian',
    'authoritarianism',
    'authoritarianisms',
    'authority',
    'authentic',
    'authenticity',
    'authenticate',
    'authenticating',
    'authentication',
    'authenticator',
    'authenticators',
    'authorize',
    'authorizing',
    'authorized',
    'recognize',
    'bookkeeper',
    'calculate',
    'categorize',
    'certificate',
    'characteristic',
    'characteristics',
    'characterization',
    'characterizations',
    'characterize',
    'characters',
    'configuration',
    'data',
    'description',
    'enumerate',
    'construction',
    'cooperate',
    'transaction',
    'authorization',
    'obfuscated',
    'photograph',
    'documentaries',
    'documentary',
    'documented',
    'documenting',
    'documentation',
    'documentbased',
    'documents',
    'credentials',
    'determine',
    'credentialing',
    'instruction',
    'instructional',
    'interaction',
    'interactions',
    'interpret',
    'highlight',
    'handwriting',
    'handwritten',
    'messages',
    'myprojectmanagement',
    'passwords',
    'passwordless',
    'passwordprotected',
    'projectbased',
    'preliminary',
    'purchases',
    'services',
    'secretary',
    'secrete',
    'secretion',
    'secretariat',
    'secretarial',
    'secretbased',
    'secretive',
    'secretmenu',
    'summarize',
    'translate',
    'transcribe',
    'tokenize',
    'tokenization',
    'tokenomics',
    'tokenizers',
    'tokenized',
    'tokenizing',
    'tokens',
    'tokenbased',
    'thoughtful',
    'understand',
    'userinterface',
  };
  final suffixWithoutTerminalPunctuation = suffix.replaceFirst(
    RegExp(r'''[.,!?;:)}\]"'“”‘’`]+$'''),
    '',
  );
  final isNaturalPossessiveSuffix = RegExp(
    r"^[a-zA-Z]*['’]s$",
  ).hasMatch(suffixWithoutTerminalPunctuation);
  final hasNonNaturalSeparator = suffixWithoutTerminalPunctuation.isNotEmpty &&
      !RegExp(r'^[a-zA-Z]+$').hasMatch(suffixWithoutTerminalPunctuation) &&
      !isNaturalPossessiveSuffix;
  final isKnownNaturalHyphenatedWord =
      (suffixWithoutTerminalPunctuation.toLowerCase() == '-based' ||
              (prefix.toLowerCase() == 'secret' &&
                  suffixWithoutTerminalPunctuation.toLowerCase() == '-menu') ||
              (prefix.toLowerCase() == 'password' &&
                  suffixWithoutTerminalPunctuation.toLowerCase() ==
                      '-protected')) &&
          naturalWords.contains(word);
  final hasCredentialWordPrefix =
      prefix.toLowerCase() == 'auth' || _legacyOcrHasCredentialWord(prefix);
  if (hasCredentialWordPrefix &&
      hasNonNaturalSeparator &&
      !isKnownNaturalHyphenatedWord) {
    return false;
  }
  return naturalWords.contains(word) ||
      (word.endsWith('s') &&
          naturalWords.contains(word.substring(0, word.length - 1)));
}

bool _legacyOcrCanRedactShortNaturalWordEcho(String word) =>
    const {'documentation', 'obfuscated'}.contains(word);

bool _legacyOcrIsNaturalReadCharacterPrompt(
        String naturalWord, String before) =>
    const {
      'characteristic',
      'characteristics',
      'characterization',
      'characterizations',
    }.contains(naturalWord) &&
    RegExp(
      r'\b(?:please\s+)?read(?:\s+the)?\s*$',
      caseSensitive: false,
    ).hasMatch(before);

final _legacyOcrNaturalSourcePhrasePattern = RegExp(
  r'^\s*from (?:(?:the|this|that|these|those|a|an|my|your|our|their|his|her|its) )?(?!(?:(?:authorization|auth|api[\s_-]*key|keys?|credentials?|tokens?|secrets?|passwords?)(?=\s+(?:header|value|keys?|credentials?|tokens?|secrets?|passwords?|bearer)\b|\s*[,;:.!?]|$))\b)[\p{L}\p{M}\p{N}]+(?:[-_][\p{L}\p{M}\p{N}]+)*(?:\s+(?!(?:(?:authorization|auth|api[\s_-]*key|keys?|credentials?|tokens?|secrets?|passwords?)(?=\s+(?:header|value|keys?|credentials?|tokens?|secrets?|passwords?|bearer)\b|\s*[,;:.!?]|$))\b)[\p{L}\p{M}\p{N}]+(?:[-_][\p{L}\p{M}\p{N}]+)*)*(?=\s*[,;:.!?]|\s*$)',
  caseSensitive: false,
  unicode: true,
);

bool _legacyOcrHasCredentialUseContext(
  String text,
  Match match,
  String prefix,
  String suffix,
) =>
    _legacyOcrHasCredentialUseContextAt(
      text,
      match.start,
      match.end,
      match.group(0)!,
      prefix,
      suffix,
    );

bool _legacyOcrHasCredentialUseContextAt(
  String text,
  int matchStart,
  int matchEnd,
  String matchedText,
  String prefix,
  String suffix,
) {
  final before = text.substring(0, matchStart).trimRight();
  final after = text.substring(matchEnd).trimLeft();
  final actionVerb = RegExp(
    r'\b(use|using|send|provide|enter|supply|pass|set|read|extract|identify|recognize|transcribe)$',
    caseSensitive: false,
  ).firstMatch(before);
  final credentialTargetAfterConsumedConnector =
      const {'as', 'to'}.contains(suffix.toLowerCase()) &&
          RegExp(
            r'^(?:(?:the|a|an|my|your|our|their|his|her|its) )?(?:(?:api|access|private|oidc|openid\s+connect|oauth(?:\s*[0-9]+(?:\.[0-9]+)*)?|secret|temporary|bearer) )*(?:authorization|auth|keys?|credentials?|tokens?|secrets?|passwords?)\b',
            caseSensitive: false,
          ).hasMatch(after);
  final explicitCredentialTarget = RegExp(
        r'^as (?:(?:the|a|an|my|your|our|their|his|her|its) )?(?:(?:api|access|private|oidc|openid\s+connect|oauth(?:\s*[0-9]+(?:\.[0-9]+)*)?|secret|temporary|bearer) )*(?:authorization|auth|keys?|credentials?|tokens?|secrets?|passwords?)\b',
        caseSensitive: false,
      ).hasMatch(after) ||
      credentialTargetAfterConsumedConnector;
  final requestTargetAfterConsumedConnector = suffix.toLowerCase() == 'for' &&
      RegExp(r'^(?:the )?request\b', caseSensitive: false).hasMatch(after);
  final credentialHeaderTarget = RegExp(
    r'^(?:in(?:to)?|to|for) (?:the )?(?:authorization|auth|api[\s_-]*key|key|token|secret|credential|password)(?: header)(?: value)?\b',
    caseSensitive: false,
  ).hasMatch(after);
  final actionTarget = RegExp(
        r'^for (?:the )?request\b',
        caseSensitive: false,
      ).hasMatch(after) ||
      _legacyOcrNaturalSourcePhrasePattern.hasMatch(after) ||
      explicitCredentialTarget ||
      credentialHeaderTarget;
  final naturalWord =
      '$prefix$suffix'.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
  final matchedPrefix = RegExp(
    RegExp.escape(prefix),
    caseSensitive: false,
    unicode: true,
  ).firstMatch(matchedText);
  final absolutePrefixStart =
      matchedPrefix == null ? -1 : matchStart + matchedPrefix.start;
  final maskPrefixIsEmbedded = absolutePrefixStart > 0 &&
      RegExp(
        r'[\p{L}\p{M}\p{N}_/+~-]',
        unicode: true,
      ).hasMatch(text.substring(absolutePrefixStart - 1, absolutePrefixStart));
  final shortNaturalWordEcho = prefix.length < 8 &&
      _legacyOcrCanRedactShortNaturalWordEcho(naturalWord) &&
      !explicitCredentialTarget;
  final isNaturalContinuation = _legacyOcrHasNaturalAlphaContinuation(suffix);
  final isNaturalWordContinuation = _legacyOcrHasNaturalWordContinuation(
    prefix,
    suffix,
  );
  final useVerb = const {
    'use',
    'using',
  }.contains(actionVerb?.group(1)?.toLowerCase());
  final tokenRequestEchoContext = prefix.toLowerCase() == 'token' &&
      useVerb &&
      requestTargetAfterConsumedConnector &&
      RegExp(
        r'^\s*authorization\s*:\s*token\b',
        caseSensitive: false,
        multiLine: true,
      ).hasMatch(text);
  final bareSecretBasedUseContext = useVerb &&
      prefix.toLowerCase() == 'secret' &&
      suffix.toLowerCase() == '-based' &&
      RegExp(r'^[.!?]*$').hasMatch(after);
  final naturalReadFromSourcePrompt = isNaturalWordContinuation &&
      actionVerb?.group(1)?.toLowerCase() == 'read' &&
      _legacyOcrNaturalSourcePhrasePattern.hasMatch(after);
  final identifiedLabelContext = maskPrefixIsEmbedded &&
      !isNaturalContinuation &&
      !isNaturalWordContinuation &&
      RegExp(
        r'\b(?:extract|identify|locate|read|record|transcribe) the (?:[\p{L}\p{M}]+ )?(?:identifiers?|numbers?|ids?|values?|codes?|keys?|tokens?|passwords?|credentials?|secrets?)$',
        unicode: true,
        caseSensitive: false,
      ).hasMatch(before);
  final actionContext = !shortNaturalWordEcho &&
      !naturalReadFromSourcePrompt &&
      (credentialHeaderTarget ||
          credentialTargetAfterConsumedConnector ||
          (actionVerb != null &&
              actionTarget &&
              ((!isNaturalContinuation &&
                      (!isNaturalWordContinuation || maskPrefixIsEmbedded)) ||
                  explicitCredentialTarget ||
                  credentialHeaderTarget ||
                  (useVerb &&
                      const {'ed', 'ing'}.contains(suffix.toLowerCase())))));
  final assignmentContext = RegExp(
    r'\b(?:authorization|auth|api[\s_-]*key|key|token|secret|credential|password)(?:\s+header)?(?:\s+value)?\s*(?:is|equals|[:=])$',
    caseSensitive: false,
  ).hasMatch(before);
  final setToCredentialContext = RegExp(
    r'\bset\s+(?:(?:the|a|an|my|your|our|their|his|her|its)\s+)?(?:authorization|auth|api[\s_-]*key|key|token|secret|credential|password)(?:\s+header)?(?:\s+value)?\s+to$',
    caseSensitive: false,
  ).hasMatch(before);
  // A label's authenticity is a safe property description, not its secret value.
  final reportedValueContext = !shortNaturalWordEcho &&
      _legacyOcrHasNaturalWordContinuation(prefix, suffix) &&
      suffix.replaceAll(RegExp(r'[^a-zA-Z]'), '').length >= 4 &&
      RegExp(
        r'\b(?:says|states|reports|returns)$',
        caseSensitive: false,
      ).hasMatch(before);
  final useToProcessContext = useVerb &&
      (!_legacyOcrHasNaturalWordContinuation(prefix, suffix) ||
          maskPrefixIsEmbedded ||
          explicitCredentialTarget ||
          credentialHeaderTarget) &&
      RegExp(
        r'^to (?:process|analyze|recognize|extract|upload|download|access|authenticate|connect|send|submit|ocr|decode)\b',
        caseSensitive: false,
      ).hasMatch(after);
  final useForReceiptContext = useVerb &&
      !_legacyOcrHasNaturalWordContinuation(prefix, suffix) &&
      RegExp(r'^for (?:this|the) receipt\b', caseSensitive: false)
          .hasMatch(after);
  final terminalUseCredentialContext = useVerb &&
      !_legacyOcrHasNaturalAlphaContinuation(suffix) &&
      !_legacyOcrHasNaturalWordContinuation(prefix, suffix) &&
      after.isEmpty;
  final authenticateWithToProcessContext =
      RegExp(r'\bauthenticate with$', caseSensitive: false).hasMatch(before) &&
          (!_legacyOcrHasNaturalWordContinuation(prefix, suffix) ||
              maskPrefixIsEmbedded) &&
          RegExp(r'^to process\b', caseSensitive: false).hasMatch(after);
  return actionContext ||
      tokenRequestEchoContext ||
      bareSecretBasedUseContext ||
      assignmentContext ||
      setToCredentialContext ||
      reportedValueContext ||
      useToProcessContext ||
      useForReceiptContext ||
      terminalUseCredentialContext ||
      authenticateWithToProcessContext ||
      identifiedLabelContext;
}

bool _legacyOcrHasUncommonAlphaContinuation(String value) =>
    RegExp(r'q(?![aeiou])', caseSensitive: false).hasMatch(value) ||
    RegExp(r'^[xz](?:[^a-zA-Z0-9_].*)?$', caseSensitive: false).hasMatch(value);

bool _legacyOcrHasKeyboardSequence(String value) {
  final normalized = value.toLowerCase();
  for (final row in const ['qwertyuiop', 'asdfghjkl', 'zxcvbnm']) {
    for (var length = 5; length <= row.length; length++) {
      for (var start = 0; start + length <= row.length; start++) {
        final sequence = row.substring(start, start + length);
        if (normalized.contains(sequence) ||
            normalized.contains(sequence.split('').reversed.join())) {
          return true;
        }
      }
    }
  }
  return false;
}

bool _legacyOcrCanMatchOpenMaskPrefixWithinToken(String prefix) {
  if (prefix.length < 8) return false;
  if (RegExp(r'[-_]').hasMatch(prefix) ||
      _legacyOcrHasUncommonAlphaContinuation(prefix) ||
      _legacyOcrHasLongConsonantRun(prefix)) {
    return true;
  }
  if (prefix.length == 9) {
    return _legacyOcrHasAscendingAlphabetRun(prefix);
  }
  return _legacyOcrHasShortOpaqueAlphaKey(prefix) ||
      _legacyOcrHasHighAlphabeticEntropy(
        prefix,
        minimumLength: 10,
        minimumEntropy: 3.3,
        maximumVowelRatio: 0.45,
      );
}

bool _legacyOcrIsNaturalOAuthVersion(String value) =>
    RegExp(r'^oauth[0-9]+(?:\.[0-9]+)*$', caseSensitive: false).hasMatch(value);

bool _legacyOcrHasEmbeddedShortMaskCredential(
  String candidate,
  String prefix, {
  String? text,
  Match? match,
}) {
  if (_legacyOcrIsNaturalOAuthVersion(candidate)) return false;

  final prefixOffset = candidate.toLowerCase().indexOf(prefix.toLowerCase());
  if (prefix.length >= 8 || prefixOffset <= 0) {
    return false;
  }

  final continuation = candidate.substring(prefixOffset + prefix.length);
  final hasMixedCaseContinuation = RegExp(r'[a-z]').hasMatch(continuation) &&
      RegExp(r'[A-Z]').hasMatch(continuation);
  final hasShortMixedCaseOpaqueContinuation = continuation.length >= 5 &&
      hasMixedCaseContinuation &&
      !_legacyOcrHasNaturalWordContinuation(prefix, continuation);
  final hasShortUncommonAlphaContinuation = continuation.length >= 5 &&
      _legacyOcrHasUncommonAlphaContinuation(continuation) &&
      !_legacyOcrHasNaturalWordContinuation(prefix, continuation);
  final hasShortKeyboardSequence = continuation.length >= 5 &&
      _legacyOcrHasKeyboardSequence(continuation) &&
      !_legacyOcrHasNaturalWordContinuation(prefix, continuation);
  final hasNumericMarker = RegExp(
    r'[\p{N}_]',
    unicode: true,
  ).hasMatch(continuation);
  final hasCredentialUseContext = text != null &&
      match != null &&
      _legacyOcrHasCredentialUseContext(text, match, prefix, continuation);
  final hasCredentialLikeContinuation =
      (hasNumericMarker && continuation.length >= 5) ||
          hasShortMixedCaseOpaqueContinuation ||
          hasShortUncommonAlphaContinuation ||
          hasShortKeyboardSequence;
  if (prefix.length < 3 &&
      (!hasCredentialUseContext || !hasCredentialLikeContinuation)) {
    return false;
  }
  final ordinaryReadInstructionsPrompt = text != null &&
      match != null &&
      _legacyOcrHasNaturalWordContinuation(prefix, continuation) &&
      RegExp(
        r'\b(?:please\s+)?read\s*$',
        caseSensitive: false,
      ).hasMatch(text.substring(0, match.start)) &&
      RegExp(
        r'^instructions?\b',
        caseSensitive: false,
      ).hasMatch(text.substring(match.end).trimLeft());
  if (ordinaryReadInstructionsPrompt && !hasCredentialUseContext) {
    return false;
  }
  if ((continuation.length < 6 &&
          !hasNumericMarker &&
          !hasCredentialUseContext &&
          !hasShortMixedCaseOpaqueContinuation &&
          !hasShortUncommonAlphaContinuation &&
          !hasShortKeyboardSequence) ||
      (prefix.length == 3 && !hasNumericMarker && !hasCredentialUseContext)) {
    return false;
  }

  final alphaToken = candidate.replaceAll(
    RegExp(r'[^\p{L}\p{M}]', unicode: true),
    '',
  );
  final hasCombiningMark = RegExp(
    r'\p{M}',
    unicode: true,
  ).hasMatch(continuation);
  return hasCredentialUseContext ||
      hasNumericMarker ||
      _legacyOcrIsCredentialWord('$prefix$continuation') ||
      hasShortMixedCaseOpaqueContinuation ||
      hasShortUncommonAlphaContinuation ||
      hasShortKeyboardSequence ||
      (hasMixedCaseContinuation &&
          _legacyOcrHasHighAlphabeticEntropy(
            alphaToken,
            minimumLength: 11,
            minimumEntropy: hasCombiningMark ? 3.2 : 3.25,
            maximumVowelRatio: 0.45,
            allowUnicodeLetterMarks: true,
          )) ||
      (!hasCombiningMark &&
          _legacyOcrHasHighAlphabeticEntropy(
            alphaToken,
            minimumLength: 11,
            minimumEntropy: 3.45,
            maximumVowelRatio: 0.45,
            allowUnicodeLetterMarks: true,
          )) ||
      _legacyOcrHasHighAlphabeticEntropy(
        alphaToken,
        minimumLength: 12,
        minimumEntropy: hasCombiningMark ? 3.2 : 3.3,
        maximumVowelRatio: 0.45,
        allowUnicodeLetterMarks: true,
      );
}

bool _legacyOcrCanBridgeLineBreakAfterOpenMaskPrefix(String prefix) =>
    RegExp(r'[-_.=/+]').hasMatch(prefix) ||
    (prefix.length >= 3 && prefix.length < 8) ||
    _legacyOcrHasShortOpaqueAlphaKey(prefix) ||
    _legacyOcrHasUncommonAlphaContinuation(prefix) ||
    _legacyOcrHasLongConsonantRun(prefix) ||
    _legacyOcrHasInterleavedAlphaNumericKeyPrefix(prefix);

bool _legacyOcrHasInterleavedAlphaNumericKeyPrefix(String prefix) {
  if (prefix.length < 8 || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(prefix)) {
    return false;
  }
  final hasLowercase = RegExp(r'[a-z]').hasMatch(prefix);
  final hasUppercase = RegExp(r'[A-Z]').hasMatch(prefix);
  final digitCount = RegExp(r'[0-9]').allMatches(prefix).length;
  if (!hasLowercase || !hasUppercase || digitCount < 2) return false;

  // Interleaved character classes distinguish generated keys from words
  // that merely end in a version or year.
  var previousClass = -1;
  var classTransitions = 0;
  for (final codeUnit in prefix.codeUnits) {
    final characterClass = codeUnit >= 48 && codeUnit <= 57
        ? 2
        : codeUnit >= 65 && codeUnit <= 90
            ? 1
            : 0;
    if (previousClass >= 0 && characterClass != previousClass) {
      classTransitions++;
    }
    previousClass = characterClass;
  }
  return classTransitions >= 3;
}

bool _legacyOcrHasCredentialUseContextAcrossLineBreak(
  String text,
  String prefix,
) {
  final splitPrefix = RegExp(
    '${_legacyOcrOpenMaskPrefixPattern(prefix)}'
    r'[\r\n]+[ \t]*(\S+)',
    caseSensitive: false,
  );
  for (final match in splitPrefix.allMatches(text)) {
    final suffix = match.group(1)!.replaceFirst(
          RegExp(r'''[.,!?;:)\]}"'“”‘’`/*=+_~—-]+$'''),
          '',
        );
    if (_legacyOcrHasCredentialUseContext(text, match, prefix, suffix)) {
      return true;
    }
  }
  return false;
}

String _legacyOcrLineBreakContinuationAfterOpenMaskPrefix(
  String prefix, {
  String? text,
}) {
  if (_legacyOcrCanBridgeLineBreakAfterOpenMaskPrefix(prefix) ||
      (text != null &&
          _legacyOcrHasCredentialUseContextAcrossLineBreak(text, prefix))) {
    return r'(?:[\r\n]+[ \t]*)?';
  }
  if (text != null &&
      _legacyOcrHasDocumentationCredentialEchoAcrossLineBreak(text, prefix)) {
    return r'(?:[\r\n]+[ \t]*(?=[a-zA-Z0-9]{4,}(?=$|[^a-zA-Z0-9])))?';
  }
  if (prefix.toLowerCase() == 'password') {
    // A common word can be a masked key prefix; only bridge a newline when
    // the following token has a mixed alphanumeric credential shape.
    return r'(?:[\r\n]+[ \t]*'
        r'(?=(?=(?:[0-9]*[a-zA-Z]){2})'
        r'(?=(?:[a-zA-Z]*[0-9]){2})'
        r'[a-zA-Z0-9]{6,}(?=$|[^a-zA-Z0-9])))?';
  }
  return '';
}

bool _legacyOcrHasDocumentationCredentialEchoAcrossLineBreak(
  String text,
  String prefix,
) {
  if (prefix.toLowerCase() != 'documentation' ||
      RegExp(
        r'^\s*please\s+review\s+(?:all\s+)?the\s+documentation[\r\n]+\s*(?:carefully|visually)[.!?]?\s*$',
        caseSensitive: false,
      ).hasMatch(text)) {
    return false;
  }
  return RegExp(
    r'\bdocumentation[\r\n]+[ \t]*[a-zA-Z0-9]{4,}(?=$|[^a-zA-Z0-9])',
  ).hasMatch(text);
}

String? _legacyOcrRedactPasswordCredentialEchoAcrossLineBreak(
  String text,
  Iterable<String> credentialValues,
) {
  for (final value in credentialValues) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis == null || value.substring(ellipsis.end).isNotEmpty) continue;
    final prefix =
        value.substring(0, ellipsis.start).trim().split(RegExp(r'\s+')).last;
    if (prefix.toLowerCase() != 'password') continue;
    final pattern = RegExp(
      '(^|[^a-zA-Z0-9])${RegExp.escape(prefix)}'
      r'[\r\n]+[ \t]*'
      r'([a-zA-Z0-9_./+=~-]{6,})(?=$|[^a-zA-Z0-9_./+=~-])',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);
    final token = match?.group(2);
    if (match != null &&
        token != null &&
        token.length >= 6 &&
        RegExp(r'[a-zA-Z]').allMatches(token).length >= 2 &&
        RegExp(r'[0-9]').allMatches(token).length >= 2) {
      return text.replaceRange(
        match.start,
        match.end,
        '${match.group(1)}[redacted]',
      );
    }
  }
  return null;
}

const _legacyOcrNaturalCarefulInstructionActions = {
  'add',
  'analyze',
  'answer',
  'calculate',
  'categorize',
  'check',
  'classify',
  'compare',
  'count',
  'copy',
  'compute',
  'decode',
  'describe',
  'determine',
  'enumerate',
  'examine',
  'explain',
  'extract',
  'find',
  'give',
  'highlight',
  'identify',
  'inspect',
  'interpret',
  'list',
  'look',
  'locate',
  'note',
  'ocr',
  'output',
  'process',
  'provide',
  'read',
  'record',
  'recognize',
  'report',
  'respond',
  'return',
  'review',
  'scan',
  'search',
  'show',
  'state',
  'subtract',
  'sum',
  'summarize',
  'tell',
  'translate',
  'transcribe',
  'verify',
  'write',
};

bool _legacyOcrIsNaturalCarefullyObjectPhrase(String prefix, String text) {
  if (!const {'read', 'check'}.contains(prefix.toLowerCase())) return false;

  final isSecretLabel = RegExp(
    r'^(?:(?:the|this|that|these|those|a|an|my|your|our|their|his|her|its)\s+)?'
    r'secret\s+label\s+carefully[.!?]?$',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(text);
  return isSecretLabel ||
      RegExp(
        r'^(?:the|this|that|these|those|a|an|my|your|our|their|his|her|its)\s+'
        r'(?!authorization\b|auth\b|api[\s_-]*key\b|keys?\b|credentials?\b|tokens?\b|secrets?\b|passwords?\b)'
        r'[\p{L}\p{M}\p{N}]+(?:[-_][\p{L}\p{M}\p{N}]+)*'
        r'(?:\s+(?!authorization\b|auth\b|api[\s_-]*key\b|keys?\b|credentials?\b|tokens?\b|secrets?\b|passwords?\b)'
        r'[\p{L}\p{M}\p{N}]+(?:[-_][\p{L}\p{M}\p{N}]+)*)*[.!?]?$',
        caseSensitive: false,
        unicode: true,
      ).hasMatch(text);
}

bool _legacyOcrHasNaturalConnectorAfterLineBreak(
  String text,
  Match match,
  String prefix,
  String suffix,
  Set<String> naturalConnectors,
) {
  if (!match.group(0)!.contains(RegExp(r'[\r\n]')) ||
      _legacyOcrHasCredentialUseContext(text, match, prefix, suffix)) {
    return false;
  }
  final followingText = text.substring(match.end).trimLeft();
  final beforeMatch = text.substring(0, match.start).trimRight();
  final ocrSourcePhrase =
      _legacyOcrNaturalSourcePhrasePattern.firstMatch(followingText);
  final sourcePhraseTail = ocrSourcePhrase == null
      ? null
      : followingText.substring(ocrSourcePhrase.end).trim();
  final sourceFollowUpAction = RegExp(
    r'^[,;:]?\s*(?:and|then)\s+(?:please\s+)?([a-z]+)\b',
    caseSensitive: false,
  ).firstMatch(sourcePhraseTail ?? followingText)?.group(1)?.toLowerCase();
  final isNaturalCarefullyObjectPhrase =
      _legacyOcrIsNaturalCarefullyObjectPhrase(prefix, followingText);
  final isReadCarefullyFromOcrSource = prefix.toLowerCase() == 'read' &&
      ocrSourcePhrase != null &&
      (sourcePhraseTail!.isEmpty ||
          RegExp(r'^[.!?]$').hasMatch(sourcePhraseTail) ||
          (sourceFollowUpAction != null &&
              _legacyOcrNaturalCarefulInstructionActions
                  .contains(sourceFollowUpAction)));
  final isReadCarefullyFollowUp = prefix.toLowerCase() == 'read' &&
      ocrSourcePhrase == null &&
      sourceFollowUpAction != null &&
      _legacyOcrNaturalCarefulInstructionActions.contains(sourceFollowUpAction);
  if (_legacyOcrNaturalCarefulInstructionActions
          .contains(prefix.toLowerCase()) &&
      suffix.toLowerCase() == 'carefully' &&
      RegExp(
        r'^(?:(?:can|could|would)\s+you\s+)?please$',
        caseSensitive: false,
      ).hasMatch(beforeMatch) &&
      (followingText.isEmpty ||
          isNaturalCarefullyObjectPhrase ||
          isReadCarefullyFromOcrSource ||
          isReadCarefullyFollowUp)) {
    // The line break in this ordinary OCR prompt can join the action and
    // adverb into a false extension of an open-ended mask.
    return true;
  }
  if (!naturalConnectors.contains(suffix.toLowerCase())) return false;
  return RegExp(
    r'^(?:the|this|that|these|those|a|an|my|your|our|their|his|her|its)\b',
    caseSensitive: false,
  ).hasMatch(followingText);
}

String _legacyOcrOpenMaskPrefixPattern(String prefix) {
  final escapedPrefix = RegExp.escape(prefix);
  if (!_legacyOcrCanBridgeLineBreakAfterOpenMaskPrefix(prefix)) {
    return escapedPrefix;
  }

  final variants = <String>[escapedPrefix];
  if (RegExp(r'^[a-zA-Z0-9]+$').hasMatch(prefix)) {
    variants.add(
      prefix.split('').map(RegExp.escape).join(r'(?:[\r\n]+[ \t]*)?'),
    );
  }
  if (RegExp(r'[-_.=/+]$').hasMatch(prefix)) {
    final delimiter = prefix.substring(prefix.length - 1);
    final prefixWithoutDelimiter = prefix.substring(0, prefix.length - 1);
    variants.add(
      '${RegExp.escape(prefixWithoutDelimiter)}'
      r'[\r\n]+[ \t]*'
      '${RegExp.escape(delimiter)}',
    );
  }
  return '(?:${variants.join('|')})';
}

String _legacyOcrNormalizeNulsWithinMaskedPrefixes(
  String text,
  Iterable<String> credentialValues,
) {
  var normalized = text;
  for (final value in credentialValues) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis == null || value.substring(ellipsis.end).isNotEmpty) continue;
    final prefix =
        value.substring(0, ellipsis.start).trim().split(RegExp(r'\s+')).last;
    if (prefix.isEmpty) continue;
    final splitPrefix = RegExp(
      prefix.split('').map(RegExp.escape).join(r'\u0000*'),
      caseSensitive: false,
    );
    normalized = normalized.replaceAllMapped(
      splitPrefix,
      (match) => match.group(0)!.replaceAll('\u0000', ''),
    );
  }
  return normalized;
}

bool _legacyOcrHasRepeatedHyphenatedAlphaComponent(
  String prefix,
  String suffix,
) {
  final components = suffix.split('-');
  if (components.length < 3 ||
      !components.every(
        (component) => RegExp(r'^[a-zA-Z0-9]{2,}$').hasMatch(component),
      )) {
    return false;
  }
  if (components.toSet().length == 1) return true;

  final prefixSegment = prefix.split(RegExp(r'[-_]')).last;
  final firstCompletedComponent = '$prefixSegment${components.first}';
  final repeatedComponents = components.skip(1);
  return repeatedComponents.length >= 2 &&
      repeatedComponents.every(
        (component) => component == repeatedComponents.first,
      ) &&
      firstCompletedComponent == repeatedComponents.first;
}

bool _legacyOcrTextContainsMaskedCredential(
  String text,
  Iterable<String> credentialValues,
) {
  if (_legacyOcrIsOrdinaryTerminalReadCarefullyPrompt(text, credentialValues)) {
    return false;
  }
  // Legacy request headers may contain only a masked key; compare its visible
  // edges before preserving any persisted text or diagnostic value.
  final compactedText = text.replaceAll(RegExp(r'\s+'), '');
  final textWithoutPartMarkers = text.replaceAll('\u0000', '');
  if (_legacyOcrRedactWhitespaceSplitMaskedOpenPrefixEchoes(
        textWithoutPartMarkers,
        credentialValues,
      ) !=
      textWithoutPartMarkers) {
    return true;
  }
  final partBoundaryOffsets = <int>[];
  var cleanedTextOffset = 0;
  for (final codeUnit in text.codeUnits) {
    if (codeUnit == 0) {
      partBoundaryOffsets.add(cleanedTextOffset);
    } else {
      cleanedTextOffset++;
    }
  }
  const naturalWordsAtPartBoundaries = {
    'a',
    'an',
    'and',
    'as',
    'at',
    'by',
    'for',
    'from',
    'in',
    'into',
    'of',
    'on',
    'or',
    'the',
    'to',
    'with',
  };
  for (final value in credentialValues) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis != null) {
      final prefix =
          value.substring(0, ellipsis.start).trim().split(RegExp(r'\s+')).last;
      final suffix = value.substring(ellipsis.end);
      final allowEmbeddedPrefix = _legacyOcrCanMatchOpenMaskPrefixWithinToken(
        prefix,
      );
      if (suffix.isEmpty) {
        if (prefix.length >= 8) {
          final leftBoundary = allowEmbeddedPrefix
              ? r'(?:^|[^a-zA-Z0-9])?'
              : r'(?:^|[^a-zA-Z0-9])';
          final lineBreakContinuation =
              _legacyOcrLineBreakContinuationAfterOpenMaskPrefix(
            prefix,
            text: textWithoutPartMarkers,
          );
          final extendedPrefix = RegExp(
            '$leftBoundary${_legacyOcrOpenMaskPrefixPattern(prefix)}'
            '$lineBreakContinuation(\\S+)',
          );
          final prefixHasKeyMarker = RegExp(r'[0-9_]').hasMatch(prefix);
          for (final match in extendedPrefix.allMatches(
            textWithoutPartMarkers,
          )) {
            final rawSuffix = match.group(1)!;
            final suffix = rawSuffix.replaceFirst(
              RegExp(r'''[.,!?;:)\]}"'“”‘’`/*=+_~—-]+$'''),
              '',
            );
            if (_legacyOcrHasNaturalConnectorAfterLineBreak(
              textWithoutPartMarkers,
              match,
              prefix,
              suffix,
              naturalWordsAtPartBoundaries,
            )) {
              continue;
            }
            if (suffix.isEmpty) {
              final hasTerminalCredentialDelimiter = RegExp(
                r'[-_/=+~]+$',
              ).hasMatch(rawSuffix);
              final prefixHasCredentialShape =
                  RegExp(r'[-_0-9]').hasMatch(prefix) ||
                      _legacyOcrHasShortOpaqueAlphaKey(prefix) ||
                      _legacyOcrHasRepeatedAlphabeticSequence(prefix) ||
                      _legacyOcrHasRepeatedCharacterRun(prefix) ||
                      _legacyOcrHasHighAlphabeticEntropy(prefix);
              if (_legacyOcrHasCredentialUseContext(
                    textWithoutPartMarkers,
                    match,
                    prefix,
                    '',
                  ) ||
                  hasTerminalCredentialDelimiter ||
                  (prefixHasCredentialShape &&
                      !_legacyOcrHasNaturalWordContinuation(prefix, ''))) {
                return true;
              }
              continue;
            }
            final suffixHasKeyMarker = RegExp(r'[0-9_]').hasMatch(suffix);
            final tokenLength = prefix.length + suffix.length;
            final token = '$prefix$suffix';
            final alphaToken = token.replaceAll(RegExp(r'[^a-zA-Z]'), '');
            final alphaSuffix = suffix.replaceAll(RegExp(r'[^a-zA-Z]'), '');
            final unicodeOpaqueContinuation =
                _legacyOcrHasOpaqueUnicodeContinuation(prefix, suffix);
            final naturalWordContinuation =
                _legacyOcrHasNaturalWordContinuation(prefix, suffix);
            final naturalWord = '$prefix$suffix'
                .replaceAll(RegExp(r'[^a-zA-Z]'), '')
                .toLowerCase();
            final ordinaryNaturalPromptContext =
                _legacyOcrHasOrdinaryNaturalPromptContext(
              textWithoutPartMarkers,
              match,
              naturalWord,
              openMaskPrefix: prefix,
              hasCredentialUseContext: _legacyOcrHasCredentialUseContext(
                textWithoutPartMarkers,
                match,
                prefix,
                suffix,
              ),
              isNaturalWordContinuation: naturalWordContinuation,
              isNaturalSecretPlural:
                  naturalWord == 'secrets' && suffix.toLowerCase() == 's',
            );
            if (ordinaryNaturalPromptContext) continue;
            final naturalHyphenatedAlphaContinuation = suffix.startsWith('-') &&
                RegExp(r'^[a-zA-Z]+$').hasMatch(prefix) &&
                _legacyOcrHasNaturalAlphaContinuation(
                  alphaSuffix.toLowerCase(),
                );
            final crossesPartBoundary = partBoundaryOffsets.any(
              (offset) => offset > match.start && offset < match.end,
            );
            final beforePartBoundaryWord =
                textWithoutPartMarkers.substring(0, match.start).trimRight();
            final afterPartBoundaryWord =
                textWithoutPartMarkers.substring(match.end).trimLeft();
            final hasNaturalInstructionAroundPartBoundary = RegExp(
                  r'\b(?:check|read|review|identify|recognize|describe|summarize|analyze|extract|inspect|scan|transcribe|translate|classify|explain|process)\s*$',
                  caseSensitive: false,
                ).hasMatch(beforePartBoundaryWord) &&
                RegExp(
                  r'^(?:the|this|that|these|those|a|an)\b',
                  caseSensitive: false,
                ).hasMatch(afterPartBoundaryWord);
            final naturalWordAcrossPartBoundary = crossesPartBoundary &&
                naturalWordsAtPartBoundaries.contains(suffix.toLowerCase()) &&
                hasNaturalInstructionAroundPartBoundary;
            final naturalPrefixAcrossPartBoundary = crossesPartBoundary &&
                _legacyOcrHasNaturalWordContinuation(prefix, '');
            final shortUnclassifiedAlphaContinuation = tokenLength >= 10 &&
                RegExp(r'^[a-zA-Z]{2,5}$').hasMatch(suffix) &&
                !naturalWordContinuation &&
                !naturalWordAcrossPartBoundary &&
                !naturalPrefixAcrossPartBoundary;
            final oneLetterUnclassifiedAlphaContinuation = tokenLength >= 9 &&
                RegExp(r'^[a-zA-Z]$').hasMatch(suffix) &&
                !naturalWordContinuation &&
                !naturalPrefixAcrossPartBoundary;
            final unclassifiedAlphaContinuation = tokenLength >= 13 &&
                RegExp(r'^[a-zA-Z]{5,}$').hasMatch(suffix) &&
                !naturalWordContinuation &&
                !naturalPrefixAcrossPartBoundary;
            final hyphenatedUnclassifiedAlphaContinuation =
                suffix.startsWith('-') &&
                    tokenLength >= 12 &&
                    alphaSuffix.isNotEmpty &&
                    !naturalWordContinuation &&
                    !naturalHyphenatedAlphaContinuation;
            final shortDottedKeyContinuation = tokenLength >= 11 &&
                RegExp(r'^\.[a-zA-Z0-9]{2}$').hasMatch(suffix);
            final punctuationDelimitedContinuation =
                RegExp(r'^[._/=][a-zA-Z0-9]+$').hasMatch(suffix) &&
                    (RegExp(r'[-_0-9]').hasMatch(prefix) ||
                        prefix.contains('.') ||
                        shortDottedKeyContinuation ||
                        (tokenLength >= 12 &&
                            RegExp(r'^[._/=][a-zA-Z0-9]{3,}$')
                                .hasMatch(suffix))) &&
                    !naturalWordContinuation;
            final internalBearerPunctuationContinuation = tokenLength >= 11 &&
                RegExp(r'^[+~][a-zA-Z0-9]+$').hasMatch(suffix) &&
                !naturalWordContinuation;
            final repeatedStructuredHyphenatedSuffix = allowEmbeddedPrefix &&
                _legacyOcrHasRepeatedHyphenatedAlphaComponent(prefix, suffix);
            final myProjectManagementCredentialRequest =
                naturalWord == 'myprojectmanagement' &&
                    RegExp(r'\buse$', caseSensitive: false)
                        .hasMatch(beforePartBoundaryWord) &&
                    RegExp(r'^for (?:the )?request\b', caseSensitive: false)
                        .hasMatch(afterPartBoundaryWord);
            final hasExplicitCredentialUseContext =
                myProjectManagementCredentialRequest ||
                    _legacyOcrHasCredentialUseContext(
                      textWithoutPartMarkers,
                      match,
                      prefix,
                      suffix,
                    );
            final looksCredentialLike = hasExplicitCredentialUseContext ||
                unicodeOpaqueContinuation ||
                prefixHasKeyMarker ||
                suffixHasKeyMarker ||
                (_legacyOcrHasUncommonAlphaContinuation(suffix) &&
                    !_legacyOcrHasKeyboardSequence(suffix)) ||
                _legacyOcrHasCredentialWord(suffix) ||
                _legacyOcrHasCredentialCompound(token) ||
                shortUnclassifiedAlphaContinuation ||
                oneLetterUnclassifiedAlphaContinuation ||
                unclassifiedAlphaContinuation ||
                hyphenatedUnclassifiedAlphaContinuation ||
                repeatedStructuredHyphenatedSuffix ||
                punctuationDelimitedContinuation ||
                internalBearerPunctuationContinuation ||
                (!naturalWordContinuation &&
                    tokenLength >= 13 &&
                    (suffix.startsWith('-')
                        ? _legacyOcrHasHighAlphabeticEntropy(
                            alphaSuffix,
                            minimumLength: 8,
                            minimumEntropy: 3.2,
                            maximumVowelRatio: 0.32,
                          )
                        : _legacyOcrHasHighAlphabeticEntropy(
                            alphaToken,
                            minimumEntropy: 3.3,
                            maximumVowelRatio: 0.32,
                          ))) ||
                _legacyOcrHasAscendingAlphabetRun(token) ||
                _legacyOcrHasRepeatedAlphabeticSequence(token) ||
                _legacyOcrHasRepeatedCharacterRun(token);
            if (hasExplicitCredentialUseContext ||
                unicodeOpaqueContinuation ||
                (RegExp(r'[a-zA-Z0-9]').hasMatch(suffix) &&
                    looksCredentialLike)) {
              return true;
            }
          }
          if (!allowEmbeddedPrefix) {
            final embeddedPrefixWithTail = RegExp(
              '(?:^|[^a-zA-Z0-9])([a-zA-Z0-9]+'
              '${_legacyOcrOpenMaskPrefixPattern(prefix)}(\\S+))',
            );
            for (final match in embeddedPrefixWithTail.allMatches(
              textWithoutPartMarkers,
            )) {
              final rawSuffix = match.group(2)!;
              final suffix = rawSuffix.replaceFirst(
                RegExp(r'''[.,!?;:)}\]"'“”‘’`/*=_+~—-]+$'''),
                '',
              );
              if (suffix.isEmpty) continue;
              final naturalWordContinuation =
                  _legacyOcrHasNaturalWordContinuation(prefix, suffix);
              if (_legacyOcrHasCredentialUseContext(
                    textWithoutPartMarkers,
                    match,
                    prefix,
                    suffix,
                  ) ||
                  RegExp(r'[0-9_]').hasMatch(suffix) ||
                  (!naturalWordContinuation &&
                      ((suffix.length >= 7 &&
                              _legacyOcrHasUncommonAlphaContinuation(suffix)) ||
                          _legacyOcrHasShortOpaqueAlphaKey(suffix) ||
                          _legacyOcrHasHighAlphabeticEntropy(
                            suffix,
                            minimumLength: 8,
                            minimumEntropy: 3.2,
                            maximumVowelRatio: 0.32,
                          ))) ||
                  _legacyOcrHasCredentialWord(suffix) ||
                  _legacyOcrHasCredentialCompound(suffix)) {
                return true;
              }
            }
          }
          if (allowEmbeddedPrefix) {
            final embeddedExactPrefix = RegExp(
              '(?:^|[^a-zA-Z0-9])([a-zA-Z0-9]+'
              '${_legacyOcrOpenMaskPrefixPattern(prefix)})'
              r'(?=$|[^a-zA-Z0-9])',
            );
            for (final match in embeddedExactPrefix.allMatches(
              textWithoutPartMarkers,
            )) {
              if (match.group(1)!.length > prefix.length) return true;
            }
          }
        } else if (prefix.isNotEmpty) {
          final lineBreakContinuation =
              _legacyOcrLineBreakContinuationAfterOpenMaskPrefix(
            prefix,
            text: textWithoutPartMarkers,
          );
          if (prefix.length < 8) {
            final embeddedPrefix = RegExp(
              '(^|[^\\p{L}\\p{M}\\p{N}])'
              '([\\p{L}\\p{M}\\p{N}._/+~-]*'
              '${_legacyOcrOpenMaskPrefixPattern(prefix)}$lineBreakContinuation'
              '[\\p{L}\\p{M}\\p{N}._/+~-]+)',
              unicode: true,
              caseSensitive: false,
            );
            for (final match in embeddedPrefix.allMatches(
              textWithoutPartMarkers,
            )) {
              if (_legacyOcrHasEmbeddedShortMaskCredential(
                match.group(2)!,
                prefix,
                text: textWithoutPartMarkers,
                match: match,
              )) {
                return true;
              }
            }
          }
          final extendedPrefix = RegExp(
            '(?:^|[^a-zA-Z0-9])'
            '${_legacyOcrOpenMaskPrefixPattern(prefix)}'
            '$lineBreakContinuation(\\S+)',
          );
          for (final match in extendedPrefix.allMatches(
            textWithoutPartMarkers,
          )) {
            final rawSuffix = match.group(1)!;
            final hasTerminalCredentialDelimiter = RegExp(
              r'[-_/=+~]+$',
            ).hasMatch(rawSuffix);
            final suffix = rawSuffix.replaceFirst(
              RegExp(r'''[.,!?;:)}\]"'“”‘’`/*=_+~—-]+$'''),
              '',
            );
            final isLineBrokenCarefulActionEcho =
                _legacyOcrNaturalCarefulInstructionActions
                        .contains(prefix.toLowerCase()) &&
                    suffix.toLowerCase() == 'carefully' &&
                    match.group(0)!.contains(RegExp(r'[\r\n]')) &&
                    RegExp(
                      r'^(?:(?:can|could|would)\s+you\s+)?please$',
                      caseSensitive: false,
                    ).hasMatch(
                      textWithoutPartMarkers.substring(0, match.start).trim(),
                    );
            final followingText =
                textWithoutPartMarkers.substring(match.end).trimLeft();
            final naturalCheckPrompt = prefix.toLowerCase() == 'check' &&
                _legacyOcrIsNaturalCarefullyObjectPhrase(
                  prefix,
                  followingText,
                );
            final naturalReadPrompt = prefix.toLowerCase() == 'read' &&
                _legacyOcrIsNaturalCarefullyObjectPhrase(
                  prefix,
                  followingText,
                );
            final naturalTerminalReviewPrompt =
                prefix.toLowerCase() == 'review' && followingText.isEmpty;
            if (isLineBrokenCarefulActionEcho &&
                !naturalCheckPrompt &&
                !naturalReadPrompt &&
                !naturalTerminalReviewPrompt) {
              return true;
            }
            if (_legacyOcrHasNaturalConnectorAfterLineBreak(
              textWithoutPartMarkers,
              match,
              prefix,
              suffix,
              naturalWordsAtPartBoundaries,
            )) {
              continue;
            }
            if (suffix.isEmpty) {
              // A terminal Bearer-token marker can complete the visible
              // prefix by itself; very short prefixes are too common to use.
              if (_legacyOcrHasCredentialUseContext(
                    textWithoutPartMarkers,
                    match,
                    prefix,
                    '',
                  ) ||
                  (hasTerminalCredentialDelimiter && prefix.length >= 4)) {
                return true;
              }
              continue;
            }
            // Short visible prefixes also match ordinary words, so length
            // alone is evidence only when at least four characters are shown.
            final hasKeyMarker = RegExp(r'[0-9_]').hasMatch(suffix);
            final prefixHasKeyMarker = RegExp(r'[0-9_]').hasMatch(prefix);
            final token = '$prefix$suffix';
            final naturalOAuthVersion = _legacyOcrIsNaturalOAuthVersion(token);
            final alphaSuffix = suffix.replaceAll(RegExp(r'[^a-zA-Z]'), '');
            final alphaToken = token.replaceAll(RegExp(r'[^a-zA-Z]'), '');
            final unicodeOpaqueContinuation =
                _legacyOcrHasOpaqueUnicodeContinuation(prefix, suffix);
            final naturalWordContinuation =
                _legacyOcrHasNaturalWordContinuation(prefix, suffix);
            final naturalWordAcrossPartBoundary = partBoundaryOffsets.any(
                  (offset) => offset > match.start && offset < match.end,
                ) &&
                naturalWordsAtPartBoundaries.contains(suffix.toLowerCase());
            final unclassifiedAlphaContinuation =
                RegExp(r'^[a-zA-Z]{5,}$').hasMatch(suffix) &&
                    !naturalWordContinuation &&
                    ((prefix.length >= 4 && token.length >= 10) ||
                        _legacyOcrHasHighAlphabeticEntropy(
                          token,
                          minimumLength: 8,
                          minimumEntropy: 3.0,
                          maximumVowelRatio: 0.15,
                        ));
            final shortOpaqueAlphaContinuation =
                RegExp(r'^[a-zA-Z]{1,4}$').hasMatch(suffix) &&
                    !naturalWordContinuation &&
                    !naturalWordAcrossPartBoundary &&
                    (_legacyOcrHasShortOpaqueAlphaKey(token) ||
                        _legacyOcrHasLongConsonantRun(token));
            final hyphenatedAlphaContinuation = !naturalWordContinuation &&
                ((suffix.startsWith('-') &&
                        token.length >= 12 &&
                        alphaSuffix.length >= 8 &&
                        _legacyOcrHasHighAlphabeticEntropy(
                          alphaSuffix,
                          minimumLength: 8,
                          minimumEntropy: 3.2,
                          maximumVowelRatio: 0.45,
                        )) ||
                    (prefix.endsWith('-') &&
                        token.length >= 10 &&
                        alphaSuffix.length >= 4));
            final terminalPunctuationHyphenatedContinuation =
                hasTerminalCredentialDelimiter &&
                    suffix.startsWith('-') &&
                    token.length >= 11 &&
                    alphaSuffix.length >= 4 &&
                    !naturalWordContinuation;
            final internalBearerPunctuationContinuation = token.length >= 11 &&
                RegExp(r'^[+~][a-zA-Z0-9]+$').hasMatch(suffix) &&
                !naturalWordContinuation;
            final internalSeparatorAlphaKeyContinuation = RegExp(
                  r'^[a-zA-Z0-9]+[-_/=+~][a-zA-Z0-9]+$',
                ).hasMatch(suffix) &&
                token.length >= 12 &&
                !naturalWordContinuation &&
                _legacyOcrHasHighAlphabeticEntropy(
                  alphaToken,
                  minimumLength: 12,
                  minimumEntropy: 3.3,
                  maximumVowelRatio: 0.32,
                );
            final credentialWordPrefixContinuation =
                _legacyOcrHasCredentialWord(prefix) &&
                    RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(suffix) &&
                    !_legacyOcrHasNaturalAlphaContinuation(suffix) &&
                    !naturalWordContinuation &&
                    (!(suffix.startsWith('-') || prefix.endsWith('-')) ||
                        (alphaSuffix.length >= 8 &&
                            _legacyOcrHasHighAlphabeticEntropy(
                              alphaSuffix,
                              minimumLength: 8,
                              minimumEntropy: 3.2,
                              maximumVowelRatio: 0.45,
                            )));
            final shortAuthOpaqueContinuation =
                prefix.toLowerCase() == 'auth' &&
                    (RegExp(r'^[a-zA-Z0-9]{1,4}$').hasMatch(suffix) ||
                        RegExp(r'^[a-zA-Z]{5,}$').hasMatch(suffix) ||
                        RegExp(r'^-[a-zA-Z0-9]{3,}$').hasMatch(suffix) ||
                        _legacyOcrHasUncommonAlphaContinuation(suffix)) &&
                    !naturalWordContinuation;
            final shortCredentialWordHyphenatedContinuation =
                _legacyOcrHasCredentialWord(prefix) &&
                    suffix.startsWith('-') &&
                    alphaSuffix.length >= 4 &&
                    !naturalWordContinuation;
            final looksCredentialLike = _legacyOcrHasCredentialUseContext(
                  textWithoutPartMarkers,
                  match,
                  prefix,
                  suffix,
                ) ||
                unicodeOpaqueContinuation ||
                (hasKeyMarker && !naturalOAuthVersion) ||
                prefixHasKeyMarker ||
                credentialWordPrefixContinuation ||
                shortAuthOpaqueContinuation ||
                shortCredentialWordHyphenatedContinuation ||
                shortOpaqueAlphaContinuation ||
                unclassifiedAlphaContinuation ||
                hyphenatedAlphaContinuation ||
                terminalPunctuationHyphenatedContinuation ||
                internalBearerPunctuationContinuation ||
                internalSeparatorAlphaKeyContinuation ||
                _legacyOcrHasAscendingAlphabetRun(token) ||
                _legacyOcrHasRepeatedAlphabeticSequence(token) ||
                (!naturalWordContinuation &&
                    _legacyOcrHasHighAlphabeticEntropy(token)) ||
                _legacyOcrHasCredentialCompound(token) ||
                _legacyOcrHasCredentialWord(suffix);
            if (looksCredentialLike) return true;
          }
        }
        continue;
      }
      if (prefix.isNotEmpty &&
          RegExp(
            '${RegExp.escape(prefix)}\\S+${RegExp.escape(suffix)}',
          ).hasMatch(compactedText)) {
        return true;
      }
      continue;
    }
    final mask = value.indexOf('*');
    if (mask < 0) continue;
    final prefix = value.substring(0, mask);
    // A very short visible prefix is too common to identify a credential in
    // free text; the general credential-shape checks above still redact
    // explicit assignments and recognizable tokens.
    if (prefix.length >= 4) {
      final openMaskEcho = RegExp(
        '${RegExp.escape(prefix)}(\\S{1,12})',
        caseSensitive: false,
      );
      for (final match in openMaskEcho.allMatches(textWithoutPartMarkers)) {
        if (!_legacyOcrHasNaturalWordContinuation(prefix, match.group(1)!)) {
          return true;
        }
      }
    }
  }
  return false;
}

bool _legacyOcrHasSafeRedactedInstruction(
  String text, {
  bool allowBareAction = false,
  bool allowReceiptUse = false,
  bool allowShortDocumentationApiKeyTarget = false,
}) {
  if (!text.contains('[redacted]')) return false;
  final safeActionLead = RegExp(
    r'^\s*(?:for accurate OCR,\s*)?(?:(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?)?(?:read|review|examine|inspect|identify|recognize|describe|summarize|analyze|extract|interpret|count|find|search|locate|transcribe|translate|classify|calculate|explain|process|show|tell|check|look|scan|ocr|decode|record)\b.*\[redacted\]',
    caseSensitive: false,
    dotAll: true,
  ).hasMatch(text);
  final safeUseLead = RegExp(
    r'^\s*(?:for page \d+,\s*)?(?:please\s+)?(?:use|pass|send|supply|authenticate\s+with)\b.*\[redacted\](?:\s+as\s+(?:(?:the|a|an|my|your|our|their|his|her|its)\s+)?(?:(?:oauth\s*[0-9]*(?:\.[0-9]+)?|oidc|openid\s+connect|secret|api|access|private|bearer)\s+)*(?:authorization|auth|api\s+key|key|credential|token|secret|password)\s+value)?\s+(?:to\s+(?:process|read|recognize|describe|summarize|analyze|extract|interpret|count|find|transcribe|translate|classify|identify|ocr|decode)\b|for\s+(?:the\s+)?request\b)|^\s*(?:please\s+)?use\s+\[redacted\]\s*$|^\s*(?:please\s+)?supply\s+\[redacted\]\s+(?:the\s+)?(?:api\s+key|authorization)\s+header\b',
    caseSensitive: false,
    dotAll: true,
  ).hasMatch(text);
  final safeShortDocumentationApiKeyTarget =
      allowShortDocumentationApiKeyTarget &&
          RegExp(
            r'^\s*(?:please\s+)?use\s+\[redacted\]\s+as\s+the\s+api\s+key\s*[.!?]?\s*$',
            caseSensitive: false,
          ).hasMatch(text);
  final safeReceiptUseLead = RegExp(
    r'^\s*(?:please\s+)?use\s+\[redacted\].*\bfor (?:this|the) receipt\b',
    caseSensitive: false,
    dotAll: true,
  ).hasMatch(text);
  final safeRequestUseLead = RegExp(
        r'^\s*(?:for page \d+,\s*)?please\s+use\b.*\[redacted\].*\bfor (?:the )?request\b',
        caseSensitive: false,
        dotAll: true,
      ).hasMatch(text) ||
      !RegExp(r'\bfor (?:the )?request\b', caseSensitive: false).hasMatch(text);
  final safeScanContext = RegExp(
    r'^\s*the\s+scan\s+(?:mentions|says|contains|shows|includes)\b.*\[redacted\]',
    caseSensitive: false,
    dotAll: true,
  ).hasMatch(text);
  final safeImageContext = RegExp(
    r'^\s*the\s+image\s+(?:mentions|says|contains|shows|includes)\b.*\[redacted\]',
    caseSensitive: false,
    dotAll: true,
  ).hasMatch(text);
  final safeReceiptContextAction = RegExp(
    r'^\s*this\s+is\s+a\s+receipt[.!?]\s*(?:please\s+)?(?:read|review|examine|inspect|identify|recognize|describe|summarize|analyze|extract|interpret|count|find|search|locate|transcribe|translate|classify|calculate|explain|process|show|tell|check|look|scan|ocr|decode|record)\b.*\[redacted\]',
    caseSensitive: false,
    dotAll: true,
  ).hasMatch(text);
  final safeKeepLead = RegExp(
    r'^\s*(?:please\s+)?keep\b.*\[redacted\]',
    caseSensitive: false,
    dotAll: true,
  ).hasMatch(text);
  final bareRedactedAction = RegExp(
    r'^\s*(?:please\s+)?(?:read|review|examine|inspect|identify|recognize|describe|summarize|analyze|extract|interpret|count|find|search|locate|transcribe|translate|classify|calculate|explain|process|show|tell|check|look|scan|ocr|decode)\s+\[redacted\]\s*[.!?]?\s*$',
    caseSensitive: false,
  ).hasMatch(text);
  return (safeActionLead && (!bareRedactedAction || allowBareAction)) ||
      (safeUseLead && safeRequestUseLead) ||
      safeShortDocumentationApiKeyTarget ||
      (allowReceiptUse && safeReceiptUseLead) ||
      safeScanContext ||
      safeImageContext ||
      safeReceiptContextAction ||
      safeKeepLead;
}

bool _legacyOcrHasShortDocumentationApiKeyEcho(
  String sourceText,
  Iterable<String> credentialValues,
) {
  if (!RegExp(
    r'^\s*(?:please\s+)?use\s+documentation\s+as\s+the\s+api\s+key\s*[.!?]?\s*$',
    caseSensitive: false,
  ).hasMatch(sourceText)) {
    return false;
  }
  return credentialValues.any((value) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis == null || value.substring(ellipsis.end).isNotEmpty) {
      return false;
    }
    final prefix =
        value.substring(0, ellipsis.start).trim().split(RegExp(r'\s+')).last;
    return prefix.length < 8 && prefix.toLowerCase() == 'docu';
  });
}

bool _legacyOcrHasStrongReceiptCredentialPrefix(
  String sourceText,
  Iterable<String> credentialValues,
) {
  final echoedValue = RegExp(
    r'^\s*(?:please\s+)?use\s+([A-Za-z0-9_-]+)\s+for\s+(?:this|the)\s+receipt\b',
    caseSensitive: false,
  ).firstMatch(sourceText)?.group(1)?.toLowerCase();
  if (echoedValue == null) return false;
  final echoedValueHasCredentialShape =
      RegExp(r'[-_0-9]').hasMatch(echoedValue) ||
          _legacyOcrHasCredentialWord(echoedValue) ||
          (_legacyOcrHasHighAlphabeticEntropy(echoedValue) &&
              !_legacyOcrHasAscendingAlphabetRun(echoedValue));
  if (!echoedValueHasCredentialShape) return false;
  for (final credentialValue in credentialValues) {
    final prefix = RegExp(r'([A-Za-z0-9_-]{4,})(?:…|\.{3})\s*$')
        .firstMatch(credentialValue.trim())
        ?.group(1)
        ?.toLowerCase();
    if (prefix != null && echoedValue.startsWith(prefix)) return true;
  }
  return false;
}

bool _legacyOcrShouldPreserveBareRedactedAction(String sourceText) {
  if (RegExp(
    r'^\s*(?:please\s+)?(?:transcribe|recognize)\b',
    caseSensitive: false,
  ).hasMatch(sourceText)) {
    return true;
  }
  if (!RegExp(r'^\s*(?:please\s+)?read\b', caseSensitive: false)
      .hasMatch(sourceText)) {
    return false;
  }
  return RegExp(r'^\s*(?:please\s+)?read\s+\S*\d', caseSensitive: false)
          .hasMatch(sourceText) ||
      RegExp(
        r'^\s*please\s+read\s*[\r\n]+\s*carefully\b',
        caseSensitive: false,
      ).hasMatch(sourceText);
}

String? _legacyOcrInstructionContent(Map<String, dynamic>? rawRequest) {
  final body = rawRequest?['body'];
  if (body is! Map || body['messages'] is! List) return null;
  final credentialValues = _legacyOcrCredentialValues(rawRequest).toList();
  final sourceTextParts = <String>[];
  for (final message in body['messages'] as List) {
    if (message is! Map ||
        message['role'] != 'user' ||
        message['content'] is! List) {
      continue;
    }
    for (final part in message['content'] as List) {
      if (part is Map && part['type'] == 'text' && part['text'] is String) {
        sourceTextParts.add(part['text'] as String);
      }
    }
  }
  final hasEmbeddedNul = sourceTextParts.any((text) => text.contains('\u0000'));
  final hasCredentialInOnePart = sourceTextParts.any(
    (text) => _legacyOcrTextContainsCredential(
      text.replaceAll('\u0000', ''),
      credentialValues,
    ),
  );
  final joinedCredentialCheckText =
      sourceTextParts.join().replaceAll('\u0000', '');
  if (hasEmbeddedNul &&
      !hasCredentialInOnePart &&
      _legacyOcrTextContainsCredential(
        joinedCredentialCheckText,
        credentialValues,
      )) {
    // Removing a NUL within or between parts can reconnect a credential that
    // no individual part exposes. Fail closed before display normalization.
    return null;
  }

  final textParts = <String>[];
  final textPartsHadCredential = <bool>[];
  for (final sourceText in sourceTextParts) {
    final credentialCheckText = sourceText.replaceAll('\u0000', '');
    final hadCredential = _legacyOcrTextContainsCredential(
      credentialCheckText,
      credentialValues,
    );
    final redactionSourceText = _legacyOcrNormalizeNulsWithinMaskedPrefixes(
      sourceText,
      credentialValues,
    );
    final redactedText = hadCredential
        ? _legacyOcrRedactMaskedCredentialEchoes(
            redactionSourceText,
            credentialValues,
          )
        : sourceText;
    final nullFreeRedactedText = redactedText.replaceAll('\u0000', '');
    final containsUnmaskedExactCredential = credentialValues.any((value) {
      final candidate = value.trim();
      if (candidate.isEmpty ||
          candidate.contains('…') ||
          candidate.trimRight().endsWith('...')) {
        return false;
      }
      return nullFreeRedactedText.contains(candidate);
    });
    if (sourceText.contains('\u0000') &&
        hadCredential &&
        (containsUnmaskedExactCredential ||
            _legacyOcrTextContainsMaskedCredential(
              nullFreeRedactedText,
              credentialValues,
            ))) {
      // If a NUL split the credential so the redactor could not remove its
      // echo, discard this request instead of retaining a partial secret.
      return null;
    }
    final text = redactedText.replaceAll('\u0000', ' ');
    textParts.add(text);
    textPartsHadCredential.add(hadCredential);
  }
  if (textParts.isEmpty) return null;
  final redactedMarkedInstruction = _legacyOcrRedactNaturalWordCredentialEchoes(
    textParts.join('\u0000'),
    credentialValues,
  );
  final naturalSecretPluralRanges = RegExp(
    r'\bsecret\u0000*s\b',
    caseSensitive: false,
  ).allMatches(redactedMarkedInstruction).where((match) {
    final hasCredentialUseContext = _legacyOcrHasCredentialUseContext(
      redactedMarkedInstruction,
      match,
      'secret',
      's',
    );
    return _legacyOcrHasOrdinaryNaturalPromptContext(
      redactedMarkedInstruction,
      match,
      match.group(0)!.replaceAll('\u0000', '').toLowerCase(),
      hasCredentialUseContext: hasCredentialUseContext,
      isNaturalWordContinuation: true,
      isNaturalSecretPlural: true,
    );
  }).toList();
  var textOffset = 0;
  var textPartIndex = 0;
  final safeTextParts = redactedMarkedInstruction.split('\u0000').where((text) {
    final partIndex = textPartIndex++;
    final hadCredential = textPartsHadCredential[partIndex];
    final sourceText = sourceTextParts[partIndex];
    final start = textOffset;
    final end = start + text.length;
    textOffset = end + 1;
    final partNaturalPluralRanges = naturalSecretPluralRanges
        .where((match) => match.start < end && match.end > start)
        .toList();
    var textWithoutNaturalPlural = text;
    for (final match in partNaturalPluralRanges.reversed) {
      final localStart = match.start > start ? match.start - start : 0;
      final localEnd = match.end < end ? match.end - start : text.length;
      textWithoutNaturalPlural =
          '${textWithoutNaturalPlural.substring(0, localStart)} '
          '${textWithoutNaturalPlural.substring(localEnd)}';
    }
    final preservesNaturalPlural = partNaturalPluralRanges.isNotEmpty;
    final containsUnmaskedExactCredential = credentialValues.any((value) {
      final candidate = value.trim();
      if (candidate.isEmpty ||
          candidate.contains('…') ||
          candidate.trimRight().endsWith('...')) {
        return false;
      }
      return text.contains(candidate);
    });
    if (containsUnmaskedExactCredential) return false;
    if (text.contains('[redacted]') &&
        _legacyOcrHasWhitespaceSplitMaskedDocumentationEcho(
          sourceText,
          credentialValues,
        )) {
      // Validate the complete sanitized prompt while treating our literal
      // replacement marker as neutral text. This preserves safe context around
      // this scoped echo without allowing a second credential to survive.
      final neutralizedText = text.replaceAll('[redacted]', 'placeholder');
      if (_legacyOcrTextContainsCredential(
            neutralizedText,
            credentialValues,
          ) ||
          _legacyOcrTextContainsMaskedCredential(
            neutralizedText,
            credentialValues,
          )) {
        return false;
      }
      return _legacyOcrHasSafeRedactedInstruction(
        text,
        allowBareAction: _legacyOcrShouldPreserveBareRedactedAction(sourceText),
        allowReceiptUse: _legacyOcrHasStrongReceiptCredentialPrefix(
          sourceText,
          credentialValues,
        ),
        allowShortDocumentationApiKeyTarget:
            _legacyOcrHasShortDocumentationApiKeyEcho(
          sourceText,
          credentialValues,
        ),
      );
    }
    if (_legacyOcrTextContainsCredential(
      textWithoutNaturalPlural,
      credentialValues,
    )) {
      return false;
    }
    if (preservesNaturalPlural) return true;
    if (!hadCredential) return true;
    return _legacyOcrHasSafeRedactedInstruction(
      text,
      allowBareAction: _legacyOcrShouldPreserveBareRedactedAction(sourceText),
      allowReceiptUse: _legacyOcrHasStrongReceiptCredentialPrefix(
        sourceText,
        credentialValues,
      ),
      allowShortDocumentationApiKeyTarget:
          _legacyOcrHasShortDocumentationApiKeyEcho(
        sourceText,
        credentialValues,
      ),
    );
  }).join('\u0000');
  final instruction = safeTextParts.replaceAll('\u0000', '\n');
  if (instruction.length > 10000 ||
      RegExp(
        r'(?:data:image/|base64,)',
        caseSensitive: false,
      ).hasMatch(instruction) ||
      _legacyOcrTextContainsCredential(instruction, credentialValues) ||
      // Preserve text-part boundaries separately so an echoed key split
      // between parts can be identified without removing natural whitespace.
      _legacyOcrTextContainsMaskedCredential(
        safeTextParts,
        credentialValues,
      )) {
    return null;
  }
  return instruction;
}

String _legacyOcrRedactMaskedCredentialEchoes(
  String text,
  Iterable<String> credentialValues,
) {
  final hasSentenceBoundary = RegExp(r'[.!?]\s+\S').hasMatch(text);
  var sanitized = _legacyOcrRedactWhitespaceSplitMaskedOpenPrefixEchoes(
    _legacyOcrRedactWhitespaceSplitMaskedDocumentationEchoes(
      text,
      credentialValues,
    ),
    credentialValues,
  );
  for (final value in credentialValues) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis == null || value.substring(ellipsis.end).isNotEmpty) continue;
    final prefix =
        value.substring(0, ellipsis.start).trim().split(RegExp(r'\s+')).last;
    if (prefix.isEmpty) continue;
    final allowEmbeddedPrefix = _legacyOcrCanMatchOpenMaskPrefixWithinToken(
      prefix,
    );
    final canMatchWithinToken = prefix.length >= 8;
    final leftBoundary =
        canMatchWithinToken ? r'(?:^|[^a-zA-Z0-9])?' : r'(?:^|[^a-zA-Z0-9])';
    final tokenLead = canMatchWithinToken ? r'[a-zA-Z0-9]*' : '';
    final lineBreakContinuation =
        _legacyOcrLineBreakContinuationAfterOpenMaskPrefix(
      prefix,
      text: sanitized,
    );
    final suffixPattern =
        allowEmbeddedPrefix ? r'(?:\S+|(?=$|[^a-zA-Z0-9]))' : r'\S+';
    final extendedPrefix = RegExp(
      '$leftBoundary($tokenLead'
      '${_legacyOcrOpenMaskPrefixPattern(prefix)}'
      '$lineBreakContinuation$suffixPattern)',
      caseSensitive: false,
    );
    sanitized = sanitized.replaceAllMapped(extendedPrefix, (match) {
      final boundaryLength = match.group(0)!.length - match.group(1)!.length;
      final beforeEcho = sanitized.substring(0, match.start + boundaryLength);
      final afterEcho = sanitized.substring(match.end);
      final naturalCarefulInstructionLead =
          _legacyOcrNaturalCarefulInstructionActions
                  .contains(prefix.toLowerCase()) &&
              RegExp(
                r'^\s*(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?$',
                caseSensitive: false,
              ).hasMatch(beforeEcho);
      final readFromOcrSourcePrompt = (naturalCarefulInstructionLead ||
              (prefix.toLowerCase() == 'read' &&
                  RegExp(
                    r'^\s*(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?$',
                    caseSensitive: false,
                  ).hasMatch(beforeEcho)) ||
              RegExp(
                r'^\s*(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?read\s+$',
                caseSensitive: false,
              ).hasMatch(beforeEcho)) &&
          _legacyOcrNaturalSourcePhrasePattern.hasMatch(
            sanitized.substring(match.end),
          );
      final credentialValueTargetAfterEcho = RegExp(
        r'^\s*(?:as\s+)?(?:(?:the|a|an|my|your|our|their|his|her|its)\s+)?(?:(?:api|access|private|oidc|openid\s+connect|oauth(?:\s*[0-9]+(?:\.[0-9]+)*)?|secret|temporary|bearer)\s+)*(?:authorization|auth|keys?|credentials?|tokens?|secrets?|passwords?)\b',
        caseSensitive: false,
      ).hasMatch(sanitized.substring(match.end));
      final authorizationValueTargetAfterEcho = RegExp(
        r'^\s*(?:as\s+)?(?:(?:the|a|an|my|your|our|their|his|her|its)\s+)?(?:(?:api|access|private|oidc|openid\s+connect|oauth(?:\s*[0-9]+(?:\.[0-9]+)*)?|secret|temporary|bearer)\s+)*(?:authorization|auth)\b',
        caseSensitive: false,
      ).hasMatch(sanitized.substring(match.end));
      final safeCredentialValueActionLead = credentialValueTargetAfterEcho &&
              RegExp(
                r'^\s*(?:(?:please)\s+)?(?:pass|set|provide|enter|supply|send)\s+$',
                caseSensitive: false,
              ).hasMatch(beforeEcho) ||
          authorizationValueTargetAfterEcho &&
              RegExp(
                r'^\s*(?:(?:please)\s+)?use\s+$',
                caseSensitive: false,
              ).hasMatch(beforeEcho);
      final hasSafeInstructionLead = RegExp(
            r'^\s*(?:for accurate OCR,\s*)?(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?(?:read|review|examine|inspect|identify|recognize|describe|summarize|analyze|extract|interpret|count|find|search|transcribe|translate|classify|calculate|explain|process|show|tell|check|look|scan|ocr|decode)\s+(?:(?:the|this|that|these|those|a|an)\s+)?[a-z0-9]+\s+',
            caseSensitive: false,
          ).hasMatch(beforeEcho) ||
          RegExp(
            r'^\s*(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?(?:transcribe|recognize)\s+$',
            caseSensitive: false,
          ).hasMatch(beforeEcho) ||
          naturalCarefulInstructionLead ||
          readFromOcrSourcePrompt ||
          RegExp(
            r'^\s*(?:for accurate OCR,\s*)?(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?(?:read|review|examine|inspect|identify|recognize|describe|summarize|analyze|extract|interpret|count|find|search|transcribe|translate|classify|calculate|explain|process|show|tell|check|look|scan|ocr|decode)\s*:\s*$',
            caseSensitive: false,
          ).hasMatch(beforeEcho) ||
          RegExp(
                r'^\s*(?:for page \d+,\s*)?(?:please\s+)?use\s+$',
                caseSensitive: false,
              ).hasMatch(beforeEcho) &&
              RegExp(
                r'^\s+to\s+(?:process|read|recognize|describe|summarize|analyze|extract|interpret|count|find|transcribe|translate|classify|identify|ocr|decode)\b',
                caseSensitive: false,
              ).hasMatch(sanitized.substring(match.end));
      final rawEcho = match.group(1)!;
      final echo = rawEcho.replaceFirst(
        RegExp(r'''[.,!?;:)\]}"'“”‘’`/*=+_~—-]+$'''),
        '',
      );
      final lineBrokenCarefulActionEcho = naturalCarefulInstructionLead &&
          rawEcho.contains(RegExp(r'[\r\n]')) &&
          echo.replaceAll(RegExp(r'\s+'), '').toLowerCase() ==
              '${prefix.toLowerCase()}carefully';
      final prefixOffset = echo.toLowerCase().indexOf(prefix.toLowerCase());
      final echoSuffix =
          prefixOffset < 0 ? '' : echo.substring(prefixOffset + prefix.length);
      final splitEchoHasCredentialUseContext =
          match.group(1)!.contains(RegExp(r'[\r\n]')) &&
              _legacyOcrHasCredentialUseContext(
                sanitized,
                match,
                prefix,
                echoSuffix,
              );
      final bareSecretBasedUseContext = prefix.toLowerCase() == 'secret' &&
          echoSuffix.toLowerCase() == '-based' &&
          RegExp(
            r'\b(?:use|using)$',
            caseSensitive: false,
          ).hasMatch(beforeEcho.trimRight()) &&
          RegExp(r'^[.!?]*$').hasMatch(afterEcho.trim());
      final myProjectManagementCredentialRequest =
          prefix.toLowerCase() == 'myproject' &&
              echoSuffix.toLowerCase() == 'management' &&
              RegExp(r'\buse$', caseSensitive: false)
                  .hasMatch(beforeEcho.trimRight()) &&
              RegExp(r'^for (?:the )?request\b', caseSensitive: false)
                  .hasMatch(afterEcho.trimLeft());
      final authenticateWithToProcessContext = RegExp(
            r'\bauthenticate with$',
            caseSensitive: false,
          ).hasMatch(sanitized.substring(0, match.start).trimRight()) &&
          _legacyOcrHasCredentialUseContext(
            sanitized,
            match,
            prefix,
            echoSuffix,
          );
      final hasCredentialUseContext = splitEchoHasCredentialUseContext ||
          bareSecretBasedUseContext ||
          authenticateWithToProcessContext ||
          myProjectManagementCredentialRequest;
      final naturalReadInstructionsPrompt =
          _legacyOcrHasNaturalWordContinuation(prefix, echoSuffix) &&
              RegExp(
                r'\b(?:please\s+)?read\s*$',
                caseSensitive: false,
              ).hasMatch(beforeEcho) &&
              RegExp(
                r'^instructions?\b',
                caseSensitive: false,
              ).hasMatch(afterEcho.trimLeft());
      final naturalReadCharacterPrompt = _legacyOcrIsNaturalReadCharacterPrompt(
        '$prefix$echoSuffix'.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase(),
        beforeEcho,
      );
      final ordinaryNaturalPromptContext = !hasCredentialUseContext &&
          (naturalReadInstructionsPrompt || naturalReadCharacterPrompt);
      if (ordinaryNaturalPromptContext) return match.group(0)!;
      final hasRepeatedStructuredSuffix = allowEmbeddedPrefix &&
          _legacyOcrHasRepeatedHyphenatedAlphaComponent(prefix, echoSuffix);
      final hasAuthorizationConnectorAfterEcho = RegExp(
        r'^\s+as\s+',
        caseSensitive: false,
      ).hasMatch(afterEcho);
      final preserveAuthorizationConnector = safeCredentialValueActionLead &&
          !hasAuthorizationConnectorAfterEcho &&
          echoSuffix.replaceAll(RegExp(r'\s+'), '').toLowerCase() == 'as';
      final hasSafeInstructionAfterEcho = RegExp(
        r'\b(?:and|then)\s+(?:(?:please)\s+)?(?:read|review|examine|inspect|identify|recognize|describe|summarize|analyze|answer|extract|interpret|count|copy|compute|find|give|search|transcribe|translate|classify|explain|process|provide|show|tell|check|look|scan|ocr|decode|write|list|record|output|report|note|state|add|return|respond|subtract|sum)\s+(?:(?:the|this|that|these|those|a|an)\s+)?[a-z0-9]+\b|\bbefore\s+(?:reading|checking|reviewing|examining|inspecting|identifying|recognizing|describing|summarizing|analyzing|extracting|interpreting|counting|finding|searching|transcribing|translating|classifying|explaining|processing|showing|telling|looking|scanning|decoding|locating)\s+(?:(?:the|this|that|these|those|a|an)\s+)?[a-z0-9]+\b|\bto\s+(?:verify|confirm)\s+(?:(?:the|this|that|these|those|a|an)\s+)?[a-z0-9]+\b',
        caseSensitive: false,
      ).hasMatch(afterEcho);
      final confirmedMaskedCredentialEcho =
          _legacyOcrTextContainsMaskedCredential(echo, [value]);
      if ((!hasSentenceBoundary &&
              !hasSafeInstructionLead &&
              !hasRepeatedStructuredSuffix &&
              !hasSafeInstructionAfterEcho &&
              !safeCredentialValueActionLead &&
              !hasCredentialUseContext &&
              !confirmedMaskedCredentialEcho) ||
          echo.length <= prefix.length ||
          (!confirmedMaskedCredentialEcho &&
              !hasCredentialUseContext &&
              !lineBrokenCarefulActionEcho)) {
        return match.group(0)!;
      }
      final trailingPunctuation = rawEcho.substring(echo.length);
      final boundary = match.group(0)!.substring(0, boundaryLength);
      final authorizationConnector =
          preserveAuthorizationConnector ? ' as' : '';
      final redactedEcho = lineBrokenCarefulActionEcho
          ? '${echo.substring(0, prefix.length)} [redacted]'
          : '[redacted]';
      return '$boundary$redactedEcho$authorizationConnector$trailingPunctuation';
    });
    if (prefix.length < 8) {
      final lineBreakContinuation =
          _legacyOcrLineBreakContinuationAfterOpenMaskPrefix(
        prefix,
        text: sanitized,
      );
      final embeddedPrefix = RegExp(
        '(^|[^\\p{L}\\p{M}\\p{N}])'
        '([\\p{L}\\p{M}\\p{N}._/+~-]*'
        '${_legacyOcrOpenMaskPrefixPattern(prefix)}$lineBreakContinuation'
        '[\\p{L}\\p{M}\\p{N}._/+~-]+)',
        unicode: true,
        caseSensitive: false,
      );
      sanitized = sanitized.replaceAllMapped(embeddedPrefix, (match) {
        final rawEcho = match.group(2)!;
        final echo = rawEcho.replaceFirst(
          RegExp(r'''[.,!?;:)}\]"'“”‘’`/*=+_~—-]+$'''),
          '',
        );
        if (!_legacyOcrHasEmbeddedShortMaskCredential(
          echo,
          prefix,
          text: sanitized,
          match: match,
        )) {
          return match.group(0)!;
        }
        final trailingPunctuation = rawEcho.substring(echo.length);
        return '${match.group(1)}[redacted]$trailingPunctuation';
      });
    }
  }
  return sanitized;
}

String _legacyOcrRedactWhitespaceSplitMaskedDocumentationEchoes(
  String text,
  Iterable<String> credentialValues,
) {
  var sanitized = text;
  for (final value in credentialValues) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis == null || value.substring(ellipsis.end).isNotEmpty) continue;
    final prefix =
        value.substring(0, ellipsis.start).trim().split(RegExp(r'\s+')).last;
    if (prefix.toLowerCase() != 'documentation') continue;
    final pattern = RegExp(
      r'(^|[^a-zA-Z0-9])'
      r'([dD][oO][cC][uU][mM][eE][nN][tT][aA][tT][iI][oO][nN])'
      r'([ \t\r\n]+)'
      r'([a-zA-Z0-9_./+=~-]+(?:[ \t\r\n]+[a-zA-Z0-9_./+=~-]+)*)'
      r'(?=$|[^a-zA-Z0-9_])',
      caseSensitive: true,
    );
    sanitized = sanitized.replaceAllMapped(pattern, (match) {
      final suffix = match.group(4)!;
      final naturalPromptLength =
          _legacyOcrNaturalReadDocumentationBlueprintPromptLength(
        text.substring(0, match.start),
        suffix,
      );
      final echoSuffix = naturalPromptLength == null
          ? suffix
          : suffix.substring(naturalPromptLength);
      final credentialEnd = _legacyOcrMaskedDocumentationCredentialEchoLength(
        echoSuffix,
        value,
      );
      if (credentialEnd == 0) {
        return match.group(0)!;
      }
      if (naturalPromptLength != null) {
        final leadingWhitespace = echoSuffix.substring(
          0,
          echoSuffix.length - echoSuffix.trimLeft().length,
        );
        final safeTrailingText = echoSuffix.substring(credentialEnd);
        return '${match.group(1)}${match.group(2)}${match.group(3)}'
            '${suffix.substring(0, naturalPromptLength)}'
            '$leadingWhitespace[redacted]$safeTrailingText';
      }
      final safeTrailingText = suffix.substring(credentialEnd);
      return '${match.group(1)}[redacted]$safeTrailingText';
    });
  }
  return sanitized;
}

String _legacyOcrRedactWhitespaceSplitMaskedOpenPrefixEchoes(
  String text,
  Iterable<String> credentialValues,
) {
  var sanitized = text;
  for (final value in credentialValues) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis == null || value.substring(ellipsis.end).isNotEmpty) continue;
    final prefix =
        value.substring(0, ellipsis.start).trim().split(RegExp(r'\s+')).last;
    if (prefix.isEmpty || prefix.length >= 8) continue;

    const token = r'[a-zA-Z0-9._/+~-]+';
    final prefixPattern = RegExp(
      '(^|[^a-zA-Z0-9])(${RegExp.escape(prefix)})'
      '(?=[ \\t\\r\\n]+$token)',
      caseSensitive: false,
    );
    final tokenPattern = RegExp(token);
    final whitespacePattern = RegExp(r'[ \t\r\n]+');
    for (final match in prefixPattern.allMatches(sanitized).toList().reversed) {
      final boundary = match.group(1)!;
      final prefixStart = match.start + boundary.length;
      var cursor = prefixStart + prefix.length;
      var suffix = '';
      while (true) {
        final whitespace = whitespacePattern.matchAsPrefix(sanitized, cursor);
        if (whitespace == null) break;
        final tokenMatch =
            tokenPattern.matchAsPrefix(sanitized, whitespace.end);
        if (tokenMatch == null) break;
        suffix += tokenMatch.group(0)!;
        final echoEnd = tokenMatch.end;
        final hasCredentialShape = suffix.length >= 5 &&
            (!_legacyOcrHasKeyboardSequence(suffix) ||
                RegExp(r'[0-9_]').hasMatch(suffix)) &&
            (RegExp(r'[0-9_]').hasMatch(suffix) ||
                _legacyOcrHasUncommonAlphaContinuation(suffix) ||
                _legacyOcrHasLongConsonantRun(suffix) ||
                _legacyOcrHasShortOpaqueAlphaKey('$prefix$suffix'));
        if (!hasCredentialShape ||
            !_legacyOcrHasCredentialUseContextAt(
              sanitized,
              prefixStart,
              echoEnd,
              sanitized.substring(prefixStart, echoEnd),
              prefix,
              suffix,
            )) {
          cursor = echoEnd;
          continue;
        }
        sanitized = sanitized.replaceRange(
          match.start,
          echoEnd,
          '$boundary[redacted]',
        );
        break;
      }
    }
  }
  return sanitized;
}

bool _legacyOcrHasOrdinaryNaturalPromptContext(
  String text,
  Match match,
  String naturalWord, {
  String openMaskPrefix = '',
  required bool hasCredentialUseContext,
  required bool isNaturalWordContinuation,
  required bool isNaturalSecretPlural,
}) {
  final before =
      text.substring(0, match.start).replaceAll('\u0000', ' ').trimRight();
  final after = text.substring(match.end).replaceAll('\u0000', ' ').trimLeft();
  final politeNaturalVerbPrompt = naturalWord.endsWith('ize') &&
      RegExp(r'\bplease$', caseSensitive: false).hasMatch(before) &&
      RegExp(
        r'^(?:the|this|that|these|those|a|an)\b',
        caseSensitive: false,
      ).hasMatch(after);
  final naturalImperativePrompt = const {
        'accommodate',
        'recognize',
        'interpret',
        'calculate',
        'categorize',
        'enumerate',
        'determine',
        'highlight',
        'authenticate',
        'summarize',
        'translate',
        'transcribe',
        'understand',
      }.contains(naturalWord) &&
      (naturalWord != 'authenticate' ||
          openMaskPrefix.toLowerCase().startsWith('authenticat')) &&
      RegExp(r'^(?:please\s*)?$', caseSensitive: false).hasMatch(before) &&
      RegExp(
        r'^(?:the|this|that|these|those|a|an)\b',
        caseSensitive: false,
      ).hasMatch(after);
  final readDocumentationCarefullyPrompt = naturalWord == 'documentation' &&
      RegExp(
        r'\b(?:please\s+)?read\s+(?:(?:the|this|that|these|those|a|an))?$',
        caseSensitive: false,
      ).hasMatch(before) &&
      RegExp(r'^carefully\b', caseSensitive: false).hasMatch(after);
  final readAuthenticationDocumentationPrompt =
      naturalWord == 'documentation' &&
          RegExp(
            r'\b(?:please\s+)?read\s+(?:(?:the|this|that|these|those|a|an))?$',
            caseSensitive: false,
          ).hasMatch(before) &&
          RegExp(
            r'^on authentication\b',
            caseSensitive: false,
          ).hasMatch(after);
  final naturalReadFromOcrSourcePrompt = isNaturalWordContinuation &&
      RegExp(
        r'\b(?:please\s+)?read(?:\s+(?:the|this|that|these|those|a|an))?$',
        caseSensitive: false,
      ).hasMatch(before) &&
      _legacyOcrNaturalSourcePhrasePattern.hasMatch(after);
  const credentialProcessWords = {
    'authentication',
    'authorization',
    'credentialing',
    'tokenization',
    'tokenizing',
  };
  final naturalCredentialProcessSentenceWord = isNaturalWordContinuation &&
      (credentialProcessWords.contains(naturalWord) ||
          (naturalWord.endsWith('s') &&
              credentialProcessWords.contains(
                naturalWord.substring(0, naturalWord.length - 1),
              )));
  final bareNaturalProcessPromptVerbPattern = const {
    'authentication',
    'authorization'
  }.contains(naturalWord)
      ? r'\b(?:please\s+)?(?:read|explain|describe|summarize|review|discuss|outline|understand)\s*$'
      : r'\b(?:please\s+)?(?:explain|describe|summarize|review|discuss|outline|understand)\s*$';
  final naturalCredentialProcessInstructionPrompt =
      naturalCredentialProcessSentenceWord &&
          ((RegExp(
                    r'\b(?:please\s+)?(?:read|explain|summarize|describe|review|examine|include|provide|extract|identify|recognize|transcribe|translate|interpret|analyze|count|find|inspect|process|show|tell|check|look|scan|ocr|decode|calculate|categorize|enumerate|determine|highlight|understand)\s+(?:the|this|that|these|those|a|an|my|your|our|their|his|her|its)$',
                    caseSensitive: false,
                  ).hasMatch(before) &&
                  RegExp(
                    r"^[\p{L}][\p{L}\p{M}\p{N}_'-]*\b",
                    unicode: true,
                    caseSensitive: false,
                  ).hasMatch(after)) ||
              (RegExp(
                    bareNaturalProcessPromptVerbPattern,
                    caseSensitive: false,
                  ).hasMatch(before) &&
                  RegExp(
                    r'^(?:methods?|process(?:es)?|flows?|guides?|messages?|tables?|diagrams?|protocols?|systems?|settings?|mechanisms?|principles|overview|instructions?|documentation)\b',
                    caseSensitive: false,
                  ).hasMatch(after)));
  final readHandwritingInstructionPrompt =
      const {'handwriting', 'handwritten'}.contains(naturalWord) &&
          RegExp(
            r"\b(?:please\s+)?(?:read|review|examine|inspect|identify|recognize|describe|summarize|analyze|extract|interpret|count|find|transcribe|translate|classify|explain|process|show|tell|check|look|scan|ocr|decode|calculate|categorize|enumerate|determine|highlight)(?:\s+[\p{L}\p{M}\p{N}_'’-]+)*$",
            unicode: true,
            caseSensitive: false,
          ).hasMatch(before) &&
          RegExp(
            r'^(?:[\p{L}][\p{L}\p{M}\p{N}_-]*\b|[.!?]|$)',
            unicode: true,
            caseSensitive: false,
          ).hasMatch(after);
  final readNaturalNounInstructionPrompt = isNaturalWordContinuation &&
      (!_legacyOcrIsCredentialWord(naturalWord) ||
          naturalCredentialProcessSentenceWord) &&
      RegExp(
        r'\b(?:please\s+)?read\s*(?:(?:the|this|that|these|those|a|an))?$',
        caseSensitive: false,
      ).hasMatch(before) &&
      RegExp(
        r'^(?:label|document|receipt|invoice|record|image|sign|form|chart|page|sheet|table|login|guide|instructions?)\b',
        caseSensitive: false,
      ).hasMatch(after);
  final naturalReadCharacterPrompt =
      _legacyOcrIsNaturalReadCharacterPrompt(naturalWord, before);
  final naturalSecretaryInstructionPrompt =
      const {'secretary', 'secretaries'}.contains(naturalWord) &&
          RegExp(
            r'\b(?:please\s+)?ask(?:\s+(?:the|this|that|these|those|a|an))?$',
            caseSensitive: false,
          ).hasMatch(before) &&
          (after.isEmpty ||
              RegExp(r'^[a-z]+\b', caseSensitive: false).hasMatch(after) ||
              RegExp(r'^[.!?]$', caseSensitive: false).hasMatch(after));
  final naturalNounInstructionPrompt = RegExp(
        r'\b(?:please\s+)?(?:describe|review|examine|include|provide|extract|read\s+about|use)(?:\s+(?:the|this|that|these|those|a|an))?$',
        caseSensitive: false,
      ).hasMatch(before) &&
      (after.isEmpty ||
          RegExp(r'^[a-z]+\b', caseSensitive: false).hasMatch(after));
  final naturalCooperateImperativePrompt = naturalWord == 'cooperate' &&
      RegExp(r'^(?:please\s*)?$', caseSensitive: false).hasMatch(before) &&
      (after.isEmpty ||
          RegExp(
            r'^(?:[.!?]|[a-z]+(?:\s+[a-z]+)*(?:[.!?])?)$',
            caseSensitive: false,
          ).hasMatch(after));
  final naturalSecretPluralKeepPrompt = isNaturalSecretPlural &&
      RegExp(r'\b(?:please\s+)?keep$', caseSensitive: false).hasMatch(before) &&
      (after.isEmpty ||
          RegExp(
            r'''^[\p{L}][\p{L}\p{M}\p{N}\s,.'"’\-]*[.!?;:]?$''',
            unicode: true,
            caseSensitive: false,
          ).hasMatch(after));
  final naturalSecretPluralReadPrompt = isNaturalSecretPlural &&
      RegExp(
        r'\b(?:please\s+)?read(?:\s+(?:the|this|that|these|those|a|an))?$',
        caseSensitive: false,
      ).hasMatch(before) &&
      RegExp(
        r'^(?:in|from) (?:the|this|that|these|those|a|an) (?:image|picture|photo|photograph|scan|document|receipt|page)\b',
        caseSensitive: false,
      ).hasMatch(after);
  final naturalSecretPluralPrompt =
      naturalSecretPluralKeepPrompt || naturalSecretPluralReadPrompt;
  final naturalDefinitionQuestion = isNaturalWordContinuation &&
      RegExp(r'\bwhat does$', caseSensitive: false).hasMatch(before) &&
      RegExp(r'^mean\b', caseSensitive: false).hasMatch(after);
  final naturalNounSentence = (!_legacyOcrIsCredentialWord(naturalWord) ||
          naturalCredentialProcessSentenceWord) &&
      RegExp(
        r'^(?:the|this|that|these|those|a|an)$',
        caseSensitive: false,
      ).hasMatch(before) &&
      RegExp(r'^[a-z]+\b', caseSensitive: false).hasMatch(after);
  return !hasCredentialUseContext &&
      (politeNaturalVerbPrompt ||
          readDocumentationCarefullyPrompt ||
          readAuthenticationDocumentationPrompt ||
          naturalReadFromOcrSourcePrompt ||
          naturalReadCharacterPrompt ||
          naturalCredentialProcessInstructionPrompt ||
          readHandwritingInstructionPrompt ||
          readNaturalNounInstructionPrompt ||
          naturalImperativePrompt ||
          naturalSecretaryInstructionPrompt ||
          naturalNounInstructionPrompt ||
          naturalCooperateImperativePrompt ||
          naturalSecretPluralPrompt ||
          naturalDefinitionQuestion ||
          naturalNounSentence);
}

String _legacyOcrRedactNaturalWordCredentialEchoes(
  String text,
  Iterable<String> credentialValues,
) {
  var sanitized = text;
  for (final value in credentialValues) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis == null || value.substring(ellipsis.end).isNotEmpty) continue;
    final prefix =
        value.substring(0, ellipsis.start).trim().split(RegExp(r'\s+')).last;
    if (prefix.isEmpty) continue;
    final prefixPattern = prefix.split('').map(RegExp.escape).join(r'\u0000*');
    final extendedPrefix = RegExp('(^|[^a-zA-Z0-9])($prefixPattern)(\\S+)');
    sanitized = sanitized.replaceAllMapped(extendedPrefix, (match) {
      final rawSuffix = match.group(3)!;
      final suffix = rawSuffix.replaceFirst(
        RegExp(r'''[.,!?;:)\]}"'“”‘’`/*=+_~-]+$'''),
        '',
      );
      final naturalSuffix = suffix.replaceAll('\u0000', '');
      final naturalWord = '$prefix$naturalSuffix'
          .replaceAll(RegExp(r'[^a-zA-Z]'), '')
          .toLowerCase();
      final isCredentialWord = _legacyOcrIsCredentialWord(naturalWord);
      final before = sanitized.substring(0, match.start).trimRight();
      final after = sanitized.substring(match.end).trimLeft();
      final credentialNounForRequest = isCredentialWord &&
          RegExp(
            r'\b(?:use|send|provide|enter|supply)$',
            caseSensitive: false,
          ).hasMatch(before) &&
          RegExp(
            r'^for (?:the )?request\b',
            caseSensitive: false,
          ).hasMatch(after);
      final hasCredentialUseContext = _legacyOcrHasCredentialUseContext(
            sanitized,
            match,
            prefix,
            naturalSuffix,
          ) ||
          credentialNounForRequest ||
          (RegExp(r'\buse$', caseSensitive: false).hasMatch(before) &&
              RegExp(
                r'^for (?:the )?request\b',
                caseSensitive: false,
              ).hasMatch(after));
      final secretaryWord = const {
        'secretary',
        'secretaries',
      }.contains(naturalWord);
      final ordinaryNaturalPromptContext =
          _legacyOcrHasOrdinaryNaturalPromptContext(
        sanitized,
        match,
        naturalWord,
        openMaskPrefix: prefix,
        hasCredentialUseContext: hasCredentialUseContext,
        isNaturalWordContinuation: _legacyOcrHasNaturalWordContinuation(
          prefix,
          naturalSuffix,
        ),
        isNaturalSecretPlural: naturalWord == 'secrets' &&
            naturalSuffix.replaceAll('\u0000', '').toLowerCase() == 's',
      );
      final credentialWordEcho = isCredentialWord &&
          (!secretaryWord || hasCredentialUseContext) &&
          !ordinaryNaturalPromptContext;
      final ordinaryNounInflection = RegExp(
            r"^(?:s|['’]s|s['’])$",
            caseSensitive: false,
          ).hasMatch(naturalSuffix) &&
          !isCredentialWord &&
          !hasCredentialUseContext;
      final naturalWordEcho = (prefix.length >= 8 ||
              _legacyOcrCanRedactShortNaturalWordEcho(naturalWord) ||
              (naturalWord == 'authenticity' && hasCredentialUseContext)) &&
          _legacyOcrHasNaturalWordContinuation(prefix, naturalSuffix) &&
          !ordinaryNounInflection &&
          !ordinaryNaturalPromptContext;
      if (!credentialWordEcho && !naturalWordEcho) {
        return match.group(0)!;
      }
      final trailingPunctuation = rawSuffix.substring(suffix.length);
      final partBoundaryCount =
          RegExp(r'\u0000').allMatches('${match.group(2)}$rawSuffix').length;
      final preservedPartBoundaries =
          List<String>.filled(partBoundaryCount, '\u0000').join();
      return '${match.group(1)}[redacted]'
          '$preservedPartBoundaries$trailingPunctuation';
    });
  }
  return sanitized;
}

Map<String, dynamic>? _unavailableRetryDataFromLegacyRequest(
  String taskId,
  Map<String, dynamic>? rawRequest,
) {
  final imageCount = _legacyOcrImageCount(rawRequest);
  final modelId = _legacyOcrModelId(rawRequest);
  final instructionContent = _legacyOcrInstructionContent(rawRequest);
  if (imageCount == null && modelId == null && instructionContent == null) {
    return null;
  }
  return OcrRetryStorage.unavailableSnapshotForCount(
    taskId: taskId,
    imageCount: imageCount ?? 0,
    modelId: modelId,
    instructionContent: instructionContent,
  );
}

bool _isOcrCredentialField(Object? key) {
  if (key is! String) return false;
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized == 'key' ||
      normalized.contains('apikey') ||
      RegExp(
        r'(?:api|access|private|secret|subscription|client|service|consumer|encryption|signing|publishable|webhook|public|app|account|license|project|organization|org|deployment|database|db)key$',
      ).hasMatch(normalized) ||
      normalized.contains('token') ||
      normalized.contains('secret') ||
      normalized.endsWith('auth') ||
      normalized.contains('authorization') ||
      normalized.contains('bearer') ||
      normalized.contains('credential') ||
      normalized == 'password' ||
      normalized == 'passwd' ||
      normalized == 'passphrase' ||
      normalized.contains('cookie') ||
      normalized == 'signature' ||
      normalized == 'sig' ||
      normalized == 'jwt';
}

Iterable<String> _credentialValuesFromOcrRetryData(
  Map<dynamic, dynamic> retryData,
) sync* {
  Iterable<String> valuesFrom(dynamic value) sync* {
    if (value is Map) {
      for (final entry in value.entries) {
        if (_isOcrCredentialField(entry.key) &&
            entry.value is String &&
            (entry.value as String).trim().isNotEmpty) {
          yield entry.value as String;
        }
        yield* valuesFrom(entry.value);
      }
    } else if (value is Iterable) {
      for (final item in value) {
        yield* valuesFrom(item);
      }
    }
  }

  yield* valuesFrom(retryData);
}

Map<String, dynamic> _safeUnsupportedOcrRetryData(
  String taskId,
  Map<String, dynamic> malformedRetryData, {
  Map<String, dynamic>? legacyRetryData,
  required Iterable<String> credentialValues,
}) {
  final unsafeCredentialValues = <String>{
    ...credentialValues,
    ..._credentialValuesFromOcrRetryData(malformedRetryData),
  };
  final snapshot = OcrRetrySnapshot.fromMap(malformedRetryData);
  final legacySnapshot = legacyRetryData == null
      ? null
      : OcrRetrySnapshot.fromMap(legacyRetryData);

  String? safeReference(String? value) =>
      value != null && _isSafeOcrModelId(value.trim(), unsafeCredentialValues)
          ? value
          : null;

  final configId = safeReference(snapshot.configId) ??
      safeReference(legacySnapshot?.configId);
  final modelId =
      safeReference(snapshot.modelId) ?? safeReference(legacySnapshot?.modelId);
  final rawInstruction = snapshot.instructionContent;
  final instructionContent = rawInstruction != null &&
          !_legacyOcrTextContainsCredential(
            rawInstruction,
            unsafeCredentialValues,
          )
      ? rawInstruction
      : legacySnapshot?.instructionContent;

  final rawImages = malformedRetryData['images'];
  final fallbackImages = legacyRetryData?['images'];
  final rawImageCount = rawImages is List ? rawImages.length : 0;
  final fallbackImageCount = fallbackImages is List ? fallbackImages.length : 0;
  final imageCount = math.max(rawImageCount, fallbackImageCount);
  final unavailableImages = OcrRetryStorage.unavailableSnapshotForCount(
    taskId: taskId,
    imageCount: imageCount,
  )['images'] as List;
  final images = <Map<String, dynamic>>[];
  for (var index = 0; index < imageCount; index++) {
    final rawImage =
        rawImages is List && index < rawImages.length ? rawImages[index] : null;
    final fallbackImage =
        fallbackImages is List && index < fallbackImages.length
            ? fallbackImages[index]
            : null;
    final placeholder =
        Map<String, dynamic>.from(unavailableImages[index] as Map);
    final image = <String, dynamic>{
      'storageRef': placeholder['storageRef'],
      'format': 'jpeg',
    };

    final sourceImage = rawImage is Map ? rawImage : fallbackImage;
    if (sourceImage is Map) {
      final storageRef = sourceImage['storageRef'];
      if (storageRef is String &&
          OcrRetryImage.isValidStorageReference(storageRef)) {
        image['storageRef'] = storageRef;
      }
      final format = sourceImage['format'];
      if (format is String &&
          !_legacyOcrTextContainsCredential(format, unsafeCredentialValues)) {
        image['format'] = format;
      }
      final name = sourceImage['name'];
      if (name is String &&
          !_legacyOcrTextContainsCredential(name, unsafeCredentialValues)) {
        image['name'] = name;
      }
    }
    images.add(image);
  }

  final rawVersion = malformedRetryData['version'];
  final retryData = <String, dynamic>{
    'type': 'ocr',
    'version': rawVersion is int ? rawVersion : -1,
    if (configId != null || modelId != null)
      'modelRef': {
        if (configId != null) 'configId': configId,
        if (modelId != null) 'modelId': modelId,
      },
    'images': images,
    if (instructionContent != null) 'instructionContent': instructionContent,
  };

  final saveFolder = malformedRetryData['saveFolder'];
  if (saveFolder is String &&
      !_legacyOcrTextContainsCredential(saveFolder, unsafeCredentialValues)) {
    retryData['saveFolder'] = saveFolder;
  }
  final batchMode = malformedRetryData['batchMode'];
  if (batchMode == 'joint' || batchMode == 'perImage') {
    retryData['batchMode'] = batchMode;
  }
  final perImageConcurrency = malformedRetryData['perImageConcurrency'];
  if (perImageConcurrency is int &&
      perImageConcurrency >= 1 &&
      perImageConcurrency <= 2) {
    retryData['perImageConcurrency'] = perImageConcurrency;
  }
  final requestSizeBudgetBytes = malformedRetryData['requestSizeBudgetBytes'];
  if (requestSizeBudgetBytes is int && requestSizeBudgetBytes > 0) {
    retryData['requestSizeBudgetBytes'] = requestSizeBudgetBytes;
  }
  return Map<String, dynamic>.from(
    _withoutCredentialEchoes(retryData, unsafeCredentialValues) as Map,
  );
}

Map<String, dynamic> _unavailableRetryDataFromMalformed(
  String taskId,
  Map<String, dynamic> malformedRetryData, {
  Map<String, dynamic>? legacyRetryData,
  required Iterable<String> credentialValues,
}) {
  final safeCredentialValues = <String>{
    ...credentialValues,
    ..._credentialValuesFromOcrRetryData(malformedRetryData),
  };
  final malformedSnapshot = OcrRetrySnapshot.fromMap(malformedRetryData);
  final supportedVersion = malformedSnapshot.isLegacy ||
      malformedSnapshot.version == 1 ||
      malformedSnapshot.version == 2 ||
      malformedSnapshot.version == OcrRetrySnapshot.currentVersion;
  if (!supportedVersion) {
    return _safeUnsupportedOcrRetryData(
      taskId,
      malformedRetryData,
      legacyRetryData: legacyRetryData,
      credentialValues: safeCredentialValues,
    );
  }

  final legacySnapshot = legacyRetryData == null
      ? null
      : OcrRetrySnapshot.fromMap(legacyRetryData);
  final legacyImages = legacyRetryData?['images'];
  final legacyImageCount = legacyImages is List ? legacyImages.length : 0;
  final imageCount = malformedSnapshot.imageEntryCount > legacyImageCount
      ? malformedSnapshot.imageEntryCount
      : legacyImageCount;
  final malformedConfigId = malformedSnapshot.configId;
  final legacyConfigId = legacySnapshot?.configId;
  final configId = malformedConfigId != null &&
          _isSafeOcrModelId(malformedConfigId.trim(), safeCredentialValues)
      ? malformedConfigId
      : legacyConfigId != null &&
              _isSafeOcrModelId(legacyConfigId.trim(), safeCredentialValues)
          ? legacyConfigId
          : null;
  final malformedModelId = malformedSnapshot.modelId;
  final modelId = malformedModelId != null &&
          _isSafeOcrModelId(malformedModelId.trim(), safeCredentialValues)
      ? malformedModelId
      : legacySnapshot?.modelId;
  final malformedInstruction = malformedSnapshot.instructionContent;
  final instructionContent = malformedInstruction != null &&
          !_legacyOcrTextContainsCredential(
            malformedInstruction,
            safeCredentialValues,
          )
      ? malformedInstruction
      : legacySnapshot?.instructionContent;
  final malformedSaveFolder = malformedSnapshot.saveFolder;
  final retryData = OcrRetryStorage.unavailableSnapshotForCount(
    taskId: taskId,
    imageCount: imageCount,
    configId: configId,
    modelId: modelId,
    instructionContent: instructionContent,
    saveFolder: _legacyOcrTextContainsCredential(
      malformedSaveFolder,
      safeCredentialValues,
    )
        ? ''
        : malformedSaveFolder,
    batchMode: malformedSnapshot.batchMode,
    perImageConcurrency: malformedSnapshot.perImageConcurrency,
    requestSizeBudgetBytes: malformedSnapshot.requestSizeBudgetBytes,
    legacyModelIndex: malformedSnapshot.legacyModelIndex,
    legacyInstructionIndex: malformedSnapshot.legacyInstructionIndex,
  );
  final images = retryData['images'] as List;
  for (var index = 0; index < malformedSnapshot.images.length; index++) {
    final image = malformedSnapshot.images[index];
    final imageIndex = malformedSnapshot.imageEntryIndices[index];
    images[imageIndex] = {
      if (image.bytes != null) 'bytes': base64Encode(image.bytes!),
      if (image.storageRef != null) 'storageRef': image.storageRef,
      'format': image.format,
      if (image.name != null) 'name': image.name,
    };
  }
  final rawImages = malformedRetryData['images'];
  if (rawImages is List) {
    for (var index = 0; index < rawImages.length; index++) {
      final rawImage = rawImages[index];
      if (rawImage is! Map || index >= images.length) continue;
      final image = Map<String, dynamic>.from(images[index] as Map);
      final storageRef = rawImage['storageRef'];
      if (storageRef is String &&
          OcrRetryImage.isValidStorageReference(storageRef)) {
        image['storageRef'] = storageRef;
      }
      final format = rawImage['format'];
      if (format is String &&
          !_legacyOcrTextContainsCredential(format, safeCredentialValues)) {
        image['format'] = format;
      }
      final name = rawImage['name'];
      if (name is String &&
          !_legacyOcrTextContainsCredential(name, safeCredentialValues)) {
        image['name'] = name;
      }
      images[index] = image;
    }
  }
  return Map<String, dynamic>.from(
    _withoutCredentialEchoes(retryData, safeCredentialValues) as Map,
  );
}

bool _retryDataHasSupportedOcrSchema(Map<String, dynamic> retryData) {
  final snapshot = OcrRetrySnapshot.fromMap(retryData);
  final supportedVersion = snapshot.isLegacy ||
      snapshot.version == 1 ||
      snapshot.version == 2 ||
      snapshot.version == OcrRetrySnapshot.currentVersion;
  // Every persisted OCR retry format includes an image-entry list, even when
  // its entries are placeholders for images that must be selected again.
  // Keep partially parseable snapshots on the migration path to preserve
  // their valid images.
  return supportedVersion &&
      !snapshot.hasUnknownFields &&
      retryData['images'] is List &&
      (!snapshot.hasInvalidImages || snapshot.images.isNotEmpty);
}

dynamic _withoutCredentialEchoes(
  dynamic value,
  Iterable<String> credentialValues,
) {
  if (value is String) {
    return _legacyOcrTextContainsCredential(value, credentialValues)
        ? null
        : value;
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key is! String ||
            !_legacyOcrTextContainsCredential(
              entry.key as String,
              credentialValues,
            ))
          if (entry.value is! String ||
              !_legacyOcrTextContainsCredential(
                entry.value as String,
                credentialValues,
              ))
            entry.key: _withoutCredentialEchoes(entry.value, credentialValues),
    };
  }
  if (value is List) {
    return [
      for (final item in value)
        _withoutCredentialEchoes(item, credentialValues),
    ];
  }
  return value;
}

Map<String, dynamic>? _retryDataFromTaskMap(
  Map<String, dynamic> map, {
  Iterable<String> additionalCredentialValues = const [],
}) {
  final taskId = map['id'] as String;
  final rawRetryData = map['retryData'];
  final rawRequest = map['rawRequest'];
  final request =
      rawRequest is Map ? Map<String, dynamic>.from(rawRequest) : null;
  final credentialValues = <String>{
    ..._legacyOcrCredentialValues(request),
    ...additionalCredentialValues,
  };
  Map<String, dynamic>? malformedRetryData;
  if (rawRetryData is Map) {
    try {
      final retryData = Map<String, dynamic>.from(rawRetryData);
      if (map['type'] != BackgroundTaskType.ocr.name ||
          _retryDataHasSupportedOcrSchema(retryData)) {
        if (map['type'] == BackgroundTaskType.ocr.name) {
          final instructionContent = retryData['instructionContent'];
          if (instructionContent is String &&
              credentialValues.isNotEmpty &&
              _legacyOcrTextContainsCredential(
                instructionContent,
                credentialValues,
              )) {
            final safeLegacyInstruction = _legacyOcrInstructionContent(request);
            if (safeLegacyInstruction == null) {
              retryData.remove('instructionContent');
            } else {
              retryData['instructionContent'] = safeLegacyInstruction;
            }
          }
        }
        final modelRef = retryData['modelRef'];
        if (map['type'] == BackgroundTaskType.ocr.name && modelRef is Map) {
          final safeModelRef = Map<String, dynamic>.from(modelRef);
          for (final field in ['configId', 'modelId']) {
            final reference = safeModelRef[field];
            if (reference is String &&
                !_isSafeOcrModelId(reference.trim(), credentialValues)) {
              safeModelRef.remove(field);
            }
          }
          retryData['modelRef'] = safeModelRef;
        }
        final sanitizedRetryData = Map<String, dynamic>.from(
          _withoutCredentialEchoes(retryData, credentialValues) as Map,
        );
        final originalInstruction = rawRetryData['instructionContent'];
        if (map['type'] == BackgroundTaskType.ocr.name &&
            originalInstruction is String) {
          final redactedPasswordEcho =
              _legacyOcrRedactPasswordCredentialEchoAcrossLineBreak(
            originalInstruction,
            credentialValues,
          );
          if (redactedPasswordEcho != null &&
              !_legacyOcrTextContainsCredential(
                redactedPasswordEcho,
                credentialValues,
              ) &&
              !_legacyOcrTextContainsMaskedCredential(
                redactedPasswordEcho,
                credentialValues,
              )) {
            sanitizedRetryData['instructionContent'] = redactedPasswordEcho;
          }
        }
        return sanitizedRetryData;
      }
      malformedRetryData = retryData;
    } catch (_) {
      // Fall through to a safe unavailable snapshot instead of dropping task.
    }
  }
  if (map['type'] != BackgroundTaskType.ocr.name) return null;

  final unavailableRetryData = _unavailableRetryDataFromLegacyRequest(
    taskId,
    request,
  );
  if (malformedRetryData != null) {
    return _unavailableRetryDataFromMalformed(
      taskId,
      malformedRetryData,
      legacyRetryData: unavailableRetryData,
      credentialValues: credentialValues,
    );
  }
  return unavailableRetryData ??
      (rawRetryData == null
          ? null
          : OcrRetryStorage.unavailableSnapshotForCount(
              taskId: taskId,
              imageCount: 0,
            ));
}

Map<String, dynamic>? _sanitizeOcrRetryDataForConstruction({
  required String taskId,
  required Map<String, dynamic>? retryData,
  required Map<String, dynamic>? rawRequest,
  required Iterable<String> credentialValues,
}) {
  if (retryData == null) return null;
  final normalized = _retryDataFromTaskMap({
    'id': taskId,
    'type': BackgroundTaskType.ocr.name,
    'retryData': retryData,
    if (rawRequest != null) 'rawRequest': rawRequest,
  }, additionalCredentialValues: credentialValues);
  if (normalized == null) return null;
  return Map<String, dynamic>.from(
    _withoutCredentialEchoes(
      normalized,
      {
        ...credentialValues,
        ..._legacyOcrCredentialValues(rawRequest),
        ..._credentialValuesFromOcrRetryData(retryData),
      },
    ) as Map,
  );
}

List<OcrPageOutcome> _ocrPageOutcomesFromTaskMap(dynamic rawOutcomes) {
  if (rawOutcomes is! List) return const [];
  final outcomesByImageIndex = <int, OcrPageOutcome>{};
  for (final rawOutcome in rawOutcomes) {
    final outcome = OcrPageOutcome.fromMap(rawOutcome);
    if (outcome != null) {
      outcomesByImageIndex.putIfAbsent(outcome.imageIndex, () => outcome);
    }
  }
  final outcomes = outcomesByImageIndex.values.toList();
  outcomes.sort((a, b) => a.imageIndex.compareTo(b.imageIndex));
  return List.unmodifiable(outcomes);
}

/// A task model for OCR, ASR, and Audio Separation operations.
/// Uses a step chain (like CatCatch downloads) to show execution progress
/// without quantifying with percentages. Steps are task-type-specific.
class BackgroundTask {
  static final Expando<Object> _generationTokens = Expando<Object>();

  static Object _generationTokenFor(BackgroundTask task) =>
      _generationTokens[task] ??= Object();

  /// Returns whether [other] is another snapshot of this task generation.
  bool hasSameGenerationAs(BackgroundTask other) =>
      identical(_generationTokenFor(this), _generationTokenFor(other));

  final String id;
  final BackgroundTaskType type;
  final String title;
  final TaskStatus status;
  final String?
      result; // The text result (OCR extracted text, ASR transcription) — kept internally for saving
  final bool resultIsComplete;
  final String resultFolder;
  final bool partialSaveRequested;
  final bool resultSavedAsPartial;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? statusChangedAt;
  final List<BgTaskStep> steps; // Step chain for UI display
  final String?
      downloadedFilePath; // File path for "open file" button (like CatCatch)
  final Map<String, dynamic>?
      rawRequest; // Raw request data for error diagnostics
  final Map<String, dynamic>?
      rawResponse; // Raw response data for error diagnostics
  final List<String> _ocrDiagnosticCredentialValues;
  final Map<String, dynamic>?
      retryData; // Retry data to pre-populate form when retrying
  final List<OcrPageOutcome> ocrPageOutcomes;

  BackgroundTask({
    required String id,
    required BackgroundTaskType type,
    required String title,
    TaskStatus status = TaskStatus.running,
    String? result,
    bool resultIsComplete = true,
    String resultFolder = '',
    bool partialSaveRequested = false,
    bool resultSavedAsPartial = false,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? statusChangedAt,
    List<BgTaskStep> steps = const [],
    String? downloadedFilePath,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
    Map<String, dynamic>? retryData,
    List<OcrPageOutcome> ocrPageOutcomes = const [],
    Iterable<String> ocrDiagnosticCredentialValues = const [],
    Iterable<String> ocrCredentialValuesForSanitization = const [],
  }) : this._(
          id: id,
          type: type,
          title: title,
          status: status,
          result: result,
          resultIsComplete: resultIsComplete,
          resultFolder: resultFolder,
          partialSaveRequested: partialSaveRequested,
          resultSavedAsPartial: resultSavedAsPartial,
          error: error,
          createdAt: createdAt,
          completedAt: completedAt,
          statusChangedAt: statusChangedAt,
          steps: steps,
          downloadedFilePath: downloadedFilePath,
          rawRequest: rawRequest,
          rawResponse: rawResponse,
          retryData: retryData,
          ocrPageOutcomes: ocrPageOutcomes,
          ocrDiagnosticCredentialValues: ocrDiagnosticCredentialValues,
          ocrCredentialValuesForSanitization:
              ocrCredentialValuesForSanitization,
        );

  BackgroundTask._({
    required this.id,
    required this.type,
    required this.title,
    this.status = TaskStatus.running,
    this.result,
    this.resultIsComplete = true,
    this.resultFolder = '',
    this.partialSaveRequested = false,
    this.resultSavedAsPartial = false,
    String? error,
    DateTime? createdAt,
    this.completedAt,
    this.statusChangedAt,
    List<BgTaskStep> steps = const [],
    this.downloadedFilePath,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
    Map<String, dynamic>? retryData,
    bool retryDataAlreadySanitized = false,
    List<OcrPageOutcome> ocrPageOutcomes = const [],
    Iterable<String> ocrDiagnosticCredentialValues = const [],
    Iterable<String> ocrCredentialValuesForSanitization = const [],
  })  : error = type == BackgroundTaskType.ocr
            ? _sanitizeOcrTaskError(
                error,
                rawRequest,
                additionalCredentialValues: _combinedOcrCredentialValues(
                  ocrDiagnosticCredentialValues,
                  ocrCredentialValuesForSanitization,
                ),
              )
            : error,
        steps = type == BackgroundTaskType.ocr
            ? steps
                .map(
                  (step) => BgTaskStep(
                    label: step.label,
                    status: step.status,
                    error: _sanitizeOcrTaskError(
                      step.error,
                      rawRequest,
                      additionalCredentialValues: _combinedOcrCredentialValues(
                        ocrDiagnosticCredentialValues,
                        ocrCredentialValuesForSanitization,
                      ),
                    ),
                  ),
                )
                .toList(growable: false)
            : steps,
        _ocrDiagnosticCredentialValues = type == BackgroundTaskType.ocr
            ? List<String>.unmodifiable({
                ..._legacyOcrCredentialValues(rawRequest),
                ...ocrDiagnosticCredentialValues,
              })
            : const [],
        rawRequest = type == BackgroundTaskType.ocr
            ? _sanitizeOcrTaskRequest(
                rawRequest,
                additionalCredentialValues: _combinedOcrCredentialValues(
                  ocrDiagnosticCredentialValues,
                  ocrCredentialValuesForSanitization,
                ),
              )
            : rawRequest,
        rawResponse = type == BackgroundTaskType.ocr
            ? _sanitizeOcrTaskResponse(
                rawResponse,
                rawRequest,
                additionalCredentialValues: _combinedOcrCredentialValues(
                  ocrDiagnosticCredentialValues,
                  ocrCredentialValuesForSanitization,
                ),
              )
            : rawResponse,
        retryData = type == BackgroundTaskType.ocr && !retryDataAlreadySanitized
            ? _sanitizeOcrRetryDataForConstruction(
                taskId: id,
                retryData: retryData,
                rawRequest: rawRequest,
                credentialValues: _combinedOcrCredentialValues(
                  ocrDiagnosticCredentialValues,
                  ocrCredentialValuesForSanitization,
                ),
              )
            : retryData,
        ocrPageOutcomes = type == BackgroundTaskType.ocr
            ? List.unmodifiable(
                ocrPageOutcomes.map(
                  (outcome) => OcrPageOutcome(
                    imageIndex: outcome.imageIndex,
                    status: outcome.status,
                    text: outcome.text,
                    error: _sanitizeOcrTaskError(
                      outcome.error,
                      rawRequest,
                      additionalCredentialValues: _combinedOcrCredentialValues(
                        ocrDiagnosticCredentialValues,
                        ocrCredentialValuesForSanitization,
                      ),
                    ),
                  ),
                ),
              )
            : const [],
        createdAt = createdAt ?? DateTime.now();

  BackgroundTask copyWith({
    TaskStatus? status,
    String? result,
    bool? resultIsComplete,
    String? resultFolder,
    bool? partialSaveRequested,
    bool? resultSavedAsPartial,
    String? error,
    DateTime? completedAt,
    DateTime? statusChangedAt,
    List<BgTaskStep>? steps,
    String? downloadedFilePath,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
    Map<String, dynamic>? retryData,
    Iterable<String> ocrCredentialValuesForSanitization = const [],
    List<OcrPageOutcome>? ocrPageOutcomes,
    bool clearError = false,
    bool clearCompletedAt = false,
    bool clearDownloadedFilePath = false,
    bool clearRawRequest = false,
    bool clearRawResponse = false,
    bool clearRetryData = false,
  }) {
    final newStatus = status ?? this.status;
    final newStatusChangedAt = statusChangedAt ??
        (status != null && status != this.status
            ? DateTime.now()
            : this.statusChangedAt);
    final copy = BackgroundTask._(
      id: id,
      type: type,
      title: title,
      status: newStatus,
      result: result ?? this.result,
      resultIsComplete: resultIsComplete ?? this.resultIsComplete,
      resultFolder: resultFolder ?? this.resultFolder,
      partialSaveRequested: partialSaveRequested ?? this.partialSaveRequested,
      resultSavedAsPartial: resultSavedAsPartial ?? this.resultSavedAsPartial,
      error: clearError ? null : (error ?? this.error),
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      statusChangedAt: newStatusChangedAt,
      steps: steps ?? this.steps,
      downloadedFilePath: clearDownloadedFilePath
          ? null
          : (downloadedFilePath ?? this.downloadedFilePath),
      rawRequest: clearRawRequest ? null : (rawRequest ?? this.rawRequest),
      rawResponse: clearRawResponse ? null : (rawResponse ?? this.rawResponse),
      ocrPageOutcomes: ocrPageOutcomes ?? this.ocrPageOutcomes,
      ocrDiagnosticCredentialValues: _ocrDiagnosticCredentialValues,
      ocrCredentialValuesForSanitization: ocrCredentialValuesForSanitization,
      retryData: clearRetryData ? null : (retryData ?? this.retryData),
      retryDataAlreadySanitized: retryData == null &&
          rawRequest == null &&
          !clearRawRequest &&
          ocrCredentialValuesForSanitization.isEmpty,
    );
    _generationTokens[copy] = _generationTokenFor(this);
    return copy;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'title': title,
        'status': status.name,
        if (result != null) 'result': result,
        'resultIsComplete': resultIsComplete,
        if (resultFolder.isNotEmpty) 'resultFolder': resultFolder,
        'partialSaveRequested': partialSaveRequested,
        'resultSavedAsPartial': resultSavedAsPartial,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'statusChangedAt': statusChangedAt?.toIso8601String(),
        'steps': steps.map((s) => s.toMap()).toList(),
        if (downloadedFilePath != null)
          'downloadedFilePath': downloadedFilePath,
        if (type != BackgroundTaskType.ocr && rawRequest != null)
          'rawRequest': rawRequest,
        if (type != BackgroundTaskType.ocr && rawResponse != null)
          'rawResponse': rawResponse,
        if (retryData != null) 'retryData': retryData,
        if (ocrPageOutcomes.isNotEmpty)
          'ocrPageOutcomes':
              ocrPageOutcomes.map((outcome) => outcome.toMap()).toList(),
      };

  factory BackgroundTask.fromMap(Map<String, dynamic> map) {
    final type = BackgroundTaskType.values.byName(map['type'] as String);
    final rawRetryData = map['retryData'];
    final retryCredentialValues =
        type == BackgroundTaskType.ocr && rawRetryData is Map
            ? _credentialValuesFromOcrRetryData(
                rawRetryData,
              ).toList(growable: false)
            : const <String>[];
    return BackgroundTask._(
      id: map['id'] as String,
      type: type,
      title: map['title'] as String,
      status: TaskStatus.values.byName(map['status'] as String),
      result: map['result'] as String?,
      resultIsComplete: map['resultIsComplete'] as bool? ??
          !((map['error'] as String? ?? '').contains('finish_reason=length')),
      resultFolder: map['resultFolder'] as String? ?? '',
      partialSaveRequested: map['partialSaveRequested'] as bool? ?? false,
      resultSavedAsPartial: map['resultSavedAsPartial'] as bool? ?? false,
      error: map['error'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      statusChangedAt: map['statusChangedAt'] != null
          ? DateTime.parse(map['statusChangedAt'] as String)
          : null,
      steps: (map['steps'] as List?)
              ?.map(
                (s) => BgTaskStep.fromMap(Map<String, dynamic>.from(s as Map)),
              )
              .toList() ??
          [],
      downloadedFilePath: map['downloadedFilePath'] as String?,
      rawRequest: map['rawRequest'] as Map<String, dynamic>?,
      rawResponse: map['rawResponse'] as Map<String, dynamic>?,
      retryData: _retryDataFromTaskMap(map),
      retryDataAlreadySanitized: true,
      ocrPageOutcomes: _ocrPageOutcomesFromTaskMap(map['ocrPageOutcomes']),
      ocrCredentialValuesForSanitization: retryCredentialValues,
    );
  }
}

// ============================================================================
// Provider
// ============================================================================

final backgroundTasksProvider =
    StateNotifierProvider<BackgroundTaskNotifier, List<BackgroundTask>>(
  (ref) {
    final notifier = BackgroundTaskNotifier(
      localizationsResolver: () => appLocalizationsForLocale(
        ref.read(localeProvider),
      ),
    );
    ref.listen(localeProvider, (_, _) => notifier.refreshLocalizations());
    return notifier;
  },
);

class _TaskCancellationRegistration {
  final Object owner = Object();
  final void Function() cancel;

  _TaskCancellationRegistration(this.cancel);
}

class _TaskCleanupRegistration {
  final Future<void> Function() cleanup;

  _TaskCleanupRegistration(this.cleanup);
}

class BackgroundTaskNotifier extends StateNotifier<List<BackgroundTask>> {
  BackgroundTaskNotifier({AppLocalizations Function()? localizationsResolver})
      : _localizationsResolver = localizationsResolver ??
            (() => appLocalizationsForLocale(const Locale('zh'))),
        super([]);

  final AppLocalizations Function() _localizationsResolver;

  AppLocalizations get localizations => _localizationsResolver();

  void refreshLocalizations() {
    final strings = localizations;
    var changed = false;
    final localizedTasks = state.map((task) {
      final localized = _localizeRestoredBackgroundTask(task, strings);
      if (!identical(localized, task)) changed = true;
      return localized;
    }).toList(growable: false);
    if (changed) state = localizedTasks;
  }

  final _uuid = const Uuid();
  final Map<String, _TaskCancellationRegistration> _cancellations = {};
  final Map<String, Map<Object, List<_TaskCleanupRegistration>>> _taskCleanups =
      {};
  bool _retryAudioCleanupSafe = false;
  final Set<String> _pendingCompletedLegacyAsrRetryAudioIds = <String>{};
  final Set<String> _pendingSanitizedAsrRetryAudioIds = <String>{};
  // The last durable task snapshot remains authoritative until another write
  // replaces it, even when live retryData has already changed.
  final Set<String> _persistedRetryAudioIds = <String>{};
  final Set<String> _persistedOcrCacheReferences = <String>{};
  bool _ocrCacheOwnershipLoaded = false;
  bool _ocrCacheCleanupSafe = false;
  List<dynamic> _unrestoredTaskRecords = [];

  /// Whether retry audio references are complete enough to authorize pruning.
  bool get retryAudioCleanupSafe => _retryAudioCleanupSafe;

  /// Any task with retry data retains its audio ownership, including completed
  /// ASR tasks whose source snapshot has not yet cleared that retry data.
  Set<String> get retryAudioReferencedIds {
    final ids = <String>{};
    void addTaskReferences(BackgroundTask task) {
      ids.addAll(AsrRetryAudioStore.referencedIds(task.retryData));
    }

    final currentTasks =
        mounted ? state : _disposedSnapshot ?? const <BackgroundTask>[];
    for (final task in currentTasks) {
      addTaskReferences(task);
    }
    ids.addAll(_pendingCompletedLegacyAsrRetryAudioIds);
    ids.addAll(_pendingSanitizedAsrRetryAudioIds);
    ids.addAll(_pendingReplacedRestoreAsrRetryAudioIds);
    ids.addAll(_persistedRetryAudioIds);
    for (final removedTasks in _pendingTaskRemovalCleanupTasks.values) {
      for (final task in removedTasks) {
        addTaskReferences(task);
      }
    }
    for (final record in _unrestoredTaskRecords) {
      if (record is! Map || record['retryAudioOwnershipKnown'] != true) {
        continue;
      }
      final retryAudioIds = record['retryAudioIds'];
      if (retryAudioIds is List) ids.addAll(retryAudioIds.whereType<String>());
    }
    return ids;
  }

  Set<String> _retryAudioIdsInSnapshot(
    Iterable<BackgroundTask> tasks,
    Iterable<dynamic> preservedEntries,
  ) {
    final ids = <String>{};
    for (final task in tasks) {
      ids.addAll(AsrRetryAudioStore.referencedIds(task.retryData));
    }
    for (final entry in preservedEntries) {
      if (entry is! Map) continue;
      if (entry['retryAudioOwnershipKnown'] == true) {
        final retryAudioIds = entry['retryAudioIds'];
        if (retryAudioIds is List) {
          ids.addAll(retryAudioIds.whereType<String>());
        }
      } else if (entry['type'] == BackgroundTaskType.asr.name) {
        final recoveredIds = _recoverRetryAudioIds(entry);
        if (recoveredIds != null) {
          ids.addAll(recoveredIds);
        }
      }
    }
    return ids;
  }

  /// Returns a live task by ID, or null after removal or notifier disposal.
  BackgroundTask? taskById(String taskId) {
    if (!mounted) return null;
    return state.where((task) => task.id == taskId).firstOrNull;
  }

  List<BackgroundTask> get tasks => List.unmodifiable(state);

  /// Only live owned operations register callbacks; restored records do not.
  void registerCancellation(String taskId, void Function() cancel) {
    if (!mounted || !state.any((task) => task.id == taskId)) {
      cancel();
      return;
    }
    _cancellations[taskId] = _TaskCancellationRegistration(cancel);
  }

  void unregisterCancellation(String taskId) => _cancellations.remove(taskId);

  /// Register cancellation only while [taskGeneration] still owns [taskId].
  /// The returned token prevents an older run from unregistering its successor.
  Object? registerCancellationForGeneration(
    String taskId,
    BackgroundTask taskGeneration,
    void Function() cancel,
  ) {
    if (!mounted ||
        taskById(taskId)?.hasSameGenerationAs(taskGeneration) != true) {
      cancel();
      return null;
    }
    final registration = _TaskCancellationRegistration(cancel);
    _cancellations[taskId] = registration;
    return registration.owner;
  }

  void unregisterCancellationForGeneration(String taskId, Object owner) {
    if (identical(_cancellations[taskId]?.owner, owner)) {
      _cancellations.remove(taskId);
    }
  }

  void registerTaskCleanup(
    String taskId,
    Future<void> Function() cleanup, {
    BackgroundTask? taskGeneration,
  }) {
    final current = taskById(taskId);
    final generation = taskGeneration ?? current;
    if (!mounted ||
        current == null ||
        generation == null ||
        !current.hasSameGenerationAs(generation)) {
      return;
    }
    final token = BackgroundTask._generationTokenFor(generation);
    _taskCleanups
        .putIfAbsent(taskId, () => {})
        .putIfAbsent(token, () => <_TaskCleanupRegistration>[])
        .add(_TaskCleanupRegistration(cleanup));
  }

  void unregisterTaskCleanup(
    String taskId, {
    BackgroundTask? taskGeneration,
  }) {
    if (taskGeneration == null) {
      _taskCleanups.remove(taskId);
      return;
    }
    final registrations = _taskCleanups[taskId];
    registrations?.remove(BackgroundTask._generationTokenFor(taskGeneration));
    if (registrations?.isEmpty ?? false) _taskCleanups.remove(taskId);
  }

  Future<void> _runTaskCleanup(
    String taskId,
    BackgroundTask taskGeneration,
  ) async {
    final registrations = _taskCleanups[taskId]
        ?.remove(BackgroundTask._generationTokenFor(taskGeneration));
    if (registrations == null) return;
    if (_taskCleanups[taskId]?.isEmpty ?? false) _taskCleanups.remove(taskId);
    for (final registration in registrations) {
      try {
        await registration.cleanup();
      } catch (error) {
        debugPrint('[BackgroundTaskNotifier] Task cleanup failed: $error');
      }
    }
  }

  Future<void> _runTaskCleanupAfterPersistence(
    String taskId,
    Future<bool> persistence,
    BackgroundTask taskGeneration,
  ) async {
    try {
      if (!await persistence) {
        debugPrint(
          '[BackgroundTaskNotifier] Skipping task cleanup because removal persistence failed: $taskId',
        );
        return;
      }
      await _runTaskCleanup(taskId, taskGeneration);
    } catch (error) {
      debugPrint(
        '[BackgroundTaskNotifier] Could not confirm task removal persistence: $error',
      );
    }
  }

  void _queueTaskCleanupAfterRemoval(
    String taskId,
    BackgroundTask taskGeneration,
  ) {
    final cleanupTasks = _pendingTaskRemovalCleanupTasks.putIfAbsent(
      taskId,
      () => <BackgroundTask>[],
    );
    if (!cleanupTasks.any((task) => task.hasSameGenerationAs(taskGeneration))) {
      cleanupTasks.add(taskGeneration);
    }
  }

  void _runTaskCleanupsAfterSnapshotPersisted(
    List<BackgroundTask> persistedTasks,
  ) {
    final cleanupTasks = <(String, BackgroundTask)>[];
    for (final entry in _pendingTaskRemovalCleanupTasks.entries.toList()) {
      final remaining = <BackgroundTask>[];
      for (final removedTask in entry.value) {
        final generationWasPersisted = persistedTasks.any(
          (task) =>
              task.id == entry.key && task.hasSameGenerationAs(removedTask),
        );
        if (generationWasPersisted) {
          remaining.add(removedTask);
        } else {
          cleanupTasks.add((entry.key, removedTask));
        }
      }
      if (remaining.isEmpty) {
        _pendingTaskRemovalCleanupTasks.remove(entry.key);
      } else {
        _pendingTaskRemovalCleanupTasks[entry.key] = remaining;
      }
    }
    for (final (taskId, task) in cleanupTasks) {
      unawaited(_runTaskCleanup(taskId, task));
    }
  }

  void cancelTask(String taskId) {
    final registration = _cancellations.remove(taskId);
    if (registration == null) return;
    final task = taskById(taskId);
    registration.cancel();
    if (!mounted ||
        task == null ||
        taskById(taskId)?.hasSameGenerationAs(task) != true) {
      return;
    }
    setSteps(
      taskId,
      task.steps
          .map(
            (step) => step.copyWith(
              status: step.running
                  ? BgStepStatus.failed
                  : step.status == BgStepStatus.pending
                      ? BgStepStatus.skipped
                      : step.status,
            ),
          )
          .toList(),
    );
    if (!mounted || taskById(taskId)?.hasSameGenerationAs(task) != true) {
      return;
    }
    failTask(taskId, error: localizations.bgTaskCancelled);
  }

  /// 测试专用：覆盖持久化目录。
  ///
  /// 持久化测试需要隔离的目录（真实测试环境所有测试共享同一个
  /// AppStorage 目录，异步写入链可能跨测试交错，导致读脏数据）。
  @visibleForTesting
  static String? debugStorageDirectoryOverride;

  /// Widget tests can keep task state in memory while filesystem futures are
  /// exercised separately by persistence-focused tests.
  @visibleForTesting
  static bool debugDisablePersistence = false;

  @visibleForTesting
  static Future<void> Function()? debugBeforeOcrCacheCleanup;

  @visibleForTesting
  static Future<void> Function()? debugBeforeOcrCacheDelete;

  @visibleForTesting
  static Future<void> Function()? debugBeforeTaskSnapshotWrite;

  @visibleForTesting
  static Future<void> Function()? debugBeforeTaskSnapshotRead;

  @visibleForTesting
  static Future<void> Function()? debugAfterTaskSnapshotRead;

  @visibleForTesting
  static Future<void> Function(String taskId)?
      debugBeforeLegacyAsrRetryMigration;

  @override
  void dispose() {
    for (final registration in _cancellations.values.toList()) {
      registration.cancel();
    }
    _cancellations.clear();
    _taskCleanups.clear();
    _pendingRestoreTaskRemovalOwnershipIds.clear();
    _disposedSnapshot = List.of(state);
    _iosSyncTimer?.cancel();
    _iosSyncTimer = null;
    super.dispose();
  }

  /// Add a new background task and return its ID.
  /// Caller-supplied [taskId] values must not belong to a live task.
  /// Initializes default step chain based on task type.
  /// [retryData] stores the original input parameters (images, audio, model, etc.)
  /// so the retry flow can pre-populate the form.
  /// When [startImmediately] is true (default), the task starts as [TaskStatus.running].
  /// When false, the task starts as [TaskStatus.waiting] and can be started later via [startTask].
  String addTask({
    required BackgroundTaskType type,
    required String title,
    Map<String, dynamic>? retryData,
    bool startImmediately = true,
    String? taskId,
  }) {
    final id = taskId ?? _uuid.v4();
    final existingTasks = state.where((task) => task.id == id).toList();
    final removalOwnsId = _activeBatchRemovalAddedGenerations.any(
      (removal) => removal.containsKey(id),
    );
    if (existingTasks.isNotEmpty && !removalOwnsId) {
      throw ArgumentError.value(id, 'taskId', 'already belongs to a live task');
    }
    for (final existingTask in existingTasks) {
      _queueTaskCleanupAfterRemoval(id, existingTask);
    }
    _pendingRestoreTaskRemovals.remove(id);
    _pendingTaskRemovalReconciliations.remove(id);
    final steps = type
        .localizedStepLabels(localizations)
        .map((label) => BgTaskStep(label: label, status: BgStepStatus.pending))
        .toList();
    final task = BackgroundTask(
      id: id,
      type: type,
      title: title,
      status: startImmediately ? TaskStatus.running : TaskStatus.waiting,
      steps: steps,
      retryData: retryData,
    );
    final generation = BackgroundTask._generationTokenFor(task);
    for (final activeRemoval in _activeBatchRemovalAddedGenerations) {
      activeRemoval[id]?.add(generation);
    }
    state = [
      task,
      ...state.where((existingTask) => existingTask.id != id),
    ];
    _persistTasks(preserveSkippedEntries: true);
    _syncIosContinuedTask();
    return id;
  }

  /// Start a waiting task — transitions it from [TaskStatus.waiting] to [TaskStatus.running].
  /// Does nothing if the task is not in waiting status (e.g. already running/completed).
  void startTask(String taskId) {
    startTaskIfWaiting(taskId);
  }

  /// Atomically claim a waiting task for execution.
  ///
  /// A queue uses the return value to avoid starting a task removed or
  /// canceled while it was waiting.
  bool startTaskIfWaiting(String taskId) {
    final index = state.indexWhere((task) => task.id == taskId);
    if (index == -1 || state[index].status != TaskStatus.waiting) return false;
    final tasks = [...state];
    tasks[index] = tasks[index].copyWith(
      status: TaskStatus.running,
      statusChangedAt: DateTime.now(),
    );
    state = tasks;
    _persistTasks();
    _syncIosContinuedTask();
    return true;
  }

  bool startTaskIfWaitingForGeneration(
    String taskId,
    BackgroundTask taskGeneration,
  ) {
    final index = state.indexWhere(
      (task) => task.id == taskId && task.hasSameGenerationAs(taskGeneration),
    );
    if (index == -1 || state[index].status != TaskStatus.waiting) return false;
    final tasks = [...state];
    tasks[index] = tasks[index].copyWith(
      status: TaskStatus.running,
      statusChangedAt: DateTime.now(),
    );
    state = tasks;
    _persistTasks();
    _syncIosContinuedTask();
    return true;
  }

  /// Mark a task as completed and keep it in the list (visible to user).
  /// Optionally provide [downloadedFilePath] for the "open file" button.
  void completeTask(
    String taskId, {
    String? downloadedFilePath,
    bool resultSavedAsPartial = false,
  }) {
    _updateTask(
      taskId,
      TaskStatus.completed,
      downloadedFilePath: downloadedFilePath,
      resultSavedAsPartial: resultSavedAsPartial,
    );
  }

  Future<bool> clearDownloadedFilePath(String taskId) {
    if (!mounted) return Future<bool>.value(false);
    state = state
        .map((task) => task.id == taskId
            ? task.copyWith(clearDownloadedFilePath: true)
            : task)
        .toList();
    return _persistTasks();
  }

  /// Mark a task as failed with an optional error message.
  void failTask(
    String taskId, {
    String? error,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
    Iterable<String> ocrCredentialValuesForSanitization = const [],
  }) {
    final task = taskById(taskId);
    if (task != null &&
        task.type == BackgroundTaskType.ocr &&
        task.retryData != null &&
        (_pendingTaskRemovalReconciliations.containsKey(taskId) ||
            (task.status == TaskStatus.waiting &&
                _isBackgroundTaskCancellationError(task.error)))) {
      // Cancellation callbacks and stale runners can report failure while
      // removal is in progress or after rollback. Keep the retry task's
      // cancellation outcome instead of notifying for a stale failure.
      return;
    }
    _updateTask(
      taskId,
      TaskStatus.failed,
      error: error,
      rawRequest: rawRequest,
      rawResponse: rawResponse,
      ocrCredentialValuesForSanitization: ocrCredentialValuesForSanitization,
    );
  }

  /// Set the result text for a task (OCR extracted text, ASR transcription, etc.).
  /// Can be called multiple times to update partial/intermediate results.
  /// The result is kept internally for file saving but NOT displayed in the card UI.
  void setResult(
    String taskId,
    String result, {
    bool isComplete = true,
    String? folder,
  }) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(
        result: result,
        resultIsComplete: isComplete,
        resultFolder: folder,
        error: t.error,
      );
    }).toList();
    _persistTasks();
  }

  /// Persist ordered per-image status so task cards and retries keep context.
  void setOcrPageOutcomes(String taskId, List<OcrPageOutcome> outcomes) {
    final ordered = outcomes.toList()
      ..sort((a, b) => a.imageIndex.compareTo(b.imageIndex));
    state = state
        .map(
          (task) => task.id == taskId
              ? task.copyWith(ocrPageOutcomes: List.unmodifiable(ordered))
              : task,
        )
        .toList();
    _persistTasks();
  }

  /// Persist the explicit user choice to save an incomplete OCR result.
  Future<bool> markPartialResultSaveRequested(String taskId) {
    state = state
        .map(
          (task) => task.id == taskId
              ? task.copyWith(partialSaveRequested: true)
              : task,
        )
        .toList();
    return _persistTasks();
  }

  /// Reopen the save step for a failed OCR task whose result is still present.
  bool startSaveRetry(String taskId) {
    final task = taskById(taskId);
    if (task == null ||
        task.type != BackgroundTaskType.ocr ||
        task.status != TaskStatus.failed ||
        task.result == null) {
      return false;
    }
    state = state.map((task) {
      if (task.id != taskId) return task;
      final steps = [...task.steps];
      if (steps.length > 4) {
        steps[4] = steps[4].copyWith(
          status: BgStepStatus.running,
          clearError: true,
        );
      }
      return task.copyWith(
        status: TaskStatus.running,
        clearError: true,
        clearCompletedAt: true,
        statusChangedAt: DateTime.now(),
        steps: steps,
      );
    }).toList();
    _persistTasks();
    _syncIosContinuedTask();
    return true;
  }

  /// Set the full step chain for a task.
  void setSteps(String taskId, List<BgTaskStep> steps) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(steps: steps);
    }).toList();
    _persistTasks();
    _syncIosContinuedTask();
  }

  /// Set raw request/response diagnostic data for error viewing.
  void setRawDiagnostics(
    String taskId, {
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
    Iterable<String> ocrCredentialValuesForSanitization = const [],
  }) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(rawRequest: rawRequest, rawResponse: rawResponse);
    }).toList();
    _persistTasks();
  }

  /// Update a single step by index (e.g. mark as completed/running/failed).
  void updateStep(
    String taskId,
    int index, {
    bool? completed,
    bool? running,
    bool? failed,
    bool? skipped,
    String? error,
    String? label,
  }) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      final steps = [...t.steps];
      if (index < 0 || index >= steps.length) return t;
      BgStepStatus newStatus;
      if (completed == true) {
        newStatus = BgStepStatus.completed;
      } else if (running == true) {
        newStatus = BgStepStatus.running;
      } else if (failed == true) {
        newStatus = BgStepStatus.failed;
      } else if (skipped == true) {
        newStatus = BgStepStatus.skipped;
      } else {
        return t; // no change
      }
      steps[index] = steps[index].copyWith(
        status: newStatus,
        error: error,
        label: label,
      );
      return t.copyWith(steps: steps);
    }).toList();
    _persistTasks();
    _syncIosContinuedTask();
  }

  /// Remove a task from the list.
  void removeTask(String taskId) {
    if (_taskSnapshotIncomplete) {
      if (!state.any((task) => task.id == taskId)) return;
      // Keep the task visible until a partial snapshot can be safely written,
      // so the UI cannot claim a deletion that will return on restart.
      unawaited(removeTasksPersisted([taskId]));
      return;
    }
    if (!state.any((task) => task.id == taskId) &&
        _pendingTaskRemovalReconciliations.containsKey(taskId)) {
      // The in-flight removal owns reconciliation for the persisted task.
      // A duplicate request must not replace its rollback token.
      return;
    }
    final removalToken = _recordPendingRestoreTaskRemoval(taskId);
    _pendingTaskRemovalReconciliations[taskId] = removalToken;
    if (_restoreBarrier != null) {
      // Even when a different generation with this ID is in state, the
      // in-flight snapshot may still contain an older disk generation whose
      // retry audio remains owned until its removal is durable.
      _pendingRestoreTaskRemovalOwnershipIds.add(taskId);
    }
    final originalSnapshot = List<BackgroundTask>.of(state);
    _cancellations.remove(taskId)?.cancel();
    final removedTasks = state.where((task) => task.id == taskId).toList();
    for (final task in removedTasks) {
      _queueTaskCleanupAfterRemoval(taskId, task);
    }
    final removed = removedTasks.firstOrNull;
    state = state.where((t) => t.id != taskId).toList();
    final Future<bool> persistence;
    if (removed?.type == BackgroundTaskType.ocr) {
      final references = OcrRetryStorage.referencesFromSnapshot(
        removed!.retryData,
      );
      persistence = _persistOcrTaskRemoval(
        taskId,
        references,
        removedTask: removed!,
        removalToken: removalToken,
        originalSnapshot: originalSnapshot,
      );
    } else {
      persistence = _persistTasks(
        excludedPersistedTaskIds: {taskId},
        retryOnceOnRemovalWriteFailure: true,
      );
    }
    _syncIosContinuedTask();
    for (final task in removedTasks) {
      unawaited(
        _runTaskCleanupAfterPersistence(taskId, persistence, task),
      );
    }
  }

  /// Save removals before publishing them; absent IDs also retry disk cleanup.
  Future<bool> removeTasksPersisted(Iterable<String> ids) async {
    final removedIds = ids.toSet();
    final addedTaskGenerations = <String, Set<Object>>{
      for (final id in removedIds) id: <Object>{},
    };
    _activeBatchRemovalAddedGenerations.add(addedTaskGenerations);
    final suppressedNotificationGenerations = <Object>[];
    try {
      for (final id in removedIds) {
        final task = taskById(id);
        if (task == null) continue;
        final generation = BackgroundTask._generationTokenFor(task);
        suppressedNotificationGenerations.add(generation);
        _taskNotificationSuppressionGenerationCounts.update(
          generation,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      for (final id in removedIds) {
        cancelTask(id);
      }
      while (_removalBarrier != null) {
        await _removalBarrier!.future;
      }
      if (!mounted) return false;
      if (removedIds.isEmpty) return true;

      final gate = Completer<void>();
      _removalBarrier = gate;
      try {
        final removedTasks =
            state.where((task) => removedIds.contains(task.id)).toList();
        // A same-ID task added after this request began is a new generation
        // and must survive even when this request waited behind another batch.
        bool isNotRemovedTaskGeneration(BackgroundTask task) {
          if (!removedIds.contains(task.id)) return true;
          final generation = BackgroundTask._generationTokenFor(task);
          return addedTaskGenerations[task.id]?.contains(generation) ?? false;
        }

        final tasksToCleanup = removedTasks
            .where((task) => !isNotRemovedTaskGeneration(task))
            .toList();
        final proposed = state.where(isNotRemovedTaskGeneration).toList();
        final retainedAddedTaskIds = {
          for (final task in proposed)
            if (removedIds.contains(task.id)) task.id,
        };
        final excludedPersistedTaskIds = removedIds.difference(
          retainedAddedTaskIds,
        );
        if (!await _writeSnapshot(
          proposed,
          preserveSkippedEntries: _taskSnapshotIncomplete,
          excludedPersistedTaskIds: excludedPersistedTaskIds,
        )) {
          return false;
        }
        if (_restoreBarrier != null) {
          for (final id in removedIds) {
            if (retainedAddedTaskIds.contains(id)) continue;
            _recordPendingRestoreTaskRemoval(id);
          }
        }
        final cacheCandidates = <String>{
          for (final task in removedTasks)
            if (task.type == BackgroundTaskType.ocr)
              ...OcrRetryStorage.referencesFromSnapshot(task.retryData),
        };
        final currentTasks = mounted ? state : (_disposedSnapshot ?? const []);
        cacheCandidates.addAll({
          for (final task in currentTasks)
            if (removedIds.contains(task.id) &&
                task.type == BackgroundTaskType.ocr)
              ...OcrRetryStorage.referencesFromSnapshot(task.retryData),
        });
        if (mounted) {
          state = state.where(isNotRemovedTaskGeneration).toList();
          _syncIosContinuedTask();
        }
        if (!mounted) {
          // Deferred ordinary writes own this snapshot after disposal. Only a
          // successful removal may remove these IDs from its final flush.
          _disposedSnapshot =
              _disposedSnapshot?.where(isNotRemovedTaskGeneration).toList();
        }
        await _deleteUnreferencedOcrCache(cacheCandidates);
        for (final task in tasksToCleanup) {
          await _runTaskCleanup(task.id, task);
        }
        return true;
      } finally {
        _removalBarrier = null;
        gate.complete();
      }
    } finally {
      _activeBatchRemovalAddedGenerations.remove(addedTaskGenerations);
      for (final generation in suppressedNotificationGenerations) {
        final count = _taskNotificationSuppressionGenerationCounts[generation];
        if (count == 1) {
          _taskNotificationSuppressionGenerationCounts.remove(generation);
        } else if (count != null) {
          _taskNotificationSuppressionGenerationCounts[generation] = count - 1;
        }
      }
    }
  }

  Future<void> _deleteUnreferencedOcrCache(Set<String> candidates) async {
    if (candidates.isEmpty) return;
    try {
      await OcrRetryStorage.withCacheMaintenanceLock(() async {
        await debugBeforeOcrCacheDelete?.call();
        final referenced = await _ocrCacheReferencesForCleanup();
        if (referenced == null) return;
        await OcrRetryStorage.deleteUnreferenced(
          candidates: candidates,
          referenced: referenced,
        );
      });
    } catch (error) {
      debugPrint('[BackgroundTaskNotifier] OCR cache cleanup failed: $error');
    }
  }

  Future<void> _cleanupOrphanedOcrCache() async {
    if (_taskSnapshotIncomplete) return;
    try {
      await OcrRetryStorage.withCacheMaintenanceLock(() async {
        final beforeCleanup = debugBeforeOcrCacheCleanup;
        if (beforeCleanup != null) await beforeCleanup();
        final referenced = await _ocrCacheReferencesForCleanup();
        if (referenced == null) return;
        await OcrRetryStorage.cleanupUnreferencedCache(referenced: referenced);
      });
    } catch (error) {
      debugPrint('[BackgroundTaskNotifier] OCR cache sweep failed: $error');
    }
  }

  Future<bool> _persistOcrTaskRemoval(
    String taskId,
    Set<String> references, {
    required BackgroundTask removedTask,
    required Object removalToken,
    required List<BackgroundTask> originalSnapshot,
  }) {
    if (debugDisablePersistence) return Future<bool>.value(true);
    final dirOverride = debugStorageDirectoryOverride;
    Future<bool> finish(bool saved) async {
      if (saved) {
        await _deleteUnreferencedOcrCache(references);
        await _cleanupOrphanedOcrCache();
      } else {
        final restored = _restoreOcrTaskAfterFailedRemoval(
          removedTask,
          removalToken: removalToken,
          originalSnapshot: originalSnapshot,
        );
        final snapshot = mounted ? state : _disposedSnapshot;
        if (restored && snapshot != null) {
          await _writeSnapshotNow(
            snapshot,
            dirOverride,
            taskSnapshotEpoch: _taskSnapshotEpoch,
            preserveSkippedEntries: _taskSnapshotIncomplete,
            retryOnceOnRemovalWriteFailure: true,
          );
        }
      }
      return saved;
    }

    final barrier = _removalBarrier;
    if (barrier == null) {
      final write = _writeSnapshot(
        state,
        excludedPersistedTaskIds: {taskId},
        retryOnceOnRemovalWriteFailure: true,
      );
      final persistence = write.then(finish);
      _pendingWrite = persistence.then<void>((_) {});
      return persistence;
    }

    final previous = _pendingWrite ?? Future<void>.value();
    final taskSnapshotEpoch = _taskSnapshotEpoch;
    final deferred = previous.then((_) async {
      await barrier.future;
      final snapshot = mounted ? state : _disposedSnapshot;
      if (snapshot == null) return finish(false);
      final saved = await _writeSnapshotNow(
        snapshot,
        dirOverride,
        taskSnapshotEpoch: taskSnapshotEpoch,
        excludedPersistedTaskIds: {taskId},
        retryOnceOnRemovalWriteFailure: true,
        preserveSkippedEntries: _taskSnapshotIncomplete,
      );
      return finish(saved);
    });
    _pendingWrite = deferred.then<void>((_) {});
    if (!mounted) _disposedPersistence = _pendingWrite;
    return deferred;
  }

  bool _restoreOcrTaskAfterFailedRemoval(
    BackgroundTask task, {
    required Object removalToken,
    required List<BackgroundTask> originalSnapshot,
  }) {
    final taskId = task.id;
    if (!identical(_pendingTaskRemovalReconciliations[taskId], removalToken)) {
      return false;
    }
    final snapshot = mounted ? state : _disposedSnapshot;
    if (snapshot == null) return false;

    var restoredTask = false;
    if (!snapshot.any((current) => current.id == taskId)) {
      final restored = List<BackgroundTask>.of(snapshot);
      final removedIndex = originalSnapshot.indexWhere(
        (original) =>
            original.id == taskId && original.hasSameGenerationAs(task),
      );
      int? restoreIndex;
      for (var index = removedIndex + 1;
          index >= 0 && index < originalSnapshot.length;
          index++) {
        final olderTask = originalSnapshot[index];
        final currentIndex = restored.indexWhere(
          (current) =>
              current.id == olderTask.id &&
              current.hasSameGenerationAs(olderTask),
        );
        if (currentIndex >= 0) {
          restoreIndex = currentIndex;
          break;
        }
      }
      if (restoreIndex == null) {
        for (var index = removedIndex - 1; index >= 0; index--) {
          final newerTask = originalSnapshot[index];
          final currentIndex = restored.indexWhere(
            (current) =>
                current.id == newerTask.id &&
                current.hasSameGenerationAs(newerTask),
          );
          if (currentIndex >= 0) {
            restoreIndex = currentIndex + 1;
            break;
          }
        }
      }
      // Tasks added while the removal was pending are newer and belong ahead
      // of the restored generation when no original neighbor survives.
      final wasRunningBeforeCancellation = originalSnapshot.any(
        (original) =>
            original.id == taskId &&
            original.hasSameGenerationAs(task) &&
            original.status == TaskStatus.running,
      );
      final canceledWhileRunning = task.status == TaskStatus.running ||
          (wasRunningBeforeCancellation && task.status == TaskStatus.failed);
      final taskToRestore = canceledWhileRunning
          ? task.copyWith(
              status: TaskStatus.waiting,
              clearCompletedAt: true,
              error: localizations.bgTaskCancelled,
              steps: task.steps
                  .map(
                    (step) => step.copyWith(
                      status: step.running
                          ? BgStepStatus.failed
                          : step.status == BgStepStatus.pending
                              ? BgStepStatus.skipped
                              : step.status,
                    ),
                  )
                  .toList(),
            )
          : task;
      restored.insert(restoreIndex ?? restored.length, taskToRestore);
      _taskSnapshotEpoch++;
      restoredTask = true;
      if (mounted) {
        state = restored;
        _syncIosContinuedTask();
      } else {
        _disposedSnapshot = restored;
      }
    }
    if (identical(_pendingRestoreTaskRemovals[taskId], removalToken)) {
      _pendingRestoreTaskRemovals.remove(taskId);
    }
    if (identical(_pendingTaskRemovalReconciliations[taskId], removalToken)) {
      _pendingTaskRemovalReconciliations.remove(taskId);
    }
    return restoredTask;
  }

  /// Update the retry data for a task (used to set retry data after
  /// computing it asynchronously via isolate).
  void setRetryData(String taskId, Map<String, dynamic>? retryData) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(retryData: retryData);
    }).toList();
    _persistTasks();
  }

  Future<bool> setRetryDataAndWait(
    String taskId,
    Map<String, dynamic>? retryData,
  ) {
    state = state.map((task) {
      if (task.id != taskId) return task;
      return task.copyWith(retryData: retryData);
    }).toList();
    return _persistTasks();
  }

  Future<bool> setRetryDataAndWaitForGeneration(
    String taskId,
    BackgroundTask taskGeneration,
    Map<String, dynamic>? retryData,
  ) {
    var updated = false;
    state = state.map((task) {
      if (task.id != taskId || !task.hasSameGenerationAs(taskGeneration)) {
        return task;
      }
      updated = true;
      return task.copyWith(retryData: retryData);
    }).toList();
    return updated ? _persistTasks() : Future<bool>.value(false);
  }

  Future<bool> clearRetryData(String taskId) {
    state = state.map((task) {
      if (task.id != taskId) return task;
      return task.copyWith(clearRetryData: true);
    }).toList();
    return _persistTasks();
  }

  Future<bool> clearRetryDataForGeneration(
    String taskId,
    BackgroundTask taskGeneration,
  ) {
    var updated = false;
    state = state.map((task) {
      if (task.id != taskId || !task.hasSameGenerationAs(taskGeneration)) {
        return task;
      }
      updated = true;
      return task.copyWith(clearRetryData: true);
    }).toList();
    return updated ? _persistTasks() : Future<bool>.value(false);
  }

  void _updateTask(
    String taskId,
    TaskStatus status, {
    String? error,
    String? downloadedFilePath,
    bool? resultSavedAsPartial,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
    Iterable<String> ocrCredentialValuesForSanitization = const [],
  }) {
    BackgroundTask? updatedTask;
    state = state.map((t) {
      if (t.id != taskId) return t;
      final shouldClearError = error == null && status == TaskStatus.completed;
      final updated = t.copyWith(
        status: status,
        error: error,
        clearError: shouldClearError,
        downloadedFilePath: downloadedFilePath,
        resultSavedAsPartial: resultSavedAsPartial,
        rawRequest: rawRequest,
        rawResponse: rawResponse,
        ocrCredentialValuesForSanitization: ocrCredentialValuesForSanitization,
        completedAt:
            status == TaskStatus.completed || status == TaskStatus.failed
                ? DateTime.now()
                : null,
      );
      updatedTask = updated;
      return updated;
    }).toList();
    _persistTasks();

    // Send notification when task completes or fails
    if ((status == TaskStatus.completed || status == TaskStatus.failed) &&
        updatedTask != null &&
        !_taskNotificationSuppressionGenerationCounts.containsKey(
          BackgroundTask._generationTokenFor(updatedTask!),
        )) {
      final notificationError = updatedTask!.type == BackgroundTaskType.ocr
          ? updatedTask!.error
          : error;
      _sendTaskNotification(updatedTask!, status, notificationError);
    }
    _syncIosContinuedTask();
  }

  void _sendTaskNotification(
    BackgroundTask task,
    TaskStatus status,
    String? error,
  ) {
    // Fire-and-forget: notifications should never crash the task state update
    try {
      final future = NotificationService().showTaskCompletionNotification(
        taskId: task.id,
        title: task.title,
        typeLabel: task.type.localizedLabel(localizations),
        success: status == TaskStatus.completed,
        error: error,
      );
      // Handle async errors silently
      unawaited(future.catchError((_) {}));
    } catch (e) {
      debugPrint('[BackgroundTaskNotifier] Failed to send notification: $e');
    }
  }
  // ==========================================================================
  // iOS 26+ 常驻后台任务同步（BGContinuedProcessingTask）
  // ==========================================================================

  /// 周期同步间隔：单个步骤可能耗时数分钟（上传/转写），期间步骤
  /// 进度不动，系统会认为任务停滞（可能提示用户或优先终止）。
  /// 周期重报进度可避免该问题。
  static const _iosSyncInterval = Duration(seconds: 30);

  /// 周期性重报进度的定时器（仅在存在运行中任务时激活）。
  Timer? _iosSyncTimer;

  /// 最近一次上报的进度百分比：多任务并行时新增任务会稀释占比，
  /// 用单调递增值避免系统进度条回退。
  int _iosLastPercent = 0;

  /// 将当前任务运行状态同步给 iOS 常驻后台桥接。
  ///
  /// - 有任务运行：维持常驻任务（原生侧已激活时自动跳过重复提交），
  ///   并上报进度（已完成步骤占比，单调不降）。
  /// - 没有任务运行：通知系统常驻任务完成。
  ///
  /// 自愈说明：任务被系统终止后，原生侧引用清空，下一次同步会自动
  /// 重新提交建立保护；但系统只接受前台状态下的提交，因此若 App
  /// 仍在后台，自愈会推迟到 App 回到前台后的下一次同步（周期定时器
  /// 或状态变更触发）。
  void _syncIosContinuedTask() {
    if (!IosContinuedTaskService.instance.isSupported) return;
    final running = state.where((t) => t.status == TaskStatus.running).toList();
    if (running.isEmpty) {
      _iosSyncTimer?.cancel();
      _iosSyncTimer = null;
      _iosLastPercent = 0;
      unawaited(IosContinuedTaskService.instance.complete());
      return;
    }
    // 存在运行中任务：启动周期重报定时器（幂等）。
    _iosSyncTimer ??= Timer.periodic(
      _iosSyncInterval,
      (_) => _syncIosContinuedTask(),
    );
    unawaited(
      IosContinuedTaskService.instance.submit(
        title: localizations.iosContinuedTaskTitle,
      ),
    );
    final totalSteps = running.fold<int>(0, (sum, t) => sum + t.steps.length);
    final doneSteps = running.fold<int>(
      0,
      (sum, t) =>
          sum +
          t.steps
              .where(
                (s) =>
                    s.status == BgStepStatus.completed ||
                    s.status == BgStepStatus.skipped,
              )
              .length,
    );
    final rawPercent = totalSteps == 0
        ? 0
        : ((doneSteps * 100) / totalSteps).round().clamp(0, 99);
    final percent = rawPercent > _iosLastPercent ? rawPercent : _iosLastPercent;
    _iosLastPercent = percent;
    unawaited(IosContinuedTaskService.instance.updateProgress(percent));
  }
  // ============================================================================
  // Persistence
  // ============================================================================

  /// 写入链：保证多次 _persistTasks 按调用顺序落盘，避免并发写入
  /// 交错导致旧快照覆盖新快照（步骤更新非常频繁，竞态窗口真实存在）。
  Future<void>? _pendingWrite;
  // Writes queued before a failed optimistic removal must serialize the
  // restored state, rather than replay their stale taskless snapshots.
  int _taskSnapshotEpoch = 0;
  Completer<void>? _removalBarrier;
  Completer<void>? _restoreBarrier;
  Future<bool>? _activeRestore;
  int _restoreGeneration = 0;
  final Map<String, Object> _pendingRestoreTaskRemovals = <String, Object>{};
  final Map<String, Object> _pendingTaskRemovalReconciliations =
      <String, Object>{};
  // Preserve retry audio from a persisted task shadowed by an in-memory task
  // with the same ID until the replacement snapshot is durably written.
  final Set<String> _pendingReplacedRestoreAsrRetryAudioIds = <String>{};
  // A same-ID re-add clears removal tokens so the new task can be persisted,
  // but an in-flight restore may still have read an older disk generation.
  final Set<String> _pendingRestoreTaskRemovalOwnershipIds = <String>{};
  // Keep cleanup bound to the removed generation until a snapshot confirms it
  // is absent, even when the original removal write fails.
  final Map<String, List<BackgroundTask>> _pendingTaskRemovalCleanupTasks =
      <String, List<BackgroundTask>>{};
  final List<Map<String, Set<Object>>> _activeBatchRemovalAddedGenerations = [];
  final Map<Object, int> _taskNotificationSuppressionGenerationCounts =
      <Object, int>{};
  Future<List<BackgroundTask>?>? _preRestorePersistedTasks;
  List<BackgroundTask>? _disposedSnapshot;
  Future<void>? _disposedPersistence;
  // Preserve the authoritative file after a partial restore; later state
  // mutations must not serialize only the tasks that could be parsed.
  bool _taskSnapshotIncomplete = false;
  bool _taskSnapshotCanPreserveSkippedEntries = false;
  List<dynamic> _skippedTaskEntries = const [];

  Object _recordPendingRestoreTaskRemoval(String taskId) {
    final token = Object();
    _pendingRestoreTaskRemovals[taskId] = token;
    return token;
  }

  void _clearPendingRestoreTaskRemovals(Map<String, Object> removals) {
    for (final entry in removals.entries) {
      if (identical(_pendingRestoreTaskRemovals[entry.key], entry.value)) {
        _pendingRestoreTaskRemovals.remove(entry.key);
      }
    }
  }

  /// Wait for queued task writes before releasing their storage directory.
  Future<void> get pendingPersistence => _pendingWrite ?? Future<void>.value();

  Future<bool> _persistTasks({
    bool preserveSkippedEntries = false,
    Set<String> excludedPersistedTaskIds = const <String>{},
    bool retryOnceOnRemovalWriteFailure = false,
  }) {
    if (debugDisablePersistence) return Future<bool>.value(true);
    final taskSnapshotEpoch = _taskSnapshotEpoch;
    final preserveCurrentSkippedEntries =
        preserveSkippedEntries || _taskSnapshotIncomplete;
    final barrier = _removalBarrier;
    final restoreBarrier = _restoreBarrier;
    if (barrier != null || restoreBarrier != null) {
      if (!mounted && _disposedPersistence != null) {
        return _disposedPersistence!.then((_) => false);
      }
      final previous = _pendingWrite ?? Future<void>.value();
      final dirOverride = debugStorageDirectoryOverride;
      final deferred = previous.then((_) async {
        if (barrier != null) await barrier.future;
        if (restoreBarrier != null) await restoreBarrier.future;
        final snapshot = mounted ? state : _disposedSnapshot;
        if (snapshot == null) return false;
        return _writeSnapshotNow(
          snapshot,
          dirOverride,
          taskSnapshotEpoch: taskSnapshotEpoch,
          preserveSkippedEntries: restoreBarrier != null
              ? _taskSnapshotIncomplete
              : preserveCurrentSkippedEntries,
          excludedPersistedTaskIds: excludedPersistedTaskIds,
          retryOnceOnRemovalWriteFailure: retryOnceOnRemovalWriteFailure,
        );
      });
      _pendingWrite = deferred.then<void>((_) {});
      if (!mounted) _disposedPersistence = _pendingWrite;
      return deferred;
    }
    if (!mounted) {
      final snapshot = _disposedSnapshot;
      if (snapshot == null) return Future<bool>.value(false);
      final disposedPersistence = _disposedPersistence;
      if (disposedPersistence != null) {
        return disposedPersistence.then((_) => false);
      }
      final write = _writeSnapshot(
        snapshot,
        preserveSkippedEntries: preserveCurrentSkippedEntries,
        excludedPersistedTaskIds: excludedPersistedTaskIds,
        retryOnceOnRemovalWriteFailure: retryOnceOnRemovalWriteFailure,
      );
      _disposedPersistence = write.then<void>((_) {});
      return write;
    }
    return _writeSnapshot(
      state,
      preserveSkippedEntries: preserveCurrentSkippedEntries,
      excludedPersistedTaskIds: excludedPersistedTaskIds,
      retryOnceOnRemovalWriteFailure: retryOnceOnRemovalWriteFailure,
    );
  }

  Future<bool> _writeSnapshot(
    List<BackgroundTask> snapshot, {
    bool preserveSkippedEntries = false,
    Set<String> excludedPersistedTaskIds = const <String>{},
    bool retryOnceOnRemovalWriteFailure = false,
  }) {
    if (_taskSnapshotIncomplete &&
        (!preserveSkippedEntries ||
            !_canSafelyPreserveSkippedEntries(snapshot))) {
      return Future<bool>.value(false);
    }
    // 同样在调用时捕获持久化目录覆盖值：写入链可能延迟到调用之后
    // 才真正执行，若此时再解析目录，测试 teardown 已重置覆盖值，
    // 残留写入会落到共享的正式目录（跨测试污染）。
    final dirOverride = debugStorageDirectoryOverride;
    final taskSnapshotEpoch = _taskSnapshotEpoch;
    // 串行化写入：每次写入排在上一次写入完成之后。
    final write = (_pendingWrite ?? Future<void>.value()).then((_) {
      return _writeSnapshotNow(
        snapshot,
        dirOverride,
        taskSnapshotEpoch: taskSnapshotEpoch,
        preserveSkippedEntries: preserveSkippedEntries,
        excludedPersistedTaskIds: excludedPersistedTaskIds,
        retryOnceOnRemovalWriteFailure: retryOnceOnRemovalWriteFailure,
      );
    });
    _pendingWrite = write.then<void>((_) {});
    return write;
  }

  Future<bool> _writeSnapshotNow(
    List<BackgroundTask> snapshot,
    String? dirOverride, {
    required int taskSnapshotEpoch,
    bool preserveSkippedEntries = false,
    Set<String> excludedPersistedTaskIds = const <String>{},
    bool retryOnceOnRemovalWriteFailure = false,
  }) async {
    final excludedTaskIds = <String>{
      ...excludedPersistedTaskIds,
      ..._pendingRestoreTaskRemovals.keys,
      ..._pendingTaskRemovalReconciliations.keys,
    };
    final pendingRemovalTokens = Map<String, Object>.of(
      _pendingRestoreTaskRemovals,
    );
    final taskRemovalTokens = Map<String, Object>.of(
      _pendingTaskRemovalReconciliations,
    );
    final sourceSnapshot = taskSnapshotEpoch == _taskSnapshotEpoch
        ? snapshot
        : mounted
            ? state
            : _disposedSnapshot;
    if (sourceSnapshot == null) return false;
    var currentSnapshot = sourceSnapshot
        .where((task) => !excludedTaskIds.contains(task.id))
        .toList();
    var preserveCurrentSkippedEntries = preserveSkippedEntries;

    if (_restoreBarrier != null) {
      await _waitForRestoreBarrier();
      final latestSnapshot = mounted ? state : _disposedSnapshot;
      if (latestSnapshot == null) return false;
      currentSnapshot = latestSnapshot
          .where((task) => !excludedTaskIds.contains(task.id))
          .toList();
      preserveCurrentSkippedEntries = _taskSnapshotIncomplete;
    }

    if (_restoreGeneration == 0) {
      final generationBeforeLoad = _restoreGeneration;
      final persistedTasks = await _loadPreRestorePersistedTasks(dirOverride);
      if (generationBeforeLoad != _restoreGeneration ||
          _restoreBarrier != null ||
          taskSnapshotEpoch != _taskSnapshotEpoch) {
        await _waitForRestoreBarrier();
        final latestSnapshot = mounted ? state : _disposedSnapshot;
        if (latestSnapshot == null) return false;
        currentSnapshot = latestSnapshot
            .where((task) => !excludedTaskIds.contains(task.id))
            .toList();
        preserveCurrentSkippedEntries = _taskSnapshotIncomplete;
      }
      if (persistedTasks == null) return false;
      currentSnapshot = [
        for (final task in persistedTasks)
          if (!excludedTaskIds.contains(task.id) &&
              !currentSnapshot.any((current) => current.id == task.id))
            task,
        ...currentSnapshot,
      ];
    }

    final canPreserveSkippedEntries = _taskSnapshotIncomplete &&
        preserveCurrentSkippedEntries &&
        _canSafelyPreserveSkippedEntries(currentSnapshot);
    if (_taskSnapshotIncomplete && !canPreserveSkippedEntries) {
      return false;
    }
    for (final task in currentSnapshot) {
      if (task.type != BackgroundTaskType.asr ||
          _ocrCacheReferencesInPersistedValue({
            'rawRequest': task.rawRequest,
            'rawResponse': task.rawResponse,
          }).isEmpty ||
          _unrestoredTaskRecords.any(
            (record) =>
                record is Map &&
                record['ocrCacheOwnershipKnown'] == false &&
                record['ocrCacheTaskId'] == task.id,
          )) {
        continue;
      }
      // ASR diagnostics are sanitized before serialization. Record their
      // cache ownership while the raw fields are still available so the
      // durable snapshot cannot make a live reference invisible.
      _unrestoredTaskRecords.add(
        _unrestoredTaskRecord(
          retryAudioOwnershipKnown: true,
          ocrCacheOwnershipKnown: false,
          ocrCacheTaskId: task.id,
        ),
      );
      _ocrCacheCleanupSafe = false;
    }
    final skippedEntries = canPreserveSkippedEntries
        ? List<dynamic>.unmodifiable(_skippedTaskEntries)
        : const <dynamic>[];
    final retireUnrestoredRecords = _restoreGeneration > 0;
    // A durable replacement snapshot removes an unknown task row and all of
    // its discarded fields. Keep its credential-free diagnostic marker while
    // resolving OCR ownership; conservatively retain unknown audio ownership.
    final unrestoredRecords = List<dynamic>.unmodifiable([
      for (final record in _unrestoredTaskRecords)
        if (!retireUnrestoredRecords ||
            record is! Map ||
            record['retireAfterSnapshot'] != true)
          if (retireUnrestoredRecords &&
              record is Map &&
              record['ocrCacheOwnershipKnown'] == false &&
              record['ocrCacheTaskId'] is String &&
              !currentSnapshot.any(
                (task) => task.id == record['ocrCacheTaskId'],
              ) &&
              !skippedEntries.any(
                (entry) =>
                    entry is Map && entry['id'] == record['ocrCacheTaskId'],
              ))
            _unrestoredTaskRecord(
              retryAudioOwnershipKnown:
                  record['retryAudioOwnershipKnown'] == true,
              retryAudioIds: {
                if (record['retryAudioIds'] is List)
                  for (final id in record['retryAudioIds'] as List)
                    if (id is String) id,
              },
              ocrCacheOwnershipKnown: true,
            )
          else
            record,
    ]);
    final preservedEntries = [...skippedEntries, ...unrestoredRecords];
    final saved = _hasCacheMigrations(currentSnapshot)
        ? await OcrRetryStorage.withCacheMaintenanceLock(
            () => _writePreparedSnapshot(
              currentSnapshot,
              dirOverride,
              preservedEntries: preservedEntries,
            ),
          )
        : await _writePreparedSnapshot(
            currentSnapshot,
            dirOverride,
            preservedEntries: preservedEntries,
          );
    // Retry a failed removal once from current state to retain a same-ID task
    // added while the first snapshot write was pending.
    if (!saved && retryOnceOnRemovalWriteFailure) {
      final latestSnapshot = mounted ? state : _disposedSnapshot;
      if (latestSnapshot == null) return false;
      final retryExcludedTaskIds = <String>{
        for (final id in excludedPersistedTaskIds)
          if (_pendingRestoreTaskRemovals.containsKey(id) ||
              _pendingTaskRemovalReconciliations.containsKey(id))
            id,
      };
      return _writeSnapshotNow(
        latestSnapshot,
        dirOverride,
        taskSnapshotEpoch: taskSnapshotEpoch,
        preserveSkippedEntries: preserveCurrentSkippedEntries,
        excludedPersistedTaskIds: retryExcludedTaskIds,
      );
    }
    if (saved) {
      if (retireUnrestoredRecords) {
        _unrestoredTaskRecords = List<dynamic>.of(unrestoredRecords);
      }
      _persistedRetryAudioIds
        ..clear()
        ..addAll(_retryAudioIdsInSnapshot(currentSnapshot, preservedEntries));
      _pendingCompletedLegacyAsrRetryAudioIds.clear();
      _pendingSanitizedAsrRetryAudioIds.clear();
      _pendingReplacedRestoreAsrRetryAudioIds.clear();
      if (retireUnrestoredRecords) {
        _retryAudioCleanupSafe = _pendingCompletedLegacyAsrRetryAudioIds
                .isEmpty &&
            !_hasUntrackedSkippedAsrAudioOwnership(_skippedTaskEntries) &&
            _unrestoredTaskRecords.every(
              (record) =>
                  record is Map && record['retryAudioOwnershipKnown'] == true,
            );
      }
      final reconciledTaskIds = <String>{};
      for (final entry in taskRemovalTokens.entries) {
        if (identical(
          _pendingTaskRemovalReconciliations[entry.key],
          entry.value,
        )) {
          reconciledTaskIds.add(entry.key);
          _pendingTaskRemovalReconciliations.remove(entry.key);
        }
      }
      if (reconciledTaskIds.isNotEmpty) {
        if (mounted) {
          state = state
              .where((task) => !reconciledTaskIds.contains(task.id))
              .toList();
        }
        _disposedSnapshot = _disposedSnapshot
            ?.where((task) => !reconciledTaskIds.contains(task.id))
            .toList();
      }
      final restoreBarrier = _restoreBarrier;
      if (restoreBarrier == null || restoreBarrier.isCompleted) {
        _clearPendingRestoreTaskRemovals(pendingRemovalTokens);
      }
      await _removePersistedTasksFromPreRestoreCache(excludedTaskIds);
      _runTaskCleanupsAfterSnapshotPersisted(currentSnapshot);
    }
    return saved;
  }

  Future<void> _removePersistedTasksFromPreRestoreCache(Set<String> ids) async {
    if (ids.isEmpty) return;
    final cached = _preRestorePersistedTasks;
    if (cached == null) return;
    final tasks = await cached;
    if (tasks == null) return;
    _preRestorePersistedTasks = Future<List<BackgroundTask>?>.value(
      tasks.where((task) => !ids.contains(task.id)).toList(),
    );
  }

  Future<void> _waitForRestoreBarrier() async {
    var barrier = _restoreBarrier;
    while (barrier != null && !barrier.isCompleted) {
      await barrier.future;
      barrier = _restoreBarrier;
    }
  }

  Future<List<BackgroundTask>?> _loadPreRestorePersistedTasks(
    String? dirOverride,
  ) async {
    final cached = _preRestorePersistedTasks;
    if (cached != null) return cached;
    final loaded = await _loadPersistedTasks(
      dirOverride: dirOverride,
      waitForDebugRead: false,
    );
    if (!loaded.isReadable) return null;
    if (!loaded.isComplete) {
      _taskSnapshotIncomplete = true;
      _taskSnapshotCanPreserveSkippedEntries = true;
      _skippedTaskEntries = loaded.skippedEntries;
      if (_restoreGeneration == 0) {
        // Parsed tasks are only cached here; retryAudioReferencedIds cannot
        // see them until restore publishes them into state. Keep pruning
        // disabled until the restore path recomputes ownership.
        _retryAudioCleanupSafe = false;
      }
      _unrestoredTaskRecords = loaded.unrestoredRecords;
    }
    final tasks = loaded.tasks;
    _preRestorePersistedTasks = Future<List<BackgroundTask>?>.value(tasks);
    return tasks;
  }

  Future<bool> _writePreparedSnapshot(
    List<BackgroundTask> snapshot,
    String? dirOverride, {
    List<dynamic> preservedEntries = const [],
  }) async {
    final preparedAsr = _prepareAsrRetriesForPersistence(snapshot);
    if (preparedAsr == null) return false;
    final prepared = await _prepareOcrRetriesForPersistence(preparedAsr);
    if (prepared == null) return false;
    _publishPreparedRetrySnapshots(snapshot, prepared);
    final data = <dynamic>[
      ...prepared.map((task) => task.toMap()),
      ...preservedEntries,
    ];
    final saved = await _writeSnapshotData(data, dirOverride);
    if (saved) {
      _persistedOcrCacheReferences
        ..clear()
        ..addAll(
          _ocrCacheReferencesFromTasksAndEntries(prepared, preservedEntries),
        );
      _ocrCacheOwnershipLoaded = true;
      _ocrCacheCleanupSafe = _hasKnownOcrCacheOwnership(
        prepared,
        preservedEntries,
      );
    }
    return saved;
  }

  List<BackgroundTask>? _prepareAsrRetriesForPersistence(
    List<BackgroundTask> snapshot,
  ) {
    final prepared = List<BackgroundTask>.of(snapshot);
    for (var index = 0; index < prepared.length; index++) {
      final task = prepared[index];
      if (task.type != BackgroundTaskType.asr) continue;
      // ASR transport diagnostics may contain provider credentials or audio
      // payloads. Keep them available to the current UI session, but do not
      // write raw request/response bodies into the task snapshot.
      final safeError = task.error == null
          ? null
          : AsrRetryConfigSnapshot.sanitizeDiagnosticText(task.error!);
      final safeSteps = [
        for (final step in task.steps)
          BgTaskStep(
            label: step.label,
            status: step.status,
            error: step.error == null
                ? null
                : AsrRetryConfigSnapshot.sanitizeDiagnosticText(step.error!),
          ),
      ];
      final diagnosticsChanged = task.rawRequest != null ||
          task.rawResponse != null ||
          safeError != task.error ||
          List.generate(task.steps.length, (i) => i).any(
            (i) => safeSteps[i].error != task.steps[i].error,
          );
      var preparedTask = task;
      if (diagnosticsChanged) {
        preparedTask = task.copyWith(
          error: safeError,
          steps: safeSteps,
          clearRawRequest: true,
          clearRawResponse: true,
        );
      }
      if (task.retryData == null) {
        prepared[index] = preparedTask;
        continue;
      }
      // Legacy rows are migrated by restore and scheduler preparation, which
      // own the correct storage adapter and know when all input bytes are
      // durable. A direct in-memory legacy value has not gone through that
      // migration, so omit it from this snapshot while leaving it available
      // to the scheduler for migration.
      if (!task.retryData!.containsKey('version')) {
        if (!_canSafelyPreserveLegacyAsrRetryData(task.retryData)) {
          debugPrint(
            '[BackgroundTaskNotifier] Omitting unsafe legacy ASR retry data from snapshot for ${task.id}',
          );
          prepared[index] = preparedTask.copyWith(clearRetryData: true);
          continue;
        }
        prepared[index] = preparedTask;
        continue;
      }
      final retryData = AsrRetryAudioStore.sanitizeVersionedRetryData(
        task.retryData,
        allowUnknownChunkStatuses: true,
      );
      if (retryData == null) {
        debugPrint(
          '[BackgroundTaskNotifier] Refusing unsafe ASR retry data for ${task.id}',
        );
        return null;
      }
      try {
        if (jsonEncode(retryData) != jsonEncode(task.retryData)) {
          preparedTask = preparedTask.copyWith(retryData: retryData);
        }
      } on Object {
        return null;
      }
      prepared[index] = preparedTask;
    }
    return prepared;
  }

  bool _canSafelyPreserveSkippedEntries(List<BackgroundTask> snapshot) {
    if (!_taskSnapshotCanPreserveSkippedEntries ||
        !_canSafelySerializeKnownTasks(snapshot)) {
      return false;
    }
    for (final entry in _skippedTaskEntries) {
      if (entry is! Map) return false;
      if (entry.keys.any((key) => key is! String) ||
          entry.containsKey('rawRequest') ||
          entry.containsKey('rawResponse')) {
        return false;
      }
      final error = entry['error'];
      if (error != null &&
          (error is! String || _sanitizeOcrTaskError(error, null) != error)) {
        return false;
      }
      final rawSteps = entry['steps'];
      if (rawSteps != null) {
        if (rawSteps is! List) return false;
        for (final rawStep in rawSteps) {
          if (rawStep is! Map) continue;
          final stepError = rawStep['error'];
          if (stepError != null &&
              (stepError is! String ||
                  _sanitizeOcrTaskError(stepError, null) != stepError)) {
            return false;
          }
        }
      }
      final entryType = entry['type'];
      if (entryType == BackgroundTaskType.asr.name) {
        if (!_canSafelyPreserveSkippedAsrEntry(entry)) return false;
        continue;
      }
      if (entryType != BackgroundTaskType.ocr.name) {
        if (BackgroundTaskType.values.any((type) => type.name == entryType)) {
          continue;
        }
        return false;
      }
      final retryData = entry['retryData'];
      if (retryData == null) continue;
      if (retryData is! Map) return false;
      try {
        final retrySnapshot = OcrRetrySnapshot.fromMap(
          Map<String, dynamic>.from(retryData),
        );
        if (retrySnapshot.version != OcrRetrySnapshot.currentVersion ||
            retrySnapshot.needsMigration ||
            retrySnapshot.hasInvalidImages ||
            retrySnapshot.images.any((image) => image.bytes != null)) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  bool _canSafelySerializeKnownTasks(List<BackgroundTask> snapshot) {
    for (final task in snapshot) {
      if (task.retryData == null) continue;
      if (task.type == BackgroundTaskType.asr) {
        if (!task.retryData!.containsKey('version') ||
            !AsrRetryAudioStore.hasValidVersionedReferences(task.retryData) ||
            AsrRetryAudioStore.recoverableReferencedIds(task.retryData) ==
                null) {
          return false;
        }
        continue;
      }
      if (task.type != BackgroundTaskType.ocr) continue;
      try {
        final retrySnapshot = OcrRetrySnapshot.fromMap(task.retryData!);
        if (retrySnapshot.version != OcrRetrySnapshot.currentVersion ||
            retrySnapshot.needsMigration ||
            retrySnapshot.hasInvalidImages ||
            retrySnapshot.hasInvalidImageMetadata ||
            retrySnapshot.images.any((image) => image.bytes != null)) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// Returns every safely known OCR cache owner, or null when the persisted
  /// task snapshot cannot be read safely enough to authorize deletion.
  Future<Set<String>?> ocrCacheReferencesForCleanup() =>
      _ocrCacheReferencesForCleanup();

  /// Uses the already loaded snapshot while OCR cache maintenance is locked.
  Set<String>? ocrCacheReferencesFromLoadedSnapshotForCleanup() {
    if (!_ocrCacheOwnershipLoaded || !_ocrCacheCleanupSafe) return null;
    final tasks = mounted ? state : (_disposedSnapshot ?? const []);
    return {
      for (final task in tasks)
        ..._ocrCacheReferencesInPersistedValue(task.toMap()),
      ..._persistedOcrCacheReferences,
      ..._referencesFromSkippedTaskEntries(),
      for (final removedTasks in _pendingTaskRemovalCleanupTasks.values)
        for (final task in removedTasks)
          ..._ocrCacheReferencesInPersistedValue(task.toMap()),
    };
  }

  Future<Set<String>?> _ocrCacheReferencesForCleanup() async {
    final persisted = await _loadPersistedTasks();
    if (!persisted.isReadable || !persisted.ocrCacheCleanupSafe) return null;
    final tasks = mounted ? state : (_disposedSnapshot ?? const []);
    return _ocrCacheReferencesFromTasksAndEntries(
      [...tasks, ...persisted.tasks],
      [..._skippedTaskEntries, ...persisted.skippedEntries],
    );
  }

  bool _canSafelyCollectSkippedOcrCacheReferences(Object? retryData) {
    if (retryData == null) return true;
    if (retryData is! Map) return false;
    try {
      final data = Map<String, dynamic>.from(retryData);
      final type = data['type'];
      if ((type != null && type != BackgroundTaskType.ocr.name) ||
          data['images'] is! List) {
        return false;
      }
      data['type'] ??= BackgroundTaskType.ocr.name;
      final snapshot = OcrRetrySnapshot.fromMap(data);
      final supportedVersion = snapshot.isLegacy ||
          snapshot.version == 1 ||
          snapshot.version == 2 ||
          snapshot.version == OcrRetrySnapshot.currentVersion;
      if (!supportedVersion) {
        // A future version makes image execution unsupported, but its
        // recognized image references still have known ownership. Unknown
        // fields and malformed image metadata remain fail-closed.
        return !snapshot.hasUnknownFields &&
            !snapshot.hasInvalidImageMetadata &&
            snapshot.imageEntryCount == snapshot.images.length;
      }
      return !snapshot.hasUnknownFields &&
          !snapshot.hasInvalidImages &&
          !snapshot.hasInvalidImageMetadata;
    } catch (_) {
      return false;
    }
  }

  Set<String> _ocrCacheReferencesInPersistedValue(Object? value) {
    final references = <String>{};
    final pending = <Object?>[value];
    final referencePattern = RegExp(r'ocr_retry_cache/[0-9a-f]{64}\.bin');
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (current is Map) {
        for (final entry in current.entries) {
          pending
            ..add(entry.key)
            ..add(entry.value);
        }
      } else if (current is List) {
        pending.addAll(current);
      } else if (current is String) {
        for (final match in referencePattern.allMatches(current)) {
          final reference = match.group(0);
          if (reference != null &&
              OcrRetryImage.isValidStorageReference(reference)) {
            references.add(reference);
          }
        }
      }
    }
    return references;
  }

  bool _requiresDurableOcrCacheOwnershipMarker(Object? retryData) {
    if (retryData is! Map) {
      return _ocrCacheReferencesInPersistedValue(retryData).isNotEmpty;
    }
    try {
      final data = Map<String, dynamic>.from(retryData);
      final rawCacheReferences = _ocrCacheReferencesInPersistedValue(data);
      final version = data['version'];
      bool containsCacheReference(Object? value) =>
          _ocrCacheReferencesInPersistedValue(value).isNotEmpty;
      if (data['type'] != null && data['type'] != BackgroundTaskType.ocr.name) {
        return rawCacheReferences.isNotEmpty;
      }
      if (version is int &&
          version > OcrRetrySnapshot.currentVersion &&
          rawCacheReferences.isNotEmpty) {
        final futureData = {...data, 'type': BackgroundTaskType.ocr.name};
        final snapshot = OcrRetrySnapshot.fromMap(futureData);
        final rawImages = futureData['images'];
        final referencesOutsideStorageRefs = <String>{
          ..._ocrCacheReferencesInPersistedValue(
            Map<String, dynamic>.from(futureData)..remove('images'),
          ),
          if (futureData.containsKey('images') && rawImages is! List)
            ..._ocrCacheReferencesInPersistedValue(rawImages),
          if (rawImages is List)
            for (final image in rawImages)
              ..._ocrCacheReferencesInPersistedValue(
                image is Map
                    ? (Map<dynamic, dynamic>.of(image)..remove('storageRef'))
                    : image,
              ),
        };
        // The unsupported-version migration discards every input image. Once
        // that transformed snapshot is durable, its recognized storageRefs
        // can be collected. Refs in unknown fields or malformed image shapes
        // still require a durable owner marker until the task is removed.
        return snapshot.hasUnknownFields ||
            snapshot.hasInvalidImageMetadata ||
            snapshot.imageEntryCount != snapshot.images.length ||
            referencesOutsideStorageRefs.isNotEmpty;
      }
      final modelIndex = data['modelIndex'];
      if (modelIndex != null &&
          modelIndex is! int &&
          containsCacheReference(modelIndex)) {
        return true;
      }
      final instructionIndex = data['instructionIndex'];
      if (instructionIndex != null &&
          instructionIndex is! int &&
          containsCacheReference(instructionIndex)) {
        return true;
      }
      final instructionContent = data['instructionContent'];
      if (instructionContent != null &&
          instructionContent is! String &&
          containsCacheReference(instructionContent)) {
        return true;
      }
      final saveFolder = data['saveFolder'];
      if (saveFolder != null &&
          saveFolder is! String &&
          containsCacheReference(saveFolder)) {
        return true;
      }
      final batchMode = data['batchMode'];
      if (batchMode != null &&
          (batchMode is! String ||
              (batchMode != OcrBatchMode.joint.name &&
                  batchMode != OcrBatchMode.perImage.name)) &&
          containsCacheReference(batchMode)) {
        return true;
      }
      final perImageConcurrency = data['perImageConcurrency'];
      if (perImageConcurrency != null &&
          (perImageConcurrency is! int ||
              perImageConcurrency < 1 ||
              perImageConcurrency > 2) &&
          containsCacheReference(perImageConcurrency)) {
        return true;
      }
      final requestSizeBudgetBytes = data['requestSizeBudgetBytes'];
      if (requestSizeBudgetBytes != null &&
          (requestSizeBudgetBytes is! int || requestSizeBudgetBytes <= 0) &&
          containsCacheReference(requestSizeBudgetBytes)) {
        return true;
      }

      const snapshotFields = {
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
      // These historical extensions are known credential/inline-body fields;
      // sanitizing them cannot discard another cache reference.
      const sanitizedNonOwnershipFields = {'apiKey', 'imageData'};
      for (final entry in data.entries) {
        final key = entry.key;
        if (key is! String) {
          if (containsCacheReference(key) ||
              containsCacheReference(entry.value)) {
            return true;
          }
          continue;
        }
        if (snapshotFields.contains(key)) continue;
        if (!sanitizedNonOwnershipFields.contains(key) ||
            (entry.value != null && entry.value is! String)) {
          if (containsCacheReference(key) ||
              containsCacheReference(entry.value)) {
            return true;
          }
          continue;
        }
        if (containsCacheReference(key) ||
            containsCacheReference(entry.value)) {
          return true;
        }
      }
      final modelRef = data['modelRef'];
      if (modelRef != null &&
          modelRef is! Map &&
          containsCacheReference(modelRef)) {
        return true;
      }
      if (modelRef is Map) {
        const modelReferenceFields = {'configId', 'modelId'};
        for (final entry in modelRef.entries) {
          if (entry.key is! String ||
              !modelReferenceFields.contains(entry.key) ||
              (entry.value != null && entry.value is! String)) {
            if (containsCacheReference(entry.key) ||
                containsCacheReference(entry.value)) {
              return true;
            }
            continue;
          }
          if (containsCacheReference(entry.key) ||
              containsCacheReference(entry.value)) {
            return true;
          }
        }
      }
      final images = data['images'];
      if (images != null && images is! List && containsCacheReference(images)) {
        return true;
      }
      if (images is List) {
        const imageFields = {'storageRef', 'format', 'name', 'bytes'};
        for (final image in images) {
          if (image is! Map) {
            if (containsCacheReference(image)) return true;
            continue;
          }
          for (final entry in image.entries) {
            final key = entry.key;
            if (key is! String) {
              if (containsCacheReference(key) ||
                  containsCacheReference(entry.value)) {
                return true;
              }
              continue;
            }
            if (imageFields.contains(key)) continue;
            if (!sanitizedNonOwnershipFields.contains(key) ||
                (entry.value != null && entry.value is! String)) {
              if (containsCacheReference(key) ||
                  containsCacheReference(entry.value)) {
                return true;
              }
              continue;
            }
            if (containsCacheReference(key) ||
                containsCacheReference(entry.value)) {
              return true;
            }
          }
          final storageRef = image['storageRef'];
          if (storageRef != null &&
              (storageRef is! String ||
                  !OcrRetryImage.isValidStorageReference(storageRef)) &&
              containsCacheReference(storageRef)) {
            return true;
          }
          final format = image['format'];
          if (format != null &&
              format is! String &&
              containsCacheReference(format)) {
            return true;
          }
          final name = image['name'];
          if (name != null && name is! String && containsCacheReference(name)) {
            return true;
          }
          final bytes = image['bytes'];
          if (bytes != null &&
              bytes is! String &&
              containsCacheReference(bytes)) {
            return true;
          }
        }
      }
      if (rawCacheReferences.isNotEmpty) {
        final snapshot = OcrRetrySnapshot.fromMap(data);
        final retainedReferences = {
          for (final image in snapshot.images)
            if (image.storageRef != null) image.storageRef!,
        };
        if (!retainedReferences.containsAll(rawCacheReferences)) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  bool _hasUnserializedTaskOcrCacheReferences(Map<dynamic, dynamic> taskRow) {
    bool containsCacheReference(Object? value) =>
        _ocrCacheReferencesInPersistedValue(value).isNotEmpty;

    if (taskRow['type'] != BackgroundTaskType.ocr.name &&
        containsCacheReference(taskRow['retryData'])) {
      // ASR persistence rebuilds supported retryData from a whitelist; an OCR
      // cache ref in that non-OCR payload may be dropped by the sanitizer.
      return true;
    }

    bool hasDroppedCollectionReferences(
      Object? rawEntries,
      Set<String> serializedFields,
      bool Function(Map<dynamic, dynamic>) hasValidShape,
    ) {
      if (rawEntries == null) return false;
      if (rawEntries is! List) return containsCacheReference(rawEntries);
      for (final rawEntry in rawEntries) {
        if (rawEntry is! Map) {
          if (containsCacheReference(rawEntry)) return true;
          continue;
        }
        if (!hasValidShape(rawEntry)) {
          if (containsCacheReference(rawEntry)) return true;
          continue;
        }
        for (final entry in rawEntry.entries) {
          if ((entry.key is! String || !serializedFields.contains(entry.key)) &&
              (containsCacheReference(entry.key) ||
                  containsCacheReference(entry.value))) {
            return true;
          }
        }
      }
      return false;
    }

    if (hasDroppedCollectionReferences(
      taskRow['steps'],
      const {'label', 'status', 'error'},
      (step) =>
          step['label'] is String &&
          (step['status'] == null ||
              (step['status'] is String &&
                  BgStepStatus.values.any(
                    (status) => status.name == step['status'],
                  ))) &&
          (step['error'] == null || step['error'] is String),
    )) {
      return true;
    }
    if (hasDroppedCollectionReferences(
      taskRow['ocrPageOutcomes'],
      const {'imageIndex', 'status', 'text', 'error'},
      (outcome) =>
          outcome['imageIndex'] is int &&
          (outcome['imageIndex'] as int) >= 0 &&
          outcome['status'] is String &&
          OcrPageOutcomeStatus.values.any(
            (status) => status.name == outcome['status'],
          ) &&
          (outcome['text'] == null || outcome['text'] is String) &&
          (outcome['error'] == null || outcome['error'] is String),
    )) {
      return true;
    }

    const serializedTaskFields = {
      'id',
      'type',
      'title',
      'status',
      'result',
      'resultIsComplete',
      'resultFolder',
      'partialSaveRequested',
      'resultSavedAsPartial',
      'error',
      'createdAt',
      'completedAt',
      'statusChangedAt',
      'steps',
      'downloadedFilePath',
      'retryData',
      'ocrPageOutcomes',
    };
    for (final entry in taskRow.entries) {
      final isRawDiagnosticField =
          entry.key == 'rawRequest' || entry.key == 'rawResponse';
      final rawDiagnosticsAreSanitized =
          taskRow['type'] == BackgroundTaskType.ocr.name ||
              taskRow['type'] == BackgroundTaskType.asr.name;
      final isDiscardedField = (!serializedTaskFields.contains(entry.key) &&
              !(!rawDiagnosticsAreSanitized && isRawDiagnosticField)) ||
          (rawDiagnosticsAreSanitized && isRawDiagnosticField);
      if (isDiscardedField &&
          (containsCacheReference(entry.key) ||
              containsCacheReference(entry.value))) {
        return true;
      }
    }
    return false;
  }

  Set<String> _referencesFromSkippedTaskEntries([Iterable<dynamic>? entries]) {
    final references = <String>{};
    for (final entry in entries ?? _skippedTaskEntries) {
      if (entry is! Map) continue;
      final serializedFields = Map<dynamic, dynamic>.of(entry)
        ..remove('retryData');
      references.addAll(_ocrCacheReferencesInPersistedValue(serializedFields));
      final retryData = entry['retryData'];
      if (retryData is! Map) continue;
      try {
        final data = Map<String, dynamic>.from(retryData);
        if (entry['type'] == BackgroundTaskType.ocr.name) {
          data['type'] ??= BackgroundTaskType.ocr.name;
          references.addAll(OcrRetryStorage.referencesFromSnapshot(data));
        }
      } catch (_) {
        // Unknown persisted data must never expand the set of deletable paths.
      }
    }
    return references;
  }

  Set<String> _ocrCacheReferencesFromTasksAndEntries(
    Iterable<BackgroundTask> tasks,
    Iterable<dynamic> entries,
  ) {
    final references = <String>{};
    for (final task in tasks) {
      final serialized = task.toMap();
      if (task.type == BackgroundTaskType.ocr) {
        references.addAll(
          OcrRetryStorage.referencesFromSnapshot(task.retryData),
        );
        // OCR images can carry large legacy Base64 payloads; recognized cache
        // references are collected above, so scan only its other serialized
        // fields recursively.
        serialized.remove('retryData');
      }
      references.addAll(_ocrCacheReferencesInPersistedValue(serialized));
    }
    references.addAll(_referencesFromSkippedTaskEntries(entries));
    return references;
  }

  bool _hasKnownOcrCacheOwnership(
    Iterable<BackgroundTask> tasks,
    Iterable<dynamic> entries,
  ) {
    for (final task in tasks) {
      if (task.type == BackgroundTaskType.ocr &&
          _requiresDurableOcrCacheOwnershipMarker(task.retryData)) {
        return false;
      }
    }
    for (final entry in entries) {
      if (entry is! Map) return false;
      if (entry['_unrestoredTaskRecord'] == true) {
        if (entry['ocrCacheOwnershipKnown'] != true) return false;
        continue;
      }
      // Non-OCR rows may still carry cache owners in fields their task model
      // would discard; preserved raw rows remain authoritative until removed.
      if (_hasUnserializedTaskOcrCacheReferences(entry)) return false;
      if (entry['type'] != BackgroundTaskType.ocr.name) continue;
      final retryData = entry['retryData'];
      if (!_canSafelyCollectSkippedOcrCacheReferences(retryData) ||
          _requiresDurableOcrCacheOwnershipMarker(retryData) ||
          _hasUnserializedTaskOcrCacheReferences(entry)) {
        return false;
      }
    }
    return true;
  }

  bool _hasCacheMigrations(List<BackgroundTask> snapshot) {
    for (final task in snapshot) {
      if (task.type != BackgroundTaskType.ocr || task.retryData == null) {
        continue;
      }
      try {
        final retrySnapshot = OcrRetrySnapshot.fromMap(task.retryData!);
        final canMigrateVersion = retrySnapshot.isLegacy ||
            retrySnapshot.version == 1 ||
            retrySnapshot.version == 2 ||
            retrySnapshot.version == OcrRetrySnapshot.currentVersion;
        if (canMigrateVersion && retrySnapshot.needsMigration) return true;
      } catch (_) {
        // Malformed data is sanitized by the prepare step without cache I/O.
      }
    }
    return false;
  }

  Future<List<BackgroundTask>?> _prepareOcrRetriesForPersistence(
    List<BackgroundTask> snapshot,
  ) async {
    final prepared = List<BackgroundTask>.of(snapshot);
    for (var index = 0; index < prepared.length; index++) {
      final task = prepared[index];
      if (task.type != BackgroundTaskType.ocr || task.retryData == null) {
        continue;
      }

      OcrRetrySnapshot retrySnapshot;
      try {
        retrySnapshot = OcrRetrySnapshot.fromMap(task.retryData!);
      } catch (error) {
        debugPrint(
          '[BackgroundTaskNotifier] Dropping malformed OCR retry data for ${task.id}: $error',
        );
        prepared[index] = task.copyWith(clearRetryData: true);
        continue;
      }

      final canMigrateVersion = retrySnapshot.isLegacy ||
          retrySnapshot.version == 1 ||
          retrySnapshot.version == 2 ||
          retrySnapshot.version == OcrRetrySnapshot.currentVersion;
      if (!canMigrateVersion) {
        prepared[index] = task.copyWith(
          retryData: _unavailableOcrRetryData(task.id, retrySnapshot),
        );
        continue;
      }
      if (!retrySnapshot.needsMigration) continue;

      try {
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: task.id,
          snapshot: retrySnapshot,
          allowIncompleteImages: retrySnapshot.hasInvalidImages,
        );
        prepared[index] = task.copyWith(retryData: retryData);
      } catch (error) {
        debugPrint(
          '[BackgroundTaskNotifier] Failed to migrate OCR retry data for ${task.id}: $error',
        );
        if (retrySnapshot.images.any(
          (image) => image.bytes?.isNotEmpty ?? false,
        )) {
          // Keep valid legacy inputs in memory and on disk until the cache
          // write works. This also preserves valid entries in a mixed snapshot
          // while unavailable placeholders are prepared for invalid siblings.
          // The caller skips this entire tasks.json update so a progress change
          // cannot rewrite the inline image payload.
          return null;
        }
        prepared[index] = task.copyWith(
          retryData: _unavailableOcrRetryData(task.id, retrySnapshot),
        );
      }
    }
    return prepared;
  }

  void _publishPreparedRetrySnapshots(
    List<BackgroundTask> original,
    List<BackgroundTask> prepared,
  ) {
    final changed = <String, BackgroundTask>{};
    final originalById = {for (final task in original) task.id: task};
    for (var index = 0; index < original.length; index++) {
      final before = original[index];
      final after = prepared[index];
      if (before.id != after.id ||
          identical(before.retryData, after.retryData) ||
          (before.retryData != null && after.retryData == null)) {
        continue;
      }
      changed[before.id] = after;
    }
    if (changed.isEmpty) return;

    List<BackgroundTask> update(List<BackgroundTask> current) =>
        current.map((task) {
          final before = originalById[task.id];
          final after = changed[task.id];
          if (before == null ||
              after == null ||
              !identical(task.retryData, before.retryData)) {
            return task;
          }
          return task.copyWith(retryData: after.retryData);
        }).toList(growable: false);

    if (mounted) state = update(state);
    if (_disposedSnapshot != null) {
      _disposedSnapshot = update(_disposedSnapshot!);
    }
  }

  Future<bool> _writeSnapshotData(
    List<dynamic> data,
    String? dirOverride,
  ) async {
    try {
      final file = await _tasksFile(dirOverride);
      await _writeTasksFile(file, jsonEncode(data));
      return true;
    } catch (e) {
      debugPrint('[BackgroundTaskNotifier] Failed to persist tasks: $e');
      return false;
    }
  }

  /// 原子写入任务文件（委托 [AtomicFile]：写临时文件 + rename 替换）。
  ///
  /// 直接 writeAsString 不是原子操作——写入中途崩溃/断电会留下
  /// 半截 JSON，下次启动恢复时整个文件解析失败、任务全部丢失。
  /// （写入链已串行化，不存在并发写同一文件的竞态。）
  Future<void> _writeTasksFile(File file, String data) async {
    await debugBeforeTaskSnapshotWrite?.call();
    await AtomicFile.writeString(file, data);
  }

  Future<({BackgroundTask task, List<AsrAudioReference> references})>
      _migrateLegacyAsrRetryData(BackgroundTask task) async {
    final retryData = task.retryData!;
    if (task.status == TaskStatus.completed) {
      return (
        task: task.copyWith(
          clearRetryData: true,
          clearRawRequest: true,
          clearRawResponse: true,
          clearError: true,
          steps: [
            for (final step in task.steps)
              BgTaskStep(label: step.label, status: step.status),
          ],
        ),
        references: const <AsrAudioReference>[],
      );
    }
    final versionedReferences = AsrRetryAudioStore.sanitizeVersionedRetryData({
      ...retryData,
      'type': 'asr',
      'version': 2,
    }, allowUnknownChunkStatuses: true);
    if (versionedReferences != null &&
        (versionedReferences.containsKey('audioReference') ||
            versionedReferences.containsKey('audioReferences'))) {
      final preservedReferences = <AsrAudioReference>[];
      final singleReference = versionedReferences['audioReference'];
      if (singleReference is Map) {
        preservedReferences.add(
          AsrAudioReference.fromMap(
            Map<String, dynamic>.from(singleReference),
          ),
        );
      }
      final multipleReferences = versionedReferences['audioReferences'];
      if (multipleReferences is List) {
        for (final entry in multipleReferences) {
          if (entry is Map && entry['audioReference'] is Map) {
            preservedReferences.add(
              AsrAudioReference.fromMap(
                Map<String, dynamic>.from(entry['audioReference'] as Map),
              ),
            );
          }
        }
      }
      return (
        task: task.copyWith(
          retryData: versionedReferences,
          clearRawRequest: true,
          clearRawResponse: true,
          clearError: true,
          steps: [
            for (final step in task.steps)
              BgTaskStep(label: step.label, status: step.status),
          ],
        ),
        references: preservedReferences,
      );
    }

    final audioEntries = retryData['audios'];
    final store = AsrRetryAudioStore();
    final references = <AsrAudioReference>[];

    AsrAudioReference missingSource(int index) => AsrAudioReference(
          id: const Uuid().v4().replaceAll('-', '').toLowerCase(),
          name: 'audio-${index + 1}.bin',
          format: 'bin',
          byteLength: 0,
          sha256: List.filled(64, '0').join(),
          requiresSourceReselection: true,
        );

    try {
      if (audioEntries is List) {
        for (var index = 0; index < audioEntries.length; index++) {
          final entry = audioEntries[index];
          if (entry is! Map) {
            references.add(missingSource(index));
            continue;
          }

          final url = entry['url'];
          if (url is String && url.trim().isNotEmpty) {
            final rawUrl = url.trim();
            final safeUrl = AsrRetryConfigSnapshot.sanitizeDiagnosticUrl(
              rawUrl,
            );
            references.add(
              AsrAudioReference(
                id: const Uuid().v4().replaceAll('-', '').toLowerCase(),
                name: safeUrl,
                format: 'url',
                byteLength: 0,
                sha256: List.filled(64, '0').join(),
                url: safeUrl,
                requiresSourceReselection: safeUrl.isEmpty ||
                    safeUrl != rawUrl ||
                    AsrRetryConfigSnapshot.urlContainsCredentials(rawUrl),
              ),
            );
            continue;
          }

          final encodedBytes = entry['bytes'];
          Uint8List? bytes;
          if (encodedBytes is String) {
            try {
              final decoded = base64Decode(encodedBytes);
              if (decoded.isNotEmpty) bytes = Uint8List.fromList(decoded);
            } on FormatException {
              // Malformed legacy audio is retained only as a reselection cue.
            }
          }
          if (bytes == null) {
            references.add(missingSource(index));
            continue;
          }

          const safeFormats = {
            'aac',
            'flac',
            'm4a',
            'mp3',
            'mp4',
            'ogg',
            'opus',
            'pcm',
            'wav',
            'webm',
          };
          final rawFormat = entry['format'];
          final format = rawFormat is String &&
                  safeFormats.contains(rawFormat.trim().toLowerCase())
              ? rawFormat.trim().toLowerCase()
              : 'bin';
          references.add(
            await store.save(
              bytes,
              name: 'audio-${index + 1}.$format',
              format: format,
            ),
          );
        }
      }

      if (references.isEmpty) references.add(missingSource(0));
      final migratedRetryData = <String, dynamic>{
        'type': 'asr',
        'version': 2,
        'audioReferences': [
          for (final reference in references)
            {'audioReference': reference.toMap(), 'chunks': const <dynamic>[]},
        ],
      };
      final rawSaveFolder = retryData['saveFolder'];
      if (rawSaveFolder is String && rawSaveFolder.trim().isNotEmpty) {
        final safeSaveFolder = AsrRetryConfigSnapshot.sanitizeDiagnosticText(
          rawSaveFolder,
        );
        if (safeSaveFolder == rawSaveFolder.trim() &&
            safeSaveFolder.length <= 512) {
          migratedRetryData['saveFolder'] = safeSaveFolder;
        }
      }

      return (
        task: task.copyWith(
          retryData: migratedRetryData,
          clearRawRequest: true,
          clearRawResponse: true,
          clearError: true,
          steps: [
            for (final step in task.steps)
              BgTaskStep(label: step.label, status: step.status),
          ],
        ),
        references: references,
      );
    } catch (_) {
      for (final reference in references) {
        await store.releaseProtection(reference);
        await store.deleteIfUnreferenced(reference, const <String>{});
      }
      rethrow;
    }
  }

  Future<
      ({
        List<BackgroundTask> tasks,
        bool isComplete,
        bool isCompleteExceptLegacyAsr,
        bool isReadable,
        List<dynamic> skippedEntries,
        bool cleanupSafe,
        bool ocrCacheCleanupSafe,
        List<dynamic> unrestoredRecords,
        bool hasUnsafeSkippedAsrData,
      })> _loadPersistedTasks({
    String? dirOverride,
    bool waitForDebugRead = true,
  }) async {
    try {
      final file = await _tasksFile(dirOverride);
      if (!await file.exists()) {
        return (
          tasks: <BackgroundTask>[],
          isComplete: true,
          isCompleteExceptLegacyAsr: true,
          isReadable: true,
          skippedEntries: <dynamic>[],
          cleanupSafe: true,
          ocrCacheCleanupSafe: true,
          unrestoredRecords: <dynamic>[],
          hasUnsafeSkippedAsrData: false,
        );
      }
      if (waitForDebugRead) await debugBeforeTaskSnapshotRead?.call();
      final content = await file.readAsString();
      if (waitForDebugRead) await debugAfterTaskSnapshotRead?.call();
      if (content.isEmpty) {
        return (
          tasks: <BackgroundTask>[],
          isComplete: false,
          isCompleteExceptLegacyAsr: false,
          isReadable: false,
          skippedEntries: <dynamic>[],
          cleanupSafe: false,
          ocrCacheCleanupSafe: false,
          unrestoredRecords: <dynamic>[_unrestoredTaskRecordMarker],
          hasUnsafeSkippedAsrData: false,
        );
      }
      Object? decoded;
      try {
        decoded = jsonDecode(content);
      } on FormatException catch (e) {
        debugPrint('[BackgroundTaskNotifier] Failed to decode task list: $e');
        return (
          tasks: <BackgroundTask>[],
          isComplete: false,
          isCompleteExceptLegacyAsr: false,
          isReadable: false,
          skippedEntries: <dynamic>[],
          cleanupSafe: false,
          ocrCacheCleanupSafe: false,
          unrestoredRecords: <dynamic>[_unrestoredTaskRecordMarker],
          hasUnsafeSkippedAsrData: false,
        );
      }
      if (decoded is! List) {
        return (
          tasks: <BackgroundTask>[],
          isComplete: false,
          isCompleteExceptLegacyAsr: false,
          isReadable: false,
          skippedEntries: <dynamic>[],
          cleanupSafe: false,
          ocrCacheCleanupSafe: false,
          unrestoredRecords: <dynamic>[_unrestoredTaskRecordMarker],
          hasUnsafeSkippedAsrData: false,
        );
      }
      final list = decoded;
      final tasks = <BackgroundTask>[];
      final skippedEntries = <dynamic>[];
      final unrestoredRecords = <dynamic>[];
      var isComplete = true;
      var isCompleteExceptLegacyAsr = true;
      var cleanupSafe = true;
      var ocrCacheCleanupSafe = true;
      var hasUnsafeSkippedAsrData = false;
      for (final m in list) {
        if (m is Map && m['_unrestoredTaskRecord'] == true) {
          isComplete = false;
          isCompleteExceptLegacyAsr = false;
          final ownershipKnown = m['retryAudioOwnershipKnown'] == true;
          final retireAfterSnapshot = m['retireAfterSnapshot'] == true;
          final rawIds = m['retryAudioIds'];
          final retryAudioIds = <String>{};
          const markerKeys = {
            '_unrestoredTaskRecord',
            'retryAudioOwnershipKnown',
            'retryAudioIds',
            'retireAfterSnapshot',
            'ocrCacheOwnershipKnown',
            'ocrCacheTaskId',
          };
          final hasUnsafeMarkerFields = m.entries.any(
            (entry) =>
                !markerKeys.contains(entry.key) &&
                !_canSafelyPreserveLegacyAsrRetryData({
                  entry.key: entry.value,
                }),
          );
          if (hasUnsafeMarkerFields) hasUnsafeSkippedAsrData = true;
          var markerValid = m.keys.every(
                (key) => key is String && markerKeys.contains(key),
              ) &&
              (rawIds == null || rawIds is List) &&
              (m['retireAfterSnapshot'] == null ||
                  m['retireAfterSnapshot'] is bool) &&
              (m['ocrCacheOwnershipKnown'] == null ||
                  m['ocrCacheOwnershipKnown'] is bool) &&
              (m['ocrCacheTaskId'] == null ||
                  (m['ocrCacheTaskId'] is String &&
                      (m['ocrCacheTaskId'] as String).isNotEmpty));
          if (rawIds is List) {
            for (final id in rawIds) {
              if (id is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
                markerValid = false;
                break;
              }
              retryAudioIds.add(id);
            }
          }
          final ocrCacheOwnershipKnown = m['ocrCacheOwnershipKnown'] == true;
          if (!markerValid || !ownershipKnown) cleanupSafe = false;
          if (!markerValid || !ocrCacheOwnershipKnown) {
            ocrCacheCleanupSafe = false;
          }
          unrestoredRecords.add(
            _unrestoredTaskRecord(
              retryAudioOwnershipKnown: markerValid && ownershipKnown,
              retryAudioIds: markerValid ? retryAudioIds : const {},
              retireAfterSnapshot: markerValid && retireAfterSnapshot,
              ocrCacheOwnershipKnown: markerValid && ocrCacheOwnershipKnown,
              ocrCacheTaskId: markerValid && m['ocrCacheTaskId'] is String
                  ? m['ocrCacheTaskId'] as String
                  : null,
            ),
          );
          continue;
        }
        final rawMap = m is Map ? m : null;
        final rawRetryData = rawMap?['retryData'];
        final hasNonOcrRetryCacheReferences = rawMap != null &&
            rawMap['type'] != BackgroundTaskType.ocr.name &&
            _ocrCacheReferencesInPersistedValue(rawRetryData).isNotEmpty;
        final hasAsrReferenceShape = rawRetryData is Map &&
            (rawRetryData.containsKey('audioReference') ||
                rawRetryData.containsKey('audioReferences'));
        final isAsrRecord = rawMap?['type'] == BackgroundTaskType.asr.name ||
            hasAsrReferenceShape;
        final isKnownNonAsrRecord = !isAsrRecord &&
            BackgroundTaskType.values.any(
              (type) => type.name == rawMap?['type'],
            );
        final hasUnserializedOcrCacheReferences = rawMap != null &&
            (_hasUnserializedTaskOcrCacheReferences(rawMap) ||
                hasNonOcrRetryCacheReferences);
        var ocrCacheOwnershipMarkerRecorded = false;
        void recordUnknownOcrCacheOwnership() {
          if (ocrCacheOwnershipMarkerRecorded || rawMap == null) return;
          unrestoredRecords.add(
            _unrestoredTaskRecord(
              retryAudioOwnershipKnown: true,
              ocrCacheOwnershipKnown: false,
              ocrCacheTaskId:
                  rawMap['id'] is String ? rawMap['id'] as String : null,
            ),
          );
          ocrCacheOwnershipMarkerRecorded = true;
        }

        if (hasUnserializedOcrCacheReferences) {
          ocrCacheCleanupSafe = false;
          recordUnknownOcrCacheOwnership();
        }
        try {
          if (rawMap == null) {
            throw const FormatException('Task row is not an object');
          }
          var task = BackgroundTask.fromMap(
            Map<String, dynamic>.from(rawMap),
          );
          if (task.type == BackgroundTaskType.ocr &&
              !_canSafelyCollectSkippedOcrCacheReferences(rawRetryData)) {
            // Keep cleanup fail-closed until retry data has been normalized.
            ocrCacheCleanupSafe = false;
          }
          if (hasUnserializedOcrCacheReferences ||
              (task.type == BackgroundTaskType.ocr &&
                  _requiresDurableOcrCacheOwnershipMarker(rawRetryData))) {
            // Unknown fields can contain cache owners outside the images list.
            // Persist the sanitized task together with this marker so future
            // writes cannot accidentally authorize cleanup; removing the task
            // retires its marker in the same durable snapshot.
            recordUnknownOcrCacheOwnership();
          }
          if (task.type == BackgroundTaskType.asr) {
            final rawSteps = rawMap['steps'];
            final hasUnsafeParsedTaskDiagnostics = [
              rawMap['rawRequest'],
              rawMap['rawResponse'],
              rawMap['error'],
              if (rawSteps is List)
                for (final step in rawSteps)
                  if (step is Map) step['error'],
            ].any((value) =>
                value != null && !_canSafelyPreserveLegacyAsrRetryData(value));
            final hasUnsafeVersionedRetryMetadata = rawRetryData is Map &&
                rawRetryData.containsKey('version') &&
                !_canSafelyPreserveLegacyAsrRetryData(rawRetryData);
            if (hasUnsafeParsedTaskDiagnostics ||
                hasUnsafeVersionedRetryMetadata) {
              // Parsed ASR rows need to trigger partial-snapshot sanitation
              // when diagnostics or versioned retry data contain credentials.
              hasUnsafeSkippedAsrData = true;
            }
            if (_hasAudioOwnershipOutsideRetryData(rawMap)) {
              // The task model cannot restore audio references outside its
              // versioned retryData shape. Keep the snapshot incomplete and
              // carry unknown ownership forward before any audio pruning.
              isComplete = false;
              isCompleteExceptLegacyAsr = false;
              cleanupSafe = false;
              unrestoredRecords.add(
                _unrestoredTaskRecord(
                  retryAudioOwnershipKnown: false,
                  retireAfterSnapshot: _canRetireAsrOwnershipAfterSnapshot(
                    rawMap,
                    rawRetryData,
                  ),
                ),
              );
            }
            if (rawRetryData != null && rawRetryData is! Map) {
              // The model parser drops malformed non-map ASR retry data. The
              // raw row may still own audio, so keep restoration incomplete
              // and carry unknown ownership forward before any cache pruning.
              isComplete = false;
              isCompleteExceptLegacyAsr = false;
              cleanupSafe = false;
              unrestoredRecords.add(
                _unrestoredTaskRecord(
                  retryAudioOwnershipKnown: false,
                  retireAfterSnapshot: _canRetireAsrOwnershipAfterSnapshot(
                    rawMap,
                    rawRetryData,
                  ),
                ),
              );
            } else {
              final retryAudioIds = AsrRetryAudioStore.recoverableReferencedIds(
                task.retryData,
              );
              if (retryAudioIds == null) cleanupSafe = false;
            }
            if (task.retryData != null &&
                !task.retryData!.containsKey('version')) {
              isComplete = false;
            } else if (!AsrRetryAudioStore.hasValidVersionedReferences(
              task.retryData,
            )) {
              isComplete = false;
              isCompleteExceptLegacyAsr = false;
              // A parsed task with invalid versioned references cannot be
              // safely reserialized, even when its metadata contains no
              // obvious credential or inline payload. Drop unusable retry
              // data and retain unknown ownership until that snapshot is
              // durably rewritten.
              hasUnsafeSkippedAsrData = true;
              cleanupSafe = false;
              unrestoredRecords.add(
                _unrestoredTaskRecord(
                  retryAudioOwnershipKnown: false,
                  retireAfterSnapshot: _canRetireAsrOwnershipAfterSnapshot(
                    rawMap,
                    rawRetryData,
                  ),
                ),
              );
              task = task.copyWith(clearRetryData: true);
            }
          }
          tasks.add(task);
        } catch (e) {
          // 单个损坏条目不应导致整个恢复失败：跳过并继续，
          // 保证其余有效任务仍能恢复。
          isComplete = false;
          isCompleteExceptLegacyAsr = false;
          if (isAsrRecord) {
            if (rawMap != null &&
                !_canSafelyPreserveLegacyAsrRetryData(rawMap)) {
              hasUnsafeSkippedAsrData = true;
            }
            final retryAudioIds = _recoverRetryAudioIds(rawMap);
            if (retryAudioIds == null) cleanupSafe = false;
            final hasExplicitVersion =
                rawRetryData is Map && rawRetryData.containsKey('version');
            if (rawMap?['type'] == BackgroundTaskType.asr.name &&
                !hasAsrReferenceShape &&
                !hasExplicitVersion &&
                _canSafelyPreserveSkippedAsrEntry(rawMap!)) {
              // Preserve safe legacy metadata (for example an input path) as
              // current main does, while rejecting keys and inline audio.
              skippedEntries.add(m);
            } else {
              // Keep only validated retry ownership; raw versioned/future rows
              // may contain secrets or Base64 and are never rewritten.
              unrestoredRecords.add(
                _unrestoredTaskRecord(
                  retryAudioOwnershipKnown: retryAudioIds != null,
                  retryAudioIds: retryAudioIds ?? const {},
                  ocrCacheOwnershipKnown: !hasUnserializedOcrCacheReferences,
                  ocrCacheTaskId: hasUnserializedOcrCacheReferences &&
                          rawMap['id'] is String
                      ? rawMap['id'] as String
                      : null,
                  retireAfterSnapshot: _canRetireAsrOwnershipAfterSnapshot(
                    rawMap,
                    rawRetryData,
                  ),
                ),
              );
            }
          } else if (isKnownNonAsrRecord) {
            if (hasUnserializedOcrCacheReferences) {
              recordUnknownOcrCacheOwnership();
            }
            if (rawMap?['type'] == BackgroundTaskType.ocr.name &&
                !_canSafelyCollectSkippedOcrCacheReferences(rawRetryData)) {
              ocrCacheCleanupSafe = false;
            }
            skippedEntries.add(m);
          } else {
            cleanupSafe = false;
            ocrCacheCleanupSafe = false;
            unrestoredRecords.add(
              _unrestoredTaskRecord(
                retryAudioOwnershipKnown: false,
                ocrCacheOwnershipKnown: false,
                ocrCacheTaskId:
                    rawMap?['id'] is String ? rawMap!['id'] as String : null,
              ),
            );
          }
          debugPrint(
            '[BackgroundTaskNotifier] Skipping corrupt task entry: $e',
          );
        }
      }
      return (
        tasks: tasks,
        isComplete: isComplete,
        isCompleteExceptLegacyAsr: isCompleteExceptLegacyAsr,
        isReadable: true,
        skippedEntries: skippedEntries,
        cleanupSafe: cleanupSafe,
        ocrCacheCleanupSafe: ocrCacheCleanupSafe,
        unrestoredRecords: unrestoredRecords,
        hasUnsafeSkippedAsrData: hasUnsafeSkippedAsrData,
      );
    } catch (e) {
      debugPrint('[BackgroundTaskNotifier] Failed to load persisted tasks: $e');
      return (
        tasks: <BackgroundTask>[],
        isComplete: false,
        isCompleteExceptLegacyAsr: false,
        isReadable: false,
        skippedEntries: <dynamic>[],
        cleanupSafe: false,
        ocrCacheCleanupSafe: false,
        unrestoredRecords: <dynamic>[_unrestoredTaskRecordMarker],
        hasUnsafeSkippedAsrData: false,
      );
    }
  }

  Future<File> _tasksFile([String? dirOverride]) async {
    final dirPath = dirOverride ??
        debugStorageDirectoryOverride ??
        await AppStorage.directory;
    final bgDir = Directory(p.join(dirPath, 'background'));
    try {
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }
    } catch (_) {}
    return File(p.join(bgDir.path, 'tasks.json'));
  }

  /// Restore persisted tasks on startup.
  /// Running tasks are marked as failed since they can't be resumed.
  /// Waiting tasks are kept as waiting (they haven't started yet).
  Future<bool> restoreFromPersistence() {
    final activeRestore = _activeRestore;
    if (activeRestore != null) return activeRestore;
    final activeBarrier = _restoreBarrier;
    if (activeBarrier != null) {
      return activeBarrier.future.then((_) async {
        await pendingPersistence;
        return !_taskSnapshotIncomplete;
      });
    }
    final restoreBarrier = Completer<void>();
    _restoreGeneration++;
    _restoreBarrier = restoreBarrier;
    late final Future<bool> restore;
    restore = _restorePersistedTasks(restoreBarrier).whenComplete(() {
      _completeRestoreBarrier(restoreBarrier);
      if (identical(_activeRestore, restore)) _activeRestore = null;
    });
    _activeRestore = restore;
    return restore;
  }

  Future<bool> _restorePersistedTasks(Completer<void> restoreBarrier) async {
    final loaded = await _loadPersistedTasks();
    _ocrCacheOwnershipLoaded = loaded.isReadable;
    _ocrCacheCleanupSafe = loaded.isReadable && loaded.ocrCacheCleanupSafe;
    _persistedOcrCacheReferences
      ..clear()
      ..addAll(
        _ocrCacheReferencesFromTasksAndEntries(
          loaded.tasks,
          [...loaded.skippedEntries, ...loaded.unrestoredRecords],
        ),
      );
    _persistedRetryAudioIds
      ..clear()
      ..addAll(
        _retryAudioIdsInSnapshot(
          loaded.tasks,
          [...loaded.skippedEntries, ...loaded.unrestoredRecords],
        ),
      );
    for (final task in loaded.tasks) {
      if (task.type == BackgroundTaskType.asr) {
        _pendingSanitizedAsrRetryAudioIds.addAll(
          _unrecognizedRetryAudioIds(task.retryData),
        );
      }
    }
    var snapshotComplete = loaded.isComplete;
    var cleanupSafe = loaded.cleanupSafe;
    var tasks = loaded.tasks;
    final migratedAsrReferences = <AsrAudioReference>[];
    var discardedCompletedAsrAudioReferences = false;
    final hasLegacyAsrRetryData = loaded.tasks.any(
      (task) =>
          task.type == BackgroundTaskType.asr &&
          task.retryData != null &&
          !task.retryData!.containsKey('version'),
    );
    if (!loaded.isComplete && loaded.isReadable && hasLegacyAsrRetryData) {
      tasks = List<BackgroundTask>.of(tasks);
      try {
        for (var index = 0; index < tasks.length; index++) {
          final task = tasks[index];
          if (task.type != BackgroundTaskType.asr ||
              task.retryData == null ||
              task.retryData!.containsKey('version')) {
            continue;
          }
          final recoverableAudioIds =
              AsrRetryAudioStore.recoverableReferencedIds(task.retryData);
          if (task.status == TaskStatus.completed &&
              (recoverableAudioIds?.isNotEmpty ?? false)) {
            // The migration clears completed retry data in memory. Until that
            // sanitized snapshot is durable, the old on-disk row still owns
            // any references it named.
            discardedCompletedAsrAudioReferences = true;
            _pendingCompletedLegacyAsrRetryAudioIds.addAll(
              recoverableAudioIds!,
            );
          }
          await debugBeforeLegacyAsrRetryMigration?.call(task.id);
          final migration = await _migrateLegacyAsrRetryData(task);
          tasks[index] = migration.task;
          migratedAsrReferences.addAll(migration.references);
        }
        if (loaded.isCompleteExceptLegacyAsr) snapshotComplete = true;
      } catch (error) {
        final store = AsrRetryAudioStore();
        for (final reference in migratedAsrReferences) {
          await store.releaseProtection(reference);
          await store.deleteIfUnreferenced(reference, _persistedRetryAudioIds);
        }
        migratedAsrReferences.clear();
        tasks = loaded.tasks;
        cleanupSafe = false;
        debugPrint(
          '[BackgroundTaskNotifier] Failed to migrate legacy ASR retry data: $error',
        );
      }
    }

    final pendingRemovalIds = <String>{
      ..._pendingRestoreTaskRemovals.keys,
      ..._pendingTaskRemovalReconciliations.keys,
      ..._pendingRestoreTaskRemovalOwnershipIds,
    };
    for (final task in tasks) {
      if (pendingRemovalIds.contains(task.id)) {
        // removeTask may run after the disk snapshot is read but before its
        // task enters state; retain that loaded generation until deletion is
        // durably saved so its retry audio remains owned meanwhile.
        _queueTaskCleanupAfterRemoval(task.id, task);
      }
    }
    final canScrubRejectedPartialSnapshot = !snapshotComplete &&
        loaded.isReadable &&
        loaded.hasUnsafeSkippedAsrData &&
        _pendingRestoreTaskRemovals.isEmpty &&
        _pendingTaskRemovalReconciliations.isEmpty &&
        _pendingRestoreTaskRemovalOwnershipIds.isEmpty &&
        _pendingTaskRemovalCleanupTasks.isEmpty &&
        _activeBatchRemovalAddedGenerations.isEmpty;
    _pendingRestoreTaskRemovalOwnershipIds.clear();

    _taskSnapshotIncomplete = !snapshotComplete;
    _taskSnapshotCanPreserveSkippedEntries =
        loaded.isReadable && !snapshotComplete;
    _skippedTaskEntries = loaded.skippedEntries;
    _retryAudioCleanupSafe =
        cleanupSafe && !discardedCompletedAsrAudioReferences;
    _unrestoredTaskRecords = loaded.unrestoredRecords;
    if (!snapshotComplete && !canScrubRejectedPartialSnapshot) {
      // Preserve the established partial-restore behavior during removals or
      // when rejected rows do not require security sanitation.
      _pendingRestoreTaskRemovals.clear();
    }
    if (tasks.isEmpty &&
        (snapshotComplete || !canScrubRejectedPartialSnapshot)) {
      if (snapshotComplete) {
        _pendingRestoreTaskRemovals.clear();
        await _cleanupOrphanedOcrCache();
      }
      _ocrCacheOwnershipLoaded = loaded.isReadable;
      _ocrCacheCleanupSafe = loaded.isReadable && loaded.ocrCacheCleanupSafe;
      return snapshotComplete;
    }
    final restored = <BackgroundTask>[];
    for (var task in tasks) {
      // A partial task list is not authoritative enough to publish retry-data
      // sanitation: a later deletion may be refused, leaving the old snapshot
      // on disk. Keep each parsed task's retry data unchanged until the full
      // task file can be durably rewritten.
      if (snapshotComplete &&
          task.type == BackgroundTaskType.ocr &&
          task.retryData != null) {
        OcrRetrySnapshot? parsedSnapshot;
        try {
          parsedSnapshot = OcrRetrySnapshot.fromMap(task.retryData!);
          final canMigrateVersion = parsedSnapshot.isLegacy ||
              parsedSnapshot.version == 1 ||
              parsedSnapshot.version == 2 ||
              parsedSnapshot.version == OcrRetrySnapshot.currentVersion;
          if (parsedSnapshot.hasInvalidImages && !canMigrateVersion) {
            task = task.copyWith(
              retryData: _unavailableOcrRetryData(task.id, parsedSnapshot),
            );
          }
        } catch (error) {
          if (parsedSnapshot != null) {
            task = task.copyWith(
              retryData: _unavailableOcrRetryData(task.id, parsedSnapshot),
            );
          } else {
            task = task.copyWith(clearRetryData: true);
          }
          debugPrint(
            '[BackgroundTaskNotifier] Failed to migrate OCR retry data for ${task.id}: $error',
          );
        }
      }
      task = _localizeRestoredBackgroundTask(task, localizations);
      restored.add(
        task.status == TaskStatus.running
            ? task.copyWith(
                status: TaskStatus.failed,
                error: localizations.bgTaskInterruptedOnRestart,
              )
            : task,
      );
    }
    final pendingRemovals = Map<String, Object>.of(_pendingRestoreTaskRemovals);
    final removalOwnershipIdsNow = <String>{
      ..._pendingRestoreTaskRemovals.keys,
      ..._pendingTaskRemovalReconciliations.keys,
      ..._pendingRestoreTaskRemovalOwnershipIds,
      ..._pendingTaskRemovalCleanupTasks.keys,
    };
    for (final task in restored) {
      if (!removalOwnershipIdsNow.contains(task.id) &&
          task.type == BackgroundTaskType.asr &&
          state.any((current) => current.id == task.id)) {
        _pendingReplacedRestoreAsrRetryAudioIds.addAll(
          AsrRetryAudioStore.referencedIds(task.retryData),
        );
      }
    }
    // Merge with existing state (in case tasks were added before restore completes)
    state = [
      for (final t in restored)
        if (!pendingRemovals.containsKey(t.id) &&
            !state.any((s) => s.id == t.id))
          t,
      ...state,
    ];
    if (!restoreBarrier.isCompleted) restoreBarrier.complete();
    // 将"运行中 → 已中断"的状态回写到磁盘，
    // 使持久化文件与内存状态保持一致（否则下次启动会重复标记）。
    // Rejected ASR rows are scrubbed on restore only if no task removal is in
    // flight and the remaining skipped rows have safe ownership markers.
    final canPersistPartialSnapshot = snapshotComplete ||
        (canScrubRejectedPartialSnapshot &&
            _canSafelyPreserveSkippedEntries(restored));
    final snapshotSaved = canPersistPartialSnapshot && await _persistTasks();
    if (!snapshotComplete && !snapshotSaved) {
      // A failed or unsafe partial write cannot prove a pending deletion was
      // saved; retain parsed tasks for the next complete snapshot.
      _pendingRestoreTaskRemovals.clear();
    }
    if (snapshotSaved) {
      _clearPendingRestoreTaskRemovals(pendingRemovals);
    }
    final store = AsrRetryAudioStore();
    for (final reference in migratedAsrReferences) {
      await store.releaseProtection(reference);
    }
    if (!snapshotSaved &&
        (loaded.hasUnsafeSkippedAsrData ||
            migratedAsrReferences.isNotEmpty ||
            discardedCompletedAsrAudioReferences ||
            _pendingReplacedRestoreAsrRetryAudioIds.isNotEmpty)) {
      _retryAudioCleanupSafe = false;
    }
    _ocrCacheOwnershipLoaded = loaded.isReadable;
    _ocrCacheCleanupSafe = snapshotSaved
        ? _hasKnownOcrCacheOwnership(
            mounted ? state : (_disposedSnapshot ?? restored),
            [..._skippedTaskEntries, ..._unrestoredTaskRecords],
          )
        : loaded.isReadable && loaded.ocrCacheCleanupSafe;
    // 恢复后没有运行中的任务（进程已重启），结束 iOS 常驻任务保护。
    _syncIosContinuedTask();
    if (snapshotComplete && snapshotSaved) {
      await _cleanupOrphanedOcrCache();
    }
    debugPrint(
      '[BackgroundTaskNotifier] Restored ${tasks.length} tasks from persistence',
    );
    return snapshotComplete;
  }

  void _completeRestoreBarrier(Completer<void> barrier) {
    if (identical(_restoreBarrier, barrier)) _restoreBarrier = null;
    if (!barrier.isCompleted) barrier.complete();
  }
}
