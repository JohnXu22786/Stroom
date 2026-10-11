import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import 'startup_data_validation_unavailable.dart';

@visibleForTesting
Future<String> Function(List<Object?> message)?
    debugPrimaryValidationWorkerForTesting;
@visibleForTesting
Future<String> Function(List<Object?> message)?
    debugBundledValidationWorkerForTesting;

Future<List<String?>> parseJsonBatch(List<String> contents) async {
  if (contents.isEmpty) return const [];
  final message = ['parseJsonBatch', contents];
  try {
    return _decodeParseErrors(
      await _runPrimaryValidationWorker(message),
      contents.length,
    );
  } catch (primaryError) {
    debugPrint('[DataIntegrityChecker] JSON worker failed; '
        'retrying bundled worker: $primaryError');
    try {
      final testWorker = debugBundledValidationWorkerForTesting;
      final response = testWorker == null
          ? await _runBundledValidationWorker(message)
          : await testWorker(message);
      return _decodeParseErrors(response, contents.length);
    } catch (bundledWorkerError) {
      throw StartupDataValidationUnavailable(
        primaryError,
        bundledWorkerError,
      );
    }
  }
}

Future<Map<String, Object?>> validateJsonBatchAndDataFormatsWeb(
  List<String> contents, {
  int? providerEntriesIndex,
  int? conversationsIndex,
}) async {
  final message = [
    'validateJsonBatchAndDataFormats',
    contents,
    providerEntriesIndex,
    conversationsIndex,
  ];
  try {
    return _decodeJsonBatchAndValidation(
      await _runPrimaryValidationWorker(message),
      contents.length,
    );
  } catch (primaryError) {
    debugPrint('[DataIntegrityChecker] Combined JSON worker failed; '
        'retrying bundled worker: $primaryError');
    try {
      final testWorker = debugBundledValidationWorkerForTesting;
      final response = testWorker == null
          ? await _runBundledValidationWorker(message)
          : await testWorker(message);
      return _decodeJsonBatchAndValidation(response, contents.length);
    } catch (bundledWorkerError) {
      throw StartupDataValidationUnavailable(
        primaryError,
        bundledWorkerError,
      );
    }
  }
}

/// Runs the legacy conversation block conversion in the Web worker and returns
/// the resulting JSON text without parsing that large payload on the UI thread.
Future<Map<String, Object?>> migrateLegacyConversationsWeb(String raw,
    {bool canonical = false}) async {
  final message = [
    canonical ? 'canonicalizeConversations' : 'migrateLegacyConversations',
    raw
  ];
  Object? primaryError;
  try {
    return _decodeLegacyMigrationResponse(
      await _runPrimaryValidationWorker(message),
    );
  } catch (error) {
    primaryError = error;
    debugPrint('[DataMigrationService] Conversation migration worker failed; '
        'retrying bundled worker: $error');
  }

  try {
    final testWorker = debugBundledValidationWorkerForTesting;
    final response = testWorker == null
        ? await _runBundledValidationWorker(message)
        : await testWorker(message);
    return _decodeLegacyMigrationResponse(response);
  } catch (bundledError) {
    throw StartupDataValidationUnavailable(primaryError, bundledError);
  }
}

Future<Map<String, Object?>> prepareLegacyChatConfigsWeb(String raw) =>
    _runMigrationWorker(
      ['prepareLegacyChatConfigs', raw],
      'legacy chat configuration preparation',
    );

Future<Map<String, Object?>> mergeLegacyChatConfigsWeb(
  String migratedConfigs,
  String? existingEntries,
) =>
    _runMigrationWorker(
      ['mergeLegacyChatConfigs', migratedConfigs, existingEntries],
      'legacy chat configuration merge',
    );

Future<Map<String, Object?>> fixProviderEntriesWeb(String raw) =>
    _runMigrationWorker(
      ['fixProviderEntries', raw],
      'provider entry migration',
    );

Future<Map<String, Object?>> migrateProviderModelSettingsWeb(String raw) =>
    _runMigrationWorker(
      ['migrateProviderModelSettings', raw],
      'provider model migration',
    );

