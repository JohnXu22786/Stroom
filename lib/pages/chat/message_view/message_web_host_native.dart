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
  bool _macDocumentNavigationStarted = false;
  bool _macDocumentReady = false;
  bool _macLoadInProgress = false;
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

  bool _isMacDocumentUrl(WebUri? url) =>
      url?.scheme == 'stroom-message' &&
      url.toString() == _macDocumentUri?.toString();

  Future<void> _loadMacDocument(InAppWebViewController controller) async {
    if (_macLoadInProgress || !mounted || !identical(controller, _controller)) {
      return;
    }
    _macLoadInProgress = true;
    _macLoadGeneration++;
    _macLoadFailed = false;
    _macDocumentReady = false;
    setState(() {});

    try {
      final documentUri = _macDocumentUri;
      if (documentUri == null) return;

      _macDocumentNavigationStarted = false;
      var macNavigationPending = false;

      // Load the self-contained HTML through the registered custom URL scheme.
      for (var attempt = 0; attempt < 8; attempt++) {
        if (!mounted || !identical(controller, _controller) || _macLoadFailed) {
          return;
        }
        if (_macDocumentNavigationStarted) {
          macNavigationPending = true;
          break;
        }
        try {
          if (kDebugMode) {
            debugPrint(
              '[MessageWebHost][load-start-request] macOS attempt=${attempt + 1}',
            );
          }
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri.uri(documentUri)),
          );
          if (_macLoadFailed) break;
          final currentUrl = await controller.getUrl();
          final isLoading = await controller.isLoading();
          if (kDebugMode) {
            debugPrint(
              '[MessageWebHost][load-request-sent] macOS attempt=${attempt + 1}',
            );
            debugPrint(
              '[MessageWebHost][load-state] macOS attempt=${attempt + 1} '
              'url=$currentUrl isLoading=$isLoading',
            );
          }
          // WKWebView can report the requested URL and isLoading before it
          // emits a navigation callback. Keep retrying until the callback
          // confirms that the document navigation actually started.
          if (_macDocumentNavigationStarted) {
            macNavigationPending = true;
            break;
          }
          if (isLoading) {
            // WKWebView may report the target URL and loading state before it
            // delivers its navigation callback. Reissuing loadUrl here can
            // restart the same file navigation and prevent the page from ever
            // reaching the ready bridge.
            macNavigationPending = true;
            break;
          }
          if (_macLoadFailed) break;
        } catch (error) {
          if (kDebugMode) {
            debugPrint(
              '[MessageWebHost][load-error] macOS attempt=${attempt + 1}: $error',
            );
          }
        }

        if (attempt < 7 && !_macDocumentNavigationStarted) {
          await Future<void>.delayed(
            Duration(milliseconds: 250 << attempt.clamp(0, 4)),
          );
        }
      }

      if (macNavigationPending &&
          mounted &&
          identical(controller, _controller) &&
          !_macDocumentReady &&
          !_macLoadFailed) {
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        Object? lastReadyProbe;
        while (DateTime.now().isBefore(deadline) &&
            mounted &&
            identical(controller, _controller) &&
            !_macDocumentReady &&
            !_macLoadFailed) {
          try {
            lastReadyProbe = await controller.evaluateJavascript(
              source: 'JSON.stringify(!!window.StroomMessageView)',
            );
            if (lastReadyProbe == true || lastReadyProbe == 'true') {
              _macDocumentNavigationStarted = true;
              _macDocumentReady = true;
              widget.onEvent({'type': 'ready'});
              break;
            }
          } catch (_) {
            // WKWebView may reject JavaScript evaluation while the first
            // provisional navigation is still in progress.
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (mounted &&
            identical(controller, _controller) &&
            !_macDocumentReady &&
            !_macLoadFailed) {
          if (kDebugMode) {
            debugPrint(
              '[MessageWebHost][load-timeout] macOS document did not become ready; '
              'last probe=$lastReadyProbe',
            );
          }
          setState(() => _macLoadFailed = true);
        }
      }

      if (mounted &&
          identical(controller, _controller) &&
          !_macDocumentNavigationStarted &&
          !_macDocumentReady) {
        if (kDebugMode) {
          debugPrint(
            '[MessageWebHost][load-timeout] macOS navigation did not start',
          );
        }
        setState(() => _macLoadFailed = true);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[MessageWebHost][load-error] macOS document setup: $error');
      }
      if (mounted && identical(controller, _controller)) {
        setState(() => _macLoadFailed = true);
      }
    } finally {
      if (mounted && identical(controller, _controller)) {
        _macLoadInProgress = false;
        setState(() {});
      }
    }
  }

  Future<void> _failMacLoadIfUnready(
    InAppWebViewController controller,
    int generation,
  ) async {
    await Future<void>.delayed(const Duration(seconds: 5));
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
            // WebView2 NavigateToString has a 2 MiB limit. Load the bundled file
            // on native platforms except macOS, which serves it through the
            // plugin's custom-scheme handler to avoid WKWebView file navigation.
            initialFile: defaultTargetPlatform == TargetPlatform.macOS
                ? null
                : 'assets/vendor/dsh_message_view/index.html',
            initialUrlRequest: null,
            initialData: null,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              disableContextMenu: false,
              supportZoom: false,
              useShouldOverrideUrlLoading: true,
              javaScriptHandlersForMainFrameOnly: true,
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
                data: Uint8List.fromList(utf8.encode(widget.html)),
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
              if (defaultTargetPlatform == TargetPlatform.macOS) {
                _macDocumentNavigationStarted = false;
                final generation = ++_macLoadGeneration;
                unawaited(_failMacLoadIfUnready(controller, generation));
                // WKWebView can accept loadUrl before Flutter attaches the
                // platform view to its window, but it then never starts the
                // navigation. Begin the custom-scheme request after this
                // frame has attached the view.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !identical(controller, _controller)) return;
                  unawaited(_loadMacDocument(controller));
                });
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
                      debugPrint(
                          '[MessageWebHost][handler-rejected] $rejection');
                    }
                    return;
                  }
                  if (kDebugMode) {
                    debugPrint(
                      '[MessageWebHost][handler] ${data.args.first['type']}',
                    );
                  }
                  final event =
                      Map<String, dynamic>.from(data.args.first as Map);
                  if (defaultTargetPlatform == TargetPlatform.macOS &&
                      event['type'] == 'ready') {
                    _macDocumentNavigationStarted = true;
                    _macDocumentReady = true;
                    if (_macLoadFailed) {
                      setState(() => _macLoadFailed = false);
                    }
                  }
                  widget.onEvent(event);
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
                    _failMacLoadIfUnready(controller, _macLoadGeneration));
              }
              if (mounted && rendererReady) {
                _macDocumentNavigationStarted = true;
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
                    '[MessageWebHost][navigation] $url trusted=$trusted');
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
                      onPressed: _macLoadInProgress
                          ? null
                          : _controller == null
                              ? null
                              : () => _loadMacDocument(_controller!),
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
