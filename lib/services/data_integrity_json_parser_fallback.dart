import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

@visibleForTesting
Future<String> Function(List<Object?> message)?
    debugPrimaryValidationWorkerForTesting;
@visibleForTesting
Future<String> Function(List<Object?> message)?
    debugBundledValidationWorkerForTesting;

Future<List<String?>> parseJsonBatch(List<String> contents) async =>
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

Future<Map<String, Object?>> validateJsonBatchAndDataFormatsWeb(
  List<String> contents, {
  int? providerEntriesIndex,
  int? conversationsIndex,
}) async =>
    throw UnsupportedError('Web JSON worker is not available on this platform');

Future<List<Map<String, String?>>> checkDataIntegrityWeb(
  String? providerEntriesJson,
) async =>
    throw UnsupportedError('Web JSON worker is not available on this platform');
