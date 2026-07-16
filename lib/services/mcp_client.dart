import 'dart:async';
import 'dart:convert';
import 'dart:io' show Process, ProcessStartMode;

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../models/mcp.dart';
import 'sse_client.dart';
import 'app_log_service.dart';

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
/// ## 跨平台兼容性
/// | 传输方式 | iOS | Android | Linux | Windows | macOS | Web |
/// |----------|-----|---------|-------|---------|-------|-----|
/// | stdio    | ❌  | ❌      | ✅    | ✅      | ✅    | ❌  |
/// | sse      | ✅  | ✅      | ✅    | ✅      | ✅    | ✅  |
///
/// - **stdio**: 仅桌面端可用（需要 `dart:io` Process 启动子进程）
/// - **sse**: 全端可用（使用 HTTP POST + SSE 响应，支持所有平台的条件导出 SSE 客户端）
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

  McpClient({required this.config}) {
    _validateConfig();
  }

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

  /// 是否已连接
  bool get isConnected => _state == _McpClientState.connected;

  /// 是否已释放
  bool get isDisposed => _state == _McpClientState.disposed;

  /// 是否曾连接过（避免重复调用 connect）
  bool get hasConnectedBefore =>
      _state == _McpClientState.connected ||
      _state == _McpClientState.disconnected; // 曾经连接过但已断开

  /// 获取缓存的工具列表
  List<McpTool> get cachedTools => List.unmodifiable(_cachedTools);

  /// 连接到 MCP 服务器
  Future<bool> connect() async {
    await AppLogService.info('McpClient',
        '连接 MCP 服务器: ${config.name} (${config.transportType.name})');
    if (_state == _McpClientState.disposed) return false;
    if (_state == _McpClientState.connected) return true;

    _state = _McpClientState.connecting;

    try {
      switch (config.transportType) {
        case McpTransportType.stdio:
          await _connectStdio();
        case McpTransportType.sse:
          await _connectSse();
      }

      // 发送 initialize 请求
      await _sendInitialize();
      _state = _McpClientState.connected;
      await AppLogService.info('McpClient', 'MCP 服务器连接成功: ${config.name}');
      return true;
    } catch (e) {
      debugPrint('McpClient.connect failed for ${config.name}: $e');
      _state = _McpClientState.disconnected;
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

    // Reset state for new connection attempt (supports retry)
    _sseEndpointUrl = null;
    _sseEndpointCompleter = Completer<void>();

    debugPrint(
        'MCP[${config.name}]: Establishing persistent SSE connection to ${config.url}');

    _cancelToken = CancelToken();

    // Build headers for the SSE GET connection
    final headers = <String, String>{
      ...config.headers,
    };
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      headers.putIfAbsent('x-api-key', () => config.apiKey!);
    }

    try {
      final stream = sseConnect(
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
          debugPrint('MCP[${config.name}]: SSE connection error: $error');
          if (!_sseEndpointCompleter.isCompleted) {
            _sseEndpointCompleter.completeError(error);
          }
          _completePendingRequestsWithError(
              Exception('SSE connection error: $error'));
          _state = _McpClientState.disconnected;
        },
        onDone: () {
          debugPrint('MCP[${config.name}]: SSE connection closed');
          _completePendingRequestsWithError(
              Exception('SSE connection closed unexpectedly'));
          _state = _McpClientState.disconnected;
        },
        cancelOnError: false,
      );

      // Wait for the endpoint event with a 30-second timeout
      await _sseEndpointCompleter.future.timeout(const Duration(seconds: 30));
      _state = _McpClientState.connected;
      debugPrint(
          'MCP[${config.name}]: SSE transport connected, endpoint: $_sseEndpointUrl');
    } catch (e) {
      debugPrint('MCP[${config.name}]: SSE connect failed: $e');
      _sseSubscription?.cancel();
      _sseSubscription = null;
      _cancelToken?.cancel();
      _cancelToken = null;
      _state = _McpClientState.disconnected;
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

    // 发送 notifications/initialized 通知
    final notification = JsonRpcUtils.buildRequest('notifications/initialized');
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
        await _sendSseRequest(message);
        break;
    }
  }

  /// Send a JSON-RPC message via HTTP POST to the MCP endpoint URL.
  /// The response is received through the persistent SSE connection
  /// and routed to the pending request's completer by [listTools]/[callTool].
  Future<void> _sendSseRequest(String message) async {
    if (_sseEndpointUrl == null || _sseEndpointUrl!.isEmpty) {
      debugPrint('MCP[${config.name}]: SSE endpoint URL not available');
      // Fallback: try direct POST to the SSE URL (legacy compatibility)
      await _sendSseRequestLegacy(message);
      return;
    }

    final msgId = JsonRpcUtils.extractRequestId(message);

    // Build HTTP headers for the JSON-RPC POST request
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...config.headers,
    };

    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      headers.putIfAbsent('x-api-key', () => config.apiKey!);
    }

    // Resolve relative endpoint URL against the SSE URL base
    final endpointUrl = _resolveEndpointUrl(_sseEndpointUrl!);

    try {
      await ssePost(
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
    }
  }

  /// Legacy fallback: send POST directly to SSE URL (for servers that support it).
  Future<void> _sendSseRequestLegacy(String message) async {
    if (config.url == null || config.url!.isEmpty) {
      debugPrint('MCP[${config.name}]: SSE URL is empty');
      return;
    }

    final msgId = JsonRpcUtils.extractRequestId(message);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...config.headers,
    };

    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      headers.putIfAbsent('x-api-key', () => config.apiKey!);
    }

    final cancelToken = CancelToken();

    try {
      final stream = sseStream(
        config.url!,
        headers,
        message,
        cancelToken: cancelToken,
      ).timeout(const Duration(seconds: 30));

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          _handleMessage(data);
          if (msgId != null) {
            final completer = _pendingRequests[msgId];
            if (completer == null || completer.isCompleted) {
              break;
            }
          }
        }
      }
    } on TimeoutException {
      debugPrint('MCP[${config.name}]: Legacy SSE request timed out');
      if (msgId != null) {
        final completer = _pendingRequests.remove(msgId);
        if (completer != null && !completer.isCompleted) {
          completer
              .completeError(TimeoutException('MCP SSE request timed out'));
        }
      }
    } catch (e) {
      debugPrint('MCP[${config.name}]: Legacy SSE request failed: $e');
      if (msgId != null) {
        final completer = _pendingRequests.remove(msgId);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(Exception('SSE request failed: $e'));
        }
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
      if (msg.error != null) {
        completer!.completeError(
            Exception('MCP error: ${msg.error!['message'] ?? msg.error}'));
      } else {
        completer!.complete(msg.result ?? {});
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

    return await completer.future.timeout(const Duration(seconds: 30));
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
    _cancelToken?.cancel();
    _cancelToken = null;

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