Future<Map<String, Object?>> migrateWebManifestData(
  Uint8List raw,
  List<String> folderTables,
  bool removeLegacyFolders,
  bool migrateOldVideos,
) async {
  final rawLength = raw.lengthInBytes;
  final message = [
    'migrateWebManifestData',
    raw,
    folderTables,
    removeLegacyFolders,
    migrateOldVideos,
  ];
  Object? primaryError;
  try {
    return _decodeWebManifestMigrationResponse(
      await _runPrimaryValidationWorkerData(message),
    );
  } catch (error) {
    primaryError = error;
    if (_wasManifestBufferTransferred(raw, rawLength)) {
      throw StartupDataValidationUnavailable.migration(
        StateError(
          'Manifest worker failed after transferring bytes; cannot retry: '
          '$error',
        ),
      );
    }
    debugPrint('[DataMigrationService] Web manifest migration worker failed; '
        'retrying bundled worker: $error');
  }

  try {
    final testWorker = debugBundledValidationWorkerForTesting;
    final response = testWorker == null
        ? await _runBundledValidationWorkerData(message)
        : await testWorker(message);
    return _decodeWebManifestMigrationResponse(response);
  } catch (bundledError) {
    throw StartupDataValidationUnavailable(primaryError, bundledError);
  }
}

/// Validate the persisted Web media manifest in the worker before startup
/// migration versions are advanced.
Future<Map<String, Object?>> validateWebManifestData(Uint8List raw) async {
  final rawLength = raw.lengthInBytes;
  final request = <Object?>['validateWebManifestData', raw];
  try {
    return _decodeWebManifestValidationResponse(
      await _runPrimaryValidationWorker(request),
    );
  } catch (primaryError) {
    if (_wasManifestBufferTransferred(raw, rawLength)) {
      throw StartupDataValidationUnavailable.migration(
        StateError(
          'Manifest validation worker failed after transferring bytes; '
          'cannot retry: $primaryError',
        ),
      );
    }
    debugPrint('[DataMigrationService] Web manifest validation worker failed; '
        'retrying bundled worker: $primaryError');
    try {
      final testWorker = debugBundledValidationWorkerForTesting;
      final response = testWorker == null
          ? await _runBundledValidationWorker(request)
          : await testWorker(request);
      return _decodeWebManifestValidationResponse(response);
    } catch (bundledError) {
      throw StartupDataValidationUnavailable(primaryError, bundledError);
    }
  }
}

bool _wasManifestBufferTransferred(Uint8List raw, int originalLength) =>
    originalLength > 0 && raw.buffer.lengthInBytes == 0;

Map<String, Object?> _decodeWebManifestValidationResponse(String response) {
  final decoded = jsonDecode(response);
  if (decoded is! Map || decoded['status'] is! String) {
    throw StateError('Invalid Web manifest validation response');
  }
  return Map<String, Object?>.from(decoded);
}

Map<String, Object?> _decodeWebManifestMigrationResponse(Object? response) {
  if (response is String) {
    final decoded = _decodeMigrationWorkerResponse(response);
    final payload = decoded.remove('payload');
    if (payload is String && payload.isNotEmpty) {
      // The string response is retained only for older test worker callbacks.
      // Production workers return transferable UTF-8 bytes.
      decoded['payloadBytes'] = Uint8List.fromList(utf8.encode(payload));
    }
    return decoded;
  }

  if (response is! Map) {
    throw StateError('Invalid Web manifest worker response');
  }
  final rawMetadata = response['metadata'];
  final rawPayload = response['payload'];

  if (rawMetadata is! String) {
    throw StateError('Invalid Web manifest worker metadata');
  }
  final decodedMetadata = jsonDecode(rawMetadata);
  if (decodedMetadata is! Map || decodedMetadata['status'] is! String) {
    throw StateError('Invalid Web manifest worker metadata');
  }
  final hasPayload = decodedMetadata.remove('hasPayload');
  if (hasPayload is! bool || hasPayload != (rawPayload != null)) {
    throw StateError('Invalid Web manifest worker payload state');
  }
  return {
    ...Map<String, Object?>.from(decodedMetadata),
    'payloadBytes': rawPayload == null ? null : _workerPayloadBytes(rawPayload),
  };
}

Uint8List _workerPayloadBytes(Object payload) {
  if (payload is Uint8List) return payload;
  if (payload is ByteBuffer) return Uint8List.view(payload);
  throw StateError('Invalid Web manifest worker payload');
}

Future<Map<String, Object?>> _runMigrationWorker(
  List<Object?> message,
  String operationName,
) async {
  Object? primaryError;
  try {
    return _decodeMigrationWorkerResponse(
      await _runPrimaryValidationWorker(message),
    );
  } catch (error) {
    primaryError = error;
    debugPrint('[DataMigrationService] $operationName worker failed; '
        'retrying bundled worker: $error');
  }

  try {
    final testWorker = debugBundledValidationWorkerForTesting;
    final response = testWorker == null
        ? await _runBundledValidationWorker(message)
        : await testWorker(message);
    return _decodeMigrationWorkerResponse(response);
  } catch (bundledError) {
    throw StartupDataValidationUnavailable(primaryError, bundledError);
  }
}

