import 'dart:async';
import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'batch_rename_config.dart';
import 'batch_rename_regex.dart';

/// A real browser worker is required: Flutter compute runs on the UI on web.
class BatchRenameRegexWorker {
  final Duration timeout;
  bool _disposed = false;
  void Function()? _cancelPending;
  BatchRenameRegexWorker({this.timeout = const Duration(seconds: 2)});

  Future<List<BatchRenameRegexResult>> replace(
      List<String> names, BatchReplaceOp op) async {
    if (_disposed) throw BatchRenameRegexCancelled();
    if (_cancelPending != null) throw StateError('正则计算尚未完成');
    final url = html.Url.createObjectUrlFromBlob(
        html.Blob([_workerSource], 'application/javascript'));
    html.Worker? worker;
    StreamSubscription? messages;
    StreamSubscription? errors;
    Timer? timer;
    final done = Completer<List<BatchRenameRegexResult>>();
    void fail(Object error) {
      if (!done.isCompleted) done.completeError(error);
    }

    _cancelPending = () => fail(BatchRenameRegexCancelled());
    try {
      worker = html.Worker(url);
      messages = worker.onMessage.listen((event) {
        if (done.isCompleted) return;
        try {
          final values = jsonDecode(event.data as String) as List;
          done.complete([
            for (final value in values)
              BatchRenameRegexResult(name: value['name'], error: value['error'])
          ]);
        } catch (_) {
          fail(StateError('正则预览计算失败，请调整规则'));
        }
      });
      errors = worker.onError
          .listen((_) => fail(StateError('无法启动后台正则预览，请检查浏览器设置或改用普通替换')));
      timer =
          Timer(timeout, () => fail(TimeoutException('正则计算超时，请简化表达式或缩小参与范围')));
      worker.postMessage(jsonEncode({
        'names': names,
        'find': op.find,
        'replace': op.replace,
        'caseSensitive': op.caseSensitive,
        'firstOnly': op.firstOnly,
      }));
      return await done.future;
    } finally {
      timer?.cancel();
      worker?.terminate();
      await messages?.cancel();
      await errors?.cancel();
      html.Url.revokeObjectUrl(url);
      _cancelPending = null;
    }
  }

  void dispose() {
    _disposed = true;
    _cancelPending?.call();
  }
}

// ECMAScript Unicode matching and the same $0/$n/$$ replacement contract as
// replaceBatchRenameText. This source travels with the app, requiring no host URL.
const _workerSource = r'''
self.onmessage = (event) => {
  const input = JSON.parse(event.data);
  const results = input.names.map((name) => {
    try {
      const re = new RegExp(input.find,
        'u' + (input.caseSensitive ? '' : 'i') + (input.firstOnly ? '' : 'g'));
      const value = name.replace(re, (...args) => {
        const named = typeof args[args.length - 1] === 'object';
        const groups = args.slice(0, named ? -3 : -2);
        return input.replace.replace(/\$\$|\$(\d+)/g, (token, index) => {
          if (token === '$$') return '$';
          const number = Number(index);
          if (number >= groups.length) throw Error('捕获组 $' + index + ' 不存在');
          return groups[number] ?? '';
        });
      });
      if (value.length > 4096) throw Error('中间名称过长，请调整规则');
      return {name: value};
    } catch (error) { return {error: error.message}; }
  });
  self.postMessage(JSON.stringify(results));
};
''';
