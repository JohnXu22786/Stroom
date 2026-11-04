import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// A short-lived in-app sign-in view. Callback URLs are deliberately never
/// shown, logged, or sent to the persistent browser-history service.
class TraeSoloAuthorizationPage extends StatefulWidget {
  final Uri authorizationUri;
  final Future<Uri> callback;

  const TraeSoloAuthorizationPage({
    super.key,
    required this.authorizationUri,
    required this.callback,
  });

  @override
  State<TraeSoloAuthorizationPage> createState() =>
      _TraeSoloAuthorizationPageState();
}

class _TraeSoloAuthorizationPageState extends State<TraeSoloAuthorizationPage> {
  var _finished = false;

  @override
  void initState() {
    super.initState();
    unawaited(_waitForCallback());
  }

  Future<void> _waitForCallback() async {
    try {
      final callback = await widget.callback;
      if (!mounted || _finished) return;
      _finished = true;
      Navigator.of(context).pop<Uri>(callback);
    } catch (_) {
      if (!mounted || _finished) return;
      _finished = true;
      Navigator.of(context).pop<Uri>();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('连接 Trae SOLO'),
          leading: IconButton(
            tooltip: '取消',
            icon: const Icon(Icons.close),
            onPressed: () {
              _finished = true;
              Navigator.of(context).pop<Uri>();
            },
          ),
        ),
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(widget.authorizationUri.toString()),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
              transparentBackground: false,
            ),
            shouldOverrideUrlLoading: (controller, action) async {
              final uri = action.request.url;
              if (uri == null) return NavigationActionPolicy.CANCEL;
              final scheme = uri.scheme.toLowerCase();
              if (scheme == 'https') return NavigationActionPolicy.ALLOW;
              if (scheme == 'http' &&
                  uri.host == '127.0.0.1' &&
                  uri.path == '/authorize') {
                return NavigationActionPolicy.ALLOW;
              }
              return NavigationActionPolicy.CANCEL;
            },
            onReceivedError: (controller, request, error) {
              if (request.isForMainFrame == true && mounted && !_finished) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('登录页面加载失败，请取消后重试。')),
                );
              }
            },
          ),
        ),
      );
}
