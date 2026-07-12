import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/media_resource.dart';
import 'sniffing_engine.dart';

class WebViewSniffer {
  WebViewSniffer._();

  /// Maximum time to wait for page load
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Maximum results to collect
  static const int maxResults = 50;

  /// Sniff media resources by loading URL in a background WebView
  ///
  /// This handles:
  /// - URL redirects (b23.tv → bilibili.com)
  /// - JavaScript-rendered pages
  /// - Dynamic video elements
  /// - Network request interception for media files
  ///
  /// Returns a record with:
  /// - $1: detected media resources `(List<MediaResource>)`
  /// - `$2`: the HTML `<title>` of the page (String?), if available
  static Future<(List<MediaResource>, String?)> sniff({
    required String url,
    Duration timeout = defaultTimeout,
    CancelToken? cancelToken,
    void Function(String step, int progress)? onProgress,
  }) async {
    final detectedUrls = <String>{};
    final completer = Completer<(List<MediaResource>, String?)>();
    Timer? timeoutTimer;
    var disposed = false;
    var resolvedUrl = url;
    String? capturedTitle;

    onProgress?.call('启动后台浏览器', 10);

    final headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        allowFileAccessFromFileURLs: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        // Minimal settings for background operation
        useWideViewPort: false,
        supportZoom: false,
      ),
      onLoadStop: (controller, url) async {
        if (disposed) return;
        try {
          final currentUrl = url?.toString() ?? '';
          resolvedUrl = currentUrl;
          onProgress?.call('页面加载完成，正在扫描媒体资源', 60);

          // Inject JS to scan for media in DOM
          final jsResult = await controller.evaluateJavascript(
            source: _sniffScript,
          );

          if (jsResult is List) {
            for (final item in jsResult) {
              if (item is String && item.startsWith('http')) {
                detectedUrls.add(item);
              }
            }
          } else if (jsResult is String) {
            try {
              final parsed = jsonDecode(jsResult);
              if (parsed is List) {
                for (final item in parsed) {
                  if (item is String && item.startsWith('http')) {
                    detectedUrls.add(item);
                  }
                }
              }
            } catch (_) {}
          }

          // Extract page title for auto-naming
          try {
            final titleResult = await controller.evaluateJavascript(
              source: 'document.title',
            );
            if (titleResult is String) {
              capturedTitle = titleResult.trim();
            }
          } catch (_) {}

          onProgress?.call('扫描完成，共发现 ${detectedUrls.length} 个资源', 90);

          // Convert to MediaResource list
          final resources = detectedUrls.map((u) {
            final (name, ext) = SniffingEngine.parseFileName(u);
            return MediaResource(
              url: u,
              name: name,
              ext: ext,
              initiator: currentUrl,
              isPlayable:
                  ext.isNotEmpty && !['m3u8', 'm3u', 'mpd', 'ts'].contains(ext),
              isPlaylist: ['m3u8', 'm3u', 'mpd'].contains(ext),
            );
          }).toList();

          // Cancel timeout & dispose
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete((resources, capturedTitle));
          }
        } catch (e) {
          debugPrint('[WebViewSniffer] onLoadStop error: $e');
        }
      },
      shouldInterceptRequest: (controller, request) async {
        if (disposed) return null;
        // Intercept network requests and check for media URLs
        final reqUrl = request.url.toString();
        final ext = _extractExtension(reqUrl);
        if (ext != null &&
            _mediaExtensions.contains(ext) &&
            !detectedUrls.contains(reqUrl)) {
          detectedUrls.add(reqUrl);
          debugPrint('[WebViewSniffer] Intercepted media: $reqUrl');
        }
        return null; // Let the request continue normally
      },
    );

    try {
      await headlessWebView.run();
      onProgress?.call('浏览器已启动，正在加载页面', 20);

      cancelToken?.whenCancel.then((_) {
        if (!completer.isCompleted) {
          debugPrint('[WebViewSniffer] Cancelled by user');
          if (!disposed) {
            disposed = true;
            headlessWebView.dispose();
          }
          completer.complete((<MediaResource>[], null));
        }
      });

      // Set timeout
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          debugPrint(
            '[WebViewSniffer] Timeout reached, returning ${detectedUrls.length} resources',
          );
          onProgress?.call(
            '超时，返回已发现的 ${detectedUrls.length} 个资源',
            100,
          );
          final resources = detectedUrls.map((u) {
            final (name, ext) = SniffingEngine.parseFileName(u);
            return MediaResource(
              url: u,
              name: name,
              ext: ext,
              initiator: resolvedUrl,
              isPlayable:
                  ext.isNotEmpty && !['m3u8', 'm3u', 'mpd', 'ts'].contains(ext),
              isPlaylist: ['m3u8', 'm3u', 'mpd'].contains(ext),
            );
          }).toList();
          if (!disposed) {
            disposed = true;
            headlessWebView.dispose();
          }
          completer.complete((resources, capturedTitle));
        }
      });

      return await completer.future;
    } finally {
      timeoutTimer?.cancel();
      if (!disposed) {
        disposed = true;
        await headlessWebView.dispose();
      }
    }
  }

  /// JavaScript to inject into page for DOM scanning
  static const String _sniffScript = '''
(function() {
  const results = new Set();

  // 1. Scan <video> and <audio> elements
  document.querySelectorAll('video, audio').forEach(el => {
    if (el.currentSrc && el.currentSrc.startsWith('http')) results.add(el.currentSrc);
    if (el.src && el.src.startsWith('http')) results.add(el.src);
    el.querySelectorAll('source').forEach(s => {
      if (s.src && s.src.startsWith('http')) results.add(s.src);
    });
  });

  // 2. Scan all elements with media extension URLs
  const mediaExtRe = /\\.(mp4|m3u8|m3u|mpd|ts|webm|flv|f4v|mkv|avi|mov|wmv|ogg|ogv|aac|m4a|m4s|wav|mp3)(\\?|#|\$)/i;
  document.querySelectorAll('[href],[src],[data-src],[data-url],[data-original]').forEach(el => {
    const candidates = [el.href, el.src, el.dataset.src, el.dataset.url, el.dataset.original];
    candidates.forEach(val => {
      if (val && typeof val === 'string' && val.startsWith('http') && mediaExtRe.test(val)) {
        results.add(val);
      }
    });
  });

  // 3. Scan script tags with embedded JSON data
  document.querySelectorAll('script[type="application/json"], script[id*="video"], script[id*="page"], script[id*="data"]').forEach(script => {
    try {
      const data = JSON.parse(script.textContent);
      function findUrls(obj) {
        if (!obj || typeof obj !== 'object') return;
        if (Array.isArray(obj)) { obj.forEach(findUrls); return; }
        for (const [key, val] of Object.entries(obj)) {
          if (typeof val === 'string') {
            if (val.startsWith('http') && mediaExtRe.test(val)) results.add(val);
            if (val.startsWith('//') && mediaExtRe.test(val)) results.add('https:' + val);
          } else if (typeof val === 'object') {
            findUrls(val);
          }
        }
      }
      findUrls(data);
    } catch(e) {}
  });

  // 4. Check window.__INITIAL_STATE__ or similar global vars (Bilibili, YouTube etc)
  if (typeof window.__INITIAL_STATE__ !== 'undefined') {
    try {
      function findUrls(obj) {
        if (!obj || typeof obj !== 'object') return;
        if (Array.isArray(obj)) { obj.forEach(findUrls); return; }
        for (const [key, val] of Object.entries(obj)) {
          if (typeof val === 'string') {
            if (val.startsWith('http') && mediaExtRe.test(val)) results.add(val);
            if (val.startsWith('//') && mediaExtRe.test(val)) results.add('https:' + val);
          } else if (typeof val === 'object') {
            findUrls(val);
          }
        }
      }
      findUrls(window.__INITIAL_STATE__);
    } catch(e) {}
  }

  // 5. Check __NEXT_DATA__ (Next.js pages)
  if (typeof window.__NEXT_DATA__ !== 'undefined') {
    try {
      const nextData = window.__NEXT_DATA__;
      function findUrls(obj) {
        if (!obj || typeof obj !== 'object') return;
        if (Array.isArray(obj)) { obj.forEach(findUrls); return; }
        for (const [key, val] of Object.entries(obj)) {
          if (typeof val === 'string') {
            if (val.startsWith('http') && mediaExtRe.test(val)) results.add(val);
          } else if (typeof val === 'object') {
            findUrls(val);
          }
        }
      }
      findUrls(nextData);
    } catch(e) {}
  }

  return JSON.stringify(Array.from(results));
})();
''';

  static const Set<String> _mediaExtensions = {
    'mp4',
    'm3u8',
    'm3u',
    'mpd',
    'ts',
    'webm',
    'flv',
    'f4v',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'ogg',
    'ogv',
    'aac',
    'm4a',
    'm4s',
    'wav',
    'mp3',
    'opus',
    'weba',
  };

  static String? _extractExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final dot = path.lastIndexOf('.');
      if (dot < 0) return null;
      final ext = path.substring(dot + 1).toLowerCase();
      // Remove query params if any got included
      final qmark = ext.indexOf('?');
      return qmark >= 0 ? ext.substring(0, qmark) : ext;
    } catch (_) {
      return null;
    }
  }
}