Map<String, Object?> _decodeMigrationWorkerResponse(String response) {
  final headerEnd = response.indexOf('\n');
  if (headerEnd < 0) throw StateError('Invalid migration worker response');
  final decoded = jsonDecode(response.substring(0, headerEnd));
  if (decoded is! Map || decoded['status'] is! String) {
    throw StateError('Invalid migration worker response');
  }
  return {
    ...Map<String, Object?>.from(decoded),
    'payload': response.substring(headerEnd + 1),
  };
}

Map<String, Object?> _decodeLegacyMigrationResponse(String response) {
  if (response == 'not-list') return {'isList': false};
  if (response.startsWith('parse-error\n')) {
    final message = jsonDecode(response.substring('parse-error\n'.length));
    if (message is! String) {
      throw StateError('Invalid conversation worker response');
    }
    return {'parseError': message};
  }
  final headerEnd = response.indexOf('\n');
  if (headerEnd < 0) throw StateError('Invalid conversation worker response');

  final header = response.substring(0, headerEnd).split(':');
  if (header.length != 3 ||
      header[0] != 'ok' ||
      int.tryParse(header[1]) == null ||
      int.tryParse(header[2]) == null) {
    throw StateError('Invalid conversation worker response');
  }

  return {
    'isList': true,
    'migrated': int.parse(header[1]),
    'skipped': int.parse(header[2]),
    'encoded': response.substring(headerEnd + 1),
  };
}

Map<String, Object?> _decodeJsonBatchAndValidation(
  String response,
  int expectedLength,
) {
  final decoded = jsonDecode(response);
  if (decoded is! Map) throw StateError('Invalid JSON worker response');
  final rawParseErrors = decoded['parseErrors'];
  final rawIssues = decoded['issues'];
  if (rawParseErrors is! List ||
      rawParseErrors.length != expectedLength ||
      rawParseErrors.any((value) => value != null && value is! String) ||
      rawIssues is! List ||
      rawIssues.any((issue) => !_isValidationIssue(issue))) {
    throw StateError('Invalid JSON worker response');
  }
  return {
    'parseErrors': rawParseErrors.cast<String?>(),
    'issues': rawIssues
        .map((issue) => Map<String, Object?>.from(issue as Map))
        .toList(),
  };
}

List<String?> _decodeParseErrors(String response, int expectedLength) {
  final decoded = jsonDecode(response);
  if (decoded is! List ||
      decoded.length != expectedLength ||
      decoded.any((value) => value != null && value is! String)) {
    throw StateError('Invalid JSON worker response');
  }
  return decoded.cast<String?>();
}

Future<List<Map<String, String?>>> validateDataFormatsWeb(
  String? providerEntriesJson,
  String? conversationsJson,
) async {
  return _runValidationWorker(
    [
      'validateDataFormats',
      providerEntriesJson,
      conversationsJson,
    ],
    'format validation',
  );
}

Future<List<Map<String, String?>>> checkDataIntegrityWeb(
  String? providerEntriesJson,
) async {
  return _runValidationWorker(
    ['checkDataIntegrity', providerEntriesJson],
    'integrity check',
  );
}

Future<List<Map<String, String?>>> _runValidationWorker(
  List<Object?> message,
  String checkName,
) async {
  try {
    return _decodeIssues(await _runPrimaryValidationWorker(message));
  } catch (primaryError) {
    debugPrint('[DataIntegrityChecker] $checkName worker failed; '
        'retrying bundled worker: $primaryError');
    try {
      final testWorker = debugBundledValidationWorkerForTesting;
      final response = testWorker == null
          ? await _runBundledValidationWorker(message)
          : await testWorker(message);
      return _decodeIssues(response);
    } catch (bundledWorkerError) {
      throw StartupDataValidationUnavailable(
        primaryError,
        bundledWorkerError,
      );
    }
  }
}

List<Map<String, String?>> _decodeIssues(String response) {
  final decoded = jsonDecode(response);
  if (decoded is! List || decoded.any((issue) => !_isValidationIssue(issue))) {
    throw StateError('Invalid JSON worker response');
  }
  return decoded
      .map((issue) => Map<String, String?>.from(issue as Map))
      .toList();
}

