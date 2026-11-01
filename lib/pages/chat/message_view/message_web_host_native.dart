import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
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
  static final Map<String, Future<File>> _macDocuments = {};

  InAppWebViewController? _controller;
  Future<File>? _macDocumentFuture;
  Future<void> _pending = Future.value();
  Key _macWebViewKey = UniqueKey();
  bool _macDocumentReady = false;
  bool _macLoadFailed = false;
  int _macLoadGeneration = 0;
  int _macControllerGeneration = -1;

  bool _trustedDocument(Uri uri, File? macDocument) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final document = macDocument?.uri.toString();
      final requested = uri.toString().split('#').first;
      return document == requested;
    }
    return uri.scheme == 'file' &&
        uri.path.endsWith('/assets/vendor/dsh_message_view/index.html');
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

  void _markMacDocumentReady() {
    if (_macDocumentReady) return;
    _macDocumentReady = true;
    if (!mounted) return;
    if (_macLoadFailed) setState(() => _macLoadFailed = false);
    widget.onEvent({'type': 'ready'});
  }

  static Future<File> _prepareMacDocument(String html) async {
    final content = utf8.encode(html);
    final digest = sha256.convert(content).toString();
    final pending = _macDocuments.putIfAbsent(digest, () async {
      final directory = await getTemporaryDirectory();
      final documentDirectory = Directory(
        p.join(directory.path, 'stroom-dsh-$digest'),
      );
      await documentDirectory.create(recursive: true);
      final file = File(p.join(documentDirectory.path, 'index.html'));
      if (!await file.exists() || await file.length() != content.length) {
        await file.writeAsBytes(content, flush: true);
      }
      return file;
    });
    try {
      return await pending;
    } catch (_) {
      if (identical(_macDocuments[digest], pending)) {
        _macDocuments.remove(digest);
      }
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.commands.addListener(_send);
  }

  @override
  void didUpdateWidget(covariant MessageWebHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _macDocumentFuture = null;
      _controller = null;
      _macDocumentReady = false;
      _macLoadFailed = false;
      _macLoadGeneration++;
    }
  }

  void _send() {
    final command = widget.commands.value;
    final controller = _controller;
    if (command == null || controller == null) return;
    if (defaultTargetPlatform == TargetPlatform.macOS && !_macDocumentReady) {
      // DshMessageView sends a fresh snapshot when the bridge reports ready.
      // Drop stale patches while loading or retrying instead of retaining an
      // unbounded queue while assistant messages continue to stream.
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
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return FutureBuilder<File>(
        future: _macDocumentFuture ??= _prepareMacDocument(widget.html),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (kDebugMode) {
              debugPrint(
                '[MessageWebHost][file-prepare-error] ${snapshot.error}',
              );
            }
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('消息内容加载失败'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _macDocumentFuture = null;
                    }),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildWebView(context, snapshot.data);
        },
      );
    }
    return _buildWebView(context, null);
  }

  Widget _buildWebView(BuildContext context, File? macDocument) {
    return Stack(
      children: [
        InAppWebView(
          key: defaultTargetPlatform == TargetPlatform.macOS
              ? _macWebViewKey
              : null,
          // WebView2 NavigateToString has a 2 MiB limit. Load the bundled file
          // on native platforms except macOS, which loads a temporary file
          // because its plugin cannot resolve Flutter asset paths.
          initialFile: defaultTargetPlatform == TargetPlatform.macOS
              ? null
              : 'assets/vendor/dsh_message_view/index.html',
          initialUrlRequest: macDocument == null
              ? null
              : URLRequest(url: WebUri.uri(macDocument.uri)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: true,
            disableContextMenu: false,
            supportZoom: false,
            useShouldOverrideUrlLoading: true,
            javaScriptHandlersForMainFrameOnly: true,
            allowingReadAccessTo:
                macDocument == null ? null : WebUri.uri(macDocument.parent.uri),
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
                request.url.toString() == macDocument?.uri.toString() &&
                identical(controller, _controller) &&
                _macControllerGeneration == _macLoadGeneration &&
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
              _macControllerGeneration = generation;
              _macDocumentReady = false;
              unawaited(_failMacLoadIfUnready(controller, generation));
            }
            controller.addJavaScriptHandler(
              handlerName: 'StroomMessageView',
              callback: (JavaScriptHandlerFunctionData data) {
                final trustedFrame = data.isMainFrame &&
                    _trustedDocument(data.requestUrl, macDocument);
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
                    debugPrint('[MessageWebHost][handler-rejected] $rejection');
                  }
                  return;
                }
                if (kDebugMode) {
                  debugPrint(
                    '[MessageWebHost][handler] ${data.args.first['type']}',
                  );
                }
                final event = Map<String, dynamic>.from(data.args.first as Map);
                if (defaultTargetPlatform == TargetPlatform.macOS &&
                    event['type'] == 'ready') {
                  _markMacDocumentReady();
                  return;
                }
                widget.onEvent(event);
              },
            );
          },
          onLoadStart: (controller, url) {
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
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              if (!identical(controller, _controller) ||
                  _macControllerGeneration != _macLoadGeneration) {
                return;
              }
              if (rendererReady) {
                _markMacDocumentReady();
              } else {
                unawaited(
                  _failMacLoadIfUnready(controller, _macLoadGeneration),
                );
              }
              return;
            }
            if (mounted && rendererReady) {
              widget.onEvent({'type': 'ready'});
            }
          },
          shouldOverrideUrlLoading: (controller, action) async {
            final url = action.request.url;
            final trusted = url != null && _trustedDocument(url, macDocument);
            if (kDebugMode) {
              debugPrint('[MessageWebHost][navigation] $url trusted=$trusted');
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
