import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mcp.dart';
import '../models/tts_models.dart';
import 'http_tool_service.dart';
import 'mcp_client.dart';
import 'todo_tool_service.dart';
import 'web_search_service.dart';

class ConnectivityTestResult {
  final bool succeeded;
  final String summary;
  final String details;
  final Duration elapsed;

  const ConnectivityTestResult({
    required this.succeeded,
    required this.summary,
    required this.details,
    required this.elapsed,
  });
}

/// Runs safe, user-configurable connectivity probes for the MCP tools page.
class ConnectivityTestService {
  static const _builtinPreferencePrefix = 'mcp_connectivity_test_';

  static final _jsonEncoder = const JsonEncoder.withIndent('  ');

  static String defaultMcpTestContent() => _jsonEncoder.convert({
        'method': 'tools/list',
        'params': <String, dynamic>{},
      });

  static String defaultSearchTestContent() => _jsonEncoder.convert({
        'query': 'Stroom 连通性测试',
        'count': 1,
      });

  static String defaultBuiltinTestContent(String toolName) {
    if (toolName == 'todowrite') return '{}';
    return _jsonEncoder.convert({
      'query': 'Stroom 连通性测试',
      'source': 'google',
      'count': 1,
    });
  }

  static String configuredTestContent(
    ProviderConfigItem config, {
    required bool isHttpTool,
  }) {
    final typeConfig = config.models.isNotEmpty
        ? config.models[0].typeConfig
        : config.typeConfig;
    final raw = typeConfig['connectivityTest'];
    if (raw is Map) {
      return _jsonEncoder.convert(Map<String, dynamic>.from(raw));
    }
    return isHttpTool ? defaultSearchTestContent() : defaultMcpTestContent();
  }

  static Future<String> loadBuiltinTestContent(String toolName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_builtinPreferencePrefix$toolName') ??
        defaultBuiltinTestContent(toolName);
  }

  static Future<void> saveBuiltinTestContent(
    String toolName,
    Map<String, dynamic> content,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      '$_builtinPreferencePrefix$toolName',
      _jsonEncoder.convert(content),
    );
    if (!saved) {
      throw StateError('无法保存内置工具的连通性测试内容。');
    }
  }

  static Map<String, dynamic> decodeTestContent(String rawContent) {
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map) {
      throw const FormatException('测试内容顶层必须是 JSON 对象');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Future<ConnectivityTestResult> runProviderTest({
    required ProviderConfigItem config,
    required String testContent,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final content = decodeTestContent(testContent);
      final typeConfig = config.models.isNotEmpty
          ? config.models[0].typeConfig
          : config.typeConfig;

      if (typeConfig['isHttpTool'] == true) {
        final toolName = config.models.isNotEmpty
            ? config.models[0].name
            : config.providerName;
        final result = await HttpToolService.runConnectivityTest(
          providerName: toolName,
          arguments: content,
          apiKey: HttpToolService.extractHttpToolApiKey(
            toolName,
            typeConfig,
          ),
          url: typeConfig['url'] as String? ?? config.host,
        );
        final succeeded = !result.startsWith('错误:');
        return _finish(
          stopwatch,
          succeeded,
          succeeded ? 'HTTP 工具请求成功' : 'HTTP 工具请求失败',
          result,
        );
      }

      final serverConfig = McpServerConfig.fromProviderConfig(
        providerName: config.providerName,
        typeConfig: typeConfig,
      );
      if (serverConfig == null) {
        return _finish(
          stopwatch,
          false,
          'MCP 配置无效',
          '缺少有效的传输类型配置。',
        );
      }
      final isMobile = defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      if (serverConfig.transportType == McpTransportType.stdio &&
          (kIsWeb || isMobile)) {
        return _finish(
          stopwatch,
          false,
          '当前平台不支持 stdio',
          'stdio MCP 需要启动本地进程，请在桌面版 Stroom 中测试。',
        );
      }

      final rawMethod = content['method'];
      if (rawMethod != null && rawMethod is! String) {
        return _finish(
          stopwatch,
          false,
          '测试内容无效',
          'method 必须是字符串。',
        );
      }
      final method = rawMethod as String? ?? 'tools/list';
      if (method != 'tools/list') {
        return _finish(
          stopwatch,
          false,
          '不支持的测试方法',
          '为避免测试写入远程业务数据，MCP 连通性测试只允许只读的 tools/list 方法。',
        );
      }
      final rawParams = content['params'];
      if (rawParams != null && rawParams is! Map) {
        return _finish(
          stopwatch,
          false,
          '测试内容无效',
          'params 必须是 JSON 对象。',
        );
      }

      final client = McpClient(config: serverConfig);
      try {
        final connected = await client.connect().timeout(
          const Duration(seconds: 60),
        );
        if (!connected) {
          return _finish(
            stopwatch,
            false,
            '无法连接 MCP 服务',
            '请检查地址、认证信息、网络，或查看应用日志获取连接详情。',
          );
        }
        final tools = await client.discoverTools(
          params: rawParams == null
              ? const <String, dynamic>{}
              : Map<String, dynamic>.from(rawParams as Map),
        ).timeout(const Duration(seconds: 35));
        final names = tools.map((tool) => tool.name).take(12).join(', ');
        final suffix = tools.length > 12 ? '，其余工具已省略' : '';
        return _finish(
          stopwatch,
          true,
          'MCP 连通性测试成功',
          '连接及 tools/list 请求成功，共发现 ${tools.length} 个工具'
              '${names.isEmpty ? '' : '：$names'}$suffix',
        );
      } finally {
        client.dispose();
      }
    } catch (error) {
      return _finish(
        stopwatch,
        false,
        '连通性测试失败',
        _readableError(error),
      );
    }
  }

  static Future<ConnectivityTestResult> runBuiltinTest({
    required String toolName,
    required String testContent,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final arguments = decodeTestContent(testContent);
      late final String result;
      switch (toolName) {
        case 'todowrite':
          if (arguments['todos'] != null) {
            return _finish(
              stopwatch,
              false,
              '测试参数会修改待办数据',
              '为保护当前会话待办列表，连通性测试只允许省略 todos 或设置为 null。',
            );
          }
          result = await TodoToolService.handleTodo(arguments);
          break;
        case 'web_search':
          result = await WebSearchService.handleWebSearch(arguments);
          break;
        default:
          return _finish(
            stopwatch,
            false,
            '未知的内置工具',
            '找不到工具 "$toolName" 的测试执行器。',
          );
      }

      final succeeded = !result.startsWith('错误:');
      return _finish(
        stopwatch,
        succeeded,
        succeeded ? '内置工具测试成功' : '内置工具测试失败',
        result,
      );
    } catch (error) {
      return _finish(
        stopwatch,
        false,
        '内置工具测试失败',
        _readableError(error),
      );
    }
  }

  static ConnectivityTestResult _finish(
    Stopwatch stopwatch,
    bool succeeded,
    String summary,
    String details,
  ) {
    stopwatch.stop();
    const maxDetailsLength = 4000;
    final visibleDetails = details.length <= maxDetailsLength
        ? details
        : '${details.substring(0, maxDetailsLength)}\n…（结果已截断）';
    return ConnectivityTestResult(
      succeeded: succeeded,
      summary: summary,
      details: visibleDetails,
      elapsed: stopwatch.elapsed,
    );
  }

  static String _readableError(Object error) {
    if (error is FormatException) return error.message;
    if (error is TimeoutException) return '请求超时，请检查服务响应和网络。';
    return error.toString();
  }
}
