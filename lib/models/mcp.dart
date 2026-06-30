import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/tool_call.dart';

// ============================================================================
// MCP (Model Context Protocol) 数据模型
// ============================================================================
//
// 参考: https://spec.modelcontextprotocol.io/
// 当前实现支持核心功能：
//   - 工具发现 (tools/list)
//   - 工具调用 (tools/call)
//   - 支持 stdio（本地进程）和 SSE（远程服务器）两种传输方式

// ============================================================================
// JSON-RPC 消息（MCP 基础协议）
// ============================================================================

/// MCP 协议使用的 JSON-RPC 消息
class McpMessage {
  final String jsonrpc;
  final String? id;
  final String? method;
  final Map<String, dynamic>? params;
  final Map<String, dynamic>? result;
  final Map<String, dynamic>? error;

  const McpMessage._({
    this.jsonrpc = '2.0',
    this.id,
    this.method,
    this.params,
    this.result,
    this.error,
  });

  /// 创建一个 JSON-RPC 请求
  factory McpMessage.request(String method, [Map<String, dynamic>? params]) {
    return McpMessage._(
      id: const Uuid().v4(),
      method: method,
      params: params,
    );
  }

  /// 创建一个 JSON-RPC 响应
  factory McpMessage.response({
    required String id,
    Map<String, dynamic>? result,
    Map<String, dynamic>? error,
  }) {
    return McpMessage._(
      id: id,
      result: result,
      error: error,
    );
  }

  /// 从 JSON Map 解析消息
  factory McpMessage.fromJson(Map<String, dynamic> json) {
    return McpMessage._(
      id: json['id'] as String?,
      method: json['method'] as String?,
      params: json['params'] as Map<String, dynamic>?,
      result: json['result'] as Map<String, dynamic>?,
      error: json['error'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'jsonrpc': jsonrpc,
    };
    if (id != null) map['id'] = id;
    if (method != null) map['method'] = method;
    if (params != null) map['params'] = params;
    if (result != null) map['result'] = result;
    if (error != null) map['error'] = error;
    return map;
  }

  String toJsonString() => jsonEncode(toJson());
}

// ============================================================================
// MCP 工具模型
// ============================================================================

/// MCP 服务器提供的工具定义
class McpTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const McpTool({
    required this.name,
    this.description = '',
    required this.inputSchema,
  });

  factory McpTool.fromMap(Map<String, dynamic> map) {
    return McpTool(
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      inputSchema: Map<String, dynamic>.from(
        map['inputSchema'] as Map? ?? {},
      ),
    );
  }

  /// 转换为 ChatService 可用的 ToolDefinition
  ToolDefinition toToolDefinition() {
    return ToolDefinition(
      name: name,
      description: description,
      parameters: inputSchema,
    );
  }
}

// ============================================================================
// MCP 工具调用响应
// ============================================================================

/// MCP 工具调用结果
class McpToolCallResponse {
  final List<Map<String, dynamic>> content;
  final bool isError;

  const McpToolCallResponse({
    this.content = const [],
    this.isError = false,
  });

  factory McpToolCallResponse.fromMap(Map<String, dynamic> map) {
    return McpToolCallResponse(
      content: (map['content'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      isError: map['isError'] as bool? ?? false,
    );
  }

  /// 将所有文本内容合并为单一字符串
  String get text {
    return content
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String? ?? '')
        .join('\n');
  }
}

// ============================================================================
// MCP 服务器传输类型
// ============================================================================

/// MCP 服务器传输方式
enum McpTransportType {
  /// 通过子进程的标准输入/输出通信（适用于本地 MCP 服务器）
  stdio('stdio'),

  /// 通过 HTTP SSE 通信（适用于远程 MCP 服务器）
  sse('sse');

  final String value;
  const McpTransportType(this.value);

  static McpTransportType fromValue(String? value) {
    return McpTransportType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => McpTransportType.sse,
    );
  }
}

// ============================================================================
// MCP 服务器配置
// ============================================================================

/// MCP 服务器配置，描述如何连接到 MCP 服务器
class McpServerConfig {
  /// 显示名称
  final String name;

  /// 传输方式
  final McpTransportType transportType;

  /// [stdio] 模式下：可执行命令（如 "npx", "node", "python"）
  final String? command;

  /// [stdio] 模式下：命令行参数
  final List<String>? args;

  /// [sse] 模式下：SSE 端点 URL
  final String? url;

