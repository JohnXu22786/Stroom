import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../catcatch/engine/js_hook_script.dart';
import '../catcatch/widgets/draggable_floating_panel.dart';
import '../services/browser_cookie_service.dart';

const _scriptsKey = 'browser_user_scripts';

/// Desktop user agent string for desktop-mode browsing.
const _desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// Mobile user agent string for mobile-mode browsing.
const _mobileUserAgent =
    'Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

/// Builds the [InAppWebViewSettings] appropriate for the given mode.
///
/// Key difference from the previous always-wide-viewport approach:
/// - **Mobile mode** ([isDesktopMode] == false): Uses the device viewport
///   (`useWideViewPort: false`) so mobile-optimized pages render at the
///   actual device width. This ensures touch/click coordinates map correctly
///   to visual elements, fixing issues where buttons like Baidu's search
///   button were unclickable.
/// - **Desktop mode** ([isDesktopMode] == true): Uses a wide viewport
///   (`useWideViewPort: true` with `loadWithOverviewMode: true`) so
///   desktop-optimized pages render correctly at ~1280px viewport width
///   and are properly zoomed to fit.
InAppWebViewSettings _buildSettings({required bool isDesktopMode}) {
  return InAppWebViewSettings(
    javaScriptEnabled: true,
    // Privacy: disable persistent DOM storage.
    // All data stays in memory and is discarded when the browser closes.
    domStorageEnabled: false,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
    // Mobile mode: use device viewport for correct touch targeting.
    // Desktop mode: use wide viewport to show full desktop pages.
    useWideViewPort: isDesktopMode,
    // Desktop mode: zoom out to fit the wide page in the available width.
    loadWithOverviewMode: isDesktopMode,
    supportZoom: true,
    // Android overscroll indicator; does not affect touch event handling.
    overScrollMode: OverScrollMode.ALWAYS,
    // Enable scrollbars for scrollable content.
    verticalScrollBarEnabled: true,
    horizontalScrollBarEnabled: true,
    userAgent: isDesktopMode ? _desktopUserAgent : _mobileUserAgent,
  );
}

class UserScript {
  final String name;
  final String code;
  final List<String> matches;

  UserScript({required this.name, required this.code, required this.matches});

  Map<String, dynamic> toMap() => {
        'name': name,
        'code': code,
        'matches': matches,
      };

  factory UserScript.fromMap(Map<String, dynamic> map) => UserScript(
        name: map['name'] as String? ?? '',
        code: map['code'] as String? ?? '',
        matches: (map['matches'] as List?)?.cast<String>() ?? [],
      );

  /// Whether [url] matches any of this script's match patterns
  /// (e.g. `*://*.example.com/*`).
  ///
  /// An empty match list — or an empty pattern — means "run everywhere".
  bool matchesUrl(String url) {
    if (matches.isEmpty) return true;
    for (final pattern in matches) {
      final trimmed = pattern.trim();
      if (trimmed.isEmpty) return true;
      if (_urlMatchesPattern(url, trimmed)) return true;
    }
    return false;
  }

