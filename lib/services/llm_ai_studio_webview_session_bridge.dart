import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'llm_connector_service.dart';

class LlmAiStudioWebViewResponse {
  final int statusCode;
  final Map<String, List<String>> headers;
  final Uint8List? body;
  final Stream<List<int>>? stream;

  LlmAiStudioWebViewResponse({
    required this.statusCode,
    required Map<String, List<String>> headers,
    this.body,
    this.stream,
  }) : headers = Map.unmodifiable({
          for (final entry in headers.entries)
            entry.key.toLowerCase(): List<String>.unmodifiable(entry.value),
        });
}

/// Sealed to keep bridge sessions on the in-app WebView transport.
sealed class LlmAiStudioWebViewDriver {
  Future<LlmAiStudioWebViewResponse> execute(
    LlmPreparedNativeRequest request, {
    required String requestId,
    CancelToken? cancelToken,
  });

  void dispose();
}

/// Local request path bound to the currently loaded Stroom AI Studio WebView.
/// It never reads or copies cookies, tokens, or other browser storage.
class LlmAiStudioWebViewSessionBridge {
  LlmAiStudioWebViewSessionBridge._();

  static final instance = LlmAiStudioWebViewSessionBridge._();
  static const aiStudioHost = 'aistudio.google.com';
  static const apiHost = 'generativelanguage.googleapis.com';

  _AiStudioWebViewSession? _session;

  /// Attaches only a trusted HTTPS AI Studio page. A null result means the
  /// current browser page cannot own an AI Studio connector session.
  String? attach({
    required String pageUrl,
    required LlmAiStudioWebViewDriver driver,
    String? accountId,
  }) {
    if (!isAiStudioPage(pageUrl)) {
      driver.dispose();
      return null;
    }
    final token = _randomId();
    final previous = _session;
    _session = _AiStudioWebViewSession(
      token: token,
      driver: driver,
      accountId: accountId,
    );
    previous?.driver.dispose();
    return token;
  }

  static bool isAiStudioPage(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == aiStudioHost &&
        (!uri.hasPort || uri.port == 443) &&
        uri.userInfo.isEmpty;
  }

  /// Detaches the specified page registration. An older page cannot detach a
  /// newer WebView session after a navigation race.
  void detach(String? registration) {
    if (registration == null || _session?.token != registration) return;
    final previous = _session;
    _session = null;
    previous?.driver.dispose();
  }

  Future<LlmAiStudioWebViewResponse> execute(
    String accountId,
    LlmPreparedNativeRequest request, {
    CancelToken? cancelToken,
  }) async {
    _validateRequest(request);
    if (accountId.trim().isEmpty) {
      throw const LlmAiStudioWebViewBridgeException();
    }
    if (cancelToken?.isCancelled ?? false) {
      throw const LlmAiStudioWebViewRequestCancelled();
    }
    final session = _session;
    if (session == null) throw const LlmAiStudioWebViewBridgeException();
    if (session.accountId == null) {
      session.accountId = accountId;
    } else if (session.accountId != accountId) {
      throw const LlmAiStudioWebViewBridgeException();
    }
    return session.driver.execute(
      request,
      requestId: _randomId(),
      cancelToken: cancelToken,
    );
  }

  void resetForTest() {
    final previous = _session;
    _session = null;
    previous?.driver.dispose();
  }

  static void _validateRequest(LlmPreparedNativeRequest request) {
    final uri = request.uri;
    final pathMatch = RegExp(
      r'^/v1beta/models/[A-Za-z0-9._-]+:(generateContent|streamGenerateContent)$',
    ).firstMatch(uri.path);
    final requestIsStreaming = pathMatch?.group(1) == 'streamGenerateContent';
    final queryParameters = uri.queryParametersAll;
    final validQuery = queryParameters.isEmpty ||
        (queryParameters.length == 1 &&
            queryParameters['alt']?.length == 1 &&
            queryParameters['alt']!.single == 'sse');
    final headers = <String, String>{
      for (final entry in request.headers.entries)
        entry.key.toLowerCase(): entry.value,
    };
    final hasForbiddenHeader = headers.keys.any(
      (key) =>
          key == 'authorization' ||
          key == 'cookie' ||
          key == 'proxy-authorization' ||
          key == 'x-goog-api-key',
    );
    final headersAreAllowed = headers.keys.every(
      (key) => key == 'accept' || key == 'content-type',
    );
    final contentType = headers['content-type']?.toLowerCase();
    final accept = headers['accept']?.toLowerCase();
    final expectedAccept =
        requestIsStreaming ? 'text/event-stream' : 'application/json';
    try {
      jsonEncode(request.body);
    } catch (_) {
      throw const LlmAiStudioWebViewBridgeException();
    }
    if (uri.scheme.toLowerCase() != 'https' ||
        uri.host.toLowerCase() != apiHost ||
        (uri.hasPort && uri.port != 443) ||
        uri.userInfo.isNotEmpty ||
        request.method.toUpperCase() != 'POST' ||
        pathMatch == null ||
        requestIsStreaming != (uri.queryParameters['alt'] == 'sse') ||
        !validQuery ||
        hasForbiddenHeader ||
        !headersAreAllowed ||
        contentType != 'application/json' ||
        accept != expectedAccept) {
      throw const LlmAiStudioWebViewBridgeException();
    }
  }

