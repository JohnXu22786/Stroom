import 'package:flutter/foundation.dart' show debugPrint;

/// DASH MPD 解析器
///
/// 支持：
/// - SegmentTemplate (含 $Number$ / $Time$ 模板)
/// - SegmentList (显式 URL 列表)
/// - SegmentTimeline (S 元素定义的时长序列)
/// - BaseURL / AdaptationSet / Representation 层级
/// - 相对路径 → 绝对 URL 转换
class MPDParser {
  MPDParser._();

  // ===========================================================================
  // 公共 API
  // ===========================================================================

  /// 解析 MPD 内容，返回所有分段 URL
  static Future<List<String>> parseManifest(
    String content,
    String baseUrl,
  ) async {
    final segments = await _parseAllSegments(content, baseUrl);
    return segments.map((s) => s.url).toList();
  }

  /// 获取所有分段的时长信息
  static Future<List<({String url, double duration})>> parseSegments(
    String content,
    String baseUrl,
  ) async {
    return _parseAllSegments(content, baseUrl);
  }

  // ===========================================================================
  // 内部解析
  // ===========================================================================

  static Future<List<({String url, double duration})>> _parseAllSegments(
    String content,
    String baseUrl,
  ) async {
    final result = <({String url, double duration})>[];

    // 提取 BaseURL
    final baseUrls = _extractBaseUrls(content);
    final effectiveBase =
        baseUrls.isNotEmpty ? _resolveBase(baseUrls.first, baseUrl) : baseUrl;

    // 提取所有 AdaptationSet
    final adaptationSets = _extractBlocks(content, 'AdaptationSet');
    if (adaptationSets.isEmpty) {
      // 尝试直接找 Representation（有时 AdaptationSet 省略）
      final reps = _extractBlocks(content, 'Representation');
      for (final rep in reps) {
        result.addAll(_parseRepresentation(rep, content, effectiveBase));
      }
    } else {
      for (final aset in adaptationSets) {
        final reps = _extractBlocks(aset, 'Representation');
        // 取第一个 Representation（或所有）
        for (final rep in reps) {
          result.addAll(_parseRepresentation(rep, content, effectiveBase));
        }
      }
    }

    debugPrint('[MPDParser] Parsed ${result.length} segments');
    return result;
  }

  /// 解析单个 Representation 中的分段
  static List<({String url, double duration})> _parseRepresentation(
    String repXml,
    String fullMpdXml,
    String baseUrl,
  ) {
    // 尝试 SegmentTemplate
    final template = _extractFirstBlock(repXml, 'SegmentTemplate');
    if (template != null) {
      return _parseSegmentTemplate(repXml, template, fullMpdXml, baseUrl);
    }

    // 尝试 SegmentList
    final list = _extractFirstBlock(repXml, 'SegmentList');
    if (list != null) {
      return _parseSegmentList(list, baseUrl);
    }

    return [];
  }

  // ---------------------------------------------------------------------------
  // SegmentTemplate 解析
  // ---------------------------------------------------------------------------

