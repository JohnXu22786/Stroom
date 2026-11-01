import 'dart:async';
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
  Uri? _macDocumentUri;
  Key _macWebViewKey = UniqueKey();
  final List<Map<String, dynamic>> _pendingMacCommands = [];
  bool _macDocumentReady = false;
  bool _macLoadFailed = false;
  int _macLoadGeneration = 0;

  bool _trustedDocument(Uri uri) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return uri.toString() == 'about:blank' ||
          (uri.scheme == 'stroom-message' &&
              uri.toString() == _macDocumentUri?.toString());
    }
    return uri.scheme == 'file' &&
        uri.path.endsWith('/assets/vendor/dsh_message_view/index.html');
  }

  String get _macDocumentHtml {
    const bridge = '''<script>
window.addEventListener("message", (event) => {
  if (event.source === window.parent && event.data?.type === "stroom-command") {
    window.StroomMessageView?.receive(event.data.command);
  }
});
</script>''';
    final closingBody = widget.html.lastIndexOf('</body>');
    if (closingBody < 0) return '${widget.html}$bridge';
    return widget.html.replaceRange(closingBody, closingBody, bridge);
  }

  Future<void> _failMacLoadIfUnready(
    InAppWebViewController controller,
    int generation,
  ) async {
    await Future<void>.delayed(const Duration(seconds: 30));
    if (mounted &&
        identical(controller, _controller) &&
        generation == _macLoadGeneration &&
        !_macDocumentReady) {
      setState(() => _macLoadFailed = true);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.commands.addListener(_send);
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _macDocumentUri = Uri.parse('stroom-message://renderer/index.html');
    }
  }

  void _send() {
    final command = widget.commands.value;
    final controller = _controller;
    if (command == null || controller == null) return;
    if (defaultTargetPlatform == TargetPlatform.macOS && !_macDocumentReady) {
      _pendingMacCommands.add(Map<String, dynamic>.from(command));
      return;
    }
    _sendCommand(controller, command);
  }

  void _sendCommand(
    InAppWebViewController controller,
    Map<String, dynamic> command,
  ) {
    _pending = _pending.then((_) async {
      if (!mounted || !identical(controller, _controller)) return;
      await controller.evaluateJavascript(
        source: defaultTargetPlatform == TargetPlatform.macOS
            ? 'document.querySelector("iframe")?.contentWindow?.postMessage(${jsonEncode({
                    'type': 'stroom-command',
                    'command': command
                  })}, "*");'
            : 'window.StroomMessageView?.receive(${jsonEncode(command)});',
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
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.macOS &&
        _macDocumentUri == null) {
      return const SizedBox.expand();
    }

    return Stack(
      children: [
        if (defaultTargetPlatform != TargetPlatform.macOS ||
            _macDocumentUri != null)
          InAppWebView(
            key: defaultTargetPlatform == TargetPlatform.macOS
                ? _macWebViewKey
                : null,
            // WebView2 NavigateToString has a 2 MiB limit. Load the bundled file
            // on native platforms except macOS, which serves it inside a frame
            // through the plugin's custom-scheme handler.
            initialFile: defaultTargetPlatform == TargetPlatform.macOS
                ? null
                : 'assets/vendor/dsh_message_view/index.html',
            initialUrlRequest: null,
            initialData: defaultTargetPlatform == TargetPlatform.macOS
                ? InAppWebViewInitialData(
                    data: '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>
html,body,iframe{width:100%;height:100%;margin:0;border:0;overflow:hidden}
iframe{display:block}
</style></head><body><iframe src="$_macDocumentUri" title="Stroom message content"></iframe></body></html>''',
                    baseUrl: WebUri('about:blank'),
                  )
                : null,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              disableContextMenu: false,
              supportZoom: false,
              useShouldOverrideUrlLoading: true,
              javaScriptHandlersForMainFrameOnly:
                  defaultTargetPlatform != TargetPlatform.macOS,
              resourceCustomSchemes:
                  defaultTargetPlatform == TargetPlatform.macOS
                      ? ['stroom-message']
                      : const [],
            ),
            onLoadResourceWithCustomScheme: (controller, request) {
              if (defaultTargetPlatform != TargetPlatform.macOS ||
                  request.url.toString() != _macDocumentUri?.toString()) {
                return null;
              }
              if (kDebugMode) {
                debugPrint('[MessageWebHost][custom-scheme] ${request.url}');
              }
              return CustomSchemeResponse(
                data: Uint8List.fromList(utf8.encode(_macDocumentHtml)),
                contentType: 'text/html',
              );
            },
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
              if (defaultTargetPlatform == TargetPlatform.macOS &&
                  request.isForMainFrame == true &&
                  _macDocumentUri != null &&
                  request.url.toString() == _macDocumentUri.toString() &&
                  !_macDocumentReady &&
                  mounted) {
                setState(() => _macLoadFailed = true);
              }
            },
            onWebViewCreated: (controller) {
              _controller = controller;
              if (kDebugMode) {
                debugPrint(
                  '[MessageWebHost][created] platform=$defaultTargetPlatform htmlLength=${widget.html.length}',
                );
              }
              final generation = defaultTargetPlatform == TargetPlatform.macOS
                  ? ++_macLoadGeneration
                  : null;
              if (generation != null) {
                _macDocumentReady = false;
                unawaited(_failMacLoadIfUnready(controller, generation));
              }
              controller.addJavaScriptHandler(
                handlerName: 'StroomMessageView',
                callback: (JavaScriptHandlerFunctionData data) {
                  final trustedMacFrame = defaultTargetPlatform ==
                          TargetPlatform.macOS &&
                      !data.isMainFrame &&
                      data.requestUrl.toString() == _macDocumentUri?.toString();
                  final trustedFrame = defaultTargetPlatform ==
                          TargetPlatform.macOS
                      ? trustedMacFrame
                      : data.isMainFrame && _trustedDocument(data.requestUrl);
                  final staleMacView =
                      defaultTargetPlatform == TargetPlatform.macOS &&
                          (generation != _macLoadGeneration ||
                              !identical(controller, _controller));
                  final rejection = !mounted
                      ? 'unmounted'
                      : staleMacView
                          ? 'stale-webview'
                          : !trustedFrame
                              ? 'untrusted-frame:${data.requestUrl}'
                              : data.args.length != 1 || data.args.first is! Map
                                  ? 'invalid-arguments'
                                  : null;
                  if (rejection != null) {
                    if (kDebugMode) {
                      debugPrint(
                        '[MessageWebHost][handler-rejected] $rejection',
                      );
                    }
                    return;
                  }
                  if (kDebugMode) {
                    debugPrint(
                      '[MessageWebHost][handler] ${data.args.first['type']}',
                    );
                  }
                  final event = Map<String, dynamic>.from(
                    data.args.first as Map,
                  );
                  if (defaultTargetPlatform == TargetPlatform.macOS &&
                      event['type'] == 'ready') {
                    _macDocumentReady = true;
                    final controller = _controller;
                    if (controller != null) {
                      for (final command in _pendingMacCommands) {
                        _sendCommand(controller, command);
                      }
                    }
                    _pendingMacCommands.clear();
                    if (_macLoadFailed) {
                      setState(() => _macLoadFailed = false);
                    }
                  }
                  widget.onEvent(event);
                },
              );
              if (defaultTargetPlatform == TargetPlatform.macOS &&
                  _pendingMacCommands.isEmpty) {
                _send();
              }
            },
            onLoadStart: (controller, url) {
              if (kDebugMode) debugPrint('[MessageWebHost][load-start] $url');
            },
            onLoadStop: (controller, url) async {
              // macOS hosts the renderer in an iframe; only its scoped bridge
              // event can report renderer readiness.
              if (defaultTargetPlatform == TargetPlatform.macOS) return;
              final ready = await controller.evaluateJavascript(
                source: 'JSON.stringify(!!window.StroomMessageView)',
              );
              final rendererReady = ready == 'true';
              if (kDebugMode) {
                debugPrint(
                  '[MessageWebHost][load-stop] $url ready=$rendererReady',
                );
              }
              if (kDebugMode && !rendererReady) {
                try {
                  final state = await controller.evaluateJavascript(
                    source: '''
JSON.stringify({
  url: location.href,
  state: document.readyState,
  renderer: typeof window.StroomMessageView
})''',
                  );
                  debugPrint('[MessageWebHost][not-ready] $url: $state');
                } catch (error) {
                  debugPrint('[MessageWebHost][not-ready] $url: $error');
                }
              }
              if (defaultTargetPlatform == TargetPlatform.macOS &&
                  !rendererReady) {
                unawaited(
                  _failMacLoadIfUnready(controller, _macLoadGeneration),
                );
              }
              if (mounted && rendererReady) {
                _macDocumentReady = true;
                if (defaultTargetPlatform == TargetPlatform.macOS) {
                  setState(() => _macLoadFailed = false);
                }
                widget.onEvent({'type': 'ready'});
              }
            },
            shouldOverrideUrlLoading: (controller, action) async {
              final url = action.request.url;
              final trusted = url != null && _trustedDocument(url);
              if (kDebugMode) {
                debugPrint(
                  '[MessageWebHost][navigation] $url trusted=$trusted',
                );
              }
              return trusted
                  ? NavigationActionPolicy.ALLOW
                  : NavigationActionPolicy.CANCEL;
            },
          ),
        if (defaultTargetPlatform == TargetPlatform.macOS && _macLoadFailed)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(height: 8),
                    const Text('消息内容加载失败'),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _macWebViewKey = UniqueKey();
                        _macLoadGeneration++;
                        _macDocumentReady = false;
                        _macLoadFailed = false;
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
