import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show Locale;

import '../l10n/app_localizations.dart';
import '../models/mcp.dart';
import '../models/tool_call.dart';
import '../providers/locale_provider.dart' show appLocalizationsForLocale;
import 'app_log_service.dart';

// ============================================================================
// HTTP 工具服务层
//
// 为纯 Dart 工具（Brave Search、Searxng、Bocha、Querit）提供 HTTP API 调用能力。
// 这些工具没有官方的 Remote MCP 服务，底层是直接调 HTTP API。
// 全端可用（iOS / Android / Linux / Windows / macOS / Web）。
// ============================================================================

/// HTTP 工具的服务层，管理 API Key 并提供工具处理函数
typedef HttpSearchResult = ({
  String title,
  String url,
  String description,
});

class HttpToolService {
  static const Map<String, Set<String>> _credentialHeaderNamesByProvider = {
    'Brave Search': {'x-subscription-token'},
    'Bocha': {'authorization'},
    'Querit': {'authorization'},
    'Searxng': {'authorization'},
  };

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

  static Set<String> credentialHeaderNamesForProvider(String providerName) =>
      _credentialHeaderNamesByProvider[providerName] ?? const {};

  /// Reads an HTTP search key from its explicit field or the provider's own
  /// credential header, ignoring unrelated custom headers.
  static String extractHttpToolApiKey(
    String providerName,
    Map<String, dynamic>? typeConfig,
  ) {
    if (typeConfig == null) return '';

    final credentialHeaderNames =
        credentialHeaderNamesForProvider(providerName);
    final rawHeaders = typeConfig['headers'];
    final credentialHeaders = <String, dynamic>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        final name = entry.key.toString();
        if (credentialHeaderNames.contains(name.toLowerCase())) {
          credentialHeaders[name] = entry.value;
        }
      }
    }

    return McpServerConfig.extractApiKeyFromTypeConfig({
      'apiKey': typeConfig['apiKey'],
      'headers': credentialHeaders,
    });
  }

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
  static Future<String> handleBraveSearch(
    Map<String, dynamic> args, {
    String? apiKey,
    Locale? locale,
  }) async {
    final l10n = appLocalizationsForLocale(locale);
    final query = (args['query'] as String?) ?? '';
    final count = (args['count'] as num?)?.toInt() ?? 10;
    final effectiveApiKey = apiKey ?? _braveApiKey;
    await AppLogService.info(
        'HttpToolService', 'Brave 搜索: query=$query, count=$count');

    if (effectiveApiKey.isEmpty) {
      return l10n.toolResultHttpApiKeyMissing('Brave Search');
    }
    if (query.isEmpty) return l10n.toolResultWebSearchEmptyQuery;

    try {
      final response = await _dio.get(
        'https://api.search.brave.com/res/v1/web/search',
        queryParameters: {
          'q': query,
          'count': count.clamp(1, 20),
        },
        options: Options(
          headers: {
            'X-Subscription-Token': effectiveApiKey,
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _extractBraveResults(data, l10n);
      }
      return l10n.toolResultHttpRequestFailedStatus(
          'Brave Search', response.statusCode.toString());
    } catch (e) {
      debugPrint('Brave Search error: $e');
      await AppLogService.error('HttpToolService', 'Brave 搜索失败: $query', e);
      return l10n.toolResultHttpRequestFailed('Brave Search', e.toString());
    }
  }

  /// Bocha Search handler (async)
  static Future<String> handleBochaSearch(
    Map<String, dynamic> args, {
    String? apiKey,
    Locale? locale,
  }) async {
    final l10n = appLocalizationsForLocale(locale);
    final query = (args['query'] as String?) ?? '';
    final count = (args['count'] as num?)?.toInt() ?? 10;
    final effectiveApiKey = apiKey ?? _bochaApiKey;
    await AppLogService.info(
        'HttpToolService', 'Bocha 搜索: query=$query, count=$count');

    if (effectiveApiKey.isEmpty) {
      return l10n.toolResultHttpApiKeyMissing('Bocha');
    }
    if (query.isEmpty) return l10n.toolResultWebSearchEmptyQuery;

    try {
      final response = await _dio.post(
        'https://api.bochaai.com/v1/web-search',
        options: Options(
          headers: {
            'Authorization': 'Bearer $effectiveApiKey',
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
        return _extractBochaResults(data, l10n);
      }
      return l10n.toolResultHttpRequestFailedStatus(
          'Bocha', response.statusCode.toString());
    } catch (e) {
      debugPrint('Bocha search error: $e');
      await AppLogService.error('HttpToolService', 'Bocha 搜索失败: $query', e);
      return l10n.toolResultHttpRequestFailed('Bocha', e.toString());
    }
  }

  /// Querit Search handler (async)
  static Future<String> handleQueritSearch(
    Map<String, dynamic> args, {
    String? apiKey,
    Locale? locale,
  }) async {
    final l10n = appLocalizationsForLocale(locale);
    final query = (args['query'] as String?) ?? '';
    final count = (args['count'] as num?)?.toInt() ?? 10;
    final effectiveApiKey = apiKey ?? _queritApiKey;
    await AppLogService.info(
        'HttpToolService', 'Querit 搜索: query=$query, count=$count');

    if (effectiveApiKey.isEmpty) {
      return l10n.toolResultHttpApiKeyMissing('Querit');
    }
    if (query.isEmpty) return l10n.toolResultWebSearchEmptyQuery;

    try {
      final response = await _dio.post(
        'https://api.querit.ai/v1/search',
        options: Options(
          headers: {
            'Authorization': 'Bearer $effectiveApiKey',
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
        return _extractQueritResults(data, l10n);
      }
      return l10n.toolResultHttpRequestFailedStatus(
          'Querit', response.statusCode.toString());
    } catch (e) {
      debugPrint('Querit search error: $e');
      await AppLogService.error('HttpToolService', 'Querit 搜索失败: $query', e);
      return l10n.toolResultHttpRequestFailed('Querit', e.toString());
    }
  }

  /// SearXNG Search handler (async)
  static Future<String> handleSearxngSearch(
    Map<String, dynamic> args, {
    String? url,
    String? apiKey,
    Locale? locale,
  }) async {
    final l10n = appLocalizationsForLocale(locale);
    final query = (args['query'] as String?) ?? '';
    final count = (args['count'] as num?)?.toInt() ?? 10;
    final effectiveUrl = url ?? _searxngUrl;
    final effectiveApiKey = apiKey ?? _searxngApiKey;
    await AppLogService.info(
        'HttpToolService', 'SearXNG 搜索: query=$query, count=$count');

    if (effectiveUrl.isEmpty || effectiveUrl == 'http://localhost:8080') {
      return l10n.toolResultHttpUrlMissing('SearXNG');
    }
    if (query.isEmpty) return l10n.toolResultWebSearchEmptyQuery;

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (effectiveApiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $effectiveApiKey';
      }

      final response = await _dio.get(
        '${effectiveUrl.replaceAll(RegExp(r'/+$'), '')}/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': count.clamp(1, 50),
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _extractSearxngResults(data, l10n);
      }
      return l10n.toolResultHttpRequestFailedStatus(
          'SearXNG', response.statusCode.toString());
    } catch (e) {
      debugPrint('Searxng search error: $e');
      await AppLogService.error('HttpToolService', 'SearXNG 搜索失败: $query', e);
      return l10n.toolResultHttpRequestFailed('SearXNG', e.toString());
    }
  }

  /// Runs one of the configured HTTP tools without changing the active chat
  /// service's process-wide credentials.
  static Future<String> runConnectivityTest({
    required String providerName,
    required Map<String, dynamic> arguments,
    required String apiKey,
    required String url,
    Locale? locale,
  }) {
    switch (providerName) {
      case 'Brave Search':
        return handleBraveSearch(arguments, apiKey: apiKey, locale: locale);
      case 'Bocha':
        return handleBochaSearch(arguments, apiKey: apiKey, locale: locale);
      case 'Querit':
        return handleQueritSearch(arguments, apiKey: apiKey, locale: locale);
      case 'Searxng':
        return handleSearxngSearch(
          arguments,
          url: url,
          apiKey: apiKey,
          locale: locale,
        );
      default:
        return Future.value(
          appLocalizationsForLocale(locale)
              .toolResultHttpUnknownTool(providerName),
        );
    }
  }

  // ======================================================================
  // Result extractors
  // ======================================================================

  static String _extractBraveResults(
    Map<String, dynamic> data,
    AppLocalizations l10n,
  ) {
    final results = <HttpSearchResult>[];
    final web = data['web'] as Map<String, dynamic>?;
    final items = web?['results'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        results.add((
          title: item['title'] as String? ?? '',
          url: item['url'] as String? ?? '',
          description: item['description'] as String? ?? '',
        ));
      }
    }
    return formatSearchResults(results, l10n: l10n);
  }

  static String _extractBochaResults(
    Map<String, dynamic> data,
    AppLocalizations l10n,
  ) {
    final results = <HttpSearchResult>[];
    final dataObj = data['data'] as Map<String, dynamic>?;
    final webPages = dataObj?['webPages'] as Map<String, dynamic>?;
    final items = webPages?['value'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        results.add((
          title: item['name'] as String? ?? '',
          url: item['url'] as String? ?? '',
          description: item['snippet'] as String? ?? '',
        ));
      }
    }
    return formatSearchResults(results, l10n: l10n);
  }

  static String _extractQueritResults(
    Map<String, dynamic> data,
    AppLocalizations l10n,
  ) {
    final results = <HttpSearchResult>[];
    final items = data['results'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        results.add((
          title: item['title'] as String? ?? '',
          url: item['url'] as String? ?? '',
          description: item['content'] as String? ?? '',
        ));
      }
    }
    return formatSearchResults(results, l10n: l10n, contentLabel: true);
  }

  static String _extractSearxngResults(
    Map<String, dynamic> data,
    AppLocalizations l10n,
  ) {
    final results = <HttpSearchResult>[];
    final items = data['results'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        results.add((
          title: item['title'] as String? ?? '',
          url: item['url'] as String? ?? '',
          description: item['content'] as String? ?? '',
        ));
      }
    }
    return formatSearchResults(results, l10n: l10n);
  }

  static String formatSearchResults(
    List<HttpSearchResult> results, {
    AppLocalizations? l10n,
    Locale? locale,
    bool contentLabel = false,
  }) {
    final strings = l10n ?? appLocalizationsForLocale(locale);
    if (results.isEmpty) return strings.toolResultWebSearchEmptyResults;

    final descriptionLabel = contentLabel
        ? strings.toolResultSearchContentLabel
        : strings.toolResultWebSearchSummaryLabel;
    return results
        .map((result) =>
            '${strings.toolResultSearchTitleLabel}: ${result.title}\n'
            '${strings.toolResultWebSearchLinkLabel}: ${result.url}\n'
            '$descriptionLabel: ${result.description}\n')
        .join('\n---\n');
  }
}
