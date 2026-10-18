import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/llm_account.dart';
import 'llm_ai_studio_webview_session_bridge.dart';
import 'llm_connector_service.dart';

typedef LlmAiStudioRelayExecutor = Future<LlmConnectorResponse> Function(
  LlmAccount account,
  LlmPreparedNativeRequest request,
);

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
  final LlmAiStudioRelayExecutor? _aiStudioRelayExecutor;
  final LlmAiStudioWebViewSessionBridge _aiStudioWebViewSessionBridge;

  LlmConnectorHttpClient({
    required this.accountService,
    Dio? dio,
    LlmNativeRequestBuilder? requestBuilder,
    LlmAiStudioRelayExecutor? aiStudioRelayExecutor,
    LlmAiStudioWebViewSessionBridge? aiStudioWebViewSessionBridge,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 60),
              ),
            ),
        _requestBuilder = requestBuilder ?? LlmNativeRequestBuilder(),
        _aiStudioRelayExecutor = aiStudioRelayExecutor,
        _aiStudioWebViewSessionBridge = aiStudioWebViewSessionBridge ??
            LlmAiStudioWebViewSessionBridge.instance;

  Future<LlmConnectorResponse> request({
    required LlmAccount account,
    required String modelId,
    required Object? body,
    bool stream = false,
    String? nativeFormat,
    CancelToken? cancelToken,
  }) async {
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
      final relay = _aiStudioRelayExecutor;
      final prepared = _requestBuilder.build(
        account: storedAccount,
        credential: null,
        modelId: modelId,
        body: body,
        stream: stream,
        nativeFormat: nativeFormat,
      );
      try {
        if (relay != null) return await relay(storedAccount, prepared);
        final response = await _aiStudioWebViewSessionBridge.execute(
          storedAccount.id,
          prepared,
          cancelToken: cancelToken,
        );
        if (response.statusCode == 401) {
          throw const LlmConnectorAuthenticationRequired();
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw LlmConnectorHttpException(statusCode: response.statusCode);
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
      } on LlmAiStudioWebViewSessionExpired {
        throw const LlmConnectorAuthenticationRequired();
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
            responseType: stream ? ResponseType.stream : ResponseType.bytes,
            validateStatus: (status) => status != null,
          ),
          cancelToken: cancelToken,
        );
        final status = response.statusCode ?? 0;
        if (status == 401 && !didRetry && _canRefresh(storedAccount)) {
          if (stream && response.data is ResponseBody) {
            await (response.data as ResponseBody).stream.drain<void>();
          }
          didRetry = true;
          try {
            if (await accountService.refreshCredential(storedAccount)) continue;
          } catch (_) {
            throw const LlmConnectorHttpException(statusCode: 401);
          }
        }
        if (status < 200 || status >= 300) {
          if (stream && response.data is ResponseBody) {
            await (response.data as ResponseBody).stream.drain<void>();
          }
          throw LlmConnectorHttpException(statusCode: status);
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
        final decoded = _decodeResponseBody(response.data);
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
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) {
          throw const LlmConnectorRequestCancelled();
        }
        throw const LlmConnectorHttpException();
      } catch (_) {
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
            parseLlmConnectorObservation(connectorType, decoded),
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
      final bytes =
          data is Uint8List ? data : Uint8List.fromList(data as List<int>);
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
}

/// Safe failure that never forwards the upstream error body or transport
/// exception, either of which may include private prompt or credential data.
class LlmConnectorHttpException implements Exception {
  final int? statusCode;

  const LlmConnectorHttpException({this.statusCode});

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
