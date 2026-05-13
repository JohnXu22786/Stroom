import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import '../config/default_rules.dart';
import '../models/media_resource.dart';
import 'm3u8_parser.dart';
import 'mpd_parser.dart';

/// URL 嗅探引擎
///
/// 分析用户提供的 URL，检测媒体资源类型并返回 [MediaResource] 列表。
/// 支持：
/// - 直接媒体 URL (.mp4, .webm, .mp3 等)
/// - 播放列表 URL (.m3u8, .mpd)
/// - 网页 URL（分析页面中的媒体资源）
class SniffingEngine {
  SniffingEngine._();

  /// 分析 URL，返回检测到的媒体资源列表
  ///
  /// [url] 用户输入的 URL
  /// [headers] 自定义 HTTP 请求头
  /// [cancelToken] 取消令牌
  /// [onProgress] 进度回调 (step, progress%)
  static Future<List<MediaResource>> analyzeUrl(
    String url, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
    void Function(String step, int progress)? onProgress,
  }) async {
    onProgress?.call('正在分析 URL', 10);
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw ArgumentError('无效的 URL: $url');
    }

    // 检查取消
    // Note: sniffing is typically fast (HTTP fetch), so cancellation is best-effort.
    // The HttpClient created inside _fetchUrlContent is closed in its own finally block.
    cancelToken?.whenCancel.then((_) => null);

    final allHeaders = Map<String, String>.from(DefaultRules.defaultHeaders);
    if (headers != null) allHeaders.addAll(headers);

    // 1. 从 URL 提取文件名和扩展名
    final (name, ext) = parseFileName(url);
    if (!isMediaExtension(ext) && ext.isNotEmpty) {
      debugPrint('[SniffingEngine] Extension "$ext" is not a media type, '
          'will attempt content-type detection');
    }

    // 2. 检查是否是播放列表
    if (DefaultRules.playlistExtensions.contains(ext)) {
      onProgress?.call('正在获取播放列表内容', 30);
      final content = await _fetchUrlContent(url, allHeaders);
      // Note: sniffing is typically fast, cancellation is best-effort.
      cancelToken?.whenCancel.then((_) => null);

      if (ext == 'm3u8' || ext == 'm3u') {
        onProgress?.call('正在解析 M3U8 播放列表', 50);
        final segments = await M3U8Parser.parsePlaylist(content, url);
        final segmentedMedia = await _parseSegmentsToMedia(segments, url, ext);
        onProgress?.call('播放列表解析完成', 80);

        // 获取总时长信息
        final segDurations = await M3U8Parser.parseSegments(content, url);
        final totalDuration = segDurations.fold<double>(
          0,
          (sum, s) => sum + s.duration,
        );

        return [
          MediaResource(
            url: url,
            name: name,
            ext: ext,
            mimeType: 'application/vnd.apple.mpegurl',
            initiator: url,
            isPlayable: false,
            isPlaylist: true,
            duration: totalDuration > 0
                ? Duration(seconds: totalDuration.round()).toString()
                : null,
          ),
          ...segmentedMedia,
        ];
      } else if (ext == 'mpd') {
        onProgress?.call('正在解析 MPD 播放列表', 50);
        final segments = await MPDParser.parseManifest(content, url);
        final segmentedMedia = await _parseSegmentsToMedia(segments, url, ext);
        onProgress?.call('MPD 解析完成', 80);

        // 获取总时长信息
        final mpdSegments = await MPDParser.parseSegments(content, url);
        final mpdTotalDuration =
            mpdSegments.fold<double>(0, (sum, s) => sum + s.duration);

        return [
          MediaResource(
            url: url,
            name: name,
            ext: ext,
            mimeType: 'application/dash+xml',
            initiator: url,
            isPlayable: false,
            isPlaylist: true,
            duration: mpdTotalDuration > 0
                ? Duration(seconds: mpdTotalDuration.round()).toString()
                : null,
          ),
          ...segmentedMedia,
        ];
      }
    }

    // 3. 发送 HEAD 请求获取 Content-Type 和 Content-Length
    onProgress?.call('正在探测资源信息', 40);
    String? mimeType;
    int? contentLength;

    try {
      final headResult = await _headRequest(url, allHeaders);
      mimeType = headResult.$1;
      contentLength = headResult.$2;
    } catch (e) {
      debugPrint('[SniffingEngine] HEAD request failed: $e');
    }

    // 4. 如果扩展名不是媒体类型，但 Content-Type 是，修正 ext
    String finalExt = ext;
    String finalName = name;
    if (!isMediaExtension(ext) && mimeType != null) {
      final detectedExt = _extFromMime(mimeType);
      if (detectedExt != null) {
        finalExt = detectedExt;
      }
    }

    // 如果扩展名为空，尝试从 Content-Type 推断
    if (finalExt.isEmpty && mimeType != null) {
      final detectedExt = _extFromMime(mimeType);
      if (detectedExt != null) {
        finalExt = detectedExt;
      }
    }

    onProgress?.call('分析完成', 100);

    return [
      MediaResource(
        url: url,
        name: finalName,
        ext: finalExt,
        mimeType: mimeType,
        size: contentLength,
        initiator: url,
        isPlayable: isPlayable(finalExt, mimeType),
        isPlaylist: false,
      ),
    ];
  }

  /// 从 URL 中提取文件名和扩展名
  ///
  /// 返回 (name, ext)，name 不含扩展名。
  /// 示例：
  ///   "https://example.com/video.mp4?t=123" → ("video", "mp4")
  ///   "https://example.com/path/to/file" → ("file", "")
  static (String name, String ext) parseFileName(String url) {
    // 去掉查询参数
    final queryIdx = url.indexOf('?');
    final cleanUrl = queryIdx >= 0 ? url.substring(0, queryIdx) : url;

    // 去掉 fragment
    final fragmentIdx = cleanUrl.indexOf('#');
    final pathUrl =
        fragmentIdx >= 0 ? cleanUrl.substring(0, fragmentIdx) : cleanUrl;

    final filename = p.basename(pathUrl);
    if (filename.isEmpty || filename == '/') {
      // 无文件名，尝试从路径最后一段取
      final segments = Uri.tryParse(url)?.pathSegments ?? [];
      if (segments.isNotEmpty) {
        final last = segments.last;
        if (last.isNotEmpty) {
          final dot = last.lastIndexOf('.');
          if (dot > 0) {
            return (
              last.substring(0, dot),
              last.substring(dot + 1).toLowerCase()
            );
          }
          return (last, '');
        }
      }
      return ('unknown', '');
    }

    final dot = filename.lastIndexOf('.');
    if (dot > 0) {
      return (
        filename.substring(0, dot),
        filename.substring(dot + 1).toLowerCase(),
      );
    }
    return (filename, '');
  }

  /// 检查扩展名是否属于媒体类型
  static bool isMediaExtension(String ext) {
    return DefaultRules.mediaExtensions.contains(ext.toLowerCase());
  }

  /// 根据扩展名和 MIME 类型判断是否可播放
  static bool isPlayable(String ext, String? mimeType) {
    final lowerExt = ext.toLowerCase();
    if (DefaultRules.playableExtensions.contains(lowerExt)) return true;
    if (mimeType != null) {
      for (final prefix in DefaultRules.mediaMimePrefixes) {
        if (mimeType.startsWith(prefix)) return true;
      }
    }
    return false;
  }

  /// 按期望时长 ± 容差秒 筛选资源
  ///
  /// [resources] 媒体资源列表
  /// [expectedDurationSec] 用户期望的时长（秒）
  /// [toleranceSec] 容差秒数（默认 2）
  static List<MediaResource> filterByDuration(
    List<MediaResource> resources,
    int expectedDurationSec, {
    int toleranceSec = 2,
  }) {
    if (resources.isEmpty) return [];
    // 仅筛选有时长信息的资源（播放列表等）
    final result = <MediaResource>[];
    for (final res in resources) {
      if (res.duration == null) {
        // 没有时长信息，保留（可能是直接媒体文件）
        result.add(res);
        continue;
      }
      final duration = _parseDurationToSeconds(res.duration!);
      if (duration == null) {
        result.add(res);
        continue;
      }
      if ((duration - expectedDurationSec).abs() <= toleranceSec) {
        result.add(res);
      }
    }
    return result;
  }

  // ===========================================================================
  // 内部方法
  // ===========================================================================

  /// HEAD 请求获取 Content-Type 和 Content-Length
  static Future<(String?, int?)> _headRequest(
    String url,
    Map<String, String> headers,
  ) async {
    final dio = Dio();
    try {
      final response = await dio.head(
        url,
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      final contentType = response.headers.value('content-type');
      final contentLengthStr = response.headers.value('content-length');
      final length =
          contentLengthStr != null ? int.tryParse(contentLengthStr) : null;
      return (contentType, length);
    } finally {
      dio.close();
    }
  }

  /// 获取 URL 内容
  static Future<String> _fetchUrlContent(
    String url,
    Map<String, String> headers,
  ) async {
    final dio = Dio();
    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      if (response.statusCode != 200) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'HTTP ${response.statusCode}',
        );
      }
      return response.data is String ? response.data as String : '';
    } finally {
      dio.close();
    }
  }

  /// 将分段 URL 列表转为 MediaResource 列表
  static Future<List<MediaResource>> _parseSegmentsToMedia(
    List<String> segments,
    String baseUrl,
    String ext,
  ) async {
    return segments.map((segUrl) {
      final (segName, segExt) = parseFileName(segUrl);
      return MediaResource(
        url: segUrl,
        name: segName,
        ext: segExt.isEmpty ? 'ts' : segExt,
        initiator: baseUrl,
        isPlayable: false,
        isPlaylist: false,
      );
    }).toList();
  }

  /// 从 MIME 类型推断扩展名
  static String? _extFromMime(String mimeType) {
    for (final entry in _mimeToExt.entries) {
      if (mimeType.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  static const Map<String, String> _mimeToExt = {
    'video/mp4': 'mp4',
    'video/webm': 'webm',
    'video/ogg': 'ogv',
    'video/x-flv': 'flv',
    'video/x-matroska': 'mkv',
    'video/mp2t': 'ts',
    'video/3gpp': 'mp4',
    'audio/mpeg': 'mp3',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'audio/ogg': 'ogg',
    'audio/webm': 'weba',
    'audio/aac': 'aac',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'application/vnd.apple.mpegurl': 'm3u8',
    'application/x-mpegurl': 'm3u8',
    'application/dash+xml': 'mpd',
  };

  /// 将 "00:12:34.567" 格式的时长转为秒
  static double? _parseDurationToSeconds(String duration) {
    // HH:MM:SS.mmm
    final parts = duration.split(':');
    if (parts.length == 3) {
      final h = double.tryParse(parts[0]) ?? 0;
      final m = double.tryParse(parts[1]) ?? 0;
      final s = double.tryParse(parts[2]) ?? 0;
      return h * 3600 + m * 60 + s;
    }
    if (parts.length == 2) {
      final m = double.tryParse(parts[0]) ?? 0;
      final s = double.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    }
    return double.tryParse(duration);
  }
}
