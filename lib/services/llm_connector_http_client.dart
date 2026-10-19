import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/llm_account.dart';
import 'llm_ai_studio_webview_session_bridge.dart';
import 'llm_connector_service.dart';

/// A connector response contains the upstream payload and request-level usage.
/// Account quota is populated only when a connector supplies a comparable,
/// explicitly supported observation.
class LlmConnectorResponse {
  final int statusCode;
  final Object? body;
  final LlmConnectorObservation observation;
  final Future<LlmConnectorObservation>? completedObservation;

  const LlmConnectorResponse({
    required this.statusCode,
    required this.body,
    required this.observation,
    this.completedObservation,
  });
}

/// Sends connector-native requests. Each connector retains its own protocol
/// path, authentication headers, and request body; no protocol conversion is
/// performed here.
class LlmConnectorHttpClient {
  final LlmAccountConnectorService accountService;
  final Dio _dio;
  final LlmNativeRequestBuilder _requestBuilder;
  final LlmAiStudioWebViewSessionBridge _aiStudioWebViewSessionBridge;

  LlmConnectorHttpClient({
    required this.accountService,
    Dio? dio,
    LlmNativeRequestBuilder? requestBuilder,
    LlmAiStudioWebViewSessionBridge? aiStudioWebViewSessionBridge,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 60),
             ),
           ),
       _requestBuilder = requestBuilder ?? LlmNativeRequestBuilder(),
       _aiStudioWebViewSessionBridge =
           aiStudioWebViewSessionBridge ??
           LlmAiStudioWebViewSessionBridge.instance;

  Future<LlmConnectorResponse> request({
    required LlmAccount account,
    required String modelId,
    required Object? body,
    bool stream = false,
    String? nativeFormat,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Future<void> Function()? onRequestSent,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    var requestSentMarkerStarted = false;
    Future<void>? requestSentMarker;
    var requestSentMarkerFailed = false;
    void markRequestSent() {
      if (requestSentMarkerStarted) return;
      requestSentMarkerStarted = true;
      requestSentMarker =
          Future<void>.sync(() async {
            await onRequestSent?.call();
          }).then<void>(
            (_) {},
            onError: (Object _, StackTrace __) {
              requestSentMarkerFailed = true;
            },
          );
    }

    Future<void> waitForRequestSentMarker() async {
      final marker = requestSentMarker;
      if (marker != null) await marker;
      if (requestSentMarkerFailed) {
        throw const LlmConnectorHttpException();
      }
    }

    void reportSendProgress(int sent, int total) {
      if (sent > 0) markRequestSent();
      onSendProgress?.call(sent, total);
    }

    if (modelId.trim().isEmpty) {
      throw const LlmConnectorHttpException();
    }
    var storedAccount = await accountService.getAccount(account.id);
    if (storedAccount == null ||
        LlmConnectorRegistry.canonicalId(storedAccount.connectorType) !=
            LlmConnectorRegistry.canonicalId(account.connectorType)) {
      throw const LlmConnectorHttpException();
    }
    if (storedAccount.connectorType == 'antigravity') {
      try {
        storedAccount = await accountService.ensureAntigravityProjectId(
          storedAccount,
        );
      } catch (_) {
        throw const LlmConnectorHttpException();
      }
    }
    if (storedAccount.connectorType == 'aistudio') {
      final requestCancelToken = _requestCancelToken(cancelToken);
      final prepared = _requestBuilder.build(
        account: storedAccount,
        credential: null,
        modelId: modelId,
        body: body,
        stream: stream,
        nativeFormat: nativeFormat,
      );
      try {
        final response = await _aiStudioWebViewSessionBridge.execute(
          storedAccount.id,
          prepared,
          cancelToken: requestCancelToken,
        );
        markRequestSent();
        await waitForRequestSentMarker();
        if (response.statusCode == 401) {
          throw const LlmConnectorAuthenticationRequired();
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw await _failureFromResponse(
            response.statusCode,
            response.headers,
            stream ? response.stream : response.body,
            onErrorBodyLimitReached: () {
              requestCancelToken.cancel('Error response body limit reached');
            },
          );
        }
        final headerObservation = parseLlmConnectorHeaderObservation(
          storedAccount.connectorType,
          response.headers,
        );
        if (stream) {
          final source = response.stream ?? Stream<List<int>>.empty();
          final completed = Completer<LlmConnectorObservation>();
          final chunks = _observeResponseStream(
            storedAccount.connectorType,
            source,
            headerObservation,
            completed,
          );
          return LlmConnectorResponse(
            statusCode: response.statusCode,
            body: chunks,
            observation: headerObservation,
            completedObservation: completed.future,
          );
        }
        final decoded = _decodeResponseBody(response.body);
        final bodyObservation = decoded is Uint8List || decoded is List<int>
            ? mergeLlmConnectorObservations(
                parseLlmConnectorObservation(
                  storedAccount.connectorType,
                  decoded,
                ),
                parseLlmConnectorSseObservation(
                  storedAccount.connectorType,
                  decoded as List<int>,
                ),
              )
            : parseLlmConnectorObservation(
                storedAccount.connectorType,
                decoded,
              );
        return LlmConnectorResponse(
          statusCode: response.statusCode,
          body: decoded,
          observation: mergeLlmConnectorObservations(
            headerObservation,
            bodyObservation,
          ),
        );
      } on LlmConnectorHttpException {
        rethrow;
      } on LlmConnectorAuthenticationRequired {
        rethrow;
      } on LlmConnectorRequestCancelled {
        rethrow;
      } on LlmAiStudioWebViewRequestCancelled {
        throw const LlmConnectorRequestCancelled();
      } on LlmAiStudioWebViewNetworkException {
        throw const LlmConnectorHttpException();
      } on LlmAiStudioWebViewBridgeException {
        throw const LlmConnectorTransportUnavailable();
      } catch (_) {
        throw const LlmConnectorHttpException();
      }
    }

    var didPrepareCredential = false;
    var didRetry = false;
    while (true) {
      final requestCancelToken = _requestCancelToken(cancelToken);
      final credential = await accountService.readCredential(storedAccount.id);
      if (!didPrepareCredential &&
          _needsInitialCredentialRefresh(storedAccount, credential)) {
        didPrepareCredential = true;
        try {
          if (await accountService.refreshCredential(storedAccount)) continue;
        } catch (_) {
          throw const LlmConnectorHttpException();
        }
      }
      late final LlmPreparedNativeRequest prepared;
      try {
        prepared = _requestBuilder.build(
          account: storedAccount,
          credential: credential,
          modelId: modelId,
          body: body,
          stream: stream,
          nativeFormat: nativeFormat,
        );
      } catch (_) {
        throw const LlmConnectorHttpException();
      }
      try {
        final response = await _dio.requestUri<Object?>(
          prepared.uri,
          data: prepared.body,
          options: Options(
            method: prepared.method,
            headers: prepared.headers,
            // Keep the response streamed until its status is known so an
            // oversized error body can be cancelled before Dio buffers it.
            responseType: ResponseType.stream,
            validateStatus: (status) => status != null,
            connectTimeout: connectTimeout,
            sendTimeout: sendTimeout,
            receiveTimeout: receiveTimeout,
          ),
          cancelToken: requestCancelToken,
          onSendProgress: reportSendProgress,
        );
        // A response confirms dispatch, including when Dio did not report an
        // upload callback (for example, an empty request body).
        markRequestSent();
        await waitForRequestSentMarker();
        final status = response.statusCode ?? 0;
        if (status < 200 || status >= 300) {
          final failure = await _failureFromResponse(
            status,
            response.headers.map,
            response.data,
            onErrorBodyLimitReached: () {
              requestCancelToken.cancel('Error response body limit reached');
            },
          );
          if (status == 401 && !didRetry && _canRefresh(storedAccount)) {
            didRetry = true;
            try {
              if (await accountService.refreshCredential(storedAccount)) {
                continue;
              }
            } catch (_) {
              // Preserve the authentication response's safe classification
              // data when credential refresh itself cannot complete.
            }
          }
          throw failure;
        }
        final headerObservation = parseLlmConnectorHeaderObservation(
          storedAccount.connectorType,
          response.headers.map,
        );
        if (stream) {
          final responseBody = response.data;
          final source = responseBody is ResponseBody
              ? responseBody.stream
              : responseBody as Stream<List<int>>;
          final completed = Completer<LlmConnectorObservation>();
          final chunks = _observeResponseStream(
            storedAccount.connectorType,
            source,
            headerObservation,
            completed,
          );
          return LlmConnectorResponse(
            statusCode: status,
            body: chunks,
            observation: headerObservation,
            completedObservation: completed.future,
          );
        }
        final responseData = response.data;
        final decoded = _decodeResponseBody(
          responseData is ResponseBody
              ? await _readResponseStream(responseData.stream)
              : responseData is Stream<List<int>>
              ? await _readResponseStream(responseData)
              : responseData,
        );
        final bodyObservation = decoded is Uint8List || decoded is List<int>
            ? mergeLlmConnectorObservations(
                parseLlmConnectorObservation(
                  storedAccount.connectorType,
                  decoded,
                ),
                parseLlmConnectorSseObservation(
                  storedAccount.connectorType,
                  decoded as List<int>,
                ),
              )
            : parseLlmConnectorObservation(
                storedAccount.connectorType,
                decoded,
              );
        return LlmConnectorResponse(
          statusCode: status,
          body: decoded,
          observation: mergeLlmConnectorObservations(
            headerObservation,
            bodyObservation,
          ),
        );
      } on LlmConnectorHttpException {
        rethrow;
      } on LlmConnectorRequestCancelled {
        rethrow;
      } on DioException catch (error) {
        if (error.response != null) markRequestSent();
        await waitForRequestSentMarker();
        if (CancelToken.isCancel(error)) {
          throw const LlmConnectorRequestCancelled();
        }
        if (_isConnectionFailure(error)) {
          throw const LlmConnectorHttpException(code: 'connection_error');
        }
        throw const LlmConnectorHttpException();
      } catch (_) {
        await waitForRequestSentMarker();
        throw const LlmConnectorHttpException();
      }
    }
  }

  static bool _canRefresh(LlmAccount account) {
    final connector = LlmConnectorRegistry.find(account.connectorType);
    return connector?.canRefreshCredentials == true &&
        (account.authType == 'oauth' ||
            (account.connectorType == 'vertex' &&
                account.authType == 'service_account'));
  }

  static bool _isConnectionFailure(DioException error) =>
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError;

  static CancelToken _requestCancelToken(CancelToken? parent) {
    final requestToken = CancelToken();
    if (parent == null) return requestToken;
    if (parent.isCancelled) {
      requestToken.cancel(parent.cancelError);
      return requestToken;
    }
    final requestTokenReference = WeakReference(requestToken);
    parent.whenCancel.then((error) {
      requestTokenReference.target?.cancel(error);
    });
    return requestToken;
  }

  static Stream<List<int>> _observeResponseStream(
    String connectorType,
    Stream<List<int>> source,
    LlmConnectorObservation initialObservation,
    Completer<LlmConnectorObservation> completed,
  ) async* {
    var observation = initialObservation;
    var partialLine = '';
    final dataLines = <String>[];
    var dataLinesLength = 0;
    var discardingOversizedFrame = false;
    const maxSseFrameCharacters = 1048576;
    final usageAccumulator = LlmConnectorSseObservationAccumulator(
      connectorType,
    );

    void discardCurrentFrame() {
      partialLine = '';
      dataLines.clear();
      dataLinesLength = 0;
      discardingOversizedFrame = true;
    }

    void addDataLine(String data) {
      if (discardingOversizedFrame) return;
      // Count one delimiter per data line as well, bounding empty-line floods.
      if (dataLinesLength + data.length + 1 > maxSseFrameCharacters) {
        discardCurrentFrame();
        return;
      }
      dataLines.add(data);
      dataLinesLength += data.length + 1;
    }

    void observeFrame() {
      if (discardingOversizedFrame) {
        dataLines.clear();
        dataLinesLength = 0;
        discardingOversizedFrame = false;
        return;
      }
      if (dataLines.isEmpty) return;
      final data = dataLines.join('\n').trim();
      dataLines.clear();
      dataLinesLength = 0;
      if (data.isEmpty || data == '[DONE]') return;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          observation = mergeLlmConnectorObservations(
            observation,
            usageAccumulator.observe(decoded),
          );
        }
      } catch (_) {
        // Non-JSON event data is not an observation.
      }
    }

    void processLine(String line) {
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.isEmpty) {
        observeFrame();
      } else if (line.startsWith('data:')) {
        var data = line.substring(5);
        if (data.startsWith(' ')) data = data.substring(1);
        addDataLine(data);
      }
    }

    void acceptText(String text) {
      var start = 0;
      while (start < text.length) {
        final newline = text.indexOf('\n', start);
        if (newline < 0) {
          final remainingLength = text.length - start;
          if (partialLine.length + remainingLength > maxSseFrameCharacters) {
            discardCurrentFrame();
          } else {
            partialLine += text.substring(start);
          }
          return;
        }

        final lineLength = newline - start;
        if (partialLine.length + lineLength > maxSseFrameCharacters) {
          discardCurrentFrame();
        } else {
          final line = '$partialLine${text.substring(start, newline)}';
          partialLine = '';
          processLine(line);
        }
        start = newline + 1;
      }
    }

    try {
      await for (final chunk in source) {
        acceptText(utf8.decode(chunk, allowMalformed: true));
        yield chunk;
      }
      if (partialLine.isNotEmpty) {
        processLine(partialLine);
        partialLine = '';
      }
      observeFrame();
    } on LlmAiStudioWebViewRequestCancelled {
      throw const LlmConnectorRequestCancelled();
    } on LlmConnectorRequestCancelled {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const LlmConnectorRequestCancelled();
      }
      if (_isConnectionFailure(error)) {
        throw const LlmConnectorHttpException(code: 'connection_error');
      }
      throw const LlmConnectorHttpException();
    } catch (_) {
      throw const LlmConnectorHttpException();
    } finally {
      if (!completed.isCompleted) completed.complete(observation);
    }
  }

  static bool _needsInitialCredentialRefresh(
    LlmAccount account,
    String? credential,
  ) {
    if (!_canRefresh(account) || credential == null) return false;
    Map? bundle;
    try {
      final decoded = jsonDecode(credential);
      if (decoded is Map) bundle = decoded;
    } catch (_) {
      return false;
    }
    if (bundle == null) return false;
    if (account.connectorType == 'meta') {
      final dcaToken = bundle['dca_token'] ?? bundle['dcaToken'];
      final accessToken = bundle['access_token'] ?? bundle['accessToken'];
      final apiKey = bundle['api_key'] ?? bundle['apiKey'];
      return (dcaToken is String && dcaToken.trim().isNotEmpty ||
              accessToken is String && accessToken.trim().startsWith('dca:')) &&
          (apiKey is! String || apiKey.trim().isEmpty);
    }
    if (account.connectorType == 'vertex' &&
        account.authType == 'service_account') {
      final token = bundle['access_token'] ?? bundle['accessToken'];
      if (token is! String || token.trim().isEmpty) return true;
    }
    if (account.authType == 'oauth' && account.connectorType != 'meta') {
      final token = bundle['access_token'] ?? bundle['accessToken'];
      if (token is! String || token.trim().isEmpty) return true;
    }
    final expiryValue = bundle['expires_at'] ?? bundle['expired'];
    DateTime? expiry;
    if (expiryValue is String) expiry = DateTime.tryParse(expiryValue);
    if (expiryValue is num) {
      expiry = DateTime.fromMillisecondsSinceEpoch(
        expiryValue.toInt() * 1000,
        isUtc: true,
      );
    }
    return expiry != null &&
        !expiry.isAfter(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        );
  }

  static Object? _decodeResponseBody(Object? data) {
    if (data == null) return null;
    if (data is Map) return data;
    if (data is Uint8List || data is List<int>) {
      final bytes = data is Uint8List
          ? data
          : Uint8List.fromList(data as List<int>);
      try {
        return jsonDecode(utf8.decode(bytes));
      } catch (_) {
        return bytes;
      }
    }
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    if (data is List) return data;
    return data;
  }

  static Future<Uint8List> _readResponseStream(Stream<List<int>> stream) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static const _classificationHeaderNames = {
    'retry-after',
    'x-ratelimit-reset',
    'x-rate-limit-reset',
    'x-quota-reset',
    'x-reset-at',
  };

  static Future<LlmConnectorHttpException> _failureFromResponse(
    int statusCode,
    Map<String, List<String>> headers,
    Object? body, {
    void Function()? onErrorBodyLimitReached,
  }) async {
    final safeHeaders = <String, String>{};
    for (final entry in headers.entries) {
      final name = entry.key.toLowerCase();
      if (!_classificationHeaderNames.contains(name) || entry.value.isEmpty) {
        continue;
      }
      final value = entry.value.first.trim();
      if (value.isEmpty ||
          value.length > 256 ||
          value.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
        continue;
      }
      safeHeaders[name] = value;
    }

    Object? decodedBody;
    try {
      decodedBody = await _readFailureBody(
        body,
        onLimitReached: onErrorBodyLimitReached,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const LlmConnectorRequestCancelled();
      }
      // Status and allowlisted headers still classify the request if the
      // upstream error body is malformed or its stream fails while draining.
    } catch (_) {
      // Status and allowlisted headers still classify the request if the
      // upstream error body is malformed or its stream fails while draining.
    }

    return LlmConnectorHttpException(
      statusCode: statusCode,
      code: _errorCode(decodedBody),
      headers: Map.unmodifiable(safeHeaders),
    );
  }

  static Future<Object?> _readFailureBody(
    Object? body, {
    void Function()? onLimitReached,
  }) async {
    if (body is ResponseBody) {
      return _decodeResponseBody(
        await _readBoundedFailureStream(
          body.stream,
          onLimitReached: onLimitReached,
        ),
      );
    }
    if (body is Stream<List<int>>) {
      return _decodeResponseBody(
        await _readBoundedFailureStream(body, onLimitReached: onLimitReached),
      );
    }
    return _decodeResponseBody(body);
  }

  static Future<Uint8List> _readBoundedFailureStream(
    Stream<List<int>> stream, {
    void Function()? onLimitReached,
  }) async {
    const maxErrorBodyBytes = 32768;
    final bytes = BytesBuilder(copy: false);
    var retained = 0;
    final iterator = StreamIterator<List<int>>(stream);
    try {
      while (await iterator.moveNext()) {
        final chunk = iterator.current;
        final available = maxErrorBodyBytes - retained;
        if (available <= 0) break;
        final take = chunk.length < available ? chunk.length : available;
        bytes.add(take == chunk.length ? chunk : chunk.sublist(0, take));
        retained += take;
        if (retained >= maxErrorBodyBytes) {
          onLimitReached?.call();
          break;
        }
      }
    } finally {
      // Wait for cancellation to reach the adapter before releasing the
      // routed request and its concurrency reservation.
      await iterator.cancel();
    }
    return bytes.takeBytes();
  }

  static String? _errorCode(Object? body) {
    if (body is! Map) return null;
    final error = body['error'];
    final candidates = [
      if (error is Map) error['code'],
      if (error is Map) error['type'],
      body['code'],
      body['type'],
    ];
    final codePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$');
    for (final candidate in candidates) {
      if (candidate is! String) continue;
      final code = candidate.trim();
      if (codePattern.hasMatch(code)) return code;
    }
    return null;
  }
}

