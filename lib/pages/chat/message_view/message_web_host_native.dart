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

  bool _trustedDocument(Uri uri) =>
      uri.path.endsWith('/assets/vendor/dsh_message_view/index.html') &&
      (defaultTargetPlatform == TargetPlatform.macOS
          ? uri.scheme == 'https' && uri.host == 'stroom.invalid'
          : uri.scheme == 'file');

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
        initialData: defaultTargetPlatform == TargetPlatform.macOS
            ? InAppWebViewInitialData(
                data: widget.html,
                baseUrl: WebUri(
                  'https://stroom.invalid/assets/vendor/dsh_message_view/index.html',
                ),
              )
            : null,
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
          if (kDebugMode) debugPrint('[MessageWebHost][created]');
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
          if (mounted && ready == true) widget.onEvent({'type': 'ready'});
        },
        shouldOverrideUrlLoading: (controller, action) async =>
            action.request.url != null && _trustedDocument(action.request.url!)
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL,
      );
}