bool _isValidationIssue(Object? value) {
  if (value is! Map) return false;
  final message = value['message'];
  final severity = value['severity'];
  final dataKey = value['dataKey'];
  return message is String &&
      message.isNotEmpty &&
      (severity == 'error' || severity == 'warning') &&
      (dataKey == null || dataKey is String);
}

Future<String> _runPrimaryValidationWorker(List<Object?> message) {
  final testWorker = debugPrimaryValidationWorkerForTesting;
  return testWorker == null ? _runWorker(message) : testWorker(message);
}

Future<Object?> _runPrimaryValidationWorkerData(List<Object?> message) {
  final testWorker = debugPrimaryValidationWorkerForTesting;
  return testWorker == null ? _runWorkerData(message) : testWorker(message);
}

Future<String> _runBundledValidationWorker(List<Object?> message) async {
  final response = await _runBundledValidationWorkerData(message);
  if (response is! String) {
    throw StateError('Invalid JSON worker response');
  }
  return response;
}

Future<Object?> _runBundledValidationWorkerData(
  List<Object?> message,
) async {
  final source =
      await rootBundle.loadString('web/data_integrity_json_worker.js');
  final workerUrl = html.Url.createObjectUrlFromBlob(
    html.Blob([source], 'application/javascript'),
  );
  try {
    return await _runWorkerDataAtUrl(message, workerUrl);
  } finally {
    html.Url.revokeObjectUrl(workerUrl);
  }
}

Future<String> _runWorker(List<Object?> message) async {
  return _runWorkerAtUrl(message, _workerUrl());
}

Future<String> _runWorkerAtUrl(List<Object?> message, String url) async {
  final response = await _runWorkerDataAtUrl(message, url);
  if (response is! String) {
    throw StateError('Invalid JSON worker response');
  }
  return response;
}

Future<Object?> _runWorkerData(List<Object?> message) =>
    _runWorkerDataAtUrl(message, _workerUrl());

Future<Object?> _runWorkerDataAtUrl(
  List<Object?> message,
  String url,
) async {
  final result = Completer<Object?>();
  final isManifestMigration =
      message.isNotEmpty && message.first == 'migrateWebManifestData';
  final hasTransferableManifest = message.isNotEmpty &&
      (message.first == 'migrateWebManifestData' ||
          message.first == 'validateWebManifestData');
  String? manifestMetadata;
  html.Worker? worker;
  StreamSubscription<html.MessageEvent>? messageSubscription;
  StreamSubscription<html.Event>? errorSubscription;
  try {
    final activeWorker = html.Worker(url);
    worker = activeWorker;
    messageSubscription = activeWorker.onMessage.listen((event) {
      if (result.isCompleted) return;
      if (!isManifestMigration) {
        result.complete(event.data);
        return;
      }

      if (manifestMetadata == null) {
        final data = event.data;
        if (data is! String) {
          result.completeError(
            StateError('Invalid Web manifest worker metadata message'),
          );
          return;
        }
        try {
          final metadata = jsonDecode(data);
          if (metadata is! Map ||
              metadata['status'] is! String ||
              metadata['hasPayload'] is! bool) {
            throw StateError('Invalid Web manifest worker metadata');
          }
          if (metadata['hasPayload'] as bool) {
            manifestMetadata = data;
          } else {
            result.complete({'metadata': data, 'payload': null});
          }
        } catch (error, stackTrace) {
          result.completeError(error, stackTrace);
        }
        return;
      }

      final data = event.data;
      if (data is! Uint8List && data is! ByteBuffer) {
        result.completeError(
          StateError('Invalid Web manifest worker payload message'),
        );
        return;
      }
      result.complete({'metadata': manifestMetadata, 'payload': data});
    });
    errorSubscription = activeWorker.onError.listen((event) {
      if (!result.isCompleted) {
        final message = event is html.ErrorEvent
            ? event.message ?? 'JSON worker failed'
            : 'JSON worker failed';
        result.completeError(StateError(message));
      }
    });
    final transferList =
        hasTransferableManifest ? [(message[1] as Uint8List).buffer] : null;
    // Move the manifest bytes into the worker instead of cloning them on UI.
    activeWorker.postMessage(message, transferList);
    return await result.future;
  } finally {
    if (messageSubscription != null) await messageSubscription.cancel();
    if (errorSubscription != null) await errorSubscription.cancel();
    worker?.terminate();
  }
}

String _workerUrl() {
  final baseHref = html.document.querySelector('base')?.getAttribute('href');
  final appBase =
      Uri.parse(html.window.location.href).resolve(baseHref ?? './');
  return appBase.resolve('data_integrity_json_worker.js').toString();
}
