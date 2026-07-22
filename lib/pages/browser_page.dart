import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl;
    _loadScripts();
    _loadRetentionMode();
  }

  Future<void> _loadRetentionMode() async {
    final enabled = await BrowserCookieService.getRetentionMode();
    setState(() => _cookieRetentionEnabled = enabled);
  }

  @override
  void dispose() {
    _urlController.dispose();

    // When cookie retention is disabled (privacy mode), delete all cookies
    // on browser close to ensure no history/cookies persist after exit.
    // When retention is enabled, cookies are preserved across sessions.
    if (!_cookieRetentionEnabled) {
      BrowserCookieService.clearAllCookies();
    }

    super.dispose();
  }

  Future<void> _loadScripts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scriptsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _scripts = list
          .map((e) => UserScript.fromMap(e as Map<String, dynamic>))
          .toList();
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

  void _injectScripts() {
    if (_webViewController == null) return;
    for (final script in _scripts) {
      if (script.code.isEmpty) continue;
      _webViewController!.evaluateJavascript(source: script.code);
    }
  }

  // ===========================================================================
  // CatCatch sniffing integration
  // ===========================================================================

  /// Inject the cat-catch JS hook script into the WebView.
  /// Called at page start time (onLoadStart) so it runs before any page scripts.
  Future<void> _injectCatCatchHook() async {
    if (_webViewController == null) return;
    try {
      await _webViewController!.evaluateJavascript(
        source: JsHookScript.script,
      );
      _catCatchHookInjected = true;
      debugPrint('[BrowserPage] CatCatch hook injected');
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
  void _onConfirmCapture(String selectedUrl) {
    debugPrint('[BrowserPage] User confirmed capture: $selectedUrl');

    // Show a snackbar with options
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已捕获: ${selectedUrl.split('/').last}'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '下载',
          onPressed: () {
            // Navigate back to the cat-catch page with the URL pre-filled
            Navigator.of(context).pop(selectedUrl);
          },
        ),
      ),
    );
  }

  /// Reset detected URLs for a new page load.
  /// The panel visibility is NOT reset here — it persists across page
  /// navigations until the user manually closes it.
  void _resetDetection() {
    setState(() {
      _detectedUrls.clear();
      _catCatchHookInjected = false;
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
      body: Stack(
        children: [
          // --- WebView + Loading ---
          Column(
            children: [
              if (_isLoading && _progress < 1.0)
                LinearProgressIndicator(value: _progress),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                  initialSettings:
                      _buildSettings(isDesktopMode: _isDesktopMode),
                  onWebViewCreated: (controller) {
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
                  },
                  onLoadStart: (controller, url) {
                    setState(() => _isLoading = true);
                    _urlController.text = url.toString();
                    // Reset detection for new page
                    _resetDetection();
                    // Inject cat-catch hook as early as possible
                    _injectCatCatchHook();
                  },
                  onLoadStop: (controller, url) {
                    setState(() => _isLoading = false);
                    _injectScripts();
                    // Re-inject cat-catch hook if somehow missed
                    if (!_catCatchHookInjected) {
                      _injectCatCatchHook();
                    }
                    // Also run a DOM scan after page load
                    controller.evaluateJavascript(
                      source: '''
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
''',
                    );
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
              left: _panelOffset.dx,
              top: _panelOffset.dy,
              child: DraggableFloatingPanel(
                key: const ValueKey('catcatch_panel'),
                visible: true,
                detectedUrls: _detectedUrls,
                onConfirmCapture: _onConfirmCapture,
                onClose: () {
                  setState(() {
                    _catCatchPanelVisible = false;
                    _detectedUrls.clear();
                  });
                },
                onDragUpdate: (delta) {
                  setState(() {
                    _panelOffset = Offset(
                      max(0.0, _panelOffset.dx + delta.dx),
                      max(0.0, _panelOffset.dy + delta.dy),
                    );
                  });
                },
              ),
            ),
        ],
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
                setState(() {
                  _isDesktopMode = !_isDesktopMode;
                });
                // Apply all mode-appropriate settings atomically before
                // reloading. This ensures useWideViewPort,
                // loadWithOverviewMode, and userAgent are all consistent
                // with the selected mode when the page starts loading.
                await _webViewController?.setSettings(
                  settings: _buildSettings(isDesktopMode: _isDesktopMode),
                );
                _webViewController?.reload();
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
              icon: Icon(
                Icons.pets,
                color: _catCatchPanelVisible
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
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
    _scripts.add(UserScript(name: '', code: '', matches: []));
    _editScript(_scripts.length - 1);
  }

  void _editScript(int index) {
    showDialog(
      context: context,
      builder: (ctx) => _ScriptEditDialog(
        script: _scripts[index],
        onSaved: (updated) {
          setState(() => _scripts[index] = updated);
          _notifyChanged();
        },
      ),
    );
  }

  void _notifyChanged() {
    widget.onScriptsChanged(List.from(_scripts));
  }
}

class _ScriptEditDialog extends StatefulWidget {
  final UserScript script;
  final void Function(UserScript) onSaved;

  const _ScriptEditDialog({required this.script, required this.onSaved});

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
            widget.onSaved(UserScript(
              name: _nameCtrl.text,
              code: _codeCtrl.text,
              matches: _matchesCtrl.text
                  .split('\n')
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList(),
            ));
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
