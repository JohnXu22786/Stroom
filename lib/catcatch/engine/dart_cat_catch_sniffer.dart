import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../config/default_rules.dart';
import '../models/media_resource.dart';
import 'm3u8_parser.dart';
import 'mpd_parser.dart';
import 'sniffing_engine.dart';

// =============================================================================
// Sniff Result
// =============================================================================

/// Whether the resource was discovered via direct HTTP sniffing or
/// requires interactive WebView-based sniffing.
enum SniffSource {
  /// Found by making direct HTTP requests (no browser needed).
  direct,

  /// Found via WebView-based interactive sniffing (needs browser).
  webview,
}

/// The result of a sniffing operation.
class SniffResult {
  /// The discovered media resources.
  final List<MediaResource> resources;

  /// The source mechanism that found these resources.
  final SniffSource source;

  /// If direct sniffing failed, this flag indicates whether WebView
  /// sniffing should be attempted.
  final bool needsWebViewFallback;

  /// Any error message from the sniffing process.
  final String? error;

  const SniffResult({
    this.resources = const [],
    this.source = SniffSource.direct,
    this.needsWebViewFallback = false,
    this.error,
  });
}

// =============================================================================
// DartCatCatchSniffer — Pure Dart Core Sniffer
// =============================================================================

/// A standalone, pure-Dart media resource sniffer that operates without
/// any browser environment.
///
/// This is the refactored core of the "cat-catch" system. It replaces any
/// prior browser-extension-style patterns with direct HTTP requests using
/// [dio].
///
/// Design:
/// - Takes [targetUrl] and [headers] as input → returns [SniffResult]
/// - Uses [dio] with configurable [HttpClientAdapter] for testing
/// - Uses HEAD requests for metadata (content-type, content-length)
/// - Parses HTML/JSON text for embedded media URLs via regex
/// - Falls back to [SniffingEngine] for playlist (m3u8/mpd) parsing
///
/// Usage:
/// ```dart
/// final sniffer = DartCatCatchSniffer();
/// final result = await sniffer.sniff(
///   'https://example.com/video.mp4',
///   headers: {'Referer': 'https://example.com'},
/// );
/// // result.resources contains discovered MediaResource items
/// ```
class DartCatCatchSniffer {
  final Dio _dio;
  bool _disposed = false;

