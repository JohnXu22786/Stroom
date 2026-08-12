import 'dart:async';
import 'dart:convert';
import 'dart:io' show Process, ProcessStartMode;

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;

import '../models/mcp.dart';
import 'sse_client.dart';
import 'app_log_service.dart';

// ============================================================================
// MCP 远程传输函数类型（可注入以便测试）
// ============================================================================

/// streamable HTTP：POST 一条 JSON-RPC 消息，逐行产出响应（完整 SSE 行）。
typedef McpPostLinesFn = Stream<String> Function(
  String url,
  Map<String, String> headers,
  String body, {
  CancelToken? cancelToken,
  void Function(Map<String, List<String>> headers)? onResponseHeaders,
});

/// legacy SSE：GET 建立持久连接，逐行产出（含 `event: endpoint`）。
typedef McpSseConnectFn = Stream<String> Function(
  String url,
  Map<String, String> headers, {
  CancelToken? cancelToken,
  void Function(Map<String, List<String>> headers)? onResponseHeaders,
});

/// legacy SSE：向消息端点 POST 一条 JSON-RPC 消息，返回响应体字符串。
typedef McpSsePostFn = Future<String> Function(
  String url,
  Map<String, String> headers,
  String body, {
  CancelToken? cancelToken,
});

/// 单次 streamable HTTP 响应的 SSE 解析器。
///
/// **每个请求独立实例**：聊天服务会并发执行同一服务器的多个工具调用
/// （Future.wait），共享解析状态会把两个响应的 data 行拼在一起。
///
/// 支持：
/// - `event: <name>` / `data: <payload>`（同事件内多个 data 行按 SSE 规范
///   以 `\n` 连接，作为完整 JSON-RPC 载荷）；
/// - `data:` / `event:` 冒号后无空格（SSE 规范允许）；
/// - 裸 JSON 行（application/json 响应体，无 SSE 帧）。
class _SseResponseParser {
  String? _currentEvent;
  final List<String> _dataLines = [];

  /// 处理一行；[onPayload] 在解析出完整 JSON-RPC 载荷时回调。
  void handleLine(String line, void Function(String payload) onPayload) {
    if (line.startsWith('event:')) {
      _currentEvent = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      var payload = line.substring(5);
      if (payload.startsWith(' ')) payload = payload.substring(1);
      _dataLines.add(payload);
    } else if (line.isEmpty) {
      _flush(onPayload);
    } else if (_currentEvent == null &&
        _dataLines.isEmpty &&
        line.trimLeft().startsWith('{')) {
      // application/json 裸响应体：整行即 JSON-RPC 消息
      onPayload(line.trim());
    }
  }

  /// 流结束时调用：补发尚未遇到空行的残余 data 行（某些服务器响应
  /// 末尾没有空行分隔符）。
  void flush(void Function(String payload) onPayload) => _flush(onPayload);

  void _flush(void Function(String payload) onPayload) {
    if (_dataLines.isEmpty) {
      _currentEvent = null;
      return;
    }
    final payload = _dataLines.join('\n').trim();
    _dataLines.clear();
    _currentEvent = null;
    if (payload.isNotEmpty) onPayload(payload);
  }
}

/// 远程 MCP 实际使用的传输协议。
///
/// - [streamableHttp]：现代远程服务器（Exa/Tavily/Firecrawl/Jina/智谱等）
///   的标准传输：每条 JSON-RPC 消息直接 POST，响应从该 POST 的 SSE 流中
///   读取（`event: message` / `data:` 帧，或 application/json 裸 JSON）。
/// - [legacySse]：旧版 HTTP+SSE：GET 建立持久连接，收到 `event: endpoint`
///   后用该 URL POST 消息，响应经 GET 流回传。
enum _RemoteMode { streamableHttp, legacySse }

// ============================================================================
// JSON-RPC 工具函数（纯逻辑，可直接测试）
// ============================================================================

