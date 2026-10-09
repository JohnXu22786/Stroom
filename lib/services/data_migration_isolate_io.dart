import 'dart:async';
import 'dart:isolate';

Future<T> runInIsolate<T>(FutureOr<T> Function() computation) =>
    Isolate.run(computation);
