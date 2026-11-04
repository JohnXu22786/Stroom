import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/llm_account.dart';
import 'aws_bedrock_converse.dart';
import 'aws_bedrock_event_stream.dart';
import 'aws_credential_chain.dart';
import 'aws_sigv4.dart';
import 'llm_connector_service.dart';
import 'llm_oauth_flow.dart';
import 'devin_connect_rpc.dart';
import 'cursor_connect_rpc.dart';
import 'cursor_http2_transport.dart';

/// A connector response contains the upstream payload and request-level usage.
/// Account quota is populated only when a connector supplies a comparable,
/// explicitly supported observation.
class LlmConnectorResponse {
  final int statusCode;
  final Map<String, List<String>> headers;
  final Object? body;
  final LlmConnectorObservation observation;
  final Future<LlmConnectorObservation>? completedObservation;

  const LlmConnectorResponse({
    required this.statusCode,
    required this.body,
    required this.observation,
    this.headers = const {},
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

  LlmConnectorHttpClient({
    required this.accountService,
    Dio? dio,
    LlmNativeRequestBuilder? requestBuilder,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 60),
              ),
            ),
        _requestBuilder = requestBuilder ?? LlmNativeRequestBuilder();

  Future<LlmConnectorResponse> request({
    required LlmAccount account,
    required String modelId,
    required Object? body,
    String? conversationId,
    bool stream = false,
    String? nativeFormat,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Future<void> Function()? onRequestSent,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const LlmConnectorRequestCancelled();
    }
    var requestSentMarkerStarted = false;
    Future<void>? requestSentMarker;
    var requestSentMarkerFailed = false;
    void markRequestSent() {
      if (requestSentMarkerStarted) return;
      requestSentMarkerStarted = true;
      requestSentMarker = Future<void>.sync(() async {
        await onRequestSent?.call();
      }).then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {
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
    if (storedAccount.connectorType == 'aistudio' &&
        storedAccount.authType == 'relay') {
      throw const LlmConnectorAuthenticationRequired();
    }
    if (storedAccount.authType == 'oauth' &&
        !LlmOAuthProviderPolicy.forProvider(
          storedAccount.connectorType,
        ).supported) {
      throw const LlmConnectorAuthenticationRequired();
    }
    if (storedAccount.connectorType == 'qoder' &&
        storedAccount.authType == 'oauth' &&
        storedAccount.status == LlmAccountStatus.needsAttention) {
      throw const LlmConnectorAuthenticationRequired();
    }
    if (storedAccount.connectorType == 'antigravity') {
      try {
        storedAccount = await accountService.ensureAntigravityProjectId(
          storedAccount,
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) {
          throw const LlmConnectorRequestCancelled();
        }
        throw const LlmConnectorHttpException();
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
          if (await accountService.refreshCredential(
            storedAccount,
            cancelToken: cancelToken,
          )) {
            continue;
          }
        } on DioException catch (error) {
          if (CancelToken.isCancel(error)) {
            throw const LlmConnectorRequestCancelled();
          }
          throw const LlmConnectorHttpException();
        } catch (_) {
          throw const LlmConnectorHttpException();
        }
      }
      late final LlmPreparedNativeRequest prepared;
      try {
        AwsSigV4Credentials? awsCredentials;
        if (storedAccount.connectorType == 'bedrock') {
          try {
            if (storedAccount.authType == 'aws_credentials') {
              final decoded = jsonDecode(credential ?? '');
              if (decoded is! Map) {
                throw const LlmConnectorHttpException();
              }
              awsCredentials = AwsSigV4Credentials.fromJson(
                Map<String, dynamic>.from(decoded),
              );
            } else {
              awsCredentials = await AwsCredentialChain.resolve();
            }
          } catch (_) {
            throw const LlmConnectorHttpException(
              code: 'aws_credentials_unavailable',
            );
          }
          if (awsCredentials == null) {
            throw const LlmConnectorHttpException(
              code: 'aws_credentials_unavailable',
            );
          }
        }
        prepared = _requestBuilder.build(
          account: storedAccount,
          credential: credential,
          awsCredentials: awsCredentials,
          modelId: modelId,
          body: body,
          conversationId: conversationId,
          // Devin's source contract exposes unary Connect-RPC. The app's
          // chat stream adapter still expects SSE, which is synthesized from
          // the completed unary response below.
          stream: storedAccount.connectorType == 'devin' ? false : stream,
          nativeFormat: nativeFormat,
        );
      } on LlmConnectorHttpException {
        rethrow;
      } on CursorConnectRpcException catch (error) {
        throw LlmConnectorHttpException(
          code: error.code == 'unsupported_images'
              ? 'cursor_inline_images_only'
              : error.code.startsWith('unsupported_')
                  ? 'unsupported_capability'
                  : 'invalid_request',
        );
      } catch (_) {
        throw const LlmConnectorHttpException();
      }
      if (storedAccount.connectorType == 'cursor') {
        try {
          final accessToken = LlmNativeRequestBuilder.credentialBundleString(
            credential,
            const ['access_token', 'accessToken'],
          );
          if (accessToken == null || prepared.body is! List<int>) {
            throw const LlmConnectorAuthenticationRequired();
          }
          final response = await CursorHttp2Transport.open(
            dio: _dio,
            accessToken: accessToken,
            modelId: modelId,
            requestBody: prepared.body as List<int>,
            requestBlobs: prepared.requestBlobs,
            cancelToken: requestCancelToken,
            onRequestSent: () {
              markRequestSent();
              return waitForRequestSentMarker();
            },
          );
          await waitForRequestSentMarker();
          if (response.statusCode < 200 || response.statusCode >= 300) {
            if (response.statusCode == 401 &&
                !didRetry &&
                _canRefresh(storedAccount)) {
              didRetry = true;
              if (await accountService.refreshCredential(
                storedAccount,
                cancelToken: cancelToken,
              )) {
                continue;
              }
            }
            throw LlmConnectorHttpException(
              code: response.statusCode == 401 || response.statusCode == 403
                  ? 'authentication_required'
                  : 'upstream_error',
            );
          }
          if (stream) {
            final completed = Completer<LlmConnectorObservation>();
            final chunks = _cursorSse(response.deltas, modelId, completed);
            return LlmConnectorResponse(
              statusCode: response.statusCode,
              headers: response.headers,
              body: chunks,
              observation: LlmConnectorObservation(),
              completedObservation: completed.future,
            );
          }
          final text = StringBuffer();
          final reasoning = StringBuffer();
          Map<String, int>? usage;
          await for (final delta in response.deltas) {
            if (delta.text != null) text.write(delta.text);
            if (delta.reasoning != null) reasoning.write(delta.reasoning);
            usage = delta.usage ?? usage;
          }
          if (_isCursorComposerModel(modelId)) {
            text.write(
              CursorConnectFrameDecoder.visibleComposerReply(
                reasoning.toString(),
              ),
            );
            reasoning.clear();
          }
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final decoded = <String, dynamic>{
            'id': 'cursor-${now.toRadixString(16)}',
            'object': 'chat.completion',
            'created': now,
            'model': modelId,
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content': text.toString(),
                  if (reasoning.isNotEmpty)
                    'reasoning_content': reasoning.toString(),
                },
                'finish_reason': 'stop',
              },
            ],
          };
          if (usage != null) decoded['usage'] = usage;
          return LlmConnectorResponse(
            statusCode: response.statusCode,
            headers: response.headers,
            body: decoded,
            observation: LlmConnectorObservation(),
          );
        } on LlmConnectorHttpException {
          rethrow;
        } on LlmConnectorRequestCancelled {
          rethrow;
        } on CursorConnectRpcException catch (error) {
          if (error.code == 'unsupported_capability' ||
              error.code.startsWith('unsupported_')) {
            throw const LlmConnectorHttpException(
              code: 'unsupported_capability',
            );
          }
          if (error.code == 'authentication_required') {
            throw const LlmConnectorAuthenticationRequired();
          }
          if (error.code == 'request_cancelled') {
            throw const LlmConnectorRequestCancelled();
          }
          throw LlmConnectorHttpException(
            code: error.code == 'http2_unavailable' ||
                    error.code == 'transport_error'
                ? 'connection_error'
                : 'upstream_error',
          );
        } catch (_) {
          await waitForRequestSentMarker();
          throw const LlmConnectorHttpException();
        }
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
            followRedirects: storedAccount.connectorType != 'command-code',
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
            discardBody: stream,
            onErrorBodyLimitReached: () {
              requestCancelToken.cancel('Error response body limit reached');
            },
          );
          if (status == 401 && !didRetry && _canRefresh(storedAccount)) {
            didRetry = true;
            try {
              if (await accountService.refreshCredential(
                storedAccount,
                cancelToken: cancelToken,
              )) {
                continue;
              }
            } on DioException catch (error) {
              if (CancelToken.isCancel(error)) {
                throw const LlmConnectorRequestCancelled();
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
        if (storedAccount.connectorType == 'devin' &&
            storedAccount.authType == 'oauth') {
          final responseData = response.data;
          final responseBytes = responseData is ResponseBody
              ? await _readResponseStream(responseData.stream)
              : responseData is Stream<List<int>>
                  ? await _readResponseStream(responseData)
                  : responseData;
          if (responseBytes is! Uint8List && responseBytes is! List<int>) {
            throw const LlmConnectorHttpException();
          }
          final decoded = DevinConnectRpc.decodeChatResponse(
            responseBytes as List<int>,
          );
          final bodyObservation = parseLlmConnectorObservation(
            storedAccount.connectorType,
            decoded,
          );
          final observation = mergeLlmConnectorObservations(
            headerObservation,
            bodyObservation,
          );
          if (!stream) {
            return LlmConnectorResponse(
              statusCode: status,
              headers: response.headers.map,
              body: decoded,
              observation: observation,
            );
          }
          final choice = (decoded['choices'] as List).first as Map;
          final message = choice['message'] as Map;
          final messageToolCalls = message['tool_calls'];
          final toolCalls = messageToolCalls is Iterable
              ? messageToolCalls.indexed.map((entry) {
                  final item = entry.$2 as Map;
                  final fn = item['function'] as Map;
                  return {
                    'index': entry.$1,
                    'id': item['id'],
                    'type': 'function',
                    'function': {
                      'name': fn['name'],
                      'arguments': fn['arguments'],
                    },
                  };
                }).toList(growable: false)
              : null;
          final chunk = {
            'id': decoded['id'],
            'object': 'chat.completion.chunk',
            'created': decoded['created'],
            'model': decoded['model'],
            'choices': [
              {
                'index': 0,
                'delta': {
                  'content': message['content'],
                  ...?(toolCalls == null ? null : {'tool_calls': toolCalls}),
                },
                'finish_reason': choice['finish_reason'],
              },
            ],
          };
          final encoded = utf8.encode(
            'data: ${jsonEncode(chunk)}\n\ndata: [DONE]\n\n',
          );
          return LlmConnectorResponse(
            statusCode: status,
            headers: response.headers.map,
            body: Stream<List<int>>.value(encoded),
            observation: observation,
          );
        }
        if (storedAccount.connectorType == 'bedrock') {
          final responseData = response.data;
          final responseStream = responseData is ResponseBody
              ? responseData.stream
              : responseData is Stream<List<int>>
                  ? responseData
                  : null;
          if (stream) {
            if (responseStream == null) {
              throw const LlmConnectorHttpException();
            }
            final converted = AwsBedrockEventStreamAdapter.toOpenAiSse(
              responseStream,
            );
            final completed = Completer<LlmConnectorObservation>();
            final chunks = _observeResponseStream(
              storedAccount.connectorType,
              converted,
              headerObservation,
              completed,
            );
            return LlmConnectorResponse(
              statusCode: status,
              headers: response.headers.map,
              body: chunks,
              observation: headerObservation,
              completedObservation: completed.future,
            );
          }
          final raw = _decodeResponseBody(
            responseStream == null
                ? responseData
                : await _readResponseStream(responseStream),
          );
          final chatResponse = AwsBedrockConverseAdapter.fromConverse(raw);
          final bodyObservation = parseLlmConnectorObservation(
            storedAccount.connectorType,
            chatResponse,
          );
          return LlmConnectorResponse(
            statusCode: status,
            headers: response.headers.map,
            body: chatResponse,
            observation: mergeLlmConnectorObservations(
              headerObservation,
              bodyObservation,
            ),
          );
        }
        if (storedAccount.connectorType == 'gitlab-duo') {
          final responseData = response.data;
          final rawResponse = responseData is ResponseBody
              ? await _readResponseStream(responseData.stream)
              : responseData is Stream<List<int>>
                  ? await _readResponseStream(responseData)
                  : responseData;
          final normalized = _normalizeGitLabDuoResponse(
            _decodeResponseBody(rawResponse),
            modelId,
          );
          final bodyObservation = parseLlmConnectorObservation(
            storedAccount.connectorType,
            normalized,
          );
          return LlmConnectorResponse(
            statusCode: status,
            headers: response.headers.map,
            body: stream
                ? Stream<List<int>>.value(
                    _encodeOpenAiChatCompletionStream(normalized),
                  )
                : normalized,
            observation: mergeLlmConnectorObservations(
              headerObservation,
              bodyObservation,
            ),
          );
        }
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
            headers: response.headers.map,
            body: chunks,
            observation: headerObservation,
            completedObservation: completed.future,
          );
        }
        final responseData = response.data;
        final rawResponse = responseData is ResponseBody
            ? await _readResponseStream(responseData.stream)
            : responseData is Stream<List<int>>
                ? await _readResponseStream(responseData)
                : responseData;
        final isSseResponse = response.headers
                .value('content-type')
                ?.toLowerCase()
                .contains('text/event-stream') ??
            false;
        final decoded = !stream &&
                storedAccount.connectorType == 'ghe-copilot' &&
                isSseResponse
            ? nativeFormat == 'anthropic'
                ? _bufferAnthropicMessagesSse(rawResponse)
                : nativeFormat == 'responses' ||
                        (nativeFormat == null &&
                            modelId.toLowerCase().contains('codex'))
                    ? _bufferOpenAiResponsesSse(rawResponse)
                    : _bufferOpenAiChatSse(rawResponse)
            : !stream &&
                    const {
                      'codebuddy-cn',
                      'codebuddy-intl',
                      'workbuddy',
                      'cline',
                      'clinepass',
                    }.contains(storedAccount.connectorType) &&
                    isSseResponse
                ? _bufferOpenAiChatSse(rawResponse)
                : _decodeResponseBody(rawResponse);
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
          headers: response.headers.map,
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

  static Stream<List<int>> _cursorSse(
    Stream<CursorAgentDelta> source,
    String modelId,
    Completer<LlmConnectorObservation> completed,
  ) async* {
    final id =
        'cursor-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    Map<String, int>? usage;
    final composerReply = CursorComposerReplyDecoder();
    final isComposer = _isCursorComposerModel(modelId);
    try {
      await for (final delta in source) {
        usage = delta.usage ?? usage;
        final composerText = isComposer && delta.reasoning != null
            ? composerReply.add(delta.reasoning!)
            : null;
        if (composerText != null && composerText.isNotEmpty) {
          yield CursorConnectFrameDecoder.encodeSseChunk(
            id: id,
            model: modelId,
            text: composerText,
          );
        }
        if (delta.text != null || (!isComposer && delta.reasoning != null)) {
          yield CursorConnectFrameDecoder.encodeSseChunk(
            id: id,
            model: modelId,
            text: delta.text,
            reasoning: isComposer ? null : delta.reasoning,
          );
        }
      }
      if (isComposer) {
        final finalText = composerReply.finish();
        if (finalText.isNotEmpty) {
          yield CursorConnectFrameDecoder.encodeSseChunk(
            id: id,
            model: modelId,
            text: finalText,
          );
        }
      }
      yield CursorConnectFrameDecoder.encodeSseChunk(
        id: id,
        model: modelId,
        usage: usage,
        done: true,
      );
      yield Uint8List.fromList(utf8.encode('data: [DONE]\n\n'));
      if (!completed.isCompleted) {
        completed.complete(LlmConnectorObservation());
      }
    } on CursorConnectRpcException catch (error) {
      if (!completed.isCompleted) {
        completed.complete(LlmConnectorObservation());
      }
      if (error.code.startsWith('unsupported_')) {
        yield CursorConnectFrameDecoder.encodeSseErrorChunk(
          'unsupported_capability',
        );
        return;
      }
      rethrow;
    } catch (_) {
      if (!completed.isCompleted) {
        completed.complete(LlmConnectorObservation());
      }
      rethrow;
    }
  }

  static bool _isCursorComposerModel(String modelId) => RegExp(
        r'^composer(?:-|$)',
        caseSensitive: false,
      ).hasMatch(modelId.split('/').last);

  static bool _canRefresh(LlmAccount account) {
    final connector = LlmConnectorRegistry.find(account.connectorType);
    return connector?.canRefreshCredentials == true &&
        ((account.authType == 'oauth' &&
                (account.connectorType != 'vertex' ||
                    LlmOAuthProviderPolicy.forProvider(
                      account.connectorType,
                    ).supported)) ||
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
    if (account.connectorType == 'muse-code') {
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
    if (account.authType == 'oauth' && account.connectorType != 'muse-code') {
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

  static Map<String, dynamic> _bufferOpenAiChatSse(Object? data) {
    final bytes = data is Uint8List
        ? data
        : data is List<int>
            ? Uint8List.fromList(data)
            : null;
    if (bytes == null) throw const LlmConnectorHttpException();
    final text = utf8.decode(bytes, allowMalformed: true);
    final content = StringBuffer();
    final reasoning = StringBuffer();
    final calls = <int, Map<String, dynamic>>{};
    String? id;
    String? model;
    String? finishReason;
    Map<String, dynamic>? usage;
    for (final line in const LineSplitter().convert(text)) {
      if (!line.startsWith('data:')) continue;
      final dataLine = line.substring(5).trim();
      if (dataLine.isEmpty || dataLine == '[DONE]') continue;
      Object? parsed;
      try {
        parsed = jsonDecode(dataLine);
      } catch (_) {
        continue;
      }
      if (parsed is! Map) continue;
      final chunk = Map<String, dynamic>.from(parsed);
      if (chunk['error'] != null) throw const LlmConnectorHttpException();
      id ??= chunk['id'] is String ? chunk['id'] as String : null;
      model ??= chunk['model'] is String ? chunk['model'] as String : null;
      if (chunk['usage'] is Map) {
        usage = Map<String, dynamic>.from(chunk['usage'] as Map);
      }
      final choices = chunk['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        continue;
      }
      final choice = Map<String, dynamic>.from(choices.first as Map);
      final delta = choice['delta'];
      if (delta is Map) {
        final text = delta['content'];
        if (text is String) content.write(text);
        final thought = delta['reasoning_content'] ?? delta['reasoning'];
        if (thought is String) reasoning.write(thought);
        final toolCalls = delta['tool_calls'];
        if (toolCalls is List) {
          for (final rawCall in toolCalls) {
            if (rawCall is! Map) continue;
            final call = Map<String, dynamic>.from(rawCall);
            final index = call['index'] is int ? call['index'] as int : 0;
            final saved = calls.putIfAbsent(
              index,
              () => {
                'id': '',
                'type': 'function',
                'function': {'name': '', 'arguments': ''},
              },
            );
            if (call['id'] is String) saved['id'] = call['id'];
            final function = call['function'];
            if (function is Map) {
              final mergedFunction = saved['function'] as Map<String, dynamic>;
              if (function['name'] is String) {
                mergedFunction['name'] =
                    '${mergedFunction['name']}${function['name']}';
              }
              if (function['arguments'] is String) {
                mergedFunction['arguments'] =
                    '${mergedFunction['arguments']}${function['arguments']}';
              }
            }
          }
        }
      }
      if (choice['finish_reason'] is String) {
        finishReason = choice['finish_reason'] as String;
      }
    }
    final usageField = usage == null ? null : <String, dynamic>{'usage': usage};
    return {
      'id': id ?? 'buffered-chat-completion',
      'object': 'chat.completion',
      'model': model ?? '',
      ...?usageField,
      'choices': [
        {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': content.toString(),
            if (reasoning.isNotEmpty) 'reasoning_content': reasoning.toString(),
            if (calls.isNotEmpty)
              'tool_calls': [
                for (final i in calls.keys.toList()..sort()) calls[i],
              ],
          },
          'finish_reason': finishReason ?? 'stop',
        },
      ],
    };
  }

  static Map<String, dynamic> _bufferAnthropicMessagesSse(Object? data) {
    final bytes = data is Uint8List
        ? data
        : data is List<int>
            ? Uint8List.fromList(data)
            : null;
    if (bytes == null) throw const LlmConnectorHttpException();
    final text = utf8.decode(bytes, allowMalformed: true);
    final blocks = <int, Map<String, dynamic>>{};
    String? id;
    String? model;
    String? stopReason;
    String? stopSequence;
    var inputTokens = 0;
    var outputTokens = 0;
    for (final line in const LineSplitter().convert(text)) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      Object? decoded;
      try {
        decoded = jsonDecode(payload);
      } catch (_) {
        continue;
      }
      if (decoded is! Map) continue;
      final event = Map<String, dynamic>.from(decoded);
      switch (event['type']) {
        case 'error':
          throw const LlmConnectorHttpException();
        case 'message_start':
          final message = event['message'];
          if (message is Map) {
            id = message['id'] as String?;
            model = message['model'] as String?;
            final usage = message['usage'];
            if (usage is Map) {
              inputTokens = (usage['input_tokens'] as num?)?.toInt() ?? 0;
              outputTokens = (usage['output_tokens'] as num?)?.toInt() ?? 0;
            }
          }
          break;
        case 'content_block_start':
          final index = (event['index'] as num?)?.toInt();
          final block = event['content_block'];
          if (index != null && block is Map) {
            blocks[index] = Map<String, dynamic>.from(block);
          }
          break;
        case 'content_block_delta':
          final index = (event['index'] as num?)?.toInt();
          final block = index == null ? null : blocks[index];
          final delta = event['delta'];
          if (block == null || delta is! Map) continue;
          if (delta['type'] == 'text_delta' && delta['text'] is String) {
            block['text'] = '${block['text'] ?? ''}${delta['text']}';
          } else if (delta['type'] == 'thinking_delta' &&
              delta['thinking'] is String) {
            block['thinking'] =
                '${block['thinking'] ?? ''}${delta['thinking']}';
          } else if (delta['type'] == 'signature_delta' &&
              delta['signature'] is String) {
            block['signature'] =
                '${block['signature'] ?? ''}${delta['signature']}';
          } else if (delta['type'] == 'input_json_delta' &&
              delta['partial_json'] is String) {
            block['input'] = '${block['input'] ?? ''}${delta['partial_json']}';
          }
          break;
        case 'message_delta':
          final delta = event['delta'];
          if (delta is Map) {
            stopReason = delta['stop_reason'] as String?;
            stopSequence = delta['stop_sequence'] as String?;
          }
          final usage = event['usage'];
          if (usage is Map) {
            inputTokens =
                (usage['input_tokens'] as num?)?.toInt() ?? inputTokens;
            outputTokens =
                (usage['output_tokens'] as num?)?.toInt() ?? outputTokens;
          }
          break;
      }
    }
    if (blocks.isEmpty) throw const LlmConnectorHttpException();
    final content = <Map<String, dynamic>>[];
    for (final index in blocks.keys.toList()..sort()) {
      final block = Map<String, dynamic>.from(blocks[index]!);
      if (block['type'] == 'tool_use' && block['input'] is String) {
        try {
          final input = jsonDecode(block['input'] as String);
          block['input'] = input is Map ? Map<String, dynamic>.from(input) : {};
        } catch (_) {
          throw const LlmConnectorHttpException();
        }
      }
      content.add(block);
    }
    return {
      'id': id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'message',
      'role': 'assistant',
      'model': model,
      'content': content,
      'stop_reason': stopReason,
      'stop_sequence': stopSequence,
      'usage': {'input_tokens': inputTokens, 'output_tokens': outputTokens},
    };
  }

  static Map<String, dynamic> _bufferOpenAiResponsesSse(Object? data) {
    final bytes = data is Uint8List
        ? data
        : data is List<int>
            ? Uint8List.fromList(data)
            : null;
    if (bytes == null) throw const LlmConnectorHttpException();
    final text = utf8.decode(bytes, allowMalformed: true);
    for (final line in const LineSplitter().convert(text)) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      Object? decoded;
      try {
        decoded = jsonDecode(payload);
      } catch (_) {
        continue;
      }
      if (decoded is! Map) continue;
      final event = Map<String, dynamic>.from(decoded);
      if (event['type'] == 'response.failed' || event['error'] != null) {
        throw const LlmConnectorHttpException();
      }
      if (event['type'] == 'response.completed' ||
          event['type'] == 'response.done') {
        final response = event['response'];
        if (response is Map) return Map<String, dynamic>.from(response);
      }
      if (event['object'] == 'response' && event['status'] == 'completed') {
        return event;
      }
    }
    throw const LlmConnectorHttpException();
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
    bool discardBody = false,
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
      if (discardBody) {
        onErrorBodyLimitReached?.call();
      } else {
        decodedBody = await _readFailureBody(body);
      }
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

  static Future<Object?> _readFailureBody(Object? body) async {
    if (body is ResponseBody) {
      return _decodeResponseBody(await _readBoundedFailureStream(body.stream));
    }
    if (body is Stream<List<int>>) {
      return _decodeResponseBody(await _readBoundedFailureStream(body));
    }
    return _decodeResponseBody(body);
  }

  static Future<Uint8List> _readBoundedFailureStream(
    Stream<List<int>> stream,
  ) async {
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
Map<String, dynamic> _normalizeGitLabDuoResponse(
  Object? value,
  String requestedModel,
) {
  if (value is! Map) throw const LlmConnectorHttpException();
  final payload = Map<String, dynamic>.from(value);
  final choices = payload['choices'];
  final firstChoice =
      choices is List && choices.isNotEmpty && choices.first is Map
          ? Map<String, dynamic>.from(choices.first as Map)
          : const <String, dynamic>{};
  final rawMessage = firstChoice['message'];
  final message =
      rawMessage is Map ? Map<String, dynamic>.from(rawMessage) : null;
  final content = firstChoice['text'] is String
      ? firstChoice['text'] as String
      : message?['content'] is String
          ? message!['content'] as String
          : payload['content'] is String
              ? payload['content'] as String
              : null;
  if (content == null) throw const LlmConnectorHttpException();
  final model = payload['model'];
  final modelName = model is String
      ? model
      : model is Map
          ? model['name'] is String
              ? model['name'] as String
              : model['id'] is String
                  ? model['id'] as String
                  : requestedModel
          : requestedModel;
  final created = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return {
    'id': 'chatcmpl-gitlab-$created',
    'object': 'chat.completion',
    'created': created,
    'model': modelName,
    'choices': [
      {
        'index': 0,
        'message': {'role': 'assistant', 'content': content},
        'finish_reason': 'stop',
      },
    ],
  };
}

Uint8List _encodeOpenAiChatCompletionStream(Map<String, dynamic> completion) {
  final choice = (completion['choices'] as List).first as Map;
  final message = choice['message'] as Map;
  final chunk = {
    'id': completion['id'],
    'object': 'chat.completion.chunk',
    'created': completion['created'],
    'model': completion['model'],
    'choices': [
      {
        'index': 0,
        'delta': {'content': message['content']},
        'finish_reason': null,
      },
    ],
  };
  final finish = {
    'id': completion['id'],
    'object': 'chat.completion.chunk',
    'created': completion['created'],
    'model': completion['model'],
    'choices': [
      {'index': 0, 'delta': {}, 'finish_reason': 'stop'},
    ],
  };
  return Uint8List.fromList(
    utf8.encode(
      'data: ${jsonEncode(chunk)}\n\ndata: ${jsonEncode(finish)}\n\ndata: [DONE]\n\n',
    ),
  );
}

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

class LlmConnectorAuthenticationRequired implements Exception {
  const LlmConnectorAuthenticationRequired();

  @override
  String toString() =>
      'The provider account needs valid API credentials or OAuth authorization.';
}

class LlmConnectorRequestCancelled implements Exception {
  const LlmConnectorRequestCancelled();

  @override
  String toString() => 'LLM connector request was cancelled.';
}
