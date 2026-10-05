import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show debugPrint;

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
  final decoded = jsonDecode(
    await _runWorker([
      'validateDataFormats',
      providerEntriesJson,
      conversationsJson,
    ]),
  );
  if (decoded is! List || decoded.any((issue) => issue is! Map)) {
    throw StateError('Invalid JSON worker response');
  }
  return decoded
      .map((issue) => Map<String, String?>.from(issue as Map))
      .toList();
}

Future<String> _runWorker(List<Object?> message) async {
  final result = Completer<String>();
  html.Worker? worker;
  StreamSubscription<html.MessageEvent>? messageSubscription;
  StreamSubscription<html.Event>? errorSubscription;
  try {
    final activeWorker = html.Worker(_workerUrl());
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
  final appBase = Uri.parse(html.window.location.href)
      .resolve(baseHref ?? './');
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
