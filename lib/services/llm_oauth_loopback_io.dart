import 'dart:async';
import 'dart:io';

import 'llm_oauth_loopback.dart';

Future<LlmOAuthLoopback> bindLlmOAuthLoopback(
  String path, {
  required String host,
  required int port,
}) async {
  if (host != '127.0.0.1' && host != 'localhost') {
    throw ArgumentError.value(host, 'host', 'Must be a loopback hostname.');
  }
  final servers = <HttpServer>[];
  try {
    if (host == 'localhost') {
      final ipv6Server = await HttpServer.bind(
        InternetAddress.loopbackIPv6,
        port,
        v6Only: true,
      );
      servers.add(ipv6Server);
      final ipv4Port = port == 0 ? ipv6Server.port : port;
      servers.add(
        await HttpServer.bind(InternetAddress.loopbackIPv4, ipv4Port),
      );
    } else {
      servers.add(await HttpServer.bind(InternetAddress.loopbackIPv4, port));
    }
    return _IoLlmOAuthLoopback(servers, path, host);
  } catch (_) {
    for (final server in servers) {
      await server.close(force: true);
    }
    rethrow;
  }
}

class _IoLlmOAuthLoopback implements LlmOAuthLoopback {
  final List<HttpServer> _servers;
  final String _path;
  final String _host;
  late final List<StreamSubscription<HttpRequest>> _subscriptions;
  Completer<Uri>? _nextUri;
  Uri? _pendingUri;
  HttpResponse? _pendingResponse;
  var _closed = false;

  _IoLlmOAuthLoopback(this._servers, this._path, this._host) {
    _subscriptions = [
      for (final server in _servers) server.listen(_onRequest),
    ];
  }

  @override
  Uri get redirectUri =>
      Uri(scheme: 'http', host: _host, port: _servers.first.port, path: _path);

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
      host: _host,
      port: _servers.first.port,
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
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    await Future.wait(_servers.map((server) => server.close(force: true)));
  }
}
