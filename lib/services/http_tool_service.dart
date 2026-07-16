import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'app_log_service.dart';

import '../models/tool_call.dart';

// ============================================================================
// HTTP 工具服务层
//
// 为纯 Dart 工具（Brave Search、Searxng、Bocha、Querit）提供 HTTP API 调用能力。
// 这些工具没有官方的 Remote MCP 服务，底层是直接调 HTTP API。
// 全端可用（iOS / Android / Linux / Windows / macOS / Web）。
// ============================================================================

/// HTTP 工具的服务层，管理 API Key 并提供工具处理函数
class HttpToolService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // API Keys - updated from provider config
  static String _braveApiKey = '';
  static String _searxngUrl = 'http://localhost:8080';
  static String _searxngApiKey = '';
  static String _bochaApiKey = '';
  static String _queritApiKey = '';

  /// Update API keys from provider config
  static void updateApiKeys({
    String? braveApiKey,
    String? searxngUrl,
    String? searxngApiKey,
    String? bochaApiKey,
    String? queritApiKey,
  }) {
    if (braveApiKey != null) _braveApiKey = braveApiKey;
    if (searxngUrl != null) _searxngUrl = searxngUrl;
    if (searxngApiKey != null) _searxngApiKey = searxngApiKey;
    if (bochaApiKey != null) _bochaApiKey = bochaApiKey;
    if (queritApiKey != null) _queritApiKey = queritApiKey;
  }

  // ======================================================================
  // Tool definitions — 注册为 ChatService 的 built-in tool
  // ======================================================================

  static final List<ToolDefinition> toolDefinitions = [
    ToolDefinition(
      name: 'brave_web_search',
      description: '使用 Brave Search API 进行网络搜索（需要配置 API Key）',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '搜索关键词',
          },
          'count': {
            'type': 'integer',
            'description': '返回结果数量（最大 20）',
            'default': 10,
          },
        },
        'required': ['query'],
      },
    ),
    ToolDefinition(
      name: 'bocha_web_search',
      description: '使用博查 AI Search API 进行网络搜索（需要配置 API Key）',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '搜索关键词',
          },
          'count': {
            'type': 'integer',
            'description': '返回结果数量',
            'default': 10,
          },
        },
        'required': ['query'],
      },
    ),
    ToolDefinition(
      name: 'querit_search',
      description: '使用 Querit Search API 进行网络搜索（需要配置 API Key）',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '搜索关键词',
          },
          'count': {
            'type': 'integer',
            'description': '返回结果数量',
            'default': 10,
          },
        },
        'required': ['query'],
      },
    ),
    ToolDefinition(
      name: 'searxng_search',
      description: '使用 SearXNG 实例进行隐私友好的网络搜索（需要配置 SearXNG URL）',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '搜索关键词',
          },
          'count': {
            'type': 'integer',
            'description': '返回结果数量',
            'default': 10,
          },
        },
        'required': ['query'],
      },
    ),
    // Fetch tool — already available as webfetch, just documenting here
  ];

  // ======================================================================
  // Tool handlers
  // ======================================================================

  /// Brave Search handler (async)
  static Future<String> handleBraveSearch(Map<String, dynamic> args) async {
    final query = (args['query'] as String?) ?? '';
    final count = (args['count'] as num?)?.toInt() ?? 10;
    await AppLogService.info(
        'HttpToolService', 'Brave 搜索: query=$query, count=$count');

    if (_braveApiKey.isEmpty) {
      return '错误: Brave Search API Key 未配置，请在设置页面配置。';
    }
    if (query.isEmpty) return '错误: 搜索关键词不能为空。';

    try {
      final response = await _dio.get(
        'https://api.search.brave.com/res/v1/web/search',
        queryParameters: {
          'q': query,
          'count': count.clamp(1, 20),
        },
        options: Options(
          headers: {
            'X-Subscription-Token': _braveApiKey,
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _extractBraveResults(data);
      }
      return '错误: Brave Search 请求失败 (HTTP ${response.statusCode})';
    } catch (e) {
      debugPrint('Brave Search error: $e');
      await AppLogService.error('HttpToolService', 'Brave 搜索失败: $query', e);
      return '错误: Brave Search 请求失败: $e';
    }
  }

  /// Bocha Search handler (async)
  static Future<String> handleBochaSearch(Map<String, dynamic> args) async {
    final query = (args['query'] as String?) ?? '';
    final count = (args['count'] as num?)?.toInt() ?? 10;
    await AppLogService.info(
        'HttpToolService', 'Bocha 搜索: query=$query, count=$count');

    if (_bochaApiKey.isEmpty) {
      return '错误: Bocha API Key 未配置，请在设置页面配置。';
    }
    if (query.isEmpty) return '错误: 搜索关键词不能为空。';

    try {
      final response = await _dio.post(
        'https://api.bochaai.com/v1/web-search',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_bochaApiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'query': query,
          'count': count,
          'summary': true,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _extractBochaResults(data);
      }
      return '错误: Bocha 请求失败 (HTTP ${response.statusCode})';
    } catch (e) {
      debugPrint('Bocha search error: $e');
      await AppLogService.error('HttpToolService', 'Bocha 搜索失败: $query', e);
      return '错误: Bocha 请求失败: $e';
    }
  }

  /// Querit Search handler (async)
  static Future<String> handleQueritSearch(Map<String, dynamic> args) async {
    final query = (args['query'] as String?) ?? '';
    final count = (args['count'] as num?)?.toInt() ?? 10;
    await AppLogService.info(
        'HttpToolService', 'Querit 搜索: query=$query, count=$count');

    if (_queritApiKey.isEmpty) {
      return '错误: Querit API Key 未配置，请在设置页面配置。';
    }
    if (query.isEmpty) return '错误: 搜索关键词不能为空。';

    try {
      final response = await _dio.post(
        'https://api.querit.ai/v1/search',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_queritApiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'query': query,
          'count': count,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _extractQueritResults(data);
      }
      return '错误: Querit 请求失败 (HTTP ${response.statusCode})';
    } catch (e) {
      debugPrint('Querit search error: $e');
      await AppLogService.error('HttpToolService', 'Querit 搜索失败: $query', e);
      return '错误: Querit 请求失败: $e';
    }
  }

  /// SearXNG Search handler (async)
  static Future<String> handleSearxngSearch(Map<String, dynamic> args) async {
    final query = (args['query'] as String?) ?? '';
    final count = (args['count'] as num?)?.toInt() ?? 10;
    await AppLogService.info(
        'HttpToolService', 'SearXNG 搜索: query=$query, count=$count');

    if (_searxngUrl.isEmpty || _searxngUrl == 'http://localhost:8080') {
      return '错误: SearXNG 实例 URL 未配置，请在设置页面配置。';
    }
    if (query.isEmpty) return '错误: 搜索关键词不能为空。';

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (_searxngApiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_searxngApiKey';
      }

      final response = await _dio.get(
        '${_searxngUrl.replaceAll(RegExp(r'/+$'), '')}/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': count.clamp(1, 50),
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _extractSearxngResults(data);
      }
      return '错误: SearXNG 请求失败 (HTTP ${response.statusCode})';
    } catch (e) {
      debugPrint('Searxng search error: $e');
      await AppLogService.error('HttpToolService', 'SearXNG 搜索失败: $query', e);
      return '错误: SearXNG 请求失败: $e';
    }
  }

  // ======================================================================
  // Result extractors
  // ======================================================================

  static String _extractBraveResults(Map<String, dynamic> data) {
    final results = <String>[];
    final web = data['web'] as Map<String, dynamic>?;
    if (web != null) {
      final items = web['results'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          final title = item['title'] as String? ?? '';
          final url = item['url'] as String? ?? '';
          final desc = item['description'] as String? ?? '';
          results.add('标题: $title\n链接: $url\n摘要: $desc\n');
        }
      }
    }
    if (results.isEmpty) return '未找到相关结果。';
    return results.join('\n---\n');
  }

  static String _extractBochaResults(Map<String, dynamic> data) {
    // Bocha API returns: { "data": { "webPages": { "value": [...] } } }
    final results = <String>[];
    final dataObj = data['data'] as Map<String, dynamic>?;
    if (dataObj != null) {
      final webPages = dataObj['webPages'] as Map<String, dynamic>?;
      if (webPages != null) {
        final items = webPages['value'] as List<dynamic>?;
        if (items != null) {
          for (final item in items) {
            final name = item['name'] as String? ?? '';
            final url = item['url'] as String? ?? '';
            final snippet = item['snippet'] as String? ?? '';
            results.add('标题: $name\n链接: $url\n摘要: $snippet\n');
          }
        }
      }
    }
    if (results.isEmpty) return '未找到相关结果。';
    return results.join('\n---\n');
  }

  static String _extractQueritResults(Map<String, dynamic> data) {
    final results = <String>[];
    // Querit returns: { "results": [...] }
    final items = data['results'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        final title = item['title'] as String? ?? '';
        final url = item['url'] as String? ?? '';
        final content = item['content'] as String? ?? '';
        results.add('标题: $title\n链接: $url\n内容: $content\n');
      }
    }
    if (results.isEmpty) return '未找到相关结果。';
    return results.join('\n---\n');
  }

  static String _extractSearxngResults(Map<String, dynamic> data) {
    final results = <String>[];
    final items = data['results'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        final title = item['title'] as String? ?? '';
        final url = item['url'] as String? ?? '';
        final content = item['content'] as String? ?? '';
        results.add('标题: $title\n链接: $url\n摘要: $content\n');
      }
    }
    if (results.isEmpty) return '未找到相关结果。';
    return results.join('\n---\n');
  }
}