/// JSON-RPC 编解码工具函数
class JsonRpcUtils {
  /// 解析一行 JSON-RPC 响应字符串
  static McpMessage? parseResponse(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      return McpMessage.fromJson(json);
    } catch (e) {
      debugPrint('JsonRpcUtils.parseResponse: invalid JSON: $e');
      return null;
    }
  }

  /// 从 tools/list 的 result 中提取工具列表
  static List<McpTool> extractTools(Map<String, dynamic>? result) {
    if (result == null) return [];
    final toolsJson = result['tools'] as List<dynamic>?;
    if (toolsJson == null) return [];
    return toolsJson
        .map((e) => McpTool.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 从 tools/call 的 result 中提取调用结果
  static McpToolCallResponse? extractCallResult(Map<String, dynamic>? result) {
    if (result == null) return null;
    return McpToolCallResponse.fromMap(result);
  }

  /// 构建 JSON-RPC 请求字符串
  static String buildRequest(String method, [Map<String, dynamic>? params]) {
    return McpMessage.request(method, params).toJsonString();
  }

  /// 构建 JSON-RPC 通知字符串（无 id，服务端不返回响应）
  static String buildNotification(String method,
      [Map<String, dynamic>? params]) {
    return McpMessage.notification(method, params).toJsonString();
  }

  /// 从 JSON-RPC 消息体中提取 request ID
  static String? extractRequestId(String message) {
    try {
      final parsed = jsonDecode(message) as Map<String, dynamic>;
      return parsed['id'] as String?;
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// MCP 客户端 — 连接到 MCP 服务器并执行工具
// ============================================================================

/// MCP 客户端状态
enum _McpClientState { created, connecting, connected, disconnected, disposed }

/// MCP 客户端，管理与单个 MCP 服务器的连接
///
/// ## 远程传输协议
/// 远程服务器优先使用 **streamable HTTP**（现代标准：每条 JSON-RPC 消息
/// 直接 POST，响应从该 POST 的 SSE 流中读取）；POST 失败（如旧版服务器
/// 仅支持 HTTP+SSE）时自动回退 **legacy SSE**（GET 建立连接 + endpoint
/// POST）。
///
/// ## 跨平台兼容性
/// | 传输方式 | iOS | Android | Linux | Windows | macOS | Web |
/// |----------|-----|---------|-------|---------|-------|-----|
/// | stdio    | ❌  | ❌      | ✅    | ✅      | ✅    | ❌  |
/// | sse      | ✅  | ✅      | ✅    | ✅      | ✅    | ✅  |
///
/// - **stdio**: 仅桌面端可用（需要 `dart:io` Process 启动子进程）
/// - **sse / streamable HTTP**: 全端可用（使用 HTTP POST + SSE 响应，
///   支持所有平台的条件导出 SSE 客户端）
class McpClient {
  final McpServerConfig config;

  _McpClientState _state = _McpClientState.created;
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  /// 挂起的请求：id -> Completer
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  /// 当前连接的工具列表（缓存）
  List<McpTool> _cachedTools = [];

  McpClient({
    required this.config,
    McpPostLinesFn? postLines,
    McpSseConnectFn? sseConnectFn,
    McpSsePostFn? ssePostFn,
  })  : _postLines = postLines ?? ssePostLines,
        _sseConnectFn = sseConnectFn ?? sseConnect,
        _ssePostFn = ssePostFn ?? ssePost {
    _validateConfig();
  }

  /// 注入或默认的传输函数（默认实现来自 sse_client.dart 的条件导出）。
  final McpPostLinesFn _postLines;
  final McpSseConnectFn _sseConnectFn;
  final McpSsePostFn _ssePostFn;

  void _validateConfig() {
    if (config.transportType == McpTransportType.sse &&
        (config.url == null || config.url!.isEmpty)) {
      throw ArgumentError('SSE transport requires a non-empty URL');
    }
    if (config.transportType == McpTransportType.stdio &&
        (config.command == null || config.command!.isEmpty)) {
      throw ArgumentError('Stdio transport requires a non-empty command');
    }
  }

  // ==========================================================================
  // 远程 MCP 传输（SSE）通用逻辑
  // ==========================================================================

  _RemoteMode _mode = _RemoteMode.legacySse;

  /// streamable HTTP 会话 ID（响应头 `mcp-session-id`），后续请求回传。
  String? _mcpSessionId;

  /// 正在进行的 streamable HTTP POST 订阅（连接阶段读取 initialize 响应）。
  StreamSubscription<String>? _postStreamSubscription;

  /// 解析发给远程服务器的请求头：
  ///
  /// 1. 请求头中的占位值（空、`'Bearer '` 前缀、裸 `'Bearer'`）用
  ///    [McpServerConfig.apiKey] 填充；
  /// 2. 以 apiKey 字段为唯一凭据来源，收敛为**单个**鉴权类请求头
  ///    （优先 Authorization，其次 x-api-key/token…），刷新过期值并删除
  ///    冗余鉴权头——同一凭据重复发送可能被服务器拒绝（如 Tavily 明确
  ///    拒绝 x-api-key）。
  ///
  /// 旧实现无条件给 apiKey 追加 `x-api-key` 头——Tavily 不接受该头，
  /// 且 `putIfAbsent` 不会覆盖已存在的空占位头（Exa 会发出空 key）。
  @visibleForTesting
  static Map<String, String> resolveRequestHeaders(McpServerConfig config) {
    final headers = <String, String>{...config.headers};
    final key = config.apiKey;
    if (key == null || key.isEmpty) return headers;

    // 1. 填充鉴权类请求头的占位值（仅 Authorization 头加 Bearer 前缀，
    //    其余头用裸 key）。非鉴权头不注入 key——自定义头留作用户显式配置。
    for (final entry in headers.entries.toList()) {
      if (!_isAuthHeaderName(entry.key) || !_isHeaderPlaceholder(entry.value)) {
        continue;
      }
      headers[entry.key] =
          entry.key.toLowerCase() == 'authorization' ? 'Bearer $key' : key;
    }

    // 2. 收敛为单个鉴权头（apiKey 覆盖所有鉴权类请求头的最新值）。
    //    先物化列表再修改 Map，避免迭代期间并发修改。
    final authNames = headers.keys.where(_isAuthHeaderName).toList();
    if (authNames.isEmpty) {
      headers['Authorization'] = 'Bearer $key';
      return headers;
    }
    String? preferred;
    for (final name in authNames) {
      if (name.toLowerCase() == 'authorization') {
        preferred = name;
        break;
      }
    }
    preferred ??= authNames.first;
    headers[preferred] =
        preferred.toLowerCase() == 'authorization' ? 'Bearer $key' : key;
    for (final name in authNames) {
      if (name != preferred) headers.remove(name);
    }
    return headers;
  }

  /// 判断请求头值是否为"待填充"的占位值（空 / `Bearer ` 前缀 / 裸 `Bearer`）。
  static bool _isHeaderPlaceholder(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    if (trimmed.toLowerCase() == 'bearer') return true;
    return value.endsWith(' ');
  }

  /// 判断请求头名是否为常见的鉴权头。
  static bool _isAuthHeaderName(String name) {
    final lower = name.toLowerCase();
    return lower == 'authorization' ||
        lower == 'x-api-key' ||
        lower == 'api-key' ||
        lower == 'apikey' ||
        lower == 'token' ||
        lower == 'key';
  }

  /// 构建 POST 请求头：鉴权 + streamable HTTP 协议头 + 会话 ID。
  Map<String, String> _buildPostHeaders() {
    final headers = resolveRequestHeaders(config)
      ..['Content-Type'] = 'application/json'
      ..['Accept'] = 'application/json, text/event-stream'
      ..['MCP-Protocol-Version'] = '2024-11-05';
    final session = _mcpSessionId;
    if (session != null && session.isNotEmpty) {
      headers['Mcp-Session-Id'] = session;
    }
    return headers;
  }

  /// 构建 legacy SSE GET 请求头：鉴权 + Accept。
  Map<String, String> _buildGetHeaders() {
    return resolveRequestHeaders(config)..['Accept'] = 'text/event-stream';
  }

  /// 是否已连接
  bool get isConnected => _state == _McpClientState.connected;

  /// 是否已释放
  bool get isDisposed => _state == _McpClientState.disposed;

  /// 获取缓存的工具列表
  List<McpTool> get cachedTools => List.unmodifiable(_cachedTools);

  /// 正在进行的 connect() future。
  ///
  /// 防并发重连：并行工具执行时，同一断开的 MCP 服务器可能同时收到
  /// 多个工具调用，各自触发 connect()。没有此守卫会并发执行两次
  /// 连接：stdio 启动两个子进程（一个孤儿）、SSE 建立两条持久连接
  /// （一条泄漏），且共享的 _sseEndpointCompleter/_cancelToken 会被
  /// 互相覆盖。连接完成后置空，允许后续重连。
  Future<bool>? _connectFuture;

  /// 连接到 MCP 服务器
  Future<bool> connect() {
    if (_state == _McpClientState.disposed) return Future.value(false);
    if (_state == _McpClientState.connected) return Future.value(true);
    final inFlight = _connectFuture;
    if (inFlight != null) return inFlight;

    final future = _connectInternal().whenComplete(() {
      _connectFuture = null;
    });
    _connectFuture = future;
    return future;
  }

  Future<bool> _connectInternal() async {
    await AppLogService.info('McpClient',
        '连接 MCP 服务器: ${config.name} (${config.transportType.name})');
    // 日志 await 期间可能已 dispose()：不得把 disposed 状态覆盖回
    // connecting（否则整个连接流程会在已释放的客户端上继续执行，
    // 启动无人清理的新进程/新 SSE 连接）。
    if (_state == _McpClientState.disposed) return false;

    _state = _McpClientState.connecting;

    try {
      switch (config.transportType) {
        case McpTransportType.stdio:
          await _connectStdio();
          await _sendInitialize();
        case McpTransportType.sse:
          // _connectSse 内部自行发送 initialize（streamable HTTP 模式下
          // 连接即 initialize 往返；legacy SSE 模式在收到 endpoint 后发送）。
          await _connectSse();
      }

      // 连接期间被 dispose()：不复活已释放的客户端（否则后续
      // callTool 会对空 _process/已取消的 SSE 请求超时 30s）。
      if (_state == _McpClientState.disposed) return false;
      _state = _McpClientState.connected;
      await AppLogService.info('McpClient', 'MCP 服务器连接成功: ${config.name}');
      return true;
    } catch (e) {
      debugPrint('McpClient.connect failed for ${config.name}: $e');
      // dispose() 后的失败不得把 disposed 状态覆盖回 disconnected
      //（否则后续 connect() 会重新拉起一个已释放客户端的连接）。
      if (_state != _McpClientState.disposed) {
        _state = _McpClientState.disconnected;
      }
      await AppLogService.error('McpClient', 'MCP 服务器连接失败: ${config.name}', e);
      return false;
    }
  }

  Future<void> _connectStdio() async {
    // stdio 传输仅桌面端可用（iOS/Android/Web 不支持启动子进程）
    if (kIsWeb) {
      throw UnsupportedError('stdio MCP 在 Web 平台上不可用。请使用 SSE (远程) MCP 服务器。');
    }

    try {
      _process = await Process.start(
        config.command!,
        config.args ?? [],
        environment: config.env.isNotEmpty ? config.env : null,
        mode: ProcessStartMode.normal,
      );
      // 启动期间已 dispose()：终止刚拉起的孤儿进程（dispose 的 kill
      // 发生在 _process 赋值之前，够不到这个新进程）。
      if (_state == _McpClientState.disposed) {
        _process?.kill();
        _process = null;
        return;
      }

      _stdoutSubscription = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleMessage, onError: _handleError);

      _stderrSubscription = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        debugPrint('MCP[${config.name}] stderr: $line');
      });

      _process!.exitCode.then((code) {
        // dispose() 后进程被 kill：不得把 disposed 状态覆盖回
        // disconnected（否则后续 connect() 会重新拉起已释放的客户端）。
        if (_state == _McpClientState.disposed) return;
        debugPrint('MCP[${config.name}] process exited with code $code');
        _state = _McpClientState.disconnected;
        for (final entry in _pendingRequests.entries) {
          if (!entry.value.isCompleted) {
            entry.value.completeError(
                Exception('MCP process exited unexpectedly with code $code'));
          }
        }
        _pendingRequests.clear();
      });
    } catch (e) {
      debugPrint('McpClient._connectStdio failed: $e');
      rethrow;
    }
  }

  /// CancelToken for SSE requests
  CancelToken? _cancelToken;

  /// Persistent SSE connection subscription (standard MCP SSE protocol)
  StreamSubscription<String>? _sseSubscription;

  /// Endpoint URL extracted from the SSE `event: endpoint` message
  String? _sseEndpointUrl;

  /// Completer that resolves when the SSE `event: endpoint` is received.
  /// Recreated on each connection attempt to support retry.
  Completer<void> _sseEndpointCompleter = Completer<void>();

  Future<void> _connectSse() async {
    if (config.url == null || config.url!.isEmpty) {
      throw ArgumentError('SSE URL is required');
    }

    // 重连时先拆除上一轮连接，否则旧 GET 订阅的 onDone/onError 回调会
    // 在新连接上误改共享状态（把健康的连接标记为断开），旧 _cancelToken
    // 也会误伤新的在途请求。
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _postStreamSubscription?.cancel();
    _postStreamSubscription = null;
    _cancelToken?.cancel();

    // Reset state for new connection attempt (supports retry)
    _sseEndpointUrl = null;
    _sseEndpointCompleter = Completer<void>();
    _mode = _RemoteMode.streamableHttp;
    _mcpSessionId = null;

    debugPrint(
        'MCP[${config.name}]: Connecting to ${config.url} (${config.transportType.name})');

    _cancelToken = CancelToken();

    // 现代远程 MCP 服务器（Exa/Tavily/Firecrawl/Jina/智谱等）已全部迁移到
    // streamable HTTP：仅接受 POST（GET 返回 405/406），响应从 POST 的
    // SSE 流中读取。先尝试 POST 传输；失败（405/超时/流无响应）再回退
    // legacy SSE GET（兼容用户自建的旧版 HTTP+SSE 服务器）。
    final streamableOk = await _tryConnectStreamableHttp();
    if (_state == _McpClientState.disposed) return;
    if (streamableOk) return;

    debugPrint(
        'MCP[${config.name}]: streamable HTTP failed, falling back to legacy SSE');
    await _connectLegacySse();
  }

  /// 尝试 streamable HTTP（POST）传输：连接即 initialize 请求/响应往返。
  /// 成功时返回 true 并设置 [_mode]；失败（服务器拒绝/超时/流无响应）
  /// 返回 false，由调用方决定回退 legacy SSE。
  Future<bool> _tryConnectStreamableHttp() async {
    final headers = _buildPostHeaders();
    final request = JsonRpcUtils.buildRequest('initialize', {
      'protocolVersion': '2024-11-05',
      'capabilities': {},
      'clientInfo': {
        'name': 'stroom',
        'version': '0.2.13',
      },
    });
    final msgId = JsonRpcUtils.extractRequestId(request);
    if (msgId == null) return false;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[msgId] = completer;

    // 探测用独立 CancelToken：回退 legacy SSE 前必须取消挂起的 POST，
    // 但不能动共享的 _cancelToken（legacy 连接还要用）。
    final probeToken = CancelToken();
    final parser = _SseResponseParser();

    try {
      final stream = _postLines(
        config.url!,
        headers,
        request,
        cancelToken: probeToken,
        onResponseHeaders: (h) {
          final session = h['mcp-session-id']?.firstOrNull;
          if (session != null && session.isNotEmpty) {
            _mcpSessionId = session;
          }
        },
      );
      _postStreamSubscription = stream.listen(
        (line) {
          parser.handleLine(line, _handleMessage);
          // 收到 initialize 响应（_handleMessage 已把该请求从 pending 移除）
          // 后关闭 POST 流——streamable HTTP 每次请求/响应独立成对。
          if (!_pendingRequests.containsKey(msgId)) {
            _postStreamSubscription?.cancel();
            _postStreamSubscription = null;
          }
        },
        onError: (Object error) {
          debugPrint('MCP[${config.name}]: streamable HTTP error: $error');
          if (!completer.isCompleted) {
            completer.completeError(
                Exception('streamable HTTP connection error: $error'));
          }
        },
        onDone: () {
          // 流结束：把尚未遇到空行的残余 data 行补发（某些服务器响应
          // 末尾没有空行分隔符）。
          parser.flush(_handleMessage);
          if (!completer.isCompleted) {
            completer.completeError(
                Exception('streamable HTTP stream closed before response'));
          }
        },
        cancelOnError: false,
      );

      await completer.future.timeout(const Duration(seconds: 15));
      if (_state == _McpClientState.disposed) return false;

      _mode = _RemoteMode.streamableHttp;
      debugPrint('MCP[${config.name}]: streamable HTTP transport connected');

      // notifications/initialized 通知（无 id，尽力而为，失败不阻断连接）
      try {
        await _sendStreamableMessage(
            JsonRpcUtils.buildNotification('notifications/initialized'));
      } catch (e) {
        debugPrint('MCP[${config.name}]: notifications/initialized failed: $e');
      }
      return true;
    } catch (e) {
      debugPrint('MCP[${config.name}]: streamable HTTP connect failed: $e');
      _pendingRequests.remove(msgId);
      await _postStreamSubscription?.cancel();
      _postStreamSubscription = null;
      probeToken.cancel();
      return false;
    }
  }

  /// legacy HTTP+SSE 传输：GET 建立持久连接，等待 `event: endpoint`，
  /// 随后用 endpoint URL POST 消息，响应经 GET 流回传。
  Future<void> _connectLegacySse() async {
    final headers = _buildGetHeaders();
    debugPrint(
        'MCP[${config.name}]: Establishing persistent SSE connection to ${config.url}');

    try {
      final stream = _sseConnectFn(
        config.url!,
        headers,
        cancelToken: _cancelToken,
      );

      String? currentEvent;

      _sseSubscription = stream.listen(
        (line) {
          if (line.startsWith('event: ')) {
            currentEvent = line.substring(7).trim();
          } else if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (currentEvent == 'endpoint') {
              // Standard MCP: server sends event: endpoint with URL to post messages
              _sseEndpointUrl = data.trim();
              debugPrint(
                  'MCP[${config.name}]: received endpoint URL: $_sseEndpointUrl');
              if (!_sseEndpointCompleter.isCompleted) {
                _sseEndpointCompleter.complete();
              }
            } else {
              // JSON-RPC response through the SSE stream
              _handleMessage(data);
            }
            currentEvent = null;
          } else if (line.isEmpty) {
            currentEvent = null;
          }
        },
        onError: (Object error) {
          debugPrint(
              'MCP[${config.name}]: legacy SSE connection error: $error');
          // dispose() 已取消 _cancelToken 触发本回调：保持 disposed 终态
          if (_state == _McpClientState.disposed) return;
          if (!_sseEndpointCompleter.isCompleted) {
            _sseEndpointCompleter.completeError(error);
          }
          _completePendingRequestsWithError(
              Exception('SSE connection error: $error'));
          _state = _McpClientState.disconnected;
        },
        onDone: () {
          debugPrint('MCP[${config.name}]: legacy SSE connection closed');
          // dispose() 取消订阅触发本回调：保持 disposed 终态
          if (_state == _McpClientState.disposed) return;
          if (!_sseEndpointCompleter.isCompleted) {
            _sseEndpointCompleter
                .completeError(Exception('SSE stream closed without endpoint'));
          }
          _completePendingRequestsWithError(
              Exception('SSE connection closed unexpectedly'));
          _state = _McpClientState.disconnected;
        },
        cancelOnError: false,
      );

      // Wait for the endpoint event with a 30-second timeout
      await _sseEndpointCompleter.future.timeout(const Duration(seconds: 30));
      // 等待期间可能已 dispose()（取消订阅后 endpoint completer 由
      // dispose 以错误完成，或 30s 超时）：不得把 disposed 覆盖回
      // connected——_connectInternal 的 disposed 检查兜底返回 false。
      if (_state == _McpClientState.disposed) return;
      _mode = _RemoteMode.legacySse;
      debugPrint(
          'MCP[${config.name}]: legacy SSE transport connected, endpoint: $_sseEndpointUrl');
      // 旧版协议：initialize 经 endpoint POST 发送，响应走 GET 流回传。
      await _sendInitialize();
    } catch (e) {
      debugPrint('MCP[${config.name}]: legacy SSE connect failed: $e');
      _sseSubscription?.cancel();
      _sseSubscription = null;
      _cancelToken?.cancel();
      _cancelToken = null;
      // dispose() 后的失败不得把 disposed 状态覆盖回 disconnected
      //（否则后续 connect() 会重新拉起一个已释放客户端的连接）。
      if (_state != _McpClientState.disposed) {
        _state = _McpClientState.disconnected;
      }
      rethrow;
    }
  }

  Future<void> _sendInitialize() async {
    await AppLogService.info('McpClient', '发送 initialize 请求: ${config.name}');
    final request = JsonRpcUtils.buildRequest('initialize', {
      'protocolVersion': '2024-11-05',
      'capabilities': {},
      'clientInfo': {
        'name': 'stroom',
        'version': '0.2.13',
      },
    });
    await _sendMessage(request);

    // 发送 notifications/initialized 通知（无 id，符合 MCP 规范）
    final notification =
        JsonRpcUtils.buildNotification('notifications/initialized');
    await _sendMessage(notification);
    await AppLogService.info('McpClient', 'initialize 完成: ${config.name}');
  }

  Future<void> _sendMessage(String message) async {
    if (_state == _McpClientState.disposed) return;

    switch (config.transportType) {
      case McpTransportType.stdio:
        _process?.stdin.writeln(message);
        break;
      case McpTransportType.sse:
        if (_mode == _RemoteMode.streamableHttp) {
          await _sendStreamableMessage(message);
        } else {
          await _sendSseRequest(message);
        }
        break;
    }
  }

  /// streamable HTTP：POST 一条 JSON-RPC 消息，从该 POST 自身的响应流中
  /// 读取响应并路由到挂起的 completer（见 [_handleMessage]）。
  ///
  /// 解析器每次调用独立实例：聊天服务会并发执行同一服务器的多个工具
  /// 调用（Future.wait），共享解析状态会把不同请求的响应 data 行拼坏。
  Future<void> _sendStreamableMessage(String message) async {
    if (_state == _McpClientState.disposed) return;

    final msgId = JsonRpcUtils.extractRequestId(message);
    final headers = _buildPostHeaders();
    final parser = _SseResponseParser();

    try {
      final stream = _postLines(
        config.url!,
        headers,
        message,
        cancelToken: _cancelToken,
        onResponseHeaders: (h) {
          final session = h['mcp-session-id']?.firstOrNull;
          if (session != null && session.isNotEmpty) {
            _mcpSessionId = session;
          }
        },
      );
      // 通知（无 id）无响应可读：短超时兜底，避免服务器保持连接时
      // connect/调用被挂住；请求则等待完整响应。
      final streamWithTimeout = msgId == null
          ? stream.timeout(const Duration(seconds: 5))
          : stream.timeout(const Duration(seconds: 30));
      await for (final line in streamWithTimeout) {
        parser.handleLine(line, _handleMessage);
        // 本请求的响应已收到（_handleMessage 已把该请求从 pending 移除）：
        // 关闭 POST 流，避免悬挂连接。
        if (msgId != null && !_pendingRequests.containsKey(msgId)) break;
      }
      // 流结束：把残余 data 行补发（响应末尾无空行分隔符时）。
      parser.flush(_handleMessage);
      // 流正常结束但请求响应未收到（服务器空体/提前关闭）：补完 pending，
      // 避免 completer 永久残留在 _pendingRequests，并标记断开以便重连。
      if (msgId != null) {
        final completer = _pendingRequests.remove(msgId);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
              Exception('stream closed before response received'));
          if (_state != _McpClientState.disposed) {
            _state = _McpClientState.disconnected;
          }
        }
      }
    } catch (e) {
      debugPrint('MCP[${config.name}]: streamable HTTP request failed: $e');
      if (msgId != null) {
        final completer = _pendingRequests.remove(msgId);
        if (completer != null && !completer.isCompleted) {
          completer
              .completeError(Exception('streamable HTTP request failed: $e'));
        }
      }
      // 传输层失败（超时/流错误/连接断开）且非通知：标记断开，下次调用
      // 会重连。通知失败不阻断已建立的连接。
      if (msgId != null && _state != _McpClientState.disposed) {
        _state = _McpClientState.disconnected;
      }
    }
  }

  /// legacy HTTP+SSE：向 endpoint URL POST 一条 JSON-RPC 消息。
  /// 响应经持久 GET 连接回传，由 [_handleMessage] 路由到挂起的 completer。
  Future<void> _sendSseRequest(String message) async {
    if (_sseEndpointUrl == null || _sseEndpointUrl!.isEmpty) {
      debugPrint('MCP[${config.name}]: SSE endpoint URL not available');
      return;
    }

    final msgId = JsonRpcUtils.extractRequestId(message);
    final headers = _buildPostHeaders();

    // Resolve relative endpoint URL against the SSE URL base
    final endpointUrl = _resolveEndpointUrl(_sseEndpointUrl!);

    try {
      await _ssePostFn(
        endpointUrl,
        headers,
        message,
        cancelToken: _cancelToken,
      );
      // Response will arrive through the persistent SSE connection
      // and be handled by _handleMessage in the _sseSubscription listener.
    } catch (e) {
      debugPrint('MCP[${config.name}]: POST to endpoint failed: $e');
      if (msgId != null) {
        final completer = _pendingRequests.remove(msgId);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(Exception('SSE POST request failed: $e'));
        }
      }
      // 传输层失败：标记断开，下次调用会重连。
      if (_state != _McpClientState.disposed) {
        _state = _McpClientState.disconnected;
      }
    }
  }

  /// Resolve a possibly-relative endpoint URL against the SSE base URL.
  String _resolveEndpointUrl(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      // Absolute URL
      return endpoint;
    }
    // Relative URL: resolve against the SSE URL base
    final uri = Uri.tryParse(config.url ?? '');
    if (uri == null) return endpoint;
    final resolved = uri.resolve(endpoint);
    return resolved.toString();
  }

  void _handleMessage(String line) {
    final msg = JsonRpcUtils.parseResponse(line);
    if (msg == null) return;

    if (msg.id != null && _pendingRequests.containsKey(msg.id)) {
      final completer = _pendingRequests.remove(msg.id);
      // isCompleted 守卫：同 id 的响应可能经不同路径（流解析 vs
      // onError/onDone 兜底）重复到达，二次 complete 会抛 StateError。
      if (completer != null && !completer.isCompleted) {
        if (msg.error != null) {
          completer.completeError(
              Exception('MCP error: ${msg.error!['message'] ?? msg.error}'));
        } else {
          completer.complete(msg.result ?? {});
        }
      }
    }
  }

  void _handleError(Object error) {
    debugPrint('MCP[${config.name}] stream error: $error');
  }

  /// 列出 MCP 服务器上所有可用的工具
  Future<List<McpTool>> listTools() async {
    await AppLogService.info('McpClient', '列出 MCP 工具: ${config.name}');
    if (_state != _McpClientState.connected) {
      final connected = await connect();
      if (!connected) return [];
    }

    try {
      final result = await _sendRequest('tools/list');
      _cachedTools = JsonRpcUtils.extractTools(result);
      await AppLogService.info('McpClient',
          'MCP 工具列表获取完成: ${config.name}, 共 ${_cachedTools.length} 个工具');
      return List.from(_cachedTools);
    } catch (e) {
      debugPrint('McpClient.listTools failed: $e');
      await AppLogService.error('McpClient', '列出 MCP 工具失败: ${config.name}', e);
      return [];
    }
  }

  /// 调用 MCP 服务器上的工具
  Future<String> callTool(String name, Map<String, dynamic> arguments) async {
    await AppLogService.info('McpClient', '调用 MCP 工具: $name (${config.name})');
    if (_state != _McpClientState.connected) {
      final connected = await connect();
      if (!connected) {
        return 'Error: MCP server "${config.name}" is not connected';
      }
    }

    try {
      final result = await _sendRequest('tools/call', {
        'name': name,
        'arguments': arguments,
      });
      final response = JsonRpcUtils.extractCallResult(result);
      if (response == null) return 'Error: No response from MCP tool "$name"';
      if (response.isError) return 'Error: ${response.text}';
      await AppLogService.info('McpClient', 'MCP 工具调用完成: $name');
      return response.text;
    } catch (e) {
      debugPrint('McpClient.callTool failed: $e');
      await AppLogService.error('McpClient', '调用 MCP 工具失败: $name', e);
      return 'Error: ${e.toString()}';
    }
  }

  Future<Map<String, dynamic>> _sendRequest(String method,
      [Map<String, dynamic>? params]) async {
    final request = McpMessage.request(method, params);
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[request.id!] = completer;

    await _sendMessage(request.toJsonString());

    return await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        // 超时：清除 pending，避免 completer 永久残留（下次同名请求/
        // 断线清理会重复 complete）。仅远程传输标记断开以便重连——stdio
        // 进程的断开由进程退出回调负责，此处不改变其语义。
        _pendingRequests.remove(request.id);
        if (config.transportType == McpTransportType.sse &&
            _state != _McpClientState.disposed) {
          _state = _McpClientState.disconnected;
        }
        throw TimeoutException('MCP request timed out: $method');
      },
    );
  }

  /// Complete all pending requests with an error (e.g., on connection drop).
  void _completePendingRequestsWithError(Exception error) {
    for (final entry in _pendingRequests.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(error);
      }
    }
    _pendingRequests.clear();
  }

  /// 释放资源
  void dispose() {
    AppLogService.info('McpClient', '释放 MCP 客户端: ${config.name}');
    if (_state == _McpClientState.disposed) return;
    _state = _McpClientState.disposed;

    _stdoutSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription?.cancel();
    _stderrSubscription = null;

    // Cancel SSE subscription and in-flight requests
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _postStreamSubscription?.cancel();
    _postStreamSubscription = null;
    _cancelToken?.cancel();
    _cancelToken = null;

    // 让正在等待 endpoint 事件的 connect() 快速失败（取消订阅不会触发
    // onDone，不完成此 completer 会让 connect 空等 30s 超时）。
    // 用值完成而非 completeError：无监听者时 completeError 会产生
    // 未处理异步错误；_connectSse 的 await 之后有 disposed 状态检查，
    // 值完成同样会让 connect 立即走 disposed 短路返回。
    if (!_sseEndpointCompleter.isCompleted) {
      _sseEndpointCompleter.complete();
    }

    // 完成所有挂起的请求（带错误）
    _completePendingRequestsWithError(Exception('Client disposed'));

    _process?.kill();
    _process = null;
    _cachedTools = [];
    AppLogService.info('McpClient', 'MCP 客户端已释放: ${config.name}');
  }
}

// ============================================================================
// MCP 客户端管理器 — 管理多个 MCP 客户端
// ============================================================================

/// 管理多个 MCP 客户端实例
class McpClientManager {
  final Map<String, McpClient> _clients = {};

  /// 所有客户端
  Map<String, McpClient> get clients => Map.unmodifiable(_clients);

  /// 获取指定 ID 的客户端
  McpClient? getClient(String id) => _clients[id];

  /// 添加一个客户端
  void addClient(String id, McpClient client) {
    // 如果已存在相同 ID 的客户端，先释放旧的
    final existing = _clients[id];
    if (existing != null) {
      existing.dispose();
    }
    _clients[id] = client;
  }

  /// 移除并释放指定 ID 的客户端
  void removeClient(String id) {
    final client = _clients.remove(id);
    client?.dispose();
  }

  /// 释放所有客户端
  void disposeAll() {
    for (final client in _clients.values) {
      client.dispose();
    }
    _clients.clear();
  }
}
