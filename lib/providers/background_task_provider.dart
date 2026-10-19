import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../models/ocr_batch_execution.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/ios_continued_task_service.dart';
import '../services/ocr_retry_storage.dart';
import '../pages/ocr/ocr_retry_snapshot.dart';
import '../utils/atomic_file.dart';
import '../utils/ocr_diagnostics.dart';
import 'task_provider.dart';

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
  if (error != null &&
      _legacyOcrTextContainsMaskedCredential(error, credentialValues)) {
    return 'OCR 错误详情已隐藏';
  }
  return OcrDiagnosticSnapshot.sanitizeStoredTaskError(
    error,
    excludedValues: credentialValues,
  );
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
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:/-]{0,127}$').hasMatch(value) ||
      RegExp(
        r'^(?:sk-(?:proj-|ant-api\d{2}-|or-v1-)?[a-z0-9]{8,}|gsk_[a-z0-9]{8,}|gh[pousr]_[a-z0-9]{8,}|AIza[a-z0-9_-]{20,})$',
        caseSensitive: false,
      ).hasMatch(value) ||
      _legacyOcrTextContainsCredential(value, credentialValues)) {
    return null;
  }
  return value;
}

Iterable<String> _legacyOcrCredentialValues(Map<String, dynamic>? rawRequest) =>
    OcrDiagnosticSnapshot.credentialValuesFromRequest(rawRequest);

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
  return _legacyOcrTextContainsMaskedCredential(text, credentialValues);
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
      r'^(?:s|es|ed|ing|er|est|ly|ary|aries|ation|ization|istic|based)$',
      caseSensitive: false,
    ).hasMatch(value);

