import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../models/tool_call.dart';

// ============================================================================
// 网络搜索工具服务层
//
// 参照 Cherry-HQ/cherry-studio 的 LocalProvider 搜索实现（Google、Bing、Baidu），
// 改为纯 Dart 实现，通过 HTTP 请求搜索页面并解析 HTML 获取结果。
// 无需 API Key，全端可用。
//
// 三个搜索引擎合并在一个工具中，通过 source 参数选择：
// - google: https://www.google.com/search?q=%s
// - bing:   https://www.bing.com/search?q=%s
// - baidu:  https://www.baidu.com/s?wd=%s
// ============================================================================

/// 网络搜索工具的服务层，提供 Google/Bing/Baidu 免费搜索功能
class WebSearchService {
  WebSearchService._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    },
  ));

  /// 搜索源枚举值
  static const List<String> supportedSources = ['google', 'bing', 'baidu'];

  /// 工具定义列表
  static final List<ToolDefinition> toolDefinitions = [
    ToolDefinition(
      name: 'web_search',
      description: '通过网络搜索获取实时信息。支持 Google、Bing、百度三个搜索引擎，'
          '通过 source 参数选择首选引擎（默认 google）；'
          '首选引擎不可用或未返回可解析结果时会自动尝试其他引擎。'
          '无需 API Key，免费使用。'
          '每个结果包含标题、链接和内容摘要。',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '搜索关键词',
          },
          'source': {
            'type': 'string',
            'description': '首选搜索引擎：google（谷歌）、bing（必应）、baidu（百度）；'
                '不可用时会自动切换',
            'enum': ['google', 'bing', 'baidu'],
          },
          'count': {
            'type': 'integer',
            'description': '返回结果数量（最大 10）',
            'default': 5,
          },
        },
        'required': ['query'],
      },
    ),
  ];

  /// 验证搜索源是否有效
  @visibleForTesting
  static bool isValidSource(String? source) {
    if (source == null || source.isEmpty) return true; // 默认 google
    return supportedSources.contains(source);
  }

  /// 构建搜索 URL
  @visibleForTesting
  static String buildSearchUrl(String query, String? source) {
    final effectiveSource = _resolveSource(source);
    final encodedQuery = Uri.encodeComponent(query);

    switch (effectiveSource) {
      case 'bing':
        return 'https://www.bing.com/search?q=$encodedQuery';
      case 'baidu':
        return 'https://www.baidu.com/s?wd=$encodedQuery';
      case 'google':
      default:
        return 'https://www.google.com/search?q=$encodedQuery';
    }
  }

  /// 处理 web_search 调用
  ///
  /// [args] 包含：
  ///   - query (String): 搜索关键词
  ///   - source (String?): 搜索引擎，可选 google/bing/baidu，默认 google
  ///   - count (int?): 返回结果数量，默认 5，最大 10
  static Future<String> handleWebSearch(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    final source = args['source'] as String?;
    final count = (args['count'] as num?)?.toInt() ?? 5;

    // 验证参数
    if (query.isEmpty) {
      return '错误: 搜索关键词不能为空。';
    }

    if (!isValidSource(source)) {
      return '错误: 不支持的搜索引擎 "$source"。'
          '可选值: google, bing, baidu';
    }

    final effectiveSource = _resolveSource(source);
    final maxResults = count.clamp(1, 10);
    debugPrint(
        'WebSearch: preferredSource=$effectiveSource, count=$maxResults');

    final failures = <String>[];
    final noResultSources = <String>[];
    final sourcesToTry = [
      effectiveSource,
      ...supportedSources.where((source) => source != effectiveSource),
    ];

    for (final sourceToTry in sourcesToTry) {
      try {
        final response = await _dio.get<String>(
          buildSearchUrl(query, sourceToTry),
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: true,
            maxRedirects: 5,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.statusCode != 200) {
          failures.add('$sourceToTry: HTTP ${response.statusCode}');
          continue;
        }

        final html = response.data ?? '';
        final results = _parseResults(html, sourceToTry, maxResults);
        if (results.isEmpty) {
          if (_hasExplicitNoResults(html, sourceToTry)) {
            noResultSources.add(sourceToTry);
            continue;
          }
          failures.add('$sourceToTry: 未返回可解析的搜索结果');
          continue;
        }

        final formattedResults = formatResults(results, sourceToTry);
        if (sourceToTry != effectiveSource) {
          final preferredReason = noResultSources.contains(effectiveSource)
              ? '未找到相关结果'
              : '暂不可用';
          return '首选引擎 ${_sourceName(effectiveSource)} $preferredReason，已切换到 ${_sourceName(sourceToTry)}。\n\n'
              '$formattedResults';
        }
        return formattedResults;
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        failures.add(statusCode == null
            ? '$sourceToTry: ${e.type.name}'
            : '$sourceToTry: HTTP $statusCode');
        debugPrint('WebSearch: $sourceToTry request failed (${e.type.name})');
      } catch (e) {
        failures.add('$sourceToTry: ${e.runtimeType}');
        debugPrint('WebSearch: $sourceToTry failed (${e.runtimeType})');
      }
    }

    if (noResultSources.isNotEmpty) {
      final noResults = noResultSources.map(_sourceName).join('、');
      if (failures.isEmpty && noResultSources.length == sourcesToTry.length) {
        return '未找到相关搜索结果（$noResults 均明确返回无结果）。';
      }
      return '搜索不完整：$noResults 明确返回无结果；'
          '其他引擎不可用或返回了无法解析的页面：${failures.join('；')}';
    }

    return '错误: 所有搜索引擎均不可用。${failures.join('；')}';
  }

  static String _sourceName(String source) => switch (source) {
        'google' => 'Google',
        'bing' => 'Bing',
        'baidu' => '百度',
        _ => source,
      };

  static bool _hasExplicitNoResults(String html, String source) {
    final text = _stripHtmlTags(html).toLowerCase();
    final messages = switch (source) {
      'google' => [
          'did not match any documents',
          '找不到和您查询的',
          '没有找到和您查询的',
        ],
      'bing' => [
          'there are no results for',
          'no results found',
          '没有找到相关结果',
        ],
      'baidu' => [
          '抱歉，未找到与',
          '很抱歉，未找到与',
          '抱歉，没有找到与',
          '没有找到与',
        ],
      _ => const <String>[],
    };
    return messages.any(text.contains);
  }

  /// 解析结果
  static List<SearchResult> _parseResults(
      String html, String source, int maxResults) {
    switch (source) {
      case 'bing':
        return parseBingResults(html, maxResults: maxResults);
      case 'baidu':
        return parseBaiduResults(html, maxResults: maxResults);
      case 'google':
      default:
        return parseGoogleResults(html, maxResults: maxResults);
    }
  }

  /// 解析 Google 搜索结果 HTML
  ///
  /// Google 结果格式：包含 class="MjjYud" 的 div 块，
  /// 其中 h3 > a 为标题链接，附近文本为摘要
  @visibleForTesting
  static List<SearchResult> parseGoogleResults(
    String html, {
    int maxResults = 10,
  }) {
    final results = <SearchResult>[];

    // 匹配结果块：通过 h3 > a 提取标题和链接
    // 支持直接 URL (https://...) 和 Google 跳转 URL (/url?q=...)
    final resultRegex = RegExp(
      r'<h3[^>]*>.*?<a[^>]*href="(https?://[^"]+|/url\?q=[^"]+)"[^>]*>(.*?)</a>.*?</h3>',
      dotAll: true,
      caseSensitive: false,
    );

    final matches = resultRegex.allMatches(html);
    for (final match in matches) {
      if (results.length >= maxResults) break;

      final url = _cleanUrl(match.group(1) ?? '');
      final title = _stripHtmlTags(match.group(2) ?? '').trim();

      if (title.isNotEmpty && url.isNotEmpty) {
        final snippet = _extractSnippetNearResult(html, match);

        results.add(SearchResult(
          title: title,
          url: url,
          snippet: snippet,
        ));
      }
    }

    return results;
  }

  /// 解析 Bing 搜索结果 HTML
  ///
  /// Bing 结果格式：li.b_algo > h2 > a 为标题链接
  @visibleForTesting
  static List<SearchResult> parseBingResults(
    String html, {
    int maxResults = 10,
  }) {
    final results = <SearchResult>[];

    // 匹配 b_algo 结果块
    final resultRegex = RegExp(
      r'<li[^>]*class="[^"]*b_algo[^"]*"[^>]*>.*?<h2[^>]*>.*?'
      r'<a[^>]*href="(https?://[^"]+)"[^>]*>(.*?)</a>.*?</h2>',
      dotAll: true,
      caseSensitive: false,
    );

    final matches = resultRegex.allMatches(html);
    for (final match in matches) {
      if (results.length >= maxResults) break;

      final url = _cleanUrl(match.group(1) ?? '');
      final title = _stripHtmlTags(match.group(2) ?? '').trim();

      if (title.isNotEmpty && url.isNotEmpty) {
        final snippet = _extractSnippetAfter(match.group(0)!, html);
        results.add(SearchResult(
          title: title,
          url: url,
          snippet: snippet,
        ));
      }
    }

    return results;
  }

  /// 解析百度搜索结果 HTML
  ///
  /// 百度结果格式：div.result > h3 > a 为标题链接
  @visibleForTesting
  static List<SearchResult> parseBaiduResults(
    String html, {
    int maxResults = 10,
  }) {
    final results = <SearchResult>[];

    // 匹配 result 块
    final resultRegex = RegExp(
      r'<div[^>]*class="[^"]*result[^"]*"[^>]*>.*?<h3[^>]*>.*?'
      r'<a[^>]*href="(https?://[^"]+)"[^>]*>(.*?)</a>.*?</h3>',
      dotAll: true,
      caseSensitive: false,
    );

    final matches = resultRegex.allMatches(html);
    for (final match in matches) {
      if (results.length >= maxResults) break;

      final url = _cleanUrl(match.group(1) ?? '');
      final title = _stripHtmlTags(match.group(2) ?? '').trim();

      if (title.isNotEmpty && url.isNotEmpty) {
        final blockStart = html.lastIndexOf('<div', match.start);
        final blockEnd = html.indexOf('</div>', match.end);
        final block = blockStart >= 0 && blockEnd > blockStart
            ? html.substring(blockStart, blockEnd + 6)
            : match.group(0)!;
        final snippet = _extractAbstract(block);

        results.add(SearchResult(
          title: title,
          url: url,
          snippet: snippet,
        ));
      }
    }

    return results;
  }

  /// 格式化搜索结果
  @visibleForTesting
  static String formatResults(List<SearchResult> results, String source) {
    if (results.isEmpty) {
      return '未找到相关搜索结果。';
    }

    final sourceName = _sourceName(source);
    final buffer = StringBuffer('来自 $sourceName 的搜索结果：\n\n');

    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      buffer.writeln('${i + 1}. ${r.title}');
      buffer.writeln('   链接: ${r.url}');
      if (r.snippet.isNotEmpty) {
        buffer.writeln('   摘要: ${r.snippet}');
      }
      if (i < results.length - 1) {
        buffer.writeln('---');
      }
    }

    return buffer.toString();
  }

  /// 解析搜索源（空值默认 google）
  static String _resolveSource(String? source) {
    if (source == null || source.isEmpty) return 'google';
    if (supportedSources.contains(source)) return source;
    return 'google';
  }

  /// 清理 URL（去掉多余参数和编码）
  /// 公开包装用于测试
  @visibleForTesting
  static String cleanUrlForTest(String url) => _cleanUrl(url);

  static String _cleanUrl(String url) {
    // 解码 HTML 实体
    var cleaned = url
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // 处理 Google 的 /url?q= 格式
    final urlQMatch = RegExp(r'^/url\?q=(https?://[^&]+)').firstMatch(cleaned);
    if (urlQMatch != null) {
      cleaned = Uri.decodeComponent(urlQMatch.group(1)!);
    }

    // 处理 Bing 的跳转 URL
    // /ck/a?...&u=a1BASE64...
    // 格式: /ck/a?someparams&u=a1<base64-encoded-url>
    if (cleaned.contains('/ck/a?')) {
      try {
        final uParam = RegExp(r'[?&]u=([^&]+)').firstMatch(cleaned);
        if (uParam != null) {
          final encodedPart = uParam.group(1)!;
          // Bing 的 u 参数是 a1 + base64 编码的 URL
          // 如：a1aHR0cHM6Ly9leGFtcGxlLmNvbQ
          // a1 是前缀，后面是 base64
          if (encodedPart.startsWith('a1')) {
            final b64 = _padBase64(encodedPart.substring(2));
            try {
              final decoded = utf8.decode(base64.decode(b64));
              if (decoded.startsWith('http://') ||
                  decoded.startsWith('https://')) {
                cleaned = decoded;
              }
            } catch (_) {
              // 解码失败，使用原始 URL
            }
          }
        }
      } catch (_) {}
    }

    // 只保留 http/https 协议的 URL
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      return cleaned;
    }

    return '';
  }

  /// Base64 填充
  static String _padBase64(String b64) {
    final mod = b64.length % 4;
    if (mod == 0) return b64;
    return b64 + '=' * (4 - mod);
  }

  /// 去除 HTML 标签
  static String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 提取匹配位置附近的摘要文本（用于 Google）
  ///
  /// 先尝试在匹配之前找特定 class 的 div 摘要，
  /// 再尝试在匹配之后的同一父级中找文本内容。
  static String _extractSnippetNearResult(String html, RegExpMatch match) {
    final beforeText = html.substring(0, match.start);

    // 先尝试在匹配之前找特定 class 的 div 摘要
    final snippetRegex = RegExp(
      r'<div[^>]*class="[^"]*(?:VwiC3b|BNeawe|yXK7lf|lEBKkf|st)[^"]*"[^>]*>'
      r'(.*?)</div>',
      dotAll: true,
      caseSensitive: false,
    );
    final matches = snippetRegex.allMatches(beforeText).toList();
    if (matches.isNotEmpty) {
      final text = _stripHtmlTags(matches.last.group(1) ?? '');
      if (text.isNotEmpty) return text;
    }

    // 再尝试在匹配之后的同一父级中找 <span> 文本（用于简单的测试 HTML）
    final afterTextIdx = match.end;
    if (afterTextIdx < html.length) {
      final afterText = html.substring(afterTextIdx);
      // 在接下来 500 个字符内找非空文本
      final nearText =
          afterText.length > 500 ? afterText.substring(0, 500) : afterText;
      final spanRegex = RegExp(
        r'<span[^>]*>(.*?)</span>',
        dotAll: true,
        caseSensitive: false,
      );
      final spanMatch = spanRegex.firstMatch(nearText);
      if (spanMatch != null) {
        final text = _stripHtmlTags(spanMatch.group(1) ?? '');
        if (text.isNotEmpty) return text;
      }
    }

    return '';
  }

  /// 提取匹配位置之后的摘要文本（用于 Bing）
  static String _extractSnippetAfter(String matchBlock, String fullHtml) {
    final afterIdx = fullHtml.indexOf(matchBlock);
    if (afterIdx < 0) return '';

    final afterText = fullHtml.substring(afterIdx + matchBlock.length);
    // 在之后找 <p> 标签
    final pRegex =
        RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true, caseSensitive: false);
    final pMatch = pRegex.firstMatch(afterText);
    if (pMatch != null) {
      return _stripHtmlTags(pMatch.group(1) ?? '');
    }
    return '';
  }

  /// 提取百度结果的摘要文本
  static String _extractAbstract(String block) {
    // 匹配 c-abstract 类
    final abstractRegex = RegExp(
      r'<div[^>]*class="[^"]*c-abstract[^"]*"[^>]*>(.*?)</div>',
      dotAll: true,
      caseSensitive: false,
    );
    final match = abstractRegex.firstMatch(block);
    if (match != null) {
      return _stripHtmlTags(match.group(1) ?? '');
    }

    // 备选：匹配 span.content-right_*
    final contentRegex = RegExp(
      r'<span[^>]*class="[^"]*content-right[^"]*"[^>]*>(.*?)</span>',
      dotAll: true,
      caseSensitive: false,
    );
    final match2 = contentRegex.firstMatch(block);
    if (match2 != null) {
      return _stripHtmlTags(match2.group(1) ?? '');
    }

    return '';
  }
}

/// 搜索结果数据模型
class SearchResult {
  final String title;
  final String url;
  final String snippet;

  const SearchResult({
    required this.title,
    required this.url,
    this.snippet = '',
  });
}
