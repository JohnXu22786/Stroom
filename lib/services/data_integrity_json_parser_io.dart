import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show debugPrint;

Future<List<String?>> parseJsonBatch(List<String> contents) async {
  if (contents.isEmpty) return const [];
  try {
    return await Isolate.run(() => _parseJsonBatchSync(contents));
  } catch (e) {
    debugPrint('[DataIntegrityChecker] JSON Isolate 不可用，回退同步解析: $e');
    return _parseJsonBatchSync(contents);
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