  /// Matches [url] against a user-script-style glob pattern where `*` is the
  /// only wildcard.
  ///
  /// Matching is per URL component (scheme / host / path) so a host wildcard
  /// can never bleed into the path (`https://attacker.com/x.example.com/y`
  /// does NOT match `*://*.example.com/*`), and follows Chrome match-pattern
  /// semantics: scheme and host are case-insensitive (the path is not), a
  /// leading `*.` host wildcard also matches the apex domain, and ports and
  /// userinfo are ignored.
  static bool _urlMatchesPattern(String url, String pattern) {
    String globToRegex(String value, {required bool host}) {
      var v = value;
      final apexWildcard = host && v.startsWith('*.');
      if (apexWildcard) v = v.substring(2);
      var escaped = RegExp.escape(v).replaceAll(r'\*', '.*');
      if (host && apexWildcard) {
        escaped = '([^/]*\\.)?$escaped';
      }
      return '^$escaped\$';
    }

    final urlUri = Uri.tryParse(url);
    if (urlUri == null || !urlUri.hasScheme) return false;

    var pat = pattern.trim();
    // A scheme-less pattern matches any scheme. The scheme is a leading
    // token, not just the first "://" (which may appear inside a query).
    // A path-only pattern (leading "/") matches any host.
    final schemeMatch = RegExp(r'^([a-zA-Z0-9+.*-]+)://').firstMatch(pat);
    if (schemeMatch == null) {
      pat = pat.startsWith('/') ? '*://*$pat' : '*://$pat';
    }
    final schemeSep = pat.indexOf('://');
    assert(schemeSep > 0, 'a scheme-less pattern is always prefixed');
    final schemePat = pat.substring(0, schemeSep);
    final rest = pat.substring(schemeSep + 3);
    final slash = rest.indexOf('/');
    var hostPat = slash < 0 ? rest : rest.substring(0, slash);
    // A pattern without an explicit path matches any path.
    final pathPat = slash < 0 ? '/*' : rest.substring(slash);
    // Strip userinfo and port from the host pattern: Uri.host excludes them,
    // and Chrome match-pattern semantics ignore them too.
    final atSign = hostPat.lastIndexOf('@');
    if (atSign >= 0) hostPat = hostPat.substring(atSign + 1);
    hostPat = hostPat.replaceFirst(RegExp(r':\d+$'), '');
    // Uri.host strips IPv6 brackets — strip them from the pattern too.
    if (hostPat.startsWith('[') && hostPat.endsWith(']')) {
      hostPat = hostPat.substring(1, hostPat.length - 1);
    }

    final schemeOk = RegExp(globToRegex(schemePat.toLowerCase(), host: false))
        .hasMatch(urlUri.scheme);
    if (!schemeOk) return false;
    // An empty host pattern (e.g. "file:///*") only matches URLs with no
    // host (file:// URLs); any other scheme with a real host fails.
    if (hostPat.isNotEmpty) {
      final hostOk = RegExp(globToRegex(hostPat.toLowerCase(), host: true))
          .hasMatch(urlUri.host);
      if (!hostOk) return false;
    } else if (urlUri.host.isNotEmpty) {
      return false;
    }

    final urlPathAndQuery = '${urlUri.path.isEmpty ? '/' : urlUri.path}'
        '${urlUri.hasQuery ? '?${urlUri.query}' : ''}';
    // The path is matched case-sensitively (Chrome semantics).
    return RegExp(globToRegex(pathPat, host: false)).hasMatch(urlPathAndQuery);
  }
}

class BrowserPage extends StatefulWidget {
  final String initialUrl;
  const BrowserPage({super.key, this.initialUrl = 'https://www.google.com'});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? _webViewController;
  final _urlController = TextEditingController();
  bool _isLoading = false;
  double _progress = 0;
  List<UserScript> _scripts = [];

  /// Whether to use desktop user agent.
  bool _isDesktopMode = false;

  // ===========================================================================
  // CatCatch sniffing state
  // ===========================================================================

  /// URLs detected by the JS hook in the WebView.
  final List<String> _detectedUrls = [];

  /// Whether the cat-catch hook has been injected for the current page.
  bool _catCatchHookInjected = false;

  /// The URL the cat-catch hook was injected for. Used to re-inject after
  /// navigation when the flag is stale (e.g. an earlier injection completed
  /// after a newer page started loading).
  String? _catCatchHookInjectedFor;

  /// The URL of the most recently loaded page (or about to load), used for
  /// user-script match rules and cookie domain tracking.
  String _currentUrl = '';

  /// Whether the cat-catch floating panel is currently visible.
  /// The panel persists its visibility state across page navigations
  /// and is only hidden when the user manually closes it or toggles
  /// the show/hide button in the bottom bar.
  bool _catCatchPanelVisible = true;

  /// Whether cookie retention mode is enabled.
  /// When enabled, cookies are not deleted on browser close.
  bool _cookieRetentionEnabled = false;

  /// Current position offset of the floating panel, managed by the parent
  /// (BrowserPage) instead of internally by DraggableFloatingPanel.
  /// This avoids the need for a full-screen compositing layer inside the
  /// panel, which would interfere with the WebView's pointer event routing.
  Offset _panelOffset = const Offset(8, 8);

  /// The size of the body area the panel floats over (between the AppBar
  /// and the bottom bar). Captured by the body [LayoutBuilder] and used to
  /// clamp the panel offset; clamped against this (not the full screen) so
  /// the panel can never slide under the bars and become unreachable.
  Size _panelAreaSize = Size.zero;

