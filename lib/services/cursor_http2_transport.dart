import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http2/transport.dart';
import 'package:uuid/uuid.dart';

import 'cursor_connect_rpc.dart';

const cursorAgentClientVersion = 'cli-2026.07.08-0c04a8a';
const cursorAgentStreamTimeout = Duration(minutes: 5);
const cursorServerConfigUrl =
    'https://api2.cursor.sh/aiserver.v1.ServerConfigService/GetServerConfig';

void ensureCursorRequestNotCancelled(CancelToken? cancelToken) {
  if (cancelToken?.isCancelled ?? false) {
    throw const CursorConnectRpcException('request_cancelled');
  }
}

Future<T> awaitCursorConnection<T>({
  required Future<T> connection,
  required CancelToken? cancelToken,
  required void Function(T) disposeLateConnection,
  Duration timeout = const Duration(seconds: 20),
}) {
  final result = Completer<T>();
  var settled = false;
  var abandoned = false;
  final timer = Timer(timeout, () {
    if (settled) return;
    settled = true;
    abandoned = true;
    result.completeError(const CursorConnectRpcException('transport_error'));
  });
  connection.then(
    (value) {
      if (abandoned || (cancelToken?.isCancelled ?? false)) {
        try {
          disposeLateConnection(value);
        } catch (_) {}
        if (!settled) {
          settled = true;
          timer.cancel();
          result.completeError(
            const CursorConnectRpcException('request_cancelled'),
          );
        }
      } else if (!settled) {
        settled = true;
        timer.cancel();
        result.complete(value);
      } else {
        try {
          disposeLateConnection(value);
        } catch (_) {}
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (settled) return;
      settled = true;
      timer.cancel();
      result.completeError(error, stackTrace);
    },
  );
  cancelToken?.whenCancel.then((_) {
    if (settled) return;
    settled = true;
    abandoned = true;
    timer.cancel();
    result.completeError(const CursorConnectRpcException('request_cancelled'));
  });
  return result.future;
}

/// Bounds the full response lifetime after a routed stream is consumed.
Stream<T> cursorAgentResponseWithDeadline<T>(
  Stream<T> source, {
  Duration timeout = cursorAgentStreamTimeout,
  required void Function() onTimeout,
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  Timer? timer;
  var timedOut = false;
  controller = StreamController<T>(
    onListen: () {
      subscription = source.listen(
        controller.add,
        onError: (Object error, StackTrace stackTrace) {
          if (!timedOut) controller.addError(error, stackTrace);
        },
        onDone: () {
          timer?.cancel();
          if (!timedOut) unawaited(controller.close());
        },
      );
    },
    onCancel: () {
      timer?.cancel();
      unawaited(subscription?.cancel());
    },
  );
  timer = Timer(timeout, () {
    timedOut = true;
    controller.addError(const CursorConnectRpcException('response_timeout'));
    onTimeout();
    unawaited(subscription?.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
}

class CursorAgentHttpResponse {
  final int statusCode;
  final Map<String, List<String>> headers;
  final Stream<CursorAgentDelta> deltas;

  const CursorAgentHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.deltas,
  });
}

void terminateCursorTransportForStatus(
  int statusCode,
  void Function() terminate,
) {
  if (statusCode < 200 || statusCode >= 300) terminate();
}

/// Drives the pinned Cursor bidirectional Connect-RPC through HTTP/2 so the
/// request-context and key-value acknowledgements can be written while the
/// response is still streaming.
class CursorHttp2Transport {
  static Future<CursorAgentHttpResponse> open({
    required Dio dio,
    required String accessToken,
    required String modelId,
    required List<int> requestBody,
    Map<String, Uint8List> requestBlobs = const {},
    CancelToken? cancelToken,
    Future<void> Function()? onRequestSent,
  }) async {
    if (accessToken.trim().isEmpty) {
      throw const CursorConnectRpcException('authentication_required');
    }
    ensureCursorRequestNotCancelled(cancelToken);
    late final Response<List<int>> serverConfig;
    try {
      serverConfig = await dio.post<List<int>>(
        cursorServerConfigUrl,
        data: Uint8List(0),
        options: Options(
          contentType: 'application/proto',
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status != null,
          headers: {
            'authorization': 'Bearer ${accessToken.trim()}',
            'connect-protocol-version': '1',
            'user-agent': 'connect-es/1.6.1',
            'x-cursor-client-type': 'cli',
            'x-cursor-client-version': cursorAgentClientVersion,
          },
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const CursorConnectRpcException('request_cancelled');
      }
      if (error.response != null) {
        return CursorAgentHttpResponse(
          statusCode: error.response!.statusCode ?? 0,
          headers: error.response!.headers.map,
          deltas: const Stream.empty(),
        );
      }
      throw const CursorConnectRpcException('transport_error');
    }
    final configStatus = serverConfig.statusCode ?? 0;
    if (configStatus < 200 || configStatus >= 300) {
      return CursorAgentHttpResponse(
        statusCode: configStatus,
        headers: serverConfig.headers.map,
        deltas: const Stream.empty(),
      );
    }
    final endpoint = CursorConnectFrameDecoder.decodeAgentRunEndpoint(
      serverConfig.data ?? const <int>[],
    );
    ensureCursorRequestNotCancelled(cancelToken);
    final socket = await awaitCursorConnection<SecureSocket>(
      connection: SecureSocket.connect(
        endpoint.host,
        endpoint.port == 0 ? 443 : endpoint.port,
        supportedProtocols: const ['h2'],
      ),
      cancelToken: cancelToken,
      disposeLateConnection: (socket) => socket.destroy(),
    );
    try {
      ensureCursorRequestNotCancelled(cancelToken);
    } on CursorConnectRpcException {
      socket.destroy();
      rethrow;
    }
    if (socket.selectedProtocol != 'h2') {
      socket.destroy();
      throw const CursorConnectRpcException('http2_unavailable');
    }
    final connection = ClientTransportConnection.viaSocket(socket);
    final requestId = const Uuid().v4();
    final traceId = _randomHex(32);
    final spanId = _randomHex(16);
    final stream = connection.makeRequest([
      Header.ascii(':method', 'POST'),
      Header.ascii(':scheme', 'https'),
      Header.ascii(':authority', endpoint.authority),
      Header.ascii(':path', endpoint.path),
      Header.ascii('authorization', 'Bearer ${accessToken.trim()}'),
      Header.ascii('content-type', 'application/connect+proto'),
      Header.ascii('connect-protocol-version', '1'),
      Header.ascii('connect-accept-encoding', 'gzip'),
      Header.ascii('user-agent', 'connect-es/1.6.1'),
      Header.ascii('x-cursor-client-type', 'cli'),
      Header.ascii('x-cursor-client-version', cursorAgentClientVersion),
      Header.ascii('x-ghost-mode', 'true'),
      Header.ascii('traceparent', '00-$traceId-$spanId-01'),
      Header.ascii('backend-traceparent', '00-$traceId-$spanId-01'),
      Header.ascii('x-original-request-id', requestId),
      Header.ascii('x-request-id', requestId),
    ]);
    final status = Completer<int>();
    final responseHeaders = <String, List<String>>{};
    late final StreamController<CursorAgentDelta> controller;
    final decoder = CursorConnectFrameDecoder();
    var responseStatus = 0;
    var terminal = false;
    var sawContent = false;
    var terminated = false;
    Timer? drainTimer;

    void terminate() {
      if (terminated) return;
      terminated = true;
      stream.terminate();
      unawaited(connection.terminate());
      socket.destroy();
    }

    controller = StreamController<CursorAgentDelta>(
      onCancel: () {
        drainTimer?.cancel();
        terminate();
      },
    );

    void completeAfterTerminal() {
      if (terminal) return;
      terminal = true;
      drainTimer = Timer(const Duration(milliseconds: 300), () {
        try {
          stream.sendData(const [], endStream: true);
        } catch (_) {}
        if (!controller.isClosed) unawaited(controller.close());
        drainTimer = Timer(const Duration(seconds: 2), terminate);
      });
    }

    stream.incomingMessages.listen(
      (message) {
        if (message is HeadersStreamMessage) {
          for (final header in message.headers) {
            final name = String.fromCharCodes(header.name).toLowerCase();
            final value = String.fromCharCodes(header.value);
            if (name == ':status') {
              responseStatus = int.tryParse(value) ?? 0;
              if (!status.isCompleted) status.complete(responseStatus);
              if (responseStatus < 200 || responseStatus >= 300) {
                if (!controller.isClosed) unawaited(controller.close());
                terminateCursorTransportForStatus(responseStatus, terminate);
              }
            } else if (const {
              'content-type',
              'connect-protocol-version',
              'grpc-status',
            }.contains(name)) {
              responseHeaders.putIfAbsent(name, () => []).add(value);
            }
          }
        } else if (message is DataStreamMessage) {
          if (responseStatus < 200 || responseStatus >= 300) return;
          try {
            for (final delta in decoder.add(message.bytes)) {
              if (delta.requestContextId != null) {
                stream.sendData(
                  CursorConnectFrameDecoder.encodeRequestContextAck(
                    delta.requestContextId!,
                    delta.execId ?? '',
                  ),
                );
              } else if (delta.mcpStateId != null) {
                stream.sendData(
                  CursorConnectFrameDecoder.encodeMcpStateAck(
                    id: delta.mcpStateId!,
                    execId: delta.execId ?? '',
                    serverIdentifier: delta.mcpServerIdentifier ?? 'stroom',
                  ),
                );
              } else if (delta.keyValueId != null) {
                final blobIdHex = delta.keyValueBlobId
                    ?.map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                    .join();
                stream.sendData(
                  CursorConnectFrameDecoder.encodeKeyValueAck(
                    id: delta.keyValueId!,
                    set: delta.keyValueSet ?? false,
                    blobData: delta.keyValueGet == true
                        ? requestBlobs[blobIdHex] ?? Uint8List(0)
                        : null,
                    requestMetadata: delta.requestMetadata,
                  ),
                );
                if (modelId.toLowerCase().contains('composer') && sawContent) {
                  completeAfterTerminal();
                }
              } else if (delta.unsupportedAction != null) {
                controller.addError(
                  CursorConnectRpcException(
                    'unsupported_${delta.unsupportedAction}',
                  ),
                );
                terminate();
                return;
              } else if (terminal) {
                continue;
              } else {
                if (delta.text != null || delta.reasoning != null) {
                  sawContent = true;
                }
                controller.add(delta);
                if (delta.turnEnded) completeAfterTerminal();
              }
            }
          } catch (error) {
            controller.addError(
              error is CursorConnectRpcException
                  ? error
                  : const CursorConnectRpcException('invalid_response'),
            );
            terminate();
          }
        }
      },
      onError: (Object _) {
        if (!status.isCompleted) {
          status.completeError(
            const CursorConnectRpcException('transport_error'),
          );
        }
        if (!controller.isClosed) {
          controller.addError(
            const CursorConnectRpcException('transport_error'),
          );
          unawaited(controller.close());
        }
        terminate();
      },
      onDone: () {
        drainTimer?.cancel();
        if (!status.isCompleted) {
          status.completeError(
            const CursorConnectRpcException('missing_response_status'),
          );
        }
        try {
          decoder.finish();
          if (!controller.isClosed) unawaited(controller.close());
          unawaited(connection.finish());
          socket.destroy();
        } on CursorConnectRpcException catch (error) {
          if (!controller.isClosed) {
            controller.addError(error);
            unawaited(controller.close());
          }
          terminate();
        }
      },
      cancelOnError: true,
    );
    cancelToken?.whenCancel.then((_) {
      drainTimer?.cancel();
      if (!controller.isClosed) {
        controller.addError(
          const CursorConnectRpcException('request_cancelled'),
        );
      }
      terminate();
    });

    try {
      ensureCursorRequestNotCancelled(cancelToken);
      stream.sendData(requestBody);
      await onRequestSent?.call();
    } on CursorConnectRpcException {
      terminate();
      rethrow;
    } catch (_) {
      terminate();
      throw const CursorConnectRpcException('request_send_failed');
    }
    try {
      final statusCode = await status.future.timeout(
        const Duration(seconds: 30),
      );
      return CursorAgentHttpResponse(
        statusCode: statusCode,
        headers: Map.unmodifiable(responseHeaders),
        deltas: statusCode < 200 || statusCode >= 300
            ? const Stream.empty()
            : cursorAgentResponseWithDeadline(
                controller.stream,
                onTimeout: terminate,
              ),
      );
    } on TimeoutException {
      terminate();
      throw const CursorConnectRpcException('response_timeout');
    } catch (_) {
      terminate();
      rethrow;
    }
  }

  static String _randomHex(int length) {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join()
        .substring(0, length);
  }
}
