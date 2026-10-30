import 'dart:async';
import 'dart:io';

import 'llm_oauth_loopback.dart';

Future<LlmOAuthLoopback> bindLlmOAuthLoopback(String path) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  return _IoLlmOAuthLoopback(server, path);
}

class _IoLlmOAuthLoopback implements LlmOAuthLoopback {
  final HttpServer _server;
  final String _path;
  late final StreamSubscription<HttpRequest> _subscription;
  Completer<Uri>? _nextUri;
  Uri? _pendingUri;
  HttpResponse? _pendingResponse;
  var _closed = false;

  _IoLlmOAuthLoopback(this._server, this._path) {
    _subscription = _server.listen(_onRequest);
  }

  @override
  Uri get redirectUri =>
      Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: _path);

  void _onRequest(HttpRequest request) {
    if (request.method != 'GET') {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..close();
      return;
    }
    if (request.uri.path != _path) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    final waiter = _nextUri;
    if (_pendingResponse != null || (waiter?.isCompleted ?? false)) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    _pendingResponse = request.response;
    final callback = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: _server.port,
      path: request.uri.path,
      query: request.uri.hasQuery ? request.uri.query : null,
      fragment: request.uri.hasFragment ? request.uri.fragment : null,
    );
    if (waiter == null) {
      _pendingUri = callback;
    } else {
      waiter.complete(callback);
    }
  }

  @override
  Future<Uri> nextCallback() {
    if (_closed || _nextUri != null) {
      return Future.error(
        StateError('OAuth callback listener is unavailable.'),
      );
    }
    final waiter = Completer<Uri>();
    _nextUri = waiter;
    final pendingUri = _pendingUri;
    if (pendingUri != null) {
      _pendingUri = null;
      waiter.complete(pendingUri);
    }
    return waiter.future;
  }

  @override
  Future<void> respond({required bool accepted}) async {
    final response = _pendingResponse;
    if (response == null) return;
    _pendingResponse = null;
    _pendingUri = null;
    _nextUri = null;
    response
      ..statusCode = accepted ? HttpStatus.ok : HttpStatus.badRequest
      ..headers.contentType = ContentType.html
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..headers.set('Referrer-Policy', 'no-referrer');
    response.write(
      accepted
          ? '<!doctype html><title>Stroom authorization</title><p>You can return to Stroom.</p>'
          : '<!doctype html><title>Authorization failed</title><p>Stroom could not complete authorization. Return to the app and try again.</p>',
    );
    await response.close();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final waiter = _nextUri;
    _nextUri = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(StateError('OAuth callback listener is closed.'));
    }
    await _subscription.cancel();
    await _server.close(force: true);
  }
}