  /// Incremented on every page navigation; passed to the floating panel so
  /// it can drop a selection made on the previous page even when the new
  /// page detects the same number of URLs.
  int _detectionEpoch = 0;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl;
    _loadScripts();
    _loadRetentionMode();
  }

  Future<void> _loadRetentionMode() async {
    final enabled = await BrowserCookieService.getRetentionMode();
    if (!mounted) return;
    setState(() => _cookieRetentionEnabled = enabled);
  }

  /// Restores persisted cookies to the WebView (if retention is enabled).
  /// Should be called after the WebView is created, BEFORE the initial page
  /// is loaded, so the first request carries the restored cookies.
  Future<void> _restoreCookies() async {
    await BrowserCookieService.restoreCookiesFromFile();
  }

  /// Persists current cookies to file (if retention is enabled).
  /// Should be called after page loads and on browser close.
  Future<void> _persistCookies() async {
    await BrowserCookieService.persistCookiesToFile();
  }

  @override
  void dispose() {
    _urlController.dispose();

    // When cookie retention is enabled, persist cookies to file so they
    // survive the browser close. When disabled, clear everything.
    // clearAllCookies already clears the persisted store internally.
    // Read the persisted value here (not the possibly-stale widget state)
    // so a toggle that was still in flight when the page closed wins.
    BrowserCookieService.getRetentionMode().then((enabled) {
      if (enabled) {
        BrowserCookieService.persistCookiesToFile();
      } else {
        BrowserCookieService.clearAllCookies();
      }
    });

    super.dispose();
  }

  Future<void> _loadScripts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scriptsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _scripts = decoded
          .whereType<Map<String, dynamic>>()
          .map(UserScript.fromMap)
          .toList();
    } catch (e) {
      debugPrint('_loadScripts failed: $e');
    }
  }

  Future<void> _saveScripts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _scriptsKey, jsonEncode(_scripts.map((s) => s.toMap()).toList()));
    } catch (e) {
      debugPrint('_saveScripts failed: $e');
    }
  }

  /// Injects all user scripts whose match rules apply to [_currentUrl].
  /// An empty match list means "run everywhere".
  void _injectScripts() {
    if (_webViewController == null) return;
    for (final script in _scripts) {
      if (script.code.isEmpty) continue;
      if (!script.matchesUrl(_currentUrl)) continue;
      _safeEvaluate(script.code);
    }
  }

  /// Runs [source] in the WebView, swallowing errors that occur when the
  /// page is torn down mid-evaluation (rapid navigation, reload).
  void _safeEvaluate(String source) {
    final controller = _webViewController;
    if (controller == null) return;
    controller.evaluateJavascript(source: source).catchError((Object e) {
      debugPrint('[BrowserPage] evaluateJavascript error: $e');
    });
  }

  // ===========================================================================
  // CatCatch sniffing integration
  // ===========================================================================

  /// Inject the cat-catch JS hook script into the WebView.
  /// Called at page start time (onLoadStart) so it runs before any page scripts.
  Future<void> _injectCatCatchHook(String url) async {
    if (_webViewController == null) return;
    try {
      await _webViewController!.evaluateJavascript(
        source: JsHookScript.script,
      );
      // Only record the injection if this page is still current — a slow
      // injection for a previous page must not mark the current one as done.
      if (url == _currentUrl) {
        _catCatchHookInjected = true;
        _catCatchHookInjectedFor = url;
        debugPrint('[BrowserPage] CatCatch hook injected for $url');
      }
    } catch (e) {
      _catCatchHookInjected = false;
      debugPrint('[BrowserPage] Failed to inject CatCatch hook: $e');
    }
  }

  /// Handle a message received from the JS hook's CatCatchChannel.
  void _onCatCatchMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null || url.isEmpty) return;

      debugPrint('[BrowserPage] CatCatch sniffed: $url');
      setState(() {
        // Dedup: only add if not already in list
        if (!_detectedUrls.contains(url)) {
          _detectedUrls.add(url);
        }
      });
    } catch (e) {
      debugPrint('[BrowserPage] CatCatch message parse error: $e');
    }
  }

  /// User tapped "Confirm Capture" on the floating panel.
  ///
  /// Contract: the captured URL is handed back to the page that pushed this
  /// one via `Navigator.pop(selectedUrl)`. The caller (catcatch_page) is
  /// expected to await the push result and pre-fill the download form.
  void _onConfirmCapture(String selectedUrl) {
    debugPrint('[BrowserPage] User confirmed capture: $selectedUrl');

    // Short display name; falls back to the URL for trailing-slash URLs.
    final shortName = selectedUrl.split('/').last;
    final displayName = shortName.isEmpty ? selectedUrl : shortName;

    // Show a snackbar with options
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已捕获: $displayName'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '下载',
          onPressed: () {
            // Navigate back to the cat-catch page with the URL pre-filled.
            // Guard against being the root route (pop is a no-op then).
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop(selectedUrl);
            }
          },
        ),
      ),
    );
  }

  /// Reset detected URLs for a new page load.
  /// The panel visibility is NOT reset here — it persists across page
  /// navigations until the user manually closes it. The detection epoch
  /// bumps so the panel drops any selection from the previous page.
  void _resetDetection() {
    setState(() {
      _detectedUrls.clear();
      _catCatchHookInjected = false;
      _detectionEpoch++;
    });
  }

  void _goToUrl(String url) {
    var uri = url.trim();
    if (uri.isEmpty) return;
    if (!uri.startsWith('http://') && !uri.startsWith('https://')) {
      uri = 'https://$uri';
    }
    _urlController.text = uri;
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(uri)));
  }

  /// Clamps the floating panel offset so the panel's header stays within the
  /// body area. Re-applied on every build to survive rotation/resize; falls
  /// back to the screen size before the first layout.
  Offset _clampedPanelOffset() {
    final size = _panelAreaSize == Size.zero
        ? MediaQuery.sizeOf(context)
        : _panelAreaSize;
    return Offset(
      _panelOffset.dx
          .clamp(0.0, max(0.0, size.width - DraggableFloatingPanel.panelWidth)),
      _panelOffset.dy.clamp(0.0, max(0.0, size.height - 48)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: TextField(
          controller: _urlController,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: '输入网址',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18),
              onPressed: () => _goToUrl(_urlController.text),
            ),
          ),
          textInputAction: TextInputAction.go,
          onSubmitted: _goToUrl,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension, size: 20),
            tooltip: '用户脚本',
            onPressed: _showScriptManager,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Cache the real body bounds (between AppBar and bottom bar) for
          // panel-offset clamping.
          _panelAreaSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              // --- WebView + Loading ---
              Column(
                children: [
                  if (_isLoading && _progress < 1.0)
                    LinearProgressIndicator(value: _progress),
                  Expanded(
                    child: InAppWebView(
                      // The initial page is loaded explicitly in onWebViewCreated
                      // AFTER persisted cookies are restored, so the first request
                      // carries them (restore no-ops when retention is disabled).
                      initialUrlRequest: null,
                      initialSettings:
                          _buildSettings(isDesktopMode: _isDesktopMode),
                      onWebViewCreated: (controller) async {
                        _webViewController = controller;

                        // Register JavaScript handler for CatCatchChannel
                        controller.addJavaScriptHandler(
                          handlerName: 'CatCatchChannel',
                          callback: (args) {
                            if (args.isNotEmpty && args.first is String) {
                              _onCatCatchMessage(args.first as String);
                            }
                          },
                        );

                        // Restore persisted cookies before the first page load.
                        // A restore failure must not block the initial
                        // navigation (restore itself already no-ops when
                        // retention is disabled).
                        try {
                          await _restoreCookies();
                        } catch (e) {
                          debugPrint('[BrowserPage] cookie restore failed: $e');
                        }
                        if (!mounted) return;
                        try {
                          await controller.loadUrl(
                            urlRequest:
                                URLRequest(url: WebUri(widget.initialUrl)),
                          );
                        } catch (e) {
                          debugPrint('[BrowserPage] initial load failed: $e');
                        }
                      },
                      onLoadStart: (controller, url) {
                        final urlString = url.toString();
                        setState(() {
                          _isLoading = true;
                          _progress = 0;
                        });
                        _currentUrl = urlString;
                        _urlController.text = urlString;
                        // Reset detection for new page
                        _resetDetection();
                        // Inject cat-catch hook as early as possible
                        _injectCatCatchHook(urlString);
                      },
                      onLoadStop: (controller, url) {
                        setState(() => _isLoading = false);
                        _currentUrl = url.toString();
                        // Track the host so cookies can be persisted/displayed
                        // even on platforms without CookieManager.getAllCookies.
                        BrowserCookieService.noteVisitedUrl(url.toString());
                        _injectScripts();
                        // Re-inject cat-catch hook if somehow missed or if an
                        // earlier injection was for a previous page
                        if (!_catCatchHookInjected ||
                            _catCatchHookInjectedFor != url.toString()) {
                          _injectCatCatchHook(url.toString());
                        }
                        // Persist cookies after page load (if retention enabled)
                        _persistCookies();
                        // Also run a DOM scan after page load
                        _safeEvaluate('''
(function() {
  document.querySelectorAll('video, audio').forEach(function(el) {
    var src = el.currentSrc || el.src || '';
    if (src && src.startsWith('http')) {
      window.flutter_inappwebview.callHandler('CatCatchChannel', JSON.stringify({
        url: src,
        method: 'GET',
        initiator: window.location.href,
        mimeType: el.tagName === 'VIDEO' ? 'video/*' : 'audio/*'
      }));
    }
  });
})();
''');
                      },
                      onProgressChanged: (controller, progress) {
                        setState(() => _progress = progress / 100.0);
                      },
                    ),
                  ),
                ],
              ),

              // --- Draggable Floating Panel ---
              // Positioned by the parent (BrowserPage) rather than internally
              // by the panel itself. This avoids the panel creating a full-screen
              // compositing layer (Stack + IgnorePointer + SizedBox.expand())
              // that interferes with the WebView's platform-level event routing.
              // The panel now only renders within its own natural content bounds.
              if (_catCatchPanelVisible)
                Positioned(
                  // Clamp on every build (not only while dragging) so the panel
                  // can never be lost off-screen, including after rotation or
                  // window resize.
                  left: _clampedPanelOffset().dx,
                  top: _clampedPanelOffset().dy,
                  child: DraggableFloatingPanel(
                    key: const ValueKey('catcatch_panel'),
                    visible: true,
                    detectionEpoch: _detectionEpoch,
                    detectedUrls: _detectedUrls,
                    onConfirmCapture: _onConfirmCapture,
                    onClose: () {
                      setState(() {
                        _catCatchPanelVisible = false;
                        _detectedUrls.clear();
                      });
                    },
                    onDragUpdate: (delta) {
                      // Start from the RENDERED (clamped) offset and clamp again
                      // with the same bounds used at render time. This keeps the
                      // stored offset free of overshoot AND avoids a dead zone
                      // when the window shrinks (rotation/resize) while the
                      // stored offset is stale beyond the new bounds.
                      final size = _panelAreaSize == Size.zero
                          ? MediaQuery.sizeOf(context)
                          : _panelAreaSize;
                      final current = _clampedPanelOffset();
                      setState(() {
                        _panelOffset = Offset(
                          (current.dx + delta.dx).clamp(
                              0.0,
                              max(
                                  0.0,
                                  size.width -
                                      DraggableFloatingPanel.panelWidth)),
                          (current.dy + delta.dy)
                              .clamp(0.0, max(0.0, size.height - 48)),
                        );
                      });
                    },
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _webViewController?.goBack(),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _webViewController?.goForward(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _webViewController?.reload(),
            ),
            // Desktop / Mobile UA toggle
            IconButton(
              icon: Icon(
                _isDesktopMode ? Icons.phone_android : Icons.desktop_windows,
                size: 20,
              ),
              tooltip: _isDesktopMode ? '切换到手机版' : '切换到电脑版',
              onPressed: () async {
                final controller = _webViewController;
                if (controller == null) return;
                final messenger = ScaffoldMessenger.of(context);
                setState(() {
                  _isDesktopMode = !_isDesktopMode;
                });
                // Apply all mode-appropriate settings atomically before
                // reloading. This ensures useWideViewPort,
                // loadWithOverviewMode, and userAgent are all consistent
                // with the selected mode when the page starts loading.
                try {
                  await controller.setSettings(
                    settings: _buildSettings(isDesktopMode: _isDesktopMode),
                  );
                  controller.reload();
                } catch (e) {
                  debugPrint('[BrowserPage] UA switch failed: $e');
                  if (mounted) {
                    setState(() => _isDesktopMode = !_isDesktopMode);
                  }
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      _isDesktopMode ? '已切换到电脑版UA' : '已切换到手机版UA',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            // Cookie retention toggle
            IconButton(
              icon: Icon(
                Icons.cookie,
                color: _cookieRetentionEnabled
                    ? Colors.orange
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              tooltip: _cookieRetentionEnabled
                  ? 'Cookies持久化(已开启)'
                  : 'Cookies持久化(已关闭)',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final newValue =
                    await BrowserCookieService.toggleRetentionMode();
                if (!mounted) return;
                setState(() => _cookieRetentionEnabled = newValue);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      newValue ? '已启用Cookies持久化' : '已关闭Cookies持久化',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            // CatCatch panel show/hide toggle
            IconButton(
              icon: SvgPicture.asset(
                'assets/images/cat_head.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  _catCatchPanelVisible
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  BlendMode.srcIn,
                ),
              ),
              tooltip: _catCatchPanelVisible ? '隐藏嗅探面板' : '显示嗅探面板',
              onPressed: () {
                setState(() {
                  _catCatchPanelVisible = !_catCatchPanelVisible;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showScriptManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ScriptManagerSheet(
        scripts: _scripts,
        onScriptsChanged: (scripts) {
          setState(() => _scripts = scripts);
          _saveScripts();
          _injectScripts();
        },
      ),
    );
  }
}

// =============================================================================
// Script Manager (unchanged from original)
// =============================================================================

class _ScriptManagerSheet extends StatefulWidget {
  final List<UserScript> scripts;
  final void Function(List<UserScript>) onScriptsChanged;

  const _ScriptManagerSheet({
    required this.scripts,
    required this.onScriptsChanged,
  });

  @override
  State<_ScriptManagerSheet> createState() => _ScriptManagerSheetState();
}

class _ScriptManagerSheetState extends State<_ScriptManagerSheet> {
  late List<UserScript> _scripts;

  @override
  void initState() {
    super.initState();
    _scripts = List.from(widget.scripts);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            AppBar(
              title: const Text('用户脚本'),
              automaticallyImplyLeading: false,
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                  onPressed: _addScript,
                ),
              ],
            ),
            Expanded(
              child: _scripts.isEmpty
                  ? const Center(
                      child: Text('暂无脚本，点击"添加"创建'),
                    )
                  : ListView.builder(
                      itemCount: _scripts.length,
                      itemBuilder: (ctx, i) {
                        final s = _scripts[i];
                        return ListTile(
                          title: Text(s.name.isNotEmpty ? s.name : '未命名脚本'),
                          subtitle: Text('${s.matches.length} 个匹配规则'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () {
                              setState(() => _scripts.removeAt(i));
                              _notifyChanged();
                            },
                          ),
                          onTap: () => _editScript(i),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _addScript() {
    _editScript(-1);
  }

  Future<void> _editScript(int index) async {
    final isNew = index < 0;
    final script =
        isNew ? UserScript(name: '', code: '', matches: []) : _scripts[index];
    final updated = await showDialog<UserScript>(
      context: context,
      builder: (ctx) => _ScriptEditDialog(script: script),
    );
    // Only commit when the user saved; cancelling leaves the list unchanged.
    if (updated == null) return;
    setState(() {
      if (isNew) {
        _scripts.add(updated);
      } else {
        _scripts[index] = updated;
      }
    });
    _notifyChanged();
  }

  void _notifyChanged() {
    widget.onScriptsChanged(List.from(_scripts));
  }
}

class _ScriptEditDialog extends StatefulWidget {
  final UserScript script;

  const _ScriptEditDialog({required this.script});

  @override
  State<_ScriptEditDialog> createState() => _ScriptEditDialogState();
}

class _ScriptEditDialogState extends State<_ScriptEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _matchesCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.script.name);
    _codeCtrl = TextEditingController(text: widget.script.code);
    _matchesCtrl =
        TextEditingController(text: widget.script.matches.join('\n'));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _matchesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑脚本'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '脚本名称',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '脚本代码 (JavaScript)',
                  border: OutlineInputBorder(),
                  hintText:
                      '// ==UserScript==\n// @name\n// @match *://*/*\n// ==/UserScript==\n\nconsole.log("hello");',
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _matchesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '匹配网址 (每行一个)',
                  border: OutlineInputBorder(),
                  hintText: '*://*.example.com/*',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              UserScript(
                name: _nameCtrl.text,
                code: _codeCtrl.text,
                matches: _matchesCtrl.text
                    .split('\n')
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty)
                    .toList(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