bool _legacyOcrHasNaturalWordContinuation(String prefix, String suffix) {
  if (RegExp(r'[\p{N}_]', unicode: true).hasMatch(suffix)) return false;

  final unicodeWord = '$prefix$suffix'
      .replaceAll(RegExp(r'[^\p{L}]', unicode: true), '')
      .toLowerCase();
  if (const {'secretaría', 'secretária'}.contains(unicodeWord)) return true;
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
    'secretive',
    'secretmenu',
    'summarize',
    'translate',
    'transcribe',
    'tokenize',
    'tokenization',
    'tokenizers',
    'tokenized',
    'tokenizing',
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

bool _legacyOcrHasCredentialUseContext(
  String text,
  Match match,
  String prefix,
  String suffix,
) {
  final before = text.substring(0, match.start).trimRight();
  final after = text.substring(match.end).trimLeft();
  final actionVerb = RegExp(
    r'\b(use|using|send|provide|enter|supply|pass|set|read|extract|identify|recognize|transcribe)$',
    caseSensitive: false,
  ).firstMatch(before);
  final credentialTargetAfterConsumedConnector = suffix.toLowerCase() == 'as' &&
      RegExp(
        r'^(?:(?:the|a|an|my|your|our|their|his|her|its) )?(?:(?:api|access|private|oauth(?:\s*[0-9]+(?:\.[0-9]+)*)?|temporary|bearer) )*(?:authorization|auth|keys?|credentials?|tokens?|secrets?|passwords?)\b',
        caseSensitive: false,
      ).hasMatch(after);
  final explicitCredentialTarget = RegExp(
        r'^as (?:(?:the|a|an|my|your|our|their|his|her|its) )?(?:(?:api|access|private|oauth(?:\s*[0-9]+(?:\.[0-9]+)*)?|temporary|bearer) )*(?:authorization|auth|keys?|credentials?|tokens?|secrets?|passwords?)\b',
        caseSensitive: false,
      ).hasMatch(after) ||
      credentialTargetAfterConsumedConnector;
  final credentialHeaderTarget = RegExp(
    r'^(?:in(?:to)?|to|for) (?:the )?(?:authorization|auth|api[\s_-]*key|key|token|secret|credential|password)(?: header)(?: value)?\b',
    caseSensitive: false,
  ).hasMatch(after);
  final actionTarget = RegExp(
        r'^for (?:the )?request\b',
        caseSensitive: false,
      ).hasMatch(after) ||
      RegExp(
        r'^from (?:the )?(?:receipt|image|document|label|form|page|photo|note)\b',
        caseSensitive: false,
      ).hasMatch(after) ||
      explicitCredentialTarget ||
      credentialHeaderTarget;
  final naturalWord =
      '$prefix$suffix'.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
  final matchedText = match.group(0)!;
  final matchedPrefix = RegExp(
    RegExp.escape(prefix),
    caseSensitive: false,
    unicode: true,
  ).firstMatch(matchedText);
  final absolutePrefixStart =
      matchedPrefix == null ? -1 : match.start + matchedPrefix.start;
  final maskPrefixIsEmbedded = absolutePrefixStart > 0 &&
      RegExp(
        r'[\p{L}\p{M}\p{N}._/+~-]',
        unicode: true,
      ).hasMatch(text.substring(absolutePrefixStart - 1, absolutePrefixStart));
  final shortNaturalWordEcho =
      prefix.length < 8 && _legacyOcrCanRedactShortNaturalWordEcho(naturalWord);
  final isNaturalContinuation = _legacyOcrHasNaturalAlphaContinuation(suffix);
  final isNaturalWordContinuation = _legacyOcrHasNaturalWordContinuation(
    prefix,
    suffix,
  );
  final useVerb = const {
    'use',
    'using',
  }.contains(actionVerb?.group(1)?.toLowerCase());
  final naturalReadFromSourcePrompt = isNaturalWordContinuation &&
      actionVerb?.group(1)?.toLowerCase() == 'read' &&
      RegExp(
        r'^from (?:the )?(?:receipt|image|document|label|form|page|photo|note)\b',
        caseSensitive: false,
      ).hasMatch(after);
  final identifiedLabelContext = maskPrefixIsEmbedded &&
      RegExp(
        r'\b(?:identify|transcribe) the (?:[\p{L}\p{M}]+ )?(?:identifiers?|numbers?|ids?|values?|codes?|keys?|tokens?|passwords?|credentials?|secrets?)$',
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
        r'^to (?:process|analyze|recognize|extract|upload|download|access|authenticate|connect|send|submit)\b',
        caseSensitive: false,
      ).hasMatch(after);
  return actionContext ||
      assignmentContext ||
      setToCredentialContext ||
      reportedValueContext ||
      useToProcessContext ||
      identifiedLabelContext;
}

bool _legacyOcrHasUncommonAlphaContinuation(String value) =>
    RegExp(r'q(?![aeiou])', caseSensitive: false).hasMatch(value) ||
    RegExp(r'^[xz](?:[^a-zA-Z0-9_].*)?$', caseSensitive: false).hasMatch(value);

bool _legacyOcrCanMatchOpenMaskPrefixWithinToken(String prefix) {
  if (prefix.length < 8) return false;
  if (RegExp(r'[-_]').hasMatch(prefix) ||
      _legacyOcrHasUncommonAlphaContinuation(prefix) ||
      _legacyOcrHasLongConsonantRun(prefix)) {
    return true;
  }
  if (prefix.length == 9) return false;
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
  if (prefix.length < 3 || prefix.length >= 8 || prefixOffset <= 0) {
    return false;
  }

  final continuation = candidate.substring(prefixOffset + prefix.length);
  final hasCredentialUseContext = text != null &&
      match != null &&
      _legacyOcrHasCredentialUseContext(text, match, prefix, continuation);
  final hasNumericMarker = RegExp(
    r'[\p{N}_]',
    unicode: true,
  ).hasMatch(continuation);
  if ((continuation.length < 6 &&
          !hasNumericMarker &&
          !hasCredentialUseContext) ||
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
    (prefix.length >= 3 && prefix.length < 8);

String _legacyOcrLineBreakContinuationAfterOpenMaskPrefix(String prefix) {
  return _legacyOcrCanBridgeLineBreakAfterOpenMaskPrefix(prefix)
      ? r'(?:[\r\n]+[ \t]*)?'
      : '';
}

bool _legacyOcrHasNaturalConnectorAfterLineBreak(
  String text,
  Match match,
  String prefix,
  String suffix,
  Set<String> naturalConnectors,
) {
  if (!match.group(0)!.contains(RegExp(r'[\r\n]')) ||
      !naturalConnectors.contains(suffix.toLowerCase())) {
    return false;
  }
  final followingText = text.substring(match.end).trimLeft();
  return RegExp(
        r'^(?:the|this|that|these|those|a|an|my|your|our|their|his|her|its)\b',
        caseSensitive: false,
      ).hasMatch(followingText) &&
      !_legacyOcrHasCredentialUseContext(text, match, prefix, suffix);
}

String _legacyOcrOpenMaskPrefixPattern(String prefix) {
  final escapedPrefix = RegExp.escape(prefix);
  if (!_legacyOcrCanBridgeLineBreakAfterOpenMaskPrefix(prefix) ||
      !RegExp(r'[-_.=/+]$').hasMatch(prefix)) {
    return escapedPrefix;
  }

  final delimiter = prefix.substring(prefix.length - 1);
  final prefixWithoutDelimiter = prefix.substring(0, prefix.length - 1);
  return '(?:$escapedPrefix|${RegExp.escape(prefixWithoutDelimiter)}'
      r'[\r\n]+[ \t]*'
      '${RegExp.escape(delimiter)})';
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
  // Legacy request headers may contain only a masked key; compare its visible
  // edges before preserving any persisted text or diagnostic value.
  final compactedText = text.replaceAll(RegExp(r'\s+'), '');
  final textWithoutPartMarkers = text.replaceAll('\u0000', '');
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
              _legacyOcrLineBreakContinuationAfterOpenMaskPrefix(prefix);
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
            final hasExplicitCredentialUseContext =
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
                _legacyOcrHasUncommonAlphaContinuation(suffix) ||
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
              _legacyOcrLineBreakContinuationAfterOpenMaskPrefix(prefix);
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
    if (prefix.length >= 4 &&
        RegExp('${RegExp.escape(prefix)}\\S{1,12}').hasMatch(compactedText)) {
      return true;
    }
  }
  return false;
}

String? _legacyOcrInstructionContent(Map<String, dynamic>? rawRequest) {
  final body = rawRequest?['body'];
  if (body is! Map || body['messages'] is! List) return null;
  final credentialValues = _legacyOcrCredentialValues(rawRequest).toList();
  final textParts = <String>[];
  for (final message in body['messages'] as List) {
    if (message is! Map ||
        message['role'] != 'user' ||
        message['content'] is! List) {
      continue;
    }
    for (final part in message['content'] as List) {
      if (part is Map && part['type'] == 'text' && part['text'] is String) {
        var text = part['text'] as String;
        if (_legacyOcrTextContainsCredential(text, credentialValues)) {
          text = _legacyOcrRedactMaskedCredentialEchoes(text, credentialValues);
        }
        if (!_legacyOcrTextContainsCredential(text, credentialValues)) {
          textParts.add(text);
        }
      }
    }
  }
  if (textParts.isEmpty) return null;
  final redactedMarkedInstruction = _legacyOcrRedactNaturalWordCredentialEchoes(
    textParts.join('\u0000'),
    credentialValues,
  );
  final instruction = redactedMarkedInstruction.replaceAll('\u0000', '\n');
  if (instruction.length > 10000 ||
      RegExp(
        r'(?:data:image/|base64,)',
        caseSensitive: false,
      ).hasMatch(instruction) ||
      _legacyOcrTextContainsCredential(instruction, credentialValues) ||
      // Preserve text-part boundaries separately so an echoed key split
      // between parts can be identified without removing natural whitespace.
      _legacyOcrTextContainsMaskedCredential(
        textParts.join('\u0000'),
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
  var sanitized = text;
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
        _legacyOcrLineBreakContinuationAfterOpenMaskPrefix(prefix);
    final suffixPattern =
        allowEmbeddedPrefix ? r'(?:\S+|(?=$|[^a-zA-Z0-9]))' : r'\S+';
    final extendedPrefix = RegExp(
      '$leftBoundary($tokenLead'
      '${_legacyOcrOpenMaskPrefixPattern(prefix)}'
      '$lineBreakContinuation$suffixPattern)',
    );
    sanitized = sanitized.replaceAllMapped(extendedPrefix, (match) {
      final boundaryLength = match.group(0)!.length - match.group(1)!.length;
      final beforeEcho = sanitized.substring(0, match.start + boundaryLength);
      final readFromOcrSourcePrompt = RegExp(
            r'^\s*(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?read\s+$',
            caseSensitive: false,
          ).hasMatch(beforeEcho) &&
          RegExp(
            r'^\s+from (?:the )?(?:receipt|image|document|label|form|page|photo|note)\b',
            caseSensitive: false,
          ).hasMatch(sanitized.substring(match.end));
      final credentialValueTargetAfterEcho = RegExp(
        r'^\s*(?:as\s+)?(?:(?:the|a|an|my|your|our|their|his|her|its)\s+)?(?:(?:api|access|private|oauth(?:\s*[0-9]+(?:\.[0-9]+)*)?|temporary|bearer)\s+)*(?:authorization|auth|keys?|credentials?|tokens?|secrets?|passwords?)\b',
        caseSensitive: false,
      ).hasMatch(sanitized.substring(match.end));
      final authorizationValueTargetAfterEcho = RegExp(
        r'^\s*(?:as\s+)?(?:(?:the|a|an|my|your|our|their|his|her|its)\s+)?(?:(?:api|access|private|oauth(?:\s*[0-9]+(?:\.[0-9]+)*)?|temporary|bearer)\s+)*(?:authorization|auth)\b',
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
            r'^\s*(?:for accurate OCR,\s*)?(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?(?:read|review|examine|inspect|identify|recognize|describe|summarize|analyze|extract|interpret|count|find|search|transcribe|translate|classify|explain|process|show|tell|check|look|scan|ocr|decode)\s+(?:(?:the|this|that|these|those|a|an)\s+)?[a-z0-9]+\s+',
            caseSensitive: false,
          ).hasMatch(beforeEcho) ||
          RegExp(
            r'^\s*(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?(?:transcribe|recognize)\s+$',
            caseSensitive: false,
          ).hasMatch(beforeEcho) ||
          readFromOcrSourcePrompt ||
          RegExp(
            r'^\s*(?:for accurate OCR,\s*)?(?:(?:can|could|would)\s+you\s+)?(?:please\s+)?(?:read|review|examine|inspect|identify|recognize|describe|summarize|analyze|extract|interpret|count|find|search|transcribe|translate|classify|explain|process|show|tell|check|look|scan|ocr|decode)\s*:\s*$',
            caseSensitive: false,
          ).hasMatch(beforeEcho) ||
          RegExp(
                r'^\s*(?:for page \d+,\s*)?(?:please\s+)?use\s+$',
                caseSensitive: false,
              ).hasMatch(beforeEcho) &&
              RegExp(
                r'^\s+to\s+(?:process|read|recognize|describe|summarize|analyze|extract|interpret|count|find|transcribe|translate|classify|identify)\b',
                caseSensitive: false,
              ).hasMatch(sanitized.substring(match.end));
      final rawEcho = match.group(1)!;
      final echo = rawEcho.replaceFirst(
        RegExp(r'''[.,!?;:)\]}"'“”‘’`/*=+_~—-]+$'''),
        '',
      );
      final prefixOffset = echo.indexOf(prefix);
      final echoSuffix =
          prefixOffset < 0 ? '' : echo.substring(prefixOffset + prefix.length);
      final hasRepeatedStructuredSuffix = allowEmbeddedPrefix &&
          _legacyOcrHasRepeatedHyphenatedAlphaComponent(prefix, echoSuffix);
      final afterEcho = sanitized.substring(match.end);
      final hasAuthorizationConnectorAfterEcho = RegExp(
        r'^\s+as\s+',
        caseSensitive: false,
      ).hasMatch(afterEcho);
      final preserveAuthorizationConnector = safeCredentialValueActionLead &&
          !hasAuthorizationConnectorAfterEcho &&
          echoSuffix.replaceAll(RegExp(r'\s+'), '').toLowerCase() == 'as';
      final hasSafeInstructionAfterEcho = RegExp(
        r'\b(?:and|then)\s+(?:(?:please)\s+)?(?:read|review|examine|inspect|identify|recognize|describe|summarize|analyze|extract|interpret|count|find|search|transcribe|translate|classify|explain|process|show|tell|check|look|scan|ocr|decode)\s+(?:(?:the|this|that|these|those|a|an)\s+)?[a-z0-9]+\b|\bbefore\s+(?:reading|checking|reviewing|examining|inspecting|identifying|recognizing|describing|summarizing|analyzing|extracting|interpreting|counting|finding|searching|transcribing|translating|classifying|explaining|processing|showing|telling|looking|scanning|decoding|locating)\s+(?:(?:the|this|that|these|those|a|an)\s+)?[a-z0-9]+\b|\bto\s+(?:verify|confirm)\s+(?:(?:the|this|that|these|those|a|an)\s+)?[a-z0-9]+\b',
        caseSensitive: false,
      ).hasMatch(afterEcho);
      if ((!hasSentenceBoundary &&
              !hasSafeInstructionLead &&
              !hasRepeatedStructuredSuffix &&
              !hasSafeInstructionAfterEcho &&
              !safeCredentialValueActionLead) ||
          echo.length <= prefix.length ||
          !_legacyOcrTextContainsMaskedCredential(echo, [value])) {
        return match.group(0)!;
      }
      final trailingPunctuation = rawEcho.substring(echo.length);
      final boundary = match.group(0)!.substring(0, boundaryLength);
      final authorizationConnector =
          preserveAuthorizationConnector ? ' as' : '';
      return '$boundary[redacted]$authorizationConnector$trailingPunctuation';
    });
    if (prefix.length < 8) {
      final lineBreakContinuation =
          _legacyOcrLineBreakContinuationAfterOpenMaskPrefix(prefix);
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

bool _legacyOcrHasOrdinaryNaturalPromptContext(
  String text,
  Match match,
  String naturalWord, {
  required bool hasCredentialUseContext,
  required bool isNaturalWordContinuation,
}) {
  final before = text.substring(0, match.start).trimRight();
  final after = text.substring(match.end).trimLeft();
  final politeNaturalVerbPrompt = naturalWord.endsWith('ize') &&
      RegExp(r'\bplease$', caseSensitive: false).hasMatch(before) &&
      RegExp(
        r'^(?:the|this|that|these|those|a|an)\b',
        caseSensitive: false,
      ).hasMatch(after);
  final naturalImperativePrompt = const {
        'recognize',
        'interpret',
        'calculate',
        'categorize',
        'enumerate',
        'determine',
        'highlight',
        'summarize',
        'translate',
        'transcribe',
        'understand',
      }.contains(naturalWord) &&
      before.isEmpty &&
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
  final naturalReadFromOcrSourcePrompt = isNaturalWordContinuation &&
      RegExp(
        r'\b(?:please\s+)?read(?:\s+(?:the|this|that|these|those|a|an))?$',
        caseSensitive: false,
      ).hasMatch(before) &&
      RegExp(
        r'^from (?:the )?(?:receipt|image|document|label|form|page|photo|note)\b',
        caseSensitive: false,
      ).hasMatch(after);
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
        r'\b(?:please\s+)?read\s+(?:(?:the|this|that|these|those|a|an))?$',
        caseSensitive: false,
      ).hasMatch(before) &&
      RegExp(
        r'^(?:label|document|receipt|invoice|record|image|sign|form|chart|page|sheet|table|login|guide)\b',
        caseSensitive: false,
      ).hasMatch(after);
  final naturalNounInstructionPrompt = RegExp(
        r'\b(?:please\s+)?(?:describe|review|examine|include|provide|extract|read\s+about|use)(?:\s+(?:the|this|that|these|those|a|an))?$',
        caseSensitive: false,
      ).hasMatch(before) &&
      (after.isEmpty ||
          RegExp(r'^[a-z]+\b', caseSensitive: false).hasMatch(after));
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
          naturalReadFromOcrSourcePrompt ||
          naturalCredentialProcessInstructionPrompt ||
          readHandwritingInstructionPrompt ||
          readNaturalNounInstructionPrompt ||
          naturalImperativePrompt ||
          naturalNounInstructionPrompt ||
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
        hasCredentialUseContext: hasCredentialUseContext,
        isNaturalWordContinuation: _legacyOcrHasNaturalWordContinuation(
          prefix,
          naturalSuffix,
        ),
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
              _legacyOcrCanRedactShortNaturalWordEcho(naturalWord)) &&
          _legacyOcrHasNaturalWordContinuation(prefix, naturalSuffix) &&
          !ordinaryNounInflection &&
          !ordinaryNaturalPromptContext;
      if (!credentialWordEcho && !naturalWordEcho) {
        return match.group(0)!;
      }
      final trailingPunctuation = rawSuffix.substring(suffix.length);
      return '${match.group(1)}[redacted]$trailingPunctuation';
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

Map<String, dynamic>? _retryDataFromTaskMap(Map<String, dynamic> map) {
  final taskId = map['id'] as String;
  final rawRetryData = map['retryData'];
  if (rawRetryData is Map) {
    try {
      return Map<String, dynamic>.from(rawRetryData);
    } catch (_) {
      // Fall through to a safe unavailable snapshot instead of dropping task.
    }
  }
  if (map['type'] != BackgroundTaskType.ocr.name) return null;

  final rawRequest = map['rawRequest'];
  final request =
      rawRequest is Map ? Map<String, dynamic>.from(rawRequest) : null;
  return _unavailableRetryDataFromLegacyRequest(taskId, request) ??
      (rawRetryData == null
          ? null
          : OcrRetryStorage.unavailableSnapshotForCount(
              taskId: taskId,
              imageCount: 0,
            ));
}

List<OcrPageOutcome> _ocrPageOutcomesFromTaskMap(dynamic rawOutcomes) {
  if (rawOutcomes is! List) return const [];
  final outcomes = <OcrPageOutcome>[];
  for (final rawOutcome in rawOutcomes) {
    final outcome = OcrPageOutcome.fromMap(rawOutcome);
    if (outcome != null) outcomes.add(outcome);
  }
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
    this.retryData,
    List<OcrPageOutcome> ocrPageOutcomes = const [],
    Iterable<String> ocrDiagnosticCredentialValues = const [],
  })  : error = type == BackgroundTaskType.ocr
            ? _sanitizeOcrTaskError(
                error,
                rawRequest,
                additionalCredentialValues: ocrDiagnosticCredentialValues,
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
                      additionalCredentialValues: ocrDiagnosticCredentialValues,
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
                additionalCredentialValues: ocrDiagnosticCredentialValues,
              )
            : rawRequest,
        rawResponse = type == BackgroundTaskType.ocr
            ? _sanitizeOcrTaskResponse(
                rawResponse,
                rawRequest,
                additionalCredentialValues: ocrDiagnosticCredentialValues,
              )
            : rawResponse,
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
                      additionalCredentialValues: ocrDiagnosticCredentialValues,
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
    final copy = BackgroundTask(
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
      retryData: clearRetryData ? null : (retryData ?? this.retryData),
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
        if (rawRequest != null) 'rawRequest': rawRequest,
        if (rawResponse != null) 'rawResponse': rawResponse,
        if (retryData != null) 'retryData': retryData,
        if (ocrPageOutcomes.isNotEmpty)
          'ocrPageOutcomes':
              ocrPageOutcomes.map((outcome) => outcome.toMap()).toList(),
      };

  factory BackgroundTask.fromMap(Map<String, dynamic> map) => BackgroundTask(
        id: map['id'] as String,
        type: BackgroundTaskType.values.byName(map['type'] as String),
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
                  (s) =>
                      BgTaskStep.fromMap(Map<String, dynamic>.from(s as Map)),
                )
                .toList() ??
            [],
        downloadedFilePath: map['downloadedFilePath'] as String?,
        rawRequest: map['rawRequest'] as Map<String, dynamic>?,
        rawResponse: map['rawResponse'] as Map<String, dynamic>?,
        retryData: _retryDataFromTaskMap(map),
        ocrPageOutcomes: _ocrPageOutcomesFromTaskMap(map['ocrPageOutcomes']),
      );
}

// ============================================================================
// Provider
// ============================================================================

final backgroundTasksProvider =
    StateNotifierProvider<BackgroundTaskNotifier, List<BackgroundTask>>(
  (ref) => BackgroundTaskNotifier(),
);

class _TaskCancellationRegistration {
  final Object owner = Object();
  final void Function() cancel;

  _TaskCancellationRegistration(this.cancel);
}

class BackgroundTaskNotifier extends StateNotifier<List<BackgroundTask>> {
  final _uuid = const Uuid();
  final Map<String, _TaskCancellationRegistration> _cancellations = {};

  /// Returns a live task by ID, or null after removal or notifier disposal.
  BackgroundTask? taskById(String taskId) {
    if (!mounted) return null;
    return state.where((task) => task.id == taskId).firstOrNull;
  }

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
    failTask(taskId, error: '已取消');
  }

  /// 测试专用：覆盖持久化目录。
  ///
  /// 持久化测试需要隔离的目录（真实测试环境所有测试共享同一个
  /// AppStorage 目录，异步写入链可能跨测试交错，导致读脏数据）。
  @visibleForTesting
  static String? debugStorageDirectoryOverride;

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

  BackgroundTaskNotifier() : super([]);

  @override
  void dispose() {
    for (final registration in _cancellations.values.toList()) {
      registration.cancel();
    }
    _cancellations.clear();
    _disposedSnapshot = List.of(state);
    _iosSyncTimer?.cancel();
    _iosSyncTimer = null;
    super.dispose();
  }

  /// Add a new background task and return its ID.
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
    _pendingRestoreTaskRemovals.remove(id);
    _pendingTaskRemovalReconciliations.remove(id);
    final steps = type.stepLabels
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
    state = [task, ...state];
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

  /// Mark a task as failed with an optional error message.
  void failTask(
    String taskId, {
    String? error,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
  }) {
    _updateTask(
      taskId,
      TaskStatus.failed,
      error: error,
      rawRequest: rawRequest,
      rawResponse: rawResponse,
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
  void markPartialResultSaveRequested(String taskId) {
    state = state
        .map(
          (task) => task.id == taskId
              ? task.copyWith(partialSaveRequested: true)
              : task,
        )
        .toList();
    _persistTasks();
  }

  /// Reopen the save step for a failed OCR task whose result is still present.
  void startSaveRetry(String taskId) {
    state = state.map((task) {
      if (task.id != taskId ||
          task.type != BackgroundTaskType.ocr ||
          task.status != TaskStatus.failed ||
          task.result == null) {
        return task;
      }
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
    final removalToken = _recordPendingRestoreTaskRemoval(taskId);
    _pendingTaskRemovalReconciliations[taskId] = removalToken;
    _cancellations.remove(taskId)?.cancel();
    final removed = state.where((task) => task.id == taskId).firstOrNull;
    state = state.where((t) => t.id != taskId).toList();
    if (removed?.type == BackgroundTaskType.ocr && removed?.retryData != null) {
      final references = OcrRetryStorage.referencesFromSnapshot(
        removed!.retryData,
      );
      _persistOcrTaskRemoval(taskId, references);
    } else {
      _persistTasks(
        excludedPersistedTaskIds: {taskId},
        retryOnceOnRemovalWriteFailure: true,
      );
    }
    _syncIosContinuedTask();
  }

  /// Save removals before publishing them; absent IDs also retry disk cleanup.
  Future<bool> removeTasksPersisted(Iterable<String> ids) async {
    final removedIds = ids.toSet();
    final addedTaskGenerations = <String, Set<Object>>{
      for (final id in removedIds) id: <Object>{},
    };
    _activeBatchRemovalAddedGenerations.add(addedTaskGenerations);
    try {
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
        return true;
      } finally {
        _removalBarrier = null;
        gate.complete();
      }
    } finally {
      _activeBatchRemovalAddedGenerations.remove(addedTaskGenerations);
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

  Future<void> _persistOcrTaskRemoval(String taskId, Set<String> references) {
    final barrier = _removalBarrier;
    if (barrier == null) {
      final write = _writeSnapshot(
        state,
        excludedPersistedTaskIds: {taskId},
        retryOnceOnRemovalWriteFailure: true,
      );
      return _pendingWrite = write.then<void>((saved) async {
        if (saved) {
          await _deleteUnreferencedOcrCache(references);
          await _cleanupOrphanedOcrCache();
        }
      });
    }

    final previous = _pendingWrite ?? Future<void>.value();
    final dirOverride = debugStorageDirectoryOverride;
    final deferred = previous.then((_) async {
      await barrier.future;
      final snapshot = mounted ? state : _disposedSnapshot;
      if (snapshot == null) return;
      final saved = await _writeSnapshotNow(
        snapshot,
        dirOverride,
        excludedPersistedTaskIds: {taskId},
        retryOnceOnRemovalWriteFailure: true,
      );
      if (saved) {
        await _deleteUnreferencedOcrCache(references);
        await _cleanupOrphanedOcrCache();
      }
    });
    _pendingWrite = deferred;
    if (!mounted) _disposedPersistence = deferred;
    return deferred;
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

  void _updateTask(
    String taskId,
    TaskStatus status, {
    String? error,
    String? downloadedFilePath,
    bool? resultSavedAsPartial,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
  }) {
    BackgroundTask? oldTask;
    state = state.map((t) {
      if (t.id != taskId) return t;
      oldTask = t;
      final shouldClearError = error == null && status == TaskStatus.completed;
      return t.copyWith(
        status: status,
        error: error,
        clearError: shouldClearError,
        downloadedFilePath: downloadedFilePath,
        resultSavedAsPartial: resultSavedAsPartial,
        rawRequest: rawRequest,
        rawResponse: rawResponse,
        completedAt:
            status == TaskStatus.completed || status == TaskStatus.failed
                ? DateTime.now()
                : null,
      );
    }).toList();
    _persistTasks();

    // Send notification when task completes or fails
    if ((status == TaskStatus.completed || status == TaskStatus.failed) &&
        oldTask != null) {
      _sendTaskNotification(oldTask!, status, error);
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
        typeLabel: task.type.label,
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
    unawaited(IosContinuedTaskService.instance.submit());
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
  Completer<void>? _removalBarrier;
  Completer<void>? _restoreBarrier;
  int _restoreGeneration = 0;
  final Map<String, Object> _pendingRestoreTaskRemovals = <String, Object>{};
  final Map<String, Object> _pendingTaskRemovalReconciliations =
      <String, Object>{};
  final List<Map<String, Set<Object>>> _activeBatchRemovalAddedGenerations = [];
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
      final write = _writeSnapshot(
        snapshot,
        preserveSkippedEntries: preserveCurrentSkippedEntries,
        excludedPersistedTaskIds: excludedPersistedTaskIds,
        retryOnceOnRemovalWriteFailure: retryOnceOnRemovalWriteFailure,
      );
      _disposedPersistence ??= write.then<void>((_) {});
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
    // 串行化写入：每次写入排在上一次写入完成之后。
    final write = (_pendingWrite ?? Future<void>.value()).then((_) {
      return _writeSnapshotNow(
        snapshot,
        dirOverride,
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
    var currentSnapshot =
        snapshot.where((task) => !excludedTaskIds.contains(task.id)).toList();
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
          _restoreBarrier != null) {
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
    final skippedEntries = canPreserveSkippedEntries
        ? List<dynamic>.unmodifiable(_skippedTaskEntries)
        : const <dynamic>[];

    final saved = _hasCacheMigrations(currentSnapshot)
        ? await OcrRetryStorage.withCacheMaintenanceLock(
            () => _writePreparedSnapshot(
              currentSnapshot,
              dirOverride,
              preservedEntries: skippedEntries,
            ),
          )
        : await _writePreparedSnapshot(
            currentSnapshot,
            dirOverride,
            preservedEntries: skippedEntries,
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
        preserveSkippedEntries: preserveCurrentSkippedEntries,
        excludedPersistedTaskIds: retryExcludedTaskIds,
      );
    }
    if (saved) {
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
    final prepared = await _prepareOcrRetriesForPersistence(snapshot);
    if (prepared == null) return false;
    _publishPreparedRetrySnapshots(snapshot, prepared);
    final data = <dynamic>[
      ...prepared.map((task) => task.toMap()),
      ...preservedEntries,
    ];
    return _writeSnapshotData(data, dirOverride);
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
      if (task.type != BackgroundTaskType.ocr || task.retryData == null) {
        continue;
      }
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

  Future<Set<String>?> _ocrCacheReferencesForCleanup() async {
    final persisted = await _loadPersistedTasks();
    if (!persisted.isReadable) return null;
    final tasks = mounted ? state : (_disposedSnapshot ?? const []);
    return {
      for (final task in tasks)
        if (task.type == BackgroundTaskType.ocr)
          ...OcrRetryStorage.referencesFromSnapshot(task.retryData),
      for (final task in persisted.tasks)
        if (task.type == BackgroundTaskType.ocr)
          ...OcrRetryStorage.referencesFromSnapshot(task.retryData),
      ..._referencesFromSkippedTaskEntries(),
      ..._referencesFromSkippedTaskEntries(persisted.skippedEntries),
    };
  }

  Set<String> _referencesFromSkippedTaskEntries([Iterable<dynamic>? entries]) {
    final references = <String>{};
    for (final entry in entries ?? _skippedTaskEntries) {
      if (entry is! Map) continue;
      final retryData = entry['retryData'];
      if (retryData is! Map) continue;
      try {
        references.addAll(
          OcrRetryStorage.referencesFromSnapshot(
            Map<String, dynamic>.from(retryData),
          ),
        );
      } catch (_) {
        // Unknown persisted data must never expand the set of deletable paths.
      }
    }
    return references;
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
          identical(before.retryData, after.retryData)) {
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

  Future<
      ({
        List<BackgroundTask> tasks,
        bool isComplete,
        bool isReadable,
        List<dynamic> skippedEntries,
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
          isReadable: true,
          skippedEntries: <dynamic>[],
        );
      }
      if (waitForDebugRead) await debugBeforeTaskSnapshotRead?.call();
      final content = await file.readAsString();
      if (waitForDebugRead) await debugAfterTaskSnapshotRead?.call();
      if (content.isEmpty) {
        return (
          tasks: <BackgroundTask>[],
          isComplete: false,
          isReadable: false,
          skippedEntries: <dynamic>[],
        );
      }
      final list = jsonDecode(content) as List;
      final tasks = <BackgroundTask>[];
      final skippedEntries = <dynamic>[];
      var isComplete = true;
      for (final m in list) {
        try {
          tasks.add(
            BackgroundTask.fromMap(Map<String, dynamic>.from(m as Map)),
          );
        } catch (e) {
          // 单个损坏条目不应导致整个恢复失败：跳过并继续，
          // 保证其余有效任务仍能恢复。
          isComplete = false;
          skippedEntries.add(m);
          debugPrint(
            '[BackgroundTaskNotifier] Skipping corrupt task entry: $e',
          );
        }
      }
      return (
        tasks: tasks,
        isComplete: isComplete,
        isReadable: true,
        skippedEntries: skippedEntries,
      );
    } catch (e) {
      debugPrint('[BackgroundTaskNotifier] Failed to load persisted tasks: $e');
      return (
        tasks: <BackgroundTask>[],
        isComplete: false,
        isReadable: false,
        skippedEntries: <dynamic>[],
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
  Future<void> restoreFromPersistence() async {
    final activeRestore = _restoreBarrier;
    if (activeRestore != null) {
      await activeRestore.future;
      await pendingPersistence;
      return;
    }
    final restoreBarrier = Completer<void>();
    _restoreGeneration++;
    _restoreBarrier = restoreBarrier;
    try {
      await _restorePersistedTasks(restoreBarrier);
    } finally {
      _completeRestoreBarrier(restoreBarrier);
    }
  }

  Future<void> _restorePersistedTasks(Completer<void> restoreBarrier) async {
    final loaded = await _loadPersistedTasks();
    _taskSnapshotIncomplete = !loaded.isComplete;
    _taskSnapshotCanPreserveSkippedEntries =
        loaded.isReadable && !loaded.isComplete;
    _skippedTaskEntries = loaded.skippedEntries;
    final tasks = loaded.tasks;
    if (!loaded.isComplete) {
      // A partial snapshot cannot prove a pending deletion was saved; keep
      // parsed tasks visible, matching removeTask's partial-write behavior.
      _pendingRestoreTaskRemovals.clear();
    }
    if (tasks.isEmpty) {
      if (loaded.isComplete) {
        _pendingRestoreTaskRemovals.clear();
        await _cleanupOrphanedOcrCache();
      }
      return;
    }
    final restored = <BackgroundTask>[];
    for (var task in tasks) {
      // A partial task list is not authoritative enough to publish retry-data
      // sanitation: a later deletion may be refused, leaving the old snapshot
      // on disk. Keep each parsed task's retry data unchanged until the full
      // task file can be durably rewritten.
      if (loaded.isComplete &&
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
      restored.add(
        task.status == TaskStatus.running
            ? task.copyWith(status: TaskStatus.failed, error: '应用重启，已中断')
            : task,
      );
    }
    final pendingRemovals = Map<String, Object>.of(_pendingRestoreTaskRemovals);
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
    // A partial parse cannot safely replace the authoritative file: skipped
    // entries may still own retry-cache references.
    final snapshotSaved = loaded.isComplete && await _persistTasks();
    if (snapshotSaved) {
      _clearPendingRestoreTaskRemovals(pendingRemovals);
    }
    // 恢复后没有运行中的任务（进程已重启），结束 iOS 常驻任务保护。
    _syncIosContinuedTask();
    if (loaded.isComplete && snapshotSaved) {
      await _cleanupOrphanedOcrCache();
    }
    debugPrint(
      '[BackgroundTaskNotifier] Restored ${tasks.length} tasks from persistence',
    );
  }

  void _completeRestoreBarrier(Completer<void> barrier) {
    if (identical(_restoreBarrier, barrier)) _restoreBarrier = null;
    if (!barrier.isCompleted) barrier.complete();
  }
}
