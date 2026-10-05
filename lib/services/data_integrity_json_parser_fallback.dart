import 'dart:convert';

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

Future<List<Map<String, String?>>> checkDataIntegrityWeb(
  String? providerEntriesJson,
) async =>
    throw UnsupportedError('Web JSON worker is not available on this platform');
