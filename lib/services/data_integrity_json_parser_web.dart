import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

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
  try {
    final decoded = jsonDecode(await _runWorker(['parseJsonBatch', contents]));
    if (decoded is! List ||
        decoded.length != contents.length ||
        decoded.any((value) => value != null && value is! String)) {
      throw StateError('Invalid JSON worker response');
    }
    return decoded.cast<String?>();
  } catch (e) {
    debugPrint('[DataIntegrityChecker] JSON Worker 不可用，回退同步解析: $e');
    return contents.map(_parseJsonSync).toList();
  }
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

Future<String> _runBundledValidationWorker(List<Object?> message) async {
  final source =
      await rootBundle.loadString('web/data_integrity_json_worker.js');
  final workerUrl = html.Url.createObjectUrlFromBlob(
    html.Blob([source], 'application/javascript'),
  );
  try {
    return await _runWorkerAtUrl(message, workerUrl);
  } finally {
    html.Url.revokeObjectUrl(workerUrl);
  }
}

Future<String> _runWorker(List<Object?> message) async {
  return _runWorkerAtUrl(message, _workerUrl());
}

Future<String> _runWorkerAtUrl(List<Object?> message, String url) async {
  final result = Completer<String>();
  html.Worker? worker;
  StreamSubscription<html.MessageEvent>? messageSubscription;
  StreamSubscription<html.Event>? errorSubscription;
  try {
    final activeWorker = html.Worker(url);
    worker = activeWorker;
    messageSubscription = activeWorker.onMessage.listen((event) {
      if (event.data is! String) {
        if (!result.isCompleted) {
          result.completeError(StateError('Invalid JSON worker response'));
        }
        return;
      }
      if (!result.isCompleted) result.complete(event.data as String);
    });
    errorSubscription = activeWorker.onError.listen((event) {
      if (!result.isCompleted) {
        final message = event is html.ErrorEvent
            ? event.message ?? 'JSON worker failed'
            : 'JSON worker failed';
        result.completeError(StateError(message));
      }
    });
    activeWorker.postMessage(message);
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

String? _parseJsonSync(String content) {
  try {
    jsonDecode(content);
    return null;
  } catch (e) {
    return e.toString();
  }
}
