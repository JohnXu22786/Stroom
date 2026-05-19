import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;

/// M3U8 / HLS 播放列表解析器
///
/// 支持：
/// - 单码率播放列表 (#EXTINF)
/// - 多码率播放列表 (#EXT-X-STREAM-INF)，自动选择最高码率
/// - AES-128 加密检测
/// - 相对路径 → 绝对 URL 转换
class M3U8Parser {
  M3U8Parser._();

  // ===========================================================================
  // 公共 API
  // ===========================================================================

  /// 解析 m3u8 内容，返回所有 TS 分段 URL 列表
  ///
  /// [content] M3U8 文本内容
  /// [baseUrl] 用于将相对路径拼装为绝对 URL
  ///
  /// 如果遇到多码率播放列表，递归解析最高码率的子播放列表。
  static Future<List<String>> parsePlaylist(
    String content,
    String baseUrl,
  ) async {
    final lines = _normalizeLines(content);
    final segments = <String>[];

    if (_hasStreamInf(lines)) {
      debugPrint('[M3U8Parser] Detected multi-bitrate playlist');
      final variants = _parseStreamInf(lines);
      if (variants.isEmpty) return [];
      // 按带宽降序排序，选最高码率
      variants.sort((a, b) => (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0));
      final selectedUrl = _resolveUrl(variants.first.url, baseUrl);
      debugPrint(
          '[M3U8Parser] Selected variant: bandwidth=${variants.first.bandwidth}');
      final subContent = await _fetchUrl(selectedUrl);
      return parsePlaylist(subContent, selectedUrl);
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTINF:')) {
        if (i + 1 < lines.length) {
          final urlLine = lines[i + 1].trim();
          if (!urlLine.startsWith('#')) {
            segments.add(_resolveUrl(urlLine, baseUrl));
          }
        }
      }
    }

    debugPrint('[M3U8Parser] Parsed ${segments.length} segments');
    return segments;
  }

  /// 获取所有分段的时长信息（秒），用于 ±2s 时长筛选
  ///
  /// 如果是多码率播放列表（#EXT-X-STREAM-INF），自动选择最高码率的子播放列表并递归解析。
  static Future<List<({String url, double duration})>> parseSegments(
    String content,
    String baseUrl,
  ) async {
    // 检测多码率播放列表
    if (content.contains('#EXT-X-STREAM-INF:')) {
      final lines = _normalizeLines(content);
      String? bestUrl;
      int bestBandwidth = 0;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
          final bandwidth =
              bandwidthMatch != null ? int.parse(bandwidthMatch.group(1)!) : 0;

          if (i + 1 < lines.length && bandwidth > bestBandwidth) {
            final subUrl = _resolveUrl(lines[i + 1].trim(), baseUrl);
            bestUrl = subUrl;
            bestBandwidth = bandwidth;
          }
        }
      }

      if (bestUrl != null) {
        debugPrint(
            '[M3U8Parser] parseSegments selected variant: bandwidth=$bestBandwidth');
        final subContent = await _fetchUrl(bestUrl);
        return parseSegments(subContent, bestUrl);
      }
      return [];
    }

    final lines = _normalizeLines(content);
    final result = <({String url, double duration})>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTINF:')) {
        final duration = _parseExtinfDuration(line);
        if (i + 1 < lines.length) {
          final urlLine = lines[i + 1].trim();
          if (!urlLine.startsWith('#')) {
            result.add((
              url: _resolveUrl(urlLine, baseUrl),
              duration: duration,
            ));
          }
        }
      }
    }
    return result;
  }

  /// 检测是否使用 AES-128 加密
  static bool isEncrypted(String content) {
    return RegExp(
      r'#EXT-X-KEY:.*?METHOD\s*=\s*AES-128',
      caseSensitive: false,
    ).hasMatch(content);
  }

  /// 提取 AES-128 密钥 URL
  static String? extractKeyUrl(String content, String baseUrl) {
    final match = RegExp(
      r'#EXT-X-KEY:.*?URI\s*=\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(content);
    if (match == null) return null;
    return _resolveUrl(match.group(1)!, baseUrl);
  }

  // ===========================================================================
  // 内部方法
  // ===========================================================================

  /// 标准化行：统一换行、过滤空白
  static List<String> _normalizeLines(String content) {
    return content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
  }

  static bool _hasStreamInf(List<String> lines) {
    return lines.any((l) => l.trim().startsWith('#EXT-X-STREAM-INF:'));
  }

  /// 解析 #EXTINF 时长，格式: #EXTINF:<duration>,[<title>]
  static double _parseExtinfDuration(String line) {
    final raw = line.substring('#EXTINF:'.length).trim();
    final comma = raw.indexOf(',');
    final numStr = comma >= 0 ? raw.substring(0, comma) : raw;
    return double.tryParse(numStr.trim()) ?? 0.0;
  }

  /// 解析多码率变体
  static List<_StreamVariant> _parseStreamInf(List<String> lines) {
    final variants = <_StreamVariant>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
      final params = _parseTagParams(
        line.substring('#EXT-X-STREAM-INF:'.length),
      );
      final bw = int.tryParse(params['BANDWIDTH'] ?? '');
      if (i + 1 < lines.length) {
        final url = lines[i + 1].trim();
        if (!url.startsWith('#')) {
          variants.add(_StreamVariant(url: url, bandwidth: bw));
        }
      }
    }
    return variants;
  }

  /// 解析标签参数 key=value
  static Map<String, String> _parseTagParams(String raw) {
    final map = <String, String>{};
    final re = RegExp(r'(\w+)\s*=\s*"([^"]*)"|(\w+)\s*=\s*([^,"\s]+)');
    for (final m in re.allMatches(raw)) {
      map[(m.group(1) ?? m.group(3) ?? '').toUpperCase()] =
          m.group(2) ?? m.group(4) ?? '';
    }
    return map;
  }

  /// 相对路径 → 绝对 URL
  static String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return url;

    if (url.startsWith('/')) {
      return '${uri.scheme}://${uri.host}${_portPart(uri)}$url';
    }
    final base = uri.toString();
    final lastSlash = base.lastIndexOf('/');
    final dir = lastSlash >= 0 ? base.substring(0, lastSlash + 1) : '$base/';
    return '$dir$url';
  }

  static String _portPart(Uri uri) {
    if (uri.port == 80 || uri.port == 443 || uri.port <= 0) return '';
    return ':${uri.port}';
  }

  /// 通过 HTTP 获取 URL 内容（用于递归解析子播放列表）
  static Future<String> _fetchUrl(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to fetch playlist: HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }
}

/// 多码率变体
class _StreamVariant {
  final String url;
  final int? bandwidth;
  const _StreamVariant({required this.url, this.bandwidth});
}
