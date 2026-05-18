/// cat-catch 默认媒体检测规则
///
/// 定义了引擎用于识别和分类媒体资源的所有默认配置常量。
class DefaultRules {
  DefaultRules._();

  /// 允许的媒体扩展名（全小写，不含点号）
  static const Set<String> mediaExtensions = {
    'mp4',
    'mp3',
    'm4a',
    'm4s',
    'webm',
    'ogg',
    'ogv',
    'mov',
    'mkv',
    'flv',
    'f4v',
    'hlv',
    'wmv',
    'wma',
    'wav',
    'aac',
    'avi',
    'mpeg',
    'mpg',
    'ts',
    'm3u8',
    'm3u',
    'mpd',
    'opus',
    'weba',
  };

  /// 可预览播放的扩展名
  static const Set<String> playableExtensions = {
    'mp4',
    'webm',
    'ogg',
    'ogv',
    'mp3',
    'wav',
    'm4a',
    'aac',
    'mov',
    'mkv',
  };

  /// 播放列表/清单扩展名
  static const Set<String> playlistExtensions = {
    'm3u8',
    'm3u',
    'mpd',
  };

  /// 允许的 Content-Type 前缀
  static const Set<String> mediaMimePrefixes = {
    'video/',
    'audio/',
  };

  /// 完整的媒体 Content-Type 列表
  static const Set<String> mediaMimeTypes = {
    'video/mp4',
    'video/webm',
    'video/ogg',
    'video/x-flv',
    'video/x-matroska',
    'video/3gpp',
    'video/mp2t',
    'audio/mpeg',
    'audio/wav',
    'audio/x-wav',
    'audio/ogg',
    'audio/webm',
    'audio/aac',
    'audio/mp4',
    'audio/x-m4a',
    'application/vnd.apple.mpegurl',
    'application/x-mpegurl',
    'application/dash+xml',
  };

  /// 默认的 HTTP 请求头（模拟真实浏览器）
  ///
  /// 用于绕过服务器的反爬/Bot 检测机制。
  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,'
        'image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.7',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };

  /// 构建完整的浏览器模拟请求头
  ///
  /// 在 [defaultHeaders] 基础上，添加动态的 [Referer]、[Origin] 等头。
  /// [referer] 来源页面 URL（防盗链关键）
  /// [extraHeaders] 额外的自定义头
  static Map<String, String> buildBrowserHeaders({
    String? referer,
    Map<String, String>? extraHeaders,
  }) {
    final headers = Map<String, String>.from(defaultHeaders);

    // 设置 Referer（防盗链关键头）
    if (referer != null && referer.isNotEmpty) {
      headers['Referer'] = referer;
      // 同时设置 Origin（部分 CDN 检查）
      try {
        final uri = Uri.parse(referer);
        headers['Origin'] = '${uri.scheme}://${uri.host}';
      } catch (_) {}
    }

    // 添加额外头
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// 下载并发数上限
  static const int maxConcurrency = 3;

  /// 单分段下载重试次数上限
  static const int maxRetriesPerSegment = 3;

  /// 期望时长筛选容差（秒）
  static const int durationToleranceSeconds = 3;

  /// 临时文件后缀
  static const String tempFileSuffix = '.catcatch_tmp';

  /// 进度文件后缀
  static const String progressFileSuffix = '.progress.json';
}