/// Safe failure that never forwards the upstream error body or transport
/// exception, either of which may include private prompt or credential data.
class LlmConnectorHttpException implements Exception {
  final int? statusCode;

  /// Stable classification hint; raw transport messages are never exposed.
  final String? code;

  /// Allowlisted classification headers; arbitrary upstream headers are never
  /// forwarded into routing state.
  final Map<String, String> headers;

  const LlmConnectorHttpException({
    this.statusCode,
    this.code,
    this.headers = const {},
  });

  @override
  String toString() => statusCode == null
      ? 'LLM connector request could not be completed.'
      : 'LLM connector request failed with status $statusCode.';
}

/// AI Studio's pinned executor is a WebSocket relay. It requires the local
/// relay provider to be connected before it can execute requests.
class LlmConnectorTransportUnavailable implements Exception {
  const LlmConnectorTransportUnavailable();

  @override
  String toString() =>
      'Google AI Studio needs a signed-in Stroom in-app browser session.';
}

class LlmConnectorAuthenticationRequired implements Exception {
  const LlmConnectorAuthenticationRequired();

  @override
  String toString() =>
      'Google AI Studio session expired or needs sign-in in the in-app browser.';
}

class LlmConnectorRequestCancelled implements Exception {
  const LlmConnectorRequestCancelled();

  @override
  String toString() => 'LLM connector request was cancelled.';
}
