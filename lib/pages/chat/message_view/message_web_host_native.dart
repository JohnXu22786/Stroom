import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MessageWebHost extends StatefulWidget {
  final String html;
  final ValueNotifier<Map<String, dynamic>?> commands;
  final void Function(Map<String, dynamic>) onEvent;

  const MessageWebHost(
      {super.key,
      required this.html,
      required this.commands,
      required this.onEvent});

  @override
  State<MessageWebHost> createState() => _MessageWebHostState();
}

class _MessageWebHostState extends State<MessageWebHost> {
  InAppWebViewController? _controller;
  Future<void> _pending = Future.value();

  bool _trustedDocument(Uri uri) =>
      uri.scheme == 'file' &&
      uri.path.endsWith('/assets/vendor/dsh_message_view/index.html');

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
          source: 'window.StroomMessageView?.receive(${jsonEncode(command)});');
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
        // every native platform; all scripts, styles and fonts are self-contained.
        initialFile: 'assets/vendor/dsh_message_view/index.html',
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          transparentBackground: true,
          disableContextMenu: false,
          supportZoom: false,
          useShouldOverrideUrlLoading: true,
          javaScriptHandlersForMainFrameOnly: true,
          // Linux currently matches literal substrings; other hosts use regex.
          javaScriptHandlersOriginAllowList:
              defaultTargetPlatform == TargetPlatform.linux
                  ? {'file://'}
                  : {r'^(file://.*|null)$'},
        ),
        onWebViewCreated: (controller) {
          _controller = controller;
          controller.addJavaScriptHandler(
              handlerName: 'StroomMessageView',
              callback: (JavaScriptHandlerFunctionData data) {
                if (!mounted ||
                    !data.isMainFrame ||
                    !_trustedDocument(data.requestUrl) ||
                    data.args.length != 1 ||
                    data.args.first is! Map) return;
                widget
                    .onEvent(Map<String, dynamic>.from(data.args.first as Map));
              });
        },
        onLoadStop: (controller, url) async {
          final ready = await controller.evaluateJavascript(
              source: '!!window.StroomMessageView');
          if (mounted && ready == true) widget.onEvent({'type': 'ready'});
        },
        shouldOverrideUrlLoading: (controller, action) async =>
            action.request.url != null && _trustedDocument(action.request.url!)
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL,
      );
}