  /// 环境变量
  final Map<String, String> env;

  /// 是否为内置供应商 MCP 服务器
  final bool isVendor;

  const McpServerConfig({
    required this.name,
    this.transportType = McpTransportType.stdio,
    this.command,
    this.args,
    this.url,
    this.env = const {},
    this.isVendor = false,
  });

  /// 创建 stdio 模式的配置
  factory McpServerConfig.stdio({
    required String name,
    required String command,
    List<String>? args,
    Map<String, String>? env,
    bool isVendor = false,
  }) {
    return McpServerConfig(
      name: name,
      transportType: McpTransportType.stdio,
      command: command,
      args: args,
      env: env ??
          <String, String>{
            // 确保 PATH 环境变量传递给子进程
            'PATH': _defaultPath(),
          },
      isVendor: isVendor,
    );
  }

  /// 创建 SSE 模式的配置
  factory McpServerConfig.sse({
    required String name,
    required String url,
    Map<String, String>? env,
    bool isVendor = false,
  }) {
    return McpServerConfig(
      name: name,
      transportType: McpTransportType.sse,
      url: url,
      env: env ?? const {},
      isVendor: isVendor,
    );
  }

  /// 创建供应商内置 MCP 配置
  factory McpServerConfig.vendor({
    required String name,
    required String command,
    List<String>? args,
    Map<String, String>? env,
  }) {
    return McpServerConfig.stdio(
      name: name,
      command: command,
      args: args,
      env: env,
      isVendor: true,
    );
  }

  /// 从 ProviderConfigItem 的 typeConfig 重建 McpServerConfig
  static McpServerConfig? fromProviderConfig({
    required String providerName,
    required Map<String, dynamic>? typeConfig,
  }) {
    if (typeConfig == null || typeConfig.isEmpty) return null;
    final transport = typeConfig['transport'] as String?;
    if (transport == null) return null;

    final transportType = McpTransportType.fromValue(transport);
    final argsRaw = typeConfig['args'];
    final args = argsRaw is List ? argsRaw.cast<String>() : <String>[];
    final envRaw = typeConfig['env'];
    final env = envRaw is Map
        ? (envRaw as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
        : <String, String>{};
    final isVendor = typeConfig['isVendor'] as bool? ?? false;

    switch (transportType) {
      case McpTransportType.stdio:
        return McpServerConfig.stdio(
          name: providerName,
          command: typeConfig['command'] as String? ?? '',
          args: args,
          env: env,
          isVendor: isVendor,
        );
      case McpTransportType.sse:
        return McpServerConfig.sse(
          name: providerName,
          url: typeConfig['url'] as String? ?? '',
          env: env,
          isVendor: isVendor,
        );
    }
  }

  /// 序列化到 Map（用于存储到 ProviderConfigItem.typeConfig）
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'transport': transportType.value,
    };
    if (name.isNotEmpty) map['name'] = name;
    if (transportType == McpTransportType.stdio) {
      if (command != null) map['command'] = command;
      if (args != null && args!.isNotEmpty) map['args'] = args;
    } else {
      if (url != null) map['url'] = url;
    }
    if (env.isNotEmpty) map['env'] = env;
    if (isVendor) map['isVendor'] = true;
    return map;
  }

  /// 从 Map 反序列化
  static McpServerConfig? fromMap(Map<String, dynamic> map) {
    final transport = map['transport'] as String?;
    if (transport == null) return null;

    final transportType = McpTransportType.fromValue(transport);
    final name = map['name'] as String? ?? '';
    final argsRaw = map['args'];
    final args = argsRaw is List ? argsRaw.cast<String>() : <String>[];
    final envRaw = map['env'];
    final env = envRaw is Map
        ? (envRaw as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
        : <String, String>{};
    final isVendor = map['isVendor'] as bool? ?? false;

    switch (transportType) {
      case McpTransportType.stdio:
        return McpServerConfig.stdio(
          name: name,
          command: map['command'] as String? ?? '',
          args: args,
          env: env,
          isVendor: isVendor,
        );
      case McpTransportType.sse:
        return McpServerConfig.sse(
          name: name,
          url: map['url'] as String? ?? '',
          env: env,
          isVendor: isVendor,
        );
    }
  }

  static String _defaultPath() {
    // 默认 PATH（在桌面平台上通常会被系统环境变量覆盖）
    return '/usr/local/bin:/usr/bin:/bin';
  }
}
