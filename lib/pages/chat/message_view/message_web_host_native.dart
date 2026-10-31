import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MessageWebHost extends StatefulWidget {
  final String html;
  final ValueNotifier<Map<String, dynamic>?> commands;
  final void Function(Map<String, dynamic>) onEvent;

  const MessageWebHost({
    super.key,
    required this.html,
    required this.commands,
    required this.onEvent,
  });

  @override
  State<MessageWebHost> createState() => _MessageWebHostState();
}

class _MessageWebHostState extends State<MessageWebHost> {
  InAppWebViewController? _controller;
  Future<void> _pending = Future.value();
  bool _macDocumentNavigationStarted = false;

  static const _macDocumentUrl =
      'https://stroom.invalid/assets/vendor/dsh_message_view/index.html';

  bool _trustedDocument(Uri uri) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      // WKWebView can report about:blank while loading HTML supplied as data.
      return uri.toString() == 'about:blank' ||
          (uri.scheme == 'https' &&
              uri.host == 'stroom.invalid' &&
              uri.path.endsWith('/assets/vendor/dsh_message_view/index.html'));
    }
    return uri.scheme == 'file' &&
        uri.path.endsWith('/assets/vendor/dsh_message_view/index.html');
  }

  bool _isMacDocumentUrl(WebUri? url) =>
      url?.scheme == 'https' &&
      url?.host == 'stroom.invalid' &&
      url?.path.endsWith('/assets/vendor/dsh_message_view/index.html') == true;

  Future<void> _loadMacDocument(InAppWebViewController controller) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      if (!mounted ||
          !identical(controller, _controller) ||
          _macDocumentNavigationStarted) {
        return;
      }

      try {
        if (kDebugMode) {
          debugPrint(
            '[MessageWebHost][load-data-start] macOS attempt=${attempt + 1}',
          );
        }
        await controller.loadData(
          data: widget.html,
          baseUrl: WebUri(_macDocumentUrl),
        );
        if (kDebugMode) {
          debugPrint(
            '[MessageWebHost][load-data-sent] macOS attempt=${attempt + 1}',
          );
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            '[MessageWebHost][load-error] macOS attempt=${attempt + 1}: $error',
          );
        }
      }

      if (attempt < 4 && !_macDocumentNavigationStarted) {
        await Future<void>.delayed(
          Duration(milliseconds: 250 << attempt.clamp(0, 3)),
        );
      }
    }

    if (mounted &&
        identical(controller, _controller) &&
        !_macDocumentNavigationStarted &&
        kDebugMode) {
      debugPrint(
        '[MessageWebHost][load-timeout] macOS navigation did not start',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    widget.commands.addListener(_send);
  }

  void _send() {
    final command = widget.commands.value;
    final controller = _controller;
    if (command == null || controller == null) return;
    _pending = _pending.then((_) async {
      if (!mounted || !identical(controller, _controller)) return;
      await controller.evaluateJavascript(
        source: 'window.StroomMessageView?.receive(${jsonEncode(command)});',
      );
    }).catchError((Object error) {
      if (mounted) debugPrint('[MessageWebHost] $error');
    });
  }

  @override
  void dispose() {
    widget.commands.removeListener(_send);
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InAppWebView(
        // WebView2 NavigateToString has a 2 MiB limit. Load the bundled file on
        // native platforms except macOS, whose plugin cannot resolve Flutter
        // asset URLs from the app bundle. Give the in-memory HTML a reserved,
        // non-routable origin so the main-frame guard can validate it below.
        initialFile: defaultTargetPlatform == TargetPlatform.macOS
            ? null
            : 'assets/vendor/dsh_message_view/index.html',
        initialData: null,
        // Leave the plugin origin allow-list unset: WKWebView file URLs have
        // no host. The handler below validates this exact main-frame URL.
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          transparentBackground: true,
          disableContextMenu: false,
          supportZoom: false,
          useShouldOverrideUrlLoading: true,
          javaScriptHandlersForMainFrameOnly: true,
        ),
        onConsoleMessage: (controller, message) {
          if (kDebugMode) {
            debugPrint('[MessageWebHost][console] ${message.message}');
          }
        },
        onReceivedError: (controller, request, error) {
          if (kDebugMode && request.isForMainFrame == true) {
            debugPrint(
              '[MessageWebHost][load-error] ${request.url}: ${error.description}',
            );
          }
        },
        onWebViewCreated: (controller) {
          _controller = controller;
          if (kDebugMode) {
            debugPrint(
              '[MessageWebHost][created] platform=$defaultTargetPlatform htmlLength=${widget.html.length}',
            );
          }
          if (defaultTargetPlatform == TargetPlatform.macOS) {
            _macDocumentNavigationStarted = false;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _loadMacDocument(controller);
            });
            // Platform-view creation can happen between frames. Schedule the
            // post-frame load, then retry only until WKWebView starts navigating.
            WidgetsBinding.instance.ensureVisualUpdate();
          }
          controller.addJavaScriptHandler(
            handlerName: 'StroomMessageView',
            callback: (JavaScriptHandlerFunctionData data) {
              final rejection = !mounted
                  ? 'unmounted'
                  : !data.isMainFrame
                      ? 'subframe'
                      : !_trustedDocument(data.requestUrl)
                          ? 'untrusted-url:${data.requestUrl}'
                          : data.args.length != 1 || data.args.first is! Map
                              ? 'invalid-arguments'
                              : null;
              if (rejection != null) {
                if (kDebugMode) {
                  debugPrint('[MessageWebHost][handler-rejected] $rejection');
                }
                return;
              }
              if (kDebugMode) {
                debugPrint(
                    '[MessageWebHost][handler] ${data.args.first['type']}');
              }
              widget.onEvent(Map<String, dynamic>.from(data.args.first as Map));
            },
          );
        },
        onLoadStart: (controller, url) {
          if (defaultTargetPlatform == TargetPlatform.macOS &&
              _isMacDocumentUrl(url)) {
            _macDocumentNavigationStarted = true;
          }
          if (kDebugMode) debugPrint('[MessageWebHost][load-start] $url');
        },
        onLoadStop: (controller, url) async {
          final ready = await controller.evaluateJavascript(
            source: '!!window.StroomMessageView',
          );
          if (kDebugMode) {
            debugPrint('[MessageWebHost][load-stop] $url ready=$ready');
          }
          if (kDebugMode && ready != true) {
            try {
              final state = await controller.evaluateJavascript(
                source: '''
JSON.stringify({
  url: location.href,
  state: document.readyState,
  renderer: typeof window.StroomMessageView,
  root: document.getElementById("root")?.textContent
})''',
              );
              debugPrint('[MessageWebHost][not-ready] $url: $state');
            } catch (error) {
              debugPrint('[MessageWebHost][not-ready] $url: $error');
            }
          }
          if (mounted && ready == true) {
            _macDocumentNavigationStarted = true;
            widget.onEvent({'type': 'ready'});
          }
        },
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url;
          final trusted = url != null && _trustedDocument(url);
          if (kDebugMode) {
            debugPrint('[MessageWebHost][navigation] $url trusted=$trusted');
          }
          return trusted
              ? NavigationActionPolicy.ALLOW
              : NavigationActionPolicy.CANCEL;
        },
      );
}
