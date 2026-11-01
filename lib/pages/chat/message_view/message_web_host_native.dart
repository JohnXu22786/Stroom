import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

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
  Directory? _macDocumentDirectory;
  Uri? _macDocumentUri;
  bool _macDocumentNavigationStarted = false;
  bool _macDocumentReady = false;
  bool _macLoadInProgress = false;
  bool _macLoadFailed = false;
  int _macLoadGeneration = 0;

  bool _trustedDocument(Uri uri) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return uri.toString() == 'about:blank' ||
          (uri.scheme == 'file' &&
              uri.toString() == _macDocumentUri?.toString());
    }
    return uri.scheme == 'file' &&
        uri.path.endsWith('/assets/vendor/dsh_message_view/index.html');
  }

  bool _isMacDocumentUrl(WebUri? url) =>
      url?.scheme == 'file' && url.toString() == _macDocumentUri?.toString();

  Future<void> _loadMacDocument(InAppWebViewController controller) async {
    if (_macLoadInProgress || !mounted || !identical(controller, _controller)) {
      return;
    }
    _macLoadInProgress = true;
    _macLoadGeneration++;
    _macLoadFailed = false;
    _macDocumentReady = false;
    setState(() {});

    Directory? createdDirectory;
    try {
      var documentDirectory = _macDocumentDirectory;
      var documentUri = _macDocumentUri;
      if (documentDirectory == null || documentUri == null) {
        final directory = await getTemporaryDirectory();
        await directory.create(recursive: true);
        documentDirectory = await directory.createTemp('stroom-message-');
        createdDirectory = documentDirectory;
        if (!mounted || !identical(controller, _controller)) {
          await _deleteMacDocumentDirectory(documentDirectory);
          return;
        }
        final document = File('${documentDirectory.path}/index.html');
        await document.writeAsString(widget.html, flush: true);
        documentUri = document.uri;
        _macDocumentDirectory = documentDirectory;
        _macDocumentUri = documentUri;
      }

      if (!mounted || !identical(controller, _controller)) {
        if (createdDirectory != null) {
          await _deleteMacDocumentDirectory(createdDirectory);
          if (identical(createdDirectory, _macDocumentDirectory)) {
            _macDocumentDirectory = null;
            _macDocumentUri = null;
          }
        }
        return;
      }

      _macDocumentNavigationStarted = false;
      var macNavigationPending = false;

      // WKWebView's loadHTMLString/loadData path does not consistently start a
      // navigation. Give WebKit read access to this self-contained file only.
      for (var attempt = 0; attempt < 8; attempt++) {
        if (!mounted ||
            !identical(controller, _controller) ||
            _macLoadFailed) {
          return;
        }
        if (_macDocumentNavigationStarted) {
          macNavigationPending = true;
          break;
        }
        try {
          if (kDebugMode) {
            debugPrint(
              '[MessageWebHost][load-file-start] macOS attempt=${attempt + 1}',
            );
          }
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri.uri(documentUri)),
            allowingReadAccessTo: WebUri.uri(documentUri),
          );
          if (_macLoadFailed) break;
          final currentUrl = await controller.getUrl();
          final isLoading = await controller.isLoading();
          if (kDebugMode) {
            debugPrint(
              '[MessageWebHost][load-file-sent] macOS attempt=${attempt + 1}',
            );
            debugPrint(
              '[MessageWebHost][load-file-state] macOS attempt=${attempt + 1} '
              'url=$currentUrl isLoading=$isLoading',
            );
          }
          if (currentUrl?.toString() == documentUri.toString() &&
              (isLoading || _macDocumentNavigationStarted)) {
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
        while (DateTime.now().isBefore(deadline) &&
            mounted &&
            identical(controller, _controller) &&
            !_macDocumentReady &&
            !_macLoadFailed) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (mounted &&
            identical(controller, _controller) &&
            !_macDocumentReady &&
            !_macLoadFailed) {
          if (kDebugMode) {
            debugPrint(
              '[MessageWebHost][load-timeout] macOS document did not become ready',
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
      if (createdDirectory != null &&
          !identical(createdDirectory, _macDocumentDirectory)) {
        await _deleteMacDocumentDirectory(createdDirectory);
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

  Future<void> _deleteMacDocumentDirectory(Directory directory) async {
    try {
      await directory.delete(recursive: true);
    } catch (_) {
      // The OS may already have removed the temporary files.
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
    final documentDirectory = _macDocumentDirectory;
    if (documentDirectory != null) {
      unawaited(_deleteMacDocumentDirectory(documentDirectory));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          InAppWebView(
            // WebView2 NavigateToString has a 2 MiB limit. Load the bundled file on
            // native platforms except macOS, where the document is copied into an
            // isolated temporary directory and opened as a file URL.
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
                      debugPrint(
                          '[MessageWebHost][handler-rejected] $rejection');
                    }
                    return;
                  }
                  if (kDebugMode) {
                    debugPrint(
                        '[MessageWebHost][handler] ${data.args.first['type']}');
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
                unawaited(_failMacLoadIfUnready(
                  controller,
                  _macLoadGeneration,
                ));
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
                        onPressed: _macLoadInProgress || _controller == null
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