  static String _randomId() {
    final random = Random.secure();
    return List<String>.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
  }
}

class _AiStudioWebViewSession {
  final String token;
  final LlmAiStudioWebViewDriver driver;
  String? accountId;

  _AiStudioWebViewSession({
    required this.token,
    required this.driver,
    required this.accountId,
  });
}

class LlmAiStudioWebViewBridgeException implements Exception {
  const LlmAiStudioWebViewBridgeException();

  @override
  String toString() => 'Google AI Studio is unavailable in the in-app browser.';
}

class LlmAiStudioWebViewNetworkException implements Exception {
  const LlmAiStudioWebViewNetworkException();
}

class LlmAiStudioWebViewRequestCancelled implements Exception {
  const LlmAiStudioWebViewRequestCancelled();

  @override
  String toString() => 'Google AI Studio request was cancelled.';
}

/// Executes native GenerateContent requests from the active AI Studio WebView
/// so the platform WebView supplies its own protected session cookies.
final class LlmAiStudioInAppWebViewDriver extends LlmAiStudioWebViewDriver {
  final InAppWebViewController controller;
  final Map<String, Future<void> Function()> _cancelRequests = {};
  bool _disposed = false;

  LlmAiStudioInAppWebViewDriver(this.controller);

  @override
  Future<LlmAiStudioWebViewResponse> execute(
    LlmPreparedNativeRequest request, {
    required String requestId,
    CancelToken? cancelToken,
  }) async {
    LlmAiStudioWebViewSessionBridge._validateRequest(request);
    if (_disposed || !await _isOnAiStudioPage()) {
      throw const LlmAiStudioWebViewBridgeException();
    }
    final response = Completer<LlmAiStudioWebViewResponse>();
    final streaming = request.uri.queryParameters['alt'] == 'sse';
    final stream = StreamController<List<int>>();
    var finished = false;
    var consumerCancelled = false;
    var handlerRegistered = false;
    final handlerName = 'StroomAiStudio$requestId';

    void cleanup() {
      if (finished) return;
      finished = true;
      _cancelRequests.remove(requestId);
      if (handlerRegistered) {
        try {
          controller.removeJavaScriptHandler(handlerName: handlerName);
        } catch (_) {
          // The WebView may already be closing.
        }
      }
      if (!stream.isClosed) unawaited(stream.close());
    }

    void fail(Object error) {
      if (finished) return;
      if (streaming && response.isCompleted) {
        if (!consumerCancelled) stream.addError(error);
        cleanup();
      } else if (!response.isCompleted) {
        response.completeError(error);
        cleanup();
      } else {
        cleanup();
      }
    }

    Future<void> abort(Object reason, {bool fromConsumer = false}) async {
      if (finished) return;
      consumerCancelled = fromConsumer;
      try {
        await controller.evaluateJavascript(
          source:
              'window.__stroomAiStudioAborters?.[${jsonEncode(requestId)}]?.abort();',
        );
      } catch (_) {
        // A navigation can tear down the page before its abort function runs.
      }
      if (!fromConsumer) fail(reason);
      if (fromConsumer) cleanup();
    }

    _cancelRequests[requestId] =
        () => abort(const LlmAiStudioWebViewBridgeException());
    stream.onCancel = () =>
        abort(const LlmAiStudioWebViewRequestCancelled(), fromConsumer: true);

    controller.addJavaScriptHandler(
      handlerName: handlerName,
      callback: (args) async {
        if (_disposed || finished || args.length < 2 || args[0] != requestId) {
          return false;
        }
        if (!await _isOnAiStudioPage()) return false;
        final type = args[1];
        if (type == 'network_error') {
          fail(const LlmAiStudioWebViewNetworkException());
          return true;
        }
        if (type == 'cancelled') {
          fail(const LlmAiStudioWebViewRequestCancelled());
          return true;
        }
        if (type == 'complete' && args.length >= 5) {
          final status = _statusCode(args[2]);
          if (status == null) {
            fail(const LlmAiStudioWebViewBridgeException());
            return true;
          }
          final contentType = args[3] is String ? args[3] as String : '';
          final body = status >= 200 && status < 300 && args[4] is String
              ? Uint8List.fromList(utf8.encode(args[4] as String))
              : null;
          if (!response.isCompleted) {
            response.complete(
              LlmAiStudioWebViewResponse(
                statusCode: status,
                headers: _responseHeaders(contentType),
                body: body,
              ),
            );
          }
          cleanup();
          return true;
        }
        if (type == 'start' && args.length >= 4) {
          final status = _statusCode(args[2]);
          if (status == null) {
            fail(const LlmAiStudioWebViewBridgeException());
            return true;
          }
          final contentType = args[3] is String ? args[3] as String : '';
          if (!response.isCompleted) {
            response.complete(
              LlmAiStudioWebViewResponse(
                statusCode: status,
                headers: _responseHeaders(contentType),
                stream: stream.stream,
              ),
            );
          }
          if (status < 200 || status >= 300) cleanup();
          return true;
        }
        if (type == 'chunk' && args.length >= 3) {
          final chunk = args[2];
          if (chunk is String && !stream.isClosed) {
            stream.add(utf8.encode(chunk));
          }
          return true;
        }
        if (type == 'end') {
          cleanup();
          return true;
        }
        return false;
      },
    );
    handlerRegistered = true;

    void onCancelled(DioException _) {
      unawaited(abort(const LlmAiStudioWebViewRequestCancelled()));
    }

    cancelToken?.whenCancel.then(onCancelled);

    final headers = <String, String>{};
    for (final entry in request.headers.entries) {
      final name = entry.key.toLowerCase();
      if (name == 'content-type' || name == 'accept') {
        headers[name] = entry.value;
      }
    }
    final functionBody = r'''
      const expectedOrigin = 'https://generativelanguage.googleapis.com';
      if (window.location.origin !== 'https://aistudio.google.com' ||
          !url.startsWith(expectedOrigin + '/')) {
        await window.flutter_inappwebview.callHandler(handlerName, requestId, 'network_error');
        return false;
      }
      const aborters = window.__stroomAiStudioAborters ||
        (window.__stroomAiStudioAborters = Object.create(null));
      const abortController = new AbortController();
      aborters[requestId] = abortController;
      let timedOut = false;
      let timeoutHandle;
      const resetTimeout = () => {
        clearTimeout(timeoutHandle);
        timeoutHandle = setTimeout(() => {
          timedOut = true;
          abortController.abort();
        }, timeoutMs);
      };
      resetTimeout();
      try {
        const response = await fetch(url, {
          method: 'POST',
          headers: headers,
          body: body,
          credentials: 'include',
          cache: 'no-store',
          redirect: 'manual',
          signal: abortController.signal
        });
        if (response.type === 'opaqueredirect' || response.status === 0) {
          await window.flutter_inappwebview.callHandler(handlerName, requestId, 'network_error');
          return false;
        }
        if (new URL(response.url).origin !== expectedOrigin) {
          await window.flutter_inappwebview.callHandler(handlerName, requestId, 'network_error');
          return false;
        }
        const contentType = response.headers.get('content-type') || '';
        if (!stream) {
          const text = response.ok ? await response.text() : '';
          await window.flutter_inappwebview.callHandler(
            handlerName, requestId, 'complete', response.status, contentType, text);
          return true;
        }
        await window.flutter_inappwebview.callHandler(
          handlerName, requestId, 'start', response.status, contentType);
        if (!response.ok) return true;
        if (!response.body) {
          await window.flutter_inappwebview.callHandler(handlerName, requestId, 'end');
          return true;
        }
        const reader = response.body.getReader();
        const decoder = new TextDecoder('utf-8');
        while (true) {
          resetTimeout();
          const result = await reader.read();
          if (result.done) break;
          const text = decoder.decode(result.value, {stream: true});
          if (text) await window.flutter_inappwebview.callHandler(
            handlerName, requestId, 'chunk', text);
        }
        const tail = decoder.decode();
        if (tail) await window.flutter_inappwebview.callHandler(
          handlerName, requestId, 'chunk', tail);
        await window.flutter_inappwebview.callHandler(handlerName, requestId, 'end');
        return true;
      } catch (_) {
        const type = timedOut ? 'network_error' :
          (abortController.signal.aborted ? 'cancelled' : 'network_error');
        try {
          await window.flutter_inappwebview.callHandler(handlerName, requestId, type);
        } catch (_) {}
        return false;
      } finally {
        clearTimeout(timeoutHandle);
        delete aborters[requestId];
      }
    ''';

    final run = controller.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {
        'url': request.uri.toString(),
        'headers': headers,
        'body': jsonEncode(request.body),
        'requestId': requestId,
        'handlerName': handlerName,
        'stream': streaming,
        'timeoutMs': 60000,
      },
    );
    unawaited(
      run.then((result) {
        if (result?.error != null || !response.isCompleted) {
          fail(const LlmAiStudioWebViewBridgeException());
        }
      }).catchError((Object _) {
        fail(const LlmAiStudioWebViewBridgeException());
      }),
    );
    return response.future;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final cancel in _cancelRequests.values.toList()) {
      unawaited(cancel());
    }
  }

  Future<bool> _isOnAiStudioPage() async {
    try {
      final url = await controller.getUrl();
      return LlmAiStudioWebViewSessionBridge.isAiStudioPage(
        url?.toString() ?? '',
      );
    } catch (_) {
      return false;
    }
  }

  static int? _statusCode(Object? value) => value is num ? value.toInt() : null;

  static Map<String, List<String>> _responseHeaders(String contentType) =>
      contentType.isEmpty
          ? const {}
          : {
              'content-type': [contentType],
            };
}