  static List<({String url, double duration})> _parseSegmentTemplate(
    String repXml,
    String templateXml,
    String fullMpdXml,
    String baseUrl,
  ) {
    final result = <({String url, double duration})>[];

    final timescale = _getIntAttr(templateXml, 'timescale') ?? 1;
    final duration = _getIntAttr(templateXml, 'duration'); // 固定时长
    final startNumber = _getIntAttr(templateXml, 'startNumber') ?? 1;
    final mediaTemplate = _getAttr(templateXml, 'media');
    final initialization = _getAttr(templateXml, 'initialization');

    if (mediaTemplate == null) return result;

    // 尝试 SegmentTimeline (内部)
    final timeline = _extractFirstBlock(templateXml, 'SegmentTimeline');
    if (timeline != null) {
      // SegmentTimeline + SegmentTemplate
      final number = _getIntAttr(templateXml, 'startNumber') ?? 1;
      final sElements = _extractBlocks(timeline, 'S');
      int segNum = number;
      for (final s in sElements) {
        final t = _getIntAttr(s, 't');
        final d = _getIntAttr(s, 'd') ?? 0;
        final r = _getIntAttr(s, 'r') ?? 0;
        final count = r + 1;
        for (int i = 0; i < count; i++) {
          final segUrl = _applyTemplate(mediaTemplate, segNum, t ?? 0);
          result.add((
            url: _resolveBase(segUrl, baseUrl),
            duration: d / timescale,
          ));
          segNum++;
        }
      }
      // 初始化分段
      if (initialization != null) {
        result.insert(0, (
          url: _resolveBase(
            _applyTemplate(initialization, startNumber, 0),
            baseUrl,
          ),
          duration: 0,
        ));
      }
      return result;
    }

    // 无 Timeline，用固定 duration
    if (duration == null || duration <= 0) return result;

    // 需要计算总分段数 —— 尝试从 Representation 的 bandwidth 和总大小推算
    // 无总大小时使用保守估计：假设最多 200 个分段
    // 或者从 MPD 的 availabilityStartTime / mediaPresentationDuration 推算
    final totalDuration = _getTotalDuration(fullMpdXml);
    if (totalDuration <= 0) {
      // 无法估算，返回单个模板 URL（交给下游处理）
      result.add((
        url: _resolveBase(
          _applyTemplate(mediaTemplate, startNumber, 0),
          baseUrl,
        ),
        duration: duration / timescale,
      ));
      return result;
    }

    final segCount = (totalDuration / duration).ceil();
    int segNum = startNumber;
    for (int i = 0; i < segCount; i++) {
      result.add((
        url: _resolveBase(
          _applyTemplate(mediaTemplate, segNum, 0),
          baseUrl,
        ),
        duration: duration / timescale,
      ));
      segNum++;
    }

    // 初始化分段
    if (initialization != null) {
      result.insert(0, (
        url: _resolveBase(
          _applyTemplate(initialization, startNumber, 0),
          baseUrl,
        ),
        duration: 0,
      ));
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // SegmentList 解析
  // ---------------------------------------------------------------------------

  static List<({String url, double duration})> _parseSegmentList(
    String listXml,
    String baseUrl,
  ) {
    final result = <({String url, double duration})>[];
    final segUrls = _extractBlocks(listXml, 'SegmentURL');
    for (final seg in segUrls) {
      final media = _getAttr(seg, 'media');
      if (media != null) {
        result.add((
          url: _resolveBase(media, baseUrl),
          duration: 0,
        ));
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  /// 应用模板变量
  static String _applyTemplate(String template, int number, int time) {
    return template
        .replaceAll(r'$Number$', number.toString())
        .replaceAll(r'$Number%0', number.toString().padLeft(5, '0'))
        .replaceAll(r'$Time$', time.toString())
        .replaceAll(r'$RepresentationID$', '1');
  }

  /// 从 XML 属性值
  static String? _getAttr(String xml, String attr) {
    final re = RegExp('$attr\\s*=\\s*"([^"]*)"');
    return re.firstMatch(xml)?.group(1);
  }

  static int? _getIntAttr(String xml, String attr) {
    final v = _getAttr(xml, attr);
    return v != null ? int.tryParse(v) : null;
  }

  /// 提取 XML 块（含标签内容，支持嵌套）
  static List<String> _extractBlocks(String xml, String tag) {
    final results = <String>[];
    // 用正则避免部分单词匹配：<tag 后面必须跟空白、>、/或换行符
    final openPattern = RegExp('<$tag(?:\\s|>|/|\\n)');
    final closeTag = '</$tag>';
    int searchFrom = 0;

    while (true) {
      final match = openPattern.firstMatch(xml.substring(searchFrom));
      if (match == null) break;
      final openStart = searchFrom + match.start;

      // 跳过自闭合标签 <tag ... />
      final openEnd = xml.indexOf('>', openStart);
      if (openEnd < 0) break;

      final openContent = xml.substring(openStart, openEnd + 1);
      if (openContent.endsWith('/>')) {
        // 自闭合标签
        results.add(openContent);
        searchFrom = openEnd + 1;
        continue;
      }

      // 找对应的结束标签
      final closeIdx = xml.indexOf(closeTag, openEnd);
      if (closeIdx < 0) break;

      results.add(xml.substring(openStart, closeIdx + closeTag.length));
      searchFrom = closeIdx + closeTag.length;
    }
    return results;
  }

  /// 提取第一个块
  static String? _extractFirstBlock(String xml, String tag) {
    final blocks = _extractBlocks(xml, tag);
    return blocks.isNotEmpty ? blocks.first : null;
  }

  /// 提取所有 BaseURL 内容
  static List<String> _extractBaseUrls(String xml) {
    final urls = <String>[];
    final re = RegExp(r'<BaseURL[^>]*>([^<]*)</BaseURL>');
    for (final m in re.allMatches(xml)) {
      final url = m.group(1)?.trim();
      if (url != null && url.isNotEmpty) urls.add(url);
    }
    return urls;
  }

  /// 尝试获取 MPD 的 mediaPresentationDuration（秒）
  ///
  /// 完整解析 ISO 8601 时长字符串（如 PT0H30M0S, PT30M15S, PT1H30M）。
  static double _getTotalDuration(String repXml) {
    // 提取 mediaPresentationDuration 属性值
    final regex = RegExp(r'mediaPresentationDuration\s*=\s*"([^"]+)"');
    final match = regex.firstMatch(repXml);
    if (match == null) return 0;

    final durationStr = match.group(1)!; // 如 "PT0H30M0S"

    // 去掉 PT 前缀
    if (!durationStr.startsWith('PT')) return 0;
    final timePart = durationStr.substring(2);

    int totalSeconds = 0;

    // 提取小时
    final hMatch = RegExp(r'(\d+(?:\.\d+)?)H').firstMatch(timePart);
    if (hMatch != null) {
      totalSeconds += (double.parse(hMatch.group(1)!) * 3600).round();
    }

    // 提取分钟
    final mMatch = RegExp(r'(\d+(?:\.\d+)?)M').firstMatch(timePart);
    if (mMatch != null) {
      totalSeconds += (double.parse(mMatch.group(1)!) * 60).round();
    }

    // 提取秒
    final sMatch = RegExp(r'(\d+(?:\.\d+)?)S').firstMatch(timePart);
    if (sMatch != null) {
      totalSeconds += double.parse(sMatch.group(1)!).round();
    }

    return totalSeconds.toDouble();
  }

  /// 拼接 URL（处理相对路径）
  static String _resolveBase(String url, String baseUrl) {
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
}
