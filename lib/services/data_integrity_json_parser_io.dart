import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import 'startup_data_validation_unavailable.dart';

@visibleForTesting
Future<List<String?>> Function(List<String?> Function() computation)?
    debugJsonBatchIsolateRunnerForTesting;

Future<List<String?>> _runJsonBatchIsolate(
  List<String?> Function() computation,
) {
  final runner = debugJsonBatchIsolateRunnerForTesting;
  return runner == null ? Isolate.run(computation) : runner(computation);
}

@visibleForTesting
Future<String> Function(List<Object?> message)?
    debugPrimaryValidationWorkerForTesting;
@visibleForTesting
Future<String> Function(List<Object?> message)?
    debugBundledValidationWorkerForTesting;

Future<List<String?>> parseJsonBatch(List<String> contents) async {
  if (contents.isEmpty) return const [];
  try {
    return await _runJsonBatchIsolate(() => _parseJsonBatchSync(contents));
  } catch (e) {
    debugPrint('[DataIntegrityChecker] JSON Isolate 不可用，验证已中止: $e');
    throw StartupDataValidationUnavailable.isolate(e);
  }
}

@pragma('vm:entry-point')
List<String?> _parseJsonBatchSync(List<String> contents) =>
    contents.map((content) {
      try {
        jsonDecode(content);
        return null;
      } catch (e) {
        return e.toString();
      }
    }).toList();

Future<List<Map<String, String?>>> validateDataFormatsWeb(
  String? providerEntriesJson,
  String? conversationsJson,
) async =>
    throw UnsupportedError('Web JSON worker is not available on this platform');

Future<List<Map<String, String?>>> checkDataIntegrityWeb(
  String? providerEntriesJson,
) async =>
    throw UnsupportedError('Web JSON worker is not available on this platform');
