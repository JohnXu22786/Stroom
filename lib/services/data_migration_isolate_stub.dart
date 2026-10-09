import 'dart:async';

Future<T> runInIsolate<T>(FutureOr<T> Function() computation) async =>
    computation();