  /// Create a [DartCatCatchSniffer] with optional custom [HttpClientAdapter].
  ///
  /// The [httpClientAdapter] parameter is primarily used for testing.
  /// When omitted, a default [Dio] instance is used.
  DartCatCatchSniffer({HttpClientAdapter? httpClientAdapter})
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 15),
          ),
        ) {
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
    }
  }

  /// Dispose the underlying HTTP client.
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _dio.close();
    }
  }

  /// Sniff media resources from the given [targetUrl].
  ///
  /// [targetUrl] The URL to analyze (media file, playlist, or web page).
  /// [headers] Custom HTTP headers to include (User-Agent, Referer, etc.).
  /// [cancelToken] Optional cancellation token.
  ///
  /// Returns a [SniffResult] containing discovered [MediaResource] items.
  Future<SniffResult> sniff(
    String targetUrl, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    if (_disposed) {
      return const SniffResult(error: 'Sniffer has been disposed');
    }
    if (targetUrl.isEmpty) {
      return const SniffResult(
        error: 'URL must not be empty',
        needsWebViewFallback: false,
      );
    }

    final uri = Uri.tryParse(targetUrl);
    if (uri == null || !uri.hasScheme) {
      return SniffResult(
        error: 'Invalid URL: $targetUrl',
        needsWebViewFallback: false,
      );
    }

    try {
      // Merge custom headers with default browser headers
      final allHeaders = Map<String, String>.from(DefaultRules.defaultHeaders);
      if (headers != null) {
        allHeaders.addAll(headers);
      }

      // Step 1: Parse file extension from URL
      final (name, ext) = SniffingEngine.parseFileName(targetUrl);

      // Step 2: Playlist URL? Check BEFORE media extension since
      // playlist extensions (m3u8, m3u, mpd) are also in mediaExtensions.
      if (DefaultRules.playlistExtensions.contains(ext)) {
        return await _handlePlaylistUrl(
          targetUrl: targetUrl,
          ext: ext,
          name: name,
          headers: allHeaders,
          cancelToken: cancelToken,
        );
      }

      // Step 3: Direct media URL?
      if (ext.isNotEmpty && SniffingEngine.isMediaExtension(ext)) {
        return await _handleDirectMediaUrl(
          targetUrl: targetUrl,
          ext: ext,
          name: name,
          headers: allHeaders,
          cancelToken: cancelToken,
        );
      }

      // Step 4: Fetch and analyze HTML page for embedded media
      return await _handleHtmlPage(
        targetUrl: targetUrl,
        headers: allHeaders,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      debugPrint('[DartCatCatchSniffer] HTTP error: $e');
      return SniffResult(
        error: 'HTTP request failed: ${e.message}',
        needsWebViewFallback: true,
        source: SniffSource.direct,
      );
    } catch (e) {
      debugPrint('[DartCatCatchSniffer] Error: $e');
      return SniffResult(
        error: 'Sniffing failed: $e',
        needsWebViewFallback: true,
        source: SniffSource.direct,
      );
    }
  }

  // ===========================================================================
  // Internal handlers
  // ===========================================================================

  /// Handle a direct media URL (e.g., .mp4, .mp3, .webm).
  Future<SniffResult> _handleDirectMediaUrl({
    required String targetUrl,
    required String ext,
    required String name,
    required Map<String, String> headers,
    CancelToken? cancelToken,
  }) async {
    // Send HEAD request to get metadata
    String? mimeType;
    int? contentLength;
    try {
      final headResponse = await _dio.head(
        targetUrl,
        options: Options(headers: headers),
        cancelToken: cancelToken,
      );
      mimeType = headResponse.headers.value('content-type');
      final lengthStr = headResponse.headers.value('content-length');
      contentLength =
          lengthStr != null ? int.tryParse(lengthStr) : null;
    } catch (e) {
      debugPrint('[DartCatCatchSniffer] HEAD failed for direct URL: $e');
    }

    return SniffResult(
      resources: [
        MediaResource(
          url: targetUrl,
          name: name,
          ext: ext,
          mimeType: mimeType,
          size: contentLength,
          initiator: targetUrl,
          isPlayable: SniffingEngine.isPlayable(ext, mimeType),
          isPlaylist: false,
        ),
      ],
      source: SniffSource.direct,
    );
  }

  /// Handle a playlist URL (e.g., .m3u8, .mpd).
  Future<SniffResult> _handlePlaylistUrl({
    required String targetUrl,
    required String ext,
    required String name,
    required Map<String, String> headers,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(
      targetUrl,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
    final content = response.data is String ? response.data as String : '';

    List<String> segments;
    double totalDuration = 0;

    if (ext == 'm3u8' || ext == 'm3u') {
      segments = await M3U8Parser.parsePlaylist(content, targetUrl);
      final segDurations = await M3U8Parser.parseSegments(content, targetUrl);
      totalDuration = segDurations.fold<double>(0, (sum, s) => sum + s.duration);
    } else if (ext == 'mpd') {
      segments = await MPDParser.parseManifest(content, targetUrl);
      final mpdSegments = await MPDParser.parseSegments(content, targetUrl);
      totalDuration = mpdSegments.fold<double>(0, (sum, s) => sum + s.duration);
    } else {
      segments = [];
    }

    final resources = <MediaResource>[
      MediaResource(
        url: targetUrl,
        name: name,
        ext: ext,
        mimeType: ext == 'm3u8' || ext == 'm3u'
            ? 'application/vnd.apple.mpegurl'
            : 'application/dash+xml',
        initiator: targetUrl,
        isPlayable: false,
        isPlaylist: true,
        duration: totalDuration > 0
            ? Duration(seconds: totalDuration.round()).toString()
            : null,
      ),
      ...segments.map((segUrl) {
        final (segName, segExt) = SniffingEngine.parseFileName(segUrl);
        return MediaResource(
          url: segUrl,
          name: segName,
          ext: segExt.isEmpty ? 'ts' : segExt,
          initiator: targetUrl,
          isPlayable: false,
          isPlaylist: false,
        );
      }),
    ];

    return SniffResult(
      resources: resources,
      source: SniffSource.direct,
    );
  }

  /// Handle an HTML page — fetch and parse for embedded media URLs.
  Future<SniffResult> _handleHtmlPage({
    required String targetUrl,
    required Map<String, String> headers,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(
      targetUrl,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );

    final contentType = response.headers.value('content-type') ?? '';
    final body = response.data is String ? response.data as String : '';

    // Only parse HTML or text content
    if (!contentType.contains('text/html') &&
        !contentType.contains('text/plain') &&
        !contentType.contains('application/json') &&
        !contentType.contains('application/javascript') &&
        !contentType.contains('application/x-javascript')) {
      return const SniffResult(source: SniffSource.direct);
    }

    final urls = <String>{};

    // Regex: find media URLs in HTML/JS/JSON content
    // Matches: http(s)://... with media extensions
    // Use triple-quoted raw strings to safely include both ' and " in regex
    final mediaUrlRe = RegExp(
      r"""(https?://[^\s"'<>]+\.(mp4|m3u8|m3u|mpd|ts|webm|flv|f4v|mkv|avi|mov|wmv|ogg|ogv|aac|m4a|m4s|wav|mp3|opus|weba))"""
      r"""(?:\?[^\s"'<>]*)?""",
      caseSensitive: false,
    );

    for (final match in mediaUrlRe.allMatches(body)) {
      final url = match.group(0)!.trim();
      if (url.isNotEmpty) urls.add(url);
    }

    // Also match protocol-relative URLs (//cdn.example.com/video.mp4)
    final protocolRelativeRe = RegExp(
      r"""(//[^\s"'<>]+\.(mp4|m3u8|m3u|mpd|ts|webm|flv|f4v|mkv|avi|mov|wmv|ogg|ogv|aac|m4a|m4s|wav|mp3|opus|weba))"""
      r"""(?:\?[^\s"'<>]*)?""",
      caseSensitive: false,
    );

    final uri = Uri.tryParse(targetUrl);
    final scheme = uri?.scheme ?? 'https';
    for (final match in protocolRelativeRe.allMatches(body)) {
      urls.add('$scheme:${match.group(0)!.trim()}');
    }

    // Convert to MediaResource list
    final resources = urls.map((url) {
      final (name, ext) = SniffingEngine.parseFileName(url);
      return MediaResource(
        url: url,
        name: name,
        ext: ext,
        initiator: targetUrl,
        isPlayable: SniffingEngine.isPlayable(ext, null),
        isPlaylist: DefaultRules.playlistExtensions.contains(ext),
      );
    }).toList();

    // Check if we need WebView fallback (page likely JS-rendered)
    final needsWebView = resources.isEmpty && _looksLikeJsRenderedPage(body);

    return SniffResult(
      resources: resources,
      source: SniffSource.direct,
      needsWebViewFallback: needsWebView,
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /// Check if HTML body looks like a JS-rendered page (SPA, CSR, etc.)
  bool _looksLikeJsRenderedPage(String body) {
    final lower = body.toLowerCase();
    // Pages that rely on JS rendering typically have minimal HTML content
    // and load data via XHR/fetch
    if (lower.contains('<div id="app"') ||
        lower.contains('<div id="root"') ||
        lower.contains('<div id="__next"') ||
        lower.contains('ng-app') ||
        lower.contains('vue') && lower.contains('el:') ||
        lower.contains('react') && lower.contains('render') ||
        lower.contains('createApp') ||
        lower.contains('__NUXT__') ||
        lower.contains('__NEXT_DATA__')) {
      return true;
    }
    return false;
  }
}
